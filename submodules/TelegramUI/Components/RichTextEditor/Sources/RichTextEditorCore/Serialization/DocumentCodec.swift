import Foundation

/// Canonical JSON encoding for a `Document`: ISO-8601 dates, sorted keys (stable diffs),
/// pretty-printed.
public enum DocumentCodec {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public static func encode(_ document: Document) throws -> Data {
        try encoder().encode(document)
    }

    public static func decode(_ data: Data) throws -> Document {
        try decoder().decode(Document.self, from: data)
    }
}
