import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TextFormat
import InvisibleInkDustNode
import EmojiTextAttachmentView
import RichTextEditorCore

/// Host theme colors for the rich-text composer backend, passed across the seam as plain `UIColor`s so
/// `ChatInputTextNode` need not depend on the editor package. The RichTextEditor backend maps these 1:1
/// into its `RichTextEditorTheme`; the legacy backend ignores them (it themes via `inputTheme`).
public struct ChatRichTextThemeColors {
    public var primaryText: UIColor
    public var secondaryText: UIColor
    public var placeholder: UIColor
    public var accent: UIColor
    public var tableBorder: UIColor
    public var tableHeaderBackground: UIColor

    public init(primaryText: UIColor, secondaryText: UIColor, placeholder: UIColor, accent: UIColor, tableBorder: UIColor, tableHeaderBackground: UIColor) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.placeholder = placeholder
        self.accent = accent
        self.tableBorder = tableBorder
        self.tableHeaderBackground = tableHeaderBackground
    }
}

/// Protocol seam for the chat composer's text editor. Implemented today by
/// `ChatRichTextInputNodeImpl` (which composes the existing `ChatInputTextNode`);
/// intended to be implemented directly by the TextKit-2 RichTextEditor later.
public protocol ChatRichTextInputNode: AnyObject {
    /// The display node to insert into the view hierarchy and assign a frame to.
    var asNode: ASDisplayNode { get }

    /// Provider for animated custom-emoji views, resolved at render time. Set after creation.
    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)? { get set }

    /// Recompute and lay out the spoiler dust and custom-emoji overlays from the current
    /// attributed text, hosting both inside the composed text view's scrolling content.
    /// `textColor` / `fullTranslucency` are passed live on every call because the host's
    /// theme and energy-usage settings can change between calls; the impl reuses the most
    /// recent values for its own layout-driven refreshes.
    func updateRichRendering(textColor: UIColor, fullTranslucency: Bool)

    /// Cross-fade the spoiler dust for a reveal-state change, snapshotting the text so the
    /// transition reads as a dissolve. The caller rewrites the attributed text first (that
    /// is host/message-state domain); this method owns only the rendering side.
    func setSpoilersRevealed(_ revealed: Bool, animated: Bool)

    /// The bounding rect of the first selection rect for the given character range, in
    /// `asNode`'s coordinate space (nil if the range cannot be resolved). Lets the host
    /// anchor UI (e.g. the emoji-suggestion popup) to the caret without assuming a
    /// `UITextView` backend or reaching into scroll-view geometry.
    func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect?

    /// The caret (insertion point) rect for the current selection, in `asNode`'s coordinate
    /// space (nil if there is no caret). Like `firstSelectionRect`, this is a
    /// backend-agnostic geometry query for anchoring UI to the cursor.
    func currentCaretRect() -> CGRect?

    /// The editor's attributed content. Reads return the current text; writes replace it
    /// (the host rebuilds the attributed string after edits/state changes). Forwards to the
    /// composed editor today; a future backend implements it natively.
    var attributedText: NSAttributedString? { get set }

    /// The editor's plain-text string (read-only convenience for length/counter checks).
    var text: String { get }

    /// The editor's structured rich-text document, when the backend has one. `nil` for the
    /// legacy `UITextView`-based impl (it has no `Document` model); the TextKit-2 RichTextEditor
    /// backend returns its live `Document`. Used to seed an expanded editor with the current content.
    var richTextDocument: Document? { get }

    /// Replace the editor's structured document (the reverse of `richTextDocument`). No-op on the
    /// legacy `UITextView` backend (no `Document` model); the RichTextEditor backend replaces its
    /// live document and refreshes the host. Used to write an expanded editor's result back into
    /// the composer.
    func setRichTextDocument(_ document: Document)

    /// Apply host theme colors to the editor. No-op on the legacy `UITextView` backend (it themes via
    /// `inputTheme`/`refreshTextInputAttributes`); the RichTextEditor backend maps these into its
    /// `RichTextEditorTheme`.
    func applyRichTextTheme(_ colors: ChatRichTextThemeColors)

    /// The current selection range. Reads return the live selection; writes move/extend it
    /// (the host restores the cursor after rebuilding content). Forwards to the editor today.
    var selectedRange: NSRange { get set }

    /// The bounding rect of the current selection in the editor's coordinate space (used to
    /// anchor the system text-style menu). Read-only; forwarded as-is.
    var selectionRect: CGRect { get }

    /// Whether the editor currently holds first-responder (keyboard) focus.
    /// Distinct from `ASDisplayNode.isFirstResponder()` (which would target the wrapper).
    var isInputFirstResponder: Bool { get }

    /// Make the composed editor first responder. Returns whether it succeeded.
    @discardableResult func makeInputFirstResponder() -> Bool

    /// Resign the composed editor's first-responder status. Returns whether it succeeded.
    @discardableResult func resignInputFirstResponder() -> Bool

    /// The active input mode's primary language (for input-language tracking). Read-only.
    var primaryLanguage: String? { get }

    /// The language the editor should default its keyboard to on next focus (get/set).
    var initialPrimaryLanguage: String? { get set }

    /// Re-apply `initialPrimaryLanguage` to the live input (used when forcing the emoji keyboard).
    func resetInitialPrimaryLanguage()

    /// The text container inset (caret/text padding). Recomputed by the host each layout pass.
    var textContainerInset: UIEdgeInsets { get set }

    /// The keyboard appearance (light/dark) for the editor.
    var keyboardAppearance: UIKeyboardAppearance { get set }

    /// Whether predictive text / autocorrection is enabled.
    var autocorrectionType: UITextAutocorrectionType { get set }

    /// The editor's tint (caret + selection) color. `input`-prefixed because the impl is an
    /// `ASDisplayNode` whose own `tintColor` targets the wrapper, not the composed editor.
    var inputTintColor: UIColor? { get set }

    /// Propagate a tint-color change to the editor (mirrors `tintColorDidChange`).
    func didChangeInputTintColor()

    /// Hit-test slop expanding the editor's touch area. `input`-prefixed (wrapper collision).
    var inputHitTestSlop: UIEdgeInsets { get set }

    /// Whether the editor's scrolling content clips to bounds. `input`-prefixed (collision).
    var inputClipsToBounds: Bool { get set }

    /// The accessibility hint announced for the editor. `input`-prefixed (NSObject collision).
    var inputAccessibilityHint: String? { get set }

    /// Whether the editor accepts user interaction. `input`-prefixed because the impl's own
    /// `ASDisplayNode.isUserInteractionEnabled` targets the wrapper.
    var inputIsUserInteractionEnabled: Bool { get set }

    /// Callback to collapse/expand a quote block at a range (set once after creation).
    var toggleQuoteCollapse: ((NSRange) -> Void)? { get set }

    /// Delete one character backward from the caret (UIKeyInput-style).
    func deleteBackward()

    /// Whether the editor is currently in the emoji input mode.
    func isCurrentlyEmoji() -> Bool

    /// The attributes applied to text typed next at the caret (font/color/paragraph + the
    /// active bold/italic/monospace run). Generic text-editing concept; forwards to the
    /// editor's typing attributes.
    var inputTypingAttributes: [NSAttributedString.Key: Any] { get set }

    /// Re-derive the full attribute set of the current text (fonts, colors, spoilers,
    /// custom-emoji & collapsed-quote attachments) from theme-derived colors and state.
    /// The impl supplies its own collapsed-quote attachment factory.
    func refreshTextInputAttributes(
        context: AnyObject,
        primaryTextColor: UIColor,
        accentTextColor: UIColor,
        baseFontSize: CGFloat,
        spoilersRevealed: Bool,
        availableEmojis: Set<String>,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    )

    /// Re-derive only the typing attributes from the theme-derived text color.
    func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat)

    /// Set the insets for the editor's scroll indicator. No-op for non-scrolling backends.
    /// (A setter method rather than a property: `UIScrollView.scrollIndicatorInsets`'s
    /// getter is deprecated, and only the setter is needed here.)
    func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets)

    /// Freeze the editor's scrolling ahead of a spoiler-reveal content rewrite, so the
    /// attributed-text mutation doesn't auto-scroll. `setSpoilersRevealed(_:animated:)`
    /// re-enables scrolling when the reveal completes. No-op for non-scrolling backends.
    func prepareForSpoilerReveal()

    /// The editor's current content scroll offset, used to map content-space rects into
    /// the visible coordinate space. `.zero` for non-scrolling backends.
    var inputContentOffset: CGPoint { get }

    /// Measure the editor's content height for a width (mirrors the child's signature).
    func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat

    /// Lay out the editor's content for a size.
    func updateLayout(size: CGSize)

    /// Force an immediate layout pass of the editor child (distinct name: `ASDisplayNode`
    /// already has `layout()`, which targets the wrapper).
    func layoutInputField()

    /// The editor child's own frame, inset within `asNode` per the Model-A geometry.
    /// Distinct from `asNode.frame` (the full-size wrapper).
    var textFieldFrame: CGRect { get set }

    /// The editor child's backing view (for gesture/snapshot/layout hooks). Backend-
    /// agnostic: a direct backend returns its own content view (== `asNode.view` there).
    var inputView: UIView { get }

    /// The caret/selection tint. Distinct from `inputTintColor` (the node-level tint):
    /// this is the inner editor's caret color, toggled to hide the caret during snapshots.
    var inputCaretColor: UIColor { get set }

    /// The editor's quote/code rendering theme (quote background/foreground, line style,
    /// code colors). Set on load and on theme change.
    var inputTheme: ChatInputTextView.Theme? { get set }

    /// The editor's delegate (text/selection/editing/paste callbacks). Set once after
    /// creation. Weak at the storage layer (the composed node holds it weakly).
    var inputDelegate: ChatInputTextNodeDelegate? { get set }

    /// The editor's custom keyboard input view (`nil` ⇒ system keyboard). Distinct from
    /// `inputView` (the editor's backing view): this is the `UITextView.inputView` slot,
    /// set to an empty view to suppress the system keyboard for the entity keyboard.
    var keyboardInputView: UIView? { get set }

    /// Reload the editor's input views (after changing `keyboardInputView`).
    func reloadInputViews()

    /// The editor's current right text inset (composer accessory width); read by the
    /// send-options morph to match the bubble's text wrapping.
    var currentRightInset: CGFloat { get }

    /// Commit any pending marked/autocorrect text (called before send). For the UITextView
    /// backend this applies keyboard autocorrection; another backend finalizes marked text.
    func applyAutocorrection()
}

/// Creates the default composition-based rich text input node.
public func makeChatRichTextInputNode(disableTiling: Bool = false) -> ChatRichTextInputNode {
    return ChatRichTextInputNodeImpl(disableTiling: disableTiling)
}

final class ChatRichTextInputNodeImpl: ASDisplayNode, ChatRichTextInputNode {
    private let textInputNodeImpl: ChatInputTextNode

    private var dustNode: InvisibleInkDustNode?
    private var customEmojiContainerView: CustomEmojiContainerView?
    private var spoilersRevealed: Bool = false

    // Most recent values supplied by the host via updateRichRendering. The internal
    // layout-driven refresh (onUpdateLayout) reuses them so it renders with the same
    // theme/energy state the host last drove. nil textColor means "not configured yet".
    private var lastTextColor: UIColor?
    private var lastFullTranslucency: Bool = true

    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView?)?

    // Bridges to ASDisplayNode for callers that hold this only as a ChatRichTextInputNode.
    var asNode: ASDisplayNode {
        return self
    }

    init(disableTiling: Bool = false) {
        self.textInputNodeImpl = ChatInputTextNode(disableTiling: disableTiling)

        super.init()

        self.addSubnode(self.textInputNodeImpl)

        // Refresh overlays when the composed editor relayouts (e.g. content size changes
        // on scroll/typing), reusing the host's most recent rendering values.
        self.textInputNodeImpl.textView.onUpdateLayout = { [weak self] in
            guard let self, let textColor = self.lastTextColor else {
                return
            }
            self.updateRichRendering(textColor: textColor, fullTranslucency: self.lastFullTranslucency)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRichRendering(textColor: UIColor, fullTranslucency: Bool) {
        self.lastTextColor = textColor
        self.lastFullTranslucency = fullTranslucency

        let textInputNode = self.textInputNodeImpl

        var rects: [CGRect] = []
        var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute, CGFloat)] = []

        // The host pins the composer font size to 17.0; match it here.
        let fontSize: CGFloat = 17.0

        if let attributedText = textInputNode.attributedText {
            let beginning = textInputNode.textView.beginningOfDocument
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    func addSpoiler(startIndex: Int, endIndex: Int) {
                        if let start = textInputNode.textView.position(from: beginning, offset: startIndex), let end = textInputNode.textView.position(from: start, offset: endIndex - startIndex), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                            let textRects = textInputNode.textView.selectionRects(for: textRange)
                            for textRect in textRects {
                                if textRect.rect.width > 1.0 && textRect.rect.size.height > 1.0 {
                                    rects.append(textRect.rect.insetBy(dx: 1.0, dy: 1.0).offsetBy(dx: 0.0, dy: 1.0))
                                }
                            }
                        }
                    }

                    var startIndex: Int?
                    var currentIndex: Int?

                    let nsString = (attributedText.string as NSString)
                    nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                        if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                            if let currentStartIndex = startIndex {
                                startIndex = nil
                                let endIndex = range.location
                                addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                            }
                        } else if startIndex == nil {
                            startIndex = range.location
                        }
                        currentIndex = range.location + range.length
                    }

                    if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                        startIndex = nil
                        let endIndex = currentIndex
                        addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                    }
                }

                if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                    if let start = textInputNode.textView.position(from: beginning, offset: range.location), let end = textInputNode.textView.position(from: start, offset: range.length), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                        let textRects = textInputNode.textView.selectionRects(for: textRange)
                        for textRect in textRects {
                            var emojiFontSize = fontSize
                            if let font = attributes[.font] as? UIFont {
                                emojiFontSize = font.pointSize
                            }
                            customEmojiRects.append((textRect.rect, value, emojiFontSize))
                            break
                        }
                    }
                }
            })
        }

        if !rects.isEmpty {
            let dustNode: InvisibleInkDustNode
            if let current = self.dustNode {
                dustNode = current
            } else {
                dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: fullTranslucency)
                dustNode.alpha = self.spoilersRevealed ? 0.0 : 1.0
                dustNode.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(dustNode.view)
                self.dustNode = dustNode
            }
            dustNode.frame = CGRect(origin: CGPoint(), size: textInputNode.textView.contentSize)
            dustNode.update(size: textInputNode.textView.contentSize, color: textColor, textColor: textColor, rects: rects, wordRects: rects)
        } else if let dustNode = self.dustNode {
            dustNode.removeFromSupernode()
            self.dustNode = nil
        }

        if !customEmojiRects.isEmpty {
            let customEmojiContainerView: CustomEmojiContainerView
            if let current = self.customEmojiContainerView {
                customEmojiContainerView = current
            } else {
                customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
                    guard let strongSelf = self, let emojiViewProvider = strongSelf.emojiViewProvider else {
                        return nil
                    }
                    return emojiViewProvider(emoji)
                })
                customEmojiContainerView.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(customEmojiContainerView)
                self.customEmojiContainerView = customEmojiContainerView
            }

            customEmojiContainerView.update(fontSize: fontSize, textColor: textColor, emojiRects: customEmojiRects)
        } else if let customEmojiContainerView = self.customEmojiContainerView {
            customEmojiContainerView.removeFromSuperview()
            self.customEmojiContainerView = nil
        }
    }

    func setSpoilersRevealed(_ revealed: Bool, animated: Bool) {
        self.spoilersRevealed = revealed

        let textView = self.textInputNodeImpl.textView

        if textView.subviews.count > 1, animated {
            let containerView = textView.subviews[1]
            if let canvasView = containerView.subviews.first {
                if let snapshotView = canvasView.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = canvasView.frame.offsetBy(dx: 0.0, dy: -textView.contentOffset.y)
                    self.textInputNodeImpl.view.insertSubview(snapshotView, at: 0)
                    canvasView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView, weak textView] _ in
                        textView?.isScrollEnabled = false
                        snapshotView?.removeFromSuperview()
                        Queue.mainQueue().after(0.1) {
                            textView?.isScrollEnabled = true
                        }
                    })
                }
            }
        }
        Queue.mainQueue().after(0.1) { [weak textView] in
            textView?.isScrollEnabled = true
        }

        if animated {
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
            if let dustNode = self.dustNode {
                transition.updateAlpha(node: dustNode, alpha: revealed ? 0.0 : 1.0)
            }
        } else if let dustNode = self.dustNode {
            dustNode.alpha = revealed ? 0.0 : 1.0
        }
    }

    func firstSelectionRect(forCharacterRange characterRange: NSRange) -> CGRect? {
        let textView = self.textInputNodeImpl.textView
        let beginning = textView.beginningOfDocument
        guard let start = textView.position(from: beginning, offset: characterRange.location),
              let end = textView.position(from: start, offset: characterRange.length),
              let textRange = textView.textRange(from: start, to: end),
              let rect = textView.selectionRects(for: textRange).first?.rect else {
            return nil
        }
        // selectionRects are in the text view's (scrolling) coordinate space; convert up to
        // this node's space so the caller never depends on the editor being a scroll view.
        return textView.convert(rect, to: self.view)
    }

    func currentCaretRect() -> CGRect? {
        let textView = self.textInputNodeImpl.textView
        guard let selectedTextRange = textView.selectedTextRange else {
            return nil
        }
        let rect = textView.caretRect(for: selectedTextRange.end)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.size.width.isFinite, rect.size.height.isFinite else {
            return nil
        }
        return textView.convert(rect, to: self.view)
    }

    var attributedText: NSAttributedString? {
        get { return self.textInputNodeImpl.attributedText }
        set { self.textInputNodeImpl.attributedText = newValue }
    }

    var text: String {
        return self.textInputNodeImpl.textView.text
    }

    /// The legacy `UITextView` backend has no `Document` model.
    var richTextDocument: Document? {
        return nil
    }

    /// No-op: the legacy `UITextView` backend has no `Document` model to replace.
    func setRichTextDocument(_ document: Document) {
    }

    /// No-op: the legacy `UITextView` backend themes via `inputTheme`/`refreshTextInputAttributes`.
    func applyRichTextTheme(_ colors: ChatRichTextThemeColors) {
    }

    var selectedRange: NSRange {
        get { return self.textInputNodeImpl.selectedRange }
        set { self.textInputNodeImpl.selectedRange = newValue }
    }

    var selectionRect: CGRect {
        return self.textInputNodeImpl.selectionRect
    }

    var isInputFirstResponder: Bool {
        return self.textInputNodeImpl.isFirstResponder()
    }

    @discardableResult func makeInputFirstResponder() -> Bool {
        return self.textInputNodeImpl.becomeFirstResponder()
    }

    @discardableResult func resignInputFirstResponder() -> Bool {
        return self.textInputNodeImpl.resignFirstResponder()
    }

    var primaryLanguage: String? {
        return self.textInputNodeImpl.textInputMode?.primaryLanguage
    }

    var initialPrimaryLanguage: String? {
        get { return self.textInputNodeImpl.initialPrimaryLanguage }
        set { self.textInputNodeImpl.initialPrimaryLanguage = newValue }
    }

    func resetInitialPrimaryLanguage() {
        self.textInputNodeImpl.resetInitialPrimaryLanguage()
    }

    var textContainerInset: UIEdgeInsets {
        get { return self.textInputNodeImpl.textContainerInset }
        set { self.textInputNodeImpl.textContainerInset = newValue }
    }

    var keyboardAppearance: UIKeyboardAppearance {
        get { return self.textInputNodeImpl.keyboardAppearance }
        set { self.textInputNodeImpl.keyboardAppearance = newValue }
    }

    var autocorrectionType: UITextAutocorrectionType {
        get { return self.textInputNodeImpl.textView.autocorrectionType }
        set { self.textInputNodeImpl.textView.autocorrectionType = newValue }
    }

    var inputTintColor: UIColor? {
        get { return self.textInputNodeImpl.tintColor }
        set { self.textInputNodeImpl.tintColor = newValue }
    }

    func didChangeInputTintColor() {
        self.textInputNodeImpl.tintColorDidChange()
    }

    var inputHitTestSlop: UIEdgeInsets {
        get { return self.textInputNodeImpl.hitTestSlop }
        set { self.textInputNodeImpl.hitTestSlop = newValue }
    }

    var inputClipsToBounds: Bool {
        get { return self.textInputNodeImpl.textView.clipsToBounds }
        set { self.textInputNodeImpl.textView.clipsToBounds = newValue }
    }

    var inputAccessibilityHint: String? {
        get { return self.textInputNodeImpl.textView.accessibilityHint }
        set { self.textInputNodeImpl.textView.accessibilityHint = newValue }
    }

    var inputIsUserInteractionEnabled: Bool {
        get { return self.textInputNodeImpl.isUserInteractionEnabled }
        set { self.textInputNodeImpl.isUserInteractionEnabled = newValue }
    }

    var toggleQuoteCollapse: ((NSRange) -> Void)? {
        get { return self.textInputNodeImpl.textView.toggleQuoteCollapse }
        set { self.textInputNodeImpl.textView.toggleQuoteCollapse = newValue }
    }

    func deleteBackward() {
        self.textInputNodeImpl.textView.deleteBackward()
    }

    func isCurrentlyEmoji() -> Bool {
        return self.textInputNodeImpl.isCurrentlyEmoji()
    }

    var inputTypingAttributes: [NSAttributedString.Key: Any] {
        get { return self.textInputNodeImpl.textView.typingAttributes }
        set { self.textInputNodeImpl.textView.typingAttributes = newValue }
    }

    func refreshTextInputAttributes(
        context: AnyObject,
        primaryTextColor: UIColor,
        accentTextColor: UIColor,
        baseFontSize: CGFloat,
        spoilersRevealed: Bool,
        availableEmojis: Set<String>,
        emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    ) {
        refreshChatTextInputAttributes(context: context, textView: self.textInputNodeImpl.textView, primaryTextColor: primaryTextColor, accentTextColor: accentTextColor, baseFontSize: baseFontSize, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
            return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
        })
    }

    func refreshTextInputTypingAttributes(textColor: UIColor, baseFontSize: CGFloat) {
        refreshChatTextInputTypingAttributes(self.textInputNodeImpl.textView, textColor: textColor, baseFontSize: baseFontSize)
    }

    func setInputScrollIndicatorInsets(_ insets: UIEdgeInsets) {
        self.textInputNodeImpl.textView.scrollIndicatorInsets = insets
    }

    func prepareForSpoilerReveal() {
        self.textInputNodeImpl.textView.isScrollEnabled = false
    }

    var inputContentOffset: CGPoint {
        return self.textInputNodeImpl.textView.contentOffset
    }

    func textHeightForWidth(_ width: CGFloat, rightInset: CGFloat) -> CGFloat {
        return self.textInputNodeImpl.textHeightForWidth(width, rightInset: rightInset)
    }

    func updateLayout(size: CGSize) {
        self.textInputNodeImpl.updateLayout(size: size)
    }

    func layoutInputField() {
        self.textInputNodeImpl.layout()
    }

    var textFieldFrame: CGRect {
        get { return self.textInputNodeImpl.frame }
        set { self.textInputNodeImpl.frame = newValue }
    }

    var inputView: UIView {
        return self.textInputNodeImpl.view
    }

    var inputCaretColor: UIColor {
        get { return self.textInputNodeImpl.textView.tintColor }
        set { self.textInputNodeImpl.textView.tintColor = newValue }
    }

    var inputTheme: ChatInputTextView.Theme? {
        get { return self.textInputNodeImpl.textView.theme }
        set { self.textInputNodeImpl.textView.theme = newValue }
    }

    var inputDelegate: ChatInputTextNodeDelegate? {
        get { return self.textInputNodeImpl.delegate }
        set { self.textInputNodeImpl.delegate = newValue }
    }

    var keyboardInputView: UIView? {
        get { return self.textInputNodeImpl.textView.inputView }
        set { self.textInputNodeImpl.textView.inputView = newValue }
    }

    func reloadInputViews() {
        self.textInputNodeImpl.textView.reloadInputViews()
    }

    var currentRightInset: CGFloat {
        return self.textInputNodeImpl.textView.currentRightInset
    }

    func applyAutocorrection() {
        Keyboard.applyAutocorrection(textView: self.textInputNodeImpl.textView)
    }
}
