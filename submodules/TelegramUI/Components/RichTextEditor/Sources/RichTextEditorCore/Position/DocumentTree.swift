import Foundation

public enum DocumentTree {
    /// Builds the `.doc` root node for a document.
    public static func build(from document: Document) -> DocNode {
        .doc(children: document.blocks.map(node(for:)))
    }

    private static func node(for block: Block) -> DocNode {
        switch block {
        case .paragraph(let p):
            return .paragraph(id: p.id,
                              children: [.text(length: p.utf16Count, ref: .paragraph(p.id))])
        case .media(let img):
            if img.kind == .audio {
                // Audio is a caption-less atom — no caption paragraph node (nodeSize = 1 atom + 2 wrapper = 3).
                return .mediaBlock(id: img.id, children: [.mediaAtom(id: img.id)])
            }
            return .mediaBlock(id: img.id, children: [
                .mediaAtom(id: img.id),
                .paragraph(id: img.id,
                           children: [.text(length: img.captionUTF16Count, ref: .caption(img.id))]),
            ])
        case .table(let t):
            return .table(id: t.id, children: t.rows.map { row in
                .row(id: row.id, children: row.cells.map { cell in
                    .cell(id: cell.id, children: cell.blocks.map(node(for:)))
                })
            })
        case .code(let cb):
            // A code block reuses the paragraph node shape (content + 2 tokens); only the ref
            // distinguishes it so position mapping can identify it as code.
            return .paragraph(id: cb.id,
                              children: [.text(length: cb.utf16Count, ref: .code(cb.id))])
        case .pullQuote(let pq):
            // A pull quote reuses the paragraph node shape (content + 2 tokens), analogous to a code block.
            return .paragraph(id: pq.id,
                              children: [.text(length: pq.utf16Count, ref: .pullQuote(pq.id))])
        case .blockQuote(let bq):
            if bq.collapsed {
                // Folded → a caption-less atom, off the editable axis (nodeSize 3), like the old collapsedQuote.
                return .mediaBlock(id: bq.id, children: [.mediaAtom(id: bq.id)])
            }
            // Expanded → recursive container (Σ children + 2), directly recursing node(for:).
            return .blockQuote(id: bq.id, children: bq.children.map(node(for:)))
        }
    }

    /// Maximum valid position (size of the document's content).
    public static func documentSize(_ document: Document) -> Int {
        build(from: document).nodeSize
    }
}
