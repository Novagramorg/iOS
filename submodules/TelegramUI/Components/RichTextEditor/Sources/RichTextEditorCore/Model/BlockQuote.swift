import Foundation

/// A block quote: a recursive container of child blocks with a collapse flag. Mirrors the InstantPage wire
/// `.blockQuote(blocks:, caption:, collapsed:)`. Children may be ANY block, including nested block quotes.
public struct BlockQuote: Codable, Equatable {
    public var id: BlockID
    public var children: [Block]
    public var collapsed: Bool
    public init(id: BlockID, children: [Block] = [], collapsed: Bool = false) {
        self.id = id; self.children = children; self.collapsed = collapsed
    }
}
