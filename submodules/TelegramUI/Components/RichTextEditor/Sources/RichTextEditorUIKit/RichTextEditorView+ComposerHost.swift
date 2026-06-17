#if canImport(UIKit)
import UIKit

/// Small public forwarders used by the chat-composer host (`RichTextEditorChatInputNode`). The editing
/// surface (`canvas`) and `scrollView` are module-internal, so a consumer in another module reaches these
/// behaviors only through `RichTextEditorView`. No new editor logic lives here.
@available(iOS 13.0, *)
public extension RichTextEditorView {
    /// Whether the editing surface (the canvas, the actual first responder) currently has focus.
    /// `UIView.isFirstResponder` would report the wrapper, not the canvas.
    var isEditorFirstResponder: Bool { self.canvas.isFirstResponder }

    /// Resign the editing surface's first-responder status (forwarded to the canvas).
    @discardableResult
    func resignEditorFirstResponder() -> Bool { self.canvas.resignFirstResponder() }

    /// Commit any pending marked/predictive text before send. The range return value is not needed by the host.
    func finalizeComposerMarkedText() { _ = self.canvas.finalizeMarkedText() }

    /// The selection in the chat composer's flat UTF-16 coordinate space (the document's paragraphs joined
    /// by "\n", matching `ComposerDocumentBridge`). The host reads it to track the caret and writes it to
    /// move the caret after a programmatic insert/replace; without a real mapping the host is selection-blind
    /// (the caret never advances and a surrogate-pair emoji is split on edit, leaving a stray code unit).
    var composerSelectedRange: NSRange {
        get { self.canvas.composerSelectedRange }
        set { self.canvas.composerSelectedRange = newValue }
    }

    /// Reload the editing surface's input views (after changing `customInputView`).
    func reloadComposerInputViews() { self.canvas.reloadInputViews() }

    /// The editor's content scroll offset (host maps content-space rects to the visible space).
    var composerContentOffset: CGPoint { self.scrollViewContentOffset }

    /// Set the editor's scroll-indicator insets.
    func setComposerScrollIndicatorInsets(_ insets: UIEdgeInsets) { self.setScrollViewIndicatorInsets(insets) }

    /// The built-in horizontal page margin applied to text (in addition to `contentMargins`). Defaults to
    /// 16pt (document layout); a compact composer host sets it to 0 so the host owns all horizontal insets.
    var contentPageMargin: CGFloat {
        get { self.canvas.pageMargin }
        set { self.canvas.pageMargin = newValue }
    }

    /// The base inter-block vertical inset for the document root (each side). Defaults to 8pt (document
    /// inter-paragraph gap); a compact composer host sets it to 0 so a single paragraph hugs its text height.
    var blockVerticalInset: CGFloat {
        get { self.canvas.blockVerticalInset }
        set { self.canvas.blockVerticalInset = newValue }
    }

    /// Placeholder strings drawn in empty paragraphs. Defaults to the editor's built-in hints; a host that
    /// draws its own placeholder (the chat composer) sets them to "" to suppress the editor's. Applied on the
    /// next layout pass — set before the first `update(...)`/document seed.
    var placeholders: RichTextEditorPlaceholders {
        get { self.canvas.placeholders }
        set { self.canvas.placeholders = newValue }
    }

    /// The editing canvas's background. Defaults to `.systemBackground` (the document "page"); a compact host
    /// that sits on its own surface (the chat composer, over the input panel) sets it to `.clear` so the
    /// panel's background shows through. The scroll view and block backing views are already clear.
    var canvasBackgroundColor: UIColor? {
        get { self.canvas.backgroundColor }
        set { self.canvas.backgroundColor = newValue }
    }
}
#endif
