import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextWithEntitiesComponent
import TextBadgeComponent
import LiquidLens

public final class ChatListTabsComponent: Component {
    public enum Tab: Equatable {
        public struct UnreadCount: Equatable {
            public let value: Int
            public let hasUnmuted: Bool
            
            public init(value: Int, hasUnmuted: Bool) {
                self.value = value
                self.hasUnmuted = hasUnmuted
            }
        }
        
        public enum Id: Hashable {
            case all
            case filter(id: Int32)
        }
        
        case all
        case filter(id: Int32, text: ChatFolderTitle, unread: UnreadCount)
        
        public var id: Id {
            switch self {
            case .all:
                return .all
            case let .filter(id, _, _):
                return .filter(id: id)
            }
        }
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let tabs: [Tab]
    public let selectedTab: Tab.Id?
    public let selectTab: (Tab.Id) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        tabs: [Tab],
        selectedTab: Tab.Id?,
        selectTab: @escaping (Tab.Id) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.tabs = tabs
        self.selectedTab = selectedTab
        self.selectTab = selectTab
    }
    
    public static func ==(lhs: ChatListTabsComponent, rhs: ChatListTabsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.tabs != rhs.tabs {
            return false
        }
        if lhs.selectedTab != rhs.selectedTab {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct LayoutData {
        var size: CGSize
        var selectedItemFrame: CGRect
        
        init(size: CGSize, selectedItemFrame: CGRect) {
            self.size = size
            self.selectedItemFrame = selectedItemFrame
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate {
        private let lensView: LiquidLensView
        private let scrollView: ScrollView
        private let selectionView: UIImageView
        private var itemViews: [Tab.Id: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        private var tabSwitchFraction: CGFloat = 0.0
        private var temporaryLiftTimer: Foundation.Timer?
        
        private var layoutData: LayoutData?
        
        private var component: ChatListTabsComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.lensView = LiquidLensView(kind: .noContainer)
            self.scrollView = ScrollView()
            
            self.selectionView = UIImageView()
            //self.scrollView.addSubview(self.selectionView)
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.scrollsToTop = false
            self.scrollView.clipsToBounds = false
            self.scrollView.delegate = self
            
            self.addSubview(self.lensView)
            
            self.lensView.contentView.addSubview(self.scrollView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return self.scrollView.hitTest(self.convert(point, to: self.scrollView), with: event)
        }
        
        public func updateTabSwitchFraction(fraction: CGFloat, transition: ComponentTransition) {
            self.tabSwitchFraction = -fraction
            self.state?.updated(transition: transition, isLocal: true)
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            self.updateScrolling(transition: .immediate)
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let layoutData = self.layoutData else {
                return
            }
            self.lensView.update(size: layoutData.size, selectionX: -self.scrollView.contentOffset.x + layoutData.selectedItemFrame.minX, selectionWidth: layoutData.selectedItemFrame.width, isDark: component.theme.overallDarkAppearance, isLifted: self.temporaryLiftTimer != nil, transition: transition)
        }
        
        func update(component: ChatListTabsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component?.selectedTab != component.selectedTab {
                self.tabSwitchFraction = 0.0
                
                self.temporaryLiftTimer?.invalidate()
                self.temporaryLiftTimer = nil
                
                if !transition.animation.isImmediate {
                    self.temporaryLiftTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { [weak self] timer in
                        guard let self else {
                            return
                        }
                        if self.temporaryLiftTimer === timer {
                            self.temporaryLiftTimer = nil
                            self.state?.updated(transition: .spring(duration: 0.5))
                        }
                    })
                }
            }
            
            self.component = component
            self.state = state
            
            let size = CGSize(width: availableSize.width, height: 40.0)
            let sideInset: CGFloat = 3.0
            
            var contentWidth: CGFloat = sideInset
            
            var validIds: [Tab.Id] = []
            for tab in component.tabs {
                let tabId = tab.id
                validIds.append(tabId)
                
                var itemTransition = transition
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[tabId] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[tabId] = itemView
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        context: component.context,
                        theme: component.theme,
                        strings: component.strings,
                        tab: tab,
                        selectAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.selectTab(tabId)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 1000.0, height: size.height)
                )
                let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: 0.0), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                        transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0)
                        transition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                }
                    
                contentWidth += itemSize.width
            }
            contentWidth += sideInset
            
            var removedIds: [Tab.Id] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setScale(view: itemComponentView, scale: 0.001)
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                }
            }
            for id in removedIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            var selectedItemFrame: CGRect?
            if let selectedTab = component.selectedTab {
                for i in 0 ..< component.tabs.count {
                    if component.tabs[i].id == selectedTab {
                        if let itemView = self.itemViews[component.tabs[i].id]?.view {
                            var selectedItemFrameValue = itemView.frame
                            
                            var pendingItemFrame: CGRect?
                            if self.tabSwitchFraction != 0.0 {
                                if self.tabSwitchFraction > 0.0 && i != component.tabs.count - 1 {
                                    if let nextItemView = self.itemViews[component.tabs[i + 1].id]?.view {
                                        pendingItemFrame = nextItemView.frame
                                    }
                                } else if self.tabSwitchFraction < 0.0 && i != 0 {
                                    if let previousItemView = self.itemViews[component.tabs[i - 1].id]?.view {
                                        pendingItemFrame = previousItemView.frame
                                    }
                                }
                            }
                            if let pendingItemFrame {
                                let fraction = abs(self.tabSwitchFraction)
                                selectedItemFrameValue.origin.x = selectedItemFrameValue.minX * (1.0 - fraction) + pendingItemFrame.minX * fraction
                                selectedItemFrameValue.size.width = selectedItemFrameValue.width * (1.0 - fraction) + pendingItemFrame.width * fraction
                            }
                            
                            selectedItemFrame = selectedItemFrameValue
                        }
                        break
                    }
                }
            }
            
            if let selectedItemFrame {
                var selectionTransition = transition
                if self.selectionView.isHidden {
                    self.selectionView.isHidden = false
                    selectionTransition = selectionTransition.withAnimation(.none)
                }
                let selectionFrame = CGRect(origin: CGPoint(x: selectedItemFrame.minX, y: 3.0), size: CGSize(width: selectedItemFrame.width, height: size.height - 3.0 * 2.0))
                
                if self.selectionView.image?.size.height != selectionFrame.height {
                    self.selectionView.image = generateStretchableFilledCircleImage(diameter: selectionFrame.height, color: .white)?.withRenderingMode(.alwaysTemplate)
                }
                self.selectionView.tintColor = component.theme.chat.inputPanel.panelControlColor.withAlphaComponent(0.1)
                
                selectionTransition.setFrame(view: self.selectionView, frame: selectionFrame)
            } else {
                self.selectionView.isHidden = true
            }
            
            self.layoutData = LayoutData(
                size: size,
                selectedItemFrame: selectedItemFrame ?? CGRect()
            )
            
            self.ignoreScrolling = true
            let contentSize = CGSize(width: contentWidth, height: size.height)
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: size))
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            
            transition.setFrame(view: self.lensView, frame: CGRect(origin: CGPoint(), size: size))
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let tab: ChatListTabsComponent.Tab
    let selectAction: () -> Void
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, tab: ChatListTabsComponent.Tab, selectAction: @escaping () -> Void) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.tab = tab
        self.selectAction = selectAction
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.tab != rhs.tab {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let title = ComponentView<Empty>()
        var badge: ComponentView<Empty>?
        
        var component: ItemComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.selectAction()
            }
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 16.0
            let badgeSpacing: CGFloat = 5.0
            
            let font = Font.medium(15.0)
            let titleString: NSAttributedString
            var badgeData: (title: String, isActive: Bool)?
            switch component.tab {
            case .all:
                titleString = NSAttributedString(string: component.strings.ChatList_Tabs_All, font: font, textColor: component.theme.chat.inputPanel.panelControlColor)
            case let .filter(_, text, unread):
                titleString = text.attributedString(font: font, textColor: component.theme.chat.inputPanel.panelControlColor)
                if unread.value != 0 {
                    badgeData = ("\(unread.value)", unread.hasUnmuted)
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: component.theme.chat.inputPanel.panelControlColor.withMultipliedAlpha(0.1),
                    text: .plain(titleString),
                    displaysAsynchronously: false
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            
            var size = CGSize(width: sideInset + titleSize.width, height: availableSize.height)
            
            if let badgeData {
                let badge: ComponentView<Empty>
                var badgeTransition = transition
                if let current = self.badge {
                    badge = current
                } else {
                    badgeTransition = badgeTransition.withAnimation(.none)
                    badge = ComponentView()
                    self.badge = badge
                }
                let badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(TextBadgeComponent(
                        text: badgeData.title,
                        font: Font.medium(12.0),
                        background: badgeData.isActive ? component.theme.list.itemCheckColors.fillColor : component.theme.chatList.unreadBadgeInactiveBackgroundColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        insets: UIEdgeInsets(top: 1.0, left: 5.0, bottom: 2.0, right: 5.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                size.width += badgeSpacing
                let badgeFrame = CGRect(origin: CGPoint(x: size.width, y: floorToScreenPixels((size.height - badgeSize.height) * 0.5)), size: badgeSize)
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        self.addSubview(badgeView)
                        transition.animateAlpha(view: badgeView, from: 0.0, to: 1.0)
                        transition.animateScale(view: badgeView, from: 0.001, to: 1.0)
                    }
                    badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                }
                size.width += badgeSize.width
            } else if let badge = self.badge {
                self.badge = nil
                if let badgeView = badge.view {
                    transition.setFrame(view: badgeView, frame: badgeView.bounds.size.centered(around: CGPoint(x: size.width + sideInset - badgeView.bounds.width * 0.5, y: size.height * 0.5)))
                    transition.setScale(view: badgeView, scale: 0.001)
                    transition.setAlpha(view: badgeView, alpha: 0.0, completion: { [weak badgeView] _ in
                        badgeView?.removeFromSuperview()
                    })
                }
            }
            
            size.width += sideInset
            
            let titleFrame = CGRect(origin: CGPoint(x: sideInset, y: floorToScreenPixels((size.height - titleSize.height) * 0.5)), size: titleSize)
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
