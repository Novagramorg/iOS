import Foundation

/// A folded (collapsed) blockquote: a single non-editable ATOM holding the folded quote paragraphs. In the
/// position model it is caption-less (structurally identical to an audio media block, nodeSize 3); its text is
/// display-only (a ≤3-line preview). Mirrors `ChatInputContent.collapsedQuote` 1:1.
public struct CollapsedQuote: Codable, Equatable {
    public var id: BlockID
    /// The folded quote paragraphs (each `.quote` style). Restored verbatim on expand.
    public var paragraphs: [ParagraphBlock]

    public init(id: BlockID, paragraphs: [ParagraphBlock] = []) {
        self.id = id
        self.paragraphs = paragraphs
    }

    /// Joined plain text of the folded paragraphs (newline-separated) — the source for the collapsed preview.
    public var previewText: String { paragraphs.map(\.text).joined(separator: "\n") }
}
