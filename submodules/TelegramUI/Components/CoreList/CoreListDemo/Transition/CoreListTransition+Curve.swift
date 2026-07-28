import CoreGraphics

// Cubic-bezier solver copied from Display/Source/Spring.swift so CoreList stays dependency-free.
// Do not "improve" the algorithm: ComponentFlow's curves are defined by exactly these four Newton
// iterations and the 0.997 clamp, and CoreList's parity with them depends on matching it.

private func bezierA(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 1.0 - 3.0 * a2 + 3.0 * a1 }
private func bezierB(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat { 3.0 * a2 - 6.0 * a1 }
private func bezierC(_ a1: CGFloat) -> CGFloat { 3.0 * a1 }

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    ((bezierA(a1, a2) * t + bezierB(a1, a2)) * t + bezierC(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat {
    3.0 * bezierA(a1, a2) * t * t + 2.0 * bezierB(a1, a2) * t + bezierC(a1)
}

private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    var i = 0
    while i < 4 {
        let currentSlope = calcSlope(t, x1, x2)
        if currentSlope == 0.0 { return t }
        t -= (calcBezier(t, x1, x2) - x) / currentSlope
        i += 1
    }
    return t
}

func coreListBezierPoint(_ x1: CGFloat, _ y1: CGFloat,
                         _ x2: CGFloat, _ y2: CGFloat,
                         _ x: CGFloat) -> CGFloat {
    var value = calcBezier(getTForX(x, x1, x2), y1, y2)
    if value >= 0.997 { value = 1.0 }
    return value
}

public extension CoreListTransition.Animation.Curve {
    /// Progress at unit phase `offset`. Mirrors `ComponentTransition.Animation.Curve.solve(at:)`.
    ///
    /// `.spring` uses Display's own pre-iOS-9 bezier fallback rather than the private
    /// `springAnimationValueAt`, and `.bounce` is not a unit curve at all — ComponentFlow's own
    /// `solve` asserts on it and routes to private spring API instead. Both are documented
    /// approximations; CoreList adopts neither as a default.
    func solve(at offset: CGFloat) -> CGFloat {
        let x = min(max(offset, 0.0), 1.0)
        switch self {
        case .easeInOut:
            return coreListBezierPoint(0.42, 0.0, 0.58, 1.0, x)
        case .easeIn:
            return coreListBezierPoint(0.42, 0.0, 1.0, 1.0, x)
        case .spring:
            return coreListBezierPoint(0.23, 1.0, 0.32, 1.0, x)
        case .linear:
            // Identity must stay identity — no 0.997 clamp here, matching
            // `listViewAnimationCurveLinear`.
            return x
        case let .custom(c1x, c1y, c2x, c2y):
            return coreListBezierPoint(CGFloat(c1x), CGFloat(c1y), CGFloat(c2x), CGFloat(c2y), x)
        case .bounce:
            assertionFailure("`.bounce` is not a unit curve; CoreList samples `.spring` instead")
            return coreListBezierPoint(0.23, 1.0, 0.32, 1.0, x)
        }
    }
}
