import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import RoundedRectWithTailPath
import AnimatedTextComponent
import MultilineTextComponent
import LottieComponent

final class ProfileLevelRatingBarBadge: Component {
    final class TransitionHint {
        let animateText: Bool
        
        init(animateText: Bool) {
            self.animateText = animateText
        }
    }
    
    let theme: PresentationTheme
    let title: String
    let suffix: String?
    
    init(
        theme: PresentationTheme,
        title: String,
        suffix: String?
    ) {
        self.theme = theme
        self.title = title
        self.suffix = suffix
    }
    
    static func ==(lhs: ProfileLevelRatingBarBadge, rhs: ProfileLevelRatingBarBadge) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.suffix != rhs.suffix {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeLayer = SimpleShapeLayer()
        private let badgeShapeAnimation = ComponentView<Empty>()
        
        private let badgeForeground: SimpleLayer
        let badgeIcon: UIImageView
        private let badgeLabel = ComponentView<Empty>()
        private let suffixLabel = ComponentView<Empty>()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private var component: ProfileLevelRatingBarBadge?
        private var isUpdating: Bool = false
        
        private var previousAvailableSize: CGSize?
        
        override init(frame: CGRect) {
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            self.badgeView.layer.anchorPoint = CGPoint()
            
            self.badgeShapeLayer.fillColor = UIColor.white.cgColor
            self.badgeShapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.layer.addSublayer(self.badgeShapeLayer)
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
            self.badgeForeground.anchorPoint = CGPoint()
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
            
            super.init(frame: frame)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            
            self.isUserInteractionEnabled = false
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.badgeView.frame.contains(point) {
                return self
            } else {
                return nil
            }
        }
                
        func update(component: ProfileLevelRatingBarBadge, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.badgeIcon.image = UIImage(bundleImageName: "Peer Info/ProfileLevelProgressIcon")?.withRenderingMode(.alwaysTemplate)
            }
             
            self.component = component
            self.badgeIcon.tintColor = component.theme.list.itemCheckColors.foregroundColor
            
            var labelsTransition = transition
            if let hint = transition.userData(TransitionHint.self), hint.animateText {
                labelsTransition = .spring(duration: 0.4)
            }
            
            let badgeLabelSize = self.badgeLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []),
                    color: component.theme.list.itemCheckColors.foregroundColor,
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.title)
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            
            let badgeSuffixSpacing: CGFloat = 0.0
            
            let badgeSuffixSize = self.suffixLabel.update(
                transition: labelsTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(22.0),
                    color: component.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.6),
                    items: [AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        content: .text(component.suffix ?? "")
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            
            var badgeWidth: CGFloat = badgeLabelSize.width + 3.0 + 60.0
            if component.suffix != nil {
                badgeWidth += badgeSuffixSize.width + badgeSuffixSpacing
            }
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeShapeLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 600.0, height: badgeFullSize.height + 10.0))
    
            self.badgeIcon.frame = CGRect(x: 13.0, y: 8.0, width: 30.0, height: 30.0)
            
            self.badgeView.alpha = 1.0
            
            let size = badgeSize
            
            var badgeContentWidth: CGFloat = badgeLabelSize.width
            if component.suffix != nil {
                badgeContentWidth += badgeSuffixSpacing + badgeSuffixSize.width
            }
            
            let badgeLabelFrame = CGRect(origin: CGPoint(x: 15.0 + floorToScreenPixels((badgeFullSize.width - badgeContentWidth) / 2.0), y: 9.0), size: badgeLabelSize)
            if let badgeLabelView = self.badgeLabel.view {
                if badgeLabelView.superview == nil {
                    self.badgeView.addSubview(badgeLabelView)
                }
                labelsTransition.setFrame(view: badgeLabelView, frame: badgeLabelFrame)
            }
            if let suffixLabelView = self.suffixLabel.view {
                if suffixLabelView.superview == nil {
                    suffixLabelView.layer.anchorPoint = CGPoint()
                    self.badgeView.addSubview(suffixLabelView)
                }
                let badgeSuffixFrame = CGRect(origin: CGPoint(x: badgeLabelFrame.maxX + badgeSuffixSpacing, y: badgeLabelFrame.maxY - badgeSuffixSize.height), size: badgeSuffixSize)
                labelsTransition.setPosition(view: suffixLabelView, position: badgeSuffixFrame.origin)
                suffixLabelView.bounds = CGRect(origin: CGPoint(), size: badgeSuffixFrame.size)
            }
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
                
                let activeColors: [UIColor] = [
                    component.theme.list.itemCheckColors.fillColor,
                    component.theme.list.itemCheckColors.fillColor
                ]
                
                var locations: [CGFloat] = []
                let delta = 1.0 / CGFloat(activeColors.count - 1)
                for i in 0 ..< activeColors.count {
                    locations.append(delta * CGFloat(i))
                }
                
                let gradient = generateGradientImage(size: CGSize(width: 200.0, height: 60.0), colors: activeColors, locations: locations, direction: .horizontal)
                self.badgeForeground.contentsGravity = .resizeAspectFill
                self.badgeForeground.contents = gradient?.cgImage
                
                self.setupGradientAnimations()
            }
            
            return size
        }
        
        func adjustTail(size: CGSize, overflowWidth: CGFloat, transition: ComponentTransition) {
            guard let component else {
                return
            }
            let _ = component
            
            var tailPosition = size.width * 0.5
            tailPosition += overflowWidth
            tailPosition = max(36.0, min(size.width - 36.0, tailPosition))
            
            let tailPositionFraction = tailPosition / size.width
            transition.setShapeLayerPath(layer: self.badgeShapeLayer, path: generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPositionFraction, transformTail: false).cgPath)
            
            let badgeShapeSize = CGSize(width: 128, height: 128)
            let _ = self.badgeShapeAnimation.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "badge_with_tail"),
                    color: .red,//component.theme.list.itemCheckColors.fillColor,
                    placeholderColor: nil,
                    startingPosition: .begin,
                    size: badgeShapeSize,
                    renderingScale: nil,
                    loop: false,
                    playOnce: nil
                )),
                environment: {},
                containerSize: badgeShapeSize
            )
            if let badgeShapeAnimationView = self.badgeShapeAnimation.view as? LottieComponent.View, !"".isEmpty {
                if badgeShapeAnimationView.superview == nil {
                    badgeShapeAnimationView.layer.anchorPoint = CGPoint()
                    self.addSubview(badgeShapeAnimationView)
                }
                
                let transition: ComponentTransition = .immediate
                
                let shapeFrame = CGRect(origin: CGPoint(x: 0.0, y: -10.0), size: badgeShapeSize)
                badgeShapeAnimationView.center = shapeFrame.origin
                badgeShapeAnimationView.bounds = CGRect(origin: CGPoint(), size: shapeFrame.size)
                
                let scaleFactor: CGFloat = 144.0 / (946.0 / 4.0)
                transition.setScale(view: badgeShapeAnimationView, scale: scaleFactor)
                
                let badgeShapeWidth = floor(shapeFrame.width * scaleFactor)
                let badgeShapeOffset = -overflowWidth / badgeShapeWidth
                let _ = badgeShapeOffset
                
                //badgeShapeAnimationView.setFrameIndex(index: 0)
            }
            
            //let transition: ContainedViewLayoutTransition = .immediate
            //transition.updateAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: tailPositionFraction, y: 1.0))
        }
        
        func updateBadgeAngle(angle: CGFloat) {
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: self.badgeView, angle: angle)
        }
        
        private func setupGradientAnimations() {
            guard let _ = self.component else {
                return
            }
            if let _ = self.badgeForeground.animation(forKey: "movement") {
            } else {
                CATransaction.begin()
                
                let badgePreviousValue = self.badgeForeground.position.x
                let badgeNewValue: CGFloat
                if self.badgeForeground.position.x == -300.0 {
                    badgeNewValue = 0.0
                } else {
                    badgeNewValue = -300.0
                }
                self.badgeForeground.position = CGPoint(x: badgeNewValue, y: 0.0)
                
                let badgeAnimation = CABasicAnimation(keyPath: "position.x")
                badgeAnimation.duration = 4.5
                badgeAnimation.fromValue = badgePreviousValue
                badgeAnimation.toValue = badgeNewValue
                badgeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                CATransaction.setCompletionBlock { [weak self] in
                    self?.setupGradientAnimations()
                }
                self.badgeForeground.add(badgeAnimation, forKey: "movement")
                
                CATransaction.commit()
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
