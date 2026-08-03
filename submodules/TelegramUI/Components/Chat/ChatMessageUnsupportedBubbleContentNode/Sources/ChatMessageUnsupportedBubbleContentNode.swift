import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import WallpaperBackgroundNode
import AppBundle
import ChatMessageBubbleContentNode
import ChatMessageItemCommon

private let contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 8.0, right: 12.0)
private let maximumCornerRadius: CGFloat = 22.0

private let badgeDiameter: CGFloat = 44.0
private let badgeTextSpacing: CGFloat = 12.0

// The badge is two 44x44 template assets drawn at the same frame: the bubble silhouette and the
// plane positioned to sit inside it. They must not be inset relative to each other.
private let badgeBackgroundAlpha: (dark: CGFloat, light: CGFloat) = (0.2, 0.15)

private let titleSubtitleSpacing: CGFloat = 0.0

private let textButtonSpacing: CGFloat = 12.0
private let buttonHorizontalPadding: CGFloat = 11.0
private let buttonVerticalPadding: CGFloat = 8.0

private let subtitleAlpha: CGFloat = 0.6

public final class ChatMessageUnsupportedBubbleContentNode: ChatMessageBubbleContentNode {
    private let backgroundColorNode: ASDisplayNode
    private var backgroundNode: WallpaperBubbleBackgroundNode?

    private let badgeBackgroundView: UIImageView
    private let badgeIconView: UIImageView

    private let titleNode: TextNode
    private let subtitleNode: TextNode

    private let buttonNode: HighlightTrackingButton
    private let buttonTitleNode: TextNode

    private var absoluteRect: (CGRect, CGSize)?

    required public init() {
        self.backgroundColorNode = ASDisplayNode()
        self.backgroundColorNode.isLayerBacked = true
        self.backgroundColorNode.clipsToBounds = true

        self.badgeBackgroundView = UIImageView()
        self.badgeBackgroundView.contentMode = .scaleAspectFit
        self.badgeBackgroundView.image = UIImage(bundleImageName: "Chat/Message/UnsupportedIconBackground")?.withRenderingMode(.alwaysTemplate)

        self.badgeIconView = UIImageView()
        self.badgeIconView.contentMode = .scaleAspectFit
        self.badgeIconView.image = UIImage(bundleImageName: "Chat/Message/UnsupportedIcon")?.withRenderingMode(.alwaysTemplate)

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false

        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false

        self.buttonNode = HighlightTrackingButton()
        self.buttonNode.clipsToBounds = true

        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false

        super.init()

        self.addSubnode(self.backgroundColorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.buttonNode.layer.removeAnimation(forKey: "opacity")
                self.buttonNode.alpha = 0.6
            } else {
                self.buttonNode.alpha = 1.0
                self.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didLoad() {
        super.didLoad()

        self.view.addSubview(self.badgeBackgroundView)
        self.view.addSubview(self.badgeIconView)
        self.view.addSubview(self.buttonNode)
        self.buttonNode.addSubview(self.buttonTitleNode.view)
    }

    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openAppStorePage()
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)

        return { item, layoutConstants, _, _, constrainedSize, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .none)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let presentationData = item.presentationData
                let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                let primaryTextColor = serviceColor.primaryText

                // The button is sized by its own label, so measure it first: whatever it takes is
                // subtracted from the width the title and subtitle get to wrap within.
                let buttonTitleString = NSAttributedString(
                    string: presentationData.strings.Conversation_UnsupportedMedia_Action,
                    font: Font.semibold(15.0),
                    textColor: primaryTextColor
                )
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(
                    attributedString: buttonTitleString,
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: max(1.0, constrainedSize.width / 2.0), height: CGFloat.greatestFiniteMagnitude),
                    alignment: .natural,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))
                let buttonSize = CGSize(
                    width: buttonTitleLayout.size.width + buttonHorizontalPadding * 2.0,
                    height: buttonTitleLayout.size.height + buttonVerticalPadding * 2.0
                )

                let fixedWidth = contentInsets.left + badgeDiameter + badgeTextSpacing + textButtonSpacing + buttonSize.width + contentInsets.right
                let maximumTextWidth = max(1.0, constrainedSize.width - fixedWidth)

                let titleString = NSAttributedString(
                    string: presentationData.strings.Conversation_UnsupportedMedia_Title,
                    font: Font.semibold(15.0),
                    textColor: primaryTextColor
                )
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(
                    attributedString: titleString,
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: maximumTextWidth, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .natural,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let subtitleString = NSAttributedString(
                    string: presentationData.strings.Conversation_UnsupportedMedia_Text,
                    font: Font.regular(13.0),
                    textColor: primaryTextColor.withMultipliedAlpha(subtitleAlpha)
                )
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(
                    attributedString: subtitleString,
                    backgroundColor: nil,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    constrainedSize: CGSize(width: maximumTextWidth, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .natural,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let textColumnWidth = max(titleLayout.size.width, subtitleLayout.size.width)
                let textColumnHeight = titleLayout.size.height + titleSubtitleSpacing + subtitleLayout.size.height

                let initialWidth = fixedWidth + textColumnWidth
                let contentHeight = contentInsets.top + max(badgeDiameter, max(textColumnHeight, buttonSize.height)) + contentInsets.bottom

                return (initialWidth, { boundingWidth in
                    let backgroundSize = CGSize(width: boundingWidth, height: contentHeight)

                    return (backgroundSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item

                        let _ = titleApply()
                        let _ = subtitleApply()
                        let _ = buttonTitleApply()

                        let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
                        let cornerRadius = min(backgroundSize.height * 0.5, maximumCornerRadius)

                        if self.backgroundNode == nil, let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            self.backgroundNode = backgroundNode
                            self.insertSubnode(backgroundNode, at: 0)
                        }

                        if let backgroundNode = self.backgroundNode {
                            self.backgroundColorNode.isHidden = true

                            backgroundNode.clipsToBounds = true
                            backgroundNode.cornerRadius = cornerRadius
                            animation.animator.updateFrame(layer: backgroundNode.layer, frame: backgroundFrame, completion: nil)

                            if let (rect, size) = self.absoluteRect {
                                self.updateAbsoluteRect(rect, within: size)
                            }
                        } else {
                            self.backgroundColorNode.isHidden = false
                            self.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                            self.backgroundColorNode.cornerRadius = cornerRadius
                            animation.animator.updateFrame(layer: self.backgroundColorNode.layer, frame: backgroundFrame, completion: nil)
                        }

                        let isDark = presentationData.theme.theme.overallDarkAppearance

                        // The badge reads as a recess and the button as a raised surface, so they
                        // move in opposite directions from the background rather than sharing a fill.
                        let badgeFrame = CGRect(
                            origin: CGPoint(x: contentInsets.left, y: floorToScreenPixels((backgroundSize.height - badgeDiameter) / 2.0)),
                            size: CGSize(width: badgeDiameter, height: badgeDiameter)
                        )
                        animation.animator.updateFrame(layer: self.badgeBackgroundView.layer, frame: badgeFrame, completion: nil)
                        self.badgeBackgroundView.tintColor = UIColor(rgb: 0x000000)
                        self.badgeBackgroundView.alpha = isDark ? badgeBackgroundAlpha.dark : badgeBackgroundAlpha.light

                        // Same frame as the background: the plane's position inside the bubble is
                        // baked into the asset, so any inset here would push it off centre.
                        animation.animator.updateFrame(layer: self.badgeIconView.layer, frame: badgeFrame, completion: nil)
                        self.badgeIconView.tintColor = primaryTextColor

                        let textColumnX = badgeFrame.maxX + badgeTextSpacing
                        let textColumnY = floorToScreenPixels((backgroundSize.height - textColumnHeight) / 2.0)

                        let titleFrame = CGRect(origin: CGPoint(x: textColumnX, y: textColumnY), size: titleLayout.size)
                        animation.animator.updateFrame(layer: self.titleNode.layer, frame: titleFrame, completion: nil)

                        let subtitleFrame = CGRect(origin: CGPoint(x: textColumnX, y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleLayout.size)
                        animation.animator.updateFrame(layer: self.subtitleNode.layer, frame: subtitleFrame, completion: nil)

                        let buttonFrame = CGRect(
                            origin: CGPoint(
                                x: backgroundSize.width - contentInsets.right - buttonSize.width,
                                y: floorToScreenPixels((backgroundSize.height - buttonSize.height) / 2.0)
                            ),
                            size: buttonSize
                        )
                        animation.animator.updateFrame(layer: self.buttonNode.layer, frame: buttonFrame, completion: nil)

                        self.buttonNode.layer.cornerRadius = buttonSize.height * 0.5
                        self.buttonNode.backgroundColor = UIColor(rgb: isDark ? 0xffffff : 0x000000, alpha: 0.12)
                        self.buttonNode.accessibilityLabel = presentationData.strings.Conversation_UnsupportedMedia_Action

                        self.buttonTitleNode.frame = CGRect(
                            origin: CGPoint(
                                x: floorToScreenPixels((buttonSize.width - buttonTitleLayout.size.width) / 2.0),
                                y: floorToScreenPixels((buttonSize.height - buttonTitleLayout.size.height) / 2.0)
                            ),
                            size: buttonTitleLayout.size
                        )
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)

    }

    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }

    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}
