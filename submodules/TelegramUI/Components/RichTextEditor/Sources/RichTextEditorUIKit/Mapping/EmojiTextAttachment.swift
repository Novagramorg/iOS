#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// An INVISIBLE `NSTextAttachment` that only reserves a square box scaled to the run's font, and
/// carries the `EmojiRef` so the renderer can pool/position the host-provided view (the only visual)
/// and `characterAttributes(from:)` can round-trip the emoji. Draws nothing of its own.
///
/// Sizing: `S = (font.ascender + |font.descender|) * scale`, with the box's baseline offset
/// `y = font.descender`, so the square spans descender→ascender and sits on the baseline like a glyph.
///
/// `renderBoost` enlarges only the VISIBLE host view (see `BlockLayout.attachmentBox`) by that many points,
/// centered on the glyph box — it does NOT touch `attachmentBounds`, so the line height stays put and the
/// extra size bleeds into the line's leading. Used to render body emoji a touch larger than their glyph box.
@available(iOS 17.0, *)
final class EmojiTextAttachment: NSTextAttachment {
    let ref: EmojiRef
    let scale: CGFloat
    let renderBoost: CGFloat

    /// A 1×1 clear image ensures TextKit 2 calls `attachmentBounds(for:location:…)` and reserves layout
    /// space (an image-less attachment can be laid out as zero-width). It's identical for every emoji and
    /// renders nothing visible, so it's shared (a fresh render per attachment would cost on every reload).
    private static let spacerImage: UIImage =
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    init(ref: EmojiRef, scale: CGFloat, renderBoost: CGFloat = 0) {
        self.ref = ref
        self.scale = scale
        self.renderBoost = renderBoost
        super.init(data: nil, ofType: nil)
        self.image = Self.spacerImage
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        let font = (attributes[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
        let side = (font.ascender - font.descender) * scale   // descender is negative → ascender + |descender|
        return CGRect(x: 0, y: font.descender, width: side, height: side)
    }
}
#endif
