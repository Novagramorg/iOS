import Foundation
import UIKit
import ComponentFlow
import Display
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import TelegramPresentationData
import TelegramCore
import AvatarNode
import AccountContext
import StarsParticleEffect
import AppBundle

private func generateStarsAmountImage() -> UIImage {
    return UIImage(bundleImageName: "Chat/Message/StarsCount")!.precomposed().withRenderingMode(.alwaysTemplate)
}

public final class StoryLiveChatMessageComponent: Component {
    public struct Layout: Equatable {
        public var isFlipped: Bool
        public var insets: UIEdgeInsets
        public var fitToWidth: Bool
        public var transparentBackground: Bool
        
        public init(isFlipped: Bool, insets: UIEdgeInsets, fitToWidth: Bool, transparentBackground: Bool) {
            self.isFlipped = isFlipped
            self.insets = insets
            self.fitToWidth = fitToWidth
            self.transparentBackground = transparentBackground
        }
    }
    
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let layout: Layout
    let message: GroupCallMessagesContext.Message
    let contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
    
    public init(
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        layout: Layout,
        message: GroupCallMessagesContext.Message,
        contextGesture: ((ContextGesture, ContextExtractedContentContainingNode) -> Void)?
    ) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.layout = layout
        self.message = message
        self.contextGesture = contextGesture
    }
    
    public static func ==(lhs: StoryLiveChatMessageComponent, rhs: StoryLiveChatMessageComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.layout != rhs.layout {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        
        private let contentContainer: UIView
        private var avatarNode: AvatarNode?
        private let textExternal = MultilineTextWithEntitiesComponent.External()
        private let text = ComponentView<Empty>()
        private var backgroundView: UIImageView?
        private var effectLayer: StarsParticleEffectLayer?
        private var starsAmountBackgroundView: UIImageView?
        private var starsAmountIcon: UIImageView?
        private var starsAmountText: ComponentView<Empty>?

        private var component: StoryLiveChatMessageComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        static let starsAmountImage: UIImage = generateStarsAmountImage()
        
        override public init(frame: CGRect) {
            self.contentContainer = UIView()
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.contentContainer)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.contentContainer.addSubview(self.containerNode.view)
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                component.contextGesture?(gesture, self.extractedContainerNode)
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: StoryLiveChatMessageComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            self.contentContainer.transform = component.layout.isFlipped ? CGAffineTransformMakeRotation(-CGFloat.pi) : .identity
            
            self.containerNode.isGestureEnabled = component.contextGesture != nil
            
            let insets = component.layout.insets
            let avatarSize: CGFloat = 24.0
            let avatarSpacing: CGFloat = 6.0
            let avatarBackgroundInset: CGFloat = 4.0
            
            let primaryTextColor = UIColor(white: 1.0, alpha: 1.0)
            let secondaryTextColor = UIColor(white: 1.0, alpha: 0.8)
            
            var displayStarsAmountBackground = false
            var starsAmountTextSize: CGSize?
            if let paidStars = component.message.paidStars {
                displayStarsAmountBackground = component.message.text.isEmpty
                
                let starsAmountIcon: UIImageView
                if let current = self.starsAmountIcon {
                    starsAmountIcon = current
                } else {
                    starsAmountIcon = UIImageView()
                    self.starsAmountIcon = starsAmountIcon
                    self.extractedContainerNode.contentNode.view.addSubview(starsAmountIcon)
                    starsAmountIcon.image = View.starsAmountImage
                }
                starsAmountIcon.tintColor = secondaryTextColor
                
                let starsAmountText: ComponentView<Empty>
                if let current = self.starsAmountText {
                    starsAmountText = current
                } else {
                    starsAmountText = ComponentView()
                    self.starsAmountText = starsAmountText
                }
                
                starsAmountTextSize = starsAmountText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(paidStars)", font: Font.semibold(11.0), textColor: displayStarsAmountBackground ? primaryTextColor : secondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            } else {
                if let starsAmountIcon = self.starsAmountIcon {
                    self.starsAmountIcon = nil
                    starsAmountIcon.removeFromSuperview()
                }
                if let starsAmountText = self.starsAmountText {
                    self.starsAmountText = nil
                    starsAmountText.view?.removeFromSuperview()
                }
            }
            
            if displayStarsAmountBackground, let paidStars = component.message.paidStars, let baseColor = GroupCallMessagesContext.getStarAmountParamMapping(value: paidStars).color {
                let starsAmountBackgroundView: UIImageView
                if let current = self.starsAmountBackgroundView {
                    starsAmountBackgroundView = current
                } else {
                    starsAmountBackgroundView = UIImageView()
                    starsAmountBackgroundView.image = generateStretchableFilledCircleImage(diameter: 20.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                    self.starsAmountBackgroundView = starsAmountBackgroundView
                    
                    if let starsAmountIconView = self.starsAmountIcon {
                        self.extractedContainerNode.contentNode.view.insertSubview(starsAmountBackgroundView, belowSubview: starsAmountIconView)
                    } else {
                        self.extractedContainerNode.contentNode.view.addSubview(starsAmountBackgroundView)
                    }
                }
                starsAmountBackgroundView.tintColor = StoryLiveChatMessageComponent.getMessageColor(color: baseColor).withMultipliedBrightnessBy(0.7).withMultipliedAlpha(0.5)
            } else {
                if let starsAmountBackgroundView = self.starsAmountBackgroundView {
                    self.starsAmountBackgroundView = nil
                    starsAmountBackgroundView.removeFromSuperview()
                }
            }
            
            let textString = NSMutableAttributedString()
            textString.append(NSAttributedString(string: component.message.author?.displayTitle(strings: component.strings, displayOrder: .firstLast) ?? " ", font: Font.semibold(15.0), textColor: secondaryTextColor))
            if !component.message.text.isEmpty {
                textString.append(NSAttributedString(string: "  ", font: Font.semibold(15.0), textColor: secondaryTextColor))
                textString.append(NSAttributedString(string: component.message.text, font: Font.regular(15.0), textColor: primaryTextColor))
            }
            
            var textCutout: TextNodeCutout?
            if let starsAmountTextSize {
                var cutoutWidth: CGFloat = starsAmountTextSize.width + 20.0
                if displayStarsAmountBackground {
                    cutoutWidth += 10.0
                }
                textCutout = TextNodeCutout(bottomRight: CGSize(width: cutoutWidth, height: 4.0))
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    external: self.textExternal,
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: .gray,
                    text: .plain(textString),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    cutout: textCutout
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - insets.left - insets.right - avatarSize - avatarSpacing, height: 100000.0)
            )
            
            var avatarFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: avatarSize, height: avatarSize))
            if component.message.paidStars != nil {
                avatarFrame.origin.y += avatarBackgroundInset
                if component.layout.fitToWidth {
                    avatarFrame.origin.x += avatarBackgroundInset
                }
            }
            do {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
                    self.avatarNode = avatarNode
                    self.extractedContainerNode.contentNode.view.addSubview(avatarNode.view)
                }
                transition.setFrame(view: avatarNode.view, frame: avatarFrame)
                avatarNode.updateSize(size: avatarFrame.size)
                if let peer = component.message.author {
                    if peer.smallProfileImage != nil {
                        avatarNode.setPeerV2(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    } else {
                        avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
                    }
                } else {
                    avatarNode.setCustomLetters([" "])
                }
            }
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + avatarSize + avatarSpacing, y: avatarFrame.minY + 4.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.extractedContainerNode.contentNode.view.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            let backgroundOrigin = CGPoint(x: avatarFrame.minX - avatarBackgroundInset, y: avatarFrame.minY - avatarBackgroundInset)
            var backgroundFrame = CGRect(origin: backgroundOrigin, size: CGSize(width: textFrame.maxX + 8.0 - backgroundOrigin.x, height: avatarFrame.maxY + avatarBackgroundInset - backgroundOrigin.y))
            if let textLayout = self.textExternal.layout {
                if textLayout.numberOfLines > 1 {
                    backgroundFrame.size.height = max(backgroundFrame.size.height, textFrame.maxY + 8.0 - backgroundOrigin.y)
                }
            }
            
            if let starsAmountTextSize, let starsAmountTextView = self.starsAmountText?.view, let starsAmountIcon = self.starsAmountIcon {
                let starsAmountTextFrame: CGRect
                
                if displayStarsAmountBackground, let starsAmountBackgroundView = self.starsAmountBackgroundView {
                    let starsAmountBackgroundSize = CGSize(width: starsAmountTextSize.width + 5.0 + 20.0, height: 20.0)
                    let starsAmountBackgroundFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 6.0 - starsAmountBackgroundSize.width, y: backgroundFrame.minY + floor((backgroundFrame.height - starsAmountBackgroundSize.height) * 0.5)), size: starsAmountBackgroundSize)
                    transition.setFrame(view: starsAmountBackgroundView, frame: starsAmountBackgroundFrame)
                    
                    starsAmountTextFrame = CGRect(origin: CGPoint(x: starsAmountBackgroundFrame.maxX - starsAmountTextSize.width - 5.0, y: starsAmountBackgroundFrame.minY + UIScreenPixel + floor((starsAmountBackgroundFrame.height - starsAmountTextSize.height) * 0.5)), size: starsAmountTextSize)
                } else {
                    starsAmountTextFrame = CGRect(origin: CGPoint(x: textFrame.maxX - starsAmountTextSize.width - 1.0, y: textFrame.maxY - starsAmountTextSize.height + 1.0), size: starsAmountTextSize)
                }
                
                if starsAmountTextView.superview == nil {
                    starsAmountTextView.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
                    self.extractedContainerNode.contentNode.view.addSubview(starsAmountTextView)
                }
                transition.setPosition(view: starsAmountTextView, position: CGPoint(x: starsAmountTextFrame.maxX, y: starsAmountTextFrame.maxY))
                starsAmountTextView.bounds = CGRect(origin: CGPoint(), size: starsAmountTextFrame.size)
                
                if let image = starsAmountIcon.image {
                    let starsAmountIconFrame = CGRect(origin: CGPoint(x: starsAmountTextFrame.minX - 2.0 - image.size.width, y: starsAmountTextFrame.minY + UIScreenPixel), size: image.size)
                    transition.setFrame(view: starsAmountIcon, frame: starsAmountIconFrame)
                }
            }
            
            let size = CGSize(width: component.layout.fitToWidth ? backgroundFrame.maxX : availableSize.width, height: backgroundFrame.maxY)
            
            let backgroundCornerRadius = (avatarSize + avatarBackgroundInset * 2.0) * 0.5
            
            if let paidStars = component.message.paidStars, let baseColor = GroupCallMessagesContext.getStarAmountParamMapping(value: paidStars).color {
                let backgroundView: UIImageView
                if let current = self.backgroundView {
                    backgroundView = current
                } else {
                    backgroundView = UIImageView()
                    self.backgroundView = backgroundView
                    self.extractedContainerNode.contentNode.view.insertSubview(backgroundView, at: 0)
                    backgroundView.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
                
                backgroundView.tintColor = StoryLiveChatMessageComponent.getMessageColor(color: baseColor).withAlphaComponent(component.layout.transparentBackground ? 0.7 : 1.0)
                
                let effectLayer: StarsParticleEffectLayer
                if let current = self.effectLayer {
                    effectLayer = current
                } else {
                    effectLayer = StarsParticleEffectLayer()
                    self.effectLayer = effectLayer
                    backgroundView.layer.addSublayer(effectLayer)
                }
                
                transition.setFrame(layer: effectLayer, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
                effectLayer.update(color: UIColor(white: 1.0, alpha: 0.5), size: backgroundFrame.size, cornerRadius: backgroundCornerRadius, transition: transition)
            } else if let backgroundView = self.backgroundView {
                self.backgroundView = nil
                backgroundView.removeFromSuperview()
                
                if let effectLayer = self.effectLayer {
                    self.effectLayer = nil
                    effectLayer.removeFromSuperlayer()
                }
            }
            
            let contentFrame = CGRect(origin: CGPoint(), size: size)
            transition.setPosition(view: self.contentContainer, position: contentFrame.center)
            transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = backgroundFrame.insetBy(dx: -4.0, dy: 0.0)
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }

    public static func getMessageColor(color: GroupCallMessagesContext.Message.Color) -> UIColor {
        switch color {
        case .silver:
            return UIColor(rgb: 0x7C8695)
        case .red:
            return UIColor(rgb: 0xE6514E)
        case .orange:
            return UIColor(rgb: 0xEE7E20)
        case .yellow:
            return UIColor(rgb: 0xE4A20A)
        case .green:
            return UIColor(rgb: 0x5AB03D)
        case .blue:
            return UIColor(rgb: 0x3E9CDF)
        case .purple:
            return UIColor(rgb: 0x985FDC)
        }
    }
}
