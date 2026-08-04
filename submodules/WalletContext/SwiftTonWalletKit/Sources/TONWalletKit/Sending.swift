import Foundation
import TONCore
import TONCrypto
import TONContracts
import TONToncenter
import TONConnect

/// A transfer the wallet signed and broadcast.
public struct SentTransfer: Sendable {
    /// The signed external message, base64.
    public let boc: String
    /// TEP-467 normalized hash — what to look the transaction up by afterwards.
    ///
    /// Not the hash of ``boc``: an external message can be re-serialised in ways that change its
    /// plain hash without changing its meaning, so indexers key on the normalized form. Looking
    /// up by the wrong one silently never finds the transaction.
    public let normalizedHash: String

    public init(boc: String, normalizedHash: String) {
        self.boc = boc
        self.normalizedHash = normalizedHash
    }
}

extension TonWalletKit {
    // MARK: - TON

    /// Sends TON.
    ///
    /// `to` is parsed with its bounceable flag honoured, so a `UQ…`/`0Q…` address funds an
    /// account that has no contract yet instead of bouncing off it.
    @discardableResult
    public func sendTON(
        from walletID: WalletID,
        to recipient: String,
        amount: BigUInt,
        comment commentText: String? = nil,
        sendMode: SendMode = .walletDefault
    ) async throws -> SentTransfer {
        let payload = try commentText.map { try TransferPayloads.comment($0) }
        let message = try TransferMessage(
            addressString: recipient,
            amount: amount,
            payload: payload
        )
        return try await send(messages: [message], from: walletID, sendMode: sendMode)
    }

    /// Signs and broadcasts arbitrary transfers in one external message.
    ///
    /// The general form the typed helpers build on. Batching matters on V5R1, which carries up
    /// to 255 messages in one signature — sending them separately would need 255 seqno
    /// round-trips and 255 user confirmations.
    @discardableResult
    public func send(
        messages: [TransferMessage],
        from walletID: WalletID,
        sendMode: SendMode = .walletDefault
    ) async throws -> SentTransfer {
        let wallet = try requireWallet(walletID)
        let client = try requireClient(for: wallet)

        let boc = try await sign(messages: messages, wallet: wallet, sendMode: sendMode)
        let normalized: NormalizedMessage.Normalized
        do {
            normalized = try NormalizedMessage.normalize(base64: boc)
        } catch {
            throw WalletKitError.contractFailure(underlying: error)
        }

        if !configuration.skipBroadcast {
            do {
                _ = try await client.sendBoc(boc)
            } catch {
                throw WalletKitError.chainFailure(underlying: error)
            }
        }
        return SentTransfer(boc: boc, normalizedHash: normalized.hash)
    }

    // MARK: - Jettons

    /// Sends jettons.
    ///
    /// `jettonMaster` is the token contract. The sender's own jetton wallet — the contract the
    /// transfer is actually addressed to — is resolved from it, because that address depends on
    /// the master's stored wallet code and cannot be derived independently without risking
    /// disagreement with the contract.
    @discardableResult
    public func sendJetton(
        from walletID: WalletID,
        jettonMaster: String,
        to recipient: String,
        amount: BigUInt,
        comment commentText: String? = nil,
        forwardAmount: BigUInt = TransferPayloads.defaultForwardAmount,
        attachedTON: BigUInt? = nil
    ) async throws -> SentTransfer {
        let wallet = try requireWallet(walletID)
        guard amount > 0 else {
            throw WalletKitError.validationFailed(reason: "Jetton transfer amount must be positive")
        }

        // Derived from the forward amount rather than a flat default, because the jetton wallet
        // pays the forward *out of* what is attached. Leaving them independent means raising
        // the forward silently underfunds the transfer: the contract aborts with exit code 709
        // (`not_enough_tons`), nothing moves, and the send itself reports success because the
        // external message was accepted. Found exactly that way.
        let attached = attachedTON ?? (TransferPayloads.defaultJettonGas + forwardAmount)
        try validateAttachedValue(attached, forwardAmount: forwardAmount, minimumGas: TransferPayloads.defaultJettonGas)

        let destination = try parse(recipient, describedAs: "recipient")
        let senderJettonWallet = try await jettonWalletAddress(
            walletID: walletID,
            jettonMaster: jettonMaster
        )

        let body = try TransferPayloads.jettonTransfer(
            amount: amount,
            destination: destination,
            // The unspent TON comes back to us rather than staying in the jetton wallet.
            responseDestination: wallet.address,
            comment: commentText,
            forwardAmount: forwardAmount
        )

        return try await send(
            messages: [
                // Bounceable: the jetton wallet is a deployed contract, and if it rejects the
                // transfer the attached TON should come back rather than be absorbed.
                TransferMessage(address: senderJettonWallet, amount: attached, payload: body, bounce: true)
            ],
            from: walletID
        )
    }

    /// The jetton wallet holding a wallet's balance of a token, as the master computes it.
    ///
    /// Keyed by ``WalletID`` rather than a bare owner address so the lookup runs against that
    /// wallet's own network. The same master address can exist on both chains, and resolving
    /// against the wrong one yields an address that looks plausible and holds nothing.
    public func jettonWalletAddress(
        walletID: WalletID,
        jettonMaster: String
    ) async throws -> Address {
        let wallet = try requireWallet(walletID)
        return try await Self.resolveJettonWallet(
            jettonMaster: jettonMaster,
            owner: wallet.address,
            client: try requireClient(for: wallet)
        )
    }

    /// Resolves a jetton wallet through the master's `get_wallet_address`.
    static func resolveJettonWallet(
        jettonMaster: String,
        owner: Address,
        client: any ApiClient
    ) async throws -> Address {
        do {
            let ownerCell = try beginCell().storeAddress(owner).endCell()
            let result = try await client.runGetMethod(
                address: jettonMaster,
                method: "get_wallet_address",
                stack: [.slice(ownerCell.toBocBase64())]
            )
            var reader = try result.reader()
            var slice = try reader.readCell().beginParse()
            return try slice.loadAddress()
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    /// A wallet's balance of one token, in the token's base units.
    public func jettonBalance(
        walletID: WalletID,
        jettonMaster: String
    ) async throws -> BigUInt {
        let wallet = try requireWallet(walletID)
        let client = try requireClient(for: wallet)
        let jettonWallet = try await Self.resolveJettonWallet(
            jettonMaster: jettonMaster, owner: wallet.address, client: client
        )

        do {
            // An owner who has never held the token has no jetton wallet yet, which is a zero
            // balance rather than an error.
            let state = try await client.getAccountState(address: jettonWallet.rawString)
            guard state.isDeployed else { return 0 }

            var reader = try await client.runGetMethod(
                address: jettonWallet.rawString, method: "get_wallet_data", stack: []
            ).reader()
            return BigUInt(try reader.readBigInt())
        } catch {
            throw WalletKitError.chainFailure(underlying: error)
        }
    }

    // MARK: - NFTs

    /// Transfers an NFT item to a new owner.
    ///
    /// Addressed to the item contract itself, unlike a jetton transfer.
    @discardableResult
    public func sendNFT(
        from walletID: WalletID,
        item: String,
        to recipient: String,
        comment commentText: String? = nil,
        forwardAmount: BigUInt = TransferPayloads.defaultForwardAmount,
        attachedTON: BigUInt? = nil
    ) async throws -> SentTransfer {
        let wallet = try requireWallet(walletID)
        let itemAddress = try parse(item, describedAs: "NFT item")
        let newOwner = try parse(recipient, describedAs: "recipient")

        // Same derivation as jettons: the item forwards out of what is attached.
        let attached = attachedTON ?? (TransferPayloads.defaultNFTGas + forwardAmount)
        try validateAttachedValue(attached, forwardAmount: forwardAmount, minimumGas: TransferPayloads.defaultNFTGas)

        let body = try TransferPayloads.nftTransfer(
            newOwner: newOwner,
            responseDestination: wallet.address,
            comment: commentText,
            forwardAmount: forwardAmount
        )

        return try await send(
            messages: [
                TransferMessage(address: itemAddress, amount: attached, payload: body, bounce: true)
            ],
            from: walletID
        )
    }

    // MARK: - Preview

    /// Emulates a transfer without sending it.
    ///
    /// Returns nil when emulation is unavailable, matching the dApp-request path: a missing
    /// preview must not stop the user from being shown the transfer.
    public func preview(
        messages: [TransferMessage],
        from walletID: WalletID
    ) async -> EmulationPreview? {
        guard let wallet = try? requireWallet(walletID) else { return nil }
        return await emulatePreview(messages: messages, wallet: wallet)
    }

    /// Refuses an attached value that cannot cover the forward plus gas.
    ///
    /// The contract's own failure for this is exit code 709 with nothing moved and no error
    /// from the send — the external message is accepted, so a caller sees success. Catching it
    /// here turns a silent no-op into an explicit refusal before anything is signed.
    private func validateAttachedValue(
        _ attached: BigUInt,
        forwardAmount: BigUInt,
        minimumGas: BigUInt
    ) throws {
        // Expressed with addition, never subtraction. `attached - forwardAmount` **traps** on
        // `BigUInt` when a caller attaches less than they forward, so a validation error would
        // become a crash — and a wallet that crashes on bad input is far worse than one that
        // throws. Two ordered guards would also avoid the trap, but only by ordering, which a
        // later refactor can break silently.
        guard attached < forwardAmount + minimumGas else { return }

        // Saturating, computed once, before any branch. Every path below can then mention the
        // headroom without a subtraction that could underflow, so no ordering of the branches
        // can reintroduce the trap.
        let headroom = attached > forwardAmount ? attached - forwardAmount : 0

        // The two branches differ only in wording — both refuse, and both name exit code 709.
        // Collapsing them is therefore an equivalent mutation, and no test distinguishes them
        // on purpose: asserting exact diagnostic text buys brittleness, not safety.
        if attached <= forwardAmount {
            throw WalletKitError.validationFailed(reason: """
                Attached \(attached) nanoton but \(forwardAmount) is forwarded to the recipient; \
                the contract pays the forward out of the attached value and would abort with \
                exit code 709
                """)
        }
        throw WalletKitError.validationFailed(reason: """
            Attached \(attached) nanoton leaves only \(headroom) for gas after \
            forwarding \(forwardAmount); at least \(minimumGas) is needed, or the contract \
            aborts with exit code 709
            """)
    }

    private func parse(_ address: String, describedAs what: String) throws -> Address {
        do {
            return try Address.parse(address)
        } catch {
            throw WalletKitError.validationFailed(reason: "\(what) address \(address) is not a TON address")
        }
    }
}
