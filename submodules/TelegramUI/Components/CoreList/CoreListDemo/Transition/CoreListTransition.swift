import UIKit
import QuartzCore

/// A ComponentTransition-shaped animation descriptor, vendored into CoreList.
///
/// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and the demo builds
/// standalone in Xcode — so this is a self-contained copy of the value model in
/// `submodules/ComponentFlow/Source/Base/Transition.swift`. The `Animation`/`Curve` case shape is
/// identical, so `CoreListTransitionBridge.swift` in TelegramUI maps between the two case-for-case.
///
/// Deliberate divergences, all recorded in
/// `docs/superpowers/specs/2026-07-27-corelist-transition-design.md`:
///
/// - **A zero duration is immediate.** ComponentFlow treats only `.none` as immediate;
///   `.curve(duration: 0, …)` still animates there. CoreList's model settles a zero-duration
///   property immediately and half its test suite says "no animation" as `duration: 0`, so every
///   branch here tests `isImmediate` and none writes `if case .none`.
/// - **`.spring` is an approximation** (Display's bezier fallback, not the private
///   `springAnimationValueAt`), and **`.bounce` is not a unit curve** — ComponentFlow's own `solve`
///   asserts on it too. CoreList adopts neither as a default; both are supported on input.
/// - **Additions over ComponentTransition:** `Animation`/`Curve` are `Equatable` (because
///   `ListAnimationTrack` is), the struct has a hand-written `==` over `animation` alone
///   (`_userData: [Any]` blocks synthesis), and `duration`/`curve`/`scaled(by:)` carry over from the
///   deleted `ListAnimationSpec`.
/// - **Not vendored:** shape-layer, gradient, blur, mesh, parabolic, and keyframe-transform helpers.
///   No CoreList consumer, and several need private API.
public struct CoreListTransition: Equatable {
    public enum Animation: Equatable {
        public enum Curve: Equatable {
            case easeInOut
            case easeIn
            case spring
            case linear
            case custom(Float, Float, Float, Float)
            case bounce(stiffness: CGFloat, damping: CGFloat)

            public static var slide: Curve { .custom(0.33, 0.52, 0.25, 0.99) }
        }

        case none
        case curve(duration: Double, curve: Curve)
    }

    public var animation: Animation
    private var _userData: [Any] = []

    public init(animation: Animation) {
        self.animation = animation
    }

    public static var immediate: CoreListTransition { CoreListTransition(animation: .none) }

    public static func easeInOut(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .easeInOut))
    }

    public static func spring(duration: Double) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .spring))
    }

    /// True when this transition must settle its target with no animation. Unlike ComponentFlow,
    /// a non-positive duration counts: CoreList's model settles such a property immediately.
    public var isImmediate: Bool {
        switch self.animation {
        case .none:
            return true
        case let .curve(duration, _):
            return duration <= 0
        }
    }

    public var duration: TimeInterval {
        switch self.animation {
        case .none:
            return 0
        case let .curve(duration, _):
            return max(0, duration)
        }
    }

    public var curve: Animation.Curve? {
        switch self.animation {
        case .none:
            return nil
        case let .curve(_, curve):
            return curve
        }
    }

    /// Multiplies the duration, keeping the curve. Used by `ListAnimationController` to apply the
    /// Slow Animations factor exactly once on the model path.
    public func scaled(by factor: Double) -> CoreListTransition {
        switch self.animation {
        case .none:
            return self
        case let .curve(duration, curve):
            var result = self
            result.animation = .curve(duration: max(0, duration * factor), curve: curve)
            return result
        }
    }

    public func withAnimation(_ animation: Animation) -> CoreListTransition {
        var result = self
        result.animation = animation
        return result
    }

    public func withAnimationIfAnimated(_ animation: Animation) -> CoreListTransition {
        if self.isImmediate { return self }
        return self.withAnimation(animation)
    }

    public func userData<T>(_ type: T.Type) -> T? {
        for item in self._userData.reversed() {
            if let item = item as? T { return item }
        }
        return nil
    }

    public func withUserData(_ userData: Any) -> CoreListTransition {
        var result = self
        result._userData.append(userData)
        return result
    }

    /// `_userData` is `[Any]` and cannot participate; equality is the animation alone.
    public static func == (lhs: CoreListTransition, rhs: CoreListTransition) -> Bool {
        lhs.animation == rhs.animation
    }
}

public extension CoreListTransition {
    /// The module's ONLY `CATransaction` scope. Every settled write, every animation install, and
    /// the physics deceleration flights go through this; `CATransaction` must not be named anywhere
    /// else in CoreList.
    ///
    /// - Parameter disablingImplicitActions: mirrors `CATransaction.setDisableActions`. The
    ///   deceleration-flight sites pass `false` deliberately — they never disabled actions.
    /// - Parameter completion: mirrors `CATransaction.setCompletionBlock`.
    static func commit(disablingImplicitActions: Bool = true,
                       completion: (() -> Void)? = nil,
                       _ body: () -> Void) {
        CATransaction.begin()
        if disablingImplicitActions {
            CATransaction.setDisableActions(true)
        }
        if let completion {
            CATransaction.setCompletionBlock(completion)
        }
        body()
        CATransaction.commit()
    }

    // MARK: - Setters
    //
    // Each early-outs on an equal target, exactly as ComponentTransition's do, and each writes the
    // final value before installing an animation. `.immediate` writes inside `commit` so an
    // enclosing UIView animation block cannot capture the write implicitly.

    func setPositionY(layer: CALayer, _ value: CGFloat) {
        if layer.position.y == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.position.y = value
                layer.removeAnimation(forKey: "position")
            }
            return
        }
        let previous = layer.presentation()?.position.y ?? layer.position.y
        CoreListTransition.commit { layer.position.y = value }
        self.animateScalar(layer: layer, keyPath: "position.y", from: previous, to: value)
    }

    func setPositionX(layer: CALayer, _ value: CGFloat) {
        if layer.position.x == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.position.x = value
                layer.removeAnimation(forKey: "position")
            }
            return
        }
        let previous = layer.presentation()?.position.x ?? layer.position.x
        CoreListTransition.commit { layer.position.x = value }
        self.animateScalar(layer: layer, keyPath: "position.x", from: previous, to: value)
    }

    func setPosition(layer: CALayer, _ position: CGPoint) {
        self.setPositionX(layer: layer, position.x)
        self.setPositionY(layer: layer, position.y)
    }

    func setBoundsHeight(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.height == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.size.height = value
                layer.removeAnimation(forKey: "bounds.size.height")
            }
            return
        }
        let previous = layer.presentation()?.bounds.size.height ?? layer.bounds.size.height
        CoreListTransition.commit { layer.bounds.size.height = value }
        self.animateScalar(layer: layer, keyPath: "bounds.size.height", from: previous, to: value)
    }

    func setBoundsWidth(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.size.width == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.size.width = value
                layer.removeAnimation(forKey: "bounds.size.width")
            }
            return
        }
        let previous = layer.presentation()?.bounds.size.width ?? layer.bounds.size.width
        CoreListTransition.commit { layer.bounds.size.width = value }
        self.animateScalar(layer: layer, keyPath: "bounds.size.width", from: previous, to: value)
    }

    func setBoundsOriginY(layer: CALayer, _ value: CGFloat) {
        if layer.bounds.origin.y == value { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.bounds.origin.y = value
                layer.removeAnimation(forKey: "bounds.origin.y")
            }
            return
        }
        let previous = layer.presentation()?.bounds.origin.y ?? layer.bounds.origin.y
        CoreListTransition.commit { layer.bounds.origin.y = value }
        self.animateScalar(layer: layer, keyPath: "bounds.origin.y", from: previous, to: value)
    }

    func setOpacity(layer: CALayer, _ value: CGFloat) {
        if layer.opacity == Float(value) { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.opacity = Float(value)
                layer.removeAnimation(forKey: "opacity")
            }
            return
        }
        let previous = CGFloat(layer.presentation()?.opacity ?? layer.opacity)
        CoreListTransition.commit { layer.opacity = Float(value) }
        self.animateScalar(layer: layer, keyPath: "opacity", from: previous, to: value)
    }

    func setAlpha(view: UIView, _ value: CGFloat) {
        self.setOpacity(layer: view.layer, value)
    }

    func setFrame(view: UIView, frame: CGRect) {
        self.setFrame(layer: view.layer, frame: frame)
    }

    func setFrame(layer: CALayer, frame: CGRect) {
        if layer.frame == frame { return }
        if self.isImmediate {
            CoreListTransition.commit { layer.frame = frame }
            return
        }
        let anchor = layer.anchorPoint
        self.setBoundsWidth(layer: layer, frame.width)
        self.setBoundsHeight(layer: layer, frame.height)
        self.setPosition(layer: layer,
                         CGPoint(x: frame.minX + frame.width * anchor.x,
                                 y: frame.minY + frame.height * anchor.y))
    }

    func setScale(layer: CALayer, _ scale: CGFloat) {
        let transform = layer.transform
        let current = sqrt((transform.m11 * transform.m11)
                           + (transform.m12 * transform.m12)
                           + (transform.m13 * transform.m13))
        if current == scale { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
                layer.removeAnimation(forKey: "transform.scale")
            }
            return
        }
        CoreListTransition.commit { layer.transform = CATransform3DMakeScale(scale, scale, 1.0) }
        self.animateScalar(layer: layer, keyPath: "transform.scale", from: current, to: scale)
    }

    func setScale(view: UIView, _ scale: CGFloat) {
        self.setScale(layer: view.layer, scale)
    }

    func setTransform(layer: CALayer, transform: CATransform3D) {
        if CATransform3DEqualToTransform(layer.transform, transform) { return }
        if self.isImmediate {
            CoreListTransition.commit {
                layer.transform = transform
                layer.removeAnimation(forKey: "transform")
            }
            return
        }
        // A CATransform3D is not a scalar, so this samples the keyframes itself rather than going
        // through animateScalar.
        guard case let .curve(duration, curve) = self.animation, duration > 0 else { return }
        let previous = layer.presentation()?.transform ?? layer.transform
        CoreListTransition.commit { layer.transform = transform }
        let scaledDuration = max(0.0, duration * UIView.animationDurationFactor)
        let sampleCount = max(2, Int(ceil(scaledDuration * 240.0)) + 1)
        var values: [NSValue] = []
        var keyTimes: [NSNumber] = []
        for index in 0..<sampleCount {
            let phase = CGFloat(index) / CGFloat(sampleCount - 1)
            let t = curve.solve(at: phase)
            var interpolated = CATransform3DIdentity
            // Element-wise interpolation. Correct for the affine transforms CoreList item views
            // use (translate / scale / rotate about z); it is not a general matrix interpolation.
            withUnsafeBytes(of: previous) { fromBytes in
                withUnsafeBytes(of: transform) { toBytes in
                    withUnsafeMutableBytes(of: &interpolated) { outBytes in
                        let from = fromBytes.bindMemory(to: CGFloat.self)
                        let to = toBytes.bindMemory(to: CGFloat.self)
                        let out = outBytes.bindMemory(to: CGFloat.self)
                        for i in 0..<16 {
                            out[i] = from[i] + (to[i] - from[i]) * t
                        }
                    }
                }
            }
            values.append(NSValue(caTransform3D: interpolated))
            keyTimes.append(NSNumber(value: Double(phase)))
        }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .linear
        animation.duration = scaledDuration
        animation.isRemovedOnCompletion = true
        animation.fillMode = .forwards
        CoreListTransition.commit { layer.add(animation, forKey: "transform") }
    }

    func setTransform(view: UIView, transform: CATransform3D) {
        self.setTransform(layer: view.layer, transform: transform)
    }

    /// Scalar animation primitive. All setters funnel here so duration scaling and the sampled-curve
    /// rendering live in one place.
    func animateScalar(layer: CALayer,
                       keyPath: String,
                       from: CGFloat,
                       to: CGFloat,
                       additive: Bool = false,
                       completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            completion?(true)
            return
        }
        layer.animate(from: from, to: to, keyPath: keyPath, duration: duration, delay: 0,
                      curve: curve, removeOnCompletion: true, additive: additive,
                      completion: completion)
    }

    /// UIView-block animation, for item views laying out with UIKit rather than layer writes.
    /// `.custom` and `.bounce` degrade to ease-in-out options: faithful handling needs
    /// `CALayerSpringParametersOverride`, which is private API CoreList cannot reach.
    func animateView(allowUserInteraction: Bool = true,
                     delay: Double = 0.0,
                     _ body: @escaping () -> Void,
                     completion: ((Bool) -> Void)? = nil) {
        guard case let .curve(duration, curve) = self.animation, duration > 0 else {
            body()
            completion?(true)
            return
        }
        var options: UIView.AnimationOptions
        switch curve {
        case .linear:
            options = [.curveLinear]
        case .easeIn:
            options = [.curveEaseIn]
        case .spring:
            options = UIView.AnimationOptions(rawValue: 7 << 16)
        case .easeInOut, .custom, .bounce:
            options = [.curveEaseInOut]
        }
        if allowUserInteraction {
            options.insert(.allowUserInteraction)
        }
        UIView.animate(withDuration: duration * UIView.animationDurationFactor,
                       delay: delay * UIView.animationDurationFactor,
                       options: options,
                       animations: body,
                       completion: completion)
    }
}
