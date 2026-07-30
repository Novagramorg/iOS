import XCTest
import CoreGraphics
@testable import CoreListDemo

/// End-to-end regression of the pure ScrollPhysics core against real UIScrollView gestures (recorded
/// touch fixtures). The replay drives the physics from the recorded drag translations + the §4 release
/// velocity, with the first decel step integrating one display frame (analysis §2/§7), then deceleration
/// against the recorded frame timeline. The recognizer reproduction itself is validated in
/// `PanRecognizerTests`; rubber-band per-formula in the test below.
///
/// X-axis is excluded from trajectory assertions: with `contentWidth == boundsWidth` the real view locks
/// X while ScrollAxis rubber-bands it (directional lock unmodeled — out of scope for a vertical list).
final class ScrollPhysicsRegressionTests: XCTestCase {
    private let fixtures = ["slow-drag-release", "medium-flick", "flick-into-bottom", "overscroll-release"]

    private func loadFixture(_ name: String) throws -> GestureRecording {
        let dir = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Fixtures")
        return try JSONDecoder().decode(GestureRecording.self,
                                        from: Data(contentsOf: dir.appendingPathComponent("\(name).json")))
    }

    /// Per-formula: our RubberBand reproduces every captured real `_rubberBandOffsetForOffset:` call.
    func testRubberBandFormulaMatchesCapturedGroundTruth() throws {
        for name in fixtures {
            for s in try loadFixture(name).rubberBandSamples {
                XCTAssertEqual(RubberBand.offset(s.offset, min: s.min, max: s.max, range: s.range),
                               s.out, accuracy: 1e-3, "\(name): rubber-band mismatch for \(s)")
            }
        }
    }

    /// The full replayed contentOffset trajectory matches the recorded real trajectory along Y, per
    /// frame, with NO alignment/seeding shims — drag → release → free-deceleration → edge bounce →
    /// spring-back, all within a few px. (Bounds reflect measured residuals: sub-pixel rounding + the
    /// recognizer's ~0.3% velocity reproduction; not a sub-px claim.)
    func testReplayedTrajectoryMatchesRecorded() throws {
        let maxY: [String: CGFloat] = [
            "slow-drag-release": 1.0,    // pure drag + short settle
            "medium-flick": 3.0,         // free-deceleration to mid-content
            "flick-into-bottom": 3.0,    // free-decel into the edge + bounce
            "overscroll-release": 4.0,   // spring-back from a deep overscroll
        ]
        for name in fixtures {
            let d = ScrollReplay.maxDivergence(try loadFixture(name))
            XCTAssertLessThanOrEqual(d.y, maxY[name]!, "\(name): Y trajectory divergence \(d.y)")
        }
    }
}
