import Foundation
import SwiftSignalKit
import TelegramCore
import WalletBackupCrypto
import WalletEngineFFI

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

func enableWalletBackup(
    engine: TelegramEngine,
    words: [String],
    password: String?
) async throws -> TelegramCore.WalletState {
    guard let secret = WalletPhraseCodec.encode(words: words) else {
        throw WalletContext.WalletError.invalidBackupData
    }
    let holders = try await WalletSignalRequestContext<[TelegramCore.WalletBackupHolder]>().run(
        engine.wallet.getBackupHolders()
    )
    guard let parts = WalletBackupCrypto.encryptSecretForBackup(
        secret,
        holderPublicKeys: holders.map(\.publicKey)
    ) else {
        throw WalletContext.WalletError.invalidBackupData
    }
    return try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
        engine.wallet.enableBackup(encryptedParts: parts, password: password)
    )
}

private func shouldRetryWalletPhraseExport(_ error: TelegramCore.WalletOperationError) -> Bool {
    switch error {
    case .network, .tokenInvalid, .tokenExpired, .clientKeyInvalid, .partUnavailable, .invalidBackupData:
        return true
    default:
        return false
    }
}

private func exportWalletSecretPhraseAttempt(
    engine: TelegramEngine,
    password: String?,
    expectedPublicKey: Data,
    retryFetchFailure: Bool
) -> Signal<[String], TelegramCore.WalletOperationError> {
    return engine.wallet.requestSecretPhraseExport(password: password)
    |> mapToSignal { phraseExport -> Signal<[String], TelegramCore.WalletOperationError> in
        guard let keyPair = WalletBackupCryptoKeyPair.generateKeyPair() else {
            return .fail(.invalidBackupData)
        }
        let datacenterIds = phraseExport.datacenterIds
        let fetch = combineLatest(
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[0],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            ),
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[1],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            ),
            engine.wallet.fetchEncryptedSecretPhrasePart(
                datacenterId: datacenterIds[2],
                token: phraseExport.token,
                publicKey: keyPair.publicKey
            )
        )
        |> mapToSignal { first, second, third -> Signal<[String], TelegramCore.WalletOperationError> in
            guard let secret = keyPair.decryptAndCombineBackupEnvelopes([first, second, third]),
                  let words = WalletPhraseCodec.decode(secret) else {
                return .fail(.invalidBackupData)
            }
            do {
                let publicKey = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
                guard expectedPublicKey.count == 32,
                      publicKey.count == 32,
                      Data(publicKey) == expectedPublicKey else {
                    return .fail(.invalidBackupData)
                }
            } catch {
                return .fail(.invalidBackupData)
            }
            return .single(words)
        }
        return fetch
        |> `catch` { error -> Signal<[String], TelegramCore.WalletOperationError> in
            guard retryFetchFailure, shouldRetryWalletPhraseExport(error) else {
                return .fail(error)
            }
            return exportWalletSecretPhraseAttempt(
                engine: engine,
                password: password,
                expectedPublicKey: expectedPublicKey,
                retryFetchFailure: false
            )
        }
    }
}

func exportWalletSecretPhrase(
    engine: TelegramEngine,
    password: String?,
    expectedPublicKey: Data
) async throws -> [String] {
    return try await WalletSignalRequestContext<[String]>().run(
        exportWalletSecretPhraseAttempt(
            engine: engine,
            password: password,
            expectedPublicKey: expectedPublicKey,
            retryFetchFailure: true
        )
    )
}
