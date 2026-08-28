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

    // MARK: - Word encoding and checksum

    public enum BIP39Error: Error, CustomStringConvertible {
        case invalidWordCount(Int)
        case unknownWord(String)
        case checksumMismatch
        case invalidEntropyLength(Int)

        public var description: String {
            switch self {
            case .invalidWordCount(let n):
                return "BIP-39 mnemonic must be 12, 15, 18, 21 or 24 words, got \(n)"
            case .unknownWord(let w):
                return "Word \"\(w)\" is not in the BIP-39 English list"
            case .checksumMismatch:
                return "BIP-39 checksum does not match the entropy"
            case .invalidEntropyLength(let n):
                return "BIP-39 entropy must be 16, 20, 24, 28 or 32 bytes, got \(n)"
            }
        }
    }

    /// Word counts BIP-39 defines, and the entropy length each encodes.
    ///
    /// Every word carries 11 bits and BIP-39 appends one checksum bit per 32 bits of
    /// entropy, so `words * 11 == entropyBits + entropyBits / 32`.
    static let entropyBytesByWordCount: [Int: Int] = [12: 16, 15: 20, 18: 24, 21: 28, 24: 32]

    /// Decodes a mnemonic to its entropy, verifying the checksum.
    ///
    /// Unlike ``Mnemonic`` — TON's own scheme, which has no embedded checksum and instead
    /// tests a PBKDF2 property of the whole phrase — BIP-39 carries its checksum inside the
    /// words. A single mistyped word almost always fails here.
    public static func entropy(from words: [String]) throws -> Data {
        let normalized = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let entropyBytes = entropyBytesByWordCount[normalized.count] else {
            throw BIP39Error.invalidWordCount(normalized.count)
        }

        var bits = ""
        bits.reserveCapacity(normalized.count * 11)
        for word in normalized {
            guard let index = MnemonicWordlist.index(of: word) else {
                throw BIP39Error.unknownWord(word)
            }
            bits += String(repeating: "0", count: 11 - String(index, radix: 2).count)
                  + String(index, radix: 2)
        }

        let entropyBits = entropyBytes * 8
        var entropy = Data(capacity: entropyBytes)
        for byte in 0..<entropyBytes {
            let start = bits.index(bits.startIndex, offsetBy: byte * 8)
            let end = bits.index(start, offsetBy: 8)
            entropy.append(UInt8(bits[start..<end], radix: 2) ?? 0)
        }

        // The trailing bits must equal the leading bits of SHA-256(entropy).
        let checksumBits = entropyBits / 32
        let expected = Hashing.sha256(entropy)[0]
        let actualStart = bits.index(bits.startIndex, offsetBy: entropyBits)
        let actual = String(bits[actualStart...])
        var expectedBits = ""
        for i in 0..<checksumBits { expectedBits += (expected & (0x80 >> UInt8(i))) != 0 ? "1" : "0" }
        guard actual == expectedBits else { throw BIP39Error.checksumMismatch }

        return entropy
    }

    /// Encodes entropy into a mnemonic. The inverse of ``entropy(from:)``.
    public static func mnemonic(fromEntropy entropy: Data) throws -> [String] {
        guard let wordCount = entropyBytesByWordCount.first(where: { $0.value == entropy.count })?.key
        else { throw BIP39Error.invalidEntropyLength(entropy.count) }

        var bits = entropy.map { String(repeating: "0", count: 8 - String($0, radix: 2).count)
                                 + String($0, radix: 2) }.joined()
        let checksum = Hashing.sha256(entropy)[0]
        for i in 0..<(entropy.count * 8 / 32) {
            bits += (checksum & (0x80 >> UInt8(i))) != 0 ? "1" : "0"
        }

        return (0..<wordCount).map { i in
            let start = bits.index(bits.startIndex, offsetBy: i * 11)
            let end = bits.index(start, offsetBy: 11)
            return MnemonicWordlist.words[Int(bits[start..<end], radix: 2) ?? 0]
        }
    }

    /// Whether a phrase is a well-formed BIP-39 mnemonic.
    public static func validate(_ words: [String]) -> Bool {
        (try? entropy(from: words)) != nil
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
