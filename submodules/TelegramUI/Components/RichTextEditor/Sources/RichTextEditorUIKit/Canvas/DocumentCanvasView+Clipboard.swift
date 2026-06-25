#if canImport(UIKit)
import UIKit
import RichTextEditorCore

extension DocumentCanvasView {
    /// Private pasteboard UTI carrying a JSON-encoded `Document` fragment (full within-app fidelity).
    static let richTextFragmentUTI = "org.telegram.richtexteditor.fragment"

    func clipboardCanPerformAction(_ action: Selector) -> Bool {
        switch action {
        case #selector(copy(_:)), #selector(cut(_:)):
            return selFrom < selTo
        case #selector(paste(_:)):
            return pasteboard.contains(pasteboardTypes: [Self.richTextFragmentUTI, "public.rtf"]) || pasteboard.hasStrings
        default:
            return false
        }
    }

    @objc override func copy(_ sender: Any?) {
        guard selFrom < selTo, let range = selectedTextRange else { return }
        writeSelectionToPasteboard(globalFrom: selFrom, globalTo: selTo, plain: text(in: range))
    }

    @objc override func cut(_ sender: Any?) {
        guard selFrom < selTo, let range = selectedTextRange else { return }
        writeSelectionToPasteboard(globalFrom: selFrom, globalTo: selTo, plain: text(in: range))
        replace(range, withText: "")
    }

    /// Writes the three pasteboard representations for the selection atomically.
    private func writeSelectionToPasteboard(globalFrom: Int, globalTo: Int, plain: String?) {
        let fragment = Document(blocks: currentBlocks()).extractFragment(globalFrom: globalFrom, globalTo: globalTo)
        var item: [String: Any] = [:]
        if let data = try? DocumentCodec.encode(fragment) { item[Self.richTextFragmentUTI] = data }
        if let rtf = RTFConversion.rtfData(from: fragment) { item["public.rtf"] = rtf }
        if let plain = plain { item["public.utf8-plain-text"] = plain }
        pasteboard.setItems([item], options: [:])
    }

    @objc override func paste(_ sender: Any?) {
        guard let fragment = fragment(fromPasteboard: pasteboard) else { return }
        pasteFragment(fragment)
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
        if let s = pb.string, !s.isEmpty {
            return plainTextFragment(s)
        }
        return nil
    }

    /// A multi-paragraph fragment from plain text — one paragraph per line (CRLF normalized first).
    func plainTextFragment(_ s: String) -> Document {
        let lines = s.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return Document(blocks: lines.map {
            .paragraph(ParagraphBlock(id: .generate(), runs: $0.isEmpty ? [] : [TextRun(text: $0)]))
        })
    }

    /// Splices a `Document` fragment at the current selection as ONE undo step. Reuses the existing
    /// edit engine to delete the selection, then the Core `insertingFragment` model splice.
    func pasteFragment(_ fragment: Document) {
        guard !fragment.blocks.isEmpty else { return }
        editing {
            // 1. delete the selection (grapheme-safe, cross-region) → collapsed caret at selFrom.
            if selFrom < selTo {
                applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "")
            }
            let caret = head
            // 2. splice on the model.
            let doc = Document(blocks: currentBlocks())
            if let result = doc.insertingFragment(fragment, atGlobal: caret) {
                setBlocks(result.document.blocks, width: effectiveWidth)
                anchor = min(result.caret, documentSize)
                head = anchor
            } else {
                // Fallback: caret not in a top-level paragraph/code region (e.g. a table cell).
                // Flatten to plain text — newlines stripped, since applyReplace requires newline-free
                // text (paragraph breaks are structural; a code block's interior "\n"s must not leak into a run).
                let flat = fragment.blocks.map(blockPlainText).joined(separator: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                applySelectionReplace(globalFrom: caret, globalTo: caret, text: flat)
            }
        }
    }
}
#endif
