#if canImport(UIKit)
import UIKit
import CoreText
import RichTextEditorCore

/// One rendered pill — a capsule fill plus its label — used by BOTH pill kinds: a block row's pills are
/// subviews of `ButtonRowBackingView`, an inline `textButton`'s pill is hosted in the canvas overlay at
/// its attachment's rect (mirroring how an inline emoji's host view is placed).
///
/// **A pill is a VIEW, not a rasterised image, because a label can contain a custom emoji** — which needs
/// a live host view (`InlineStickerItemLayer`) that a bitmap can never carry. The V2 renderer draws pills
/// as views for the same reason.
///
/// It is NOT interactive: taps still reach the canvas's own recognizers, which resolve a pill through
/// `ButtonRowBox.pillIndex(atCanvasPoint:)`. Keeping it passthrough preserves the canvas's
/// sole-`UITextInput` invariant.
@available(iOS 13.0, *)
final class ButtonPillView: UIView {
    private(set) var labelString: NSAttributedString = NSAttributedString()
    private var horizontalPadding: CGFloat = 0.0
    private var ascent: CGFloat = 0.0
    private var colors: (fill: UIColor, label: UIColor) = (.clear, .label)

    /// Emoji host views inside this pill's label, pooled by `EmojiRef.instanceID` exactly as the canvas
    /// pools body-text emoji — so a re-layout reuses the same view and its animation survives.
    private var emojiViews: [String: UIView & RichTextEmojiView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // LOAD-BEARING: `clipsToBounds` is what makes the capsule a capsule when a label overflows, and
        // it is why the pill must not host anything it needs to draw outside its own bounds.
        clipsToBounds = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(attachment: ButtonTextAttachment) {
        self.labelString = attachment.labelString
        self.horizontalPadding = attachment.horizontalPadding
        self.ascent = attachment.ascent
        self.colors = attachment.colors
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2.0
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), bounds.width > 0, bounds.height > 0 else {
            return
        }
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2.0)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(colors.fill.cgColor)
        ctx.fillPath()

        // Recoloured HERE, not baked into `labelString` at measurement time: the mapper bakes the
        // PARAGRAPH's foreground and has no notion of a pill's colour role, so a danger/success label
        // would otherwise render in body-text colour and a disabled one would never dim.
        let recoloured = NSMutableAttributedString(attributedString: labelString)
        recoloured.addAttribute(.foregroundColor, value: colors.label,
                                range: NSRange(location: 0, length: recoloured.length))
        recoloured.draw(at: labelOrigin())
    }

    /// Top-left of the label's drawing box, centred within whatever width the pill was given. In justify
    /// mode that width is the stretched column, wider than the label's natural pill.
    private func labelOrigin() -> CGPoint {
        let inkWidth = labelString.length > 0
            ? CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(labelString), nil, nil, nil))
            : 0.0
        let x = max(horizontalPadding, (bounds.width - inkWidth) / 2.0)
        let labelHeight = labelString.size().height
        return CGPoint(x: x, y: max(0.0, (bounds.height - labelHeight) / 2.0))
    }

    /// Hosts a live view for each custom emoji in the label. `provider` is the canvas's own
    /// `emojiViewProvider`, so a pill emoji is rendered by exactly the same host machinery as a body one.
    ///
    /// Called on every layout pass; the pooling makes a re-sync cheap and keeps a running animation alive.
    func syncEmoji(provider: (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?,
                   dynamicColor: UIColor) {
        guard labelString.length > 0 else {
            for (_, view) in emojiViews { view.removeFromSuperview() }
            emojiViews.removeAll()
            return
        }
        let line = CTLineCreateWithAttributedString(labelString)
        let origin = labelOrigin()
        var present = Set<String>()

        labelString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: labelString.length), options: []) { value, range, _ in
            guard let emoji = value as? EmojiTextAttachment else {
                return
            }
            let font = labelString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
            let side = ((font?.ascender ?? 0.0) - (font?.descender ?? 0.0)) * emoji.scale
            guard side > 0 else {
                return
            }
            let x = origin.x + CTLineGetOffsetForStringIndex(line, range.location, nil)
            // The label box's baseline is `ascent` down from its top; the square spans descender→ascender
            // and sits on the baseline, exactly as `EmojiTextAttachment.box(for:)` defines it.
            let baselineY = origin.y + ascent
            let frame = CGRect(x: x, y: baselineY - side - (font?.descender ?? 0.0), width: side, height: side)

            present.insert(emoji.ref.instanceID)
            let view: UIView & RichTextEmojiView
            if let existing = emojiViews[emoji.ref.instanceID] {
                view = existing
            } else if let fresh = provider(emoji.ref.id, frame.size) {
                fresh.isUserInteractionEnabled = false
                emojiViews[emoji.ref.instanceID] = fresh
                addSubview(fresh)
                view = fresh
            } else {
                return   // no view available yet; retried on the next layout pass
            }
            // A template emoji tints to the PILL's label colour, not the body text colour — the same
            // reason the label itself is recoloured here rather than at construction.
            view.dynamicColor = dynamicColor
            view.frame = frame
        }

        for (instanceID, view) in emojiViews where !present.contains(instanceID) {
            view.removeFromSuperview()
            emojiViews[instanceID] = nil
        }
    }
}
#endif
