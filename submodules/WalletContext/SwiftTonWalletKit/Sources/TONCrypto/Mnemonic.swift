import Foundation

/// TON's native mnemonic scheme.
///
/// This is **not** BIP-39. It shares the wordlist but derives keys differently: the
/// mnemonic is HMAC'd to entropy, that entropy is stretched with 100k rounds of
/// PBKDF2-SHA512, and generation rejects any phrase whose entropy fails a "basic seed"
/// test. See ``BIP39`` for the other scheme, which walletkit also supports.
public enum Mnemonic {
    static let pbkdfIterations = 100_000

    /// Salt for the key-derivation step.
    public static let defaultSeedSalt = "TON default seed"
    public static let hdSeedSalt = "TON HD Keys seed"
    /// Salts for the two seed-classification tests.
    static let basicSeedSalt = "TON seed version"
    static let passwordSeedSalt = "TON fast seed version"

    public enum MnemonicError: Error, CustomStringConvertible {
        case invalidWordCount(Int)
        case unknownWord(String)
        case validationFailed

        public var description: String {
            switch self {
            case .invalidWordCount(let n):
                return "Mnemonic must be 12 or 24 words, got \(n)"
            case .unknownWord(let w):
                return "Word \"\(w)\" is not in the TON wordlist"
            case .validationFailed:
                return "Mnemonic failed validation"
            }
        }
    }

    // MARK: - Normalization

    static func normalize(_ words: [String]) -> [String] {
        words.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // MARK: - Entropy and seeds

    /// HMAC-SHA512 with the mnemonic as **key** and the password as **message**.
    ///
    /// That ordering is unusual and load-bearing — reversing it produces a plausible
    /// but wrong key.
    public static func entropy(from words: [String], password: String = "") -> Data {
        Hashing.hmacSHA512(key: words.joined(separator: " "), data: password)
    }

    /// Whether entropy qualifies as a "basic seed": the first derived byte must be 0.
    ///
    /// Note the reduced iteration count — `100000 / 256 == 390`, not the full 100k.
    static func isBasicSeed(_ entropy: Data) throws -> Bool {
        let seed = try Hashing.pbkdf2SHA512(
            password: entropy,
            salt: basicSeedSalt,
            iterations: max(1, pbkdfIterations / 256),
            keyLength: 64
        )
        return seed.first == 0
    }

    /// Whether entropy looks like a password-protected seed: one round, first byte 1.
    static func isPasswordSeed(_ entropy: Data) throws -> Bool {
        let seed = try Hashing.pbkdf2SHA512(
            password: entropy,
            salt: passwordSeedSalt,
            iterations: 1,
            keyLength: 64
        )
        return seed.first == 1
    }

    static func isPasswordNeeded(_ words: [String]) throws -> Bool {
        let passlessEntropy = entropy(from: words)
        return try isPasswordSeed(passlessEntropy) && !(try isBasicSeed(passlessEntropy))
    }

    /// Stretches a mnemonic into a 64-byte seed. This is the expensive step: 100k
    /// rounds of PBKDF2-SHA512.
    public static func seed(
        from words: [String],
        salt: String = defaultSeedSalt,
        password: String = ""
    ) throws -> Data {
        try Hashing.pbkdf2SHA512(
            password: entropy(from: words, password: password),
            salt: salt,
            iterations: pbkdfIterations,
            keyLength: 64
        )
    }

    // MARK: - Key derivation

    /// Derives the wallet key pair from a TON mnemonic.
    ///
    /// The reference `mnemonicToWalletKey` derives twice — once from the stretched
    /// seed, then again from the resulting secret key's first 32 bytes. Since a NaCl
    /// secret key is `seed ‖ publicKey`, the second derivation reproduces the first, so
    /// a single derivation is equivalent. Verified against `mnemonic.json`.
    public static func keyPair(from words: [String], password: String = "") throws -> KeyPair {
        let normalized = normalize(words)
        guard normalized.count == 12 || normalized.count == 24 else {
            throw MnemonicError.invalidWordCount(normalized.count)
        }
        let stretched = try seed(from: normalized, salt: defaultSeedSalt, password: password)
        return try Ed25519.keyPair(fromSeed: Data(stretched.prefix(32)))
    }

    /// Seed for HD derivation, which uses a different salt.
    public static func hdSeed(from words: [String], password: String = "") throws -> Data {
        try seed(from: normalize(words), salt: hdSeedSalt, password: password)
    }

    // MARK: - Validation

    /// Whether a mnemonic is a valid TON mnemonic.
    ///
    /// Stricter than a wordlist check: the derived entropy must also pass the basic
    /// seed test, which is what distinguishes a TON mnemonic from an arbitrary
    /// sequence of wordlist words.
    public static func validate(_ words: [String], password: String = "") throws -> Bool {
        let normalized = normalize(words)
        for word in normalized where !MnemonicWordlist.contains(word) {
            return false
        }
        if !password.isEmpty {
            guard try isPasswordNeeded(normalized) else { return false }
        }
        return try isBasicSeed(entropy(from: normalized, password: password))
    }

    // MARK: - Generation

    /// Generates a fresh mnemonic.
    ///
    /// Rejection sampling: candidates are discarded until one produces a basic seed.
    /// Each rejection costs a 390-round PBKDF2, and roughly 255 in 256 candidates are
    /// rejected, so this is **seconds of work** — never call it on the main actor.
    public static func generate(wordCount: Int = 24, password: String = "") throws -> [String] {
        guard wordCount == 12 || wordCount == 24 else {
            throw MnemonicError.invalidWordCount(wordCount)
        }

        while true {
            var candidate: [String] = []
            candidate.reserveCapacity(wordCount)
            for _ in 0..<wordCount {
                let index = try Hashing.secureRandomInt(upperBound: MnemonicWordlist.words.count)
                candidate.append(MnemonicWordlist.words[index])
            }

            if !password.isEmpty {
                guard try isPasswordNeeded(candidate) else { continue }
            }
            guard try isBasicSeed(entropy(from: candidate, password: password)) else { continue }

            return candidate
        }
    }
}
