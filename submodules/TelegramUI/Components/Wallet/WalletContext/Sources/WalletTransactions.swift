import Foundation
import TONWalletKit

let walletTransactionFetchLimit = 30
let walletPreparedTransferLifetime: TimeInterval = 5.0 * 60.0
let walletUsdtJettonMasterAddress = "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"

struct ResolvedTransferInput {
    let address: String
    let amount: Int64
    let comment: String?
}

func resolveTransferInput(address: String, amount: Int64, comment: String?) throws -> ResolvedTransferInput {
    var resolvedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
    var resolvedAmount = amount
    var resolvedComment = nonEmptyString(comment?.trimmingCharacters(in: .whitespacesAndNewlines))

    if let components = URLComponents(string: resolvedAddress), components.scheme?.lowercased() == "ton" {
        guard components.host?.lowercased() == "transfer" else {
            throw WalletContext.WalletError.invalidAddress
        }
        resolvedAddress = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if resolvedAmount <= 0,
           let value = components.queryItems?.first(where: { $0.name == "amount" })?.value,
           let parsed = Int64(value) {
            resolvedAmount = parsed
        }
        if resolvedComment == nil {
            resolvedComment = nonEmptyString(components.queryItems?.first(where: { $0.name == "text" })?.value)
        }
    }
    guard resolvedAmount > 0 else {
        throw WalletContext.WalletError.invalidAmount
    }
    guard let canonicalAddress = canonicalNonBounceableTonAddress(resolvedAddress) else {
        throw WalletContext.WalletError.invalidAddress
    }
    return ResolvedTransferInput(address: canonicalAddress, amount: resolvedAmount, comment: resolvedComment)
}

func previewFee<S: Sequence>(_ transactions: S) throws -> Int64 where S.Element == TONTransaction {
    var result: Int64 = 0
    for transaction in transactions {
        guard let fee = transaction.totalFees else {
            continue
        }
        guard let value = int64Amount(fee) else {
            throw WalletContext.WalletError.previewFailed
        }
        let (sum, overflow) = result.addingReportingOverflow(value)
        guard !overflow else {
            throw WalletContext.WalletError.previewFailed
        }
        result = sum
    }
    return result
}

func int64Amount(_ amount: TONTokenAmount) -> Int64? {
    return Int64(String(amount.nanoUnits))
}

enum WalletDataError: Error {
    case invalidData
}

private struct WalletUsdtTransfer {
    let direction: WalletContext.Transaction.Direction
    let amount: Int64
    let counterparty: String?
    let comment: String?
}

func walletTransactions(
    from transactions: [TONTransaction],
    usdtJettonWalletRawAddress: TONRawAddress?
) throws -> [WalletContext.Transaction] {
    var result: [WalletContext.Transaction] = []
    result.reserveCapacity(transactions.count)
    for transaction in transactions {
        let fee: Int64
        if let totalFees = transaction.totalFees {
            guard let value = int64Amount(totalFees) else {
                throw WalletContext.WalletError.sdk("Transaction fee is outside Int64 range")
            }
            fee = value
        } else {
            fee = 0
        }

        let incomingValue = transaction.inMessage?.value.flatMap(int64Amount)
        let outgoing = transaction.outMessages.first { message in
            guard let value = message.value.flatMap(int64Amount) else {
                return false
            }
            return value != 0
        }
        let direction: WalletContext.Transaction.Direction
        let amount: Int64
        let counterparty: String?
        let comment: String?
        let currency: WalletContext.Transaction.Currency
        if let usdtTransfer = walletUsdtTransfer(
            transaction: transaction,
            usdtJettonWalletRawAddress: usdtJettonWalletRawAddress
        ) {
            direction = usdtTransfer.direction
            amount = usdtTransfer.amount
            counterparty = usdtTransfer.counterparty
            comment = usdtTransfer.comment
            currency = .usdt
        } else if let message = transaction.inMessage, let incomingValue, incomingValue != 0 {
            direction = .incoming
            amount = incomingValue
            counterparty = message.source.map { canonicalNonBounceableTonAddress($0.value) ?? $0.value }
            comment = transactionComment(message.messageContent)
            currency = .ton
        } else if let outgoing, let outgoingValue = outgoing.value.flatMap(int64Amount) {
            direction = .outgoing
            amount = outgoingValue
            counterparty = outgoing.destination.map { canonicalNonBounceableTonAddress($0.value) ?? $0.value }
            comment = transactionComment(outgoing.messageContent)
            currency = .ton
        } else {
            direction = .unknown
            amount = 0
            counterparty = nil
            comment = nil
            currency = .ton
        }
        guard transaction.now.isFinite,
              transaction.now >= Double(Int32.min),
              transaction.now <= Double(Int32.max) else {
            throw WalletDataError.invalidData
        }
        result.append(WalletContext.Transaction(
            id: transaction.hash.value,
            logicalTime: transaction.logicalTime,
            timestamp: Int32(transaction.now),
            direction: direction,
            amount: amount,
            fee: fee,
            counterparty: counterparty,
            comment: comment,
            currency: currency
        ))
    }
    return result
}

private func walletUsdtTransfer(
    transaction: TONTransaction,
    usdtJettonWalletRawAddress: TONRawAddress?
) -> WalletUsdtTransfer? {
    guard let usdtJettonWalletRawAddress else {
        return nil
    }

    if let message = transaction.outMessages.first(where: {
        $0.destination?.raw == usdtJettonWalletRawAddress
    }), let payload = transactionDecodedPayload(message.messageContent),
       isJettonPayload(payload, opcode: message.opcode, type: "jetton_transfer", opcodeValue: "0x0f8a7ea5"),
       let amount = decodedInt64(payload["amount"]), amount > 0 {
        return WalletUsdtTransfer(
            direction: .outgoing,
            amount: amount,
            counterparty: decodedTonAddress(payload["destination"]),
            comment: decodedComment(payload)
        )
    }

    if let message = transaction.inMessage,
       message.source?.raw == usdtJettonWalletRawAddress,
       let payload = transactionDecodedPayload(message.messageContent),
       isJettonPayload(payload, opcode: message.opcode, type: "jetton_notify", opcodeValue: "0x7362d09c"),
       let amount = decodedInt64(payload["amount"]), amount > 0 {
        return WalletUsdtTransfer(
            direction: .incoming,
            amount: amount,
            counterparty: decodedTonAddress(payload["sender"]),
            comment: decodedComment(payload)
        )
    }

    return nil
}

private func transactionDecodedPayload(_ content: TONTransactionMessageContent?) -> [String: Any]? {
    guard let value = content?.decoded?.value,
          let values = decodedDictionary(value) else {
        return nil
    }
    if decodedString(values["@type"]) != nil {
        return values
    }
    if let nested = decodedDictionary(values["value"]), decodedString(nested["@type"]) != nil {
        return nested
    }
    return values
}

private func isJettonPayload(
    _ payload: [String: Any],
    opcode: String?,
    type: String,
    opcodeValue: String
) -> Bool {
    if decodedString(payload["@type"])?.lowercased() == type {
        return true
    }
    return opcode?.lowercased() == opcodeValue
}

private func decodedDictionary(_ value: Any?) -> [String: Any]? {
    let value = decodedValue(value)
    if let values = value as? [String: AnyCodable] {
        var result: [String: Any] = [:]
        for (key, value) in values {
            if let value = decodedValue(value) {
                result[key] = value
            }
        }
        return result
    }
    return value as? [String: Any]
}

private func decodedValue(_ value: Any?) -> Any? {
    if let value = value as? AnyCodable {
        return decodedValue(value.value)
    }
    return value
}

func decodedString(_ value: Any?) -> String? {
    let value = decodedValue(value)
    if let value = value as? String {
        return value
    }
    if let value = value as? NSNumber {
        return value.stringValue
    }
    return nil
}

private func decodedInt64(_ value: Any?) -> Int64? {
    let value = decodedValue(value)
    if let values = decodedDictionary(value), let nestedValue = values["value"] {
        return decodedInt64(nestedValue)
    }
    if let value = value as? String {
        return Int64(value)
    }
    if let value = value as? NSNumber {
        let doubleValue = value.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded(.towardZero) == doubleValue,
              doubleValue >= Double(Int64.min),
              doubleValue <= Double(Int64.max) else {
            return nil
        }
        return value.int64Value
    }
    return nil
}

private func decodedTonAddress(_ value: Any?) -> String? {
    let value = decodedValue(value)
    if let value = value as? String {
        return canonicalNonBounceableTonAddress(value)
            ?? canonicalNonBounceableTonAddress("0:\(value)")
    }
    guard let values = decodedDictionary(value),
          let address = decodedString(values["address"]) else {
        return nil
    }
    if let workchain = decodedString(values["workchain_id"] ?? values["workchain"]),
       let result = canonicalNonBounceableTonAddress("\(workchain):\(address)") {
        return result
    }
    return canonicalNonBounceableTonAddress(address)
}

private func decodedComment(_ payload: [String: Any]) -> String? {
    if let comment = nonEmptyString(decodedString(payload["comment"])) {
        return comment
    }
    if let text = nonEmptyString(decodedString(payload["text"])) {
        return text
    }
    if let forwardPayload = decodedDictionary(payload["forward_payload"]) {
        if let value = decodedDictionary(forwardPayload["value"]) {
            return decodedComment(value)
        }
        return decodedComment(forwardPayload)
    }
    return nil
}

private func transactionComment(_ content: TONTransactionMessageContent?) -> String? {
    guard let payload = transactionDecodedPayload(content) else {
        return nil
    }
    return decodedComment(payload)
}

func mergeTransactions(
    existing: [WalletContext.Transaction],
    new: [WalletContext.Transaction]
) -> [WalletContext.Transaction] {
    var transactionsByKey: [String: WalletContext.Transaction] = [:]
    transactionsByKey.reserveCapacity(existing.count + new.count)
    for transaction in existing {
        transactionsByKey[transactionKey(transaction)] = transaction
    }
    for transaction in new {
        transactionsByKey[transactionKey(transaction)] = transaction
    }
    return transactionsByKey.values.sorted { lhs, rhs in
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        return logicalTimeIsGreater(lhs.logicalTime, than: rhs.logicalTime)
    }
}

func transactionKey(_ transaction: WalletContext.Transaction) -> String {
    return transactionHashKey(transaction.id)
}

func transactionHashKey(_ value: String) -> String {
    return value.lowercased()
}

func transactionTraceKey(_ value: String) -> String {
    return value.lowercased()
}

private func logicalTimeIsGreater(_ lhs: String, than rhs: String) -> Bool {
    guard let normalizedLhs = normalizedUnsignedDecimal(lhs),
          let normalizedRhs = normalizedUnsignedDecimal(rhs) else {
        return lhs > rhs
    }
    if normalizedLhs.count != normalizedRhs.count {
        return normalizedLhs.count > normalizedRhs.count
    }
    return normalizedLhs > normalizedRhs
}

private func normalizedUnsignedDecimal(_ value: String) -> String? {
    let bytes = Array(value.utf8)
    guard !bytes.isEmpty, bytes.allSatisfy({ (48 ... 57).contains($0) }) else {
        return nil
    }
    let firstNonZero = bytes.firstIndex(where: { $0 != 48 }) ?? bytes.count
    if firstNonZero == bytes.count {
        return "0"
    }
    return String(decoding: bytes[firstNonZero...], as: UTF8.self)
}

private func nonEmptyString(_ value: String?) -> String? {
    guard let value, !value.isEmpty else {
        return nil
    }
    return value
}
