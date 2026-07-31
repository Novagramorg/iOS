import Foundation
import UIKit
import TelegramCore

/// One button pill: the rounded fill is the view's own `backgroundColor` + corner radius, and
/// `draw(_:)` paints the pre-laid-out label on top. Used directly for an inline `RichText.textButton`
/// and as the child of a block-level button row.
///
/// The frame is set by the owner (the item view or the row view) — this view never writes its own.
final class InstantPageV2ButtonPillView: UIView {
    private var attachment: InstantPageInlineButtonAttachment
    private var theme: InstantPageTheme
    /// Inline (`RichText.textButton`) vs block-level (`pageBlockButtonRow`). Fixed at init: a pill is
    /// created by exactly one kind of owner and never changes kind.
    private let isInline: Bool
    private var isDisabled: Bool
    private var isPressed: Bool = false
    /// `attachment.labelString` recoloured to the resolved button label colour. The attachment's own
    /// string is baked with the surrounding paragraph colour by `attributedStringForRichText`, which
    /// has no `InstantPageTheme` to resolve a button colour with — so the recolour happens here,
    /// where the theme is available.
    private var displayLabelString: NSAttributedString
    /// The action's type badge, tinted to match the label. nil for an inline pill (too small to carry
    /// one) and for the actions that have no badge — see `instantPageBlockButtonIconName`.
    private var iconImage: UIImage?

    var onButtonTapped: ((InstantPageButton) -> Void)?

    init(attachment: InstantPageInlineButtonAttachment, theme: InstantPageTheme, isInline: Bool) {
        self.attachment = attachment
        self.theme = theme
        self.isInline = isInline
        self.isDisabled = attachment.button.action == .disabled
        self.displayLabelString = attachment.labelString
        super.init(frame: CGRect())

        self.isOpaque = false
        self.applyColors()
        self.clipsToBounds = true

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.addGestureRecognizer(recognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(attachment: InstantPageInlineButtonAttachment, theme: InstantPageTheme) {
        self.attachment = attachment
        self.theme = theme
        self.isDisabled = attachment.button.action == .disabled
        self.applyColors()
        self.setNeedsDisplay()
    }

    private func applyColors() {
        let colors = instantPageButtonColors(self.attachment.button.color, theme: self.theme, isInline: self.isInline, isDisabled: self.isDisabled)
        self.backgroundColor = self.isPressed ? self.theme.panelHighlightedBackgroundColor : colors.fill

        let mutableLabel = self.attachment.labelString.mutableCopy() as! NSMutableAttributedString
        if mutableLabel.length != 0 {
            mutableLabel.addAttribute(.foregroundColor, value: colors.label, range: NSRange(location: 0, length: mutableLabel.length))
        }
        self.displayLabelString = mutableLabel

        // Same colour as the label, so a disabled button's badge dims with its text.
        self.iconImage = self.isInline ? nil : instantPageBlockButtonIcon(for: self.attachment.button.action, color: colors.label)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.bounds.height / 2.0
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        // `attachment.ascent` already includes the vertical padding, so it is exactly the baseline's
        // distance from the pill's top edge.
        // Horizontally centre the label: for an inline pill this equals the padding, but a row pill's
        // frame is stretched to an equal column width, so the label must centre within it.
        let labelWidth = self.attachment.size.width - instantPageInlineButtonHorizontalPadding * 2.0
        let x = max(instantPageInlineButtonHorizontalPadding, (self.bounds.width - labelWidth) / 2.0)
        // Vertically: `attachment.ascent` is the baseline's distance from the pill top for an inline
        // pill. A row pill has a fixed taller height, so centre the label's box instead.
        let labelBoxHeight = self.attachment.ascent + self.attachment.descent
        let y = (self.bounds.height - labelBoxHeight) / 2.0 + self.attachment.ascent - 0.33
        context.textPosition = CGPoint(x: x, y: y)
        let line = CTLineCreateWithAttributedString(self.displayLabelString)
        CTLineDraw(line, context)

        // Top-right type badge, as on a bot keyboard button. Drawn after the label so a pill too
        // narrow for both shows the badge rather than losing it under the text — the layout reserves
        // room for it, but a stretched row column can still be tight.
        if let iconImage = self.iconImage {
            let iconFrame = CGRect(
                origin: CGPoint(
                    x: self.bounds.width - instantPageBlockButtonIconInset.x - instantPageBlockButtonIconSize.width,
                    y: instantPageBlockButtonIconInset.y
                ),
                size: instantPageBlockButtonIconSize
            )
            iconImage.draw(in: iconFrame)
        }
    }

    // MARK: - Press handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if !self.isDisabled {
            self.isPressed = true
            self.applyColors()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.isPressed = false
        self.applyColors()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.isPressed = false
        self.applyColors()
    }

    @objc private func tapped() {
        // A disabled button is inert: a forward stripped its behaviour.
        if self.isDisabled {
            return
        }
        self.onButtonTapped?(self.attachment.button)
    }
}

/// Item view for an inline `RichText.textButton`.
final class InstantPageV2InlineButtonView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2InlineButtonItem
    private let pillView: InstantPageV2ButtonPillView

    var itemFrame: CGRect { return self.item.frame }

    var onButtonTapped: ((InstantPageButton) -> Void)? {
        didSet {
            self.pillView.onButtonTapped = self.onButtonTapped
        }
    }

    init(item: InstantPageV2InlineButtonItem, theme: InstantPageTheme) {
        self.item = item
        self.pillView = InstantPageV2ButtonPillView(attachment: item.attachment, theme: theme, isInline: true)
        super.init(frame: item.frame)
        self.addSubview(self.pillView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2InlineButtonItem, theme: InstantPageTheme) {
        self.item = item
        self.pillView.update(attachment: item.attachment, theme: theme)
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.pillView.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}

/// Item view for a block-level `pageBlockButtonRow`. Positions child pills at the frames the layout
/// chose (which already encode wrapping at 8 per row and equal widths within a row).
final class InstantPageV2ButtonRowView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ButtonRowItem
    private var pillViews: [InstantPageV2ButtonPillView] = []
    private var theme: InstantPageTheme

    var itemFrame: CGRect { return self.item.frame }

    var onButtonTapped: ((InstantPageButton) -> Void)? {
        didSet {
            for pill in self.pillViews {
                pill.onButtonTapped = self.onButtonTapped
            }
        }
    }

    init(item: InstantPageV2ButtonRowItem, theme: InstantPageTheme) {
        self.item = item
        self.theme = theme
        super.init(frame: item.frame)
        self.rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2ButtonRowItem, theme: InstantPageTheme) {
        self.item = item
        self.theme = theme
        // Rebuilt rather than diffed: a row holds at most a handful of pills and its count can change
        // between updates, so reuse would cost more than it saves.
        self.rebuild()
        self.setNeedsLayout()
    }

    private func rebuild() {
        for pill in self.pillViews {
            pill.removeFromSuperview()
        }
        self.pillViews = self.item.buttons.map { entry in
            let pill = InstantPageV2ButtonPillView(attachment: entry.attachment, theme: self.theme, isInline: false)
            pill.onButtonTapped = self.onButtonTapped
            self.addSubview(pill)
            return pill
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, pill) in self.pillViews.enumerated() where index < self.item.buttons.count {
            pill.frame = self.item.buttons[index].frame
        }
    }
}
