import XCTest
@testable import CoreListDemo

final class CoreListItemEqualityTests: XCTestCase {
    func testFixedHeightItem_sameHeight_isEqual() {
        let a = FixedHeightItem(height: 50)
        let b = FixedHeightItem(height: 50)
        XCTAssertTrue(a.isEqual(to: b))
    }

    func testFixedHeightItem_differentHeight_isNotEqual() {
        let a = FixedHeightItem(height: 50)
        let b = FixedHeightItem(height: 60)
        XCTAssertFalse(a.isEqual(to: b))
    }

    func testFixedHeightItem_vs_widthDependentItem_isNotEqual() {
        let a = FixedHeightItem(height: 50) as CoreListItem
        let b = WidthDependentItem(baseHeight: 50, baseWidth: 390) as CoreListItem
        XCTAssertFalse(a.isEqual(to: b))
    }

    func testDemoListItem_sameId_isEqual() {
        let id = UUID()
        let a = DemoListItem(id: id, title: "A", detail: "d1", accentColor: .red)
        let b = DemoListItem(id: id, title: "B", detail: "d2", accentColor: .blue)
        XCTAssertTrue(a.isEqual(to: b))
    }

    func testDemoListItem_differentId_isNotEqual() {
        let a = DemoListItem(id: UUID(), title: "A", detail: "d", accentColor: .red)
        let b = DemoListItem(id: UUID(), title: "A", detail: "d", accentColor: .red)
        XCTAssertFalse(a.isEqual(to: b))
    }
}
