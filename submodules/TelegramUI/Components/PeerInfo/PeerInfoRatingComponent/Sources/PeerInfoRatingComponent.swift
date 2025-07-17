import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TextLoadingEffect
import ComponentDisplayAdapters
import TooltipUI
import AccountContext
import UIKitRuntimeUtils

public final class PeerInfoRatingComponent: Component {
    let context: AccountContext
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let tooltipBackgroundColor: UIColor
    let isExpanded: Bool
    let compactLabel: String
    let fraction: CGFloat
    let label: String
    let nextLabel: String
    let tooltipLabel: String
    let action: () -> Void
    
    public init(
        context: AccountContext,
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        tooltipBackgroundColor: UIColor,
        isExpanded: Bool,
        compactLabel: String,
        fraction: CGFloat,
        label: String,
        nextLabel: String,
        tooltipLabel: String,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.tooltipBackgroundColor = tooltipBackgroundColor
        self.isExpanded = isExpanded
        self.compactLabel = compactLabel
        self.fraction = fraction
        self.label = label
        self.nextLabel = nextLabel
        self.tooltipLabel = tooltipLabel
        self.action = action
    }
    
    public static func ==(lhs: PeerInfoRatingComponent, rhs: PeerInfoRatingComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.tooltipBackgroundColor != rhs.tooltipBackgroundColor {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.compactLabel != rhs.compactLabel {
            return false
        }
        if lhs.fraction != rhs.fraction {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.nextLabel != rhs.nextLabel {
            return false
        }
        if lhs.tooltipLabel != rhs.tooltipLabel {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: UIImageView
        private let foregroundView: UIImageView
        private let foregroundMaskView: UIView
        private let foregroundClippedView: UIView
        private let foregroundClippedMaskView: UIView
        private let foregroundClippedShapeView: UIImageView
        private let compactLabel = ComponentView<Empty>()
        private let expandedLabel = ComponentView<Empty>()
        private let expandedClippedLabel = ComponentView<Empty>()
        private let nextLabel = ComponentView<Empty>()
        
        private var shimmerEffectView: TextLoadingEffectView?
        
        private var component: PeerInfoRatingComponent?
        
        private var tooltipController: TooltipScreen?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIImageView()
            
            self.foregroundView = UIImageView()
            self.foregroundMaskView = UIView()
            self.foregroundMaskView.backgroundColor = .white
            self.foregroundView.mask = self.foregroundMaskView
            if let filter = CALayer.luminanceToAlpha() {
                self.foregroundMaskView.layer.filters = [filter]
            }
            
            self.foregroundClippedView = UIView()
            self.foregroundClippedMaskView = UIView()
            self.foregroundClippedMaskView.backgroundColor = .black
            self.foregroundClippedView.mask = self.foregroundClippedMaskView
            if let filter = CALayer.luminanceToAlpha() {
                self.foregroundClippedMaskView.layer.filters = [filter]
            }
            
            self.foregroundClippedShapeView = UIImageView()
            self.foregroundClippedMaskView.addSubview(self.foregroundClippedShapeView)
            
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.foregroundClippedView)
            self.addSubview(self.foregroundView)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.component?.action()
            }
        }
        
        func update(component: PeerInfoRatingComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let previousBackgroundFrame = self.backgroundView.frame
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let baseHeight: CGFloat = 20.0
            let innerInset: CGFloat = 2.0
            
            let expandedSize = CGSize(width: 174.0, height: baseHeight)
            let collapsedSize = CGSize(width: baseHeight, height: baseHeight)
            
            if self.backgroundView.image == nil {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: baseHeight, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            if self.foregroundView.image == nil {
                self.foregroundView.image = generateStretchableFilledCircleImage(diameter: baseHeight - innerInset * 2.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            if self.foregroundClippedShapeView.image == nil {
                self.foregroundClippedShapeView.image = generateStretchableFilledCircleImage(diameter: baseHeight - innerInset * 2.0, color: .black)
            }
            
            self.backgroundView.tintColor = component.backgroundColor
            self.foregroundView.tintColor = component.foregroundColor
            
            let size = component.isExpanded ? expandedSize : collapsedSize
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            let foregroundFrame: CGRect
            if component.isExpanded {
                let foregroundWidth = floorToScreenPixels(backgroundFrame.insetBy(dx: innerInset, dy: innerInset).width * component.fraction)
                foregroundFrame = CGRect(origin: CGPoint(x: innerInset, y: innerInset), size: CGSize(width: foregroundWidth, height: backgroundFrame.height - innerInset * 2.0))
            } else {
                foregroundFrame = backgroundFrame.insetBy(dx: innerInset, dy: innerInset)
            }
            
            transition.setFrame(view: self.foregroundView, frame: foregroundFrame)
            transition.setFrame(view: self.foregroundMaskView, frame: CGRect(origin: CGPoint(), size: foregroundFrame.size))
            
            transition.setFrame(view: self.foregroundClippedView, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.foregroundClippedMaskView, frame: CGRect(origin: CGPoint(), size: size))
            self.foregroundClippedView.backgroundColor = component.foregroundColor
            transition.setFrame(view: self.foregroundClippedShapeView, frame: foregroundFrame)
            
            let compactLabelSize = self.compactLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.compactLabel, font: Font.medium(11.0), textColor: .black))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let compactLabelView = self.compactLabel.view {
                if compactLabelView.superview == nil {
                    self.foregroundMaskView.addSubview(compactLabelView)
                }
                compactLabelView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((baseHeight - innerInset * 2.0 - compactLabelSize.width) * 0.5), y: floorToScreenPixels((baseHeight - innerInset * 2.0 - compactLabelSize.height) * 0.5) + UIScreenPixel), size: compactLabelSize)
                alphaTransition.setAlpha(view: compactLabelView, alpha: component.isExpanded ? 0.0 : 1.0)
            }
            
            let expandedLabelSize = self.expandedLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.medium(11.0), textColor: .black))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let expandedLabelView = self.expandedLabel.view {
                if expandedLabelView.superview == nil {
                    self.foregroundMaskView.addSubview(expandedLabelView)
                }
                expandedLabelView.frame = CGRect(origin: CGPoint(x: 4.0, y: floorToScreenPixels((baseHeight - innerInset * 2.0 - expandedLabelSize.height) * 0.5) + UIScreenPixel), size: expandedLabelSize)
                alphaTransition.setAlpha(view: expandedLabelView, alpha: component.isExpanded ? 1.0 : 0.0)
            }
            
            let expandedClippedLabelSize = self.expandedClippedLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.medium(11.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let expandedClippedLabelView = self.expandedClippedLabel.view {
                if expandedClippedLabelView.superview == nil {
                    self.foregroundClippedMaskView.insertSubview(expandedClippedLabelView, belowSubview: self.foregroundClippedShapeView)
                }
                expandedClippedLabelView.frame = CGRect(origin: CGPoint(x: innerInset + 4.0, y: innerInset + floorToScreenPixels((baseHeight - innerInset * 2.0 - expandedClippedLabelSize.height) * 0.5) + UIScreenPixel), size: expandedClippedLabelSize)
                alphaTransition.setAlpha(view: expandedClippedLabelView, alpha: component.isExpanded ? 1.0 : 0.0)
            }
            
            let nextLabelSize = self.nextLabel.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.nextLabel, font: Font.medium(11.0), textColor: component.foregroundColor.withMultipliedAlpha(0.5)))
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let nextLabelView = self.nextLabel.view {
                if nextLabelView.superview == nil {
                    self.insertSubview(nextLabelView, belowSubview: self.foregroundView)
                }
                let nextLabelFrame = CGRect(origin: CGPoint(x: size.width - nextLabelSize.width - 4.0 - innerInset, y: floorToScreenPixels((baseHeight - nextLabelSize.height) * 0.5) + UIScreenPixel), size: nextLabelSize)
                transition.setPosition(view: nextLabelView, position: nextLabelFrame.center)
                nextLabelView.bounds = CGRect(origin: CGPoint(), size: nextLabelFrame.size)
                alphaTransition.setAlpha(view: nextLabelView, alpha: component.isExpanded ? 1.0 : 0.0)
            }
            
            if component.isExpanded {
                var shimmerEffectTransition = transition
                let shimmerEffectView: TextLoadingEffectView
                if let current = self.shimmerEffectView {
                    shimmerEffectView = current
                } else {
                    shimmerEffectTransition = .immediate
                    shimmerEffectView = TextLoadingEffectView(frame: CGRect())
                    self.shimmerEffectView = shimmerEffectView
                    self.addSubview(shimmerEffectView)
                    shimmerEffectView.frame = previousBackgroundFrame
                    shimmerEffectView.alpha = 0.0
                }
                transition.setFrame(view: shimmerEffectView, frame: backgroundFrame)
                alphaTransition.setAlpha(view: shimmerEffectView, alpha: 1.0)
                
                shimmerEffectView.update(color: .clear, borderColor: component.foregroundColor, rect: CGRect(origin: CGPoint(), size: backgroundFrame.size), path: UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: backgroundFrame.size), cornerRadius: backgroundFrame.height * 0.5).cgPath, transition: shimmerEffectTransition.containedViewLayoutTransition)
            } else if let shimmerEffectView = self.shimmerEffectView {
                self.shimmerEffectView = nil
                
                transition.setFrame(view: shimmerEffectView, frame: backgroundFrame)
                
                shimmerEffectView.update(color: .clear, borderColor: component.foregroundColor, rect: CGRect(origin: CGPoint(), size: backgroundFrame.size), path: UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: backgroundFrame.size), cornerRadius: backgroundFrame.height * 0.5).cgPath, transition: transition.containedViewLayoutTransition)
                
                alphaTransition.setAlpha(view: shimmerEffectView, alpha: 0.0, completion: { [weak shimmerEffectView] _ in
                    shimmerEffectView?.removeFromSuperview()
                })
            }
            
            let tooltipController: TooltipScreen
            if let current = self.tooltipController {
                tooltipController = current
            } else {
                tooltipController = TooltipScreen(
                    context: component.context,
                    account: component.context.account,
                    sharedContext: component.context.sharedContext,
                    text: .attributedString(text: NSAttributedString(string: component.tooltipLabel, font: Font.semibold(11.0), textColor: .white)),
                    style: .customBlur(component.tooltipBackgroundColor, -4.0),
                    arrowStyle: .small,
                    location: .point(CGRect(origin: CGPoint(x: 100.0, y: 100.0), size: CGSize()), .bottom),
                    displayDuration: .infinite,
                    isShimmering: true,
                    cornerRadius: 10.0,
                    shouldDismissOnTouch: { _, _ in
                        return .ignore
                    }
                )
                self.tooltipController = tooltipController
                
                tooltipController.containerLayoutUpdated(ContainerViewLayout(
                    size: CGSize(width: 200.0, height: 200.0),
                    metrics: LayoutMetrics(),
                    deviceMetrics: DeviceMetrics.iPhoneXSMax,
                    intrinsicInsets: UIEdgeInsets(),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                ), transition: .immediate)
                
                self.layer.addSublayer(tooltipController.view.layer)
                tooltipController.viewWillAppear(false)
                tooltipController.viewDidAppear(false)
                tooltipController.setIgnoreAppearanceMethodInvocations(true)
                tooltipController.view.isUserInteractionEnabled = false
            }
            
            transition.setFrame(view: tooltipController.view, frame: CGRect(origin: CGPoint(), size: CGSize(width: 200.0, height: 200.0)).offsetBy(dx: -200.0 * 0.5 + foregroundFrame.width - 7.0, dy: -200.0 * 0.5))
            alphaTransition.setAlpha(view: tooltipController.view, alpha: component.isExpanded ? 1.0 : 0.0)
            
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
