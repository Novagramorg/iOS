import Foundation

/// The two BIP-39 halves of a rotation mnemonic (TEP-0003 §3.3).
///
/// A rotation mnemonic is 24 words made of **two independent 12-word BIP-39 mnemonics**:
/// an *anchor* half that fixes the account address, and a *signing* half that is replaced
/// when the wallet performs its one-time key rotation. The halves are never joined into a
/// single 24-word mnemonic and their entropies are never combined — a 24-word rotation
/// phrase is not a 24-word BIP-39 phrase, and decoding it as one produces a different key
/// with no error to warn you.
///
/// Before rotation both halves are identical, so the user holds a single 12-word phrase.
/// ``init(words:)`` accepts that form and expands it; callers never duplicate words
/// themselves.
///
/// ## Not the same scheme as ``Mnemonic``
///
/// This kit now supports two unrelated mnemonic schemes, and they disagree about which
/// phrases are valid:
///
/// | | ``Mnemonic`` (TON) | ``RotationMnemonic`` (BIP-39) |
/// |---|---|---|
/// | used by | V4R2, V5R1 | wallet-v5-experimental |
/// | words | 24 | 12 (pre-rotation) or 24 (two halves) |
/// | checksum | none — a PBKDF2 property of the whole phrase | 4 bits inside the words |
/// | seed | `PBKDF2(HMAC(phrase), "TON default seed", 100000)` | `PBKDF2(phrase, "mnemonic", 2048)` |
/// | derivation | seed used directly | SLIP-0010 `m/44'/607'/0'` |
///
/// A phrase valid under one is almost never valid under the other, so a host app has to
/// know which kind of wallet it is importing rather than trying both.
public struct RotationMnemonic: Sendable, Equatable {
    /// Words in one BIP-39 half.
    public static let halfWordCount = 12
    /// Words in a full rotation phrase.
    public static let rotationWordCount = halfWordCount * 2

    /// Words 1–12. Derives the key the address is built from.
    public let anchor: [String]
    /// Words 13–24. Derives the key that signs, and the one rotation replaces.
    public let signing: [String]

    public enum RotationMnemonicError: Error, CustomStringConvertible {
        case wordCount(Int)

        public var description: String {
            switch self {
            case .wordCount(let n):
                return "A rotation mnemonic must be \(RotationMnemonic.halfWordCount) words "
                     + "(before rotation) or \(RotationMnemonic.rotationWordCount) (after), got \(n)"
            }
        }
    }

    /// Validates a phrase and splits it into halves.
    ///
    /// Accepts 12 words — the pre-rotation form, where the one half serves as both — or 24,
    /// which is split down the middle. Each half is validated as its own BIP-39 mnemonic,
    /// checksum included, so a phrase that is 24 valid BIP-39 words but not two valid
    /// halves is rejected.
    public init(words: [String]) throws {
        let normalized = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        switch normalized.count {
        case Self.halfWordCount:
            _ = try BIP39.entropy(from: normalized)
            self.anchor = normalized
            self.signing = normalized
        case Self.rotationWordCount:
            let anchor = Array(normalized.prefix(Self.halfWordCount))
            let signing = Array(normalized.suffix(Self.halfWordCount))
            _ = try BIP39.entropy(from: anchor)
            _ = try BIP39.entropy(from: signing)
            self.anchor = anchor
            self.signing = signing
        default:
            throw RotationMnemonicError.wordCount(normalized.count)
        }
    }

    /// Splits a whitespace-separated phrase and validates it.
    public static func parse(_ phrase: String) throws -> RotationMnemonic {
        try RotationMnemonic(words: phrase.split(whereSeparator: \.isWhitespace).map(String.init))
    }

    /// Whether the key has never been rotated, i.e. both halves are the same.
    public var isPreRotation: Bool { anchor == signing }

    /// The full 24-word phrase, both halves in order.
    ///
    /// Note this is always 24 words, even before rotation, where it is the user's 12-word
    /// phrase written twice. What the *user* records is ``anchor`` while
    /// ``isPreRotation`` holds, and the 24-word form afterwards.
    public var words: [String] { anchor + signing }

    /// The key pair the account address derives from.
    public func anchorKeyPair() throws -> KeyPair {
        try BIP39.keyPair(from: anchor)
    }

    /// The key pair that signs today. Equal to ``anchorKeyPair()`` before rotation.
    public func signingKeyPair() throws -> KeyPair {
        try BIP39.keyPair(from: signing)
    }

    /// The mnemonic this one becomes after rotating to `newSigning`.
    ///
    /// The anchor half is carried over unchanged — that is what keeps the address — so this
    /// is the phrase the user must record once a rotation settles. Losing it loses the
    /// wallet: the address cannot be recovered from the signing half alone.
    public func rotated(to newSigning: RotationMnemonic) -> RotationMnemonic {
        RotationMnemonic(anchor: anchor, signing: newSigning.anchor)
    }

    private init(anchor: [String], signing: [String]) {
        self.anchor = anchor
        self.signing = signing
    }

    /// Generates a fresh 12-word half.
    public static func generate() throws -> RotationMnemonic {
        let entropy = try Hashing.secureRandomBytes(16)
        return try RotationMnemonic(words: try BIP39.mnemonic(fromEntropy: entropy))
    }
}
