import UIKit
import LensTransitionRuntime

@available(iOS 26.0, *)
public final class LiquidMorphTransition {
    public init() {}

    public static func sourceVisibilityAssertion(for view: UIView) -> AnyObject? {
        return LTTransitionDriver.visibilityAssertion(for: view) as AnyObject?
    }

    public static var isSupported: Bool {
        return LTTransitionDriver.isSupported()
    }

    public static func sourcePreview(for view: UIView, parameters: UIPreviewParameters, usePresentationTransform: Bool = false) -> UITargetedPreview? {
        guard view.superview != nil, view.window != nil else { return nil }
        // UIKit accounts for an off-center visiblePath and the source transform.
        let preview = UITargetedPreview(view: view, parameters: parameters)
        guard usePresentationTransform else { return preview }
        let transform = view.layer.presentation()?.affineTransform() ?? view.transform
        let target = UIPreviewTarget(container: preview.target.container, center: preview.target.center, transform: transform)
        return preview.retargetedPreview(with: target)
    }

    private var animation: LTTransitionDriver?
    private var generation = 0
    public private(set) var isAnimating = false

    /// A second transition is rejected while one runs, unless `interruptingCurrent` is set:
    /// then it starts at once and UIKit hands it the running morph (the driver passes the
    /// in-flight coordinator as `previousAnimation`). The interrupted transition's completion
    /// still fires, typically together with the new one's, but only the newest transition
    /// clears `isAnimating`.
    @discardableResult
    public func animate(from: UITargetedPreview, to: UITargetedPreview, attachment: CGPoint, in container: UIView, sourceIdentity: UIView? = nil, interruptingCurrent: Bool = false, alongsideAnimations: (() -> Void)? = nil, completion: @escaping () -> Void) -> Bool {
        assert(Thread.isMainThread)
        guard !isAnimating || interruptingCurrent, Self.isSupported, container.window != nil,
              from.target.container.window != nil, to.target.container.window != nil,
              from.view.window != nil, to.view.window != nil,
              from.size.width > 0, from.size.height > 0, to.size.width > 0, to.size.height > 0,
              from.size.width.isFinite, from.size.height.isFinite, to.size.width.isFinite, to.size.height.isFinite,
              attachment.x.isFinite, attachment.y.isFinite else { return false }
        let pivot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        pivot.layer.cornerRadius = 5
        pivot.overrideUserInterfaceStyle = container.traitCollection.userInterfaceStyle
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        let through = UITargetedPreview(view: pivot, parameters: parameters, target: UIPreviewTarget(container: container, center: attachment))
        guard let animation = LTTransitionDriver(source: from, destination: to, pivot: through, container: container, sourceIdentity: sourceIdentity, alongside: alongsideAnimations) else { return false }
        isAnimating = true
        self.animation = animation
        generation += 1
        let transitionGeneration = generation
        let finished = { [self] in
            // UIKit calls our completion before its own cleanup. Hand views back only
            // after that cleanup, keeping the coordinator alive through the callback.
            DispatchQueue.main.async { [self, animation] in
                withExtendedLifetime(animation) {
                    if self.generation == transitionGeneration {
                        self.animation = nil
                        self.isAnimating = false
                    }
                    completion()
                }
            }
        }
        animation.start(completion: finished)
        return true
    }
}
