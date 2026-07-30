import CoreGraphics
import Foundation // pow, exp

/// UIScrollView deceleration stepper. See analysis doc §2.
/// `offset`/`velocity` are mutated in place; `velocity` is points/millisecond.
/// `rate` is the per-ms deceleration factor and must be in (0, 1) — 0.998 normal,
/// 0.99 fast (it divides `1 - rate`, so `rate == 1` would produce NaN).
struct Deceleration {
    var offset: CGFloat
    var velocity: CGFloat
    let min: CGFloat
    let max: CGFloat
    let rate: CGFloat
    let vScale: CGFloat

    private static let velocityFloor: CGFloat = 0.01      // pts/ms (§5/§2)
    private static let settleTolerance: CGFloat = 0.5     // px (§2)
    private static let bounceLnRate: CGFloat = -0.01005033585350145 // ln(0.99), fixed spring stiffness (§2)

    static func decay(dtMs: CGFloat, rate: CGFloat) -> CGFloat { pow(rate, dtMs) }

    /// Advance one frame. Returns `true` when the scroll has settled (the driver should stop).
    mutating func step(dtMs: CGFloat) -> Bool {
        guard dtMs > 0 else { return settled() }
        let hi = Swift.max(max, min)
        let lo = min

        if offset >= lo, offset <= hi {
            // §2-A: in-bounds free deceleration
            guard velocity != 0 else { return settled() }
            let decay = Self.decay(dtMs: dtMs, rate: rate)
            let dx = velocity * rate * (1 - decay) / (1 - rate) * vScale
            let proposed = offset + dx
            if proposed >= lo, proposed <= hi {
                offset = proposed
                velocity *= decay
                return settled()
            }
            // crosses an edge mid-frame: integrate to the edge, hand the remainder to the spring
            let edge = proposed > hi ? hi : lo
            let frac = (edge - offset) / (proposed - offset)        // distance-proportional time
            let timeToBound = dtMs * frac
            let decayE = Self.decay(dtMs: timeToBound, rate: rate)
            offset += velocity * rate * (1 - decayE) / (1 - rate) * vScale // ≈ edge (frac approximates time, per §2)
            velocity *= decayE
            spring(dtMs: dtMs - timeToBound)
            return settled()
        } else {
            // §2-B: overscrolled — spring toward the crossed edge
            spring(dtMs: dtMs)
            return settled()
        }
    }

    private mutating func spring(dtMs: CGFloat) {
        guard dtMs > 0 else { return }
        let hi = Swift.max(max, min)
        let edge = offset < min ? min : hi
        let springK = exp(Self.bounceLnRate * dtMs)         // fixed 0.99/ms stiffness
        let decayRem = Self.decay(dtMs: dtMs, rate: rate)
        offset = edge + springK * (offset - edge)
        offset += velocity * rate * springK * (1 - decayRem) / (1 - rate) * vScale
        velocity *= decayRem * springK
    }

    private func settled() -> Bool {
        let hi = Swift.max(max, min)
        let slow = abs(velocity) < Self.velocityFloor
        if offset >= min, offset <= hi { return slow }       // in bounds: settled once velocity dies
        let nearEdge = abs(offset - min) <= Self.settleTolerance
            || abs(offset - hi) <= Self.settleTolerance
        return slow && nearEdge
    }
}
