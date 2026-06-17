#if canImport(UIKit)
import UIKit

/// A **TextKit 1** implementation of `BlockLayoutEngine` for the iOS-15/16 back-port.
///
/// Uses `NSLayoutManager` + `NSTextStorage` + `NSTextContainer` — all available since iOS 7 — so this
/// type carries **no `@available` gate** (cf. `BlockLayout`, gated `@available(iOS 13.0, *)`): the
/// per-paragraph layout engine needs no TextKit 2 / iOS 17.
///
/// Mapping vs the TextKit 2 original:
/// - `enumerateTextSegments(.selection)` → `enumerateEnclosingRects(forGlyphRange:…)`;
/// - `enumerateTextLayoutFragments` height → `usedRect(for:)`;
/// - caret/baseline geometry → `lineFragmentRect` + `location(forGlyphAt:)` + `extraLineFragmentRect`.
///
/// **Display-only foreground (ghost + spoiler-hide) is intentionally disabled here.** TextKit 2's
/// rendering attributes have NO UIKit TextKit-1 analog (`add/removeTemporaryAttribute` is AppKit-only),
/// and the two features that need it — the inline-prediction ghost (an iOS-17 API, absent on 15/16) and
/// spoiler text-hiding — are accepted losses on the TK1 path. The methods only track ranges + bump
/// `renderVersion` to satisfy the change-detection contract; nothing is recolored.
final class BlockLayoutTK1: BlockLayoutEngine {
    let textStorage: NSTextStorage
    let layoutManager: NSLayoutManager
    let container: NSTextContainer

    private(set) var renderVersion = 0
    private var ghostRange: NSRange?
    private var spoilerRanges: [NSRange] = []

    init(attributedString: NSAttributedString, width: CGFloat) {
        textStorage = NSTextStorage(attributedString: attributedString)
        layoutManager = NSLayoutManager()
        container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
    }

    var attributedString: NSAttributedString {
        get { textStorage }
        set {
            textStorage.setAttributedString(newValue); renderVersion &+= 1
            ghostRange = nil; spoilerRanges = []
        }
    }

    func bumpRenderVersion() { renderVersion &+= 1 }

    var length: Int { textStorage.length }

    var backingStorage: NSTextStorage? { textStorage }
    var containerWidth: CGFloat { container.size.width }

    func setWidth(_ width: CGFloat) {
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
    }

    var boundingHeight: CGFloat {
        layoutManager.ensureLayout(for: container)
        return layoutManager.usedRect(for: container).height
    }

    /// Baseline of the first laid-out line relative to the layout top. `location(forGlyphAt:).y` is the
    /// glyph baseline measured from the line-fragment origin, so `lineRect.minY + loc.y` is the absolute
    /// baseline — the TK1 analog of TK2's `fragment.minY + line.glyphOrigin.y`.
    var firstLineBaselineFromTop: CGFloat? {
        guard textStorage.length > 0 else { return nil }
        layoutManager.ensureLayout(for: container)
        guard layoutManager.numberOfGlyphs > 0 else { return nil }
        var lineRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: &lineRange)
        let loc = layoutManager.location(forGlyphAt: 0)
        return lineRect.minY + loc.y
    }

    func caretRect(atOffset offset: Int) -> CGRect {
        let fallback = CGRect(x: 0, y: 0, width: 2, height: 20)
        layoutManager.ensureLayout(for: container)
        let count = textStorage.length

        // Empty text, or caret on a trailing empty line after a final newline: the extra line fragment.
        if count == 0 || offset >= count {
            let extra = layoutManager.extraLineFragmentRect
            if extra.height > 0 {
                return CGRect(x: extra.minX, y: extra.minY, width: 2, height: max(extra.height, 20))
            }
        }
        if count == 0 { return fallback }

        if offset >= count {
            // Caret at end (no trailing newline): trailing edge of the last glyph on its line.
            let lastGlyph = layoutManager.numberOfGlyphs - 1
            guard lastGlyph >= 0 else { return fallback }
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: &lineRange)
            let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1),
                                                       in: container)
            return CGRect(x: glyphRect.maxX, y: lineRect.minY, width: 2, height: max(lineRect.height, 20))
        }

        // Caret before the character at `offset`.
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: offset)
        var lineRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
        let loc = layoutManager.location(forGlyphAt: glyphIndex)
        return CGRect(x: lineRect.minX + loc.x, y: lineRect.minY, width: 2, height: max(lineRect.height, 20))
    }

    func selectionRects(start: Int, end: Int) -> [CGRect] {
        guard start < end else { return [] }
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: start, length: end - start),
                                                  actualCharacterRange: nil)
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                              withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: container) { rect, _ in rects.append(rect) }
        return rects
    }

    /// UITextView-style wash rects: same per-line enumeration as `selectionRects`, then the identical
    /// leading/trailing-edge extension math as the TK2 original.
    func selectionFillRects(start: Int, end: Int, fillTrailingLine: Bool) -> [CGRect] {
        let segs = selectionRects(start: start, end: end)
        guard !segs.isEmpty else { return [] }
        let edge = container.size.width
        let coveredFromStart = (start == 0)
        return segs.enumerated().map { i, seg in
            let toLeadingEdge = (i > 0) || coveredFromStart
            let toTrailingEdge = (i < segs.count - 1) || fillTrailingLine
            let left = toLeadingEdge ? min(seg.minX, 0) : seg.minX
            let right = toTrailingEdge ? max(seg.maxX, edge) : seg.maxX
            return CGRect(x: left, y: seg.minY, width: right - left, height: seg.height)
        }
    }

    func attachmentBox(at offset: Int) -> CGRect? {
        guard offset >= 0, offset + 1 <= textStorage.length,
              let attachment = textStorage.attribute(.attachment, at: offset, effectiveRange: nil) as? NSTextAttachment
        else { return nil }
        layoutManager.ensureLayout(for: container)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: offset)
        let runFont = (textStorage.attribute(.font, at: offset, effectiveRange: nil) as? UIFont)
            ?? UIFont.preferredFont(forTextStyle: .body)
        // Baseline of the attachment's line, taken from a TEXT glyph on that line. The emoji view must sit on
        // the SAME baseline TextKit draws the neighbouring text at (`lineFragmentRect.minY +
        // location(forGlyphAt:).y`). It must NOT be read from the attachment glyph's own `location.y` — for
        // an attachment that y tracks the box bottom (offset by the descender), which floats the emoji down —
        // nor reconstructed from the used rect + ascender, which top-aligns it (TK1 places the baseline lower
        // within a `lineHeightMultiple` line; TK2 centres, hence the two engines differ — we follow OUR text).
        var lineGlyphRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
        var baseline = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil).minY
            + runFont.ascender                                  // fallback: a lone-attachment line (no text)
        for g in lineGlyphRange.location ..< (lineGlyphRange.location + lineGlyphRange.length) {
            let ci = layoutManager.characterIndexForGlyph(at: g)
            if textStorage.attribute(.attachment, at: ci, effectiveRange: nil) == nil {
                baseline = lineRect.minY + layoutManager.location(forGlyphAt: g).y
                break
            }
        }
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                                   in: container)
        // TK1 attachment-bounds API (iOS 7+), no NSTextLocation. EmojiTextAttachment overrides this variant
        // (alongside the TK2 one), so emoji size to the run font here too.
        let bounds = attachment.attachmentBounds(for: container, proposedLineFragment: lineRect,
                                                 glyphPosition: CGPoint(x: glyphRect.minX, y: baseline),
                                                 characterIndex: offset)
        var box = CGRect(x: glyphRect.minX + bounds.minX, y: baseline - bounds.maxY,
                         width: bounds.width, height: bounds.height)
        if let boost = (attachment as? EmojiTextAttachment)?.renderBoost, boost > 0 {
            box = box.insetBy(dx: -boost / 2, dy: -boost / 2)
        }
        return box
    }

    func closestOffset(toPoint point: CGPoint) -> Int {
        let ns = attributedString.string as NSString
        var best = 0
        var bestDy = CGFloat.greatestFiniteMagnitude
        var bestDx = CGFloat.greatestFiniteMagnitude
        for offset in 0...length {
            // Skip offsets INSIDE a composed character sequence (a surrogate-pair / ZWJ / variation-selector
            // emoji is ONE caret stop). A mid-cluster caret would let a later insert/delete split the cluster,
            // leaving a stray code unit (the "service character"). Endpoints (0, length) are always stops.
            if offset > 0, offset < length, ns.rangeOfComposedCharacterSequence(at: offset).location != offset {
                continue
            }
            let caret = caretRect(atOffset: offset)
            let dy = point.y < caret.minY ? caret.minY - point.y
                   : point.y > caret.maxY ? point.y - caret.maxY : 0
            let dx = abs(caret.midX - point.x)
            if dy < bestDy - 0.5 || (dy <= bestDy + 0.5 && dx < bestDx) {
                bestDy = dy; bestDx = dx; best = offset
            }
        }
        return best
    }

    func drawText(in ctx: CGContext, at origin: CGPoint) {
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(for: container)
        UIGraphicsPushContext(ctx)
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        ctx.restoreGState()
        UIGraphicsPopContext()
    }

    func replace(start: Int, end: Int, with string: NSAttributedString) {
        textStorage.replaceCharacters(in: NSRange(location: start, length: end - start), with: string)
        renderVersion &+= 1
        ghostRange = nil; spoilerRanges = []
    }

    // Display-only foreground is disabled on TK1 (see the type doc). Track + bump only.
    func setGhostForeground(_ color: UIColor?, start: Int, end: Int) {
        ghostRange = nil
        renderVersion &+= 1
        guard color != nil, start < end else { return }
        ghostRange = NSRange(location: start, length: end - start)
    }

    @discardableResult
    func setSpoilerHidden(_ ranges: [NSRange]) -> Bool {
        let effective = ranges.filter { $0.length > 0 }
        if effective == spoilerRanges { return false }
        spoilerRanges = effective
        renderVersion &+= 1
        return true
    }
}
#endif
