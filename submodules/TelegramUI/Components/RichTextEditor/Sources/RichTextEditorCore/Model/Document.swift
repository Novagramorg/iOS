import Foundation

public struct Document: Codable, Equatable {
    public var schemaVersion: Int
    public var blocks: [Block]
    /// Whole-document writing-direction override. `.auto` = per-paragraph auto-detect.
    public var layoutDirection: DocumentLayoutDirection

    public init(schemaVersion: Int = 1, blocks: [Block] = [],
                layoutDirection: DocumentLayoutDirection = .auto) {
        self.schemaVersion = schemaVersion
        self.blocks = blocks
        self.layoutDirection = layoutDirection
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, blocks, layoutDirection }

    // Custom decode so a document missing `schemaVersion`/`layoutDirection` defaults sanely (the
    // synthesized decode would throw on a missing key). Encode is synthesized over CodingKeys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        blocks = try c.decode([Block].self, forKey: .blocks)
        layoutDirection = try c.decodeIfPresent(DocumentLayoutDirection.self, forKey: .layoutDirection) ?? .auto
    }
}
