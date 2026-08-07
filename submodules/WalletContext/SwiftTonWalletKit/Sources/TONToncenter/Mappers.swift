import Foundation
import TONCore

/// Converts Toncenter wire shapes into domain models.
enum Mappers {
    /// Toncenter returns hashes as base64; the domain models use `0x`-prefixed hex,
    /// matching the reference's `Hex` type.
    ///
    /// Returns nil for a missing or malformed value rather than throwing: a hash the
    /// server stopped sending must not take down the whole response.
    static func hexHash(fromBase64 value: String?) -> String? {
        guard let value, !value.isEmpty, let data = Data(anyBase64: value) else { return nil }
        return "0x\(data.hexString)"
    }

    /// Normalizes any address form to the canonical friendly bounceable one used as a
    /// key throughout this layer.
    static func canonical(address: String) throws -> String {
        do {
            return try Address.parse(address).toString(urlSafe: true, bounceable: true, testOnly: false)
        } catch {
            throw ToncenterError.addressNormalizationFailed(address)
        }
    }

    // MARK: - Masterchain

    static func masterchainInfo(_ wire: Wire.MasterchainInfoResponse) -> MasterchainInfo {
        MasterchainInfo(
            workchain: wire.last.workchain,
            seqno: wire.last.seqno,
            shard: wire.last.shard,
            rootHash: hexHash(fromBase64: wire.last.rootHash) ?? "0x",
            fileHash: hexHash(fromBase64: wire.last.fileHash) ?? "0x"
        )
    }

    // MARK: - Account state

    static func accountState(
        _ wire: Wire.AddressInformation,
        address: String
    ) throws -> AccountState {
        let canonicalAddress = try canonical(address: address)
        let status = AccountStatus(wire: wire.status ?? "")

        let lastTransaction: TransactionID?
        if let lt = wire.lastTransactionLt,
           lt != "0",
           let hash = hexHash(fromBase64: wire.lastTransactionHash) {
            lastTransaction = TransactionID(logicalTime: lt, hash: hash)
        } else {
            lastTransaction = nil
        }

        return AccountState(
            address: canonicalAddress,
            status: status,
            rawBalance: normalizeBalance(wire.balance),
            balance: formatBalance(wire.balance),
            extraCurrencies: wire.extraCurrencies ?? [:],
            // An empty string means "no code", which is not the same as a code cell of
            // zero length; normalize it to nil.
            code: wire.code.flatMap { $0.isEmpty ? nil : $0 },
            data: wire.data.flatMap { $0.isEmpty ? nil : $0 },
            lastTransaction: lastTransaction
        )
    }

    static func accountStates(
        _ wire: Wire.AccountStatesResponse,
        requested: [String]
    ) throws -> [String: AccountState] {
        var result: [String: AccountState] = [:]

        for entry in wire.accounts {
            let canonicalAddress = try canonical(address: entry.address)
            let lastTransaction: TransactionID?
            if let lt = entry.lastTransactionLt,
               lt != "0",
               let hash = hexHash(fromBase64: entry.lastTransactionHash) {
                lastTransaction = TransactionID(logicalTime: lt, hash: hash)
            } else {
                lastTransaction = nil
            }

            result[canonicalAddress] = AccountState(
                address: canonicalAddress,
                status: AccountStatus(wire: entry.status ?? ""),
                rawBalance: normalizeBalance(entry.balance),
                balance: formatBalance(entry.balance),
                extraCurrencies: entry.extraCurrencies ?? [:],
                code: entry.code.flatMap { $0.isEmpty ? nil : $0 },
                data: entry.data.flatMap { $0.isEmpty ? nil : $0 },
                lastTransaction: lastTransaction
            )
        }

        // Every requested address gets an entry. Accounts the chain has never seen are
        // absent from the response, and callers should not have to distinguish "absent"
        // from "empty" — a nil here has bitten enough call sites in the reference.
        for address in requested {
            let canonicalAddress = try canonical(address: address)
            if result[canonicalAddress] == nil {
                result[canonicalAddress] = .nonExisting(address: canonicalAddress)
            }
        }

        return result
    }

    /// Toncenter occasionally reports a negative or empty balance for odd accounts;
    /// clamp to a usable nanoton string.
    static func normalizeBalance(_ raw: String) -> String {
        guard !raw.isEmpty else { return "0" }
        if raw.hasPrefix("-") { return "0" }
        return raw
    }

    static func formatBalance(_ raw: String) -> String {
        Units.fromNano(BigUInt(normalizeBalance(raw)) ?? 0)
    }

    // MARK: - Get-method

    static func getMethodResult(_ wire: Wire.RunGetMethodResponse) -> GetMethodResult {
        GetMethodResult(exitCode: wire.exitCode, gasUsed: wire.gasUsed, stack: wire.stack)
    }

    // MARK: - Transactions

    static func transactions(_ wire: Wire.TransactionsResponse) -> TransactionsPage {
        TransactionsPage(
            transactions: wire.transactions.map(transaction),
            addressBook: (wire.addressBook ?? [:]).compactMapValues { $0.domain ?? $0.userFriendly }
        )
    }

    static func transaction(_ wire: Wire.WireTransaction) -> ChainTransaction {
        let description = wire.description
        // A tick_tock transaction's in_msg is an empty object, not an absent field.
        let inbound = (wire.inMsg?.isEmpty == false) ? wire.inMsg.map(message) : nil

        return ChainTransaction(
            account: wire.account,
            hash: hexHash(fromBase64: wire.hash) ?? "0x",
            logicalTime: wire.lt,
            now: wire.now,
            kind: TransactionKind(wire: description?.type),
            aborted: description?.aborted ?? false,
            exitCode: description?.computePhase?.exitCode,
            computeSkipReason: ComputeSkipReason(wire: description?.computePhase?.reason),
            totalFees: wire.totalFees,
            previousTransaction: {
                guard let lt = wire.prevTransLt, lt != "0",
                      let hash = hexHash(fromBase64: wire.prevTransHash) else { return nil }
                return TransactionID(logicalTime: lt, hash: hash)
            }(),
            traceID: wire.traceId,
            // Left nil when the server omits it, which is currently always.
            traceExternalHash: hexHash(fromBase64: wire.traceExternalHash),
            inMessage: inbound,
            outMessages: (wire.outMsgs ?? []).filter { !$0.isEmpty }.map(message)
        )
    }

    static func message(_ wire: Wire.WireMessage) -> ChainMessage {
        ChainMessage(
            hash: hexHash(fromBase64: wire.hash),
            normalizedHash: hexHash(fromBase64: wire.hashNorm),
            source: wire.source,
            destination: wire.destination,
            value: wire.value,
            forwardFee: wire.fwdFee,
            createdLogicalTime: wire.createdLt,
            opcode: wire.opcode,
            bounce: wire.bounce ?? false,
            bounced: wire.bounced ?? false,
            bodyBoc: wire.messageContent?.body,
            comment: wire.messageContent?.decoded?.comment,
            hasStateInit: wire.initState != nil
        )
    }
}
