import Foundation

public struct DocumentMetadata: Codable, Equatable {
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(title: String, createdAt: Date, modifiedAt: Date) {
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct Document: Codable, Equatable {
    public var schemaVersion: Int
    public var metadata: DocumentMetadata
    public var blocks: [Block]

    public init(schemaVersion: Int = 1, metadata: DocumentMetadata, blocks: [Block] = []) {
        self.schemaVersion = schemaVersion
        self.metadata = metadata
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, metadata, blocks }

    // Custom decode so a document missing `schemaVersion` defaults to 1 (forward/backward
    // compatibility — the synthesized decode would throw on a missing key). Encode is synthesized.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        metadata = try c.decode(DocumentMetadata.self, forKey: .metadata)
        blocks = try c.decode([Block].self, forKey: .blocks)
    }
}
