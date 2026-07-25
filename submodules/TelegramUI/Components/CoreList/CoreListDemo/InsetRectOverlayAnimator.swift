import UIKit
import QuartzCore

/// Animates the demo's inset guide with the same granular Core Animation tracks as the list.
final class InsetRectOverlayAnimator {
    private let compiler: CoreAnimationCompiler
    private let mediaTime: () -> CFTimeInterval
    private let durationFactor: () -> Double
    private var nextGeneration: UInt64 = 0

    init(compiler: CoreAnimationCompiler = CoreAnimationCompiler(),
         mediaTime: @escaping () -> CFTimeInterval = { CACurrentMediaTime() },
         durationFactor: @escaping () -> Double = { UIView.animationDurationFactor }) {
        self.compiler = compiler
        self.mediaTime = mediaTime
        self.durationFactor = durationFactor
    }

    func transition(view: UIView,
                    to finalFrame: CGRect,
                    animation: ListAnimationSpec) {
        let layer = view.layer
        let currentFrame = layer.presentation()?.frame ?? layer.frame
        transition(layer: layer,
                   from: currentFrame,
                   to: finalFrame,
                   animation: animation.scaled(by: durationFactor()),
                   at: layer.convertTime(mediaTime(), from: nil))
    }

    func transition(layer: CALayer,
                    from currentFrame: CGRect,
                    to finalFrame: CGRect,
                    animation: ListAnimationSpec,
                    at startTime: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = finalFrame
        CATransaction.commit()

        install(from: currentFrame.midX - finalFrame.midX,
                to: 0,
                property: .positionX,
                animation: animation,
                at: startTime,
                on: layer)
        install(from: currentFrame.midY - finalFrame.midY,
                to: 0,
                property: .positionY,
                animation: animation,
                at: startTime,
                on: layer)
        install(from: currentFrame.width,
                to: finalFrame.width,
                property: .width,
                animation: animation,
                at: startTime,
                on: layer)
        install(from: currentFrame.height,
                to: finalFrame.height,
                property: .height,
                animation: animation,
                at: startTime,
                on: layer)
    }

    private func install(from: CGFloat,
                         to: CGFloat,
                         property: ListAnimatedProperty,
                         animation: ListAnimationSpec,
                         at startTime: CFTimeInterval,
                         on layer: CALayer) {
        guard animation.duration > 0, abs(from - to) > 1e-6 else {
            compiler.remove(property: property, from: layer)
            return
        }

        nextGeneration &+= 1
        let track = ListAnimationTrack(generation: nextGeneration,
                                       from: from,
                                       to: to,
                                       startTime: startTime,
                                       duration: animation.duration,
                                       curve: animation.curve)
        compiler.install(track, property: property, on: layer) { [weak self, weak layer] in
            guard let self, let layer else { return }
            self.complete(property: property,
                          generation: track.generation,
                          on: layer)
        }
    }

    func generation(for property: ListAnimatedProperty, on layer: CALayer) -> UInt64? {
        let key = compiler.animationKey(for: property)
        return (layer.animation(forKey: key)?.value(forKey: "CoreListAnimation.generation")
                as? NSNumber)?.uint64Value
    }

    func complete(property: ListAnimatedProperty,
                  generation: UInt64,
                  on layer: CALayer) {
        guard self.generation(for: property, on: layer) == generation else { return }
        compiler.remove(property: property, from: layer)
    }
}
