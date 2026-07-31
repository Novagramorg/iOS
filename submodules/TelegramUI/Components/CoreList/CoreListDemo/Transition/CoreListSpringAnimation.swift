import UIKit
import QuartzCore

// Spring factories copied verbatim from UIKitRuntimeUtils' `makeSpringAnimationImpl` /
// `make26SpringAnimationImpl` (UIKitUtils.m:53, :68). Only `valueAt:` and the
// `highFrameRateReason` key were private there; the CASpringAnimation parameters themselves are
// public API, so CoreList builds the same animations without taking the dependency.

func makeCoreListSpringAnimation(_ keyPath: String, duration: Double) -> CABasicAnimation {
    if #available(iOS 26.0, *) {
        return makeCoreList26SpringAnimation(keyPath, duration)
    }
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 3.0
    springAnimation.stiffness = 1000.0
    springAnimation.damping = 500.0
    springAnimation.duration = 0.5
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    return springAnimation
}

func makeCoreList26SpringAnimation(_ keyPath: String, _ duration: Double) -> CABasicAnimation {
    let springAnimation = CASpringAnimation(keyPath: keyPath)
    springAnimation.mass = 1.0
    springAnimation.stiffness = 555.027
    springAnimation.damping = 47.118
    springAnimation.duration = duration
    springAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
    if #available(iOS 17.0, *) {
        springAnimation.allowsOverdamping = false
    }
    if #available(iOS 15.0, *) {
        springAnimation.preferredFrameRateRange = CAFrameRateRange(minimum: 80.0,
                                                                   maximum: 120.0,
                                                                   preferred: 120.0)
    }
    return springAnimation
}

/// Which of `CAAnimationUtils.swift:119`'s three `kCAMediaTimingFunctionSpring` branches a duration
/// selects.
///
/// **Always resolved from the LOGICAL duration.** `0.5` and `0.3832` are logical values —
/// `CAAnimationUtils` sees them unscaled because it handles Slow Animations with `speed`, whereas
/// CoreList pre-scales. Resolving from a scaled duration would see `5.0` under a ×10 drag
/// coefficient, miss `.system05`, and silently emit a bezier: a divergence visible only under Slow
/// Animations.
enum CoreListSpringKind: Equatable {
    case system26
    case system05
    case adjustedBezier
}

func coreListSpringKind(logicalDuration: Double) -> CoreListSpringKind {
    if #available(iOS 26.0, *), abs(logicalDuration - 0.3832) <= 0.0001 {
        return .system26
    }
    if logicalDuration == 0.5 {
        return .system05
    }
    return .adjustedBezier
}

/// Analytic evaluation of a real `CASpringAnimation`, reproducing what
/// `-[CASpringAnimation(AnimationUtils) valueAt:]` does in `UIKitUtils.m:24`.
///
/// `valueAt:` is Display's OWN category, not an Apple selector — `CASpringAnimation` does not
/// respond to it unless `UIKitRuntimeUtils` is linked, which CoreList deliberately does not do. What
/// it wraps is the genuinely private `_solveForInput:`, and the wrapper exists because that method's
/// argument is `float` on some builds and `double` on others, so the IMP has to be called with the
/// matching calling convention. This reimplements the same lookup.
///
/// The selector name is assembled at runtime rather than written as a literal, matching Display.
private enum CoreListSpringSolver {
    typealias FloatImp = @convention(c) (AnyObject, Selector, Float) -> Float
    typealias DoubleImp = @convention(c) (AnyObject, Selector, Double) -> Double

    static let selector = NSSelectorFromString("_" + "solveForInput:")

    /// Resolved once: which calling convention `_solveForInput:` uses, or neither if it is gone.
    static let resolved: (float: FloatImp?, double: DoubleImp?) = {
        guard let method = class_getInstanceMethod(CASpringAnimation.self, selector) else {
            return (nil, nil)
        }
        // Argument 2 is the first real parameter: 0 is self, 1 is _cmd. `NSMethodSignature` is not
        // usable from Swift, so read the encoding straight off the method.
        var argumentType = [CChar](repeating: 0, count: 16)
        method_getArgumentType(method, 2, &argumentType, argumentType.count)
        let imp = method_getImplementation(method)
        switch argumentType[0] {
        case CChar(UInt8(ascii: "f")):
            return (unsafeBitCast(imp, to: FloatImp.self), nil)
        case CChar(UInt8(ascii: "d")):
            return (nil, unsafeBitCast(imp, to: DoubleImp.self))
        default:
            return (nil, nil)
        }
    }()

    static func solve(_ animation: CASpringAnimation, _ t: CGFloat) -> CGFloat? {
        if let floatImp = resolved.float {
            return CGFloat(floatImp(animation, selector, Float(t)))
        }
        if let doubleImp = resolved.double {
            return CGFloat(doubleImp(animation, selector, Double(t)))
        }
        return nil
    }
}

private let system05Spring = makeCoreListSpringAnimation("", duration: 0.5) as? CASpringAnimation
private let system26Spring = makeCoreList26SpringAnimation("", 0.3832) as? CASpringAnimation

/// Analytic value of a system spring at unit `phase`, or nil for `.adjustedBezier` (solved by
/// `Curve.solve`) and on any OS where `_solveForInput:` has gone away — callers fall back to the
/// adjusted bezier so the model and the emitter degrade together rather than disagreeing.
///
/// Display's own fallback returns `t`, i.e. linear. Returning nil is better: it lets the caller use
/// the adjusted bezier, which is at least the right family of curve.
func coreListSpringValue(kind: CoreListSpringKind, phase: CGFloat) -> CGFloat? {
    let animation: CASpringAnimation?
    switch kind {
    case .system05: animation = system05Spring
    case .system26: animation = system26Spring
    case .adjustedBezier: return nil
    }
    guard let animation else { return nil }
    return CoreListSpringSolver.solve(animation, min(max(phase, 0.0), 1.0))
}
