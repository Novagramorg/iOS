import Foundation
import XCTest
@testable import Postbox

private struct Item: Codable, Equatable {
    var id: Int32
    var name: String
}

/// The generic `encodeArray` / `decodeArray` pair on `PostboxEncoder` / `PostboxDecoder`
/// must use the same `.ObjectArray` wire format as every other writer and reader of that
/// value type: `[Int32 count]` then, per element, `[Int32 typeHash][Int32 length][payload]`.
/// `positionOnKey` walks exactly that layout to skip over the value, so a writer that
/// deviates from it also breaks every key that follows.
final class PostboxCodingArrayTests: XCTestCase {
    private func roundTrip(_ items: [Item]) -> [Item]? {
        let encoder = PostboxEncoder()
        encoder.encodeArray(items, forKey: "items")
        let decoder = PostboxDecoder(buffer: encoder.memoryBuffer())
        return decoder.decodeArray([Item].self, forKey: "items")
    }

    func testEncodeArrayDecodeArrayRoundTripsEveryElement() {
        let items = [Item(id: 1, name: "one"), Item(id: 2, name: "two"), Item(id: 3, name: "three")]

        XCTAssertEqual(self.roundTrip(items), items)
    }

    func testEncodeArrayDecodeArrayRoundTripsAnEmptyArray() {
        XCTAssertEqual(self.roundTrip([]), [])
    }

    func testKeysAfterAnEncodedArrayRemainReachable() {
        let encoder = PostboxEncoder()
        encoder.encodeArray([Item(id: 1, name: "one"), Item(id: 2, name: "two")], forKey: "items")
        encoder.encodeInt32(7, forKey: "after")

        let decoder = PostboxDecoder(buffer: encoder.memoryBuffer())

        XCTAssertEqual(decoder.decodeOptionalInt32ForKey("after"), 7)
    }

    func testDecodeArrayReadsAnArrayWrittenByTheCodableAdapter() {
        struct Outer: Codable {
            var items: [Item]
        }
        let items = [Item(id: 10, name: "ten"), Item(id: 20, name: "twenty")]

        let encoder = PostboxEncoder()
        encoder.encode(Outer(items: items), forKey: "outer")
        let outerDecoder = PostboxDecoder(buffer: encoder.memoryBuffer())
        guard let (outerData, _) = outerDecoder.decodeObjectDataForKey("outer") else {
            return XCTFail("outer object not found")
        }

        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: outerData))

        XCTAssertEqual(decoder.decodeArray([Item].self, forKey: "items"), items)
    }
}
