import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import AnimatedTextComponent
import StarsParticleEffect

final class StarReactionButtonBadgeComponent: Component {
    let theme: PresentationTheme
    let count: Int
    let isFilled: Bool
    
    init(
        theme: PresentationTheme,
        count: Int,
        isFilled: Bool
    ) {
        self.theme = theme
        self.count = count
        self.isFilled = isFilled
    }
    
    static func ==(lhs: StarReactionButtonBadgeComponent, rhs: StarReactionButtonBadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isFilled != rhs.isFilled {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let text = ComponentView<Empty>()
        
        private var component: StarReactionButtonBadgeComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StarReactionButtonBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let height: CGFloat = 15.0
            let sideInset: CGFloat = 4.0
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(10.0),
                    color: component.theme.chat.inputPanel.panelControlColor,
                    items: [AnimatedTextComponent.Item(id: AnyHashable(0), content: .text(countString(Int64(component.count))))],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let size = CGSize(width: textSize.width + sideInset * 2.0, height: height)
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            
            let backgroundTintColor: GlassBackgroundView.TintColor
            if component.isFilled {
                backgroundTintColor = .init(kind: .custom, color: UIColor(rgb: 0xFFB10D))
            } else {
                backgroundTintColor = .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7))
            }
            
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: backgroundTintColor, isInteractive: true, transition: transition)
            
            if let textView = self.text.view {
                let textFrame = textSize.centered(in: CGRect(origin: CGPoint(), size: size))
                
                if textView.superview == nil {
                    textView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
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


final class StarReactionButtonComponent: Component {
    let theme: PresentationTheme
    let count: Int
    let isFilled: Bool
    let action: (UIView) -> Void
    let longPressAction: ((UIView) -> Void)?
    
    init(
        theme: PresentationTheme,
        count: Int,
        isFilled: Bool,
        action: @escaping (UIView) -> Void,
        longPressAction: ((UIView) -> Void)?
    ) {
        self.theme = theme
        self.count = count
        self.isFilled = isFilled
        self.action = action
        self.longPressAction = longPressAction
    }
    
    static func ==(lhs: StarReactionButtonComponent, rhs: StarReactionButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isFilled != rhs.isFilled {
            return false
        }
        if (lhs.longPressAction == nil) != (rhs.longPressAction == nil) {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let backgroundEffectLayer: StarsParticleEffectLayer
        private let backgroundMaskView: UIView
        private let backgroundBadgeMask: UIImageView
        private let iconView: UIImageView
        private var badge: ComponentView<Empty>?
        
        private var longTapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
        
        private var component: StarReactionButtonComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            self.backgroundMaskView = UIView()
            self.backgroundBadgeMask = UIImageView()
            self.backgroundMaskView.addSubview(self.backgroundBadgeMask)
            
            self.backgroundEffectLayer = StarsParticleEffectLayer()
            self.backgroundView.contentView.layer.addSublayer(self.backgroundEffectLayer)
            
            //self.backgroundView.mask = self.backgroundMaskView
            
            self.backgroundMaskView.backgroundColor = .white
            if let filter = CALayer.luminanceToAlpha() {
                self.backgroundMaskView.layer.filters = [filter]
            }
            
            self.iconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.iconView)
            
            let longTapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.longTapAction(_:)))
            longTapRecognizer.tapActionAtPoint = { _ in
                return .waitForSingleTap
            }
            self.longTapRecognizer = longTapRecognizer
            self.backgroundView.contentView.addGestureRecognizer(longTapRecognizer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func longTapAction(_ recogizer: TapLongTapOrDoubleTapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            switch recogizer.state {
            case .ended:
                if let gesture = recogizer.lastRecognizedGestureAndLocation?.0 {
                    if case .tap = gesture {
                        component.action(self)
                    } else if case .longTap = gesture {
                        component.longPressAction?(self)
                    }
                }
            default:
                break
            }
        }
        
        func update(component: StarReactionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            
            if self.iconView.image == nil {
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/ButtonStar")?.withRenderingMode(.alwaysTemplate)
            }
            
            if component.count != 0 {
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
                    component: AnyComponent(StarReactionButtonBadgeComponent(
                        theme: component.theme,
                        count: component.count,
                        isFilled: component.isFilled
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                if let badgeView = badge.view {
                    var badgeFrame = CGRect(origin: CGPoint(x: min(size.width + 6.0 - badgeSize.width, floorToScreenPixels(size.width - 4.0 - badgeSize.width * 0.5)), y: -3.0), size: badgeSize)
                    if badgeSize.width > size.width * 0.8 {
                        badgeFrame.origin.x = floor((size.width - badgeSize.width) * 0.5)
                    }
                    
                    if badgeView.superview == nil {
                        badgeView.isUserInteractionEnabled = false
                        self.backgroundView.contentView.addSubview(badgeView)
                        badgeView.frame = badgeFrame
                        transition.animateScale(view: badgeView, from: 0.001, to: 1.0)
                        transition.animateAlpha(view: badgeView, from: 0.0, to: 1.0)
                    }
                    transition.setFrame(view: badgeView, frame: badgeFrame)
                }
            } else if let badge = self.badge {
                self.badge = nil
                if let badgeView = badge.view {
                    transition.setScale(view: badgeView, scale: 0.001)
                    transition.setAlpha(view: badgeView, alpha: 0.0, completion: { [weak badgeView] _ in
                        badgeView?.removeFromSuperview()
                    })
                }
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            
            let backgroundTintColor: GlassBackgroundView.TintColor
            if component.isFilled {
                backgroundTintColor = .init(kind: .custom, color: UIColor(rgb: 0xFFB10D))
            } else {
                backgroundTintColor = .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7))
            }
            
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: backgroundTintColor, isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            transition.setFrame(view: self.backgroundMaskView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            transition.setFrame(layer: self.backgroundEffectLayer, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            self.backgroundEffectLayer.update(color: UIColor(white: 1.0, alpha: 0.25), rate: 10.0, size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, transition: transition)
            
            let badgeDiameter: CGFloat = 15.0
            if self.backgroundBadgeMask.image == nil {
                self.backgroundBadgeMask.image = generateStretchableFilledCircleImage(diameter: badgeDiameter + 1.0 * 2.0, color: .black)
            }
            let badgeWidth: CGFloat = 20.0
            let badgeFrame = CGRect(origin: CGPoint(x: backgroundFrame.width - badgeWidth, y: 0.0), size: CGSize(width: badgeWidth, height: badgeDiameter))
            transition.setFrame(view: self.backgroundBadgeMask, frame: badgeFrame.insetBy(dx: -1.0, dy: -1.0))
            
            self.iconView.tintColor = component.theme.chat.inputPanel.panelControlColor
            
            if let image = self.iconView.image {
                let iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: backgroundFrame.size))
                transition.setFrame(view: self.iconView, frame: iconFrame)
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
