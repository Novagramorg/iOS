import Foundation
import TelegramCore
import TextFormat
import RichTextEditorCore

/// Build a normal message (text + entities) from entity-expressible blocks (body/quote paragraphs).
func buildEntityMessage(from blocks: [Block]) -> (text: String, entities: [MessageTextEntity]) {
    let result = NSMutableAttributedString()
    let marker = true as NSNumber
    var isFirstParagraph = true

    for block in blocks {
        guard case let .paragraph(paragraph) = block else {
            continue
        }
        if !isFirstParagraph {
            result.append(NSAttributedString(string: "\n"))
        }
        isFirstParagraph = false

        let paragraphStart = result.length
        for run in paragraph.runs {
            let text: String
            if let emoji = run.attributes.emoji {
                text = emoji.altText ?? ""
            } else {
                text = run.text
            }
            if text.isEmpty {
                continue
            }
            let piece = NSMutableAttributedString(string: text)
            let range = NSRange(location: 0, length: piece.length)
            let attributes = run.attributes
            if attributes.bold {
                piece.addAttribute(ChatTextInputAttributes.bold, value: marker, range: range)
            }
            if attributes.italic {
                piece.addAttribute(ChatTextInputAttributes.italic, value: marker, range: range)
            }
            if attributes.inlineCode {
                piece.addAttribute(ChatTextInputAttributes.monospace, value: marker, range: range)
            }
            if attributes.strikethrough {
                piece.addAttribute(ChatTextInputAttributes.strikethrough, value: marker, range: range)
            }
            if attributes.underline {
                piece.addAttribute(ChatTextInputAttributes.underline, value: marker, range: range)
            }
            if attributes.spoiler {
                piece.addAttribute(ChatTextInputAttributes.spoiler, value: marker, range: range)
            }
            if let link = attributes.link {
                piece.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: link), range: range)
            }
            result.append(piece)
        }

        if paragraph.style == .quote {
            let length = result.length - paragraphStart
            if length > 0 {
                result.addAttribute(
                    ChatTextInputAttributes.block,
                    value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
                    range: NSRange(location: paragraphStart, length: length)
                )
            }
        }
    }

    let entities = generateChatInputTextEntities(result)
    return (result.string, entities)
}
