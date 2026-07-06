import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import BundleIconComponent
import GlassBackgroundComponent

class RichTextActionBarComponent: Component {
    final class Action: Equatable {
        let id: AnyHashable
        let icon: String
        let action: ((UIView) -> Void)?
        let isSelected: Bool
        let flipHorizontally: Bool

        init(id: AnyHashable, icon: String, action: ((UIView) -> Void)?, isSelected: Bool, flipHorizontally: Bool = false) {
            self.id = id
            self.icon = icon
            self.action = action
            self.isSelected = isSelected
            self.flipHorizontally = flipHorizontally
        }

        static func ==(lhs: Action, rhs: Action) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            if (lhs.action == nil) != (rhs.action == nil) {
                return false
            }
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            if lhs.flipHorizontally != rhs.flipHorizontally {
                return false
            }
            return true
        }
    }
    
    let theme: PresentationTheme
    let actionsId: AnyHashable
    let actions: [Action]
    
    init(
        theme: PresentationTheme,
        actionsId: AnyHashable,
        actions: [Action]
    ) {
        self.theme = theme
        self.actionsId = actionsId
        self.actions = actions
    }
    
    static func ==(lhs: RichTextActionBarComponent, rhs: RichTextActionBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.actionsId != rhs.actionsId {
            return false
        }
        if lhs.actions != rhs.actions {
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
    
    final class View: UIView {
        private let backgroundContainer: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private let scrollView: ScrollView
        
        private var itemViews: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var component: RichTextActionBarComponent?
        
        override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.backgroundContainer.contentView.addSubview(self.backgroundView)
            
            self.scrollView = ScrollView()
            self.scrollView.delaysContentTouches = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.disablesInteractiveTransitionGestureRecognizer = true
            
            self.addSubview(self.backgroundContainer)
            self.backgroundView.contentView.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: RichTextActionBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            let verticalInset: CGFloat = 4.0
            let horizontalInset: CGFloat = 4.0
            
            let itemSize = CGSize(width: 40.0, height: 36.0)
            let intrinsicContentWidth = itemSize.width * CGFloat(component.actions.count)
            let areaWidth = size.width - horizontalInset * 2.0
            let minSpacing: CGFloat = 0.0
            
            var spacing = minSpacing
            if intrinsicContentWidth + minSpacing * CGFloat(max(0, component.actions.count - 1)) <= areaWidth {
                spacing = floorToScreenPixels((areaWidth - intrinsicContentWidth) / CGFloat(max(1, component.actions.count - 1)))
            }
            
            let contentSize = CGSize(width: itemSize.width * CGFloat(component.actions.count) + spacing * CGFloat(max(0, component.actions.count - 1)), height: itemSize.height)
            
            let delayIncrement: Double = 0.02
            
            var animateIn = false
            if let previousComponent, component.actionsId != previousComponent.actionsId {
                animateIn = true
                var nextDelay: Double = 0.0
                for item in previousComponent.actions {
                    if let itemView = self.itemViews[item.id]?.view {
                        transition.setAlpha(view: itemView, alpha: 0.0, delay: nextDelay, completion: { [weak itemView] _ in
                            itemView?.removeFromSuperview()
                        })
                        transition.setScale(view: itemView, scale: 0.001, delay: nextDelay)
                    }
                    
                    nextDelay += delayIncrement
                }
                self.itemViews.removeAll()
            }
            
            var validIds: [AnyHashable] = []
            var nextAppearDelay: Double = delayIncrement * 2.0
            for (index, item) in component.actions.enumerated() {
                validIds.append(item.id)
                
                let itemView: ComponentView<Empty>
                var itemTransition: ComponentTransition = .immediate
                if let current = self.itemViews[item.id] {
                    itemView = current
                } else {
                    itemTransition = itemTransition.withAnimation(.none)
                    itemView = ComponentView()
                    self.itemViews[item.id] = itemView
                }
                
                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(ActionItemComponent(
                        theme: component.theme,
                        icon: item.icon,
                        action: item.action,
                        isSelected: item.isSelected,
                        flipHorizontally: item.flipHorizontally
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: CGFloat(index) * (itemSize.width + spacing), y: 0.0), size: itemSize)
                
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollView.addSubview(itemComponentView)
                    }
                    itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    
                    if animateIn {
                        transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0, delay: nextAppearDelay)
                        transition.animateScale(view: itemComponentView, from: 0.001, to: 1.0, delay: nextAppearDelay)
                    }
                }
                
                nextAppearDelay += delayIncrement
            }
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    itemView.view?.removeFromSuperview()
                    removeIds.append(id)
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            let scrollFrame = CGRect(origin: CGPoint(x: horizontalInset, y: verticalInset), size: CGSize(width: size.width - horizontalInset * 2.0, height: size.height - verticalInset * 2.0))
            self.scrollView.frame = scrollFrame
            self.scrollView.layer.cornerRadius = scrollFrame.height * 0.5
            self.scrollView.contentSize = contentSize
            
            self.backgroundContainer.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size))
            
            self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            
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

class ActionItemComponent: Component {
    let theme: PresentationTheme
    let icon: String
    let action: ((UIView) -> Void)?
    let isSelected: Bool
    let flipHorizontally: Bool

    init(
        theme: PresentationTheme,
        icon: String,
        action: ((UIView) -> Void)?,
        isSelected: Bool,
        flipHorizontally: Bool = false
    ) {
        self.theme = theme
        self.icon = icon
        self.action = action
        self.isSelected = isSelected
        self.flipHorizontally = flipHorizontally
    }

    static func ==(lhs: ActionItemComponent, rhs: ActionItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.flipHorizontally != rhs.flipHorizontally {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = ComponentView<Empty>()
        private var selectionBackground: ComponentView<Empty>?
        
        private var component: ActionItemComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action?(self)
            }
        }
        
        func update(component: ActionItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let foregroundColor: UIColor
            if component.isSelected {
                foregroundColor = component.theme.list.itemCheckColors.foregroundColor
            } else {
                foregroundColor = component.theme.chat.inputPanel.panelControlColor.withMultipliedAlpha(component.action != nil ? 1.0 : 0.4)
            }
            
            if component.isSelected {
                let selectionBackground: ComponentView<Empty>
                if let current = self.selectionBackground {
                    selectionBackground = current
                } else {
                    selectionBackground = ComponentView()
                    self.selectionBackground = selectionBackground
                }
                let _ = selectionBackground.update(
                    transition: transition,
                    component: AnyComponent(FilledRoundedRectangleComponent(
                        color: component.theme.list.itemCheckColors.fillColor,
                        cornerRadius: .minEdge,
                        smoothCorners: false
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let selectionBackgroundView = selectionBackground.view {
                    if selectionBackgroundView.superview == nil {
                        selectionBackgroundView.isUserInteractionEnabled = false
                        self.insertSubview(selectionBackgroundView, at: 0)
                    }
                    selectionBackgroundView.frame = CGRect(origin: CGPoint(), size: availableSize)
                }
            } else if let selectionBackground = self.selectionBackground {
                self.selectionBackground = nil
                selectionBackground.view?.removeFromSuperview()
            }
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: component.icon,
                    tintColor: foregroundColor,
                    flipHorizontally: component.flipHorizontally
                )),
                environment: {},
                containerSize: availableSize
            )
            let iconFrame = iconSize.centered(in: CGRect(origin: CGPoint(), size: availableSize))
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
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
