import Foundation
import MtProtoKit
import SwiftSignalKit
import TelegramApi
import WalletBackupCrypto

private enum WalletPhraseCodec {
    private static let encodedLength = 215

    static func encode(words: [String]) -> Data? {
        let words = words
        .flatMap { value in
            value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        }
        .map { $0.lowercased() }
        guard !words.isEmpty else {
            return nil
        }
        guard var result = words.joined(separator: " ").data(using: .utf8), result.count <= encodedLength else {
            return nil
        }
        result.append(Data(repeating: 0x20, count: encodedLength - result.count))
        return result
    }

    static func decode(_ data: Data) -> [String]? {
        guard let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let words = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0).lowercased() }
        guard !words.isEmpty, encode(words: words) == data else {
            return nil
        }
        return words
    }
}

private func walletOperationError(_ error: MTRpcError, passwordProvided: Bool) -> WalletOperationError {
    let description = error.errorDescription ?? ""
    if description == "PASSWORD_HASH_INVALID" {
        return passwordProvided ? .invalidPassword : .requestPassword
    } else if description == "PASSWORD_MISSING" {
        return passwordProvided ? .twoStepAuthMissing : .requestPassword
    } else if description == "INTERNAL_NO_PASSWORD" || description == "NO_PASSWORD" {
        return .twoStepAuthMissing
    } else if description.hasPrefix("PASSWORD_TOO_FRESH_") {
        let value = description.dropFirst("PASSWORD_TOO_FRESH_".count)
        if let timeout = Int32(value) {
            return .passwordTooFresh(timeout)
        }
    } else if description.hasPrefix("SESSION_TOO_FRESH_") {
        let value = description.dropFirst("SESSION_TOO_FRESH_".count)
        if let timeout = Int32(value) {
            return .sessionTooFresh(timeout)
        }
    }
    switch description {
    case "WALLET_BACKUP_DISABLED":
        return .backupDisabled
    case "WALLET_BACKUP_NOT_AVAILABLE":
        return .backupNotAvailable
    case "WALLET_REPLACEMENT_INVALID":
        return .replacementInvalid
    case "WALLET_PUBLIC_KEY_INVALID":
        return .publicKeyInvalid
    case "WALLET_TOKEN_INVALID":
        return .tokenInvalid
    case "WALLET_TOKEN_EXPIRED":
        return .tokenExpired
    case "WALLET_CLIENT_KEY_INVALID":
        return .clientKeyInvalid
    case "WALLET_PART_UNAVAILABLE":
        return .partUnavailable
    case "WALLET_MNEMONIC_PARTS_INVALID":
        return .invalidBackupData
    default:
        if error.errorCode == 400 || error.errorCode == 406 {
            return .generic
        } else {
            return .network
        }
    }
}

private func walletPasswordProof(account: Account, password: String?) -> Signal<Api.InputCheckPasswordSRP?, WalletOperationError> {
    guard let password else {
        return .single(nil)
    }
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    return _internal_twoStepAuthData(account.network)
    |> mapError { error in
        return walletOperationError(error, passwordProvided: true)
    }
    |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP?, WalletOperationError> in
        guard let derivation = authData.currentPasswordDerivation,
              let sessionData = authData.srpSessionData else {
            return .fail(.twoStepAuthMissing)
        }
        guard let result = passwordKDF(
            encryptionProvider: account.network.encryptionProvider,
            password: password,
            derivation: derivation,
            srpSessionData: sessionData
        ) else {
            return .fail(.generic)
        }
        return .single(.inputCheckPasswordSRP(.init(
            srpId: result.id,
            A: Buffer(data: result.A),
            M1: Buffer(data: result.M1)
        )))
    }
}

func _internal_replaceWallet(
    account: Account,
    replacement: WalletReplacement,
    password: String?
) -> Signal<WalletState, WalletOperationError> {
    let apiReplacement: Api.InputWalletReplacement
    switch replacement {
    case .new:
        apiReplacement = .inputWalletNew
    case let .imported(publicKey):
        guard publicKey.count == 32 else {
            return .fail(.publicKeyInvalid)
        }
        apiReplacement = .inputWalletImported(.init(publicKey: Buffer(data: publicKey)))
    }
    return walletPasswordProof(account: account, password: password)
    |> mapToSignal { proof -> Signal<WalletState, WalletOperationError> in
        let flags: Int32 = proof == nil ? 0 : (1 << 0)
        return account.network.request(
            Api.functions.wallet.replaceWallet(flags: flags, wallet: apiReplacement, password: proof),
            automaticFloodWait: false
        )
        |> mapError { error in
            return walletOperationError(error, passwordProvided: password != nil)
        }
        |> map(WalletState.init(apiState:))
    }
}

func _internal_disableWalletBackup(
    account: Account,
    password: String?
) -> Signal<WalletState, WalletOperationError> {
    return walletPasswordProof(account: account, password: password)
    |> mapToSignal { proof -> Signal<WalletState, WalletOperationError> in
        let flags: Int32 = proof == nil ? 0 : (1 << 0)
        return account.network.request(
            Api.functions.wallet.disableBackup(flags: flags, password: proof),
            automaticFloodWait: false
        )
        |> mapError { error in
            return walletOperationError(error, passwordProvided: password != nil)
        }
        |> map(WalletState.init(apiState:))
    }
}

private struct WalletBackupHolder {
    let datacenterId: Int32
    let publicKey: Data
}

private func parseBackupHolders(_ holders: [Api.wallet.HolderDc]) -> [WalletBackupHolder]? {
    var result: [WalletBackupHolder] = []
    var datacenterIds = Set<Int32>()
    for holder in holders {
        switch holder {
        case let .holderDc(holder):
            let publicKey = holder.publicKey.makeData()
            guard publicKey.count == 32, datacenterIds.insert(holder.dc).inserted else {
                return nil
            }
            result.append(WalletBackupHolder(datacenterId: holder.dc, publicKey: publicKey))
        }
    }
    return result.count == 3 ? result : nil
}

func _internal_enableWalletBackup(
    account: Account,
    words: [String],
    password: String?
) -> Signal<WalletState, WalletOperationError> {
    guard let secret = WalletPhraseCodec.encode(words: words) else {
        return .fail(.invalidBackupData)
    }
    return account.network.request(Api.functions.wallet.getBackupHolderDcs(), automaticFloodWait: false)
    |> mapError { error in
        return walletOperationError(error, passwordProvided: password != nil)
    }
    |> mapToSignal { holders -> Signal<[Data], WalletOperationError> in
        guard let holders = parseBackupHolders(holders) else {
            return .fail(.invalidBackupData)
        }
        guard let parts = WalletBackupCrypto.encryptSecretForBackup(
            secret,
            holderPublicKeys: holders.map(\.publicKey)
        ) else {
            return .fail(.invalidBackupData)
        }
        return .single(parts)
    }
    |> mapToSignal { parts -> Signal<WalletState, WalletOperationError> in
        return walletPasswordProof(account: account, password: password)
        |> mapToSignal { proof -> Signal<WalletState, WalletOperationError> in
            let flags: Int32 = proof == nil ? 0 : (1 << 0)
            return account.network.request(
                Api.functions.wallet.enableBackup(
                    flags: flags,
                    parts: parts.map { Buffer(data: $0) },
                    password: proof
                ),
                automaticFloodWait: false
            )
            |> mapError { error in
                return walletOperationError(error, passwordProvided: password != nil)
            }
            |> map(WalletState.init(apiState:))
        }
    }
}

private func fetchWalletSecretPhrasePart(
    account: Account,
    datacenterId: Int32,
    token: String,
    publicKey: Data
) -> Signal<Data, WalletOperationError> {
    let request = Api.functions.wallet.fetchEncryptedSecretPhrasePart(
        token: token,
        publicKey: Buffer(data: publicKey)
    )
    let targetDatacenterId = Int(datacenterId)
    let signal: Signal<Api.wallet.EncryptedSecretPhrasePart, MTRpcError>
    if account.network.datacenterId == targetDatacenterId {
        signal = account.network.request(request, automaticFloodWait: false)
    } else {
        signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
        |> castError(MTRpcError.self)
        |> mapToSignal { worker in
            return worker.request(request, automaticFloodWait: false)
        }
    }
    return signal
    |> mapError { error in
        return walletOperationError(error, passwordProvided: false)
    }
    |> map { part -> Data in
        switch part {
        case let .encryptedSecretPhrasePart(part):
            return part.data.makeData()
        }
    }
}

private func shouldRetryWalletPhraseExport(_ error: WalletOperationError) -> Bool {
    switch error {
    case .network, .tokenInvalid, .tokenExpired, .clientKeyInvalid, .partUnavailable, .invalidBackupData:
        return true
    default:
        return false
    }
}

private func exportWalletSecretPhraseAttempt(
    account: Account,
    password: String?,
    retryFetchFailure: Bool
) -> Signal<[String], WalletOperationError> {
    return walletPasswordProof(account: account, password: password)
    |> mapToSignal { proof -> Signal<[String], WalletOperationError> in
        let flags: Int32 = proof == nil ? 0 : (1 << 0)
        return account.network.request(
            Api.functions.wallet.exportSecretPhrase(flags: flags, password: proof),
            automaticFloodWait: false
        )
        |> mapError { error in
            return walletOperationError(error, passwordProvided: password != nil)
        }
        |> mapToSignal { phraseParts -> Signal<[String], WalletOperationError> in
            let token: String
            let datacenterIds: [Int32]
            switch phraseParts {
            case let .secretPhraseParts(parts):
                token = parts.token
                datacenterIds = parts.dcs
            }
            guard datacenterIds.count == 3, Set(datacenterIds).count == 3 else {
                return .fail(.invalidBackupData)
            }
            guard let keyPair = WalletBackupCryptoKeyPair.generateKeyPair() else {
                return .fail(.invalidBackupData)
            }
            let fetch = combineLatest(
                fetchWalletSecretPhrasePart(account: account, datacenterId: datacenterIds[0], token: token, publicKey: keyPair.publicKey),
                fetchWalletSecretPhrasePart(account: account, datacenterId: datacenterIds[1], token: token, publicKey: keyPair.publicKey),
                fetchWalletSecretPhrasePart(account: account, datacenterId: datacenterIds[2], token: token, publicKey: keyPair.publicKey)
            )
            |> mapToSignal { first, second, third -> Signal<[String], WalletOperationError> in
                guard let secret = keyPair.decryptAndCombineBackupEnvelopes([first, second, third]),
                      let words = WalletPhraseCodec.decode(secret) else {
                    return .fail(.invalidBackupData)
                }
                return .single(words)
            }
            return fetch
            |> `catch` { error -> Signal<[String], WalletOperationError> in
                guard retryFetchFailure, shouldRetryWalletPhraseExport(error) else {
                    return .fail(error)
                }
                return exportWalletSecretPhraseAttempt(
                    account: account,
                    password: password,
                    retryFetchFailure: false
                )
            }
        }
    }
}

func _internal_exportWalletSecretPhrase(
    account: Account,
    password: String?
) -> Signal<[String], WalletOperationError> {
    return exportWalletSecretPhraseAttempt(account: account, password: password, retryFetchFailure: true)
}
