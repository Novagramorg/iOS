import XCTest
import UIKit
import QuartzCore
@testable import CoreListDemo

final class CoreAnimationCompilerParityTests: XCTestCase {
    private final class IntItem: CoreListItem {
        let id: Int
        let height: CGFloat
        var identity: AnyHashable { id }

        init(id: Int, height: CGFloat) {
            self.id = id
            self.height = height
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: height)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? IntItem)?.id == id
        }
    }

    private final class AnimationSpyLayer: CALayer {
        var removedKeys: [String] = []

        override func removeAnimation(forKey key: String) {
            removedKeys.append(key)
            super.removeAnimation(forKey: key)
        }
    }

    private func visibleWindow() throws -> (UIWindow, UIViewController) {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        let root = UIViewController()
        root.view.backgroundColor = .white
        window.rootViewController = root
        window.makeKeyAndVisible()
        return (window, root)
    }

    private func flushCoreAnimation() {
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    func testPositionKeyframeIsAdditiveAndUsesTrackClock() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 1, from: -80, to: 0,
                                       startTime: 12, duration: 3)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .positionY)
                                      as? CAKeyframeAnimation)
        XCTAssertEqual(animation.keyPath, "position.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(animation.beginTime, 12)
        XCTAssertEqual(animation.duration, 3)
        XCTAssertEqual(animation.fillMode, .both)
        XCTAssertFalse(animation.isRemovedOnCompletion)
    }

    func testOpacityKeyframeIsAbsolute() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 2, from: 0.25, to: 1,
                                       startTime: 4, duration: 2)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .opacity)
                                      as? CAKeyframeAnimation)
        XCTAssertFalse(animation.isAdditive)
        XCTAssertEqual(animation.keyPath, "opacity")
    }

    func testHeightKeyframeIsAbsoluteAndIndependentlyKeyed() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 3, from: 75, to: 100,
                                       startTime: 4, duration: 2)

        let animation = try XCTUnwrap(compiler.animation(for: track, property: .height)
                                      as? CAKeyframeAnimation)

        XCTAssertFalse(animation.isAdditive)
        XCTAssertEqual(animation.keyPath, "bounds.size.height")
        XCTAssertEqual(compiler.animationKey(for: .height), "CoreListAnimation.height")
        XCTAssertNotEqual(compiler.animationKey(for: .height),
                          compiler.animationKey(for: .positionY))
        XCTAssertNotEqual(compiler.animationKey(for: .height),
                          compiler.animationKey(for: .opacity))
    }

    func testHorizontalGeometryKeyframesHaveIndependentMappings() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let position = ListAnimationTrack(generation: 31, from: -40, to: 0,
                                          startTime: 4, duration: 2)
        let width = ListAnimationTrack(generation: 32, from: 390, to: 310,
                                       startTime: 4, duration: 2)

        let positionAnimation = try XCTUnwrap(
            compiler.animation(for: position, property: .positionX) as? CAKeyframeAnimation
        )
        let widthAnimation = try XCTUnwrap(
            compiler.animation(for: width, property: .width) as? CAKeyframeAnimation
        )

        XCTAssertEqual(positionAnimation.keyPath, "position.x")
        XCTAssertTrue(positionAnimation.isAdditive)
        XCTAssertEqual(widthAnimation.keyPath, "bounds.size.width")
        XCTAssertFalse(widthAnimation.isAdditive)
        XCTAssertNotEqual(compiler.animationKey(for: .positionX),
                          compiler.animationKey(for: .width))
    }

    func testViewportKeyframeIsAdditiveBoundsOrigin() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 90, from: -500, to: 0,
                                       startTime: 10, duration: 4)
        let animation = try XCTUnwrap(compiler.animation(
            for: track, property: .viewportOffset
        ) as? CAKeyframeAnimation)

        XCTAssertEqual(animation.keyPath, "bounds.origin.y")
        XCTAssertTrue(animation.isAdditive)
        XCTAssertEqual(compiler.animationKey(for: .viewportOffset),
                       "CoreListAnimation.viewportOffset")
    }

    func testCompiledSamplesLinearlyInterpolateTheAnalyticTrack() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let spans: [(CGFloat, CGFloat)] = [(-400, 0), (0, 1), (75, -125)]

        let cases: [(ListAnimatedProperty, [(CGFloat, CGFloat)], Double)] = [
            (.positionY, spans, 0.02),
            (.height, [(75, 100), (100, 40)], 0.02),
            (.opacity, [(0, 1)], 0.0001),
        ]
        for (property, propertySpans, accuracy) in cases {
            for (from, to) in propertySpans {
                let track = ListAnimationTrack(generation: 7, from: from, to: to,
                                               startTime: 19, duration: 3)
                let animation = try XCTUnwrap(compiler.animation(for: track, property: property)
                                              as? CAKeyframeAnimation)
                for step in 0..<101 {
                    let phase = (Double(step) + 0.37) / 101
                    let compiled = try interpolatedValue(of: animation, phase: phase)
                    let analytic = Double(track.value(at: track.startTime + phase * track.duration))
                    XCTAssertEqual(compiled, analytic, accuracy: accuracy,
                                   "\(property) \(from)->\(to) diverged at phase \(phase)")
                }
            }
        }
    }

    func testCompilationUsesInclusiveSamplingAndPreservesGenerationAndSlowClock() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 10)
        // The duration is already Slow-Animation-scaled before it reaches the compiler.
        let track = ListAnimationTrack(generation: 91, from: 20, to: 0,
                                       startTime: 40, duration: 3)
        let animation = try XCTUnwrap(compiler.animation(for: track, property: .positionY)
                                      as? CAKeyframeAnimation)
        let values = try XCTUnwrap(animation.values as? [NSNumber])
        let keyTimes = try XCTUnwrap(animation.keyTimes)

        XCTAssertEqual(values.count, 31)
        XCTAssertEqual(keyTimes.count, 31)
        XCTAssertEqual(values.first?.doubleValue, Double(track.value(at: 40)))
        XCTAssertEqual(values.last?.doubleValue, Double(track.value(at: 43)))
        XCTAssertEqual(keyTimes.first?.doubleValue, 0)
        XCTAssertEqual(keyTimes.last?.doubleValue, 1)
        XCTAssertEqual(animation.calculationMode, .linear)
        XCTAssertEqual(animation.duration, 3, "the compiler must not apply Slow Animation scaling twice")
        XCTAssertEqual((animation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       track.generation)
    }

    func testInstallUsesStableKeysAndReplacementKeepsOtherProperty() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let layer = CALayer()
        layer.speed = 0
        layer.timeOffset = 10
        let firstPosition = ListAnimationTrack(generation: 1, from: 80, to: 0,
                                               startTime: 10, duration: 2)
        let opacity = ListAnimationTrack(generation: 2, from: 0, to: 1,
                                         startTime: 10, duration: 2)
        let replacement = ListAnimationTrack(generation: 3, from: 40, to: 0,
                                              startTime: 10.5, duration: 1.5)
        let height = ListAnimationTrack(generation: 4, from: 75, to: 100,
                                        startTime: 10, duration: 2)
        let heightReplacement = ListAnimationTrack(generation: 5, from: 80, to: 110,
                                                   startTime: 10.5, duration: 1.5)

        compiler.install(firstPosition, property: .positionY, on: layer)
        compiler.install(opacity, property: .opacity, on: layer)
        compiler.install(height, property: .height, on: layer)
        compiler.install(replacement, property: .positionY, on: layer)
        compiler.install(heightReplacement, property: .height, on: layer)

        XCTAssertEqual(compiler.animationKey(for: .positionY), "CoreListAnimation.positionY")
        XCTAssertEqual(compiler.animationKey(for: .opacity), "CoreListAnimation.opacity")
        XCTAssertEqual(compiler.animationKey(for: .height), "CoreListAnimation.height")
        let installedPosition = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .positionY))
        )
        let installedOpacity = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .opacity))
        )
        let installedHeight = try XCTUnwrap(
            layer.animation(forKey: compiler.animationKey(for: .height))
        )
        XCTAssertEqual((installedPosition.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       replacement.generation)
        XCTAssertEqual((installedOpacity.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       opacity.generation)
        XCTAssertEqual((installedHeight.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
                       heightReplacement.generation)
    }

    func testDisabledCompilerDoesNotInstallAnimation() {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240, emitsAnimations: false)
        let layer = CALayer()
        let track = ListAnimationTrack(generation: 1, from: 1, to: 0,
                                       startTime: 0, duration: 1)

        compiler.install(track, property: .opacity, on: layer)

        XCTAssertNil(layer.animation(forKey: compiler.animationKey(for: .opacity)))
    }

    func testRemoveTargetsOnlyThePropertyStableKey() {
        let compiler = CoreAnimationCompiler()
        let layer = AnimationSpyLayer()

        compiler.remove(property: .positionY, from: layer)

        XCTAssertEqual(layer.removedKeys, ["CoreListAnimation.positionY"])
        XCTAssertFalse(layer.removedKeys.contains("CoreListAnimation.opacity"))
    }

    func testPausedWindowBackedLayerPresentationMatchesAnalyticPositionTrack() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 44, from: -80, to: 0,
                                       startTime: 12, duration: 3)
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        let root = UIViewController()
        window.rootViewController = root
        root.view.backgroundColor = .white
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.position = CGPoint(x: 100, y: 200)
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .positionY, on: layer)

        for phase in [0.0, 0.5, 1.0] {
            layer.timeOffset = track.startTime + phase * track.duration
            root.view.layoutIfNeeded()
            CATransaction.flush()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

            let presentation = try XCTUnwrap(layer.presentation())
            let renderedOffset = presentation.position.y - layer.position.y
            let analyticOffset = track.value(at: layer.timeOffset)
            XCTAssertEqual(renderedOffset, analyticOffset, accuracy: 0.1,
                           "real Core Animation diverged at phase \(phase)")
        }
    }

    func testPausedWindowBackedLayerPresentationMatchesAnalyticOpacityTrack() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 45, from: 0.2, to: 1,
                                       startTime: 12, duration: 3)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.position = CGPoint(x: 100, y: 200)
        layer.opacity = 1
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .opacity, on: layer)

        for phase in [0.0, 0.5, 1.0] {
            layer.timeOffset = track.startTime + phase * track.duration
            flushCoreAnimation()
            XCTAssertEqual(CGFloat(try XCTUnwrap(layer.presentation()).opacity),
                           track.value(at: layer.timeOffset), accuracy: 0.01)
        }
    }

    func testPausedWindowBackedLayerPresentationMatchesAnalyticHeightTrack() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 46, from: 75, to: 100,
                                       startTime: 12, duration: 3)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 100)
        layer.position = CGPoint(x: 100, y: 200)
        layer.backgroundColor = UIColor.red.cgColor
        layer.speed = 0
        layer.timeOffset = track.startTime
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .height, on: layer)

        for phase in [0.0, 0.5, 1.0] {
            layer.timeOffset = track.startTime + phase * track.duration
            flushCoreAnimation()
            XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.height,
                           track.value(at: layer.timeOffset), accuracy: 0.1)
        }
    }

    func testPausedViewportAddsToChangingBoundsAndPhysicsFlight() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 240)
        let track = ListAnimationTrack(generation: 47, from: -200, to: 0,
                                       startTime: 12, duration: 4)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 500, width: 320, height: 640)
        layer.position = CGPoint(x: 160, y: 320)
        layer.speed = 0
        layer.timeOffset = 14
        root.view.layer.addSublayer(layer)
        compiler.install(track, property: .viewportOffset, on: layer)
        flushCoreAnimation()

        let correction = track.value(at: layer.timeOffset)
        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       500 + correction, accuracy: 0.1)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.bounds.origin.y = 575
        CATransaction.commit()
        flushCoreAnimation()
        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       575 + correction, accuracy: 0.1)

        let flight = CAKeyframeAnimation(keyPath: "bounds.origin.y")
        flight.isAdditive = true
        flight.values = [-50, -50]
        flight.keyTimes = [0, 1]
        flight.calculationMode = .linear
        flight.beginTime = track.startTime
        flight.duration = track.duration
        flight.fillMode = .both
        flight.isRemovedOnCompletion = false
        layer.add(flight, forKey: "listDecelerationFlight")
        flushCoreAnimation()

        XCTAssertEqual(try XCTUnwrap(layer.presentation()).bounds.origin.y,
                       575 + correction - 50, accuracy: 0.1)
    }

    func testControllerHeightRetargetPreservesPositionAndOpacityKeys() throws {
        var time: CFTimeInterval = 0
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 75)

        controller.insert(identity: "row", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 8))
        let positionBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))

        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        time = 1
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 100, newSettledHeight: 125,
                                    transition: .easeInOut(duration: 3))

        let positionAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        XCTAssertEqual(positionAfter.beginTime, positionBefore.beginTime)
        XCTAssertEqual(positionAfter.duration, positionBefore.duration)
        XCTAssertEqual(opacityAfter.beginTime, opacityBefore.beginTime)
        XCTAssertEqual(opacityAfter.duration, opacityBefore.duration)
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .height)))
    }

    func testPausedWindowBackedReplacementMatchesControllerModel() throws {
        var time: CFTimeInterval = 10
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(samplesPerSecond: 240),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.anchorPoint = .zero
        layer.position.y = 100
        layer.speed = 0
        layer.timeOffset = time
        root.view.layer.addSublayer(layer)
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4), transactionTime: time)

        time = 11
        layer.timeOffset = time
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.position.y = 150
        CATransaction.commit()
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 150,
                                      transition: .easeInOut(duration: 3), transactionTime: time)
        let replacement = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))

        for phase in [0.0, 0.5, 1.0] {
            time = replacement.startTime + phase * replacement.duration
            layer.timeOffset = time
            flushCoreAnimation()
            let presentation = try XCTUnwrap(layer.presentation())
            XCTAssertEqual(presentation.position.y - layer.position.y,
                           replacement.value(at: time), accuracy: 0.1)
        }
    }

    func testPausedWindowBackedCrossingCarriesMatchAnalyticModel() throws {
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { IntItem(id: $0, height: 75) }
        }
        let original = Array(0..<30)
        let expanded = Array(0..<5) + Array(100..<105) + Array(5..<30)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }

        let outgoingFixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(original), preloadMargin: 200, emitsCA: true
        )
        root.view.addSubview(outgoingFixture.listView)
        outgoingFixture.apply(items(expanded), duration: 8)
        let outgoingIdentity = AnyHashable(8)
        let outgoingView = try XCTUnwrap(
            outgoingFixture.crossingCarryView(identity: outgoingIdentity)
        )
        let outgoingAnimation = try XCTUnwrap(outgoingView.layer.animation(
            forKey: "CoreListAnimation.positionY"
        ) as? CAKeyframeAnimation)
        XCTAssertTrue(outgoingAnimation.isAdditive)
        outgoingView.layer.speed = 0

        for time in [0.0, 4.0, 8.0] {
            outgoingFixture.clock.now = time
            outgoingView.layer.timeOffset = time
            flushCoreAnimation()
            let snapshot = try XCTUnwrap(
                outgoingFixture.listView.crossingCarrySnapshots.first {
                    $0.identity == outgoingIdentity
                }
            )
            let analytic = snapshot.settledContentY
                + (outgoingFixture.animationController.positionOffset(
                    identity: outgoingIdentity,
                    at: time
                ) ?? 0)
            XCTAssertEqual(try XCTUnwrap(outgoingView.layer.presentation()).position.y,
                           analytic, accuracy: 0.1)
        }

        let incomingFixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(expanded), preloadMargin: 200, emitsCA: true
        )
        root.view.addSubview(incomingFixture.listView)
        incomingFixture.apply(items(original), duration: 8)
        let incomingIdentity = AnyHashable(8)
        let incomingView = try XCTUnwrap(incomingFixture.view(identity: incomingIdentity))
        let incomingAnimation = try XCTUnwrap(incomingView.layer.animation(
            forKey: "CoreListAnimation.positionY"
        ) as? CAKeyframeAnimation)
        XCTAssertTrue(incomingAnimation.isAdditive)
        incomingView.layer.speed = 0

        for time in [0.0, 4.0, 8.0] {
            incomingFixture.clock.now = time
            incomingView.layer.timeOffset = time
            flushCoreAnimation()
            let settled = try XCTUnwrap(
                incomingFixture.driver.settledContentY(identity: incomingIdentity)
            )
            let analytic = settled + (incomingFixture.animationController.positionOffset(
                identity: incomingIdentity,
                at: time
            ) ?? 0)
            XCTAssertEqual(try XCTUnwrap(incomingView.layer.presentation()).position.y,
                           analytic, accuracy: 0.1)
        }
    }

    func testPausedUnwitnessedCrossingRunMatchesAnalyticModel() throws {
        func items(_ ids: [Int]) -> [CoreListItem] {
            ids.map { IntItem(id: $0, height: 75) }
        }
        let expanded = Array(0..<5) + Array(1000..<1100) + Array(5..<40)
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 600),
            items: items(Array(0..<40)),
            preloadMargin: 200,
            emitsCA: true
        )
        root.view.addSubview(fixture.listView)
        fixture.apply(items(expanded), duration: 8)
        let identities = [AnyHashable(5), AnyHashable(6)]
        let views = try identities.map {
            try XCTUnwrap(fixture.crossingCarryView(identity: $0))
        }
        for view in views {
            XCTAssertNotNil(view.layer.animation(forKey: "CoreListAnimation.positionY"))
            view.layer.speed = 0
        }

        for time in [0.0, 4.0, 8.0] {
            fixture.clock.now = time
            views.forEach { $0.layer.timeOffset = time }
            flushCoreAnimation()
            var presentationY: [CGFloat] = []
            for (identity, view) in zip(identities, views) {
                let snapshot = try XCTUnwrap(
                    fixture.listView.crossingCarrySnapshots.first {
                        $0.identity == identity
                    }
                )
                let analytic = snapshot.settledContentY
                    + (fixture.animationController.positionOffset(
                        identity: identity,
                        at: time
                    ) ?? 0)
                let y = try XCTUnwrap(view.layer.presentation()).position.y
                XCTAssertEqual(y, analytic, accuracy: 0.1)
                presentationY.append(y)
            }
            XCTAssertEqual(presentationY[1] - presentationY[0], 75, accuracy: 0.1)
        }
    }

    func testPausedWindowBackedReboundMatchesOriginalTrackPhaseAndDeadline() throws {
        var time: CFTimeInterval = 10
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(samplesPerSecond: 240),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let first = CALayer()
        first.position.y = 100
        controller.seedLive(identity: "row", layer: first)
        controller.transitionPosition(identity: "row", layer: first,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4), transactionTime: time)
        let original = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        controller.unbind(identity: "row", layer: first)

        time = 11
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let rebound = CALayer()
        rebound.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        rebound.anchorPoint = .zero
        rebound.position.y = 100
        rebound.speed = 0
        rebound.timeOffset = time
        root.view.layer.addSublayer(rebound)
        controller.rebind(identity: "row", layer: rebound)

        for phase in [0.25, 0.5, 1.0] {
            time = original.startTime + phase * original.duration
            rebound.timeOffset = time
            flushCoreAnimation()
            let presentation = try XCTUnwrap(rebound.presentation())
            XCTAssertEqual(presentation.position.y - rebound.position.y,
                           original.value(at: time), accuracy: 0.1)
        }
    }

    func testControllerScalesLogicalDurationExactlyOnceForModelAndCA() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 40 },
            durationFactor: { 10 }
        )
        let layer = CALayer()
        layer.position.y = 180

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 0.3))

        let track = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let animation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(track.duration, 3)
        XCTAssertEqual(animation.duration, 3,
                       "the controller, model, and compiler must share one scaled duration")
    }

    func testControllerViewportSlowDurationAndSameTargetPreserveExactTrackAndCA() throws {
        var time: CFTimeInterval = 40
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 10 }
        )
        let layer = CALayer()
        layer.bounds.origin.y = 300
        controller.seedViewport(layer: layer)
        controller.transitionViewport(
            layer: layer, oldSettledOffset: 100, newSettledOffset: 300,
            transition: .easeInOut(duration: 0.3), transactionTime: time,
            completion: { _ in }
        )
        let beforeTrack = try XCTUnwrap(controller.model.track(
            for: .viewport, property: .viewportOffset
        ))
        let key = compiler.animationKey(for: .viewportOffset)
        let beforeAnimation = try XCTUnwrap(layer.animation(forKey: key))
        XCTAssertEqual(beforeTrack.duration, 3)
        XCTAssertEqual(beforeAnimation.duration, 3)

        time = 41
        let mutation = controller.transitionViewport(
            layer: layer, oldSettledOffset: 300, newSettledOffset: 300,
            transition: .easeInOut(duration: 20), transactionTime: time,
            completion: { _ in }
        )
        let afterTrack = try XCTUnwrap(controller.model.track(
            for: .viewport, property: .viewportOffset
        ))
        let afterAnimation = try XCTUnwrap(layer.animation(forKey: key))
        XCTAssertEqual(mutation, .unchanged)
        XCTAssertEqual(afterTrack, beforeTrack)
        XCTAssertEqual(afterAnimation.beginTime, beforeAnimation.beginTime)
        XCTAssertEqual(afterAnimation.duration, beforeAnimation.duration)
        XCTAssertEqual(
            (afterAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (beforeAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
    }

    func testControllerSamePositionTargetLeavesInstalledGenerationAndClockUntouched() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()
        layer.position.y = 180

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))
        let beforeTrack = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let beforeAnimation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))

        time = 11
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 180,
                                      newSettledY: 180 + 5e-7,
                                      transition: .easeInOut(duration: 20))

        let afterTrack = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        let afterAnimation = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(afterTrack, beforeTrack)
        XCTAssertEqual(afterAnimation.beginTime, beforeAnimation.beginTime)
        XCTAssertEqual(afterAnimation.duration, beforeAnimation.duration)
        XCTAssertEqual(
            (afterAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (beforeAnimation.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
    }

    func testControllerSameHeightTargetLeavesModelAndInstalledCAKeyExactlyUntouched() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        let beforeTrack = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        let key = compiler.animationKey(for: .height)
        let installed = try XCTUnwrap(layer.animation(forKey: key))
        installed.setValue("preserve-height-install", forKey: "HeightRebind.installSentinel")
        layer.add(installed, forKey: key)

        time = 11
        let mutation = controller.transitionHeight(
            identity: "row", layer: layer,
            oldSettledHeight: 100, newSettledHeight: 100 + 5e-7,
            transition: .easeInOut(duration: 20)
        )

        XCTAssertEqual(mutation, .unchanged)
        XCTAssertEqual(controller.model.track(for: owner, property: .height), beforeTrack)
        XCTAssertEqual(layer.animation(forKey: key)?.value(
            forKey: "HeightRebind.installSentinel"
        ) as? String, "preserve-height-install")
    }

    func testControllerResetRemovesHeightModelStateAndInstalledCAKey() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 0 },
            durationFactor: { 1 }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4))
        XCTAssertNotNil(controller.model.track(for: owner, property: .height))
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .height)))

        controller.reset()

        XCTAssertNil(controller.model.value(for: owner, property: .height, at: 0))
        XCTAssertNil(controller.model.track(for: owner, property: .height))
        XCTAssertNil(layer.animation(forKey: compiler.animationKey(for: .height)))
    }

    func testControllerPositionRetargetPreservesInFlightOpacityKey() throws {
        var time: CFTimeInterval = 0
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let layer = CALayer()

        controller.insert(identity: "row", layer: layer, transition: .easeInOut(duration: 8))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))

        time = 1
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 180, newSettledY: 220,
                                      transition: .easeInOut(duration: 3))

        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        let position = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(
            (opacityAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (opacityBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
        XCTAssertEqual(opacityAfter.beginTime, opacityBefore.beginTime)
        XCTAssertEqual(opacityAfter.duration, opacityBefore.duration)
        XCTAssertEqual(
            (position.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            controller.model.track(for: .live(AnyHashable("row")), property: .positionY)?.generation
        )
    }

    func testControllerStaleUnbindDoesNotClearRecycledLayersCurrentOwnerKeys() throws {
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { 0 },
            durationFactor: { 1 }
        )
        let layer = CALayer()

        controller.insert(identity: "A", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "A", layer: layer,
                                      oldSettledY: 0, newSettledY: 80,
                                      transition: .easeInOut(duration: 8))
        controller.insert(identity: "B", layer: layer, transition: .easeInOut(duration: 8))
        controller.transitionPosition(identity: "B", layer: layer,
                                      oldSettledY: 0, newSettledY: 120,
                                      transition: .easeInOut(duration: 8))

        let positionBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityBefore = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))

        controller.unbind(identity: "A", layer: layer)

        let positionAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        let opacityAfter = try XCTUnwrap(layer.animation(
            forKey: compiler.animationKey(for: .opacity)
        ))
        XCTAssertEqual(
            (positionAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (positionBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )
        XCTAssertEqual(
            (opacityAfter.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            (opacityBefore.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
        )

        let unchanged = controller.transitionPosition(
            identity: "B", layer: layer,
            oldSettledY: 120, newSettledY: 120,
            transition: .easeInOut(duration: 20)
        )
        XCTAssertEqual(unchanged, .unchanged)
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .positionY)))
        XCTAssertNotNil(layer.animation(forKey: compiler.animationKey(for: .opacity)))
    }

    func testControllerRebindEmitsOriginalTrackClockAndCurrentBindingFinalizesIt() throws {
        var time: CFTimeInterval = 10
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let firstLayer = CALayer()
        let reboundLayer = CALayer()

        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionPosition(identity: "row", layer: firstLayer,
                                      oldSettledY: 100, newSettledY: 180,
                                      transition: .easeInOut(duration: 4))
        let original = try XCTUnwrap(controller.model.track(
            for: .live(AnyHashable("row")), property: .positionY
        ))
        controller.unbind(identity: "row", layer: firstLayer)

        time = 11
        controller.rebind(identity: "row", layer: reboundLayer)
        let rebound = try XCTUnwrap(reboundLayer.animation(
            forKey: compiler.animationKey(for: .positionY)
        ))
        XCTAssertEqual(rebound.beginTime, original.startTime)
        XCTAssertEqual(rebound.duration, original.duration)
        XCTAssertEqual(
            (rebound.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            original.generation
        )

        time = 14
        controller.reapSettledTracks()
        XCTAssertNil(reboundLayer.animation(forKey: compiler.animationKey(for: .positionY)),
                     "the stale first binding must not consume the generation before the rebound binding")
    }

    func testControllerAutonomouslyPrunesCompletedUnboundOwnerAtAnalyticDeadline() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()

        controller.seedLive(identity: "row", layer: layer)
        controller.transitionPosition(identity: "row", layer: layer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4),
                                      transactionTime: time)
        controller.unbind(identity: "row", layer: layer, at: time)

        XCTAssertTrue(controller.model.contains(owner))
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)

        let early = scheduled.removeFirst().work
        early()
        XCTAssertTrue(controller.model.contains(owner),
                      "an early callback must retain active analytic state")
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)

        time = 14
        XCTAssertTrue(controller.model.contains(owner))
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner),
                       "deadline cleanup must not depend on a test driver or display link")
    }

    func testControllerAutonomouslyPrunesHeightOnlyUnboundOwnerAtAnalyticDeadline() throws {
        var time: CFTimeInterval = 10
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let layer = CALayer()
        layer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: layer)
        controller.transitionHeight(identity: "row", layer: layer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        XCTAssertNil(controller.model.track(for: owner, property: .positionY))
        XCTAssertNil(controller.model.track(for: owner, property: .opacity))

        controller.unbind(identity: "row", layer: layer, at: time)

        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(try XCTUnwrap(scheduled.first?.delay), 4, accuracy: 1e-9)
        time = 14
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testStaleHeightReapCannotConsumeReboundReplacementGeneration() throws {
        var time: CFTimeInterval = 0
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        firstLayer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionHeight(identity: "row", layer: firstLayer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        let reboundLayer = CALayer()
        reboundLayer.bounds.size.height = 100
        controller.rebind(identity: "row", layer: reboundLayer)
        controller.transitionHeight(identity: "row", layer: reboundLayer,
                                    oldSettledHeight: 100, newSettledHeight: 200,
                                    transition: .easeInOut(duration: 8),
                                    transactionTime: time)
        let replacement = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        controller.unbind(identity: "row", layer: reboundLayer, at: time)

        time = 4
        scheduled.removeFirst().work()
        XCTAssertEqual(controller.model.track(for: owner, property: .height), replacement,
                       "the original height deadline must not consume the replacement generation")

        time = 9
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testStaleHeightCACompletionCannotClearReboundReplacementOrInstalledKey() throws {
        var time: CFTimeInterval = 0
        var installedCompletions: [() -> Void] = []
        let compiler = CoreAnimationCompiler(samplesPerSecond: 20)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { time },
            durationFactor: { 1 },
            animationInstaller: { track, property, layer, completion in
                compiler.install(track, property: property, on: layer)
                installedCompletions.append(completion)
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        firstLayer.bounds.size.height = 75
        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionHeight(identity: "row", layer: firstLayer,
                                    oldSettledHeight: 75, newSettledHeight: 100,
                                    transition: .easeInOut(duration: 4),
                                    transactionTime: time)
        XCTAssertEqual(installedCompletions.count, 1)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        let reboundLayer = CALayer()
        reboundLayer.bounds.size.height = 100
        controller.rebind(identity: "row", layer: reboundLayer)
        XCTAssertEqual(installedCompletions.count, 2)
        controller.transitionHeight(identity: "row", layer: reboundLayer,
                                    oldSettledHeight: 100, newSettledHeight: 200,
                                    transition: .easeInOut(duration: 8),
                                    transactionTime: time)
        XCTAssertEqual(installedCompletions.count, 3)
        let replacement = try XCTUnwrap(
            controller.model.track(for: owner, property: .height)
        )
        let key = compiler.animationKey(for: .height)
        let installedReplacement = try XCTUnwrap(reboundLayer.animation(forKey: key))

        time = 4
        installedCompletions[0]()
        installedCompletions[1]()

        XCTAssertEqual(controller.model.track(for: owner, property: .height), replacement)
        let afterStaleCompletions = try XCTUnwrap(reboundLayer.animation(forKey: key))
        XCTAssertEqual(
            (afterStaleCompletions.value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value,
            replacement.generation
        )
        XCTAssertEqual(afterStaleCompletions.beginTime, installedReplacement.beginTime)
        XCTAssertEqual(afterStaleCompletions.duration, installedReplacement.duration)
    }

    func testStaleAutonomousUnboundReapCannotConsumeReplacementGeneration() throws {
        var time: CFTimeInterval = 0
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: false),
            mediaTime: { time },
            durationFactor: { 1 },
            scheduleAfter: { delay, work in
                scheduled.append((delay, work))
            }
        )
        let owner = ListAnimationOwner.live(AnyHashable("row"))
        let firstLayer = CALayer()
        let secondLayer = CALayer()

        controller.seedLive(identity: "row", layer: firstLayer)
        controller.transitionPosition(identity: "row", layer: firstLayer,
                                      oldSettledY: 0, newSettledY: 100,
                                      transition: .easeInOut(duration: 4),
                                      transactionTime: time)
        controller.unbind(identity: "row", layer: firstLayer, at: time)

        time = 1
        controller.rebind(identity: "row", layer: secondLayer)
        controller.transitionPosition(identity: "row", layer: secondLayer,
                                      oldSettledY: 100, newSettledY: 200,
                                      transition: .easeInOut(duration: 8),
                                      transactionTime: time)
        let replacement = try XCTUnwrap(controller.model.track(
            for: owner, property: .positionY
        ))
        controller.unbind(identity: "row", layer: secondLayer, at: time)

        time = 4
        scheduled.removeFirst().work()
        XCTAssertEqual(controller.model.track(for: owner, property: .positionY), replacement,
                       "an old analytic deadline must not consume a replacement generation")

        time = 9
        scheduled.removeFirst().work()
        XCTAssertFalse(controller.model.contains(owner))
    }

    func testGhostBlockControllerTrackMatchesPausedWrapperLayer() throws {
        var time: CFTimeInterval = 12
        let controller = ListAnimationController(
            compiler: CoreAnimationCompiler(samplesPerSecond: 240),
            mediaTime: { time },
            durationFactor: { 1 }
        )
        let (window, root) = try visibleWindow()
        defer { window.isHidden = true }
        let wrapper = UIView(frame: CGRect(x: 0, y: 100, width: 320, height: 1))
        wrapper.layer.anchorPoint = CGPoint(x: 0, y: 0)
        wrapper.layer.speed = 0
        wrapper.layer.timeOffset = time
        root.view.addSubview(wrapper)
        let owner = ListAnimationOwner.ghostBlock(71)
        controller.seedGhostBlock(owner: owner,
                                  layer: wrapper.layer,
                                  settledRootY: 100)
        controller.transitionGhostBlock(owner: owner,
                                        layer: wrapper.layer,
                                        oldSettledY: 100,
                                        newSettledY: 180,
                                        transition: .easeInOut(duration: 4),
                                        transactionTime: time)

        for phase in [0.0, 0.5, 1.0] {
            time = 12 + phase * 4
            wrapper.layer.timeOffset = time
            flushCoreAnimation()
            let renderedRoot = try XCTUnwrap(wrapper.layer.presentation()).position.y
            let analyticRoot = wrapper.layer.position.y
                + (controller.ghostBlockOffset(owner: owner, at: time) ?? 0)
            XCTAssertEqual(renderedRoot, analyticRoot, accuracy: 0.1)
        }
    }

    private func interpolatedValue(of animation: CAKeyframeAnimation,
                                   phase: Double) throws -> Double {
        let values = try XCTUnwrap(animation.values as? [NSNumber])
        let keyTimes = try XCTUnwrap(animation.keyTimes)
        let clamped = min(max(phase, 0), 1)
        guard clamped > 0 else { return values[0].doubleValue }
        guard clamped < 1 else { return values[values.count - 1].doubleValue }

        for index in 1..<keyTimes.count {
            let upperTime = keyTimes[index].doubleValue
            guard clamped <= upperTime else { continue }
            let lowerTime = keyTimes[index - 1].doubleValue
            let localPhase = (clamped - lowerTime) / (upperTime - lowerTime)
            let lowerValue = values[index - 1].doubleValue
            let upperValue = values[index].doubleValue
            return lowerValue + (upperValue - lowerValue) * localPhase
        }
        return values[values.count - 1].doubleValue
    }
}
