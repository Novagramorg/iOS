import XCTest
import UIKit
@testable import CoreListDemo

/// A new animation's `from` must be the value the layer is CURRENTLY RENDERING, not the model's
/// analytic value at the pass clock. The two differ by the producing pass's commit delay, which is
/// invisible while one authority owns a layer and becomes a visible drift the moment two do — the
/// chat's hosted item node reads `presentation()` for its own box while the row read the model.
///
/// Measured on device before this change: one-signed, compounding, up to 3.2pt.
final class PresentationResumeSamplingTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)

    // MARK: - The assumption everything else rests on

    /// The existing 819 tests keep their exact model-vs-CA assertions only because they never resolve
    /// a presentation layer, so `presentedValueProvider` returns nil and they stay on the analytic
    /// path. `ListAnimationController.swift:578` records that as measured; this pins it, so a future
    /// harness change that starts committing cannot silently move the whole suite onto the presented
    /// path and quietly weaken every one of those assertions.
    func testFixtureLayersHaveNoPresentationLayer() throws {
        let fixture = VirtualListFixture(itemCount: 22, itemHeight: 50, viewport: viewport)
        var items = fixture.listView.items
        items.removeFirst()
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        XCTAssertTrue(fixture.hasActiveAnimations,
                      "precondition: an animation is in flight, so a presentation layer would exist")
        // Every layer the provider could be asked about: the rows, and the scroll view that carries
        // the viewport track.
        var layers = fixture.activeWindow.items.map(\.view.layer)
        layers.append(fixture.scrollView.layer)
        for layer in layers {
            XCTAssertNil(layer.presentation(), "\(layer) resolved a presentation layer")
        }
    }

    // MARK: - The seam

    /// A model with one live owner carrying an in-flight height track, so `resumeValue` has both an
    /// analytic answer to fall back to and a track to be asked about.
    private func modelWithLiveOwner() -> (ListAnimationModel, ListAnimationOwner) {
        let model = ListAnimationModel()
        let owner = ListAnimationOwner.live(AnyHashable(UUID()))
        _ = model.transitionHeight(owner: owner,
                                   oldSettledHeight: 40,
                                   newSettledHeight: 140,
                                   at: 0,
                                   transition: .linear(duration: 1.0))
        return (model, owner)
    }

    /// The provider's value is used verbatim — it is already in the track's space, and the model does
    /// not convert. An earlier version subtracted a `settled` reference for additive properties; see
    /// `resumeValue` for why that was wrong.
    func testResumeValueReturnsTheProvidedValueVerbatim() throws {
        let (model, owner) = modelWithLiveOwner()
        model.presentedValueProvider = { _, property in property == .height ? 63.5 : nil }

        XCTAssertEqual(try XCTUnwrap(model.resumeValue(for: owner, property: .height, at: 0.5)),
                       63.5, accuracy: 1e-9)
    }

    /// `.viewportOffset` and `.positionX` are not sampled. The viewport's model `bounds.origin.y` is
    /// the live scroll position rather than the settled offset, and sampling it produced a whole-list
    /// jump on every re-issue; `.positionX` is simply unmeasured. `.positionY` IS sampled and is read
    /// as a position by its consumer, so it is not in this list.
    func testUnsampledPropertiesAreDeclinedByTheInstalledProvider() throws {
        let controller = ListAnimationController()
        let layer = CALayer()
        controller.transitionHeight(identity: AnyHashable(UUID()), layer: layer,
                                    oldSettledHeight: 40, newSettledHeight: 140,
                                    transition: .linear(duration: 1.0))
        let provider = try XCTUnwrap(controller.model.presentedValueProvider)
        let owner = ListAnimationOwner.live(AnyHashable(UUID()))
        for property in [ListAnimatedProperty.viewportOffset, .positionX] {
            XCTAssertNil(provider(owner, property), "\(property) must not be sampled")
        }
    }

    /// No provider is today's behaviour, exactly — this is what keeps the windowless suite unchanged.
    func testResumeValueFallsBackToTheAnalyticValueWithoutAProvider() {
        let (model, owner) = modelWithLiveOwner()

        XCTAssertEqual(model.resumeValue(for: owner, property: .height, at: 0.5),
                       model.value(for: owner, property: .height, at: 0.5))
    }

    /// A provider that declines this property is the same as no provider.
    func testResumeValueFallsBackWhenTheProviderReturnsNil() {
        let (model, owner) = modelWithLiveOwner()
        model.presentedValueProvider = { _, _ in nil }

        XCTAssertEqual(model.resumeValue(for: owner, property: .height, at: 0.5),
                       model.value(for: owner, property: .height, at: 0.5))
    }

    // MARK: - The invariant this whole change buys

    /// A re-issue mid-flight must start from what the layer is RENDERING, not from what the model
    /// computes for the pass clock.
    ///
    /// The two are separated deliberately rather than left a few milliseconds apart: the first
    /// transition is stamped at `t0`, the animation is allowed to run for real for ~0.2s, and the
    /// re-issue is stamped at `t0 + 0.8`. The model's analytic answer is therefore ~120 while the
    /// screen is at ~60. A `from` near 60 can only have come from the presentation layer, and one near
    /// 120 can only have come from the model — no tolerance juggling required.
    func testReissuedHeightResumesFromThePresentedValueNotTheModelClock() throws {
        // A window with no `UIWindowScene` never enters the render tree, so its layers never resolve a
        // presentation layer — which is the whole point of this test. Attach to the test host's scene.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 40))
        window.addSubview(host)
        window.layoutIfNeeded()

        let controller = ListAnimationController()
        let identity = AnyHashable(UUID())
        let t0 = CACurrentMediaTime()
        controller.transitionHeight(identity: identity, layer: host.layer,
                                    oldSettledHeight: 40, newSettledHeight: 140,
                                    transition: .linear(duration: 1.0),
                                    transactionTime: t0)
        CATransaction.flush()

        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }

        let presented = try XCTUnwrap(host.layer.presentation()?.bounds.size.height)
        XCTAssertGreaterThan(presented, 40.5, "precondition: the animation is in flight")
        XCTAssertLessThan(presented, 100.0, "precondition: well short of the model's t0+0.8 answer")

        controller.transitionHeight(identity: identity, layer: host.layer,
                                    oldSettledHeight: 140, newSettledHeight: 240,
                                    transition: .linear(duration: 1.0),
                                    transactionTime: t0 + 0.8)

        let reissued = try XCTUnwrap(
            host.layer.animation(forKey: "CoreListAnimation.height") as? CABasicAnimation)
        let from = try XCTUnwrap((reissued.fromValue as? NSNumber)?.doubleValue)
        XCTAssertEqual(from, Double(presented), accuracy: 5.0,
                       "re-issue started from the model clock (~120) instead of the screen (~\(presented))")
    }

    /// The additive/absolute split must agree with what the compiler actually emits, or a presented
    /// value would be converted into a space the animation is not in. Two switches that must stay in
    /// sync is the shape of defect this whole change came out of, so it is asserted rather than
    /// assumed.
    func testAdditiveClassificationMatchesTheCompiler() {
        let compiler = CoreAnimationCompiler(emitsAnimations: false)
        for property in [ListAnimatedProperty.viewportOffset, .positionX, .positionY,
                         .width, .height, .opacity] {
            XCTAssertEqual(property.isAdditiveTrack, compiler.isAdditive(property),
                           "classification disagrees for \(property)")
        }
    }
}
