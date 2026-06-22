#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// One top-level paragraph's text region, tagged with its start offset in the composer's flat string.
    private struct ComposerParagraph { let globalStart: Int; let length: Int; let flatStart: Int }

    /// The document's top-level text blocks (paragraphs + code blocks) in order, each with its start
    /// offset in the composer's flat UTF-16 string — the blocks' text joined by "\n", exactly the
    /// representation `ComposerDocumentBridge` flattens to/from. Non-text blocks (tables/images) contribute
    /// nothing, matching the bridge.
    private func composerParagraphs() -> [ComposerParagraph] {
        var result: [ComposerParagraph] = []
        var flat = 0
        for box in boxes {
            guard (box is BlockBox || box is CodeBlockBox), let region = box.leafRegions().first else { continue }
            if !result.isEmpty { flat += 1 }   // the "\n" that joins this paragraph to the previous one
            result.append(ComposerParagraph(globalStart: region.globalStart, length: region.length, flatStart: flat))
            flat += region.length
        }
        return result
    }

    private func composerFlatOffset(forGlobal g: Int, in paragraphs: [ComposerParagraph]) -> Int {
        for p in paragraphs where g >= p.globalStart && g <= p.globalStart + p.length {
            return p.flatStart + (g - p.globalStart)
        }
        // A structural slot outside any paragraph region (or an empty document): clamp to the flat end.
        if let last = paragraphs.last { return last.flatStart + last.length }
        return 0
    }

    private func composerGlobal(forFlat f: Int, in paragraphs: [ComposerParagraph]) -> Int {
        for p in paragraphs where f >= p.flatStart && f <= p.flatStart + p.length {
            return p.globalStart + (f - p.flatStart)
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
