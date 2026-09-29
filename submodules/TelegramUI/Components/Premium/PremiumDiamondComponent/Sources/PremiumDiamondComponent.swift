import UIKit
import Display
import ComponentFlow
import Metal
import MetalEngine
import SwiftSignalKit
import TelegramPresentationData

public final class InteractiveDiamondComponent: Component {
    public enum Appearance: UInt32, CaseIterable, Sendable {
        case blue = 0
        case white = 1
        case cool = 2
    }

    public enum ExpansionStyle {
        case centered
        case downward
    }

    public enum AnimationMode: Equatable {
        case continuous
        case lottie(loop: Bool)
    }

    public struct MotionState {
        public let rotation: CGFloat
        public let time: CFTimeInterval
        public let transferEnergy: CGFloat?
    }

    public struct RefractionSource: Equatable {
        let texture: MTLTexture
        let uv: SIMD4<Float>
        let rect: CGRect
        let preservesColors: Bool
        let backgroundColor: SIMD3<Float>?

        public init(texture: MTLTexture, uv: SIMD4<Float>, rect: CGRect, preservesColors: Bool = false, backgroundColor: SIMD3<Float>? = nil) {
            self.texture = texture
            self.uv = uv
            self.rect = rect
            self.preservesColors = preservesColors
            self.backgroundColor = backgroundColor
        }

        public static func ==(lhs: RefractionSource, rhs: RefractionSource) -> Bool {
            return lhs.texture === rhs.texture && lhs.uv == rhs.uv && lhs.rect == rhs.rect
                && lhs.preservesColors == rhs.preservesColors
                && lhs.backgroundColor == rhs.backgroundColor
        }
    }

    private let size: CGSize
    private let diamondWidth: CGFloat
    private let isVisible: Bool
    private let theme: PresentationTheme
    private let appearance: Appearance
    private let expansionStyle: ExpansionStyle
    private let expandedCenter: CGPoint?
    private let animationMode: AnimationMode
    private let animateOnAppear: Bool
    private let tapToSpin: Bool

    public init(size: CGSize, diamondWidth: CGFloat, isVisible: Bool, theme: PresentationTheme, appearance: Appearance = .blue, expansionStyle: ExpansionStyle = .centered, expandedCenter: CGPoint? = nil, animationMode: AnimationMode = .continuous, animateOnAppear: Bool = false, tapToSpin: Bool = false) {
        self.size = size
        self.diamondWidth = diamondWidth
        self.isVisible = isVisible
        self.theme = theme
        self.appearance = appearance
        self.expansionStyle = expansionStyle
        self.expandedCenter = expandedCenter
        self.animationMode = animationMode
        self.animateOnAppear = animateOnAppear
        self.tapToSpin = tapToSpin
    }

    public static func ==(lhs: InteractiveDiamondComponent, rhs: InteractiveDiamondComponent) -> Bool {
        return lhs.size == rhs.size && lhs.diamondWidth == rhs.diamondWidth
            && lhs.isVisible == rhs.isVisible && lhs.theme === rhs.theme && lhs.appearance == rhs.appearance
            && lhs.expansionStyle == rhs.expansionStyle
            && lhs.expandedCenter == rhs.expandedCenter
            && lhs.animationMode == rhs.animationMode
            && lhs.animateOnAppear == rhs.animateOnAppear
            && lhs.tapToSpin == rhs.tapToSpin
    }

    public final class View: UIView {
        private struct Expansion {
            let start: CFTimeInterval
            let from: CGFloat
            let holding: Bool
        }

        private let diamondLayer = InteractiveDiamondLayer(backgroundStars: false)
        public let pressGesture = UILongPressGestureRecognizer()
        private var isHolding = false
        public private(set) var isExpanded = false
        public var onExpansionChanged: ((Bool) -> Void)?
        public var onMotionUpdated: ((MotionState?) -> Void)?
        public var scrollTiltProvider: ((CFTimeInterval) -> Float)? {
            get { return self.diamondLayer.scrollTiltProvider }
            set { self.diamondLayer.scrollTiltProvider = newValue }
        }
        private var restingSize = CGSize.zero
        private var expansionStyle: ExpansionStyle = .centered
        private var expandedCenter: CGPoint?
        private var refractionSource: RefractionSource?
        private var animationMode: AnimationMode = .continuous
        private var expansion: Expansion?
        private var grip: CGFloat = 0.0
        private var dragPosition: CGPoint?
        private var pressStart: (position: CGPoint, time: CFTimeInterval)?
        private var dragSamples: [(x: CGFloat, time: CFTimeInterval)] = []
        private var landingHaptic: DispatchWorkItem?

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

        public var isPlaying: Bool {
            return self.diamondLayer.isPlaying
        }

        public func playOnce() {
            guard self.animationMode == .lottie(loop: false) else { return }
            self.diamondLayer.resetAnimation()
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
            self.diamondLayer.onPoseUpdated = { [weak self] pose in
                guard let self else { return }
                if self.expansionStyle == .downward {
                    self.applyExpansion()
                } else {
                    self.updateExpansion(at: CACurrentMediaTime())
                }
                if let onMotionUpdated = self.onMotionUpdated {
                    if let state = self.diamondLayer.animationState {
                        onMotionUpdated(MotionState(
                            rotation: CGFloat(pose.yaw),
                            time: CFTimeInterval(state.time),
                            transferEnergy: state.transferEnergy.map { CGFloat($0) }
                        ))
                    } else {
                        onMotionUpdated(nil)
                    }
                }
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
            self.landingHaptic?.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func reduceMotionChanged() {
            self.diamondLayer.setReduceMotion(UIAccessibility.isReduceMotionEnabled)
            if UIAccessibility.isReduceMotionEnabled {
                self.expansion = nil
                self.grip = self.isHolding ? 1.0 : 0.0
                self.diamondLayer.resetGrowth()
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
            if self.animationMode != .continuous {
                return super.point(inside: point, with: event)
            }
            return CGRect(x: self.bounds.midX - 32.0, y: self.bounds.midY - 32.0, width: 64.0, height: 64.0).contains(point)
        }

        @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
            let now = CACurrentMediaTime()
            let position = gesture.location(in: self)
            switch gesture.state {
            case .began:
                self.cancelLandingHaptic()
                Haptics.prime()
                self.dragPosition = position
                self.pressStart = (position, now)
                self.dragSamples = [(position.x, now)]
                self.diamondLayer.updateDrag(state: .began)
            case .changed, .ended:
                guard let previous = self.dragPosition else { return }
                let wasHolding = self.isHolding
                let releasePower = CGFloat(self.diamondLayer.refractionStrength)
                let translation = CGPoint(x: position.x - previous.x, y: position.y - previous.y)
                // Average recent movement so a tiny final touch sample does not erase the fling.
                self.dragSamples.append((position.x, now))
                while self.dragSamples.count > 2 && self.dragSamples[0].time < now - 0.08 {
                    self.dragSamples.removeFirst()
                }
                let sample = self.dragSamples[0]
                let interval = CGFloat(max(now - sample.time, 1.0 / 240.0))
                let velocity = CGPoint(x: (position.x - sample.x) / interval, y: 0.0)
                let tapDirection: Float?
                if gesture.state == .ended, self.diamondLayer.diamondStyle.tapToSpin,
                   let pressStart = self.pressStart, now - pressStart.time < 0.25,
                   hypot(position.x - pressStart.position.x, position.y - pressStart.position.y) < 10.0 {
                    tapDirection = position.x < self.bounds.midX ? -1.0 : 1.0
                } else {
                    tapDirection = nil
                }
                self.dragPosition = gesture.state == .ended ? nil : position
                if gesture.state == .ended {
                    self.pressStart = nil
                    self.dragSamples.removeAll(keepingCapacity: true)
                }
                self.diamondLayer.updateDrag(state: gesture.state, translation: translation, velocity: velocity, scale: 220.0, releaseImpulse: 3.0 * 6.5, playFlingHaptic: false, tapSpinDirection: tapDirection)
                if gesture.state == .ended, wasHolding {
                    self.scheduleLandingHaptic(power: releasePower)
                }
            case .cancelled, .failed:
                self.cancelLandingHaptic()
                self.dragPosition = nil
                self.pressStart = nil
                self.dragSamples.removeAll(keepingCapacity: true)
                self.diamondLayer.updateDrag(state: .cancelled)
            default:
                break
            }
        }

        private func scheduleLandingHaptic(power: CGFloat) {
            self.cancelLandingHaptic()
            guard power > 0.2, !self.isHolding else { return }
            let impact = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.landingHaptic = nil
                guard self.window != nil, self.isRenderingEnabled, self.isUserInteractionEnabled,
                      !self.isHolding, UIApplication.shared.applicationState == .active else { return }
                Haptics.hit(0.35 + 0.4 * min(1.0, power))
            }
            self.landingHaptic = impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: impact)
        }

        private func cancelLandingHaptic() {
            self.landingHaptic?.cancel()
            self.landingHaptic = nil
        }

        private func setHolding(_ holding: Bool) {
            guard self.isHolding != holding else { return }
            let now = CACurrentMediaTime()
            self.updateExpansion(at: now)
            self.isHolding = holding
            if self.expansionStyle == .downward {
                if UIAccessibility.isReduceMotionEnabled {
                    self.diamondLayer.resetGrowth()
                }
                self.applyExpansion()
                return
            }
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
            let expanded = self.isHolding || self.expansion != nil || self.diamondLayer.isGrowthAnimating
            self.diamondLayer.usesHighFrameRate = expanded || self.diamondLayer.hasTransferAnimation || self.diamondLayer.hasBumpAnimation
            self.diamondLayer.interactionScale = self.expansionStyle == .downward ? 1.0 : Float(1.0 + 2.75 * self.grip)
            let refractionStrength = self.expansionStyle == .downward && self.diamondLayer.diamondStyle.dragGrow != 1.0
                ? (self.diamondLayer.pose.grow - 1.0) / (self.diamondLayer.diamondStyle.dragGrow - 1.0)
                : Float(self.grip)
            self.diamondLayer.refractionStrength = min(1.0, max(0.0, refractionStrength))
            let restingCenter = CGPoint(x: self.restingSize.width * 0.5, y: self.restingSize.height * 0.5)
            let expandedCenter = self.expandedCenter ?? restingCenter
            // Move the rendered layer with the growth spring, keeping gesture coordinates fixed.
            self.diamondLayer.position = CGPoint(
                x: restingCenter.x + (expandedCenter.x - restingCenter.x) * CGFloat(refractionStrength),
                y: restingCenter.y + (expandedCenter.y - restingCenter.y) * CGFloat(refractionStrength)
            )
            self.updateRefractionPosition()
            if self.diamondLayer.isCompletingTransfer || self.diamondLayer.hasStarBursts {
                self.diamondLayer.renderSize = CGSize(width: 240.0, height: 240.0)
            } else if expanded {
                self.diamondLayer.renderSize = CGSize(width: 220.0, height: 220.0)
            } else if self.diamondLayer.hasTransferAnimation || self.diamondLayer.hasBumpAnimation {
                self.diamondLayer.renderSize = CGSize(width: 96.0, height: 96.0)
            } else {
                self.diamondLayer.renderSize = self.restingSize
            }
            self.diamondLayer.setNeedsUpdate()
            if self.isExpanded != expanded {
                self.isExpanded = expanded
                self.onExpansionChanged?(expanded)
            }
        }

        public func cancelInteraction() {
            self.cancelLandingHaptic()
            self.diamondLayer.cancelTapSpin()
            guard self.isHolding || self.expansion != nil || self.dragPosition != nil || self.diamondLayer.isGrowthAnimating else {
                self.applyExpansion()
                return
            }
            if self.pressGesture.state == .began || self.pressGesture.state == .changed {
                self.pressGesture.isEnabled = false
                self.pressGesture.isEnabled = true
            }
            if self.isHolding { self.diamondLayer.updateDrag(state: .cancelled) }
            self.dragPosition = nil
            self.pressStart = nil
            self.dragSamples.removeAll(keepingCapacity: true)
            self.isHolding = false
            self.expansion = nil
            self.grip = 0.0
            self.diamondLayer.resetGrowth()
            self.applyExpansion()
        }

        public func spin(_ velocity: Float, decay: Float) {
            self.diamondLayer.spin(velocity, decay: decay)
        }

        public func animateBump(delay: Double = 0.0) {
            self.diamondLayer.animateBump(delay: delay)
        }

        public func updateTransferState(isSending: Bool, animateCompletion: Bool) {
            self.diamondLayer.updateTransferState(isSending: isSending, animateCompletion: animateCompletion)
        }

        public func updateRefractionSource(_ source: RefractionSource?) {
            guard self.refractionSource != source else { return }
            self.refractionSource = source
            self.updateRefractionPosition()
            self.diamondLayer.setNeedsUpdate()
        }

        private func updateRefractionPosition() {
            guard let source = self.refractionSource else {
                self.diamondLayer.refractionSource = nil
                return
            }
            self.diamondLayer.refractionSource = RefractionSource(
                texture: source.texture,
                uv: source.uv,
                rect: source.rect.offsetBy(
                    dx: self.restingSize.width * 0.5 - self.diamondLayer.position.x,
                    dy: self.restingSize.height * 0.5 - self.diamondLayer.position.y
                ),
                preservesColors: source.preservesColors,
                backgroundColor: source.backgroundColor
            )
        }

        fileprivate func update(component: InteractiveDiamondComponent) -> CGSize {
            if self.animationMode != component.animationMode {
                self.cancelInteraction()
                self.animationMode = component.animationMode
            }
            let isInteractive = component.animationMode == .continuous
            self.pressGesture.isEnabled = isInteractive
            self.disablesInteractiveModalDismiss = isInteractive
            self.disablesInteractiveTransitionGestureRecognizer = isInteractive
            if self.expansionStyle != component.expansionStyle {
                self.cancelInteraction()
                self.expansionStyle = component.expansionStyle
            }
            self.restingSize = component.size
            self.expandedCenter = component.expandedCenter
            var style = self.diamondLayer.diamondStyle
            style.animateOnAppear = component.animateOnAppear
            switch component.animationMode {
            case .continuous:
                style.animationMode = .continuous
                style.referenceAnimationLoops = true
            case let .lottie(loop):
                style.animationMode = .reference
                style.referenceAnimationLoops = loop
            }
            style.swayScale = isInteractive ? 1.0 : 0.0
            style.floatAmplitude = isInteractive ? 1.5 : 0.0
            style.floatPeriod = 3.2
            self.diamondLayer.highlightBoost = isInteractive ? 0.4 : 0.0
            style.mainSparkleOnRotation = isInteractive
            style.widthPoints = Float(component.diamondWidth)
            style.appearance = component.appearance
            // The card reference keeps the top nearly fixed: 3x growth moves the center down by 24 pt.
            style.dragGrow = component.expansionStyle == .downward ? 3.0 : 1.0
            style.growShift = component.expansionStyle == .downward && component.expandedCenter == nil ? 12.0 : 0.0
            style.growDamping = component.expansionStyle == .downward ? 0.62 : 0.42
            style.releaseDecay = component.expansionStyle == .downward ? 1.1 : 0.0
            style.releaseTilt = component.expansionStyle == .downward ? 0.0 : 2.6
            style.tapToSpin = isInteractive && component.tapToSpin
            self.diamondLayer.update(style: style)
            self.diamondLayer.lightBackground = component.expansionStyle == .centered && !component.theme.overallDarkAppearance
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

public enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let firm = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static var pendingRefusal: DispatchWorkItem?

    public static func prime() { light.prepare() }

    public static func hit(_ intensity: CGFloat = 0.45) {
        light.impactOccurred(intensity: intensity)
        light.prepare()
    }

    public static func strong() {
        heavy.impactOccurred(intensity: 1)
        heavy.prepare()
    }

    public static func refuse() {
        cancelRefusal()
        firm.impactOccurred(intensity: 0.8)
        firm.prepare()
        let secondImpact = DispatchWorkItem {
            pendingRefusal = nil
            guard UIApplication.shared.applicationState == .active else { return }
            firm.impactOccurred(intensity: 0.55)
            firm.prepare()
        }
        pendingRefusal = secondImpact
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: secondImpact)
    }

    public static func cancelRefusal() {
        pendingRefusal?.cancel()
        pendingRefusal = nil
    }
}
