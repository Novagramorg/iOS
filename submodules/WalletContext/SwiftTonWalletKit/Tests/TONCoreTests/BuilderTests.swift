import XCTest
import TONTestVectors
@testable import TONCore

/// Golden vectors for the snake-string spill, generated from `@ton/core`.
///
/// `storeStringTail` originally called `storeBytes` directly and threw on anything longer than
/// the remaining space — around 120 characters for a transfer comment, so an ordinary
/// user-typed message failed to build. The reference fills the current cell and spills the rest
/// into a reference chain.
///
/// Loaded from generated vectors rather than pasted literals. The first version of this file
/// hand-copied base64 out of terminal output and silently lost four characters from one case,
/// which is precisely the failure mode generated vectors exist to remove.
final class SnakeStringVectorTests: XCTestCase {
    struct SnakeVector: Decodable {
        let label: String
        let text: String
        let byteLength: Int
        /// `storeStringTail` into an empty cell.
        let plainBoc: String
        /// After a 32-bit opcode — the shape a transfer comment takes, which shifts the
        /// spill boundary by four bytes.
        let commentBoc: String
    }

    private func vectors() throws -> [SnakeVector] {
        try Vectors.load("snake-strings")
    }

    func testStoreStringTailMatchesTheReference() throws {
        let all = try vectors()
        XCTAssertGreaterThan(all.count, 5, "expected a populated vector file")

        for vector in all {
            let plain = try beginCell().storeStringTail(vector.text).endCell()
            XCTAssertEqual(
                plain.toBocBase64(), vector.plainBoc,
                "plain storeStringTail diverged for \(vector.label)"
            )

            let comment = try beginCell()
                .storeUInt(0, bits: 32)
                .storeStringTail(vector.text)
                .endCell()
            XCTAssertEqual(
                comment.toBocBase64(), vector.commentBoc,
                "comment payload diverged for \(vector.label)"
            )
        }
    }

    /// Every case must also read back as the text that went in.
    func testRoundTrips() throws {
        for vector in try vectors() {
            var slice = try beginCell().storeStringTail(vector.text).endCell().beginParse()
            XCTAssertEqual(try slice.loadStringTail(), vector.text, vector.label)
        }
    }

    /// The vectors must actually cross the spill boundary, or they prove nothing about the
    /// behaviour that was broken.
    func testVectorsCoverTheSpillBoundary() throws {
        var withRefs = 0
        var withoutRefs = 0
        for vector in try vectors() {
            let cell = try beginCell().storeStringTail(vector.text).endCell()
            if cell.refs.isEmpty { withoutRefs += 1 } else { withRefs += 1 }
        }
        XCTAssertGreaterThan(withRefs, 0, "no vector spills into a reference")
        XCTAssertGreaterThan(withoutRefs, 0, "no vector fits in a single cell")
    }

    /// The boundary depends on what is already in the cell.
    func testSpillBoundaryAccountsForExistingContent() throws {
        let exact = try beginCell().storeStringTail(String(repeating: "a", count: 127)).endCell()
        XCTAssertTrue(exact.refs.isEmpty, "127 bytes fits an empty cell without spilling")

        let shifted = try beginCell()
            .storeUInt(0, bits: 32)
            .storeStringTail(String(repeating: "a", count: 127))
            .endCell()
        XCTAssertEqual(shifted.refs.count, 1, "the opcode should push four bytes into a ref")
    }
}
