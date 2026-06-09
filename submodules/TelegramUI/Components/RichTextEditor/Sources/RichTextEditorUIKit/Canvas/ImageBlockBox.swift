#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The grey "Add caption" hint shown under an image while its caption is empty. `rect` spans the full
/// caption content width so a centered paragraph style centers the text horizontally.
struct CaptionPlaceholder { let text: String; let rect: CGRect; let font: UIFont }

/// An image-with-caption block: a rendered image (resolved from `assetID` via the canvas's image
/// provider) above an editable caption. Contributes `captionLength + 5` tokens; the caption text
/// begins at `nodeStart + 2` (after the image atom and the caption paragraph's open token). The
/// position `nodeStart` (before the atom) is a gap.
final class ImageBlockBox: CanvasBlock {
    let id: BlockID
    var assetID: String
    var naturalSize: Size2D
    var displayWidth: Double?
    var alignment: ImageAlignment
    let caption: BlockLayout
    let mapper: AttributedStringMapper

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    let verticalInset: CGFloat = 8
    let captionGap: CGFloat = 4
    /// The most-recently-set layout width (from `setWidth` or `init`). Used by `height`,
    /// `imageAreaHeight`, and `imageRect` so they are correct before `frame` is assigned by
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

    init(image block: ImageBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = block.id
        assetID = block.assetID
        naturalSize = block.naturalSize
        displayWidth = block.displayWidth
        alignment = block.alignment
        self.mapper = mapper
        layoutWidth = max(width, 1)
        // The caption's paragraph id matches the image block's id — it only keys the paragraph style
        // here; `currentBlock()` extracts the caption runs, not this temporary paragraph's id.
        let captionPara = ParagraphBlock(id: block.id, style: .body,
                                         paragraph: ImageBlockBox.captionParagraph,
                                         runs: block.caption)
        caption = BlockLayout(attributedString: mapper.attributedString(for: captionPara),
                              width: max(width, 1))
    }

    // CanvasBlock — text region is the caption.
    var rendersAsBlockView: Bool { true }
    var blockViewFrame: CGRect { frame.union(imageRect()) }   // a full-bleed image draws past its inset frame
    var textLayout: BlockLayout { caption }
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
        let font = mapper.styleSheet.font(for: .body, attributes: .plain)
        let ps = mapper.styleSheet.paragraphStyle(for: .body, attributes: ImageBlockBox.captionParagraph, list: nil)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        return font.lineHeight * mult
    }

    /// Width of the "Add caption" placeholder in the caption (body) font — used to align the empty-caption
    /// caret to the START (left edge) of the centered placeholder rather than the line's center.
    private var captionPlaceholderTextWidth: CGFloat {
        let font = mapper.styleSheet.font(for: .body, attributes: .plain)
        return (ImageBlockBox.captionPlaceholderText as NSString).size(withAttributes: [.font: font]).width
    }

    var height: CGFloat {
        verticalInset + imageAreaHeight + captionGap
            + max(caption.boundingHeight, captionEmptyLineHeight) + verticalInset
    }

    var textOrigin: CGPoint {
        CGPoint(x: frame.minX,
                y: frame.minY + verticalInset + imageAreaHeight + captionGap)
    }

    // NOTE: assumes a top-level image (bleeds past the page margin to the canvas edge). No command inserts an image into a table cell today; if that becomes possible, a nested image must skip the bleed.
    func imageRect() -> CGRect {
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
        .image(ImageBlock(id: id, assetID: assetID, naturalSize: naturalSize, displayWidth: displayWidth,
                          alignment: alignment, caption: mapper.runs(from: caption.attributedString)))
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
        var attrs = mapper.attributes(for: CharacterAttributes(), style: .body)
        attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: .body,
                                                                  attributes: ImageBlockBox.captionParagraph, list: nil)
        return attrs
    }

    /// Non-nil only when the caption is EMPTY: a centered "Add caption" placeholder at the caption line.
    /// Drawn by THIS block (inside its `BlockBackingView`), not the canvas `placeholderDraws()` seam,
    /// because an image is view-backed (`rendersAsBlockView`) — its caption and placeholder must share
    /// the same render layer. Mirrors the paragraph placeholder's color/font.
    func captionPlaceholder() -> CaptionPlaceholder? {
        guard caption.length == 0 else { return nil }
        let font = mapper.styleSheet.font(for: .body, attributes: .plain)
        let rect = CGRect(x: textOrigin.x, y: textOrigin.y, width: layoutWidth, height: captionEmptyLineHeight)
        return CaptionPlaceholder(text: ImageBlockBox.captionPlaceholderText, rect: rect, font: font)
    }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        let rect = imageRect()
        if let image = imageProvider(assetID) { image.draw(in: rect) }
        else { UIColor.secondarySystemFill.setFill(); ctx.fill(rect) }
        caption.drawText(in: ctx, at: textOrigin)
        if let ph = captionPlaceholder() {
            // Use the caption's OWN paragraph style (centered + body line-height metrics) so the
            // placeholder is metrically identical to real caption text — same centering AND same baseline,
            // so nothing shifts vertically the instant the user types.
            let ps = mapper.styleSheet.paragraphStyle(for: .body, attributes: ImageBlockBox.captionParagraph, list: nil)
            NSAttributedString(string: ph.text, attributes: [
                .font: ph.font,
                .foregroundColor: UIColor.placeholderText,
                .paragraphStyle: ps,
            ]).draw(in: ph.rect)
        }
    }
}
#endif
