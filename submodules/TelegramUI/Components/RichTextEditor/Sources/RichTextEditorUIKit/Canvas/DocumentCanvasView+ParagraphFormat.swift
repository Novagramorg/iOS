#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Paragraph-level formatting commands. They apply to every top-level `BlockBox` the selection
/// touches (a collapsed caret = its one paragraph), mutate the box's `style` / `paragraphAttributes`,
/// and run inside `editing { }` for undo. Top-level only in 5a — paragraph styles inside table cells
/// (headings in cells aren't meaningful GFM) are out of scope.
@available(iOS 17.0, *)
extension DocumentCanvasView {
    /// Assigns a named paragraph style (Title/H1–H3/Body/Quote) to the touched paragraphs and rebuilds
    /// their run layout so the style's font (size/weight) actually applies. Run size/family pins are
    /// cleared so the style decides them; user bold/italic/strike/code and links are preserved.
    /// Title/headings are regular-weight by default (StyleSheet.font no longer forces bold), so bold is a
    /// pure user toggle that round-trips uniformly — a heading→body down-convert carries no residual bold.
    func setParagraphStyle(_ name: ParagraphStyleName) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let lo = p.textStart, hi = p.textStart + p.textLength
                guard selFrom <= hi && selTo >= lo else { continue }
                p.style = name
                var para = p.currentParagraph()
                para.runs = para.runs.map { run in
                    var a = run.attributes
                    a.fontSize = nil
                    a.fontFamily = nil
                    return TextRun(text: run.text, attributes: a)
                }
                p.layout.attributedString = mapper.attributedString(for: para)
            }
            recomputeSpans()
        }
    }

    /// Sets paragraph alignment on the touched paragraphs. Alignment is a pure paragraph-style
    /// property, so `restyle` (which re-applies `.paragraphStyle`) suffices — no font rebuild.
    func setAlignment(_ alignment: TextAlignment) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let lo = p.textStart, hi = p.textStart + p.textLength
                guard selFrom <= hi && selTo >= lo else { continue }
                p.paragraphAttributes.alignment = alignment
                restyle(p)
            }
            recomputeSpans()
        }
    }
}
#endif
