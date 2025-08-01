import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import HierarchyTrackingLayer
import AnimatedTextComponent

final class ProfileLevelRatingBarComponent: Component {
    final class TransitionHint {
        let animate: Bool
        
        init(animate: Bool) {
            self.animate = animate
        }
    }
    
    let theme: PresentationTheme
    let value: CGFloat
    let leftLabel: String
    let rightLabel: String
    let badgeValue: String
    let badgeTotal: String?
    let level: Int
    
    init(
        theme: PresentationTheme,
        value: CGFloat,
        leftLabel: String,
        rightLabel: String,
        badgeValue: String,
        badgeTotal: String?,
        level: Int
    ) {
        self.theme = theme
        self.value = value
        self.leftLabel = leftLabel
        self.rightLabel = rightLabel
        self.badgeValue = badgeValue
        self.badgeTotal = badgeTotal
        self.level = level
    }
    
    static func ==(lhs: ProfileLevelRatingBarComponent, rhs: ProfileLevelRatingBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.leftLabel != rhs.leftLabel {
            return false
        }
        if lhs.rightLabel != rhs.rightLabel {
            return false
        }
        if lhs.badgeValue != rhs.badgeValue {
            return false
        }
        if lhs.badgeTotal != rhs.badgeTotal {
            return false
        }
        if lhs.level != rhs.level {
            return false
        }
        return true
    }
    
    private final class AnimationState {
        let fromValue: CGFloat
        let toValue: CGFloat
        let fromBadgeSize: CGSize
        let startTime: Double
        let duration: Double
        let isWraparound: Bool
        
        init(fromValue: CGFloat, toValue: CGFloat, fromBadgeSize: CGSize, startTime: Double, duration: Double, isWraparound: Bool) {
            self.fromValue = fromValue
            self.toValue = toValue
            self.fromBadgeSize = fromBadgeSize
            self.startTime = startTime
            self.duration = duration
            self.isWraparound = isWraparound
        }
        
        func timeFraction(at timestamp: Double) -> CGFloat {
            var fraction = CGFloat((timestamp - self.startTime) / self.duration)
            fraction = max(0.0, min(1.0, fraction))
            return fraction
        }
        
        func fraction(at timestamp: Double) -> CGFloat {
            return listViewAnimationCurveSystem(self.timeFraction(at: timestamp))
        }
        
        func value(at timestamp: Double) -> CGFloat {
            let fraction = self.fraction(at: timestamp)
            return (1.0 - fraction) * self.fromValue + fraction * self.toValue
        }
        
        func wrapAroundValue(at timestamp: Double, topValue: CGFloat) -> CGFloat {
            let fraction = self.fraction(at: timestamp)
            if fraction <= 0.5 {
                let halfFraction = fraction / 0.5
                return (1.0 - halfFraction) * self.fromValue + halfFraction * topValue
            } else {
                let halfFraction = (fraction - 0.5) / 0.5
                return halfFraction * self.toValue
            }
        }
        
        func badgeSize(at timestamp: Double, endValue: CGSize) -> CGSize {
            let fraction = self.fraction(at: timestamp)
            return CGSize(
                width: (1.0 - fraction) * self.fromBadgeSize.width + fraction * endValue.width,
                height: endValue.height
            )
        }
    }
    
    final class View: UIView {
        private let barBackground: UIImageView
        private let backgroundClippingContainer: UIView
        private let foregroundClippingContainer: UIView
        private let barForeground: UIImageView
        
        private let backgroundLeftLabel = ComponentView<Empty>()
        private let backgroundRightLabel = ComponentView<Empty>()
        private let foregroundLeftLabel = ComponentView<Empty>()
        private let foregroundRightLabel = ComponentView<Empty>()
        
        private let badge = ComponentView<Empty>()
        
        private var component: ProfileLevelRatingBarComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var hierarchyTracker: HierarchyTrackingLayer?
        private var animationLink: SharedDisplayLinkDriver.Link?
        
        private var animationState: AnimationState?
        
        override init(frame: CGRect) {
            self.barBackground = UIImageView()
            self.backgroundClippingContainer = UIView()
            self.backgroundClippingContainer.clipsToBounds = true
            self.foregroundClippingContainer = UIView()
            self.foregroundClippingContainer.clipsToBounds = true
            self.barForeground = UIImageView()
            
            super.init(frame: frame)
            
            let hierarchyTracker = HierarchyTrackingLayer()
            self.hierarchyTracker = hierarchyTracker
            self.layer.addSublayer(hierarchyTracker)
            
            self.hierarchyTracker?.isInHierarchyUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                self.updateAnimations()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        private func updateAnimations() {
            if let hierarchyTracker = self.hierarchyTracker, hierarchyTracker.isInHierarchy {
                if self.animationState != nil {
                    if self.animationLink == nil {
                        self.animationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.updateAnimations()
                        })
                    }
                } else {
                    self.animationLink?.invalidate()
                    self.animationLink = nil
                    self.animationState = nil
                }
            } else {
                self.animationLink?.invalidate()
                self.animationLink = nil
                self.animationState = nil
            }
            
            if let animationState = self.animationState {
                if animationState.timeFraction(at: CACurrentMediaTime()) >= 1.0 {
                    self.animationState = nil
                    self.updateAnimations()
                }
            }
            
            if self.animationState != nil && !self.isUpdating {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }
        
        func update(component: ProfileLevelRatingBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let barHeight: CGFloat = 30.0
            
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var labelsTransition = transition
            if let previousComponent = self.component, let hint = transition.userData(TransitionHint.self), hint.animate {
                labelsTransition = .spring(duration: 0.4)
                
                let fromValue: CGFloat
                if let animationState = self.animationState {
                    fromValue = animationState.value(at: CACurrentMediaTime())
                } else {
                    fromValue = previousComponent.value
                }
                let fromBadgeSize: CGSize
                if let badgeView = self.badge.view as? ProfileLevelRatingBarBadge.View {
                    fromBadgeSize = badgeView.bounds.size
                } else {
                    fromBadgeSize = CGSize()
                }
                self.animationState = AnimationState(
                    fromValue: fromValue,
                    toValue: component.value,
                    fromBadgeSize: fromBadgeSize,
                    startTime: CACurrentMediaTime(),
                    duration: 0.4 * UIView.animationDurationFactor(),
                    isWraparound: false//previousComponent.level < component.level
                )
                self.updateAnimations()
            }
            
            self.component = component
            self.state = state
            
            if self.barBackground.image == nil {
                self.barBackground.image = generateStretchableFilledCircleImage(diameter: 12.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                self.barForeground.image = self.barBackground.image
            }
            
            self.barBackground.tintColor = component.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5)
            self.barForeground.tintColor = component.theme.list.itemCheckColors.fillColor
            
            if self.barBackground.superview == nil {
                self.addSubview(self.barBackground)
                self.addSubview(self.backgroundClippingContainer)
                
                self.addSubview(self.foregroundClippingContainer)
                self.foregroundClippingContainer.addSubview(self.barForeground)
            }
            
            let progressValue: CGFloat
            if let animationState = self.animationState {
                progressValue = animationState.value(at: CACurrentMediaTime())
            } else {
                progressValue = component.value
            }
            
            let barBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - barHeight), size: CGSize(width: availableSize.width, height: barHeight))
            transition.setFrame(view: self.barBackground, frame: barBackgroundFrame)
            
            let barForegroundFrame = CGRect(origin: barBackgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progressValue * barBackgroundFrame.width), height: barBackgroundFrame.height))
            
            var barApparentForegroundFrame = barForegroundFrame
            if let animationState = self.animationState, animationState.isWraparound {
                let progressValue = animationState.wrapAroundValue(at: CACurrentMediaTime(), topValue: 1.0)
                barApparentForegroundFrame = CGRect(origin: barBackgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progressValue * barBackgroundFrame.width), height: barBackgroundFrame.height))
            }
            transition.setFrame(view: self.foregroundClippingContainer, frame: barApparentForegroundFrame)
            
            let backgroundClippingFrame = CGRect(origin: CGPoint(x: barBackgroundFrame.minX + barApparentForegroundFrame.width, y: barBackgroundFrame.minY), size: CGSize(width: barBackgroundFrame.width - barApparentForegroundFrame.width, height: barBackgroundFrame.height))
            transition.setPosition(view: self.backgroundClippingContainer, position: backgroundClippingFrame.center)
            transition.setBounds(view: self.backgroundClippingContainer, bounds: CGRect(origin: CGPoint(x: backgroundClippingFrame.minX - barBackgroundFrame.minX, y: 0.0), size: backgroundClippingFrame.size))
            
            transition.setFrame(view: self.barForeground, frame: CGRect(origin: CGPoint(), size: barBackgroundFrame.size))
            
            let labelFont = Font.semibold(14.0)
            
            let leftLabelSize = self.backgroundLeftLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: labelFont,
                    color: component.theme.list.itemPrimaryTextColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.leftLabel)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let _ = self.foregroundLeftLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: labelFont,
                    color: component.theme.list.itemCheckColors.foregroundColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.leftLabel)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let rightLabelSize = self.backgroundRightLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: labelFont,
                    color: component.theme.list.itemPrimaryTextColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.rightLabel)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let _ =  self.foregroundRightLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: labelFont,
                    color: component.theme.list.itemCheckColors.foregroundColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.rightLabel)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            
            let leftLabelFrame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((barBackgroundFrame.height - leftLabelSize.height) * 0.5)), size: leftLabelSize)
            let rightLabelFrame = CGRect(origin: CGPoint(x: barBackgroundFrame.width - 12.0 - rightLabelSize.width, y: floorToScreenPixels((barBackgroundFrame.height - rightLabelSize.height) * 0.5)), size: rightLabelSize)
            
            if let backgroundLeftLabelView = self.backgroundLeftLabel.view {
                if backgroundLeftLabelView.superview == nil {
                    backgroundLeftLabelView.layer.anchorPoint = CGPoint()
                    self.backgroundClippingContainer.addSubview(backgroundLeftLabelView)
                }
                transition.setPosition(view: backgroundLeftLabelView, position: leftLabelFrame.origin)
                backgroundLeftLabelView.bounds = CGRect(origin: CGPoint(), size: leftLabelFrame.size)
            }
            if let foregroundLeftLabelView = self.foregroundLeftLabel.view {
                if foregroundLeftLabelView.superview == nil {
                    foregroundLeftLabelView.layer.anchorPoint = CGPoint()
                    self.foregroundClippingContainer.addSubview(foregroundLeftLabelView)
                }
                transition.setPosition(view: foregroundLeftLabelView, position: leftLabelFrame.origin)
                foregroundLeftLabelView.bounds = CGRect(origin: CGPoint(), size: leftLabelFrame.size)
            }
            if let backgroundRightLabelView = self.backgroundRightLabel.view {
                if backgroundRightLabelView.superview == nil {
                    backgroundRightLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.backgroundClippingContainer.addSubview(backgroundRightLabelView)
                }
                transition.setPosition(view: backgroundRightLabelView, position: CGPoint(x: rightLabelFrame.maxX, y: rightLabelFrame.minY))
                backgroundRightLabelView.bounds = CGRect(origin: CGPoint(), size: rightLabelFrame.size)
            }
            if let foregroundRightLabelView = self.foregroundRightLabel.view {
                if foregroundRightLabelView.superview == nil {
                    foregroundRightLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.foregroundClippingContainer.addSubview(foregroundRightLabelView)
                }
                transition.setPosition(view: foregroundRightLabelView, position: CGPoint(x: rightLabelFrame.maxX, y: rightLabelFrame.minY))
                foregroundRightLabelView.bounds = CGRect(origin: CGPoint(), size: rightLabelFrame.size)
            }
            
            let badgeSize = self.badge.update(
                transition: transition.withUserData(ProfileLevelRatingBarBadge.TransitionHint(animateText: !labelsTransition.animation.isImmediate)),
                component: AnyComponent(ProfileLevelRatingBarBadge(
                    theme: component.theme,
                    title: "\(component.badgeValue)",
                    suffix: component.badgeTotal
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )
            
            if let badgeView = self.badge.view as? ProfileLevelRatingBarBadge.View {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                
                let apparentBadgeSize: CGSize
                if let animationState = self.animationState {
                    apparentBadgeSize = animationState.badgeSize(at: CACurrentMediaTime(), endValue: badgeSize)
                } else {
                    apparentBadgeSize = badgeSize
                }
                
                var badgeFrame = CGRect(origin: CGPoint(x: barBackgroundFrame.minX + barForegroundFrame.width - apparentBadgeSize.width * 0.5, y: barBackgroundFrame.minY - 18.0 - badgeSize.height), size: apparentBadgeSize)
                
                let badgeSideInset: CGFloat = 0.0
                
                let badgeOverflowWidth: CGFloat
                if badgeFrame.minX < badgeSideInset {
                    badgeOverflowWidth = badgeSideInset - badgeFrame.minX
                } else if badgeFrame.minX + badgeFrame.width > availableSize.width - badgeSideInset {
                    badgeOverflowWidth = availableSize.width - badgeSideInset - badgeFrame.width - badgeFrame.minX
                } else {
                    badgeOverflowWidth = 0.0
                }
                
                badgeFrame.origin.x += badgeOverflowWidth
                badgeView.frame = badgeFrame
                
                badgeView.adjustTail(size: apparentBadgeSize, overflowWidth: -badgeOverflowWidth, transition: transition)
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
