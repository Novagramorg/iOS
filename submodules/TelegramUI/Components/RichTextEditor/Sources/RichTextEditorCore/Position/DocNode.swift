import Foundation

/// Read-only positionable tree derived from a `Document`. `.doc` is the root.
public indirect enum DocNode: Equatable {
    case doc(children: [DocNode])
    case paragraph(id: BlockID, children: [DocNode])      // children: exactly one .text
    case text(length: Int, ref: TextNodeRef)              // inline content (UTF-16 length)
    case imageBlock(id: BlockID, children: [DocNode])     // [.imageAtom, caption paragraph]
    case imageAtom(id: BlockID)                           // leaf atom
    case table(id: BlockID, children: [DocNode])          // children: rows
    case row(id: BlockID, children: [DocNode])            // children: cells
    case cell(id: BlockID, children: [DocNode])           // children: cell blocks

    public var children: [DocNode] {
        switch self {
        case .doc(let c), .paragraph(_, let c), .imageBlock(_, let c),
             .table(_, let c), .row(_, let c), .cell(_, let c):
            return c
        case .text, .imageAtom:
            return []
        }
    }

    public var isLeaf: Bool {
        switch self {
        case .text, .imageAtom: return true
        default: return false
        }
    }

    /// Size in position tokens.
    public var nodeSize: Int {
        switch self {
        case .text(let length, _): return length
        case .imageAtom: return 1
        case .doc(let c): return c.reduce(0) { $0 + $1.nodeSize }        // doc: no +2
        case .paragraph(_, let c), .imageBlock(_, let c), .table(_, let c),
             .row(_, let c), .cell(_, let c):
            return c.reduce(0) { $0 + $1.nodeSize } + 2
        }
    }
}
