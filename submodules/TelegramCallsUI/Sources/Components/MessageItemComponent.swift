import Foundation
import Display
import UIKit
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AvatarNode
import GlassBackgroundComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import AccountContext
import TextFormat
import TelegramPresentationData
import ReactionSelectionNode

final class MessageItemComponent: Component {
    private let context: AccountContext
    private let peer: EnginePeer
    private let text: String
    private let entities: [MessageTextEntity]
    private let availableReactions: [ReactionItem]?
    private let avatarTapped: () -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        text: String,
        entities: [MessageTextEntity],
        availableReactions: [ReactionItem]?,
        avatarTapped: @escaping () -> Void = {}
    ) {
        self.context = context
        self.peer = peer
        self.text = text
        self.entities = entities
        self.availableReactions = availableReactions
        self.avatarTapped = avatarTapped
    }
    
    static func == (lhs: MessageItemComponent, rhs: MessageItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if (lhs.availableReactions ?? []).isEmpty != (rhs.availableReactions ?? []).isEmpty {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let container: UIView
        private let background: GlassBackgroundView
        private let avatarNode: AvatarNode
        private let text: ComponentView<Empty>
        weak var standaloneReactionAnimation: StandaloneReactionAnimation?
        
        private var component: MessageItemComponent?
        
        override init(frame: CGRect) {
            self.container = UIView()
            self.container.transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
            
            self.background = GlassBackgroundView()
            
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
            
            self.text = ComponentView()
            
            super.init(frame: frame)
                        
            self.addSubview(self.container)
            self.container.addSubview(self.background)
            self.container.addSubview(self.avatarNode.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func animateFrom(globalFrame: CGRect, cornerRadius: CGFloat, textSnapshotView: UIView, transition: ComponentTransition) {
            guard let superview = self.superview?.superview?.superview else {
                return
            }
            
            let originalCenter = self.container.center
            let originalTransform = self.container.transform
            
            let superviewCenter = self.convert(self.container.center, to: superview)
            self.container.center = superviewCenter
            self.container.transform = .identity
            superview.addSubview(self.container)
            
            self.container.addSubview(textSnapshotView)
            transition.setAlpha(view: textSnapshotView, alpha: 0.0, completion: { _ in
                textSnapshotView.removeFromSuperview()
            })
            transition.setPosition(view: textSnapshotView, position: CGPoint(x: textSnapshotView.center.x + 71.0, y: textSnapshotView.center.y))
            
            let initialSize = self.background.frame.size
            self.background.update(size: globalFrame.size, cornerRadius: cornerRadius, isDark: true, tintColor: UIColor(rgb: 0x1b1d22), transition: .immediate)
            self.background.update(size: initialSize, cornerRadius: 18.0, isDark: true, tintColor: UIColor(rgb: 0x1b1d22), transition: transition)
            
            let deltaX = (globalFrame.width - self.container.frame.width) / 2.0
            let deltaY = (globalFrame.height - self.container.frame.height) / 2.0
            let fromFrame = superview.convert(globalFrame, from: nil).offsetBy(dx: -deltaX, dy: -deltaY)
            
            self.container.center = fromFrame.center
            transition.setPosition(view: self.container, position: superviewCenter, completion: { _ in
                self.container.center = originalCenter
                self.container.transform = originalTransform
                self.insertSubview(self.container, at: 0)
            })
            
            if let textView = self.text.view {
                transition.animatePosition(view: textView, from: CGPoint(x: -71.0, y: 0.0), to: .zero, additive: true)
                transition.animateAlpha(view: textView, from: 0.0, to: 1.0)
            }
            transition.animateAlpha(view: self.avatarNode.view, from: 0.0, to: 1.0)
            transition.animateScale(view: self.avatarNode.view, from: 0.01, to: 1.0)
        }
        
        func update(component: MessageItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            var transition = transition
            if isFirstTime {
                transition = .immediate
            }
            self.component = component
            
            let theme = defaultDarkPresentationTheme
            
            let backgroundColor = UIColor(rgb: 0x1b1d22)
            
            let textFont = Font.regular(14.0)
            let boldTextFont = Font.semibold(14.0)
            let textColor: UIColor = .white
            let linkColor: UIColor = UIColor(rgb: 0x59b6fa)
                        
            let minimalHeight: CGFloat = 36.0
            let cornerRadius = minimalHeight * 0.5
            let avatarInset: CGFloat = 4.0
            let avatarSize = CGSize(width: minimalHeight - avatarInset * 2.0, height: minimalHeight - avatarInset * 2.0)
            let avatarSpacing: CGFloat = 10.0
            let rightInset: CGFloat = 13.0
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarInset, y: avatarInset), size: avatarSize)
            if component.peer.smallProfileImage != nil {
                self.avatarNode.setPeerV2(
                    context: component.context,
                    theme: theme,
                    peer: component.peer,
                    authorOfMessage: nil,
                    overrideImage: nil,
                    emptyColor: nil,
                    clipStyle: .round,
                    synchronousLoad: true,
                    displayDimensions: avatarSize
                )
            } else {
                self.avatarNode.setPeer(
                    context: component.context,
                    theme: theme,
                    peer: component.peer,
                    clipStyle: .round,
                    synchronousLoad: true,
                    displayDimensions: avatarSize
                )
            }
            if self.avatarNode.bounds.isEmpty {
                self.avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(view: self.avatarNode.view, frame: avatarFrame)
            }
                        
            let attributedText = stringWithAppliedEntities(component.text, entities: component.entities, baseColor: textColor, linkColor: linkColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: textFont, boldItalicFont: boldTextFont, fixedFont: textFont, blockQuoteFont: textFont, message: nil).mutableCopy() as! NSMutableAttributedString
            attributedText.insert(NSAttributedString(string: component.peer.compactDisplayTitle + " ", font: boldTextFont, textColor: textColor), at: 0)
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: .white,
                    text: .plain(attributedText),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarInset - avatarSize.width - avatarSpacing - rightInset, height: .greatestFiniteMagnitude)
            )
            
            let size = CGSize(width: avatarInset + avatarSize.width + avatarSpacing + textSize.width + rightInset, height: max(minimalHeight, textSize.height + 15.0))
            
            let textFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize.width + avatarSpacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.container.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            
            transition.setFrame(view: self.container, frame: CGRect(origin: CGPoint(), size: size))

            self.background.update(size: size, cornerRadius: cornerRadius, isDark: true, tintColor: backgroundColor, transition: transition)
            transition.setFrame(view: self.background, frame: CGRect(origin: CGPoint(), size: size))
            
            if isFirstTime, let availableReactions = component.availableReactions, let textView = self.text.view {
                var reactionItem: ReactionItem?
                for item in availableReactions {
                    if case .builtin(component.text.strippedEmoji) = item.reaction.rawValue {
                        reactionItem = item
                        break
                    }
                }
                
                if let reactionItem {
                    Queue.mainQueue().justDispatch {
                        guard let listView = self.superview else {
                            return
                        }
                        
                        let emojiTargetView = UIView(frame: CGRect(origin: CGPoint(x: textView.frame.width - 44.0, y: 0.0), size: CGSize(width: 44.0, height: 44.0)))
                        emojiTargetView.isUserInteractionEnabled = false
                        textView.addSubview(emojiTargetView)
                        
                        let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: nil, useDirectRendering: false)
                        self.container.addSubview(standaloneReactionAnimation.view)
                        
                        if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                            self.standaloneReactionAnimation = nil
                            standaloneReactionAnimation.view.removeFromSuperview()
                        }
                        self.standaloneReactionAnimation = standaloneReactionAnimation
                        
                        standaloneReactionAnimation.frame = listView.bounds
                        standaloneReactionAnimation.animateReactionSelection(
                            context: component.context,
                            theme: theme,
                            animationCache: component.context.animationCache,
                            reaction: reactionItem,
                            avatarPeers: [],
                            playHaptic: true,
                            isLarge: false,
                            hideCenterAnimation: true,
                            targetView: emojiTargetView,
                            addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                                guard let self else {
                                    return
                                }
                                
                                if let standaloneReactionAnimation = self.standaloneReactionAnimation {
                                    self.standaloneReactionAnimation = nil
                                    standaloneReactionAnimation.view.removeFromSuperview()
                                }
                                self.standaloneReactionAnimation = standaloneReactionAnimation
                                
                                standaloneReactionAnimation.frame = self.bounds
                                listView.addSubview(standaloneReactionAnimation.view)
                            },
                            completion: { [weak standaloneReactionAnimation] in
                                standaloneReactionAnimation?.view.removeFromSuperview()
                            }
                        )
                    }
                }
            }
            
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
