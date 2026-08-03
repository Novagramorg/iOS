import XCTest
import UIKit
@testable import CoreListDemo

final class PhysicsScrollEngineTests: XCTestCase {

    func test_contentHost_isPlainView() {
        let engine = PhysicsScrollEngine()
        XCTAssertFalse(engine.contentHost is UIScrollView, "host is a plain UIView, not a UIScrollView")
    }

    func test_setOffset_writesOffset_doesNotFireOnScroll() {
        let engine = PhysicsScrollEngine()
        engine.contentHost.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.setOffset(140)
        XCTAssertEqual(engine.offset, 140, accuracy: 0.001)
        XCTAssertEqual(engine.contentHost.bounds.origin.y, 140, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic setOffset must not fire onScroll")
    }

    func test_applyShift_addsToOffset_doesNotFireOnScroll() {
        let engine = PhysicsScrollEngine()
        engine.contentHost.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        engine.setOffset(100)
        var fired: [CGFloat] = []
        engine.onScroll = { fired.append($0) }
        engine.applyShift(25)
        XCTAssertEqual(engine.offset, 125, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty)
    }

    func test_decelerationMode_defaultsToStepped_andIsSelectable() {
        let engine = PhysicsScrollEngine()
        XCTAssertEqual(engine.decelerationMode, .stepped)
        engine.decelerationMode = .keyframe
        XCTAssertEqual(engine.decelerationMode, .keyframe)
    }

    func test_containerOrigin_delegatesToNaturalBase() {
        let engine = PhysicsScrollEngine()
        let h: CGFloat = 600
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), -h, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), -h / 2, accuracy: 0.001)
    }

    // MARK: - Gesture arbitration

    /// A fresh engine plus its host sized like a viewport, and the engine's own pan recognizer.
    private func makeArbitrationFixture() -> (engine: PhysicsScrollEngine, host: UIView, pan: UIGestureRecognizer) {
        let engine = PhysicsScrollEngine()
        let host = engine.contentHost
        host.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        let recognizers = host.gestureRecognizers ?? []
        precondition(recognizers.count == 1, "the engine attaches exactly one recognizer to its host")
        return (engine, host, recognizers[0])
    }

    /// A view under `host` carrying `recognizer` — the shape of any content recognizer in the list.
    @discardableResult
    private func addContentView(with recognizer: UIGestureRecognizer, under host: UIView) -> UIView {
        let content = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        content.addGestureRecognizer(recognizer)
        host.addSubview(content)
        return content
    }

    func test_simultaneity_deniedForNestedScrollViewPan() {
        let f = makeArbitrationFixture()
        let nested = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        f.host.addSubview(nested)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: nested.panGestureRecognizer),
            "an in-bubble scroll view competes for the same drag and must own it exclusively"
        )
    }

    func test_simultaneity_deniedForBareContentPan() {
        let f = makeArbitrationFixture()
        let contentPan = UIPanGestureRecognizer()
        addContentView(with: contentPan, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: contentPan),
            "chat's swipe-to-reply is a bare content pan and must own its drag exclusively"
        )
    }

    func test_simultaneity_deniedForContentTap() {
        let f = makeArbitrationFixture()
        let tap = UITapGestureRecognizer()
        addContentView(with: tap, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: tap),
            "exclusion is what absorbs the stopping tap; a grant here would need a failure dependency to claw it back"
        )
    }

    func test_simultaneity_deniedForPressAndHold() {
        let f = makeArbitrationFixture()
        // Stands in for Display's `ContextGesture` (a plain UIGestureRecognizer subclass), which
        // CoreList cannot import.
        let press = UIGestureRecognizer()
        addContentView(with: press, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: press),
            "granting a press-and-hold and then holding it with a failure dependency is the limbo bug"
        )
    }

    func test_simultaneity_doesNotOverrideAContentRecognizersOwnRefusal() {
        // The lesson of both arbitration bugs. UIKit takes EITHER delegate's yes, so a grant here
        // overrides a refusal that is written in a file this one never mentions — a nested scroll
        // view's UIKit default, or `ContextGesture`'s explicit `is UIPanGestureRecognizer -> false`.
        // Our pan IS a pan, so anything refusing pans is refusing us.
        let f = makeArbitrationFixture()
        let refuser = PanRefusingRecognizer(target: nil, action: nil)
        addContentView(with: refuser, under: f.host)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: refuser),
            "the engine must never grant simultaneity over a content recognizer's own refusal"
        )
    }

    func test_simultaneity_deniedOutsideHost() {
        let f = makeArbitrationFixture()
        let outside = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 60))
        let outsideTap = UITapGestureRecognizer()
        outside.addGestureRecognizer(outsideTap)

        XCTAssertFalse(
            f.engine.gestureRecognizer(f.pan, shouldRecognizeSimultaneouslyWith: outsideTap),
            "the grant is scoped to descendants of host; a sibling or ancestor recognizer gets nothing"
        )
    }

    func test_simultaneity_deniedWhenQueriedForSomeOtherRecognizer() {
        let f = makeArbitrationFixture()
        let tap = UITapGestureRecognizer()
        addContentView(with: tap, under: f.host)
        let unrelated = UIPanGestureRecognizer()

        XCTAssertFalse(
            f.engine.gestureRecognizer(unrelated, shouldRecognizeSimultaneouslyWith: tap),
            "the engine answers only for its own pan"
        )
    }

    func test_engine_declaresNoFailureDependency() {
        // A failure dependency HOLDS a content recognizer in `.possible` until the pan fails, and a
        // pan force-begun on moving content never fails until lift. `ContextGesture` drives its press
        // animation from its own timer + display link, independent of arbitration, so it animated
        // without ever activating. Exclusion fails the recognizer instead, promptly — and
        // `ListViewImpl` declares no such dependency anywhere. Re-adding one brings the limbo back.
        let engine = PhysicsScrollEngine()
        XCTAssertFalse(
            engine.responds(to: #selector(UIGestureRecognizerDelegate
                .gestureRecognizer(_:shouldBeRequiredToFailBy:))),
            "the engine must declare no failure dependency; see the limbo gotcha in CLAUDE.md"
        )
    }

    func test_shouldBegin_defersToATrackingControl() {
        let f = makeArbitrationFixture()
        // With no live touches `pan.location(in: host)` is the origin. The control fills the host, so
        // the hit test finds it wherever inside bounds that lands. If the precondition below ever
        // fails, the location convention changed — fix this geometry, not the implementation.
        let control = StubTrackingControl(frame: f.host.bounds)
        f.host.addSubview(control)
        XCTAssertTrue(f.host.hitTest(f.pan.location(in: f.host), with: nil) is StubTrackingControl,
                      "test geometry: the pan location must hit the stub control")

        control.isTrackingOverride = false
        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan),
                      "a control that is not tracking does not hold the touch")

        control.isTrackingOverride = true
        XCTAssertFalse(f.engine.gestureRecognizerShouldBegin(f.pan),
                       "a tracking UIControl keeps the touch; chat puts real UIButtons in the list")
    }

    func test_shouldBegin_twoTouchBranchPrecedesTheControlBranch() {
        // ListViewScroller checks for a two-touch pan on the same view FIRST and returns from that
        // branch, so a tracking control below is never consulted. `numberOfTouches` is read-only and
        // cannot be faked, so the touch-count answer itself is not assertable — but the ORDER is, and
        // getting it backwards would change behaviour whenever both are present.
        let f = makeArbitrationFixture()
        let control = StubTrackingControl(frame: f.host.bounds)
        control.isTrackingOverride = true
        f.host.addSubview(control)
        XCTAssertFalse(f.engine.gestureRecognizerShouldBegin(f.pan), "control branch alone")

        let twoFinger = UIPanGestureRecognizer()
        twoFinger.minimumNumberOfTouches = 2
        f.host.addGestureRecognizer(twoFinger)

        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan),
                      "the two-touch branch returns before the control branch is reached")
    }

    func test_shouldBegin_allowsByDefault() {
        let f = makeArbitrationFixture()
        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(f.pan))
    }

    func test_shouldBegin_allowsARecognizerThatIsNotOurPan() {
        let f = makeArbitrationFixture()
        let control = StubTrackingControl(frame: f.host.bounds)
        control.isTrackingOverride = true
        f.host.addSubview(control)
        let unrelated = UIPanGestureRecognizer()

        XCTAssertTrue(f.engine.gestureRecognizerShouldBegin(unrelated),
                      "the engine gates only its own pan")
    }
}

/// A `UIControl` whose tracking state can be set, standing in for a chat inline-keyboard button
/// mid-press. `isTracking` is read-only on `UIControl` and cannot otherwise be driven without a
/// real touch stream.
private final class StubTrackingControl: UIControl {
    var isTrackingOverride = false
    override var isTracking: Bool { isTrackingOverride }
}

/// A recognizer whose OWN delegate refuses simultaneity with any pan — the shape of Display's
/// `ContextGesture` (`Display/Source/ContextGesture.swift:66`), which CoreList cannot import.
private final class PanRefusingRecognizer: UIGestureRecognizer {
    private final class RefusePans: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(other is UIPanGestureRecognizer)
        }
    }
    private let refusal = RefusePans()
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        self.delegate = refusal
    }
}
