import Foundation

/// Standard BIP-39 mnemonics, plus SLIP-0010 ed25519 derivation.
///
/// The second mnemonic scheme walletkit supports. Distinct from ``Mnemonic``: BIP-39
/// stretches the *phrase* with 2048 rounds and the salt `"mnemonic" + passphrase`,
/// then TON derives along path `m/44'/607'/0'`.
public enum BIP39 {
    static let iterations = 2048
    static let saltPrefix = "mnemonic"

    /// TON's derivation path. All indices are hardened.
    public static let tonDerivationPath: [UInt32] = [44, 607, 0]

    /// BIP-39 seed: PBKDF2-SHA512 over the NFKD-normalized phrase.
    public static func seed(from words: [String], passphrase: String = "") throws -> Data {
        let phrase = words.joined(separator: " ").decomposedStringWithCompatibilityMapping
        let salt = (saltPrefix + passphrase).decomposedStringWithCompatibilityMapping
        return try Hashing.pbkdf2SHA512(
            password: Data(phrase.utf8),
            salt: Data(salt.utf8),
            iterations: iterations,
            keyLength: 64
        )
    }

    /// Derives the TON key pair from a BIP-39 mnemonic.
    public static func keyPair(from words: [String], passphrase: String = "") throws -> KeyPair {
        let seedBytes = try seed(from: words, passphrase: passphrase)
        let derived = try SLIP10.deriveEd25519Path(seed: seedBytes, path: tonDerivationPath)
        return try Ed25519.keyPair(fromSeed: Data(derived.key.prefix(32)))
    }
}

/// SLIP-0010 hardened derivation for ed25519.
///
/// Only hardened derivation exists for ed25519, so every index is implicitly offset by
/// 2^31 — callers pass unhardened indices.
public enum SLIP10 {
    static let curveSeed = "ed25519 seed"
    static let hardenedOffset: UInt32 = 0x8000_0000

    public struct ExtendedKey: Hashable, Sendable {
        public let key: Data
        public let chainCode: Data
    }

    public enum SLIP10Error: Error, CustomStringConvertible {
        case indexAlreadyHardened(UInt32)

        public var description: String {
            switch self {
            case .indexAlreadyHardened(let i):
                return "Index \(i) must be below the hardened offset; it is applied automatically"
            }
        }
    }

    public static func masterKey(fromSeed seed: Data) -> ExtendedKey {
        let i = Hashing.hmacSHA512(key: Data(curveSeed.utf8), data: seed)
        return ExtendedKey(key: Data(i.prefix(32)), chainCode: Data(i.suffix(32)))
    }

    public static func deriveHardened(_ parent: ExtendedKey, index: UInt32) throws -> ExtendedKey {
        guard index < hardenedOffset else { throw SLIP10Error.indexAlreadyHardened(index) }

        var data = Data([0x00])
        data.append(parent.key)
        let hardened = index + hardenedOffset
        // Index is big-endian.
        for shift in stride(from: 24, through: 0, by: -8) {
            data.append(UInt8((hardened >> UInt32(shift)) & 0xff))
        }

        let i = Hashing.hmacSHA512(key: parent.chainCode, data: data)
        return ExtendedKey(key: Data(i.prefix(32)), chainCode: Data(i.suffix(32)))
    }

    public static func deriveEd25519Path(seed: Data, path: [UInt32]) throws -> ExtendedKey {
        var state = masterKey(fromSeed: seed)
        for index in path {
            state = try deriveHardened(state, index: index)
        }
        return state
    }
}
