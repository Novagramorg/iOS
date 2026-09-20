import Foundation
import CryptoKit
import Security

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

/// Derive only from an engine-validated mnemonic; keep within protected access.
/// Buffer erasure is best effort because Swift/CryptoKit may retain copies.
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

    /// The seed must not escape protected access.
    func withSeed<T>(_ body: (Data) throws -> T) rethrows -> T {
        var copy = self.seed
        defer { copy.resetBytes(in: copy.startIndex..<copy.endIndex) }
        return try body(copy)
    }

    func sign(_ message: Data) throws -> Data {
        return try Curve25519.Signing.PrivateKey(rawRepresentation: self.seed).signature(for: message)
    }
}

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

final class TonConnectSessionCrypto {
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    private let appBox: TonConnectNaClBox
    let publicKey: Data

    init(anchorSeed: Data, appPublicKey: Data, serverNonce: Data) throws {
        guard anchorSeed.count == 32, appPublicKey.count == 32 else {
            throw TonConnectCryptoError.invalidKey
        }
        guard !serverNonce.isEmpty else { throw TonConnectCryptoError.invalidNonce }
        guard serverNonce.count <= TonConnectNaClBox.maximumPacketLength else {
            throw TonConnectCryptoError.messageTooLarge
        }
        // serverNonce is a variable-length derivation salt, separate from the packet nonce.
        var prk = TonConnectCryptoPrimitives.hmacSHA512(key: anchorSeed, data: Data("tonconnect/session/v1".utf8))
        defer { prk.resetBytes(in: prk.startIndex..<prk.endIndex) }
        var input = Data(appPublicKey)
        input.append(serverNonce)
        var okm = TonConnectCryptoPrimitives.hmacSHA512(key: prk, data: input)
        defer { okm.resetBytes(in: okm.startIndex..<okm.endIndex) }
        var scalar = Array(okm.prefix(32))
        defer { scalar.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        scalar[0] &= 248
        scalar[31] &= 127
        scalar[31] |= 64
        var rawKey = Data(scalar)
        defer { rawKey.resetBytes(in: rawKey.startIndex..<rawKey.endIndex) }
        self.privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawKey)
        self.publicKey = self.privateKey.publicKey.rawRepresentation
        self.appBox = try TonConnectNaClBox(privateKey: rawKey, peerPublicKey: appPublicKey)
    }

    /// ephemeral32 || nonce24 || tag16 || body32; the peer is the ephemeral key.
    func openChallenge(_ challenge: Data) throws -> Data {
        guard challenge.count == 104 else { throw TonConnectCryptoError.malformedCiphertext }
        var rawKey = self.privateKey.rawRepresentation
        defer { rawKey.resetBytes(in: rawKey.startIndex..<rawKey.endIndex) }
        let box = try TonConnectNaClBox(privateKey: rawKey, peerPublicKey: Data(challenge.prefix(32)))
        let opened = try box.open(Data(challenge.dropFirst(56)), nonce: Data(challenge.dropFirst(32).prefix(24)))
        guard opened.count == 32 else { throw TonConnectCryptoError.malformedCiphertext }
        return opened
    }

    func seal(_ plaintext: Data) throws -> Data {
        guard plaintext.count <= TonConnectNaClBox.maximumPlaintextLength else {
            throw TonConnectCryptoError.messageTooLarge
        }
        var nonce = Data(count: 24)
        let status = nonce.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return errSecAllocate }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, baseAddress)
        }
        guard status == errSecSuccess else { throw TonConnectCryptoError.randomGenerationFailed }
        let encrypted = try self.appBox.seal(plaintext, nonce: nonce)
        nonce.append(encrypted)
        return nonce
    }

    func open(_ packet: Data) throws -> Data {
        guard packet.count >= 40 else { throw TonConnectCryptoError.malformedCiphertext }
        guard packet.count <= TonConnectNaClBox.maximumPacketLength else {
            throw TonConnectCryptoError.messageTooLarge
        }
        return try self.appBox.open(Data(packet.dropFirst(24)), nonce: Data(packet.prefix(24)))
    }
}

/// NaCl crypto_box: X25519 -> HSalsa20 -> XSalsa20-Poly1305. Its output is
/// tag16 || ciphertext; the session layer adds the random nonce24 prefix.
final class TonConnectNaClBox {
    static let maximumPacketLength = 1_048_576
    static let maximumPlaintextLength = maximumPacketLength - 24 - 16
    private var key: [UInt8]

    init(privateKey: Data, peerPublicKey: Data) throws {
        guard privateKey.count == 32, peerPublicKey.count == 32 else {
            throw TonConnectCryptoError.invalidKey
        }
        do {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
            let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)
            var sharedBytes = shared.withUnsafeBytes { Array($0) }
            defer { sharedBytes.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
            var nonzero: UInt8 = 0
            for byte in sharedBytes { nonzero |= byte }
            guard nonzero != 0 else { throw TonConnectCryptoError.invalidKey }
            self.key = Self.hsalsa20(key: sharedBytes, nonce: [UInt8](repeating: 0, count: 16))
        } catch {
            throw TonConnectCryptoError.invalidKey
        }
    }

    deinit {
        self.key.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) }
    }

    func seal(_ plaintext: Data, nonce: Data) throws -> Data {
        guard nonce.count == 24 else { throw TonConnectCryptoError.invalidNonce }
        guard plaintext.count <= Self.maximumPlaintextLength else { throw TonConnectCryptoError.messageTooLarge }
        let message = Array(plaintext)
        var stream = Self.xsalsa20(key: self.key, nonce: Array(nonce), count: message.count + 32)
        defer { stream.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        var ciphertext = [UInt8](repeating: 0, count: message.count)
        for index in message.indices { ciphertext[index] = message[index] ^ stream[index + 32] }
        let tag = Self.poly1305(message: ciphertext, key: Array(stream.prefix(32)))
        return Data(tag + ciphertext)
    }

    func open(_ ciphertext: Data, nonce: Data) throws -> Data {
        guard nonce.count == 24 else { throw TonConnectCryptoError.invalidNonce }
        guard ciphertext.count >= 16 else { throw TonConnectCryptoError.malformedCiphertext }
        guard ciphertext.count <= Self.maximumPacketLength - 24 else { throw TonConnectCryptoError.messageTooLarge }
        // Array rebases Data slices whose startIndex is nonzero.
        let bytes = Array(ciphertext)
        let encrypted = Array(bytes.dropFirst(16))
        var stream = Self.xsalsa20(key: self.key, nonce: Array(nonce), count: encrypted.count + 32)
        defer { stream.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        let tag = Self.poly1305(message: encrypted, key: Array(stream.prefix(32)))
        guard tonConnectConstantTimeEqual(Data(tag), Data(bytes.prefix(16))) else {
            throw TonConnectCryptoError.authenticationFailed
        }
        var plaintext = [UInt8](repeating: 0, count: encrypted.count)
        for index in encrypted.indices { plaintext[index] = encrypted[index] ^ stream[index + 32] }
        return Data(plaintext)
    }

    private static func load32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }

    private static func store32(_ word: UInt32, into bytes: inout [UInt8], at offset: Int) {
        for index in 0..<4 { bytes[offset + index] = UInt8(truncatingIfNeeded: word >> (8 * index)) }
    }

    private static func rotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
        return (value << amount) | (value >> (32 - amount))
    }

    private static func quarterRound(_ x: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        x[b] ^= rotate(x[a] &+ x[d], by: 7)
        x[c] ^= rotate(x[b] &+ x[a], by: 9)
        x[d] ^= rotate(x[c] &+ x[b], by: 13)
        x[a] ^= rotate(x[d] &+ x[c], by: 18)
    }

    private static func rounds(_ state: [UInt32]) -> [UInt32] {
        var x = state
        for _ in 0..<10 {
            quarterRound(&x, 0, 4, 8, 12)
            quarterRound(&x, 5, 9, 13, 1)
            quarterRound(&x, 10, 14, 2, 6)
            quarterRound(&x, 15, 3, 7, 11)
            quarterRound(&x, 0, 1, 2, 3)
            quarterRound(&x, 5, 6, 7, 4)
            quarterRound(&x, 10, 11, 8, 9)
            quarterRound(&x, 15, 12, 13, 14)
        }
        return x
    }

    private static func initialState(key: [UInt8]) -> [UInt32] {
        var state = [UInt32](repeating: 0, count: 16)
        // "expand 32-byte k", serialized little endian.
        state[0] = 0x61707865; state[5] = 0x3320646e
        state[10] = 0x79622d32; state[15] = 0x6b206574
        for index in 0..<4 {
            state[1 + index] = load32(key, index * 4)
            state[11 + index] = load32(key, 16 + index * 4)
        }
        return state
    }

    private static func hsalsa20(key: [UInt8], nonce: [UInt8]) -> [UInt8] {
        var state = initialState(key: key)
        for index in 0..<4 { state[6 + index] = load32(nonce, index * 4) }
        let x = rounds(state)
        var output = [UInt8](repeating: 0, count: 32)
        for (index, position) in [0, 5, 10, 15, 6, 7, 8, 9].enumerated() {
            store32(x[position], into: &output, at: index * 4)
        }
        return output
    }

    /// The first 32 bytes are the Poly1305 key; callers cap count at 1 MiB.
    private static func xsalsa20(key: [UInt8], nonce: [UInt8], count: Int) -> [UInt8] {
        var subkey = hsalsa20(key: key, nonce: Array(nonce.prefix(16)))
        defer { subkey.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        var state = initialState(key: subkey)
        state[6] = load32(nonce, 16)
        state[7] = load32(nonce, 20)
        var output = [UInt8](repeating: 0, count: count)
        var block = [UInt8](repeating: 0, count: 64)
        defer { block.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        for blockIndex in 0..<((count + 63) / 64) {
            state[8] = UInt32(blockIndex)
            state[9] = 0
            let x = rounds(state)
            for index in 0..<16 { store32(x[index] &+ state[index], into: &block, at: index * 4) }
            let offset = blockIndex * 64
            for index in 0..<min(64, count - offset) { output[offset + index] = block[index] }
        }
        return output
    }

    /// Poly1305 in five 26-bit limbs. Products fit UInt64 (below 2^58);
    /// wraparound subtraction is used only for constant-time final reduction.
    private static func poly1305(message: [UInt8], key: [UInt8]) -> [UInt8] {
        let mask: UInt64 = 0x3ffffff
        let r0 = UInt64(load32(key, 0)) & mask
        let r1 = UInt64(load32(key, 3) >> 2) & 0x3ffff03
        let r2 = UInt64(load32(key, 6) >> 4) & 0x3ffc0ff
        let r3 = UInt64(load32(key, 9) >> 6) & 0x3f03fff
        let r4 = UInt64(load32(key, 12) >> 8) & 0x00fffff
        let s1 = r1 * 5, s2 = r2 * 5, s3 = r3 * 5, s4 = r4 * 5
        var h0: UInt64 = 0, h1: UInt64 = 0, h2: UInt64 = 0, h3: UInt64 = 0, h4: UInt64 = 0
        var offset = 0
        while offset < message.count {
            let length = min(16, message.count - offset)
            var block = [UInt8](repeating: 0, count: 16)
            for index in 0..<length { block[index] = message[offset + index] }
            if length < 16 { block[length] = 1 }
            h0 += UInt64(load32(block, 0)) & mask
            h1 += UInt64(load32(block, 3) >> 2) & mask
            h2 += UInt64(load32(block, 6) >> 4) & mask
            h3 += UInt64(load32(block, 9) >> 6) & mask
            h4 += UInt64(load32(block, 12) >> 8) | (length == 16 ? 1 << 24 : 0)
            let d0 = h0 * r0 + h1 * s4 + h2 * s3 + h3 * s2 + h4 * s1
            let d1 = h0 * r1 + h1 * r0 + h2 * s4 + h3 * s3 + h4 * s2 + (d0 >> 26)
            let d2 = h0 * r2 + h1 * r1 + h2 * r0 + h3 * s4 + h4 * s3 + (d1 >> 26)
            let d3 = h0 * r3 + h1 * r2 + h2 * r1 + h3 * r0 + h4 * s4 + (d2 >> 26)
            let d4 = h0 * r4 + h1 * r3 + h2 * r2 + h3 * r1 + h4 * r0 + (d3 >> 26)
            h0 = (d0 & mask) + (d4 >> 26) * 5
            h1 = (d1 & mask) + (h0 >> 26)
            h0 &= mask
            h2 = d2 & mask; h3 = d3 & mask; h4 = d4 & mask
            offset += length
        }
        h2 += h1 >> 26; h1 &= mask
        h3 += h2 >> 26; h2 &= mask
        h4 += h3 >> 26; h3 &= mask
        h0 += (h4 >> 26) * 5; h4 &= mask
        h1 += h0 >> 26; h0 &= mask

        let g0 = h0 + 5
        let g1 = h1 + (g0 >> 26)
        let g2 = h2 + (g1 >> 26)
        let g3 = h3 + (g2 >> 26)
        let g4 = (h4 + (g3 >> 26)) &- (1 << 26)
        let useReduced = (g4 >> 63) &- 1
        h0 = (h0 & ~useReduced) | (g0 & mask & useReduced)
        h1 = (h1 & ~useReduced) | (g1 & mask & useReduced)
        h2 = (h2 & ~useReduced) | (g2 & mask & useReduced)
        h3 = (h3 & ~useReduced) | (g3 & mask & useReduced)
        h4 = (h4 & ~useReduced) | (g4 & mask & useReduced)

        let f0 = ((h0 | (h1 << 26)) & 0xffffffff) + UInt64(load32(key, 16))
        let f1 = (((h1 >> 6) | (h2 << 20)) & 0xffffffff) + UInt64(load32(key, 20)) + (f0 >> 32)
        let f2 = (((h2 >> 12) | (h3 << 14)) & 0xffffffff) + UInt64(load32(key, 24)) + (f1 >> 32)
        let f3 = (((h3 >> 18) | (h4 << 8)) & 0xffffffff) + UInt64(load32(key, 28)) + (f2 >> 32)
        var tag = [UInt8](repeating: 0, count: 16)
        for (index, word) in [f0, f1, f2, f3].enumerated() {
            store32(UInt32(truncatingIfNeeded: word), into: &tag, at: index * 4)
        }
        return tag
    }
}
