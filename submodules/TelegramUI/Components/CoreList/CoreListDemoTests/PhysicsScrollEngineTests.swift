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
}
