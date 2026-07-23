//
//  JSValueConversionError.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 22.10.2025.
//
//  Copyright (c) 2025 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

enum JSValueConversionError: LocalizedError {
    case unableToConvertJSValue(type: Any.Type, description: String)
    case unableToConvertUndefinedJSValue(type: Any.Type)
    case unableToConvertNullJSValue(type: Any.Type)
    case unableToEncode(type: Any.Type)
    case decodingError(DecodingError)
    case encodingError(EncodingError)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .unableToConvertJSValue(let type, let description):
            return "Unable to cast JS value \(description) to \(type)"
        case .unableToConvertUndefinedJSValue(let type):
            return "Unable to cast undefined JS value to \(type)"
        case .unableToConvertNullJSValue(let type):
            return "Unable to cast null JS value to \(type)"
        case .unableToEncode(let type):
            return "Unable to encode \(type) to JSValue"
        case .unknown(let message):
            return message
        case .decodingError(let error):
            return safeDecodingErrorDescription(error)
        case .encodingError(let error):
            return error.localizedDescription
        }
    }
}

private func safeDecodingErrorDescription(_ error: DecodingError) -> String {
    let reason: String
    let codingPath: [CodingKey]
    switch error {
    case let .keyNotFound(key, context):
        reason = "key_not_found"
        codingPath = context.codingPath + [key]
    case let .typeMismatch(_, context):
        reason = "type_mismatch"
        codingPath = context.codingPath
    case let .valueNotFound(_, context):
        reason = "value_not_found"
        codingPath = context.codingPath
    case let .dataCorrupted(context):
        reason = "data_corrupted"
        codingPath = context.codingPath
    @unknown default:
        reason = "unknown"
        codingPath = []
    }
    return "TONWalletKit decoding \(reason) at \(safeCodingPath(codingPath))"
}

private func safeCodingPath(_ codingPath: [CodingKey]) -> String {
    if codingPath.isEmpty {
        return "root"
    }
    let safeKeys: Set<String> = [
        "transactions", "addressBook", "account", "accountStateBefore", "accountStateAfter",
        "description", "hash", "logicalTime", "now", "mcBlockSeqno", "traceExternalHash",
        "traceId", "previousTransactionHash", "previousTransactionLogicalTime", "origStatus",
        "endStatus", "totalFees", "totalFeesExtraCurrencies", "blockRef", "inMessage",
        "outMessages", "isEmulated", "balance", "extraCurrencies", "accountStatus",
        "frozenHash", "dataHash", "codeHash", "type", "isAborted", "isDestroyed",
        "isCreditFirst", "isTock", "isInstalled", "storagePhase", "creditPhase",
        "computePhase", "action", "storageFeesCollected", "statusChange", "credit",
        "isSkipped", "isSuccess", "isMessageStateUsed", "isAccountActivated", "gasFees",
        "gasUsed", "gasLimit", "gasCredit", "mode", "exitCode", "vmStepsNumber",
        "vmInitStateHash", "vmFinalStateHash", "isValid", "hasNoFunds",
        "totalForwardingFees", "totalActionFees", "resultCode", "totalActionsNumber",
        "specActionsNumber", "skippedActionsNumber", "messagesCreatedNumber", "actionListHash",
        "totalMessagesSize", "cells", "bits", "workchain", "shard", "seqno",
        "normalizedHash", "source", "destination", "value", "valueExtraCurrencies",
        "fwdFee", "creationLogicalTime", "createdAt", "opcode", "ihrDisabled", "ihrFee",
        "isBounce", "isBounced", "importFee", "messageContent", "body", "decoded",
        "address", "domain", "interfaces"
    ]
    var result = ""
    for key in codingPath {
        if let index = key.intValue {
            result.append("[\(index)]")
        } else {
            if !result.isEmpty {
                result.append(".")
            }
            result.append(safeKeys.contains(key.stringValue) ? key.stringValue : "field")
        }
    }
    return result
}
