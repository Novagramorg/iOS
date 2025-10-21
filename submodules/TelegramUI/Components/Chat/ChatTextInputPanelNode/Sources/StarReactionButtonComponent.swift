import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import AnimatedTextComponent

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
        private let iconView: UIImageView
        private var text: ComponentView<Empty>?
        
        private var longTapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
        
        private var component: StarReactionButtonComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
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
            
            let leftInset: CGFloat = 12.0
            let rightInset: CGFloat = 12.0
            let textSpacing: CGFloat = 2.0
            
            var size = CGSize(width: 40.0, height: 40.0)
            var textSize: CGSize?
            
            if self.iconView.image == nil {
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/ButtonStar")?.withRenderingMode(.alwaysTemplate)
            }
            
            if component.count != 0 {
                let text: ComponentView<Empty>
                var textTransition = transition
                if let current = self.text {
                    text = current
                } else {
                    textTransition = textTransition.withAnimation(.none)
                    text = ComponentView()
                    self.text = text
                }
                let textSizeValue = text.update(
                    transition: textTransition,
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.regular(17.0),
                        color: component.theme.chat.inputPanel.panelControlColor,
                        items: [AnimatedTextComponent.Item(id: AnyHashable(0), content: .number(component.count, minDigits: 1))],
                        noDelay: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                textSize = textSizeValue
                if let image = self.iconView.image {
                    size.width = leftInset + image.size.width + textSpacing + textSizeValue.width + rightInset
                }
            } else if let text = self.text {
                self.text = nil
                if let textView = text.view {
                    transition.setScale(view: textView, scale: 0.001)
                    transition.setAlpha(view: textView, alpha: 0.0, completion: { [weak textView] _ in
                        textView?.removeFromSuperview()
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
            
            self.iconView.tintColor = component.theme.chat.inputPanel.panelControlColor
            
            if let image = self.iconView.image {
                let iconFrame: CGRect
                if textSize == nil {
                    iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: backgroundFrame.size))
                } else {
                    iconFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((backgroundFrame.height - image.size.height) * 0.5)), size: image.size)
                }
                transition.setFrame(view: self.iconView, frame: iconFrame)
                
                if let textView = self.text?.view, let textSize {
                    let textFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + textSpacing, y: floor((backgroundFrame.height - textSize.height) * 0.5)), size: textSize)
                    
                    if textView.superview == nil {
                        textView.isUserInteractionEnabled = false
                        self.backgroundView.contentView.addSubview(textView)
                        textView.frame = textFrame
                        transition.animateScale(view: textView, from: 0.001, to: 1.0)
                        transition.animateAlpha(view: textView, from: 0.0, to: 1.0)
                    }
                    transition.setFrame(view: textView, frame: textFrame)
                }
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
