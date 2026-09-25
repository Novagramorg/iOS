import Foundation
import simd

// MARK: - Motion and interaction

struct DiamondMotion {
    private struct TapRotation {
        var velocity: Float
        var boost: Float
        let decayTime: Float
        let responseTime: Float
        let isFast: Bool

        mutating func step(dt: Float, speed: Float) -> Float {
            let previousVelocity = velocity
            boost *= exp(-dt / decayTime)
            let targetVelocity = speed + boost
            velocity += (targetVelocity - velocity) * (1 - exp(-dt / responseTime))
            if abs(boost) < 0.001 && abs(velocity - speed) < 0.001 {
                boost = 0
                velocity = speed
            }
            return (previousVelocity + velocity) * 0.5 * dt
        }
    }

    static let referencePitch: Float = -0.09
    private static let pitchLimit: Float = 1.1
    private static let springFrequency: Float = 3 * 2 * .pi
    private static let springDamping: Float = 0.8
    private static let tapUnlockSpeedMultiplier: Float = 1.4

    private(set) var yaw: Float = 0
    private(set) var pitch: Float = Self.referencePitch
    private(set) var isDragging = false
    var zoom: Float = 1

    private var targetYaw: Float = 0
    private var targetPitch: Float = Self.referencePitch
    private var rawPitchOffset: Float = 0
    private var yawSpringVelocity: Float = 0
    private var pitchSpringVelocity: Float = 0
    private var yawVelocity: Float = 0
    private var lastDragTime: Double = 0
    private var timeSinceRelease: Float = 10
    private var tapRotation: TapRotation?
    private var entranceInterrupted = false

    mutating func tap(direction: Float, speed: Float, mode: DiamondStyle.AnimationMode, time: Float) -> Bool? {
        guard !isDragging else { return nil }
        let tapUnlockSpeed = abs(speed) * Self.tapUnlockSpeedMultiplier
        let triggersBurst: Bool
        if let tapRotation {
            let remainingBoost = max(abs(tapRotation.boost), abs(tapRotation.velocity - speed))
            // Check the target too, so taps stay locked while the fast spin is accelerating.
            let fastSpinSpeed = max(abs(tapRotation.velocity), abs(speed + tapRotation.boost))
            if tapRotation.isFast && fastSpinSpeed > tapUnlockSpeed {
                return nil
            }
            triggersBurst = !tapRotation.isFast && remainingBoost > 0.12
        } else {
            if mode == .entrance && !entranceInterrupted && speed != 0 {
                let remainingBoost = DiamondEntrance.spinBoost * exp(-max(0, time) / DiamondEntrance.spinDecay)
                if abs(speed) + remainingBoost > tapUnlockSpeed {
                    return nil
                }
            }
            triggersBurst = false
        }
        let interval: Float = 1 / 120
        let currentVelocity = tapRotation?.velocity
            ?? automaticTravel(from: time, to: time + interval, speed: speed, mode: mode) / interval * min(timeSinceRelease / 0.75, 1)
        startRotation(direction: direction, velocity: currentVelocity + yawVelocity, isFast: triggersBurst)
        return triggersBurst
    }

    mutating func fling(direction: Float) {
        guard !isDragging else { return }
        let currentVelocity = yawSpringVelocity
        targetYaw = yaw
        yawSpringVelocity = 0
        startRotation(direction: direction, velocity: currentVelocity, isFast: true)
    }

    private mutating func startRotation(direction: Float, velocity: Float, isFast: Bool) {
        tapRotation = TapRotation(
            velocity: velocity,
            boost: direction * (isFast ? DiamondEntrance.spinBoost : 3.36),
            decayTime: isFast ? DiamondEntrance.spinDecay : 0.85,
            responseTime: isFast ? 0.08 : 0.16,
            isFast: isFast
        )
        entranceInterrupted = true
        yawVelocity = 0
        timeSinceRelease = 0.75
    }

    mutating func begin(at time: Double) {
        isDragging = true
        tapRotation = nil
        targetYaw = yaw
        targetPitch = pitch
        let offset = min(Self.pitchLimit - 0.001, max(-Self.pitchLimit + 0.001, pitch - Self.referencePitch))
        rawPitchOffset = offset / (1 - abs(offset) / Self.pitchLimit)
        yawSpringVelocity = 0
        pitchSpringVelocity = 0
        yawVelocity = 0
        lastDragTime = time
    }

    mutating func drag(dx: Float, dy: Float, scale: Float, at time: Double) {
        guard isDragging else { return }
        let sensitivity = Float.pi / max(scale, 100)
        let deltaYaw = dx * sensitivity
        targetYaw += deltaYaw
        rawPitchOffset += dy * sensitivity
        targetPitch = Self.referencePitch + rawPitchOffset / (1 + abs(rawPitchOffset) / Self.pitchLimit)
        let dt = Float(max(1.0 / 240, min(time - lastDragTime, 0.1)))
        yawVelocity = min(5, max(-5, deltaYaw / dt))
        lastDragTime = time
    }

    mutating func end(at time: Double, cancelled: Bool = false) {
        isDragging = false
        timeSinceRelease = 0
        targetPitch = Self.referencePitch
        if cancelled || time - lastDragTime > 0.12 {
            yawVelocity = 0
        }
        if cancelled {
            targetYaw = yaw
            yawSpringVelocity = 0
            pitchSpringVelocity = 0
        }
    }

    mutating func step(dt: Float, speed: Float, reduceMotion: Bool,
                       mode: DiamondStyle.AnimationMode = .continuous, time: Float = 0) {
        let dt = min(max(dt, 0), 0.05)
        if reduceMotion {
            tapRotation = nil
            if isDragging {
                yaw = targetYaw
                pitch = targetPitch
            } else {
                targetYaw = yaw
                pitch = Self.referencePitch
                targetPitch = pitch
            }
            yawSpringVelocity = 0
            pitchSpringVelocity = 0
            yawVelocity = 0
            return
        }

        var remaining = dt
        while remaining > 0 {
            let step = min(remaining, 1 / Float(120))
            let stepTime = max(0, time - remaining + step)
            if !isDragging {
                timeSinceRelease += step
                let decay = exp(-4.2 * step)
                targetYaw += yawVelocity * (1 - decay) / 4.2
                yawVelocity *= decay

                let automaticTravel: Float
                if var tapRotation = self.tapRotation {
                    automaticTravel = tapRotation.step(dt: step, speed: speed)
                    self.tapRotation = tapRotation
                } else {
                    automaticTravel = self.automaticTravel(from: max(0, stepTime - step), to: stepTime, speed: speed, mode: mode)
                }
                let travel = automaticTravel * min(timeSinceRelease / 0.75, 1)
                targetYaw += travel
                yaw += travel
            }

            let stiffness = Self.springFrequency * Self.springFrequency
            let damping = 2 * Self.springDamping * Self.springFrequency
            yawSpringVelocity += ((targetYaw - yaw) * stiffness - damping * yawSpringVelocity) * step
            pitchSpringVelocity += ((targetPitch - pitch) * stiffness - damping * pitchSpringVelocity) * step
            yaw += yawSpringVelocity * step
            pitch += pitchSpringVelocity * step
            remaining = max(0, remaining - step)
        }

        let fullTurns = (yaw / (2 * .pi)).rounded(.towardZero)
        yaw -= fullTurns * 2 * .pi
        targetYaw -= fullTurns * 2 * .pi
        if !isDragging && abs(pitch - Self.referencePitch) < 0.0001 && abs(pitchSpringVelocity) < 0.0001 {
            pitch = Self.referencePitch
            pitchSpringVelocity = 0
        }
    }

    private func automaticTravel(from start: Float, to end: Float, speed: Float, mode: DiamondStyle.AnimationMode) -> Float {
        switch mode {
        case .entrance:
            return entranceInterrupted ? speed * (end - start) : DiamondEntrance.angularTravel(from: start, to: end, speed: speed)
        case .continuous:
            return speed * (end - start)
        case .reference:
            return speed == 0 ? 0 : Self.referenceYaw(time: end) - Self.referenceYaw(time: start)
        }
    }

    private static func referenceYaw(time: Float) -> Float {
        let frame = max(0, time * 60).truncatingRemainder(dividingBy: 180)
        let times: [Float] = [0, 39, 69, 99, 179]
        let angles: [Float] = [0, -0.34, 0, 0.33, 0]
        let index = frame < 39 ? 0 : (frame < 69 ? 1 : (frame < 99 ? 2 : 3))
        let progress = min(1, (frame - times[index]) / (times[index + 1] - times[index]))
        let out = index == 2 ? SIMD2<Float>(0.167, 0.167) : SIMD2<Float>(0.5, 0)
        let into = index == 1 ? SIMD2<Float>(0.833, 0.833) : SIMD2<Float>(0.5, 1)
        let t = DiamondSparkleAnimation.easing(progress, out: out, in: into)
        return angles[index] + (angles[index + 1] - angles[index]) * t
    }
}

// MARK: - Entrance timing

struct DiamondStarBurst {
    // Matches the maximum lifetime in backgroundStarVertex, including its duration scale.
    static let lifetime: Float = 6.4
    let startTime: Float
    let seed: UInt32
}

enum DiamondEntrance {
    static let spinBoost: Float = 12.6
    static let spinDecay: Float = 0.95 / 1.4
    static let steadyStarCount = 240
    static let burstStarCount = 144

    static func extraAngle(at time: Float) -> Float {
        spinBoost * spinDecay * (1 - exp(-max(0, time) / spinDecay))
    }

    static func angularTravel(from start: Float, to end: Float, speed: Float) -> Float {
        guard speed != 0 else { return 0 }
        return speed * max(0, end-start)
            + (speed > 0 ? 1 : -1) * (extraAngle(at:end)-extraAngle(at:start))
    }

    static func highlightTime(at time: Float, entrance: Bool) -> Float {
        let time = max(0, time)
        return entrance ? time + 4 * spinDecay * (1 - exp(-time / spinDecay)) : time
    }

    static func particleTime(at time: Float, entrance: Bool) -> Float {
        let time = max(0,time)
        return entrance ? time + 2.2 * (1-exp(-time)) : time
    }
}

// MARK: - Facet lighting

enum DiamondLightAnimation {
    private static let facetSweepSpeed: Float = 0.5

    struct State {
        var crown: SIMD4<Float>
        var pavilion: SIMD4<Float>
        var sweep: SIMD4<Float>
        var crownSweep: SIMD4<Float>
        var rightCrownSweep: SIMD4<Float>
        var leftCrownSweep: SIMD4<Float>
        var pavilionSweep: SIMD4<Float>
        var rightPavilionSweep: SIMD4<Float>
        var leftPavilionSweep: SIMD4<Float>
    }

    static func state(time: Float) -> State {
        let frame = max(0, time * 60).truncatingRemainder(dividingBy: 180)
        let sweepFrame = max(0, time * 60 * facetSweepSpeed).truncatingRemainder(dividingBy: 180)
        let times: [Float] = [0, 39, 99, 179]
        let crown: [SIMD4<Float>] = [
            SIMD4(-53.8, 112.9, 50.5, -54.2), SIMD4(12, 53.4, 143.3, -112.9),
            SIMD4(-126.9, 168.8, 190.3, -192.8), SIMD4(-53.8, 112.9, 50.5, -54.2)]
        let pavilion: [SIMD4<Float>] = [
            SIMD4(-53.8, 80.7, 10.8, -165.2), SIMD4(-34.2, 23.1, 104.6, -191),
            SIMD4(-147.9, 125.5, -9.9, -106.1), SIMD4(-53.8, 80.7, 10.8, -165.2)]
        let sweep: [Float] = [-0.05, 0.84, -0.88, -0.05]
        let segment = frame < 39 ? 0 : (frame < 99 ? 1 : 2)
        let progress = min(1, max(0, (frame - times[segment]) / (times[segment+1] - times[segment])))
        let t = easing(progress)
        let transmission: Float
        if frame < 25 { transmission = 0.45 * frame / 25 }
        else if frame < 142 { transmission = 0.45 }
        else { transmission = 0.45 * max(0, (166-frame)/24) }
        return State(crown: simd_mix(crown[segment], crown[segment+1], SIMD4(repeating: t)),
                     pavilion: simd_mix(pavilion[segment], pavilion[segment+1], SIMD4(repeating: t)),
                     sweep: SIMD4(sweep[segment] + (sweep[segment+1] - sweep[segment]) * t,
                                  frame / 180 * 2 * .pi, transmission, 0),
                     crownSweep: facetSweep(sweepFrame, times: [11,49,127,179]),
                     rightCrownSweep: facetSweep(sweepFrame, times: [6,44,88]),
                     leftCrownSweep: facetSweep(sweepFrame, times: [0,38,118,167]),
                     pavilionSweep: facetSweep(sweepFrame, times: [0,38,103,163]),
                     rightPavilionSweep: facetSweep(sweepFrame, times: [5,43,92]),
                     leftPavilionSweep: facetSweep(sweepFrame, times: [0,38,112,168]))
    }

    private static func facetSweep(_ frame: Float, times: [Float]) -> SIMD4<Float> {
        let a = SIMD4<Float>(-115.8,40.3,-279.3,240.6)
        let b = SIMD4<Float>(317,-341.9,188,-131.9)
        for i in 1..<times.count where frame < times[i] {
            let progress = (frame-times[i-1]) / (times[i]-times[i-1])
            let t = DiamondSparkleAnimation.easing(progress, out: SIMD2(0.333,0), in: SIMD2(0.667,1))
            return simd_mix(i % 2 == 1 ? a : b, i % 2 == 1 ? b : a, SIMD4(repeating:t))
        }
        return times.count % 2 == 0 ? b : a
    }

    private static func easing(_ x: Float) -> Float {
        if x == 0 || x == 1 { return x }
        var low: Float = 0, high: Float = 1
        for _ in 0..<16 {
            let t = (low + high) * 0.5, s = 1 - t
            let bx = 1.5*s*s*t + 1.5*s*t*t + t*t*t
            if bx < x { low = t } else { high = t }
        }
        let t = (low + high) * 0.5
        return t*t*(3 - 2*t)
    }
}

// MARK: - Surface sparkles

enum DiamondSparkleAnimation {
    struct State {
        var shape: SIMD4<Float>
        var haloScale: Float
    }

    static func state(time: Float) -> State {
        let frame = max(0, time * 60).truncatingRemainder(dividingBy: 180)
        let scale: Float
        if frame < 33 {
            scale = 1 - easing(frame / 33, out: SIMD2(0.333, 0), in: SIMD2(0.833, 0.833))
        } else if frame < 129 {
            scale = 0
        } else {
            scale = easing((frame - 129) / 50, out: SIMD2(0.167, 0.167), in: SIMD2(0.4, 1))
        }
        let morph: Float
        if frame < 18 {
            morph = easing(frame / 18, out: SIMD2(0.167, 0.167), in: SIMD2(0.667, 1))
        } else if frame < 151 {
            morph = 1
        } else {
            morph = 1 - easing((frame - 151) / 28, out: SIMD2(0.167, 0.167), in: SIMD2(0.4, 1))
        }
        return State(shape: SIMD4(scale, morph, groupScale(frame: frame), groupScale(frame: frame - 4)),
                     haloScale: groupScale(frame: frame - 8))
    }

    struct MainPlacement {
        var angle: Float
        var height: Float
        var visibility: Float
    }

    static func mainPlacement(model: simd_float4x4, angularSpeed: Float = 0) -> MainPlacement {
        let pitch = DiamondMotion.referencePitch
        let referenceFront = SIMD4<Float>(0, -sin(pitch), cos(pitch), 0)
        var bestFacing: Float = -1
        var faceAngle: Float = 0
        for face in 0..<4 {
            let angle = Float(face) * .pi / 2
            let forward = model * SIMD4<Float>(sin(angle), 0, cos(angle), 0)
            let facing = simd_dot(forward, referenceFront)
            if facing > bestFacing { bestFacing = facing; faceAngle = angle }
        }
        let limit = Float.pi * 12 / 180
        let angle = acos(min(1, max(-1, bestFacing)))
        let facing = smoothstep(1 - angle / limit)
        let crossingDuration = 2 * limit / max(abs(angularSpeed), 0.001)
        let duration = smoothstep((crossingDuration - 0.06) / 0.34)
        let authoringToWorld: Float = 2 / 447.9
        return MainPlacement(angle: faceAngle + atan2(56.5 * authoringToWorld, 1),
                             height: 0.018, visibility: facing * duration)
    }

    private static func smoothstep(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func groupScale(frame: Float) -> Float {
        let times: [Float] = [0, 18, 35, 50, 65, 90, 105, 120, 135, 171]
        let values: [Float] = [1, 1, 0.8, 1, 0.8, 1, 0.8, 1, 0.8, 1]
        for i in 1..<times.count where frame < times[i] {
            let t = easing((frame - times[i-1]) / (times[i] - times[i-1]),
                           out: SIMD2(0.333, 0), in: SIMD2(0.667, 1))
            return values[i-1] + (values[i] - values[i-1]) * t
        }
        return 1
    }

    static func easing(_ progress: Float, out a: SIMD2<Float>, in b: SIMD2<Float>) -> Float {
        let x = min(1, max(0, progress))
        if x == 0 || x == 1 { return x }
        var low: Float = 0, high: Float = 1
        for _ in 0..<18 {
            let t = (low + high) * 0.5, s = 1 - t
            let bx = 3*s*s*t*a.x + 3*s*t*t*b.x + t*t*t
            if bx < x { low = t } else { high = t }
        }
        let t = (low + high) * 0.5, s = 1 - t
        return 3*s*s*t*a.y + 3*s*t*t*b.y + t*t*t
    }
}
