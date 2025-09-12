import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import GlassBackgroundComponent
import MultilineTextComponent
import LottieComponent
import UIKitRuntimeUtils
import BundleIconComponent
import TextBadgeComponent

public final class TabBarComponent: Component {
    public final class Item: Equatable {
        public let item: UITabBarItem
        public let action: (Bool) -> Void
        
        fileprivate var id: AnyHashable {
            return AnyHashable(ObjectIdentifier(self.item))
        }
        
        public init(item: UITabBarItem, action: @escaping (Bool) -> Void) {
            self.item = item
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.item !== rhs.item {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let items: [Item]
    public let selectedId: AnyHashable?
    
    public init(
        theme: PresentationTheme,
        items: [Item],
        selectedId: AnyHashable?
    ) {
        self.theme = theme
        self.items = items
        self.selectedId = selectedId
    }
    
    public static func ==(lhs: TabBarComponent, rhs: TabBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.selectedId != rhs.selectedId {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITabBarDelegate, UIGestureRecognizerDelegate {
        private let backgroundView: GlassBackgroundView
        private let selectionView: GlassBackgroundView.ContentImageView
        private let nativeTabBar: UITabBar?
        
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        private var selectedItemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var component: TabBarComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView(frame: CGRect())
            self.selectionView = GlassBackgroundView.ContentImageView()
            
            if #available(iOS 26.0, *) {
                self.nativeTabBar = UITabBar()
            } else {
                self.nativeTabBar = nil
            }
            
            super.init(frame: frame)
            
            if let nativeTabBar = self.nativeTabBar {
                self.addSubview(nativeTabBar)
                nativeTabBar.delegate = self
                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.onLongPressGesture(_:)))
                longPressGesture.delegate = self
                self.addGestureRecognizer(longPressGesture)
            } else {
                self.addSubview(self.backgroundView)
                self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            guard let component = self.component else {
                return
            }
            if let index = tabBar.items?.firstIndex(where: { $0 === item }) {
                if index < component.items.count {
                    component.items[index].action(false)
                }
            }
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        @objc private func onLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
            if case .began = recognizer.state {
                if let nativeTabBar = self.nativeTabBar {
                    func cancelGestures(view: UIView) {
                        for recognizer in view.gestureRecognizers ?? [] {
                            if NSStringFromClass(type(of: recognizer)).contains("sSelectionGestureRecognizer") {
                                recognizer.state = .cancelled
                            }
                        }
                        for subview in view.subviews {
                            cancelGestures(view: subview)
                        }
                    }
                    
                    cancelGestures(view: nativeTabBar)
                }
            }
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                let point = recognizer.location(in: self)
                var closestItemView: (AnyHashable, CGFloat)?
                for (id, itemView) in self.itemViews {
                    guard let itemView = itemView.view else {
                        continue
                    }
                    let distance = abs(point.x - itemView.center.x)
                    if let previousClosestItemView = closestItemView {
                        if previousClosestItemView.1 > distance {
                            closestItemView = (id, distance)
                        }
                    } else {
                        closestItemView = (id, distance)
                    }
                }
                
                if let (id, _) = closestItemView {
                    guard let item = component.items.first(where: { $0.id == id }) else {
                        return
                    }
                    item.action(false)
                    /*if previousSelectedIndex != closestNode.0 {
                     if let selectedIndex = self.selectedIndex, let _ = self.tabBarItems[selectedIndex].item.animationName {
                     container.imageNode.animationNode.play(firstFrame: false, fromIndex: nil)
                     }
                     }*/
                }
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        func update(component: TabBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let innerInset: CGFloat = 3.0
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if let nativeTabBar = self.nativeTabBar {
                if nativeTabBar.items?.count != component.items.count {
                    nativeTabBar.items = (0 ..< component.items.count).map { i in
                        return UITabBarItem(title: " ", image: nil, tag: i)
                    }
                    for (_, itemView) in self.itemViews {
                        itemView.view?.removeFromSuperview()
                    }
                    for (_, selectedItemView) in self.selectedItemViews {
                        selectedItemView.view?.removeFromSuperview()
                    }
                    if let index = component.items.firstIndex(where: { $0.id == component.selectedId }) {
                        nativeTabBar.selectedItem = nativeTabBar.items?[index]
                    }
                }
                
                let nativeSize = nativeTabBar.sizeThatFits(availableSize)
                nativeTabBar.bounds = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: nativeSize.height))
                nativeTabBar.layoutSubviews()
            }
            
            var nativeItemContainers: [Int: UIView] = [:]
            var nativeSelectedItemContainers: [Int: UIView] = [:]
            if let nativeTabBar = self.nativeTabBar {
                for subview in nativeTabBar.subviews {
                    if NSStringFromClass(type(of: subview)).contains("PlatterView") {
                        for subview in subview.subviews {
                            if NSStringFromClass(type(of: subview)).hasSuffix("SelectedContentView") {
                                for subview in subview.subviews {
                                    if NSStringFromClass(type(of: subview)).hasSuffix("TabButton") {
                                        nativeSelectedItemContainers[nativeSelectedItemContainers.count] = subview
                                    }
                                }
                            } else if NSStringFromClass(type(of: subview)).hasSuffix("ContentView") {
                                for subview in subview.subviews {
                                    if NSStringFromClass(type(of: subview)).hasSuffix("TabButton") {
                                        nativeItemContainers[nativeItemContainers.count] = subview
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            var itemSize = CGSize(width: floor((availableSize.width - innerInset * 2.0) / CGFloat(component.items.count)), height: 56.0)
            itemSize.width = min(94.0, itemSize.width)
            
            if let itemContainer = nativeItemContainers[0] {
                itemSize = itemContainer.bounds.size
            }
            
            let contentHeight = itemSize.height + innerInset * 2.0
            var contentWidth: CGFloat = innerInset
            
            if self.selectionView.image?.size.height != itemSize.height {
                self.selectionView.image = generateStretchableFilledCircleImage(radius: itemSize.height * 0.5, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.selectionView.tintColor = component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05)
            
            var validIds: [AnyHashable] = []
            var selectionFrame: CGRect?
            for index in 0 ..< component.items.count {
                let item = component.items[index]
                validIds.append(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition = transition
                
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[item.id] = itemView
                }
                
                let selectedItemView: ComponentView<Empty>
                if let current = self.selectedItemViews[item.id] {
                    selectedItemView = current
                } else {
                    selectedItemView = ComponentView()
                    self.selectedItemViews[item.id] = selectedItemView
                }
                
                let isItemSelected = component.selectedId == item.id
                
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: self.nativeTabBar == nil ? isItemSelected : false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                let _ = selectedItemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ItemComponent(
                        item: item,
                        theme: component.theme,
                        isSelected: true
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: contentWidth, y: floor((contentHeight - itemSize.height) * 0.5)), size: itemSize)
                if let itemComponentView = itemView.view as? ItemComponent.View, let selectedItemComponentView = selectedItemView.view as? ItemComponent.View {
                    if itemComponentView.superview == nil {
                        itemComponentView.isUserInteractionEnabled = false
                        selectedItemComponentView.isUserInteractionEnabled = false
                        
                        if self.nativeTabBar != nil {
                            if let itemContainer = nativeItemContainers[index] {
                                itemContainer.addSubview(itemComponentView)
                            }
                            if let itemContainer = nativeSelectedItemContainers[index] {
                                itemContainer.addSubview(selectedItemComponentView)
                            }
                        } else {
                            self.addSubview(itemComponentView)
                        }
                    }
                    if self.nativeTabBar != nil {
                        if let parentView = itemComponentView.superview {
                            let itemFrame = CGRect(origin: CGPoint(x: floor((parentView.bounds.width - itemSize.width) * 0.5), y: floor((parentView.bounds.height - itemSize.height) * 0.5)), size: itemSize)
                            itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                            itemTransition.setFrame(view: selectedItemComponentView, frame: itemFrame)
                        }
                    } else {
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                    
                    if let previousComponent, previousComponent.selectedId != item.id, isItemSelected {
                        itemComponentView.playSelectionAnimation()
                        selectedItemComponentView.playSelectionAnimation()
                    }
                }
                if isItemSelected {
                    selectionFrame = itemFrame
                }
                
                contentWidth += itemFrame.width
            }
            contentWidth += innerInset
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.view?.removeFromSuperview()
                    self.selectedItemViews[id]?.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
                self.selectedItemViews.removeValue(forKey: id)
            }
            
            if let selectionFrame, self.nativeTabBar == nil {
                var selectionViewTransition = transition
                if self.selectionView.superview == nil {
                    selectionViewTransition = selectionViewTransition.withAnimation(.none)
                    self.backgroundView.contentView.addSubview(self.selectionView)
                }
                selectionViewTransition.setFrame(view: self.selectionView, frame: selectionFrame)
            } else if self.selectionView.superview != nil {
                self.selectionView.removeFromSuperview()
            }
            
            let size = CGSize(width: min(availableSize.width, contentWidth), height: contentHeight)
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.75)), transition: transition)
            
            if let nativeTabBar = self.nativeTabBar {
                transition.setFrame(view: nativeTabBar, frame: CGRect(origin: CGPoint(x: floor((size.width - nativeTabBar.bounds.width) * 0.5), y: 0.0), size: nativeTabBar.bounds.size))
            }
            
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
    let item: TabBarComponent.Item
    let theme: PresentationTheme
    let isSelected: Bool
    
    init(item: TabBarComponent.Item, theme: PresentationTheme, isSelected: Bool) {
        self.item = item
        self.theme = theme
        self.isSelected = isSelected
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var imageIcon: ComponentView<Empty>?
        private var animationIcon: ComponentView<Empty>?
        private let title = ComponentView<Empty>()
        private var badge: ComponentView<Empty>?
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
        
        private var setImageListener: Int?
        private var setSelectedImageListener: Int?
        private var setBadgeListener: Int?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            if let component = self.component {
                if let setImageListener = self.setImageListener {
                    component.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    component.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    component.item.item.removeSetBadgeListener(setBadgeListener)
                }
            }
        }
        
        func playSelectionAnimation() {
            if let animationIconView = self.animationIcon?.view as? LottieComponent.View {
                animationIconView.playOnce()
            }
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            if previousComponent?.item.item !== component.item.item {
                if let setImageListener = self.setImageListener {
                    self.component?.item.item.removeSetImageListener(setImageListener)
                }
                if let setSelectedImageListener = self.setSelectedImageListener {
                    self.component?.item.item.removeSetSelectedImageListener(setSelectedImageListener)
                }
                if let setBadgeListener = self.setBadgeListener {
                    self.component?.item.item.removeSetBadgeListener(setBadgeListener)
                }
                self.setImageListener = component.item.item.addSetImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setSelectedImageListener = component.item.item.addSetSelectedImageListener { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
                self.setBadgeListener = UITabBarItem_addSetBadgeListener(component.item.item) { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            }
            
            self.component = component
            self.state = state
            
            if let animationName = component.item.item.animationName {
                if let imageIcon = self.imageIcon {
                    self.imageIcon = nil
                    imageIcon.view?.removeFromSuperview()
                }
                
                let animationIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.animationIcon {
                    animationIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    animationIcon = ComponentView()
                    self.animationIcon = animationIcon
                }
                
                let iconSize = animationIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: animationName
                        ),
                        color: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor,
                        placeholderColor: nil,
                        startingPosition: .end,
                        size: CGSize(width: 48.0, height: 48.0),
                        loop: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: 48.0, height: 48.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: -4.0), size: iconSize).offsetBy(dx: component.item.item.animationOffset.x, dy: component.item.item.animationOffset.y)
                if let animationIconView = animationIcon.view {
                    if animationIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.insertSubview(animationIconView, belowSubview: badgeView)
                        } else {
                            self.addSubview(animationIconView)
                        }
                    }
                    iconTransition.setFrame(view: animationIconView, frame: iconFrame)
                }
            } else {
                if let animationIcon = self.animationIcon {
                    self.animationIcon = nil
                    animationIcon.view?.removeFromSuperview()
                }
                
                let imageIcon: ComponentView<Empty>
                var iconTransition = transition
                if let current = self.imageIcon {
                    imageIcon = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    imageIcon = ComponentView()
                    self.imageIcon = imageIcon
                }
                
                let iconSize = imageIcon.update(
                    transition: iconTransition,
                    component: AnyComponent(Image(
                        image: component.isSelected ? component.item.item.selectedImage : component.item.item.image,
                        tintColor: nil,
                        contentMode: .center
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: 3.0), size: iconSize)
                if let imageIconView = imageIcon.view {
                    if imageIconView.superview == nil {
                        if let badgeView = self.badge?.view {
                            self.insertSubview(imageIconView, belowSubview: badgeView)
                        } else {
                            self.addSubview(imageIconView)
                        }
                    }
                    iconTransition.setFrame(view: imageIconView, frame: iconFrame)
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.item.item.title ?? " ", font: Font.semibold(10.0), textColor: component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: availableSize.height - 9.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if let badgeText = component.item.item.badgeValue, !badgeText.isEmpty {
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
                        text: badgeText,
                        font: Font.regular(13.0),
                        background: component.theme.rootController.tabBar.badgeBackgroundColor,
                        foreground: component.theme.rootController.tabBar.badgeTextColor,
                        insets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 1.0, right: 6.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let contentWidth: CGFloat = 25.0
                let badgeFrame = CGRect(origin: CGPoint(x: floor(availableSize.width / 2.0) + contentWidth - badgeSize.width - 5.0, y: -1.0), size: badgeSize)
                if let badgeView = badge.view {
                    if badgeView.superview == nil {
                        self.addSubview(badgeView)
                    }
                    badgeTransition.setFrame(view: badgeView, frame: badgeFrame)
                }
            } else if let badge = self.badge {
                self.badge = nil
                badge.view?.removeFromSuperview()
            }
            
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
