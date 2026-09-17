import XCTest
import SwiftSignalKit
@testable import AnimatedStickerNode

// The cached-animation format is a 20-byte header followed by
// [Int32 frameLength][frameLength bytes of LZFSE] per frame. Every field comes
// straight off disk, so a truncated or corrupted cache file must be rejected
// rather than trusted — App Store crash reports show SIGSEGV inside
// AnimatedStickerCachedFrameSource.takeFrame(draw:).
private func makeHeader(
    frameRate: Int32 = 30,
    frameCount: Int32 = 1,
    width: Int32 = 64,
    height: Int32 = 64,
    bytesPerRow: Int32 = 256
) -> Data {
    var data = Data()
    for value in [frameRate, frameCount, width, height, bytesPerRow] {
        var v = value
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }
    return data
}

private func appendInt32(_ value: Int32, to data: inout Data) {
    var v = value
    withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
}

final class AnimatedStickerFrameSourceTests: XCTestCase {
    // A negative frameLength passes `offset + 4 + Int(frameLength) > dataLength`
    // and then reaches compression_decode_buffer, where it is widened to size_t —
    // an enormous out-of-bounds read. This is the crash seen in production.
    func testNegativeFrameLengthIsRejected() {
        var data = makeHeader()
        appendInt32(-1, to: &data)
        data.append(Data(count: 64))

        guard let source = AnimatedStickerCachedFrameSource(
            queue: Queue.mainQueue(), data: data, complete: true, notifyUpdated: {}
        ) else {
            return
        }
        XCTAssertNil(source.takeFrame(draw: true))
    }

    // A frameLength larger than the remaining bytes must not be decoded either.
    func testOversizedFrameLengthIsRejected() {
        var data = makeHeader()
        appendInt32(Int32(1 << 20), to: &data)
        data.append(Data(count: 16))

        guard let source = AnimatedStickerCachedFrameSource(
            queue: Queue.mainQueue(), data: data, complete: true, notifyUpdated: {}
        ) else {
            return
        }
        XCTAssertNil(source.takeFrame(draw: true))
    }

    // Anything shorter than the 20-byte header is read out of bounds today.
    func testTruncatedHeaderIsRejected() {
        for byteCount in [0, 1, 7, 19] {
            XCTAssertNil(AnimatedStickerCachedFrameSource(
                queue: Queue.mainQueue(), data: Data(count: byteCount), complete: true, notifyUpdated: {}
            ), "\(byteCount)-byte file should be rejected")
        }
    }

    // Dimensions come off disk unvalidated; negative ones reach
    // Data(count: bytesPerRow * height) and trap.
    func testNonsensicalHeaderValuesAreRejected() {
        let cases: [(String, Data)] = [
            ("negative width", makeHeader(width: -1)),
            ("negative height", makeHeader(height: -1)),
            ("negative bytesPerRow", makeHeader(bytesPerRow: -1)),
            ("zero dimensions", makeHeader(width: 0, height: 0, bytesPerRow: 0)),
            ("bytesPerRow below width", makeHeader(width: 64, bytesPerRow: 4)),
            ("negative frameCount", makeHeader(frameCount: -1)),
        ]
        for (name, header) in cases {
            XCTAssertNil(AnimatedStickerCachedFrameSource(
                queue: Queue.mainQueue(), data: header, complete: true, notifyUpdated: {}
            ), "\(name) should be rejected")
        }
    }
}
