import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TextFormat
import TelegramCore
import RichTextEditorCore
import RichTextEditorUIKit
import ChatInputTextNode

/// `ChatRichTextInputNode` backend composing the TextKit-2 `RichTextEditorView`. Selected on iOS 17+
/// behind the `debugRichText` flag (see `ChatTextInputPanelNode.loadTextInputNode`). Phase 1 implements
/// display, layout, and editing; selection geometry, spoiler reveal, typing attributes, and the full
/// delegate suite are safe stubs (Phase 2+).
@available(iOS 13.0, *)
public final class RichTextEditorChatInputNode: ASDisplayNode, ChatRichTextInputNode {
    private let editorView = RichTextEditorView()
    private let baseFontSize: CGFloat = 17.0

    private var trackedInsets: UIEdgeInsets = .zero
    private var trackedContentMargins: UIEdgeInsets = .zero
    private var trackedRightInset: CGFloat = 0.0
    private weak var storedDelegate: ChatInputTextNodeDelegate?

    public var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)?

    /// fileId → the file-bearing custom-emoji attribute, harvested from each `attributedText` /
    /// `setInputContent` push. The editor hosts inline emoji by their `EmojiRef` fileId STRING only
    /// (`document(from:)` / `document(fromChatInputContent:)` drop the `TelegramMediaFile`), but the host
    /// renderer (`EmojiTextAttachmentView`) needs the file — so we cache the full attribute here and rebuild it
    /// for the editor's view provider. Mirrors `RichTextEmojiKeyboardController.emojiFiles`. Also the source the
    /// direct-bridge `resolveEmoji`/`registerEmoji` closures read/write (see `currentInputContent`/`setInputContent`).
    private var customEmojiAttributes: [Int64: ChatTextInputTextCustomEmojiAttribute] = [:]

    /// `MediaBlock.mediaID` → the concrete `Media` it stands for. The editor stores only the opaque host
    /// `mediaID` string (it never holds a `Media`), so the node owns the mapping — exactly as
    /// `RichTextAttachmentScreen.attachedMedia` does. Populated by the direct-bridge `registerMedia` closure
    /// from each `setInputContent` push and read back by `resolveMedia` in `currentInputContent`, so a medium
    /// the chat layer sets round-trips through the structural model. A medium the editor never received via this
    /// path (no entry) resolves to nil and its block is dropped — see `resolveMedia` below.
    private var mediaByID: [String: Media] = [:]

    public var asNode: ASDisplayNode { self }

    public override init() {
        super.init()
    }

    public override func didLoad() {
        super.didLoad()
        // Model A: this node is the wrapper (the panel frames `asNode` to fill the clipping container);
        // `editorView` is the inset child, positioned by the panel via `textFieldFrame`. They are distinct
        // views — exactly as the legacy impl keeps `textInputNodeImpl` a subnode of the wrapper.
        self.view.addSubview(self.editorView)

        // Compact-composer layout: the editor's document-editor defaults (a 16pt built-in page margin on each
        // side and a 44pt content-height floor) are wrong for a chat composer. The panel owns horizontal
        // insets (via the frame width + `textContainerInset` → `contentMargins`, which reserve the
        // accessory/send-button area) and the minimum field height, so zero both out — otherwise the field is
        // too tall (44pt floor vs the legacy ~text-height) and has an unexpected side inset.
        self.editorView.contentPageMargin = 0.0
        self.editorView.minimumContentHeight = 0.0
        // Zero the document inter-paragraph vertical gap (8pt each side): a lone composer paragraph should
        // hug its text height (~one line), not carry the document gap. The panel's own field padding
        // (textInputViewInternalInsets) provides the visual top/bottom breathing room.
        self.editorView.blockVerticalInset = 0.0
        // Suppress the editor's built-in placeholders ("Type something…" / list hints): the chat input panel
        // draws its own placeholder ("Message", etc.), so the editor's would double up.
        self.editorView.placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "")
        // The composer sits over the input panel's own background — clear the editor's document "page"
        // background (`.systemBackground`, opaque white in light mode) so the panel shows through. `nil`
        // (no background) rather than `.clear`: same transparency, but signals "unset" and avoids an
        // explicit clear-color fill.
        self.editorView.canvasBackgroundColor = nil

        // Seed an editable document. RichTextEditorView starts with ZERO blocks — its canvas is only
        // populated by the `document` setter (which normalizes an empty Document to a single empty body
        // paragraph). Every proven host (RichTextAttachmentScreen, the Demo) seeds a document at setup. We
        // MUST do it here too: our `attributedText` setter's composerContentEqual guard skips the panel's
        // initial empty push (""=="" → no-op), so without this the canvas would have no paragraph box to
        // insert into and typing would do nothing.
        self.editorView.document = Document()

        // Phase 1 delegate subset: the editor exposes onChange + the two focus transitions. The panel's
        // height/state refresh keys off chatInputTextNodeDidUpdateText (it then reads `attributedText`).
        // The remaining ChatInputTextNodeDelegate methods (chatInputTextNodeShouldReturn,
        // chatInputTextNodeDidChangeSelection, chatInputTextNodeBackspaceWhileEmpty, chatInputTextNodeMenu,
        // chatInputTextNode(shouldChangeTextIn:), chatInputTextNodeShouldCopy/Paste,
        // chatInputTextNodeShouldRespondToAction/TargetForAction) require new RichTextEditorView callbacks
        // and are deferred to Phase 2 — the editor handles selection/menu/return/backspace internally, so
        // omitting them only means the panel doesn't receive those hooks (acceptable for display/layout/editing).
        self.editorView.onChange = { [weak self] in
            guard let self else { return }
            // RichTextEditorView is parent-driven: it does NOT self-layout on a content change (unlike the
            // legacy UITextView backend, which renders its own edits). The host must call `update(...)` in
            // response to `onChange`, or inserted text is never laid out — it appears that "typing does
            // nothing". Re-lay it out here at the current committed size (mirrors RichTextAttachmentScreen's
            // onChange → re-run-layout). `update`/`performLayout` never fire `onChange` synchronously
            // (the editor's contract, covered by a regression test), so this cannot recurse. The panel's
            // delegate-driven layout pass still handles field-height growth separately.
            if self.editorView.bounds.width > 0.0 {
                _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins)
            }
            self.storedDelegate?.chatInputTextNodeDidUpdateText()
        }
        self.editorView.onBecameFirstResponder = { [weak self] in
            self?.storedDelegate?.chatInputTextNodeDidBeginEditing()
        }
        self.editorView.onResignedFirstResponder = { [weak self] in
            self?.storedDelegate?.chatInputTextNodeDidFinishEditing()
        }

        // Custom-emoji rendering. The editor hosts each inline emoji via this provider, asking by the
        // `EmojiRef` fileId string. Forward to the chat host's `emojiViewProvider` (set by the panel),
        // rebuilding the file-bearing `ChatTextInputTextCustomEmojiAttribute` from the cache harvested in
        // the `attributedText` setter — the editor carries only the fileId, but the renderer needs the
        // `TelegramMediaFile`. WITHOUT this, the editor's `canvas.emojiViewProvider` stays nil and an
        // inserted custom emoji renders blank (only its `U+FFFC` spacer is laid out). The closure reads
        // `self.emojiViewProvider` lazily, so the panel may set it after this registration. `size` is
        // ignored: the host renderer picks its own point size and the editor frames the returned view to
        // the glyph rect.
        self.editorView.registerEmojiViewProvider { [weak self] id, _ in
            guard let self, let fileId = Int64(id), let attribute = self.customEmojiAttributes[fileId],
                  let provider = self.emojiViewProvider else { return nil }
            return provider(attribute)
        }
    }

    // MARK: Display (Task 3)
    public var attributedText: NSAttributedString? {
        get { ComposerDocumentBridge.attributedString(from: self.editorView.document, baseFontSize: self.baseFontSize) }
        set {
            let incoming = newValue ?? NSAttributedString(string: "")
            // Harvest file-bearing custom-emoji attributes so the editor's fileId-only emoji-view provider
            // can rebuild them (`document(from:)` keeps only the fileId in the `EmojiRef`, dropping the
            // `TelegramMediaFile` the renderer needs). Done BEFORE the equality guard so the cache stays
            // current even when the document is not rebuilt. Only cache a file-BEARING attribute, so a later
            // file-less round-trip (the getter emits `file: nil`) never clobbers a resolved one.
            incoming.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: incoming.length), options: []) { value, _, _ in
                if let attribute = value as? ChatTextInputTextCustomEmojiAttribute, attribute.file != nil {
                    self.customEmojiAttributes[attribute.fileId] = attribute
                }
            }
            let current = ComposerDocumentBridge.attributedString(from: self.editorView.document, baseFontSize: self.baseFontSize)
            if ComposerDocumentBridge.composerContentEqual(incoming, current) {
                return
            }
            self.editorView.document = ComposerDocumentBridge.document(from: incoming)
        }
    }
    public var text: String {
        // Read plain text straight from the document model rather than round-tripping through the full
        // `Document → NSAttributedString` conversion — `text` is a hot path (the send-button counter
        // re-reads it on every keystroke). Body/quote paragraphs joined by "\n", matching the bridge's
        // Document→string flattening (non-paragraph blocks contribute nothing).
        return self.editorView.document.blocks.compactMap { block -> String? in
            if case let .paragraph(paragraph) = block {
                return paragraph.text
            }
            return nil
        }.joined(separator: "\n")
    }
    /// The editor's live structured document, used to seed an expanded editor with the current content.
    public var richTextDocument: Document? { self.editorView.document }

    /// Replace the editor's live document directly (NOT via `attributedText`, which would flatten
    /// structure beyond the `ChatTextInputAttributes` vocabulary, e.g. tables). Then run the same
    /// refresh `onChange` performs so the panel re-lays-out and re-reads content.
    public func setRichTextDocument(_ document: Document) {
        self.editorView.document = document
        if self.editorView.bounds.width > 0.0 {
            _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins)
        }
        self.storedDelegate?.chatInputTextNodeDidUpdateText()
    }

    // MARK: ChatInputContent model — the STRUCTURAL draft currency (direct bridge)

    /// The node's content as the canonical `ChatInputContent` value model. This is the chat layer's draft/state
    /// read-back (the panel's `inputTextState` reads it, NOT `attributedText`), so it MUST carry the structural
    /// blocks the `NSAttributedString` vocabulary can't express — media / tables / heading & list information.
    /// We convert the editor's live `Document` STRAIGHT to `ChatInputContent` via the direct bridge
    /// (`chatInputContent(fromDocument:)`), bypassing the lossy `Document → NSAttributedString` hop the default
    /// protocol implementation (and the legacy `attributedText` getter) take. The resolvers map the editor's
    /// opaque host keys to concrete chat-layer values: an unresolvable emoji degrades to plain text and an
    /// unresolvable medium is dropped (see `resolveEmojiRef`/`resolveMediaID`). The selection rides the editor's
    /// flat composer coordinate space (`selectedRange`), mapped into the content's structural selection — the
    /// same mapping the default implementation uses.
    public func currentInputContent() -> (content: ChatInputContent, selection: ChatInputSelection) {
        let content = chatInputContent(
            fromDocument: self.editorView.document,
            resolveEmoji: { [weak self] emojiRef in self?.resolveEmojiRef(emojiRef) ?? nil },
            resolveMedia: { [weak self] mediaID in self?.resolveMediaID(mediaID) ?? nil }
        )
        return (content, ChatInputSelection(nsRange: self.selectedRange, in: content))
    }

    /// Replace the editor's content from a `ChatInputContent`. This is the chat layer's structural SET path
    /// (draft restore, send-clear, spoiler re-decorate): it MUST land the structural blocks back into the editor
    /// `Document`, so we convert STRAIGHT via the direct bridge (`document(fromChatInputContent:)`) rather than
    /// through the flattening `attributedText` setter. The registrars hand the chat-layer identity to the node's
    /// caches and return the editor-side ref/key: `registerEmoji` records the `TelegramMediaFile` so the editor's
    /// emoji-view provider can render it, and `registerMedia` records the `Media` so a later `currentInputContent`
    /// can resolve it back. Pushes through the existing `setRichTextDocument` path (document set + layout refresh)
    /// to preserve the refresh/`didUpdateText` ordering, then restores the flat composer selection.
    public func setInputContent(_ content: ChatInputContent, selection: ChatInputSelection) {
        let newDocument = document(
            fromChatInputContent: content,
            registerEmoji: { [weak self] fileId, file in self?.registerEmojiRef(fileId: fileId, file: file) ?? EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil) },
            registerMedia: { [weak self] media in self?.registerMediaValue(media) ?? "" }
        )
        self.setRichTextDocument(newDocument)
        self.selectedRange = selection.nsRange(in: content)
    }

    /// Direct-bridge `resolveEmoji`: map an editor `EmojiRef` (whose `id` is the fileId STRING, by the node's
    /// convention) to the chat layer's `(fileId, file)`. The `file` comes from the node's `customEmojiAttributes`
    /// cache (the editor drops the `TelegramMediaFile`), or nil if this emoji wasn't seen via a file-bearing push.
    /// A non-numeric `id` (should not occur from this path) returns nil ⇒ the run degrades to plain text, matching
    /// `ComposerDocumentBridge`'s fallback.
    private func resolveEmojiRef(_ emojiRef: EmojiRef) -> (fileId: Int64, file: TelegramMediaFile?)? {
        guard let fileId = Int64(emojiRef.id) else {
            return nil
        }
        return (fileId, self.customEmojiAttributes[fileId]?.file)
    }

    /// Direct-bridge `registerEmoji`: cache the `TelegramMediaFile` (mirroring the `attributedText`-setter
    /// harvest — only a file-BEARING attribute is recorded, so a file-less round-trip never clobbers a resolved
    /// one) and mint the editor `EmojiRef` keyed by the fileId string (the node's convention; `instanceID` via the
    /// editor's `BlockID.generate()`, as `ComposerDocumentBridge` does).
    private func registerEmojiRef(fileId: Int64, file: TelegramMediaFile?) -> EmojiRef {
        if let file {
            self.customEmojiAttributes[fileId] = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: file)
        }
        return EmojiRef(id: String(fileId), instanceID: BlockID.generate().rawValue, altText: nil)
    }

    /// Direct-bridge `resolveMedia`: map the editor's opaque `mediaID` back to the concrete `Media` the node
    /// cached when it last received it (`registerMediaValue`). Nil ⇒ the media block is dropped on read-back
    /// (an unresolved medium has no `ChatInputMedia` representation).
    private func resolveMediaID(_ mediaID: String) -> Media? {
        return self.mediaByID[mediaID]
    }

    /// Direct-bridge `registerMedia`: cache the `Media` under a stable opaque key derived from its id (matching
    /// `RichTextAttachmentScreen.attachedMedia`'s `"namespace:id"` convention) and hand that key to the editor.
    /// The node does NOT itself insert the block into the editor or render it — that is the structural-set path's
    /// document push plus a media-view provider, which the composer node does not yet wire (see the TODO below);
    /// the key only needs to round-trip `currentInputContent → setInputContent` consistently, which an id-derived
    /// key does.
    private func registerMediaValue(_ media: Media) -> String {
        let mediaID: String
        if let id = media.id {
            mediaID = "\(id.namespace):\(id.id)"
        } else {
            // No stable media id (rare): fall back to an object-identity key so the same value still
            // round-trips within a single set/get cycle.
            mediaID = "anon:\(ObjectIdentifier(media as AnyObject).hashValue)"
        }
        self.mediaByID[mediaID] = media
        // TODO(parity): wire the editor media-view provider (`registerMediaViewProvider` +
        // `insertMedia`) so a media block set via the model actually RENDERS in the composer. The editor
        // exposes no media store, so the node owns `mediaByID`; the model round-trip works (media survives
        // `currentInputContent`/`setInputContent`), but a media block pushed via `setInputContent` is not yet
        // displayed — display wiring is a follow-up, tracked here.
        return mediaID
    }

    /// Map the host's theme colors 1:1 into the editor's `RichTextEditorTheme`. Assigning `editorView.theme`
    /// re-applies colors and redraws (see `RichTextEditorView.theme`).
    public func applyRichTextTheme(_ colors: ChatRichTextThemeColors) {
        self.editorView.theme = RichTextEditorTheme(
            primaryText: colors.primaryText,
            secondaryText: colors.secondaryText,
            placeholder: colors.placeholder,
            accent: colors.accent,
            tableBorder: colors.tableBorder,
            tableHeaderBackground: colors.tableHeaderBackground,
            codeBackground: colors.tableHeaderBackground  // v1: reuse the subtle panel fill; a dedicated code-bg seam color is a follow-up
        )
    }

    // MARK: Layout (Task 4)
    /// The panel sets `textFieldFrame` (the child's frame) separately; this lays the editor's content out at
    /// `size` using the tracked scroll insets + content margins. Trailing scroll inset stays `.zero` in
    /// Phase 1 (the composer field is short and grows; the keyboard inset is the panel's concern).
    public func updateLayout(size: CGSize) {
        _ = self.editorView.update(size: size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins)
    }
    /// Phase 1: measures by driving a full `update(...)` (a layout call, not a pure measure) and returning
    /// its content-driven height. The passed `size.height` only affects the editor's transient viewport
    /// flooring, NOT the returned content height — so we pass the editor's current committed height to keep
    /// the layout side-effect consistent with the live size rather than a tall sentinel. A true
    /// side-effect-free measure is a Phase 2 RichTextEditorView API.
    public func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        self.trackedRightInset = rightInset
        let measureHeight = self.editorView.bounds.height
        let measureSize = CGSize(width: width, height: measureHeight)
        return self.editorView.update(size: measureSize, insets: self.trackedInsets, contentMargins: self.trackedContentMargins)
    }
    public func layoutInputField() {
        _ = self.editorView.update(size: self.editorView.bounds.size, insets: self.trackedInsets, contentMargins: self.trackedContentMargins)
    }
    public var textFieldFrame: CGRect {
        get { self.editorView.frame }
        set { self.editorView.frame = newValue }
    }
    public var inputView: UIView { self.editorView }
    public var textContainerInset: UIEdgeInsets {
        get {
            var updated = self.trackedContentMargins
            updated.top += 2.0
            updated.right -= 14.0
            return updated
        }
        set {
            var updated = newValue
            updated.top -= 2.0
            updated.right += 14.0
            self.trackedContentMargins = updated
        }
    }
    public var currentRightInset: CGFloat { self.trackedRightInset }

    // MARK: Editing & focus (Task 5)
    public func deleteBackward() { self.editorView.deleteBackward() }
    public var isInputFirstResponder: Bool { self.editorView.isEditorFirstResponder }
    @discardableResult public func makeInputFirstResponder() -> Bool { self.editorView.becomeFirstResponder() }
    @discardableResult public func resignInputFirstResponder() -> Bool { self.editorView.resignEditorFirstResponder() }
    public func applyAutocorrection() { self.editorView.finalizeComposerMarkedText() }

    // MARK: Context menu + native format routing
    public var usesNativeRichTextEngine: Bool { true }

    public var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? {
        get { self.editorView.contextMenuItemsProvider }
        set { self.editorView.contextMenuItemsProvider = newValue }
    }

    public func performFormatAction(_ action: ChatRichTextFormatAction) {
        switch action {
        case .bold: self.editorView.toggleBold()
        case .italic: self.editorView.toggleItalic()
        case .strikethrough: self.editorView.toggleStrikethrough()
        case .underline: self.editorView.toggleUnderline()
        case .monospace: self.editorView.toggleInlineCode()
        case .spoiler: self.editorView.toggleSpoiler()
        case .quote: self.editorView.setParagraphStyle(.quote)
        case .code: self.editorView.makeCodeBlock()
        case .date:
            // TODO: no timestamp-entity model in the editor (deferred). No-op for now.
            break
        }
    }

    public func currentRichTextLinkURL() -> String? { self.editorView.currentLink() }
    public func selectedRichText() -> String { self.editorView.selectedText() }
    public func applyRichTextLink(_ url: String?) {
        if let url, !url.isEmpty {
            self.editorView.setLink(url)
        } else {
            self.editorView.removeLink()
        }
    }

    public var keyboardInputView: UIView? {
        get { self.editorView.customInputView }
        set { self.editorView.customInputView = newValue }
    }
    public func reloadInputViews() { self.editorView.reloadComposerInputViews() }
    public var inputDelegate: ChatInputTextNodeDelegate? {
        get { self.storedDelegate }
        set { self.storedDelegate = newValue }
    }

    // MARK: Simple view adapters (Task 6)
    public var inputIsUserInteractionEnabled: Bool {
        get { self.editorView.isUserInteractionEnabled }
        set { self.editorView.isUserInteractionEnabled = newValue }
    }
    public var inputClipsToBounds: Bool {
        get { self.editorView.clipsToBounds }
        set { self.editorView.clipsToBounds = newValue }
    }
    public var inputAccessibilityHint: String? {
        get { self.editorView.accessibilityHint }
        set { self.editorView.accessibilityHint = newValue }
    }
    // Stored only; the panel sets a small negative slop (-5pt all sides). Applying it needs a custom
    // hitTest(_:with:) override — deferred to Phase 2 (the editor's canvas owns hit-testing today).
    public var inputHitTestSlop: UIEdgeInsets = .zero
    public var inputContentOffset: CGPoint { self.editorView.composerContentOffset }
    public func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets) { self.editorView.setComposerScrollIndicatorInsets(insets) }

    /// The caret/selection in the composer's flat UTF-16 coordinate space (paragraphs joined by "\n",
    /// matching `ComposerDocumentBridge`). The panel reads this to know where to insert/replace and writes
    /// it to move the caret after an edit, so it MUST reflect the editor's real selection — a stub (e.g.
    /// always end-of-text + no-op setter) makes the panel selection-blind: the caret never advances after a
    /// programmatic insert and a surrogate-pair emoji gets split on edit, leaving a stray "service character".
    public var selectedRange: NSRange {
        get { self.editorView.composerSelectedRange }
        set { self.editorView.composerSelectedRange = newValue }
    }

    // MARK: Stubs — Phase 2+ (selection geometry, spoilers, typing attrs, language, theme fidelity)
    public var selectionRect: CGRect { .zero }
    public func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect? { nil }
    public func currentCaretRect() -> CGRect? { nil }
    public var spoilersRevealed: Bool = false
    public func setSpoilersRevealed(_ revealed: Bool, animated: Bool) { }
    public func prepareForSpoilerReveal() { }
    public func updateRichRendering(textColor: UIColor, fullTranslucency: Bool) { }
    public func refreshTextInputAttributes(context: AnyObject, primaryTextColor: UIColor, accentTextColor: UIColor, baseFontSize: CGFloat, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?) { }
    public func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat) { }
    public var inputTypingAttributes: [NSAttributedString.Key: Any] {
        get { [:] }
        set { }
    }
    public var toggleQuoteCollapse: ((NSRange) -> Void)?
    public func isCurrentlyEmoji() -> Bool { false }
    public var primaryLanguage: String? { nil }
    public var initialPrimaryLanguage: String?
    public func resetInitialPrimaryLanguage() { }
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var autocorrectionType: UITextAutocorrectionType = .default
    public var inputTintColor: UIColor?
    public func didChangeInputTintColor() { }
    public var inputCaretColor: UIColor = .clear
    public var inputTheme: ChatInputTextView.Theme?
}
