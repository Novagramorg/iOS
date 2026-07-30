import QuartzCore

final class CoreAnimationCompiler {
    var emitsAnimations: Bool

    init(emitsAnimations: Bool = true) {
        self.emitsAnimations = emitsAnimations
    }

    func animation(for track: ListAnimationTrack,
                   property: ListAnimatedProperty) -> CAAnimation {
        let animation = makeCoreListAnimation(from: track.from,
                                              to: track.to,
                                              keyPath: keyPath(for: property),
                                              curve: track.curve,
                                              springKind: track.springKind,
                                              logicalDuration: track.duration / max(track.durationFactor, .leastNonzeroMagnitude),
                                              durationFactor: track.durationFactor,
                                              additive: isAdditive(property))
        // Model-path properties the shared factory deliberately does not set. `beginTime` is the
        // track's own start, which is in the past on rebind — that is how phase survives.
        animation.beginTime = track.startTime
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.setValue(track.generation, forKey: "CoreListAnimation.generation")
        if property == .viewportOffset || property == .positionX || property == .positionY {
            animation.preferHighRefreshRate()
        }
        return animation
    }

    private func keyPath(for property: ListAnimatedProperty) -> String {
        switch property {
        case .viewportOffset: return "bounds.origin.y"
        case .positionX: return "position.x"
        case .positionY: return "position.y"
        case .width: return "bounds.size.width"
        case .height: return "bounds.size.height"
        case .opacity: return "opacity"
        }
    }

    private func isAdditive(_ property: ListAnimatedProperty) -> Bool {
        switch property {
        case .viewportOffset, .positionX, .positionY: return true
        case .width, .height, .opacity: return false
        }
    }

    func install(_ track: ListAnimationTrack,
                 property: ListAnimatedProperty,
                 on layer: CALayer,
                 completion: (() -> Void)? = nil) {
        guard emitsAnimations else { return }
        let animation = animation(for: track, property: property)
        if let completion {
            animation.setCoreListCompletion { _ in completion() }
        }
        layer.add(animation, forKey: animationKey(for: property))
    }

    func remove(property: ListAnimatedProperty, from layer: CALayer) {
        layer.removeAnimation(forKey: animationKey(for: property))
    }

    func animationKey(for property: ListAnimatedProperty) -> String {
        switch property {
        case .viewportOffset: return "CoreListAnimation.viewportOffset"
        case .positionX: return "CoreListAnimation.positionX"
        case .positionY: return "CoreListAnimation.positionY"
        case .width: return "CoreListAnimation.width"
        case .height: return "CoreListAnimation.height"
        case .opacity: return "CoreListAnimation.opacity"
        }
    }
}
