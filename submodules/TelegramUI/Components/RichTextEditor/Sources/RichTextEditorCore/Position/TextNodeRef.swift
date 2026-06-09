import Foundation

/// Identifies an editable text node so a global position can be mapped back to model text.
public enum TextNodeRef: Equatable {
    /// The runs of a paragraph block (top-level or inside a table cell).
    case paragraph(BlockID)
    /// The caption runs of an image block.
    case caption(BlockID)
}
