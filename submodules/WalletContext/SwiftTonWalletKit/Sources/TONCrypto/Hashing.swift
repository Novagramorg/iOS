import Foundation
import CryptoKit
import CommonCrypto

/// Hash and key-derivation primitives.
///
/// CryptoKit covers SHA-2 and HMAC on every supported platform (iOS 13+), but has no
/// PBKDF2 at any version — that comes from CommonCrypto, which is also hardware
/// accelerated and therefore the right choice for the TON mnemonic's 100k-round path.
public enum Hashing {
    // MARK: - SHA-2

    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    public static func sha512(_ data: Data) -> Data {
        Data(SHA512.hash(data: data))
    }

    // MARK: - HMAC

    public static func hmacSHA512(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        return Data(HMAC<SHA512>.authenticationCode(for: data, using: symmetricKey))
    }

    /// UTF-8 convenience. Note the argument order: TON's mnemonic entropy uses the
    /// *mnemonic* as the key and the *password* as the message, which is the reverse
    /// of what most PBKDF-style APIs suggest.
    public static func hmacSHA512(key: String, data: String) -> Data {
        hmacSHA512(key: Data(key.utf8), data: Data(data.utf8))
    }

    // MARK: - PBKDF2

    public enum HashingError: Error, CustomStringConvertible {
        case pbkdf2Failed(status: Int32)

        public var description: String {
            switch self {
            case .pbkdf2Failed(let status):
                return "PBKDF2 derivation failed with status \(status)"
            }
        }
    }

    /// PBKDF2-HMAC-SHA512.
    ///
    /// `password` is passed as raw bytes rather than a string: TON derives from HMAC
    /// output, which is not valid UTF-8.
    public static func pbkdf2SHA512(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        var derived = Data(repeating: 0, count: keyLength)

        let status: Int32 = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(iterations),
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else { throw HashingError.pbkdf2Failed(status: status) }
        return derived
    }

    public static func pbkdf2SHA512(
        password: Data,
        salt: String,
        iterations: Int,
        keyLength: Int
    ) throws -> Data {
        try pbkdf2SHA512(
            password: password,
            salt: Data(salt.utf8),
            iterations: iterations,
            keyLength: keyLength
        )
    }

    // MARK: - Random

    public enum RandomError: Error, CustomStringConvertible {
        case failed(status: Int32)
        public var description: String { "Secure random generation failed" }
    }

    public static func secureRandomBytes(_ count: Int) throws -> Data {
        var bytes = Data(repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw RandomError.failed(status: status) }
        return bytes
    }

    /// Uniform random integer in `0..<upperBound`, by rejection sampling so the
    /// distribution stays flat (modulo reduction would bias low values).
    public static func secureRandomInt(upperBound: Int) throws -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bitsNeeded = Int.bitWidth - (upperBound - 1).leadingZeroBitCount
        let bytesNeeded = (bitsNeeded + 7) / 8
        let mask = bitsNeeded >= Int.bitWidth ? Int.max : (1 << bitsNeeded) - 1

        while true {
            let bytes = try secureRandomBytes(bytesNeeded)
            var value = 0
            for byte in bytes { value = (value << 8) | Int(byte) }
            value &= mask
            if value < upperBound { return value }
        }
    }
}
