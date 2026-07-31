#if canImport(UIKit)
import UIKit
import RichTextEditorCore

extension DocumentCanvasView {
    /// Private pasteboard UTI carrying a JSON-encoded `Document` fragment (full within-app fidelity).
    /// Aliases the public `RichTextEditorClipboard.fragmentUTI` so the format has one source of truth.
    static let richTextFragmentUTI = RichTextEditorClipboard.fragmentUTI

    func clipboardCanPerformAction(_ action: Selector) -> Bool {
        switch action {
        case #selector(copy(_:)), #selector(cut(_:)):
            return selFrom < selTo
        case #selector(paste(_:)):
            return pasteboard.contains(pasteboardTypes: [Self.richTextFragmentUTI, "public.rtf"]) || pasteboard.hasStrings || (canPasteMedia?() ?? false)
        default:
            return false
        }
    }

    @objc override func copy(_ sender: Any?) {
        guard selFrom < selTo else { return }
        writeSelectionToPasteboard(globalFrom: selFrom, globalTo: selTo)
    }

    @objc override func cut(_ sender: Any?) {
        guard selFrom < selTo, let range = selectedTextRange else { return }
        writeSelectionToPasteboard(globalFrom: selFrom, globalTo: selTo)
        replace(range, withText: "")
    }

    /// Writes the three pasteboard representations for the selection atomically (via the public façade,
    /// the single source of truth for the format — see `RichTextEditorClipboard`).
    /// The plain rep is derived from the fragment via `externalChecklistPlainText` (so checklist items
    /// carry their emoji prefix); when the fragment is empty (e.g. a cross-cell table selection whose
    /// blocks `extractFragment` skips) we fall back to `text(in: selectedTextRange)` to preserve the
    /// pre-existing cross-cell concatenation behavior.
    private func writeSelectionToPasteboard(globalFrom: Int, globalTo: Int) {
        let fragment = Document(blocks: currentBlocks()).extractFragment(globalFrom: globalFrom, globalTo: globalTo)
        let plain: String? = fragment.blocks.isEmpty
            ? selectedTextRange.flatMap { text(in: $0) }
            : nil   // nil → pasteboardItem derives from fragment via externalChecklistPlainText
        pasteboard.setItems([RichTextEditorClipboard.pasteboardItem(for: fragment, plain: plain)], options: [:])
    }

    @objc override func paste(_ sender: Any?) {
        // Plain text a host transforms to rich content (markdown) → TWO-STEP paste: insert the raw plain
        // text as one undo step, then replace it with the rich content as a second, so the first undo
        // reverts rich→plain and a further undo removes it. Only when the pasteboard carries NO richer
        // representation (a fragment/RTF paste keeps its own single-step path below).
        if !pasteboardHasRichTextRepresentation(pasteboard),
           let s = pasteboard.string, !s.isEmpty,
           let transformer = plainTextFragmentTransformer,
           let rich = transformer(s), !rich.blocks.isEmpty {
            pasteMarkdownTwoStep(plainText: s, rich: rich)
            return
        }
        if let fragment = fragment(fromPasteboard: pasteboard) { pasteFragment(fragment); return }
        _ = onPasteMedia?()   // no text rep → let the host route media (image/gif/video/sticker) to send
    }

    private func pasteboardHasRichTextRepresentation(_ pb: TextPasteboard) -> Bool {
        return pb.data(forPasteboardType: Self.richTextFragmentUTI) != nil
            || pb.data(forPasteboardType: "public.rtf") != nil
            || pb.data(forPasteboardType: "com.apple.flat-rtfd") != nil
    }

    /// The richest fragment available on the pasteboard: private UTI → RTF → plain text.
    func fragment(fromPasteboard pb: TextPasteboard) -> Document? {
        if let data = pb.data(forPasteboardType: Self.richTextFragmentUTI),
           let frag = try? DocumentCodec.decode(data) {
            return frag
        }
        if let data = pb.data(forPasteboardType: "public.rtf"),
           let frag = RTFConversion.fragment(fromRTF: data) {
            return frag
        }
        if let data = pb.data(forPasteboardType: "com.apple.flat-rtfd"),
           let frag = RTFConversion.fragment(fromRTF: data) {
            return frag
        }
        if let s = pb.string, !s.isEmpty {
            return plainTextFragment(s)
        }
        return nil
    }

    /// A multi-paragraph fragment from plain text — one paragraph per line (CRLF normalized first).
    /// Lines beginning with ⬜ or ✅ (per `ChecklistEmojiMarker.strippingMarker`) are decoded as
    /// checklist paragraphs; all other lines become plain body paragraphs.
    func plainTextFragment(_ s: String) -> Document {
        let lines = s.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return Document(blocks: lines.map { line in
            if let det = ChecklistEmojiMarker.strippingMarker(line) {
                return .paragraph(ParagraphBlock(id: .generate(),
                    list: ListMembership(marker: .checklist, level: 0, checked: det.checked),
                    runs: det.remainder.isEmpty ? [] : [TextRun(text: det.remainder)]))
            }
            return .paragraph(ParagraphBlock(id: .generate(), runs: line.isEmpty ? [] : [TextRun(text: line)]))
        })
    }

    /// Splices a `Document` fragment at the current selection as ONE undo step. Reuses the existing
    /// edit engine to delete the selection, then the Core `insertingFragment` model splice.
    func pasteFragment(_ fragment: Document) {
        guard !fragment.blocks.isEmpty else { return }
        editing { _ = spliceFragmentInEditing(fragment) }
    }

    /// Deletes any selection and splices `fragment` at the caret, returning the inserted global range
    /// `[start, end)`. MUST be called inside an `editing { }` block — the caller owns the undo step.
    @discardableResult
    func spliceFragmentInEditing(_ fragment: Document) -> (start: Int, end: Int) {
        // 1. delete the selection (grapheme-safe, cross-region) → collapsed caret at selFrom.
        if selFrom < selTo {
            applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "")
        }
        let caret = head
        // 2. splice on the model.
        let doc = Document(blocks: currentBlocks())
        // A freshly-latched chat composer can report `head == 0` — its selection was set before the canvas
        // built its layout boxes, so the flat→global map yielded 0 (below the first text start). That caret
        // can't be resolved, and the plain-text fallback below drops a table/media to "". Recover by
        // retrying at the nearest real text position; only genuinely non-text loci (a caret inside a table
        // cell / media caption) fall through to the flatten.
        if let result = doc.insertingFragment(fragment, atGlobal: caret) {
            setBlocks(result.document.blocks, width: effectiveWidth)
            anchor = min(result.caret, documentSize)
            head = anchor
            return (caret, result.caret)
        }
        if let near = doc.nearestTopLevelTextPosition(to: caret),
           let result = doc.insertingFragment(fragment, atGlobal: near) {
            setBlocks(result.document.blocks, width: effectiveWidth)
            anchor = min(result.caret, documentSize)
            head = anchor
            return (near, result.caret)
        }
        // Fallback: caret not in a top-level paragraph/code region (e.g. a table cell).
        // Flatten to plain text — newlines stripped, since applyReplace requires newline-free
        // text (paragraph breaks are structural; a code block's interior "\n"s must not leak into a run).
        let flat = fragment.blocks.map(blockPlainText).joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
        applySelectionReplace(globalFrom: caret, globalTo: caret, text: flat)
        return (caret, head)
    }

    /// Two-step paste for a host markdown transform: inserts the raw `plainText` as one undo step, then
    /// replaces that inserted range with `rich` as a SECOND undo step — so one undo reverts rich→plain and
    /// a further undo removes the paste entirely.
    ///
    /// Step 2 is deferred to the NEXT run-loop cycle deliberately: the editor's `UndoManager` uses the default
    /// `groupsByEvent`, which coalesces EVERY undo registration made within a single run-loop event into one
    /// group. Doing both edits synchronously would therefore make a single undo remove the whole paste instead
    /// of first reverting rich→plain. Running step 2 in a fresh event puts it in its own undo group.
    func pasteMarkdownTwoStep(plainText: String, rich: Document) {
        guard !rich.blocks.isEmpty else { return }
        let plain = plainTextFragment(plainText)
        guard !plain.blocks.isEmpty else { return }
        var range = (start: 0, end: 0)
        // Step 1 mutates the model + registers its undo group but does NOT notify the host, so the raw-text
        // state is never laid out / drawn (no flash). Step 2 next cycle does the visible, host-notifying edit.
        suppressHostChangeNotification = true
        editing { range = spliceFragmentInEditing(plain) }        // step 1: raw plain text (this event)
        suppressHostChangeNotification = false
        DispatchQueue.main.async { [weak self] in                 // step 2: replace with rich (next event)
            guard let self else { return }
            let size = self.documentSize
            let lo = max(0, min(range.start, size))
            let hi = max(lo, min(range.end, size))
            guard lo < hi else { return }
            self.replaceRange(globalFrom: lo, globalTo: hi, with: rich)
        }
    }
}
#endif
