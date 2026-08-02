import Foundation

/// Loads golden vectors generated from the reference TypeScript implementation.
///
/// Vectors are the specification for the port: the TypeScript code is only the
/// reference implementation of them. Regenerate with
/// `cd Tools/vectorgen && npx tsx dump.ts`.
public enum Vectors {
    /// Envelope every vector file shares.
    public struct File<T: Decodable>: Decodable {
        public let source: String
        public let vectors: T
    }

    public enum LoadError: Error, CustomStringConvertible {
        case missingResource(String)
        case decodeFailed(String, underlying: Error)

        public var description: String {
            switch self {
            case .missingResource(let name):
                return """
                Vector file "\(name)" not found in the test bundle. \
                Regenerate with: cd Tools/vectorgen && npx tsx dump.ts
                """
            case .decodeFailed(let name, let underlying):
                return "Vector file \"\(name)\" failed to decode: \(underlying)"
            }
        }
    }

    /// Decodes `Vectors/<name>` and returns its `vectors` payload.
    public static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
        let data = try raw(name)
        do {
            return try JSONDecoder().decode(File<T>.self, from: data).vectors
        } catch {
            throw LoadError.decodeFailed(name, underlying: error)
        }
    }

    /// Raw bytes of a recorded Toncenter fixture, e.g. `"toncenter/mainnet/balance"`.
    ///
    /// Fixtures differ from vectors: they are recorded HTTP responses paired with the
    /// models the reference mapped them into, rather than deterministic golden values.
    public static func rawFixture(_ path: String) throws -> Data {
        let stem = path.hasSuffix(".json") ? String(path.dropLast(5)) : path
        guard let url = Bundle.module.url(forResource: "Fixtures/\(stem)", withExtension: "json") else {
            throw LoadError.missingResource("Fixtures/\(stem).json")
        }
        return try Data(contentsOf: url)
    }

    /// Raw bytes of a vector file, for tests that want to inspect the JSON directly.
    public static func raw(_ name: String) throws -> Data {
        let stem = name.hasSuffix(".json") ? String(name.dropLast(5)) : name
        guard let url = Bundle.module.url(forResource: "Vectors/\(stem)", withExtension: "json") else {
            throw LoadError.missingResource(name)
        }
        return try Data(contentsOf: url)
    }
}

// MARK: - Hex and base64 helpers

extension Data {
    /// Parses a hex string, tolerating a leading `0x` since the vectors use both forms.
    public static func fromVectorHex(_ string: String) -> Data? {
        var s = Substring(string)
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s = s.dropFirst(2) }
        guard s.count % 2 == 0 else { return nil }
        var out = Data(capacity: s.count / 2)
        var index = s.startIndex
        while index < s.endIndex {
            let next = s.index(index, offsetBy: 2)
            guard let byte = UInt8(s[index..<next], radix: 16) else { return nil }
            out.append(byte)
            index = next
        }
        return out
    }

    public var vectorHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
