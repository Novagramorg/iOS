import XCTest
import UIKit
@testable import CoreListDemo

struct MixedPassLiveSnapshot: Equatable {
    let renderedFrame: CGRect
    let settledFrame: CGRect
    let opacity: CGFloat
    let tracks: [ListAnimatedProperty: ListAnimationTrack]
}

struct MixedPassBoundarySnapshot: Equatable {
    var live: [AnyHashable: MixedPassLiveSnapshot]
    let viewportTrack: ListAnimationTrack?
    let viewportCorrection: CGFloat

    static let empty = Self(
        live: [:],
        viewportTrack: nil,
        viewportCorrection: 0
    )
}

enum MixedPassOracleError: Error {
    case missingAnimation(ListAnimatedProperty)
    case wrongGeneration
    case wrongClock
    case wrongEndpoints
    case wrongMapping
}

final class MixedPassStressOracle {
    static let properties: [ListAnimatedProperty] = [
        .positionX, .positionY, .width, .height, .opacity,
    ]

    func capture(fixture: VirtualListFixture) -> MixedPassBoundarySnapshot {
        let now = fixture.animationController.now()
        var live: [AnyHashable: MixedPassLiveSnapshot] = [:]

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            let renderedX = item.frame.minX
                + (fixture.animationController.positionOffsetX(
                    identity: identity,
                    at: now
                ) ?? 0)
            let renderedY = fixture.screenY(identity: identity) ?? 0
            let renderedWidth = fixture.animationController.width(
                identity: identity,
                at: now
            ) ?? item.frame.width
            let renderedHeight = fixture.animationController.height(
                identity: identity,
                at: now
            ) ?? item.frame.height
            let opacity = fixture.animationController.opacity(
                owner: .live(identity),
                at: now
            ) ?? 1
            let tracks = Dictionary(
                uniqueKeysWithValues: Self.properties.compactMap { property in
                    fixture.animationController.model.track(
                        for: .live(identity),
                        property: property
                    ).map { (property, $0) }
                }
            )
            let settledY = fixture.settledScreenY(identity: identity)
                ?? item.frame.minY

            live[identity] = MixedPassLiveSnapshot(
                renderedFrame: CGRect(
                    x: renderedX,
                    y: renderedY,
                    width: renderedWidth,
                    height: renderedHeight
                ),
                settledFrame: CGRect(
                    x: item.frame.minX,
                    y: settledY,
                    width: item.frame.width,
                    height: item.frame.height
                ),
                opacity: opacity,
                tracks: tracks
            )
        }

        return MixedPassBoundarySnapshot(
            live: live,
            viewportTrack: fixture.viewportTrack,
            viewportCorrection: fixture.viewportCorrection
        )
    }

    func assertBoundary(
        before: MixedPassBoundarySnapshot,
        after: MixedPassBoundarySnapshot,
        step: MixedPassStep,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard step.transition.duration > 0 else { return }
        let shared = Set(before.live.keys).intersection(after.live.keys)

        for identity in shared {
            guard let old = before.live[identity],
                  let new = after.live[identity] else {
                continue
            }
            assertEqual(
                old.renderedFrame,
                new.renderedFrame,
                accuracy: 1e-5,
                "\(context)\nidentity=\(identity) lost C0 frame continuity",
                file: file,
                line: line
            )
            XCTAssertEqual(
                old.opacity,
                new.opacity,
                accuracy: 1e-5,
                "\(context)\nidentity=\(identity) lost C0 opacity continuity",
                file: file,
                line: line
            )

            assertProperty(
                .positionX,
                oldTarget: old.settledFrame.minX,
                newTarget: new.settledFrame.minX,
                expectedFrom: old.renderedFrame.minX - new.settledFrame.minX,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .positionY,
                oldTarget: old.settledFrame.minY,
                newTarget: new.settledFrame.minY,
                expectedFrom: old.renderedFrame.minY - new.settledFrame.minY,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .width,
                oldTarget: old.settledFrame.width,
                newTarget: new.settledFrame.width,
                expectedFrom: old.renderedFrame.width,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .height,
                oldTarget: old.settledFrame.height,
                newTarget: new.settledFrame.height,
                expectedFrom: old.renderedFrame.height,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )

            XCTAssertEqual(
                old.tracks[.opacity],
                new.tracks[.opacity],
                "\(context)\nidentity=\(identity) changed an unchanged opacity track",
                file: file,
                line: line
            )
        }
    }

    func assertWindow(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windowItems = fixture.activeWindow.items
        let indices = windowItems.map(\.index)

        if let first = indices.first, let last = indices.last {
            XCTAssertEqual(
                indices,
                Array(first...last),
                "\(context)\nactive window indices are not contiguous",
                file: file,
                line: line
            )
        }
        for index in indices {
            XCTAssertTrue(
                fixture.listView.items.indices.contains(index),
                "\(context)\nloaded index \(index) is out of range",
                file: file,
                line: line
            )
        }
        let identities = indices.map { fixture.listView.items[$0].identity }
        XCTAssertEqual(
            Set(identities).count,
            identities.count,
            "\(context)\nactive window contains duplicate identities",
            file: file,
            line: line
        )

        for item in windowItems {
            XCTAssertTrue(
                item.frame.isFinite,
                "\(context)\nnon-finite frame at index \(item.index): \(item.frame)",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                item.frame.width,
                0,
                "\(context)\nnegative width at index \(item.index)",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                item.frame.height,
                0,
                "\(context)\nnegative height at index \(item.index)",
                file: file,
                line: line
            )
        }
        for pair in zip(windowItems, windowItems.dropFirst()) {
            XCTAssertEqual(
                pair.0.frame.maxY,
                pair.1.frame.minY,
                accuracy: 1e-5,
                "\(context)\nsettled frames are not contiguous between "
                    + "\(pair.0.index) and \(pair.1.index)",
                file: file,
                line: line
            )
        }
    }

    func assertInstalledAnimations(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var observed: [ListAnimationOwner: CALayer] = [
            .viewport: fixture.listView.engine.contentHost.layer,
        ]

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            observed[.live(identity)] = item.view.layer
        }
        for identity in fixture.crossingCarryIdentities {
            if let view = fixture.crossingCarryView(identity: identity) {
                observed[.live(identity)] = view.layer
            }
        }
        for block in fixture.ghostBlocks {
            if let render = fixture.listView.ghostRender(for: block.id) {
                observed[render.owner] = render.wrapper.layer
            }
        }
        for member in fixture.listView.ghostMemberHorizontalSnapshots {
            observed[member.owner] = member.view.layer
        }

        for (owner, layer) in observed {
            let properties = owner == .viewport
                ? [ListAnimatedProperty.viewportOffset]
                : Self.properties
            for property in properties {
                let track = fixture.animationController.model.track(
                    for: owner,
                    property: property
                )
                let key = fixture.animationController.compiler.animationKey(
                    for: property
                )
                let animation = layer.animation(forKey: key)

                if let track {
                    do {
                        try Self.validateTrack(
                            expected: track,
                            animation: animation,
                            property: property
                        )
                    } catch {
                        XCTFail(
                            "\(context)\nowner=\(owner) property=\(property) "
                                + "CA/model mismatch: \(error)",
                            file: file,
                            line: line
                        )
                    }
                } else {
                    XCTAssertNil(
                        animation,
                        "\(context)\nowner=\(owner) property=\(property) "
                            + "has stale installed animation",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    func settle(fixture: VirtualListFixture, max: TimeInterval) {
        fixture.animationController.reapSettledTracks()
        _ = fixture.runUntilSettled(max: max)
        fixture.animationController.reapSettledTracks()
    }

    func assertSettled(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertWindow(fixture: fixture, context: context, file: file, line: line)
        let now = fixture.animationController.now()

        XCTAssertFalse(
            fixture.hasActiveAnimations,
            "\(context)\nanalytic animations remain active",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.crossingCarryIdentities.isEmpty,
            "\(context)\ncrossing carries remain after settlement",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.viewportCarryViews.isEmpty,
            "\(context)\nviewport carries remain after settlement",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.ghostBlocks.isEmpty,
            "\(context)\nghost blocks remain after settlement",
            file: file,
            line: line
        )
        XCTAssertNil(
            fixture.viewportTrack,
            "\(context)\nviewport track remains after settlement",
            file: file,
            line: line
        )
        XCTAssertEqual(
            fixture.viewportCorrection,
            0,
            accuracy: 1e-6,
            "\(context)\nviewport correction did not settle to zero",
            file: file,
            line: line
        )

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            for property in Self.properties {
                XCTAssertNil(
                    fixture.animationController.model.track(
                        for: .live(identity),
                        property: property
                    ),
                    "\(context)\nidentity=\(identity) property=\(property) "
                        + "retained a settled track",
                    file: file,
                    line: line
                )
            }
            XCTAssertEqual(
                fixture.animationController.positionOffsetX(
                    identity: identity,
                    at: now
                ) ?? 0,
                0,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) x correction did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.positionOffset(
                    identity: identity,
                    at: now
                ) ?? 0,
                0,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) y correction did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.opacity(
                    owner: .live(identity),
                    at: now
                ) ?? 1,
                1,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) opacity did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.width(identity: identity, at: now)
                    ?? item.frame.width,
                item.frame.width,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) width did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.height(identity: identity, at: now)
                    ?? item.frame.height,
                item.frame.height,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) height did not settle",
                file: file,
                line: line
            )
        }
    }

    static func validateTrack(
        expected: ListAnimationTrack,
        animation: CAAnimation?,
        property: ListAnimatedProperty
    ) throws {
        guard let animation = animation as? CABasicAnimation else {
            throw MixedPassOracleError.missingAnimation(property)
        }
        guard (animation.value(
            forKey: "CoreListAnimation.generation"
        ) as? NSNumber)?.uint64Value == expected.generation else {
            throw MixedPassOracleError.wrongGeneration
        }
        guard abs(animation.beginTime - expected.startTime) < 1e-9 else {
            throw MixedPassOracleError.wrongClock
        }
        // A system spring's `animation.duration` is the spring's own settling duration, not the
        // track's — `speed` maps it onto the pass duration — so the track duration is not expected to
        // appear on the animation. No current scenario emits one (MixedPassScenario alternates
        // .easeInOut and .linear); the guard is here so one that does fails clearly rather than as a
        // baffling duration mismatch.
        if expected.springKind == .adjustedBezier {
            guard abs(animation.duration - expected.duration) < 1e-9 else {
                throw MixedPassOracleError.wrongClock
            }
        }
        // Endpoints are now fromValue/toValue on a CABasicAnimation rather than the first and last
        // entries of a sampled keyframe array.
        guard let first = animation.fromValue as? NSNumber,
              let last = animation.toValue as? NSNumber,
              abs(first.doubleValue - Double(expected.from)) < 1e-6,
              abs(last.doubleValue - Double(expected.to)) < 1e-6 else {
            throw MixedPassOracleError.wrongEndpoints
        }

        let expectedMapping: (keyPath: String, additive: Bool)
        switch property {
        case .viewportOffset:
            expectedMapping = ("bounds.origin.y", true)
        case .positionX:
            expectedMapping = ("position.x", true)
        case .positionY:
            expectedMapping = ("position.y", true)
        case .width:
            expectedMapping = ("bounds.size.width", false)
        case .height:
            expectedMapping = ("bounds.size.height", false)
        case .opacity:
            expectedMapping = ("opacity", false)
        }
        guard animation.keyPath == expectedMapping.keyPath,
              animation.isAdditive == expectedMapping.additive else {
            throw MixedPassOracleError.wrongMapping
        }
    }

    private func assertProperty(
        _ property: ListAnimatedProperty,
        oldTarget: CGFloat,
        newTarget: CGFloat,
        expectedFrom: CGFloat,
        old: MixedPassLiveSnapshot,
        new: MixedPassLiveSnapshot,
        step: MixedPassStep,
        identity: AnyHashable,
        context: String,
        file: StaticString,
        line: UInt
    ) {
        if abs(oldTarget - newTarget) <= 1e-6 {
            XCTAssertEqual(
                old.tracks[property],
                new.tracks[property],
                "\(context)\nidentity=\(identity) property=\(property) "
                    + "replaced an unchanged track",
                file: file,
                line: line
            )
            return
        }

        guard let track = new.tracks[property] else {
            XCTFail(
                "\(context)\nidentity=\(identity) property=\(property) "
                    + "changed target without a replacement track",
                file: file,
                line: line
            )
            return
        }
        XCTAssertEqual(
            track.from,
            expectedFrom,
            accuracy: 1e-5,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "did not start from analytic presentation",
            file: file,
            line: line
        )
        XCTAssertEqual(
            track.duration,
            step.transition.duration,
            accuracy: 1e-9,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "used the wrong pass duration",
            file: file,
            line: line
        )
        XCTAssertEqual(
            track.curve,
            step.transition.curve,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "used the wrong pass curve",
            file: file,
            line: line
        )
    }

    private func assertEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        accuracy: CGFloat,
        _ message: String,
        file: StaticString,
        line: UInt
    ) {
        XCTAssertEqual(
            lhs.minX, rhs.minX, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.minY, rhs.minY, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.width, rhs.width, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.height, rhs.height, accuracy: accuracy,
            message, file: file, line: line
        )
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}
