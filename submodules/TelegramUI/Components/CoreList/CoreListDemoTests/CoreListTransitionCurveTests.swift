import XCTest
import QuartzCore
@testable import CoreListDemo

final class CoreListTransitionCurveTests: XCTestCase {
    // MARK: - Curve solve

    func testEaseInOutMatchesDisplayBezier() {
        // bezierPoint(0.42, 0, 0.58, 1, x). Values computed from the same Newton solver
        // Display uses; see the design doc's verification table.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.25),
                       0.12916193104731982, accuracy: 1e-12)
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.75),
                       0.87083806895268023, accuracy: 1e-12)
    }

    func testEaseInOutIsSymmetricAboutMidpoint() {
        // Exact, unlike the Float-payload `.custom` equivalents below: `.easeInOut` has no case
        // payload, so its control points are Double literals.
        XCTAssertEqual(CoreListTransition.Animation.Curve.easeInOut.solve(at: 0.5), 0.5,
                       accuracy: 1e-15)
    }

    func testEveryCurveHasExactEndpoints() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            XCTAssertEqual(curve.solve(at: 0), 0, accuracy: 1e-15, "\(curve) at 0")
            XCTAssertEqual(curve.solve(at: 1), 1, accuracy: 1e-15, "\(curve) at 1")
        }
    }

    func testEveryCurveIsMonotonicAndClamps() {
        let curves: [CoreListTransition.Animation.Curve] = [
            .easeInOut, .easeIn, .spring, .linear,
            .custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        ]
        for curve in curves {
            var previous = curve.solve(at: 0)
            for step in 1...200 {
                let value = curve.solve(at: CGFloat(step) / 200.0)
                XCTAssertGreaterThanOrEqual(value, previous - 1e-12, "\(curve) at \(step)")
                previous = value
            }
            // Out-of-range input is clamped, not extrapolated.
            XCTAssertEqual(curve.solve(at: -0.5), 0, accuracy: 1e-15)
            XCTAssertEqual(curve.solve(at: 1.5), 1, accuracy: 1e-15)
        }
    }

    func testLinearIsIdentity() {
        for step in 0...10 {
            let x = CGFloat(step) / 10.0
            XCTAssertEqual(CoreListTransition.Animation.Curve.linear.solve(at: x), x,
                           accuracy: 1e-15)
        }
    }

    // The two curves the old ListAnimationCurve carried are cubic beziers: control-x at 1/3 and 2/3
    // makes x(t) = t identically, so .custom(1/3, 0, 2/3, 1) IS x²(3−2x) and .custom(1/3, 1, 2/3, 1)
    // IS 1−(1−x)³ — the two curves this module used before adopting ComponentTransition's
    // vocabulary. Pinned so the historical claim stays checkable.
    //
    // The identity is exact in real arithmetic but NOT in the enum: `custom` carries Float payloads
    // (matching ComponentTransition), so 1/3 and 2/3 round to float32 and x(t) drifts from t. The
    // realized deviation is at most 1.7e-8 in progress — 4e-7pt on a 25pt extent — which is why
    // these assert at 1e-6 rather than 1e-12. With exact Double control points the deviation is
    // 2.2e-16, so the Float payload is the entire error.
    private static let customBezierFloatTolerance: CGFloat = 1e-6

    func testSmoothstepIsACustomBezierWithinFloatPayloadPrecision() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let smoothstep = x * x * (3 - 2 * x)
            let expected = smoothstep >= 0.997 ? 1.0 : smoothstep
            XCTAssertEqual(curve.solve(at: x), expected,
                           accuracy: Self.customBezierFloatTolerance, "at \(x)")
        }
    }

    func testCubicEaseOutIsACustomBezierWithinFloatPayloadPrecision() {
        let curve = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
        for step in 0...100 {
            let x = CGFloat(step) / 100.0
            let inverse = 1 - x
            let easeOut = 1 - inverse * inverse * inverse
            let expected = easeOut >= 0.997 ? 1.0 : easeOut
            XCTAssertEqual(curve.solve(at: x), expected,
                           accuracy: Self.customBezierFloatTolerance, "at \(x)")
        }
    }

    /// Pins the deviation itself, so a future change that widens it fails loudly.
    func testCustomBezierFloatDeviationStaysBelowOnePartInTenMillion() {
        let smooth = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        let easeOut = CoreListTransition.Animation.Curve.custom(1.0 / 3.0, 1.0, 2.0 / 3.0, 1.0)
        var worst: CGFloat = 0
        for step in 0...1000 {
            let x = CGFloat(step) / 1000.0
            let ss = x * x * (3 - 2 * x)
            let inverse = 1 - x
            let eo = 1 - inverse * inverse * inverse
            worst = max(worst, abs(smooth.solve(at: x) - (ss >= 0.997 ? 1.0 : ss)))
            worst = max(worst, abs(easeOut.solve(at: x) - (eo >= 0.997 ? 1.0 : eo)))
        }
        XCTAssertLessThan(worst, 1e-7, "Float-payload deviation grew; measured \(worst)")
    }

    // MARK: - isImmediate

    func testZeroDurationIsImmediate() {
        XCTAssertTrue(CoreListTransition.immediate.isImmediate)
        XCTAssertTrue(CoreListTransition.easeInOut(duration: 0).isImmediate)
        XCTAssertTrue(CoreListTransition(animation: .curve(duration: -1, curve: .linear))
                        .isImmediate)
        XCTAssertFalse(CoreListTransition.easeInOut(duration: 0.3).isImmediate)
    }

    func testDurationAndCurveAccessors() {
        XCTAssertEqual(CoreListTransition.immediate.duration, 0)
        XCTAssertNil(CoreListTransition.immediate.curve)
        let transition = CoreListTransition.easeInOut(duration: 0.4)
        XCTAssertEqual(transition.duration, 0.4, accuracy: 1e-12)
        XCTAssertEqual(transition.curve, .easeInOut)
    }

    func testScaledMultipliesDurationAndKeepsCurve() {
        let scaled = CoreListTransition.easeInOut(duration: 0.5).scaled(by: 10)
        XCTAssertEqual(scaled.duration, 5, accuracy: 1e-12)
        XCTAssertEqual(scaled.curve, .easeInOut)
        // A negative factor cannot produce a negative duration.
        XCTAssertEqual(CoreListTransition.easeInOut(duration: 0.5).scaled(by: -2).duration, 0)
        // Scaling .none stays .none.
        XCTAssertTrue(CoreListTransition.immediate.scaled(by: 10).isImmediate)
    }

    func testEqualityComparesAnimationAndIgnoresUserData() {
        let a = CoreListTransition.easeInOut(duration: 0.3)
        let b = CoreListTransition.easeInOut(duration: 0.3).withUserData("tag")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, CoreListTransition.easeInOut(duration: 0.4))
        XCTAssertEqual(b.userData(String.self), "tag")
    }

    // MARK: - Executor

    func testImmediateSetterWritesValueAndLeavesNoAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.immediate.setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNil(layer.animation(forKey: "position"))
    }

    func testAnimatedSetterWritesFinalValueAndInstallsAnimation() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 10)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertEqual(layer.position.y, 40, accuracy: 1e-12)
        XCTAssertNotNil(layer.animation(forKey: "position.y"))
    }

    func testSetterEarlyOutsOnEqualTarget() {
        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 40)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 40)
        XCTAssertNil(layer.animation(forKey: "position.y"),
                     "an equal target must not install an animation")
    }

    func testAnimateScalesDurationByAnimationDurationFactor() throws {
        UIView.debugAnimationDurationFactorOverride = 4
        defer { UIView.debugAnimationDurationFactorOverride = nil }
        let layer = CALayer()
        layer.animate(from: 0, to: 1, keyPath: "opacity",
                      duration: 0.25, delay: 0, curve: .linear,
                      removeOnCompletion: true, additive: false)
        let animation = try XCTUnwrap(layer.animation(forKey: "opacity"))
        XCTAssertEqual(animation.duration, 1.0, accuracy: 1e-9)
    }

    func testSetTransformWritesAndAnimates() throws {
        let layer = CALayer()
        let target = CATransform3DMakeRotation(0.5, 0, 0, 1)
        CoreListTransition.immediate.setTransform(layer: layer, transform: target)
        XCTAssertTrue(CATransform3DEqualToTransform(layer.transform, target))
        XCTAssertNil(layer.animation(forKey: "transform"))
    }
}
