import Foundation
import WalletEngineFFI

@available(macOS 10.15, *)
func walletMnemonicSigningPublicKey(words: [String]) throws -> Data {
    var words = normalizedEngineMnemonic(words)
    defer { words.removeAll(keepingCapacity: false) }
    do {
        _ = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
        return try rotationMnemonicPublicKey(phrase: words.suffix(12).joined(separator: " "))
    } catch {
        throw WalletContext.WalletError.invalidMnemonic
    }
}

@available(macOS 10.15, *)
func walletOwnershipProofSignature(
    words: [String],
    expectedAnchorPublicKey: Data,
    expectedSigningPublicKey: Data,
    address: String,
    domain: String,
    timestamp: UInt64,
    payload: String
) throws -> Data {
    guard expectedAnchorPublicKey.count == 32, expectedSigningPublicKey.count == 32 else {
        throw WalletContext.WalletError.storage(.identityMismatch)
    }
    var words = normalizedEngineMnemonic(words)
    defer { words.removeAll(keepingCapacity: false) }
    let anchorPublicKey: Data
    let signingPublicKey: Data
    do {
        anchorPublicKey = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
        signingPublicKey = try rotationMnemonicPublicKey(phrase: words.suffix(12).joined(separator: " "))
    } catch {
        throw WalletContext.WalletError.invalidMnemonic
    }
    guard anchorPublicKey == expectedAnchorPublicKey,
          signingPublicKey == expectedSigningPublicKey else {
        throw WalletContext.WalletError.storage(.identityMismatch)
    }
    let digest = try walletOwnershipProofDigest(address: address, domain: domain, timestamp: timestamp, payload: payload)
    do {
        let key = try TonConnectAnchorKey.derive(
            validatedRotationMnemonic: Array(words.suffix(12)),
            expectedPublicKey: expectedSigningPublicKey
        )
        let signature = try key.sign(digest)
        guard signature.count == 64 else {
            throw WalletContext.WalletError.proofInvalid
        }
        return signature
    } catch {
        throw WalletContext.WalletError.proofInvalid
    }
}

@available(macOS 10.15, *)
func walletOwnershipProofDigest(address: String, domain: String, timestamp: UInt64, payload: String) throws -> Data {
    guard !domain.isEmpty, let domainLength = UInt32(exactly: domain.utf8.count), timestamp > 0,
          let address = try? parseTonAddress(value: address) else {
        throw WalletContext.WalletError.proofInvalid
    }
    let parts = address.raw.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[1].utf8.count == 64 else {
        throw WalletContext.WalletError.proofInvalid
    }
    let hex = Array(parts[1].utf8)
    var addressHash = Data()
    for offset in stride(from: 0, to: hex.count, by: 2) {
        guard let byte = UInt8(String(decoding: hex[offset ..< offset + 2], as: UTF8.self), radix: 16) else {
            throw WalletContext.WalletError.proofInvalid
        }
        addressHash.append(byte)
    }

    var message = Data("ton-proof-item-v2/".utf8)
    let workchain = UInt32(bitPattern: address.workchain)
    for shift in [24, 16, 8, 0] {
        message.append(UInt8(truncatingIfNeeded: workchain >> shift))
    }
    message.append(addressHash)
    for shift in [0, 8, 16, 24] {
        message.append(UInt8(truncatingIfNeeded: domainLength >> shift))
    }
    message.append(contentsOf: domain.utf8)
    for shift in stride(from: 0, to: 64, by: 8) {
        message.append(UInt8(truncatingIfNeeded: timestamp >> shift))
    }
    message.append(contentsOf: payload.utf8)

    var wrapped = Data([0xff, 0xff])
    wrapped.append(contentsOf: "ton-connect".utf8)
    wrapped.append(TonConnectCryptoPrimitives.sha256(message))
    return TonConnectCryptoPrimitives.sha256(wrapped)
}
