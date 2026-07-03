import Foundation

/// A pull quote: one text-only block holding multi-line rich text (interior "\n"s), rendered centered +
/// italic inside a content-hugging tinted pill with corner quote marks. Unlike a paragraph, its runs may
/// contain "\n" — the whole block is one editable unit. Unlike a code block, its runs keep full inline
/// formatting (bold/underline/link/color/emoji); the italic + center are render-only and never stored here.
public struct PullQuote: Codable, Equatable {
    public var id: BlockID
    public var runs: [TextRun]

    public init(id: BlockID, runs: [TextRun] = []) {
        self.id = id
        self.runs = runs
    }

    /// The plain text of the block (runs concatenated; may contain "\n").
    public var text: String { runs.map(\.text).joined() }

    /// Total UTF-16 length of the block's text.
    public var utf16Count: Int { runs.reduce(0) { $0 + $1.utf16Count } }
}
