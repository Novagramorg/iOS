#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A vertical run of `CanvasBlock`s — the shared engine for the document body and for each table
/// cell. Owns span math (relative to a `baseOffset`) and vertical layout (relative to an origin).
@available(iOS 13.0, *)
final class BlockStack {
    var boxes: [CanvasBlock]
    private(set) var baseOffset: Int = 0
    private(set) var contentHeight: CGFloat = 0

    init(boxes: [CanvasBlock] = []) { self.boxes = boxes }

    /// Assigns each box's `nodeStart` (= running tokens + 1, relative to `baseOffset`) and returns
    /// the stack's total token size.
    @discardableResult
    func recompute(baseOffset: Int) -> Int {
        self.baseOffset = baseOffset
        var pos = baseOffset
        for box in boxes {
            box.nodeStart = pos + 1
            pos += box.nodeSize
        }
        return pos - baseOffset
    }

    /// Extra inset a block reserves on the side facing a block that draws its own bounded background or
    /// border — a quote's fill or a table's grid — so that framed block has visible separation from its
    /// neighbors. Lives on the neighbor (external to the framed block), since a quote/table fills its
    /// own frame; the framed block's own inset is its internal padding.
    private static let framedNeighborMargin: CGFloat = 8

    /// The inset for `box` on the side facing `neighbor` (or the stack edge, when nil). The facing
    /// insets of two adjacent blocks together make their gap: list items stack tight (0); two body
    /// paragraphs sit at half the default; a block facing a quote or table reserves extra margin;
    /// otherwise the default.
    /// The base inter-block vertical inset (each side; two facing insets make a gap). Defaults to the
    /// document metric (`BlockBox.defaultVerticalInset`, 8pt). A compact host (chat composer) sets the root
    /// stack's base to 0 so a lone paragraph hugs its text height; nested (table-cell) stacks keep the default.
    var verticalInsetBase: CGFloat = BlockBox.defaultVerticalInset

    private func facingInset(of box: BlockBox, toward neighbor: CanvasBlock?) -> CGFloat {
        let base = self.verticalInsetBase
        if neighbor is TableBlockBox { return base + BlockStack.framedNeighborMargin }
        guard let n = neighbor as? BlockBox else { return base }
        if box.listMembership != nil && n.listMembership != nil { return 0 }
        if box.isBodyParagraph && n.isBodyParagraph { return base / 2 }
        if n.style == .quote && box.style != .quote { return base + BlockStack.framedNeighborMargin }
        return base
    }

    /// Lays boxes out top-to-bottom from `origin` at the given content `width`; returns total height.
    @discardableResult
    func layout(origin: CGPoint, width: CGFloat) -> CGFloat {
        var y = origin.y
        for i in boxes.indices {
            let box = boxes[i]
            if let b = box as? BlockBox {
                let prev: CanvasBlock? = i > 0 ? boxes[i - 1] : nil
                let next: CanvasBlock? = i + 1 < boxes.count ? boxes[i + 1] : nil
                b.topInset = facingInset(of: b, toward: prev)
                b.bottomInset = facingInset(of: b, toward: next)
            }
            box.setWidth(width)
            box.frame = CGRect(x: origin.x, y: y, width: width, height: box.height)
            y += box.height
        }
        contentHeight = y - origin.y
        return contentHeight
    }

    /// Stateless total height at content `width` — the measure analogue of `layout`'s returned height.
    /// Reads each box's structural insets (width-independent); never mutates a box. Reused by the
    /// document root and by each table cell.
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        boxes.reduce(0) { $0 + $1.measuredHeight(forWidth: width) }
    }

    func leafRegions() -> [LeafTextRegion] { boxes.flatMap { $0.leafRegions() } }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) { for b in boxes { b.draw(in: ctx, imageProvider: imageProvider) } }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        guard !boxes.isEmpty else { return baseOffset }
        let box = boxes.first(where: { point.y < $0.frame.maxY }) ?? boxes[boxes.count - 1]
        return box.closestPosition(toCanvasPoint: point)
    }
}
#endif
