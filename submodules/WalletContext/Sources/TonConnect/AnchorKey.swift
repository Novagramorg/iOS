import Foundation
import CryptoKit

@available(macOS 10.15, *)
enum TonConnectCryptoError: Error, Equatable {
    case invalidMnemonic
    case identityMismatch
    case invalidKey
    case invalidNonce
    case malformedCiphertext
    case authenticationFailed
    case messageTooLarge
    case invalidDerivation
    case randomGenerationFailed
}

@available(macOS 10.15, *)
enum TonConnectCryptoPrimitives {
    static func sha256(_ data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }

    static func sha512(_ data: Data) -> Data {
        return Data(SHA512.hash(data: data))
    }

    static func hmacSHA512(key: Data, data: Data) -> Data {
        return Data(HMAC<SHA512>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }
}

@available(macOS 10.15, *)
enum TonConnectKeyDerivation {
    /// One 64-byte PBKDF2 block, as required by BIP-39.
    static func pbkdf2SHA512(password: Data, salt: Data, iterations: Int) throws -> Data {
        guard iterations > 0, iterations <= 1_000_000, salt.count <= 1_048_576 else {
            throw TonConnectCryptoError.invalidDerivation
        }
        let key = SymmetricKey(data: password)
        var block = salt
        block.append(contentsOf: [0, 0, 0, 1])
        var digest = Array(HMAC<SHA512>.authenticationCode(for: block, using: key))
        var result = digest
        defer {
            digest.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) }
            result.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) }
        }
        for _ in 1..<iterations {
            digest = Array(HMAC<SHA512>.authenticationCode(for: digest, using: key))
            for index in result.indices {
                result[index] ^= digest[index]
            }
        }
        return Data(result)
    }

    /// Path elements are unhardened indices; every element is hardened here.
    static func slip0010(seed: Data, path: [UInt32]) throws -> (key: Data, chainCode: Data) {
        guard !seed.isEmpty, seed.count <= 1_048_576, path.count <= 255,
              path.allSatisfy({ $0 < 0x8000_0000 }) else {
            throw TonConnectCryptoError.invalidDerivation
        }
        var digest = TonConnectCryptoPrimitives.hmacSHA512(key: Data("ed25519 seed".utf8), data: seed)
        defer { digest.resetBytes(in: digest.startIndex..<digest.endIndex) }
        for index in path {
            var input = Data([0])
            input.append(digest.prefix(32))
            let hardened = index | 0x8000_0000
            input.append(contentsOf: [
                UInt8(truncatingIfNeeded: hardened >> 24), UInt8(truncatingIfNeeded: hardened >> 16),
                UInt8(truncatingIfNeeded: hardened >> 8), UInt8(truncatingIfNeeded: hardened)
            ])
            let next = TonConnectCryptoPrimitives.hmacSHA512(key: Data(digest.suffix(32)), data: input)
            input.resetBytes(in: input.startIndex..<input.endIndex)
            digest.resetBytes(in: digest.startIndex..<digest.endIndex)
            digest = next
        }
        return (Data(digest.prefix(32)), Data(digest.suffix(32)))
    }
}

/// Transient anchor material. The runtime must validate the complete rotation
/// mnemonic with wallet-engine before calling derive, then discard this object
/// at the end of protected access. Buffer resets are best effort: Swift and
/// CryptoKit may retain copies that this type cannot explicitly erase.
@available(macOS 10.15, *)
final class TonConnectAnchorKey {
    private var seed: Data
    let publicKey: Data

    private init(seed: Data, publicKey: Data) {
        self.seed = seed
        self.publicKey = publicKey
    }

    deinit {
        self.seed.resetBytes(in: self.seed.startIndex..<self.seed.endIndex)
    }

    static func derive(validatedRotationMnemonic: [String], expectedPublicKey: Data) throws -> TonConnectAnchorKey {
        guard validatedRotationMnemonic.count == 12 || validatedRotationMnemonic.count == 24 else {
            throw TonConnectCryptoError.invalidMnemonic
        }
        // NFKD matches BIP-39. Word membership/checksums are deliberately owned
        // by the existing engine adapter, not a second bundled word list.
        let words = validatedRotationMnemonic.map {
            $0.decomposedStringWithCompatibilityMapping.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard words.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 16 && $0.utf8.allSatisfy({ $0 >= 97 && $0 <= 122 }) }) else {
            throw TonConnectCryptoError.invalidMnemonic
        }
        guard expectedPublicKey.count == 32 else { throw TonConnectCryptoError.identityMismatch }
        var phrase = Data(words.prefix(12).joined(separator: " ").utf8)
        defer { phrase.resetBytes(in: phrase.startIndex..<phrase.endIndex) }
        var bip39Seed = try TonConnectKeyDerivation.pbkdf2SHA512(password: phrase, salt: Data("mnemonic".utf8), iterations: 2048)
        defer { bip39Seed.resetBytes(in: bip39Seed.startIndex..<bip39Seed.endIndex) }
        var node = try TonConnectKeyDerivation.slip0010(seed: bip39Seed, path: [44, 607, 0])
        defer {
            node.key.resetBytes(in: node.key.startIndex..<node.key.endIndex)
            node.chainCode.resetBytes(in: node.chainCode.startIndex..<node.chainCode.endIndex)
        }
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: node.key)
        let publicKey = signingKey.publicKey.rawRepresentation
        guard tonConnectConstantTimeEqual(publicKey, expectedPublicKey) else {
            throw TonConnectCryptoError.identityMismatch
        }
        return TonConnectAnchorKey(seed: node.key, publicKey: publicKey)
    }

    /// The closure must not persist or log its seed argument. Any values that
    /// escape the closure have their own lifetime and cannot be erased here.
    func withSeed<T>(_ body: (Data) throws -> T) rethrows -> T {
        var copy = self.seed
        defer { copy.resetBytes(in: copy.startIndex..<copy.endIndex) }
        return try body(copy)
    }

    func sign(_ message: Data) throws -> Data {
        return try Curve25519.Signing.PrivateKey(rawRepresentation: self.seed).signature(for: message)
    }
}

/// Accumulates every byte difference; only the public length check exits early.
@available(macOS 10.15, *)
func tonConnectConstantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
    guard lhs.count == rhs.count else { return false }
    return lhs.withUnsafeBytes { (left: UnsafeRawBufferPointer) in
        rhs.withUnsafeBytes { (right: UnsafeRawBufferPointer) in
            var difference: UInt8 = 0
            for index in 0..<left.count { difference |= left[index] ^ right[index] }
            return difference == 0
        }
    }
}
