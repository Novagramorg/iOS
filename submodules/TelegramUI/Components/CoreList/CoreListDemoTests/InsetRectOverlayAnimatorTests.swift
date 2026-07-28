import XCTest
import QuartzCore
@testable import CoreListDemo

final class InsetRectOverlayAnimatorTests: XCTestCase {
    private func animation(_ property: ListAnimatedProperty,
                           on layer: CALayer) throws -> CAKeyframeAnimation {
        let key = CoreAnimationCompiler().animationKey(for: property)
        return try XCTUnwrap(layer.animation(forKey: key) as? CAKeyframeAnimation)
    }

    private func values(_ animation: CAKeyframeAnimation) throws -> [NSNumber] {
        try XCTUnwrap(animation.values as? [NSNumber])
    }

    func testTransitionCompilesAdditivePositionAndAbsoluteExtentTracks() throws {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        let animator = InsetRectOverlayAnimator()

        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 0, width: 100, height: 200),
                            to: CGRect(x: 30, y: 20, width: 80, height: 140),
                            transition: .easeInOut(duration: 0.5),
                            at: 3)

        XCTAssertEqual(layer.frame, CGRect(x: 30, y: 20, width: 80, height: 140))
        let x = try animation(.positionX, on: layer)
        let y = try animation(.positionY, on: layer)
        let width = try animation(.width, on: layer)
        let height = try animation(.height, on: layer)
        XCTAssertTrue(x.isAdditive)
        XCTAssertTrue(y.isAdditive)
        XCTAssertFalse(width.isAdditive)
        XCTAssertFalse(height.isAdditive)
        for track in [x, y, width, height] {
            XCTAssertEqual(track.beginTime, 3, accuracy: 1e-9)
            XCTAssertEqual(track.duration, 0.5, accuracy: 1e-9)
        }
        XCTAssertEqual(try XCTUnwrap(try values(x).first).doubleValue, -20, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(y).first).doubleValue, 10, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(width).first).doubleValue, 100, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(height).first).doubleValue, 200, accuracy: 1e-6)
        let xValues = try values(x)
        // Sampled at QUARTER phase, not the midpoint. This assertion exists to prove the compiler
        // samples the track's curve rather than interpolating linearly, and `.easeInOut` is
        // symmetric about (0.5, 0.5) — so its midpoint sample equals the linear one exactly and
        // cannot distinguish the two. easeInOut(0.25) = 0.12916193104731982, against linear's 0.25.
        XCTAssertEqual(xValues[xValues.count / 4].doubleValue, -17.416761379053604, accuracy: 1e-6,
                       "the quarter point must use the track's curve, not linear interpolation")
        XCTAssertEqual(xValues[xValues.count / 2].doubleValue, -10.0, accuracy: 1e-6,
                       "easeInOut is symmetric, so its midpoint is exactly halfway")
    }

    func testReplacementStartsFromSampledPresentationAndRejectsStaleCompletion() throws {
        let layer = CALayer()
        let animator = InsetRectOverlayAnimator()
        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 0, width: 100, height: 200),
                            to: CGRect(x: 0, y: 100, width: 100, height: 100),
                            transition: .easeInOut(duration: 0.5),
                            at: 1)
        let first = try XCTUnwrap(animator.generation(for: .positionY, on: layer))

        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 40, width: 100, height: 160),
                            to: CGRect(x: 0, y: 0, width: 100, height: 200),
                            transition: .easeInOut(duration: 0.5),
                            at: 1.2)

        let replacement = try XCTUnwrap(animator.generation(for: .positionY, on: layer))
        XCTAssertNotEqual(replacement, first)
        let y = try animation(.positionY, on: layer)
        XCTAssertEqual(try XCTUnwrap(try values(y).first).doubleValue, 20, accuracy: 1e-6)
        XCTAssertEqual(y.beginTime, 1.2, accuracy: 1e-9)

        animator.complete(property: .positionY, generation: first, on: layer)
        XCTAssertEqual(animator.generation(for: .positionY, on: layer), replacement)
    }

    func testViewTransitionScalesDurationExactlyOnce() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 500))
        let animator = InsetRectOverlayAnimator(
            mediaTime: { 2 },
            durationFactor: { 10 }
        )

        animator.transition(view: view,
                            to: CGRect(x: 0, y: 300, width: 100, height: 200),
                            transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(try animation(.positionY, on: view.layer).duration, 5, accuracy: 1e-9)
        XCTAssertEqual(try animation(.height, on: view.layer).duration, 5, accuracy: 1e-9)
    }
}
