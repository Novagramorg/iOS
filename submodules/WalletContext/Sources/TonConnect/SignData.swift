import Foundation
import WalletEngineFFI

@available(macOS 10.15, *)
public struct TonConnectSignDataPayload: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        case text(String)
        case binary(Data)
        case cell(schema: String, boc: Data)
    }

    public let content: Content
    let engineRequest: WalletEngineFFI.TonConnectSignDataRequest

    init(_ request: WalletEngineFFI.TonConnectSignDataRequest) throws {
        self.engineRequest = request
        switch request.payload {
        case let .text(text):
            self.content = .text(text)
        case let .binary(bytes):
            self.content = .binary(try Self.decodeBase64(bytes))
        case let .cell(schema, cell):
            self.content = .cell(schema: schema, boc: try Self.decodeBase64(cell))
        }
    }

    private static func decodeBase64(_ value: String) throws -> Data {
        var padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        padded += String(repeating: "=", count: (4 - padded.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: padded) else { throw TonConnectWireFailure(code: .badRequest) }
        return data
    }
}
