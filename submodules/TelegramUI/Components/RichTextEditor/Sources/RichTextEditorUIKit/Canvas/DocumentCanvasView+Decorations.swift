#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
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
            result.append(BlockquoteDecoration(fill: f, bar: CGRect(x: f.minX, y: f.minY, width: self.quoteStyle.barWidth, height: f.height)))
            run = nil
        }
        for box in boxes {
            if let p = box as? BlockBox, p.style == .quote {
                run = run.map { $0.union(p.frame) } ?? p.frame
            } else if let cq = box as? CollapsedQuoteBox {
                flush()                                   // a collapsed quote is its own run (rounded both ends)
                result.append(BlockquoteDecoration(fill: cq.frame,
                                                   bar: CGRect(x: cq.frame.minX, y: cq.frame.minY,
                                                               width: self.quoteStyle.barWidth, height: cq.frame.height)))
            } else if let code = box as? CodeBlockBox {
                flush()                                   // a code block is its own run (rounded both ends)
                result.append(BlockquoteDecoration(fill: code.frame,
                                                   bar: CGRect(x: code.frame.minX, y: code.frame.minY,
                                                               width: self.quoteStyle.barWidth, height: code.frame.height)))
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

    /// One centered, content-hugging pill rect per PullQuoteBox (canvas coords). Width = the box's widest laid-out
    /// line + symmetric horizontal padding, clamped to the box's content width, centered on the box's mid-x. Height
    /// spans the box (its topInset/bottomInset already pad above/below the text). Fed to the barless pull-quote underlay.
    func pullQuotePillRects() -> [CGRect] {
        boxes.compactMap { box in
            guard let pq = box as? PullQuoteBox else { return nil }
            let hPad: CGFloat = 12   // Task 10 will source this from a PullQuoteStyle knob; match PullQuoteBox.horizontalPadding
            let w = min(pq.contentWidth + hPad * 2, box.frame.width)
            return CGRect(x: box.frame.midX - w / 2, y: box.frame.minY, width: w, height: box.frame.height)
        }
    }

    // MARK: - Collapse button runs

    /// Minimum run height (pts) for a quote run to earn a collapse affordance.
    static let collapseButtonMinRunHeight: CGFloat = 60
    /// Side length of the collapse button SF-Symbol square.
    static let collapseButtonSize: CGFloat = 18

    /// Per EXPANDED quote run that is tall enough to be worth collapsing: the first block's index and the
    /// top-right button rect (canvas coords). Collapsed quotes and short runs yield nothing. (Legacy parity:
    /// a quote shorter than the threshold reads fine expanded; only a tall run gets a collapse affordance.)
    func collapseButtonRuns() -> [(blockIndex: Int, rect: CGRect)] {
        var result: [(blockIndex: Int, rect: CGRect)] = []
        var runStart: Int?
        var runRect: CGRect?
        func flush() {
            guard let start = runStart, let f = runRect else { runStart = nil; runRect = nil; return }
            if f.height >= DocumentCanvasView.collapseButtonMinRunHeight {
                let s = DocumentCanvasView.collapseButtonSize
                let rect = CGRect(x: f.maxX - 2 - s,
                                  y: f.minY + 2, width: s, height: s)
                result.append((blockIndex: start, rect: rect))
            }
            runStart = nil; runRect = nil
        }
        for (i, box) in boxes.enumerated() {
            if let p = box as? BlockBox, p.style == .quote {
                if runStart == nil { runStart = i }
                runRect = runRect.map { $0.union(p.frame) } ?? p.frame
            } else {
                flush()
            }
        }
        flush()
        return result
    }
}

@available(iOS 13.0, *)
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
