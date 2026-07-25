import Foundation
import TelegramCore
import AccountContext
import TextFormat
import BrowserUI

/// Parses pasted plain text as CommonMark markdown (the same parser used on the rich-message send path)
/// and returns a `ChatInputContent` when the result carries formatting or structure that ordinary
/// plain-text paste would not already produce. Returns nil when:
///   - the text is unparseable / empty / iOS < 15 (`inputRichTextAttributeFromText` returns nil), or
///   - the parsed content is nothing but unformatted body paragraphs (`pastedMarkdownContentIsRicherThanPlain`).
/// Hosts convert the returned content to a `Document` (native editor) or an attributed string (legacy
/// field) with modules they already depend on.
func chatInputContentFromPastedMarkdown(context: AccountContext, plainText: String) -> ChatInputContent? {
    guard let attribute = inputRichTextAttributeFromText(context: context, text: plainText) else {
        return nil
    }
    let content = chatInputContent(fromInstantPage: attribute.instantPage)
    guard pastedMarkdownContentIsRicherThanPlain(content) else {
        return nil
    }
    return content
}
