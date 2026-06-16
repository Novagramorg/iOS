import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TextFormat
import RichTextEditorCore
import RichTextEditorUIKit
import ChatInputTextNode

/// `ChatRichTextInputNode` backend composing the TextKit-2 `RichTextEditorView`. Selected on iOS 17+
/// behind the `debugRichText` flag (see `ChatTextInputPanelNode.loadTextInputNode`). Phase 1 implements
/// display, layout, and editing; selection geometry, spoiler reveal, typing attributes, and the full
/// delegate suite are safe stubs (Phase 2+).
@available(iOS 17.0, *)
public final class RichTextEditorChatInputNode: ASDisplayNode, ChatRichTextInputNode {
    private let editorView = RichTextEditorView()
    private let baseFontSize: CGFloat = 17.0

    private var trackedInsets: UIEdgeInsets = .zero
    private var trackedContentMargins: UIEdgeInsets = .zero
    private var trackedRightInset: CGFloat = 0.0
    private weak var storedDelegate: ChatInputTextNodeDelegate?

    public var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)?

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
    }

    // MARK: Display (Task 3)
    public var attributedText: NSAttributedString? {
        get { ComposerDocumentBridge.attributedString(from: self.editorView.document, baseFontSize: self.baseFontSize) }
        set {
            let incoming = newValue ?? NSAttributedString(string: "")
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

    /// Map the host's theme colors 1:1 into the editor's `RichTextEditorTheme`. Assigning `editorView.theme`
    /// re-applies colors and redraws (see `RichTextEditorView.theme`).
    public func applyRichTextTheme(_ colors: ChatRichTextThemeColors) {
        self.editorView.theme = RichTextEditorTheme(
            primaryText: colors.primaryText,
            secondaryText: colors.secondaryText,
            placeholder: colors.placeholder,
            accent: colors.accent,
            tableBorder: colors.tableBorder,
            tableHeaderBackground: colors.tableHeaderBackground
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

    // MARK: Stubs — Phase 2+ (selection geometry, spoilers, typing attrs, language, theme fidelity)
    public var selectedRange: NSRange {
        get { NSRange(location: (self.text as NSString).length, length: 0) }
        set { }
    }
    public var selectionRect: CGRect { .zero }
    public func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect? { nil }
    public func currentCaretRect() -> CGRect? { nil }
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
