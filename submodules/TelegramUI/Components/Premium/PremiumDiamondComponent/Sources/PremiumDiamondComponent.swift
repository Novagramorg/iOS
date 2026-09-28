import UIKit
import Display
import ComponentFlow
import Metal
import MetalEngine
import SwiftSignalKit
import TelegramPresentationData

public final class InteractiveDiamondComponent: Component {
    public struct RefractionSource: Equatable {
        let texture: MTLTexture
        let uv: SIMD4<Float>
        let rect: CGRect

        public init(texture: MTLTexture, uv: SIMD4<Float>, rect: CGRect) {
            self.texture = texture
            self.uv = uv
            self.rect = rect
        }

        public static func ==(lhs: RefractionSource, rhs: RefractionSource) -> Bool {
            return lhs.texture === rhs.texture && lhs.uv == rhs.uv && lhs.rect == rhs.rect
        }
    }

    private let size: CGSize
    private let diamondWidth: CGFloat
    private let isVisible: Bool
    private let theme: PresentationTheme

    public init(size: CGSize, diamondWidth: CGFloat, isVisible: Bool, theme: PresentationTheme) {
        self.size = size
        self.diamondWidth = diamondWidth
        self.isVisible = isVisible
        self.theme = theme
    }

    public static func ==(lhs: InteractiveDiamondComponent, rhs: InteractiveDiamondComponent) -> Bool {
        return lhs.size == rhs.size && lhs.diamondWidth == rhs.diamondWidth
            && lhs.isVisible == rhs.isVisible && lhs.theme === rhs.theme
    }

    public final class View: UIView {
        private struct Expansion {
            let start: CFTimeInterval
            let from: CGFloat
            let holding: Bool
        }

        private let diamondLayer = InteractiveDiamondLayer()
        public let pressGesture = UILongPressGestureRecognizer()
        private var isHolding = false
        public private(set) var isExpanded = false
        public var onExpansionChanged: ((Bool) -> Void)?
        private var restingSize = CGSize.zero
        private var expansion: Expansion?
        private var grip: CGFloat = 0.0
        private var dragPosition: CGPoint?
        private var dragTime: CFTimeInterval = 0.0
        private var dragVelocity = CGPoint.zero

        public override var isUserInteractionEnabled: Bool {
            didSet {
                if !self.isUserInteractionEnabled { self.cancelInteraction() }
            }
        }

        public var isRenderingEnabled: Bool {
            get { return self.diamondLayer.isRenderingEnabled }
            set {
                if !newValue { self.cancelInteraction() }
                self.diamondLayer.isRenderingEnabled = newValue
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.accessibilityElementsHidden = true
            self.diamondLayer.isRenderingEnabled = false
            var style = DiamondStyle()
            style.animationMode = .continuous
            style.rotationSpeed = 2 * .pi / 26
            style.swayScale = 1
            style.backgroundStars = false
            style.mainSparkleOnRotation = true
            style.releaseTilt = 2.6
            self.diamondLayer.update(style: style)
            self.layer.addSublayer(self.diamondLayer)
            self.diamondLayer.onHold = { [weak self] holding in
                self?.setHolding(holding)
            }
            self.diamondLayer.onPoseUpdated = { [weak self] _ in
                self?.updateExpansion(at: CACurrentMediaTime())
            }
            self.pressGesture.minimumPressDuration = 0.0
            self.pressGesture.allowableMovement = .greatestFiniteMagnitude
            self.pressGesture.addTarget(self, action: #selector(self.handlePress(_:)))
            self.addGestureRecognizer(self.pressGesture)
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
            NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            self.reduceMotionChanged()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func reduceMotionChanged() {
            self.diamondLayer.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
            if UIAccessibility.isReduceMotionEnabled {
                self.expansion = nil
                self.grip = self.isHolding ? 1.0 : 0.0
                self.applyExpansion()
            }
        }

        @objc private func applicationWillResignActive() {
            self.cancelInteraction()
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil { self.cancelInteraction() }
        }

        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return CGRect(x: self.bounds.midX - 32.0, y: self.bounds.midY - 32.0, width: 64.0, height: 64.0).contains(point)
        }

        @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
            let now = CACurrentMediaTime()
            let position = gesture.location(in: self)
            switch gesture.state {
            case .began:
                self.dragPosition = position
                self.dragTime = now
                self.dragVelocity = .zero
                self.diamondLayer.updateDrag(state: .began)
            case .changed, .ended:
                guard let previous = self.dragPosition else { return }
                let translation = CGPoint(x: position.x - previous.x, y: position.y - previous.y)
                let dt = now - self.dragTime
                if translation != .zero {
                    let interval = CGFloat(max(dt, 1.0 / 240.0))
                    self.dragVelocity = CGPoint(x: translation.x / interval, y: translation.y / interval)
                    self.dragTime = now
                } else if dt > 0.12 {
                    self.dragVelocity = .zero
                }
                self.dragPosition = gesture.state == .ended ? nil : position
                self.diamondLayer.updateDrag(state: gesture.state, translation: translation, velocity: self.dragVelocity, scale: 220.0)
            case .cancelled, .failed:
                self.dragPosition = nil
                self.diamondLayer.updateDrag(state: .cancelled)
            default:
                break
            }
        }

        private func setHolding(_ holding: Bool) {
            guard self.isHolding != holding else { return }
            let now = CACurrentMediaTime()
            self.updateExpansion(at: now)
            self.isHolding = holding
            if UIAccessibility.isReduceMotionEnabled {
                self.expansion = nil
                self.grip = holding ? 1.0 : 0.0
            } else {
                self.expansion = Expansion(start: now, from: self.grip, holding: holding)
            }
            self.applyExpansion()
        }

        private func updateExpansion(at time: CFTimeInterval) {
            guard let expansion = self.expansion else { return }
            let elapsed = max(0.0, time - expansion.start)
            if expansion.holding {
                let t = min(1.0, elapsed / 0.46)
                let u = t * t * (3.0 - 2.0 * t)
                let settle = 1.0 - exp(-5.6 * u) * (cos(6.2 * u) + 5.6 / 6.2 * sin(6.2 * u))
                self.grip = expansion.from + (1.0 - expansion.from) * CGFloat(settle)
                if t == 1.0 {
                    self.grip = 1.0
                    self.expansion = nil
                }
            } else {
                self.grip = expansion.from * CGFloat(exp(-4.2 * elapsed) * cos(7.0 * elapsed))
                if elapsed >= 1.96 {
                    self.grip = 0.0
                    self.expansion = nil
                }
            }
            self.applyExpansion()
        }

        private func applyExpansion() {
            let expanded = self.isHolding || self.expansion != nil
            self.diamondLayer.usesHighFrameRate = expanded
            self.diamondLayer.interactionScale = Float(1.0 + 2.75 * self.grip)
            self.diamondLayer.refractionStrength = Float(min(1.0, max(0.0, self.grip)))
            self.diamondLayer.renderSize = expanded ? CGSize(width: 220.0, height: 220.0) : self.restingSize
            self.diamondLayer.setNeedsUpdate()
            if self.isExpanded != expanded {
                self.isExpanded = expanded
                self.onExpansionChanged?(expanded)
            }
        }

        public func cancelInteraction() {
            guard self.isHolding || self.expansion != nil || self.dragPosition != nil else { return }
            if self.pressGesture.state == .began || self.pressGesture.state == .changed {
                self.pressGesture.isEnabled = false
                self.pressGesture.isEnabled = true
            }
            if self.isHolding { self.diamondLayer.updateDrag(state: .cancelled) }
            self.dragPosition = nil
            self.isHolding = false
            self.expansion = nil
            self.grip = 0.0
            self.applyExpansion()
        }

        public func spin(_ velocity: Float, decay: Float) {
            self.diamondLayer.spin(velocity, decay: decay)
        }

        public func updateRefractionSource(_ source: RefractionSource?) {
            guard self.diamondLayer.refractionSource != source else { return }
            self.diamondLayer.refractionSource = source
            self.diamondLayer.setNeedsUpdate()
        }

        fileprivate func update(component: InteractiveDiamondComponent) -> CGSize {
            self.restingSize = component.size
            var style = self.diamondLayer.diamondStyle
            style.widthPoints = Float(component.diamondWidth)
            self.diamondLayer.update(style: style)
            self.diamondLayer.position = CGPoint(x: component.size.width * 0.5, y: component.size.height * 0.5)
            self.diamondLayer.lightBackground = !component.theme.overallDarkAppearance
            self.isRenderingEnabled = component.isVisible
            self.applyExpansion()
            return component.size
        }
    }

    public func makeView() -> View { return View(frame: .zero) }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self)
    }
}

public final class PremiumDiamondComponent: Component {
    let theme: PresentationTheme

    public init(theme: PresentationTheme) {
        self.theme = theme
    }

    public static func ==(lhs: PremiumDiamondComponent, rhs: PremiumDiamondComponent) -> Bool {
        return lhs.theme === rhs.theme
    }

    public final class View: UIView, ComponentTaggedView {
        public final class Tag {
            public init() {
            }
        }

        private let diamondLayer = InteractiveDiamondLayer()
        private let readyPromise = Promise<Bool>()

        public var ready: Signal<Bool, NoError> {
            return self.readyPromise.get()
        }

        public func matches(tag: Any) -> Bool {
            return tag is Tag
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isOpaque = false
            self.diamondLayer.onReady = { [weak self] in
                self?.readyPromise.set(.single(true))
            }
            self.layer.addSublayer(self.diamondLayer)

            let panGesture = UIPanGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handlePan(_:)))
            self.addGestureRecognizer(panGesture)
            let tapGesture = UITapGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handleTap(_:)))
            tapGesture.require(toFail: panGesture)
            self.addGestureRecognizer(tapGesture)
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: PremiumDiamondComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.diamondLayer.bounds = CGRect(origin: .zero, size: availableSize)
            self.diamondLayer.position = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5 - 8.0)
            self.diamondLayer.lightBackground = !component.theme.overallDarkAppearance
            self.diamondLayer.setNeedsUpdate()
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
