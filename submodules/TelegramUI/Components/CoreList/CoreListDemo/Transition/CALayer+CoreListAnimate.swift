import UIKit
import QuartzCore

extension CALayer {
    /// Executor-path animation. Samples the curve into a keyframe animation, which is how CoreList
    /// renders every curve (`CoreAnimationCompiler` does the same for model tracks) — so `.custom`
    /// and `.spring` need no `CAMediaTimingFunction` equivalent.
    ///
    /// Duration is scaled by `UIView.animationDurationFactor` HERE, exactly once, mirroring
    /// Display's `CAAnimationUtils`. The model path scales in `ListAnimationController` and never
    /// reaches this function; see the design doc's "two authorities, one scaling rule".
    func animate(from: CGFloat,
                 to: CGFloat,
                 keyPath: String,
                 duration: Double,
                 delay: Double = 0.0,
                 curve: CoreListTransition.Animation.Curve,
                 removeOnCompletion: Bool = true,
                 additive: Bool = false,
                 completion: ((Bool) -> Void)? = nil,
                 key: String? = nil) {
        let factor = UIView.animationDurationFactor
        let scaledDuration = max(0.0, duration * factor)
        guard scaledDuration > 0 else {
            completion?(true)
            return
        }

        let sampleCount = max(2, Int(ceil(scaledDuration * 240.0)) + 1)
        let lastIndex = sampleCount - 1
        var values: [NSNumber] = []
        var keyTimes: [NSNumber] = []
        values.reserveCapacity(sampleCount)
        keyTimes.reserveCapacity(sampleCount)
        for index in 0...lastIndex {
            let phase = CGFloat(index) / CGFloat(lastIndex)
            values.append(NSNumber(value: Double(from + (to - from) * curve.solve(at: phase))))
            keyTimes.append(NSNumber(value: Double(phase)))
        }

        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .linear
        animation.duration = scaledDuration
        animation.isAdditive = additive
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = removeOnCompletion ? .forwards : .both
        if delay > 0 {
            animation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay * factor
        }
        if let completion {
            CoreListTransition.commit(disablingImplicitActions: true,
                                      completion: { completion(true) }) {
                self.add(animation, forKey: key ?? keyPath)
            }
        } else {
            CoreListTransition.commit { self.add(animation, forKey: key ?? keyPath) }
        }
    }
}
