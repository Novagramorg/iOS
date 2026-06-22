#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The grey "Add caption" hint shown under an image while its caption is empty. `rect` spans the full
/// caption content width so a centered paragraph style centers the text horizontally.
@available(iOS 13.0, *)
struct CaptionPlaceholder { let text: String; let rect: CGRect; let font: UIFont }

/// A media-with-caption block: a host-supplied media view (resolved from `mediaID` via the canvas's
/// `mediaViewProvider`, positioned at `mediaRect()`) above an editable caption. Contributes
/// `captionLength + 5` tokens; the caption text begins at `nodeStart + 2` (after the media atom and the
/// caption paragraph's open token). The position `nodeStart` (before the atom) is a gap.
@available(iOS 13.0, *)
final class MediaBlockBox: CanvasBlock {
    let id: BlockID
    var mediaID: String
    var kind: MediaKind
    var naturalSize: Size2D
    var displayWidth: Double?
    var alignment: MediaAlignment
    let caption: BlockLayoutEngine
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    let verticalInset: CGFloat = 8
    let captionGap: CGFloat = 4
    /// The most-recently-set layout width (from `setWidth` or `init`). Used by `height`,
    /// `imageAreaHeight`, and `mediaRect` so they are correct before `frame` is assigned by
    /// `layoutSubviews`.
    private(set) var layoutWidth: CGFloat

    /// The caption renders centered. Render-only — NOT persisted: `currentBlock()` extracts only the
    /// caption runs, so alignment never enters the model (and markdown carries none).
    private static let captionParagraph = ParagraphAttributes(alignment: .center)

    /// The placeholder text shown while the caption is empty.
    private static let captionPlaceholderText = "Add caption"

    /// The full canvas width this image bleeds across: its content-strip frame width plus both page
    /// margins (the inverse of the inset top-level frame). The image draws edge-to-edge over this.
    private var canvasWidth: CGFloat { layoutWidth + CanvasMetrics.pageMargin * 2 }

    init(media block: MediaBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = block.id
        mediaID = block.mediaID
        kind = block.kind
        naturalSize = block.naturalSize
        displayWidth = block.displayWidth
        alignment = block.alignment
        self.mapper = mapper
        layoutWidth = max(width, 1)
        // The caption's paragraph id matches the media block's id — it only keys the paragraph style
        // here; `currentBlock()` extracts the caption runs, not this temporary paragraph's id.
        let captionPara = ParagraphBlock(id: block.id, style: .caption,
                                         paragraph: MediaBlockBox.captionParagraph,
                                         runs: block.caption)
        caption = makeBlockLayout(attributedString: mapper.attributedString(for: captionPara),
                                  width: max(width, 1))
    }

    // CanvasBlock — text region is the caption.
    var rendersAsBlockView: Bool { true }
    // The medium is now an overlay view (not drawn into the backing store), so the backing view only needs
    // to cover the caption (its own inset frame). The full-bleed medium is hosted in the canvas mediaOverlay.
    var blockViewFrame: CGRect { frame }
    var textLayout: BlockLayoutEngine { caption }
    var textLength: Int { caption.length }
    var nodeSize: Int { caption.length + 5 }
    var textStart: Int { nodeStart + 2 }
    var textRef: TextNodeRef { .caption(id) }

    func setWidth(_ width: CGFloat) {
        layoutWidth = max(width, 1)
        caption.setWidth(max(width, 1))
    }

    /// Displayed image size: `displayWidth` clamped to `maxWidth` (or fills `maxWidth` when no
    /// explicit `displayWidth`), aspect preserved from `naturalSize`.
    func imageDisplaySize(maxWidth: CGFloat) -> CGSize {
        let naturalW = CGFloat(naturalSize.width), naturalH = CGFloat(naturalSize.height)
        let targetW = displayWidth.map { min(CGFloat($0), maxWidth) } ?? maxWidth
        guard naturalW > 0, naturalH > 0 else { return CGSize(width: targetW, height: targetW * 0.5625) }
        return CGSize(width: targetW, height: naturalH * (targetW / naturalW))
    }

    var imageAreaHeight: CGFloat {
        imageDisplaySize(maxWidth: max(canvasWidth, 1)).height
    }

    /// One line of the caption's (body) font height, reserved only when the caption is EMPTY — TextKit 2
    /// lays out no fragment for empty text, so `caption.boundingHeight` is ~0 and the caption row would
    /// otherwise collapse. Mirrors `BlockBox.emptyLineHeight`. Keeps the "Add caption" line always visible.
    private var captionEmptyLineHeight: CGFloat {
        guard caption.length == 0 else { return 0 }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: MediaBlockBox.captionParagraph, list: nil)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        return font.lineHeight * mult
    }

    /// Width of the "Add caption" placeholder in the caption (body) font — used to align the empty-caption
    /// caret to the START (left edge) of the centered placeholder rather than the line's center.
    private var captionPlaceholderTextWidth: CGFloat {
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        return (MediaBlockBox.captionPlaceholderText as NSString).size(withAttributes: [.font: font]).width
    }

    var height: CGFloat {
        verticalInset + imageAreaHeight + captionGap
            + max(caption.boundingHeight, captionEmptyLineHeight) + verticalInset
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        // The image bleeds full-width — its area is sized at canvasWidth (= width + pageMargin*2, mirroring
        // the live `imageAreaHeight`) — while the caption lays out at the content `width`.
        let imageArea = imageDisplaySize(maxWidth: max(width + CanvasMetrics.pageMargin * 2, 1)).height
        return verticalInset + imageArea + captionGap
            + max(caption.boundingHeight(forWidth: max(width, 1)), captionEmptyLineHeight) + verticalInset
    }

    var textOrigin: CGPoint {
        CGPoint(x: frame.minX,
                y: frame.minY + verticalInset + imageAreaHeight + captionGap)
    }

    // NOTE: assumes a top-level image (bleeds past the page margin to the canvas edge). No command inserts an image into a table cell today; if that becomes possible, a nested image must skip the bleed.
    func mediaRect() -> CGRect {
        let avail = max(canvasWidth, 1)
        let size = imageDisplaySize(maxWidth: avail)
        let bleedX = frame.minX - CanvasMetrics.pageMargin
        let x: CGFloat
        switch alignment {
        case .left: x = bleedX
        case .center: x = bleedX + (avail - size.width) / 2
        case .right: x = bleedX + (avail - size.width)
        }
        return CGRect(x: x, y: frame.minY + verticalInset, width: size.width, height: size.height)
    }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        if point.y < textOrigin.y { return nodeStart }   // image area → gap before the atom
        let local = CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y)
        return textStart + caption.closestOffset(toPoint: local)
    }

    func currentBlock() -> Block {
        .media(MediaBlock(id: id, mediaID: mediaID, kind: kind, naturalSize: naturalSize, displayWidth: displayWidth,
                          alignment: alignment, caption: mapper.runs(from: caption.attributedString, style: .caption)))
    }

    func leafRegions() -> [LeafTextRegion] {
        // When the caption is empty, place its caret at the START (left edge) of the centered "Add caption"
        // placeholder — not the line center — so the caret sits just before the placeholder text rather than
        // bisecting it. The placeholder is centered in a layoutWidth-wide rect, so its left edge is
        // (layoutWidth - textWidth)/2 (clamped ≥ 0). TextKit lays out no fragment for empty text, so
        // caretRect(atOffset:0) falls back to x=0; the consumers (caretRect(for:)/updateCaretView) add this
        // offset. 0 once text exists — the glyph layout (centered) then positions the caret.
        let emptyOffset = caption.length == 0 ? max((layoutWidth - captionPlaceholderTextWidth) / 2, 0) : 0
        return [LeafTextRegion(layout: caption, globalStart: textStart, length: caption.length,
                               ref: .caption(id), canvasOrigin: textOrigin,
                               emptyLineLeadingIndent: emptyOffset, emptyLineHeight: captionEmptyLineHeight)]
    }

    /// Attributes for text typed into an EMPTY caption: body character attributes plus the render-only
    /// centered paragraph style. The caption renders centered, but that centering is render-only (not in
    /// the model), so an empty caption carries no run to inherit it from — without this, the first typed
    /// character would be left-aligned. Mirrors the empty-paragraph path in `typingAttributeDict`.
    func captionTypingAttributes() -> [NSAttributedString.Key: Any] {
        var attrs = mapper.attributes(for: CharacterAttributes(), style: .caption)
        attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: .caption,
                                                                  attributes: MediaBlockBox.captionParagraph, list: nil)
        return attrs
    }

    /// Non-nil only when the caption is EMPTY: a centered "Add caption" placeholder at the caption line.
    /// Drawn by THIS block (inside its `BlockBackingView`), not the canvas `placeholderDraws()` seam,
    /// because an image is view-backed (`rendersAsBlockView`) — its caption and placeholder must share
    /// the same render layer. Mirrors the paragraph placeholder's color/font.
    func captionPlaceholder() -> CaptionPlaceholder? {
        guard caption.length == 0 else { return nil }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let rect = CGRect(x: textOrigin.x, y: textOrigin.y, width: layoutWidth, height: captionEmptyLineHeight)
        return CaptionPlaceholder(text: MediaBlockBox.captionPlaceholderText, rect: rect, font: font)
    }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // The medium itself is now a host-supplied overlay view (positioned at `mediaRect()` by the canvas
        // media reconciler), so the backing store draws only the caption (+ its placeholder). `imageProvider`
        // is retained as the shared `CanvasBlock.draw` parameter but is unused here.
        caption.drawText(in: ctx, at: textOrigin)
        if let ph = captionPlaceholder() {
            // Use the caption's OWN paragraph style (centered + body line-height metrics) so the
            // placeholder is metrically identical to real caption text — same centering AND same baseline,
            // so nothing shifts vertically the instant the user types.
            let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: MediaBlockBox.captionParagraph, list: nil)
            NSAttributedString(string: ph.text, attributes: [
                .font: ph.font,
                .foregroundColor: mapper.theme.placeholder,
                .paragraphStyle: ps,
            ]).draw(in: ph.rect)
        }
    }
}
#endif
