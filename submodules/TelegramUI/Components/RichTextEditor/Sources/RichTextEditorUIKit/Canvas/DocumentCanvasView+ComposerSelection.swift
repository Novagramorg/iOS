#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// One custom-emoji occurrence inside a paragraph region: `localOffset` is its global-axis offset within
    /// the region (the editor counts it as 1 `U+FFFC`); `altLen` is its alt-string UTF-16 length (> 1), which
    /// the chat flat space counts instead.
    private struct ComposerEmoji { let localOffset: Int; let altLen: Int }

    /// One top-level paragraph's text region. `length` is the editor (global-axis) length (custom emoji = 1);
    /// `flatLength` is the chat flat length (custom emoji = its alt-string UTF-16 length); `flatStart` is the
    /// region's start in the composer's flat string. `emoji` are the region's custom-emoji occurrences, sorted.
    private struct ComposerParagraph {
        let globalStart: Int; let length: Int; let flatLength: Int; let flatStart: Int; let emoji: [ComposerEmoji]
    }

    /// Custom-emoji occurrences in a region, read the same way `syncEmojiViews` does (an `EmojiTextAttachment`
    /// over a one-`U+FFFC` run). Only emoji with an alt-string longer than 1 UTF-16 unit expand the flat space;
    /// a nil/empty/1-unit altText stays 1 (a fileId-only seeded ref falls back to the prior behavior).
    private func composerEmojiOccurrences(in region: LeafTextRegion) -> [ComposerEmoji] {
        var result: [ComposerEmoji] = []
        let attr = region.layout.attributedString
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, range, _ in
            guard let att = value as? EmojiTextAttachment, let alt = att.ref.altText else { return }
            let altLen = (alt as NSString).length
            if altLen > 1 { result.append(ComposerEmoji(localOffset: range.location, altLen: altLen)) }
        }
        return result.sorted { $0.localOffset < $1.localOffset }
    }

    /// The document's top-level text blocks (paragraphs + code blocks) in order, each tagged with its start
    /// offset in the composer's flat UTF-16 string — the blocks' text joined by "\n", with each custom emoji
    /// expanded to its alt-string length. Non-text blocks (tables/images) contribute nothing, matching the bridge.
    private func composerParagraphs() -> [ComposerParagraph] {
        var result: [ComposerParagraph] = []
        var flat = 0
        for box in boxes {
            guard (box is BlockBox || box is CodeBlockBox), let region = box.leafRegions().first else { continue }
            if !result.isEmpty { flat += 1 }   // the "\n" that joins this paragraph to the previous one
            let emoji = composerEmojiOccurrences(in: region)
            let flatLength = region.length + emoji.reduce(0) { $0 + ($1.altLen - 1) }
            result.append(ComposerParagraph(globalStart: region.globalStart, length: region.length,
                                            flatLength: flatLength, flatStart: flat, emoji: emoji))
            flat += flatLength
        }
        return result
    }

    /// Global axis → composer flat axis. A custom emoji at region-local offset `e.localOffset` adds `altLen-1`
    /// flat units to every position *after* it (a global offset can only land before or after the `U+FFFC`).
    private func composerFlatOffset(forGlobal g: Int, in paragraphs: [ComposerParagraph]) -> Int {
        for p in paragraphs where g >= p.globalStart && g <= p.globalStart + p.length {
            let local = g - p.globalStart
            var flatLocal = local
            for e in p.emoji where e.localOffset < local { flatLocal += (e.altLen - 1) }
            return p.flatStart + flatLocal
        }
        if let last = paragraphs.last { return last.flatStart + last.flatLength }
        return 0
    }

    /// Composer flat axis → global axis (the setter direction). Walks each region's plain runs (1:1) and
    /// custom-emoji spans (`altLen` flat → 1 global); a flat offset landing *inside* an emoji's alt-string span
    /// snaps to the nearest `U+FFFC` boundary (never mid-atom — carets snap to grapheme boundaries upstream).
    private func composerGlobal(forFlat f: Int, in paragraphs: [ComposerParagraph]) -> Int {
        for p in paragraphs where f >= p.flatStart && f <= p.flatStart + p.flatLength {
            let flatLocal = f - p.flatStart
            var globalLocal = 0
            var flatCursor = 0
            for e in p.emoji {
                let plainLen = e.localOffset - globalLocal
                if flatLocal <= flatCursor + plainLen {
                    return p.globalStart + globalLocal + (flatLocal - flatCursor)
                }
                flatCursor += plainLen
                globalLocal = e.localOffset
                if flatLocal < flatCursor + e.altLen {
                    let into = flatLocal - flatCursor   // 1 ..< altLen
                    return p.globalStart + globalLocal + (into * 2 >= e.altLen ? 1 : 0)
                }
                flatCursor += e.altLen
                globalLocal += 1
            }
            return p.globalStart + globalLocal + (flatLocal - flatCursor)
        }
        if let last = paragraphs.last { return last.globalStart + last.length }
        return 0
    }

    /// The selection expressed in the chat composer's flat UTF-16 coordinate space (see `composerParagraphs`).
    /// The host (`RichTextEditorChatInputNode.selectedRange`) reads this to track the caret and writes it to
    /// move the caret after a programmatic insert/replace. The flat axis collapses the editor's global axis
    /// (which carries non-renderable structural slots between blocks) down to one "\n" per paragraph break,
    /// so a multi-UTF-16-unit emoji and the paragraph separators line up 1:1 with what the host inserts.
    var composerSelectedRange: NSRange {
        get {
            let paragraphs = composerParagraphs()
            guard !paragraphs.isEmpty else { return NSRange(location: 0, length: 0) }
            let lo = composerFlatOffset(forGlobal: selFrom, in: paragraphs)
            let hi = composerFlatOffset(forGlobal: selTo, in: paragraphs)
            return NSRange(location: lo, length: max(0, hi - lo))
        }
        set {
            finalizeMarkedText()
            clearStructuralSelections()
            let paragraphs = composerParagraphs()
            let a = composerGlobal(forFlat: newValue.location, in: paragraphs)
            let h = composerGlobal(forFlat: newValue.location + newValue.length, in: paragraphs)
            // Programmatic selection move — bracket it so the OS keeps a fresh `selectedTextRange`.
            textInputDelegate?.selectionWillChange(self)
            anchor = clampGlobal(a); head = clampGlobal(h)
            textInputDelegate?.selectionDidChange(self)
            setNeedsDisplay(); refreshSelectionUI(); onSelectionChange?()
        }
    }
}
#endif
