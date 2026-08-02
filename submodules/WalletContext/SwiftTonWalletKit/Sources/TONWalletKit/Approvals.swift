import Foundation
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect

extension TonWalletKit {
    // MARK: - sendTransaction

    /// Signs, broadcasts, and acknowledges a transfer.
    ///
    /// Returns the signed BoC so a host app can record it. The order — sign, broadcast,
    /// reply — matters: replying before the broadcast succeeds would tell the dApp a
    /// transaction is on its way when it may never have left.
    @discardableResult
    public func approve(_ request: SendTransactionRequest) async throws -> String {
        let wallet = try requireWallet(request.walletID)
        let session = try await requireSession(request.sessionID)
        try validateNotExpired(request.validUntil)
        try validateNetwork(request.network, wallet: wallet)

        // Claiming is what makes double-approval impossible: a second tap on the same sheet
        // loses the race and is refused rather than signing the transfer twice.
        guard await eventStore.claim(id: request.id, walletID: request.walletID.value) != nil else {
            throw WalletKitError.requestAlreadyHandled(request.id)
        }

        do {
            let boc = try await sign(messages: request.messages, wallet: wallet)

            if !configuration.skipBroadcast {
                let client = try requireClient(for: wallet)
                do {
                    _ = try await client.sendBoc(boc)
                } catch {
                    throw WalletKitError.chainFailure(underlying: error)
                }
            }

            try await send(WalletResponseSuccess(id: request.id, result: boc), to: session)
            try await eventStore.complete(id: request.id)
            return boc
        } catch {
            // Release rather than complete, so a transient failure can be retried instead of
            // leaving the request stuck in `processing` until the recovery sweep finds it.
            _ = try? await eventStore.release(id: request.id, error: String(describing: error))
            throw error
        }
    }

    /// Refuses a transfer and tells the dApp.
    public func reject(_ request: SendTransactionRequest, reason: String? = nil) async throws {
        try await rejectRPC(
            id: request.id,
            sessionID: request.sessionID,
            code: SendTransactionErrorCode.userRejects.rawValue,
            message: reason ?? "User rejected the transaction"
        )
    }

    // MARK: - signMessage

    /// Signs a transfer without broadcasting it and returns the body.
    ///
    /// The dApp broadcasts it, so the wallet must not — doing both would send the same
    /// transfer twice, and the second attempt fails on a consumed seqno rather than harmlessly.
    @discardableResult
    public func approve(_ request: SignMessageRequest) async throws -> String {
        let wallet = try requireWallet(request.walletID)
        let session = try await requireSession(request.sessionID)
        try validateNotExpired(request.validUntil)
        try validateNetwork(request.network, wallet: wallet)

        guard await eventStore.claim(id: request.id, walletID: request.walletID.value) != nil else {
            throw WalletKitError.requestAlreadyHandled(request.id)
        }

        do {
            let boc = try await sign(messages: request.messages, wallet: wallet)
            try await send(SignMessageResponseSuccess(id: request.id, internalBoc: boc), to: session)
            try await eventStore.complete(id: request.id)
            return boc
        } catch {
            _ = try? await eventStore.release(id: request.id, error: String(describing: error))
            throw error
        }
    }

    public func reject(_ request: SignMessageRequest, reason: String? = nil) async throws {
        try await rejectRPC(
            id: request.id,
            sessionID: request.sessionID,
            code: SendTransactionErrorCode.userRejects.rawValue,
            message: reason ?? "User rejected the sign request"
        )
    }

    // MARK: - signData

    /// Signs a `signData` payload and replies.
    ///
    /// The timestamp is stamped here, not taken from the dApp. A dApp-supplied timestamp
    /// would let it obtain a signature that appears to have been made at a time of its
    /// choosing.
    @discardableResult
    public func approve(_ request: SignDataRequest) async throws -> String {
        let wallet = try requireWallet(request.walletID)
        let session = try await requireSession(request.sessionID)
        try validateNetwork(request.network, wallet: wallet)

        guard await eventStore.claim(id: request.id, walletID: request.walletID.value) != nil else {
            throw WalletKitError.requestAlreadyHandled(request.id)
        }

        do {
            let timestamp = UInt64(currentMillis() / 1000)
            let hash: Data
            do {
                hash = try SignData.hash(
                    payload: request.payload,
                    address: wallet.address,
                    domain: request.domain,
                    timestamp: timestamp
                )
            } catch {
                throw WalletKitError.cryptoFailure(underlying: error)
            }

            let signature = try await wallet.signData(hash: hash)
            let base64 = signature.base64EncodedString()

            try await send(
                SignDataResponseSuccess(
                    id: request.id,
                    result: .init(
                        signature: base64,
                        // Raw form: the dApp reconstructs the signed message from this, and
                        // friendly form would not match what was hashed.
                        address: wallet.address.rawString,
                        timestamp: timestamp,
                        domain: request.domain,
                        payload: echo(request.payload, network: request.network, from: request.from)
                    )
                ),
                to: session
            )
            try await eventStore.complete(id: request.id)
            return base64
        } catch {
            _ = try? await eventStore.release(id: request.id, error: String(describing: error))
            throw error
        }
    }

    public func reject(_ request: SignDataRequest, reason: String? = nil) async throws {
        try await rejectRPC(
            id: request.id,
            sessionID: request.sessionID,
            code: SignDataErrorCode.userRejects.rawValue,
            message: reason ?? "User rejected the signature request"
        )
    }

    // MARK: - Shared

    private func echo(
        _ payload: SignData.Payload,
        network: String?,
        from: String?
    ) -> SignDataPayloadEcho {
        switch payload {
        case .text(let text):
            return .text(text, network: network, from: from)
        case .binary(let data):
            return .binary(base64: data.base64EncodedString(), network: network, from: from)
        case .cell(let schema, let cell):
            return .cell(base64: cell.toBocBase64(), schema: schema, network: network, from: from)
        }
    }

    private func rejectRPC(id: String, sessionID: String, code: Int, message: String) async throws {
        let session = try await requireSession(sessionID)
        // Mark it done before sending: a rejection the user made must not be re-offered
        // because the network call failed.
        _ = try? await eventStore.complete(id: id)
        do {
            try await send(WalletResponseError(id: id, code: code, message: message), to: session)
        } catch {
            throw WalletKitError.bridgeFailure(underlying: error)
        }
    }

    /// Builds and signs the external message for a set of transfers.
    ///
    /// Reads seqno and deploy state from the chain at signing time rather than caching them:
    /// a stale seqno produces a signature the contract rejects, and a stale deploy flag
    /// produces one that either omits a required state init or pays to include a redundant one.
    func sign(
        messages: [TransferMessage],
        wallet: Wallet,
        sendMode: SendMode = .walletDefault
    ) async throws -> String {
        guard !messages.isEmpty else {
            throw WalletKitError.validationFailed(reason: "Transfer has no messages")
        }
        guard messages.count <= wallet.maxMessagesPerTransfer else {
            throw WalletKitError.tooManyMessages(count: messages.count, maximum: wallet.maxMessagesPerTransfer)
        }

        let client = try requireClient(for: wallet)
        let state: AccountState
        do {
            state = try await client.getAccountState(address: wallet.address.toString())
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }

        let seqno = state.isDeployed ? try await fetchSeqno(client: client, wallet: wallet) : 0
        let validUntil = UInt32(currentMillis() / 1000) + configuration.transferValidityWindow

        return try await wallet.signedTransfer(
            messages: messages.map { $0.toMessageRelaxed() },
            seqno: seqno,
            isDeployed: state.isDeployed,
            validUntil: validUntil,
            sendMode: sendMode
        )
    }

    /// Reads the wallet's seqno.
    ///
    /// A get-method call rather than parsing contract data, because the storage layout
    /// differs between V4R2 and V5R1 while `seqno` is a stable interface on both.
    private func fetchSeqno(client: any ApiClient, wallet: Wallet) async throws -> UInt32 {
        do {
            let result = try await client.runGetMethod(
                address: wallet.address.toString(),
                method: "seqno",
                stack: []
            )
            var reader = try result.reader()
            let value = try reader.readBigInt()
            guard let seqno = UInt32(exactly: value) else {
                throw WalletKitError.validationFailed(reason: "seqno \(value) does not fit in 32 bits")
            }
            return seqno
        } catch let error as WalletKitError {
            throw error
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    /// Emulates a transfer for the confirmation sheet.
    ///
    /// Returns nil on failure rather than throwing: a preview is an aid, and refusing to show
    /// the user the request at all because emulation was unavailable is worse than showing it
    /// without a preview. The sheet is expected to say the preview is missing.
    func emulatePreview(messages: [TransferMessage], wallet: Wallet) async -> EmulationPreview? {
        guard let client = clients[wallet.network] else { return nil }
        do {
            // Signed with a throwaway signature and emulated with signature checking off:
            // the point is the resulting value flow, not signature validity.
            let boc = try await sign(messages: messages, wallet: wallet)
            let result = try await client.emulate(boc: boc, ignoreSignature: true)
            
            print("incomplete", result.isIncomplete)
            for tx in result.transactions where tx.isFailed {
                print(
                    tx.account,
                    tx.kind,
                    tx.aborted,
                    tx.exitCode as Any,
                    tx.computeSkipReason as Any,
                    tx.inMessage.map { MessageClassifier.classify($0) } as Any
                )
            }
            
            return EmulationPreview(emulation: result, walletAddress: wallet.address.toString())
        } catch {
            return nil
        }
    }

    // MARK: - Validation

    func validateNotExpired(_ validUntil: UInt64?) throws {
        guard let validUntil else { return }
        let now = UInt64(currentMillis() / 1000)
        guard validUntil >= now else {
            throw WalletKitError.requestExpired(validUntil: validUntil, now: now)
        }
    }

    /// Refuses a request that names a network other than the wallet's.
    ///
    /// The same key produces the same address on mainnet and testnet, so a mislabelled
    /// request would sign cleanly and spend real funds.
    func validateNetwork(_ requested: String?, wallet: Wallet) throws {
        guard let requested, requested != wallet.network.chainId else { return }
        throw WalletKitError.walletNetworkMismatch(
            walletChainID: wallet.network.chainId,
            requestChainID: requested
        )
    }
}
