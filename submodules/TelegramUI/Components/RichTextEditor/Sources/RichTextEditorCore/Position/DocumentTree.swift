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
        case .image(let img):
            return .imageBlock(id: img.id, children: [
                .imageAtom(id: img.id),
                .paragraph(id: img.id,
                           children: [.text(length: img.captionUTF16Count, ref: .caption(img.id))]),
            ])
        case .table(let t):
            return .table(id: t.id, children: t.rows.map { row in
                .row(id: row.id, children: row.cells.map { cell in
                    .cell(id: cell.id, children: cell.blocks.map(node(for:)))
                })
            })
        }
    }

    /// Maximum valid position (size of the document's content).
    public static func documentSize(_ document: Document) -> Int {
        build(from: document).nodeSize
    }
}
