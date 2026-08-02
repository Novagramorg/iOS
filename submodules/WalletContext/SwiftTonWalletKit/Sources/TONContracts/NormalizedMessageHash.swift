import Foundation
import TONCore

/// TEP-467 normalized hashing for inbound external messages.
///
/// TON Connect transaction lookup is keyed on this hash. It exists because the same
/// logical transaction can be serialized several ways — with or without a source
/// address, with or without a state init, body inline or behind a ref — and every
/// variant would otherwise hash differently. Normalization pins one canonical form so a
/// wallet and a dApp agree on what to look up.
public enum NormalizedMessage {
    public enum NormalizationError: Error, CustomStringConvertible {
        case notExternalIn(String)

        public var description: String {
            switch self {
            case .notExternalIn(let kind):
                return "Message must be external-in for normalized hashing, got \(kind)"
            }
        }
    }

    public struct Normalized: Sendable {
        /// Hex, `0x`-prefixed to match the reference's `Hex` type.
        public let hash: String
        /// Base64 BoC of the normalized message.
        public let boc: String
        public let hashBytes: Data
        public let cell: Cell
    }

    /// Normalizes a serialized external message and returns its hash.
    ///
    /// Three things are forced:
    /// - the source address is dropped (`addr_none`)
    /// - `importFee` is zeroed
    /// - the state init is dropped, and the body is forced into a reference
    ///
    /// The `forceRef` part is why `Message.store(into:forceRef:)` exists at all: without
    /// it the body would be inlined whenever it happened to fit, and two wallets sending
    /// identical transactions could disagree on the hash.
    public static func normalize(boc: Data) throws -> Normalized {
        let cell = try Cell.fromBoc(boc)
        var slice = cell.beginParse()
        let message = try Message.load(from: &slice)

        guard case .externalIn(let info) = message.info else {
            let kind: String
            switch message.info {
            case .internalMessage: kind = "internal"
            case .externalOut: kind = "external-out"
            case .externalIn: kind = "external-in"
            }
            throw NormalizationError.notExternalIn(kind)
        }

        let normalized = Message(
            info: .externalIn(
                .init(src: nil, dest: info.dest, importFee: 0)
            ),
            stateInit: nil,
            body: message.body
        )

        let normalizedCell = try normalized.toCell(forceRef: true)
        let hashBytes = normalizedCell.hash()

        return Normalized(
            hash: "0x\(hashBytes.hexString)",
            boc: normalizedCell.toBoc().base64EncodedString(),
            hashBytes: hashBytes,
            cell: normalizedCell
        )
    }

    /// Convenience for a base64-encoded BoC, the form TON Connect carries.
    public static func normalize(base64: String) throws -> Normalized {
        guard let data = Data(anyBase64: base64) else {
            throw Address.ParseError.invalidBase64
        }
        return try normalize(boc: data)
    }
}
