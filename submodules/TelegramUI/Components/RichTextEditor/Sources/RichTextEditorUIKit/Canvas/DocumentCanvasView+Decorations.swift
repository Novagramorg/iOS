#if canImport(UIKit)
import UIKit
import RichTextEditorCore

extension DocumentCanvasView {
    struct BlockquoteDecoration { let fill: CGRect; let bar: CGRect }

    /// One bar+fill rect pair per RUN of consecutive `.quote` blocks, in canvas coordinates — so a
    /// multi-paragraph quote shares a single continuous background (rounded only at the run's outer
    /// corners) instead of a separate pill per paragraph. The block frames are already inset by the
    /// page margin (root layout), so the bar sits at `frame.minX` and the fill spans the content
    /// width. Drawn behind the text.
    func blockquoteDecorations() -> [BlockquoteDecoration] {
        var result: [BlockquoteDecoration] = []
        var run: CGRect?
        func flush() {
            guard let f = run else { return }
            result.append(BlockquoteDecoration(fill: f, bar: CGRect(x: f.minX, y: f.minY, width: 3, height: f.height)))
            run = nil
        }
        for box in boxes {
            if let p = box as? BlockBox, p.style == .quote {
                run = run.map { $0.union(p.frame) } ?? p.frame
            } else {
                flush()
            }
        }
        flush()
        return result
    }

    /// Blockquote fill corner radius (measured from the reference design). Consumed by the
    /// `BlockquoteUnderlay` image factory (the fills are now drawn by a stretchable-image underlay,
    /// not into the canvas context); `blockquoteDecorations()` above still supplies the run rects.
    static let blockquoteCornerRadius: CGFloat = 2.5
}

extension DocumentCanvasView {
    struct PlaceholderDraw { let text: String; let origin: CGPoint; let font: UIFont }

    /// Test/geometry seam: one entry per EMPTY top-level paragraph whose style has placeholder text.
    /// Production draws each placeholder in `BlockBox.draw`; this delegates to the same per-box
    /// `BlockBox.placeholderDraw()` so assertions match where it actually renders.
    func placeholderDraws() -> [PlaceholderDraw] {
        boxes.compactMap { box in
            guard let p = box as? BlockBox, let d = p.placeholderDraw() else { return nil }
            return PlaceholderDraw(text: d.text, origin: d.origin, font: d.font)
        }
    }
}
#endif
