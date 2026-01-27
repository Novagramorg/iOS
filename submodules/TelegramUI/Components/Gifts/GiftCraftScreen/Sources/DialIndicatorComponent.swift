import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import MultilineTextComponent
import AnimatedTextComponent

final class DialIndicatorComponent: Component {
    let content: AnyComponentWithIdentity<Empty>
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let diameter: CGFloat
    let lineWidth: CGFloat
    let fontSize: CGFloat
    let percentage: Int
    let isVisible: Bool

    public init(
        content: AnyComponentWithIdentity<Empty>,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        diameter: CGFloat,
        lineWidth: CGFloat,
        fontSize: CGFloat,
        percentage: Int,
        isVisible: Bool = true
    ) {
        self.content = content
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.percentage = percentage
        self.isVisible = isVisible
    }

    public static func ==(lhs: DialIndicatorComponent, rhs: DialIndicatorComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.diameter != rhs.diameter {
            return false
        }
        if lhs.lineWidth != rhs.lineWidth {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.percentage != rhs.percentage {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let containerView = UIView()
        private let backgroundLayer = SimpleShapeLayer()
        private let foregroundLayer = SimpleShapeLayer()
        
        private var content = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        
        private var component: DialIndicatorComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                        
            self.backgroundLayer.lineCap = .round
            self.foregroundLayer.lineCap = .round
            
            self.addSubview(self.containerView)
            
            self.containerView.layer.addSublayer(self.backgroundLayer)
            self.containerView.layer.addSublayer(self.foregroundLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: DialIndicatorComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let pathSize = CGSize(width: component.diameter, height: component.diameter)
            let pathFrame = CGRect(origin: .zero, size: pathSize).insetBy(dx: component.lineWidth * 0.5, dy: component.lineWidth * 0.5)
            
            let strokeStart: CGFloat = 0.125
            let strokeEnd: CGFloat = 1.0 - strokeStart
            
            self.backgroundLayer.lineWidth = component.lineWidth
            self.backgroundLayer.strokeColor = component.backgroundColor.cgColor
            self.backgroundLayer.fillColor = UIColor.clear.cgColor
            self.backgroundLayer.path = CGPath(ellipseIn: pathFrame, transform: nil)
            self.backgroundLayer.transform = CATransform3DMakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
            self.backgroundLayer.strokeStart = strokeStart
            self.backgroundLayer.strokeEnd = strokeEnd
            self.backgroundLayer.frame = CGRect(origin: .zero, size: pathSize)
            
            self.foregroundLayer.lineWidth = component.lineWidth
            self.foregroundLayer.strokeColor = component.foregroundColor.cgColor
            self.foregroundLayer.fillColor = UIColor.clear.cgColor
            self.foregroundLayer.path = CGPath(ellipseIn: pathFrame, transform: nil)
            self.foregroundLayer.transform = CATransform3DMakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
            self.foregroundLayer.strokeStart = strokeStart
            transition.setShapeLayerStrokeEnd(layer: self.foregroundLayer, strokeEnd: strokeStart + (strokeEnd - strokeStart) * (CGFloat(component.percentage) / 100.0))
            self.foregroundLayer.frame = CGRect(origin: .zero, size: pathSize)
            
            if previousComponent?.content.id != component.content.id {
                if let contentView = self.content.view {
                    if transition.animation.isImmediate {
                        contentView.removeFromSuperview()
                    } else {
                        transition.setScale(view: contentView, scale: 0.01)
                        transition.setAlpha(view: contentView, alpha: 0.0, completion: { _ in
                            contentView.removeFromSuperview()
                        })
                    }
                }
                self.content = ComponentView()
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: CGSize(width: component.diameter - 16.0, height: component.diameter - 16.0))
            let _ = self.content.update(
                transition: .immediate,
                component: component.content.component,
                environment: {},
                containerSize: contentFrame.size
            )
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.containerView.addSubview(contentView)
                    if !transition.animation.isImmediate {
                        transition.animateScale(view: contentView, from: 0.01, to: 1.0)
                        transition.animateAlpha(view: contentView, from: 0.0, to: 1.0)
                    }
                }
                contentView.frame = contentFrame
            }
            
            let labelItems: [AnimatedTextComponent.Item] = [
                AnimatedTextComponent.Item(id: "percent", content: .number(component.percentage, minDigits: 1)),
                AnimatedTextComponent.Item(id: "suffix", content: .text("%"))
            ]
            
            let labelSize = self.label.update(
                transition: transition,
                component: AnyComponent(
                    AnimatedTextComponent(
                        font: Font.semibold(component.fontSize),
                        color: component.foregroundColor,
                        items: labelItems
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.containerView.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((pathSize.width - labelSize.width) / 2.0) + 1.0 - UIScreenPixel, y: pathSize.height - labelSize.height + 2.0 - UIScreenPixel), size: labelSize))
            }
            
            transition.setAlpha(view: self.containerView, alpha: component.isVisible ? 1.0 : 0.0)
            transition.setBlur(layer: self.containerView.layer, radius: component.isVisible ? 0.0 : 10.0)
            
            self.containerView.frame = CGRect(origin: .zero, size: pathSize)
            
            return pathSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
