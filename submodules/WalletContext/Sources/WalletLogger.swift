import Foundation
import TelegramCore
import WalletEngineFFI

final class WalletLogger: @unchecked Sendable {
    private let sink: (String) -> Void

    init(_ sink: @escaping (String) -> Void) {
        self.sink = sink
    }

    func log(_ message: String) {
        self.sink(message)
    }

    func error(_ event: String, _ error: Error, context: String? = nil) {
        var message = "event=\(event) \(walletContextErrorFields(error))"
        if let context, !context.isEmpty {
            message += " \(context)"
        }
        self.sink(message)
    }
}

private func walletContextErrorFields(_ error: Error) -> String {
    let nsError = error as NSError
    var result = "error_type=\(String(reflecting: type(of: error))) error_domain=\(nsError.domain) error_code=\(nsError.code)"
    if let kind = walletContextErrorKind(error) {
        result += " error_kind=\(kind)"
    }
    return result
}

private func walletContextErrorKind(_ error: Error) -> String? {
    if error is CancellationError {
        return "cancelled"
    }
    if let error = error as? TelegramCore.WalletOperationError {
        switch error {
        case .generic: return "telegram_generic"
        case .network: return "telegram_network"
        case .preflightNetwork: return "telegram_preflight_network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .proofInvalid: return "proof_invalid"
        case .proofExpired: return "proof_expired"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        }
    }
    if let error = error as? WalletEngineStorageError {
        switch error {
        case .keychainStatus: return "keychain_status"
        case .corrupted: return "storage_corrupted"
        }
    }
    if let error = error as? WalletClientError {
        return "wallet_engine_\(walletEngineErrorCaseName(error))"
    }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return "unavailable"
        case .noWallet: return "no_wallet"
        case .invalidMnemonic: return "invalid_mnemonic"
        case .invalidAddress: return "invalid_address"
        case .invalidAmount: return "invalid_amount"
        case .operationInProgress: return "operation_in_progress"
        case .previewFailed: return "preview_failed"
        case .previewIncomplete: return "preview_incomplete"
        case .preparedTransferExpired: return "prepared_transfer_expired"
        case .preparedTransferNotFound: return "prepared_transfer_not_found"
        case .network: return "network"
        case .requestPassword: return "request_password"
        case .invalidPassword: return "invalid_password"
        case .twoStepAuthMissing: return "two_step_auth_missing"
        case .authorizationCancelled: return "authorization_cancelled"
        case .passwordTooFresh: return "password_too_fresh"
        case .sessionTooFresh: return "session_too_fresh"
        case .backupDisabled: return "backup_disabled"
        case .backupNotAvailable: return "backup_not_available"
        case .replacementInvalid: return "replacement_invalid"
        case .publicKeyInvalid: return "public_key_invalid"
        case .proofInvalid: return "proof_invalid"
        case .proofExpired: return "proof_expired"
        case .keyRotationFailed: return "key_rotation_failed"
        case .commentTooLong: return "comment_too_long"
        case .commentEncryptionRecipientUnavailable: return "comment_encryption_recipient_unavailable"
        case .commentEncryptionFailed: return "comment_encryption_failed"
        case .commentDecryptionFailed: return "comment_decryption_failed"
        case .tokenInvalid: return "token_invalid"
        case .tokenExpired: return "token_expired"
        case .clientKeyInvalid: return "client_key_invalid"
        case .partUnavailable: return "part_unavailable"
        case .invalidBackupData: return "invalid_backup_data"
        case .insufficientBalance: return "insufficient_balance"
        case .storage: return "storage"
        case .engine: return "engine"
        }
    }
    if let error = error as? TonApiRequestError {
        return "telegram_relay_\(error.code)"
    }
    if let error = error as? URLError {
        return "url_\(error.code.rawValue)"
    }
    return nil
}

private func walletEngineErrorCaseName(_ error: WalletClientError) -> String {
    if case .SendAlreadyInProgress = error {
        return "send_already_in_progress"
    }
    if case .SendPreviewAlreadyInProgress = error {
        return "send_preview_already_in_progress"
    }
    let reflected = String(reflecting: error)
    let withoutPayload = reflected.split(separator: "(", maxSplits: 1).first.map(String.init) ?? reflected
    let name = withoutPayload.split(separator: ".").last.map(String.init) ?? withoutPayload
    var result = ""
    for scalar in name.unicodeScalars {
        if CharacterSet.uppercaseLetters.contains(scalar) {
            if !result.isEmpty {
                result.append("_")
            }
            result.append(String(scalar).lowercased())
        } else if CharacterSet.alphanumerics.contains(scalar) {
            result.append(String(scalar).lowercased())
        } else if result.last != "_" {
            result.append("_")
        }
    }
    return result.isEmpty ? "unknown" : result
}

func synchronizationError(_ error: DomainError?) -> WalletContext.SynchronizationError {
    guard let error else { return .engine }
    switch error.code {
    case .invalidProviderResponse, .responseTooLarge, .hostPolicyViolation:
        return .invalidData
    case .hostCancelled:
        return .unavailable
    case .rateLimited:
        return .http(statusCode: error.providerStatus.map { Int($0) } ?? 429)
    case .httpRejected:
        return error.providerStatus.map { .http(statusCode: Int($0)) } ?? .network
    case .transportFailed:
        return error.hostKind == .timeout ? .timeout : .network
    }
}

func synchronizationError(_ error: Error?) -> WalletContext.SynchronizationError {
    guard let error else { return .engine }
    if let error = error as? WalletContext.SynchronizationError { return error }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable: return .unavailable
        case .network: return .network
        case .invalidAddress, .invalidAmount, .invalidMnemonic, .previewIncomplete, .previewFailed: return .invalidData
        default: return .engine
        }
    }
    if let error = error as? URLError {
        return error.code == .timedOut ? .timeout : .network
    }
    return .engine
}

func walletError(_ error: Error) -> WalletContext.WalletError {
    if let value = error as? WalletContext.WalletError { return value }
    if let value = error as? WalletContext.SynchronizationError {
        switch value {
        case .network, .timeout, .http: return .network
        case .unavailable: return .unavailable
        case .invalidData: return .engine("wallet-engine returned invalid resource data")
        case .engine: return .engine("wallet-engine resource update failed")
        }
    }
    if let value = error as? TelegramCore.WalletOperationError {
        switch value {
        case .generic: return .unavailable
        case .network: return .network
        case .preflightNetwork: return .network
        case .requestPassword: return .requestPassword
        case .invalidPassword: return .invalidPassword
        case .twoStepAuthMissing: return .twoStepAuthMissing
        case let .passwordTooFresh(timeout): return .passwordTooFresh(timeout)
        case let .sessionTooFresh(timeout): return .sessionTooFresh(timeout)
        case .backupDisabled: return .backupDisabled
        case .backupNotAvailable: return .backupNotAvailable
        case .replacementInvalid: return .replacementInvalid
        case .publicKeyInvalid: return .publicKeyInvalid
        case .proofInvalid: return .proofInvalid
        case .proofExpired: return .proofExpired
        case .tokenInvalid: return .tokenInvalid
        case .tokenExpired: return .tokenExpired
        case .clientKeyInvalid: return .clientKeyInvalid
        case .partUnavailable: return .partUnavailable
        case .invalidBackupData: return .invalidBackupData
        }
    }
    if error is URLError || error is TonApiRequestError { return .network }
    return .engine(sanitizedWalletEngineDiagnostic(String(describing: error)))
}
