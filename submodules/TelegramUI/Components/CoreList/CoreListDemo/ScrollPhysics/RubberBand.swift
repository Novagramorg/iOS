import CoreGraphics

/// UIScrollView's overscroll ("rubber-band") offset. See analysis doc §1.
/// `range` is the visible bounds dimension; `c` is the rubber-band coefficient (0.55 default).
enum RubberBand {
    /// Rubber-band coefficient for DIRECT (touch) overscroll — UIScrollView's standard 0.55
    /// (validated to machine precision against captured `_rubberBandOffsetForOffset:` ground truth).
    static let touchCoefficient: CGFloat = 0.55
    /// Rubber-band coefficient for INDIRECT (trackpad / continuous indirect-scroll) overscroll —
    /// fit to exactly 0.715 from the same captured ground truth (min==median==max over 70 samples;
    /// trackpad overscroll is looser than touch). See `docs/plans/2026-05-25-trackpad-scroll-design.md`.
    static let trackpadCoefficient: CGFloat = 0.715

    static func offset(_ x: CGFloat, min lo: CGFloat, max hi0: CGFloat,
                       range: CGFloat, c: CGFloat = touchCoefficient) -> CGFloat {
        let hi = Swift.max(hi0, lo)                 // max forced ≥ min, per §1
        guard abs(range) >= .ulpOfOne else { return x }
        if x > hi {
            let d = x - hi
            return hi + range * (1 - 1 / (1 + c * d / range))
        } else if x < lo {
            let d = lo - x
            return lo - range * (1 - 1 / (1 + c * d / range))
        } else {
            return x
        }
    }
}
