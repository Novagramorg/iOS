import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AccountContext
import Postbox
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import TelegramCallsUI
import AsyncListComponent
import AvatarNode
import MultilineTextWithEntitiesComponent
import GlassBackgroundComponent
import MultilineTextComponent

private final class MessageItemComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let message: GroupCallMessagesContext.Message
    
    init(context: AccountContext, strings: PresentationStrings, theme: PresentationTheme, message: GroupCallMessagesContext.Message) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.message = message
    }
    
    static func ==(lhs: MessageItemComponent, rhs: MessageItemComponent) -> Bool {
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
        if lhs.message != rhs.message {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let contentContainer: UIView
        private var avatarNode: AvatarNode?
        private let text = ComponentView<Empty>()
        private var backgroundView: UIImageView?

        private var component: MessageItemComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.contentContainer = UIView()
            self.contentContainer.transform = CGAffineTransformMakeRotation(-CGFloat.pi)
            
            super.init(frame: frame)
            
            self.addSubview(self.contentContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: MessageItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let insets = UIEdgeInsets(top: 8.0, left: 20.0, bottom: 8.0, right: 20.0)
            let avatarSize: CGFloat = 24.0
            let avatarSpacing: CGFloat = 6.0
            
            let textString = NSMutableAttributedString()
            textString.append(NSAttributedString(string: component.message.author?.displayTitle(strings: component.strings, displayOrder: .firstLast) ?? " ", font: Font.semibold(15.0), textColor: UIColor(white: 0.9, alpha: 1.0)))
            textString.append(NSAttributedString(string: "  ", font: Font.semibold(15.0), textColor: UIColor(white: 0.9, alpha: 1.0)))
            textString.append(NSAttributedString(string: component.message.text, font: Font.regular(15.0), textColor: UIColor(white: 1.0, alpha: 1.0)))
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: .gray,
                    text: .plain(textString),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - insets.left - insets.right - avatarSize - avatarSpacing, height: 100000.0)
            )
            
            let size = CGSize(width: availableSize.width, height: insets.top + textSize.height + insets.bottom)
            
            let avatarFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top - 4.0), size: CGSize(width: avatarSize, height: avatarSize))
            do {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
                    self.avatarNode = avatarNode
                    self.contentContainer.addSubview(avatarNode.view)
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
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + avatarSize + avatarSpacing, y: insets.top), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    textView.layer.anchorPoint = CGPoint()
                    self.contentContainer.addSubview(textView)
                }
                transition.setPosition(view: textView, position: textFrame.origin)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            if let paidStars = component.message.paidStars {
                let backgroundView: UIImageView
                if let current = self.backgroundView {
                    backgroundView = current
                } else {
                    backgroundView = UIImageView()
                    self.backgroundView = backgroundView
                    self.contentContainer.insertSubview(backgroundView, at: 0)
                    backgroundView.image = generateStretchableFilledCircleImage(diameter: 28.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                let backgroundFrame = CGRect(origin: CGPoint(x: 16.0, y: 2.0), size: CGSize(width: textFrame.maxX + 8.0 - 16.0, height: textFrame.maxY + 3.0))
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
                backgroundView.tintColor = getStarAmountColorMapping(value: paidStars)
            } else if let backgroundView = self.backgroundView {
                self.backgroundView = nil
                backgroundView.removeFromSuperview()
            }
            
            let contentFrame = CGRect(origin: CGPoint(), size: size)
            transition.setPosition(view: self.contentContainer, position: contentFrame.center)
            transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func getStarAmountColorMapping(value: Int64) -> UIColor {
    if value >= 10000 {
        return UIColor(rgb: 0x7C8695)
    }
    if value >= 2000 {
        return UIColor(rgb: 0xE6514E)
    }
    if value >= 500 {
        return UIColor(rgb: 0xEE7E20)
    }
    if value >= 250 {
        return UIColor(rgb: 0xE4A20A)
    }
    if value >= 100 {
        return UIColor(rgb: 0x5AB03D)
    }
    if value >= 50 {
        return UIColor(rgb: 0x3E9CDF)
    }
    return UIColor(rgb: 0x985FDC)
}

private final class PinnedBarMessageComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let message: GroupCallMessagesContext.Message
    
    init(context: AccountContext, strings: PresentationStrings, theme: PresentationTheme, message: GroupCallMessagesContext.Message) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.message = message
    }
    
    static func ==(lhs: PinnedBarMessageComponent, rhs: PinnedBarMessageComponent) -> Bool {
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
        if lhs.message != rhs.message {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: UIImageView
        private let foregroundClippingView: UIView
        private let foregroundView: UIImageView
        
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()

        private var component: PinnedBarMessageComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var updateTimer: Foundation.Timer?
        
        override init(frame: CGRect) {
            self.backgroundView = UIImageView()
            self.foregroundClippingView = UIView()
            self.foregroundClippingView.clipsToBounds = true
            self.foregroundView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            
            self.foregroundClippingView.addSubview(self.foregroundView)
            self.addSubview(self.foregroundClippingView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.updateTimer?.invalidate()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: PinnedBarMessageComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.updateTimer == nil {
                self.updateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate, isLocal: true)
                    }
                })
            }
            
            self.component = component
            self.state = state
            
            let itemHeight: CGFloat = 32.0
            let avatarInset: CGFloat = 4.0
            let avatarSize: CGFloat = 24.0
            let avatarSpacing: CGFloat = 6.0
            let rightInset: CGFloat = 10.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.message.author?.displayTitle(strings: component.strings, displayOrder: .firstLast) ?? " ", font: Font.semibold(15.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 1000.0, height: itemHeight)
            )
            
            let size = CGSize(width: avatarInset + avatarSize + avatarSpacing + titleSize.width + rightInset, height: itemHeight)
            
            if self.backgroundView.image == nil {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: itemHeight, color: .white)?.withRenderingMode(.alwaysTemplate)
                self.foregroundView.image = self.backgroundView.image
            }
            
            let baseColor = getStarAmountColorMapping(value: component.message.paidStars ?? 0)
            self.backgroundView.tintColor = baseColor.withMultipliedBrightnessBy(0.7)
            self.foregroundView.tintColor = baseColor
            
            let timestamp = CFAbsoluteTimeGetCurrent()
            let currentDuration = max(0.0, timestamp - Double(component.message.date))
            let timeFraction: CGFloat = 1.0 - min(1.0, currentDuration / Double(component.message.lifetime))
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.foregroundView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.foregroundClippingView, frame: CGRect(origin: CGPoint(), size: CGSize(width: floorToScreenPixels(size.width * timeFraction), height: size.height)))
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarInset, y: floor((itemHeight - avatarSize) * 0.5)), size: CGSize(width: avatarSize, height: avatarSize))
            do {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 10.0))
                    self.avatarNode = avatarNode
                    self.addSubview(avatarNode.view)
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
            
            let titleFrame = CGRect(origin: CGPoint(x: avatarInset + avatarSize + avatarSpacing, y: floor((itemHeight - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class PinnedBarComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let isExpanded: Bool
    let messages: [GroupCallMessagesContext.Message]
    let toggleExpandedAction: () -> Void
    
    init(context: AccountContext, strings: PresentationStrings, theme: PresentationTheme, isExpanded: Bool, messages: [GroupCallMessagesContext.Message], toggleExpandedAction: @escaping () -> Void) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.isExpanded = isExpanded
        self.messages = messages
        self.toggleExpandedAction = toggleExpandedAction
    }
    
    static func ==(lhs: PinnedBarComponent, rhs: PinnedBarComponent) -> Bool {
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
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.messages != rhs.messages {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let listContainer: UIView
        private let listState = AsyncListComponent.ExternalState()
        private let list = ComponentView<Empty>()
        
        private let toggleButtonBackground: GlassBackgroundView
        private let toggleButton: HighlightTrackingButton
        private let toggleButtonIcon: UIImageView

        private var component: PinnedBarComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.listContainer = UIView()
            self.listContainer.clipsToBounds = true
            
            self.toggleButtonBackground = GlassBackgroundView()
            self.toggleButton = HighlightTrackingButton()
            self.toggleButtonIcon = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.listContainer)
            
            self.toggleButtonBackground.contentView.addSubview(self.toggleButtonIcon)
            self.toggleButtonBackground.contentView.addSubview(self.toggleButton)
            self.addSubview(self.toggleButtonBackground)
            
            self.toggleButton.addTarget(self, action: #selector(self.toggleButtonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func toggleButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.toggleExpandedAction()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: PinnedBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let itemHeight: CGFloat = 32.0
            
            let insets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
            
            let size = CGSize(width: availableSize.width, height: insets.top + itemHeight + insets.bottom)
            
            let toggleButtonFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: itemHeight, height: itemHeight))
            transition.setFrame(view: self.toggleButtonBackground, frame: toggleButtonFrame)
            self.toggleButtonBackground.update(size: toggleButtonFrame.size, cornerRadius: toggleButtonFrame.height * 0.5, isDark: true, tintColor: .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), isInteractive: true, transition: transition)
            transition.setFrame(view: self.toggleButton, frame: CGRect(origin: CGPoint(), size: toggleButtonFrame.size))
            if self.toggleButtonIcon.image == nil {
                self.toggleButtonIcon.image = UIImage(bundleImageName: "Chat/Context Menu/ReactionExpandArrow")?.withRenderingMode(.alwaysTemplate)
                self.toggleButtonIcon.tintColor = .white
            }
            if let image = self.toggleButtonIcon.image {
                var iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: toggleButtonFrame.size))
                iconFrame.origin.y += 1.0
                transition.setTransform(view: self.toggleButtonIcon, transform: CATransform3DMakeRotation((!component.isExpanded) ? CGFloat.pi : 0.0, 0.0, 0.0, 1.0))
                transition.setPosition(view: self.toggleButtonIcon, position: iconFrame.center)
                transition.setBounds(view: self.toggleButtonIcon, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            }
            
            var listItems: [AnyComponentWithIdentity<Empty>] = []
            for message in component.messages {
                if let author = message.author {
                    listItems.append(AnyComponentWithIdentity(id: author.id, component: AnyComponent(PinnedBarMessageComponent(
                        context: component.context,
                        strings: component.strings,
                        theme: component.theme,
                        message: message
                    ))))
                }
            }
            
            let listInsets = UIEdgeInsets(top: 0.0, left: 5.0, bottom: 0.0, right: 5.0 + 20.0)
            let listFrame = CGRect(origin: CGPoint(x: toggleButtonFrame.maxX, y: 0.0), size: CGSize(width: size.width - toggleButtonFrame.maxX, height: size.height))
            let _ = self.list.update(
                transition: transition,
                component: AnyComponent(AsyncListComponent(
                    externalState: self.listState,
                    items: listItems,
                    itemSetId: AnyHashable(0),
                    direction: .horizontal,
                    insets: listInsets
                )),
                environment: {},
                containerSize: listFrame.size
            )
            if let listView = self.list.view {
                if listView.superview == nil {
                    self.listContainer.addSubview(listView)
                }
                transition.setPosition(view: listView, position: CGRect(origin: CGPoint(), size: listFrame.size).center)
                transition.setBounds(view: listView, bounds: CGRect(origin: CGPoint(), size: listFrame.size))
            }
            
            transition.setFrame(view: self.listContainer, frame: listFrame)
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class StoryContentLiveChatComponent: Component {
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let call: PresentationGroupCall
    let insets: UIEdgeInsets
    
    init(
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        call: PresentationGroupCall,
        insets: UIEdgeInsets
    ) {
        self.context = context
        self.strings = strings
        self.theme = theme
        self.call = call
        self.insets = insets
    }

    static func ==(lhs: StoryContentLiveChatComponent, rhs: StoryContentLiveChatComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }

    final class View: UIView {
        private let listContainer: UIView
        private let listMaskContainer: UIView
        private let maskGradientView: UIImageView

        private let pinnedBar = ComponentView<Empty>()
        
        private let listState = AsyncListComponent.ExternalState()
        private let list = ComponentView<Empty>()
        private let listShadowView: UIView

        private var component: StoryContentLiveChatComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var messagesState: GroupCallMessagesContext.State?
        private var stateDisposable: Disposable?
        
        private var isChatExpanded: Bool = false
        
        override init(frame: CGRect) {
            self.listContainer = UIView()

            self.listMaskContainer = UIView()
            self.listContainer.mask = self.listMaskContainer

            self.maskGradientView = UIImageView()
            do {
                let height: CGFloat = 40.0
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 0
                let firstLocation = 0.0
                let colors = (0 ..< numSteps).map { i -> UIColor in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                    }
                }
                let locations = (0 ..< numSteps).map { i -> CGFloat in
                    if i < firstStep {
                        return 0.0
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step)
                    }
                }
                
                let image = generateGradientImage(size: CGSize(width: 8.0, height: height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!
                self.maskGradientView.image = generateImage(CGSize(width: image.size.width, height: image.size.height * 2.0), rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    image.draw(in: CGRect(origin: CGPoint(), size: image.size))
                    
                    let bottomFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - image.size.height), size: image.size)
                    context.translateBy(x: bottomFrame.midX, y: bottomFrame.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -bottomFrame.midX, y: -bottomFrame.midY)
                    
                    image.draw(in: bottomFrame)
                })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(height - 1.0))
            }
            self.listMaskContainer.addSubview(self.maskGradientView)
            
            self.listShadowView = UIView()
            self.listShadowView.isUserInteractionEnabled = false

            super.init(frame: frame)
            
            self.addSubview(self.listShadowView)
            self.addSubview(self.listContainer)
            
            self.isChatExpanded = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            return result
        }
        
        func update(component: StoryContentLiveChatComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            if self.component?.call !== component.call {
                self.stateDisposable?.dispose()
                if let call = component.call as? PresentationGroupCallImpl {
                    self.stateDisposable = (call.messagesState
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        var updateTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        if self.messagesState == nil {
                            updateTransition = .immediate
                        }
                        self.messagesState = state
                        if !self.isUpdating {
                            self.state?.updated(transition: updateTransition)
                        }
                    })
                }
            }
            
            self.component = component
            self.state = state
            
            var listItems: [AnyComponentWithIdentity<Empty>] = []
            var topMessageByPeerId: [EnginePeer.Id: GroupCallMessagesContext.Message] = [:]
            if let messagesState = self.messagesState {
                for message in messagesState.messages.reversed() {
                    listItems.append(AnyComponentWithIdentity(id: message.id, component: AnyComponent(MessageItemComponent(
                        context: component.context,
                        strings: component.strings,
                        theme: component.theme,
                        message: message
                    ))))
                    
                    if let author = message.author, let paidStars = message.paidStars {
                        if let current = topMessageByPeerId[author.id] {
                            if let currentPaidStars = current.paidStars, currentPaidStars < paidStars {
                                topMessageByPeerId[author.id] = message
                            }
                        } else {
                            topMessageByPeerId[author.id] = message
                        }
                    }
                }
            }
            let topMessages: [GroupCallMessagesContext.Message] = topMessageByPeerId.values.sorted(by: { lhs, rhs in
                let lhsValue = lhs.paidStars ?? 0
                let rhsValue = rhs.paidStars ?? 0
                if lhsValue != rhsValue {
                    return lhsValue > rhsValue
                }
                return lhs.date > rhs.date
            })
            
            let pinnedBarSize = self.pinnedBar.update(
                transition: transition,
                component: AnyComponent(PinnedBarComponent(
                    context: component.context,
                    strings: component.strings,
                    theme: component.theme,
                    isExpanded: self.isChatExpanded,
                    messages: topMessages,
                    toggleExpandedAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.isChatExpanded = !self.isChatExpanded
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            let pinnedBarFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - component.insets.bottom - pinnedBarSize.height), size: pinnedBarSize)
            if let pinnedBarView = self.pinnedBar.view {
                if pinnedBarView.superview == nil {
                    self.addSubview(pinnedBarView)
                }
                transition.setFrame(view: pinnedBarView, frame: pinnedBarFrame)
                transition.setAlpha(view: pinnedBarView, alpha: (listItems.isEmpty && topMessages.isEmpty) ? 0.0 : 1.0)
            }
            
            var listInsets = UIEdgeInsets(top: availableSize.height - pinnedBarFrame.minY, left: component.insets.right, bottom: component.insets.top, right: component.insets.left)
            listInsets.top += 4.0
            let _ = self.list.update(
                transition: transition,
                component: AnyComponent(AsyncListComponent(
                    externalState: self.listState,
                    items: listItems,
                    itemSetId: AnyHashable(0),
                    direction: .vertical,
                    insets: listInsets
                )),
                environment: {},
                containerSize: availableSize
            )
            let listFrame = CGRect(origin: CGPoint(), size: availableSize)
            if let listView = self.list.view {
                if listView.superview == nil {
                    listView.transform = CGAffineTransformMakeRotation(CGFloat.pi)
                    self.listContainer.addSubview(listView)
                }
                transition.setPosition(view: listView, position: listFrame.offsetBy(dx: 0.0, dy: self.isChatExpanded ? 0.0 : listFrame.height).center)
                transition.setBounds(view: listView, bounds: CGRect(origin: CGPoint(), size: listFrame.size))
            }
            
            transition.setFrame(view: self.listContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.listMaskContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let maskTopInset: CGFloat = component.insets.top - 20.0
            let maskBottomInset: CGFloat = availableSize.height - pinnedBarFrame.minY - 26.0
            transition.setFrame(view: self.maskGradientView, frame: CGRect(origin: CGPoint(x: 0.0, y: maskTopInset), size: CGSize(width: availableSize.width, height: max(0.0, availableSize.height - maskTopInset - maskBottomInset))))
            
            transition.setFrame(view: self.listShadowView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            self.listShadowView.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
            transition.setAlpha(view: self.listShadowView, alpha: self.isChatExpanded ? 1.0 : 0.0)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
