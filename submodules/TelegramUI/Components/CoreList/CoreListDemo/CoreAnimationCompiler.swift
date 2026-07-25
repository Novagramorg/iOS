import QuartzCore

final class CoreAnimationCompiler {
    let samplesPerSecond: Double
    var emitsAnimations: Bool

    init(samplesPerSecond: Double = 240, emitsAnimations: Bool = true) {
        self.samplesPerSecond = samplesPerSecond
        self.emitsAnimations = emitsAnimations
    }

    func animation(for track: ListAnimationTrack,
                   property: ListAnimatedProperty) -> CAAnimation {
        let sampleCount = max(2, Int(ceil(track.duration * samplesPerSecond)) + 1)
        let lastIndex = sampleCount - 1
        var values: [NSNumber] = []
        var keyTimes: [NSNumber] = []
        values.reserveCapacity(sampleCount)
        keyTimes.reserveCapacity(sampleCount)

        for index in 0...lastIndex {
            let phase = Double(index) / Double(lastIndex)
            let time = track.startTime + phase * track.duration
            values.append(NSNumber(value: Double(track.value(at: time))))
            keyTimes.append(NSNumber(value: phase))
        }

        let animation: CAKeyframeAnimation
        switch property {
        case .viewportOffset:
            animation = CAKeyframeAnimation(keyPath: "bounds.origin.y")
            animation.isAdditive = true
        case .positionX:
            animation = CAKeyframeAnimation(keyPath: "position.x")
            animation.isAdditive = true
        case .positionY:
            animation = CAKeyframeAnimation(keyPath: "position.y")
            animation.isAdditive = true
        case .width:
            animation = CAKeyframeAnimation(keyPath: "bounds.size.width")
            animation.isAdditive = false
        case .height:
            animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
            animation.isAdditive = false
        case .opacity:
            animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.isAdditive = false
        }
        animation.values = values
        animation.keyTimes = keyTimes
        animation.calculationMode = .linear
        animation.beginTime = track.startTime
        animation.duration = track.duration
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.setValue(track.generation, forKey: "CoreListAnimation.generation")
        if property == .viewportOffset || property == .positionX || property == .positionY {
            animation.preferHighRefreshRate()
        }
        return animation
    }

    func install(_ track: ListAnimationTrack,
                 property: ListAnimatedProperty,
                 on layer: CALayer,
                 completion: (() -> Void)? = nil) {
        guard emitsAnimations else { return }
        let animation = animation(for: track, property: property)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        layer.add(animation, forKey: animationKey(for: property))
        CATransaction.commit()
    }

    func remove(property: ListAnimatedProperty, from layer: CALayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: animationKey(for: property))
        CATransaction.commit()
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
