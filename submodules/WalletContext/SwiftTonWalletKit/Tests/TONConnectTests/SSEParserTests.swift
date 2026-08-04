import XCTest
@testable import TONConnect

/// Adversarial tests for the SSE parser.
///
/// This parser sits on a long-lived connection receiving bytes in arbitrary chunks, so the
/// failure modes are all about boundaries: a field name, a `\r\n` pair, a frame separator,
/// or a multi-byte UTF-8 sequence split across two callbacks. Each of those silently
/// corrupts or drops a bridge message if handled wrongly — and a dropped message means a
/// dApp request the wallet never shows the user.
final class SSEParserTests: XCTestCase {
    private func parse(_ chunks: [String]) throws -> [SSEEvent] {
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for chunk in chunks {
            events += try parser.consume(Data(chunk.utf8))
        }
        return events
    }

    private func parse(_ text: String) throws -> [SSEEvent] {
        try parse([text])
    }

    // MARK: - Basics

    func testSingleFrame() throws {
        let events = try parse("data: hello\n\n")
        XCTAssertEqual(events, [SSEEvent(data: "hello")])
    }

    func testEventAndIDFields() throws {
        let events = try parse("event: message\ndata: payload\nid: 42\n\n")
        XCTAssertEqual(events, [SSEEvent(event: "message", data: "payload", id: "42")])
    }

    func testRetryField() throws {
        let events = try parse("data: x\nretry: 5000\n\n")
        XCTAssertEqual(events.first?.retry, 5000)
    }

    func testMultipleFrames() throws {
        let events = try parse("data: one\n\ndata: two\n\ndata: three\n\n")
        XCTAssertEqual(events.map(\.data), ["one", "two", "three"])
    }

    /// Multiple `data:` lines join with a newline, per the spec.
    func testMultipleDataLinesJoinWithNewline() throws {
        let events = try parse("data: line1\ndata: line2\ndata: line3\n\n")
        XCTAssertEqual(events.first?.data, "line1\nline2\nline3")
    }

    /// Exactly one leading space is stripped from a value; further spaces are content.
    func testOnlyOneLeadingSpaceIsStripped() throws {
        XCTAssertEqual(try parse("data: x\n\n").first?.data, "x")
        XCTAssertEqual(try parse("data:x\n\n").first?.data, "x")
        XCTAssertEqual(try parse("data:  x\n\n").first?.data, " x")
    }

    /// A field with no colon is a name with an empty value.
    func testFieldWithoutColon() throws {
        let events = try parse("data\n\n")
        XCTAssertEqual(events, [SSEEvent(data: "")])
    }

    /// Comment lines are keep-alive heartbeats and must not dispatch anything.
    func testCommentLinesAreIgnored() throws {
        let events = try parse(": heartbeat\ndata: real\n\n")
        XCTAssertEqual(events, [SSEEvent(data: "real")])
    }

    func testHeartbeatOnlyProducesNoEvents() throws {
        XCTAssertTrue(try parse(": ping\n\n: ping\n\n").isEmpty)
    }

    /// A frame with no data lines is not dispatched.
    func testFrameWithoutDataIsNotDispatched() throws {
        XCTAssertTrue(try parse("event: ping\n\n").isEmpty)
        XCTAssertTrue(try parse("id: 5\n\n").isEmpty)
    }

    func testUnknownFieldsAreIgnored() throws {
        let events = try parse("unknown: whatever\ndata: kept\n\n")
        XCTAssertEqual(events, [SSEEvent(data: "kept")])
    }

    // MARK: - Line terminators

    func testCRLFTerminators() throws {
        let events = try parse("data: hello\r\n\r\n")
        XCTAssertEqual(events, [SSEEvent(data: "hello")])
    }

    /// A lone `\r` terminates a line — but only once a following byte proves it is not
    /// the first half of a `\r\n`.
    func testLoneCRTerminatesMidStream() throws {
        // The trailing "x" forces the second \r to be resolved as a terminator.
        let events = try parse("data: hello\r\rdata: next\r\r\n")
        XCTAssertEqual(events.map(\.data), ["hello", "next"])
    }

    /// Input ending in a lone `\r` must leave the frame pending: a streaming parser
    /// cannot know whether `\n` follows in the next chunk. `finish()` is how a caller
    /// says the stream is over.
    func testTrailingLoneCRStaysPendingUntilFinish() throws {
        var parser = SSEParser()
        let events = try parser.consume(Data("data: hello\r\r".utf8))
        XCTAssertTrue(
            events.isEmpty,
            "a trailing \\r could still become \\r\\n, so nothing may be dispatched yet"
        )
        XCTAssertEqual(parser.finish(), SSEEvent(data: "hello"))
    }

    func testMixedTerminators() throws {
        let events = try parse("data: a\r\ndata: b\n\r\n")
        XCTAssertEqual(events.first?.data, "a\nb")
    }

    /// **The subtlest boundary case.** A `\r\n` split across chunks must not be read as
    /// two line breaks, which would dispatch the frame early and truncate it.
    func testCRLFSplitAcrossChunks() throws {
        let events = try parse(["data: hello\r", "\n\r\n"])
        XCTAssertEqual(
            events,
            [SSEEvent(data: "hello")],
            "a \\r\\n straddling two chunks is one line break, not two"
        )
    }

    /// The same split, but where treating the lone `\r` as a terminator would dispatch a
    /// frame that should still be accumulating.
    func testCRLFSplitDoesNotDispatchEarly() throws {
        var parser = SSEParser()
        let first = try parser.consume(Data("data: one\r".utf8))
        XCTAssertTrue(first.isEmpty, "a trailing \\r must not complete the frame yet")

        let second = try parser.consume(Data("\ndata: two\n\n".utf8))
        XCTAssertEqual(second.map(\.data), ["one\ntwo"], "both data lines belong to one frame")
    }

    // MARK: - Chunk boundaries

    /// Feeding one byte at a time must produce the same result as feeding it whole.
    func testByteByByteMatchesWholeInput() throws {
        let text = "event: message\ndata: {\"id\":\"1\"}\nid: 7\nretry: 100\n\ndata: second\n\n"
        let whole = try parse(text)
        let byByte = try parse(Array(text).map(String.init))
        XCTAssertEqual(byByte, whole, "chunking must not change the result")
        XCTAssertEqual(whole.count, 2)
    }

    /// Every possible split point must yield the same events.
    func testEverySplitPointIsEquivalent() throws {
        let text = "event: e\ndata: d1\ndata: d2\nid: 9\n\ndata: next\n\n"
        let expected = try parse(text)
        let bytes = Array(text.utf8)

        for cut in 0...bytes.count {
            var parser = SSEParser()
            var events: [SSEEvent] = []
            events += try parser.consume(Data(bytes[0..<cut]))
            events += try parser.consume(Data(bytes[cut...]))
            XCTAssertEqual(events, expected, "split at byte \(cut) changed the result")
        }
    }

    /// A field name split across chunks must not be truncated into a different field.
    func testFieldNameSplitAcrossChunks() throws {
        let events = try parse(["da", "ta: value\n", "\n"])
        XCTAssertEqual(events, [SSEEvent(data: "value")])
    }

    /// A frame separator split across chunks must still dispatch exactly once.
    func testFrameSeparatorSplitAcrossChunks() throws {
        let events = try parse(["data: a\n", "\n", "data: b\n", "\n"])
        XCTAssertEqual(events.map(\.data), ["a", "b"])
    }

    // MARK: - UTF-8

    /// A multi-byte character split across chunks must survive intact.
    ///
    /// Decoding per chunk instead of per line would corrupt it into replacement
    /// characters — and bridge payloads are JSON that may carry any text.
    func testMultiByteCharacterSplitAcrossChunks() throws {
        let text = "data: Привет 🌍\n\n"
        let bytes = Array(text.utf8)

        // Split inside the multi-byte sequences specifically.
        for cut in 6..<bytes.count {
            var parser = SSEParser()
            var events: [SSEEvent] = []
            events += try parser.consume(Data(bytes[0..<cut]))
            events += try parser.consume(Data(bytes[cut...]))
            XCTAssertEqual(
                events.first?.data,
                "Привет 🌍",
                "UTF-8 split at byte \(cut) was corrupted"
            )
        }
    }

    func testEmojiAndCJKSurvive() throws {
        let payload = "🚀 日本語 ✅ Ω"
        XCTAssertEqual(try parse("data: \(payload)\n\n").first?.data, payload)
    }

    // MARK: - Realistic bridge traffic

    /// What an actual TON Connect bridge sends: base64 envelopes with a `from` field,
    /// interleaved with heartbeats.
    func testRealisticBridgeStream() throws {
        let stream = """
        : heartbeat

        event: message
        id: 1712345678901
        data: {"from":"aabb","message":"BASE64PAYLOAD=="}

        : heartbeat

        event: message
        id: 1712345678902
        data: {"from":"aabb","message":"ANOTHER=="}


        """
        let events = try parse(stream)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].id, "1712345678901")
        XCTAssertEqual(events[1].id, "1712345678902")
        XCTAssertTrue(events[0].data.contains("BASE64PAYLOAD"))
        XCTAssertEqual(events.map(\.event), ["message", "message"])
    }

    /// A large single frame must not be split or dropped — bridge payloads can carry a
    /// whole transaction BoC.
    func testLargeFrame() throws {
        let payload = String(repeating: "A", count: 200_000)
        let events = try parse("data: \(payload)\n\n")
        XCTAssertEqual(events.first?.data.count, payload.count)
    }

    // MARK: - Safety

    /// A peer that never sends a frame boundary must not be able to exhaust memory.
    func testBufferOverflowIsBounded() throws {
        var parser = SSEParser(maxBufferBytes: 1024)
        XCTAssertThrowsError(
            try parser.consume(Data(String(repeating: "x", count: 2048).utf8))
        ) { error in
            guard case SSEParser.ParseError.bufferOverflow = error else {
                return XCTFail("expected bufferOverflow, got \(error)")
            }
        }
    }

    /// An `id` containing NUL must be ignored, per the spec.
    func testIDWithNulIsIgnored() throws {
        let events = try parse("data: x\nid: bad\0id\n\n")
        XCTAssertNil(events.first?.id)
    }

    func testNegativeRetryIsIgnored() throws {
        XCTAssertNil(try parse("data: x\nretry: -5\n\n").first?.retry)
        XCTAssertNil(try parse("data: x\nretry: notanumber\n\n").first?.retry)
    }

    /// A stream ending without a trailing blank line still has a usable frame.
    func testFinishDispatchesTrailingFrame() throws {
        var parser = SSEParser()
        let events = try parser.consume(Data("data: unterminated\n".utf8))
        XCTAssertTrue(events.isEmpty, "no blank line yet, so nothing dispatched")

        let trailing = parser.finish()
        XCTAssertEqual(trailing, SSEEvent(data: "unterminated"))
    }

    func testFinishReturnsNilWhenNothingBuffered() throws {
        var parser = SSEParser()
        _ = try parser.consume(Data("data: complete\n\n".utf8))
        XCTAssertNil(parser.finish())
    }

    func testEmptyChunksAreHarmless() throws {
        var parser = SSEParser()
        XCTAssertTrue(try parser.consume(Data()).isEmpty)
        XCTAssertTrue(try parser.consume(Data()).isEmpty)
        let events = try parser.consume(Data("data: x\n\n".utf8))
        XCTAssertEqual(events.map(\.data), ["x"])
    }

    /// Consecutive blank lines must not emit empty frames.
    func testConsecutiveBlankLinesEmitNothing() throws {
        let events = try parse("\n\n\n\ndata: real\n\n\n\n")
        XCTAssertEqual(events.map(\.data), ["real"])
    }

    func testFieldSplitting() {
        XCTAssertEqual(SSEParser.splitField("data: x").field, "data")
        XCTAssertEqual(SSEParser.splitField("data: x").value, "x")
        XCTAssertEqual(SSEParser.splitField("data:").value, "")
        XCTAssertEqual(SSEParser.splitField("noColon").field, "noColon")
        XCTAssertEqual(SSEParser.splitField("noColon").value, "")
        // A value containing colons keeps them.
        XCTAssertEqual(SSEParser.splitField("data: {\"a\":\"b\"}").value, "{\"a\":\"b\"}")
    }
}
