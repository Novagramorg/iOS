import Foundation

/// One Server-Sent Events frame.
public struct SSEEvent: Hashable, Sendable {
    /// The `event:` field, or nil when the frame did not set one.
    public let event: String?
    /// The `data:` field. Multiple `data:` lines join with newlines, per the spec.
    public let data: String
    /// The `id:` field. Persisted as `Last-Event-ID` so a reconnect resumes.
    public let id: String?
    /// The `retry:` field, in milliseconds.
    public let retry: Int?

    public init(event: String? = nil, data: String, id: String? = nil, retry: Int? = nil) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
}

/// Incremental Server-Sent Events parser.
///
/// Hand-written because `URLSession.bytes(for:)` is iOS 15 and our floor is iOS 13. It is
/// also the better choice for a long-lived stream: it gives explicit control over
/// buffering and cancellation.
///
/// The hard part is that bytes arrive in arbitrary chunks. A field name, a `\r\n` pair, a
/// frame boundary, or a multi-byte UTF-8 sequence can all be split across two `didReceive`
/// callbacks, so nothing may be decoded until a boundary is actually seen.
public struct SSEParser: Sendable {
    /// Accumulated bytes not yet forming a complete frame.
    private var buffer: Data
    /// Frame under construction.
    private var pendingData: [String]
    private var pendingEvent: String?
    private var pendingID: String?
    private var pendingRetry: Int?

    /// Guards against unbounded growth if a peer never sends a frame boundary.
    public let maxBufferBytes: Int

    public init(maxBufferBytes: Int = 4 * 1024 * 1024) {
        self.buffer = Data()
        self.pendingData = []
        self.maxBufferBytes = maxBufferBytes
    }

    public enum ParseError: Error, CustomStringConvertible {
        case bufferOverflow(Int)

        public var description: String {
            switch self {
            case .bufferOverflow(let limit):
                return "SSE buffer exceeded \(limit) bytes without a frame boundary"
            }
        }
    }

    /// Feeds a chunk and returns whatever complete frames it produced.
    ///
    /// Bytes that do not yet form a complete line are retained for the next call, so this
    /// is safe to call with arbitrarily small or large chunks.
    public mutating func consume(_ chunk: Data) throws -> [SSEEvent] {
        buffer.append(chunk)
        guard buffer.count <= maxBufferBytes else {
            throw ParseError.bufferOverflow(maxBufferBytes)
        }

        var events: [SSEEvent] = []

        // Only consume up to the last complete line; anything after stays buffered.
        while let lineEnd = nextLineEnd() {
            let lineBytes = buffer.prefix(lineEnd.lineLength)
            buffer.removeFirst(lineEnd.consumed)

            // Decode per line rather than per chunk, so a multi-byte character split
            // across chunks is already whole by the time we decode.
            let line = String(decoding: Data(lineBytes))

            if line.isEmpty {
                // A blank line dispatches the frame — but only if it has content.
                if let event = takePendingEvent() {
                    events.append(event)
                }
                continue
            }

            // A leading colon marks a comment, used for keep-alive heartbeats.
            //
            // Strictly redundant: a comment splits into an empty field name, which falls
            // through to the ignore-unknown-fields path below. Kept because heartbeats are
            // the single most common line on a live bridge, and naming them here is
            // clearer than leaving a reader to derive it. Verified equivalent by mutation.
            if line.hasPrefix(":") { continue }

            let (field, value) = Self.splitField(line)
            switch field {
            case "data":
                pendingData.append(value)
            case "event":
                pendingEvent = value
            case "id":
                // The spec says an id containing NUL must be ignored.
                if !value.contains("\0") { pendingID = value }
            case "retry":
                if let ms = Int(value), ms >= 0 { pendingRetry = ms }
            default:
                // Unknown fields are ignored, which keeps us forward-compatible.
                break
            }
        }

        return events
    }

    /// Dispatches any frame still buffered, for use when the stream ends cleanly.
    public mutating func finish() -> SSEEvent? {
        takePendingEvent()
    }

    /// Whether any partial frame or bytes remain.
    public var hasBufferedInput: Bool {
        !buffer.isEmpty || !pendingData.isEmpty || pendingEvent != nil
    }

    // MARK: - Internals

    private mutating func takePendingEvent() -> SSEEvent? {
        // A frame with no data lines is not dispatched, per the spec. An `id:`-only frame
        // still updates the last-event id, which is why that is tracked separately.
        guard !pendingData.isEmpty else {
            pendingEvent = nil
            pendingRetry = nil
            return nil
        }
        let event = SSEEvent(
            event: pendingEvent,
            // Multiple data lines join with newline.
            data: pendingData.joined(separator: "\n"),
            id: pendingID,
            retry: pendingRetry
        )
        pendingData = []
        pendingEvent = nil
        pendingRetry = nil
        return event
    }

    private struct LineEnd {
        /// Bytes in the line itself, excluding the terminator.
        let lineLength: Int
        /// Bytes to remove, including the terminator.
        let consumed: Int
    }

    /// Finds the next line terminator: `\n`, `\r\n`, or a lone `\r`.
    ///
    /// A trailing lone `\r` at the very end of the buffer is *not* treated as a
    /// terminator, because the next chunk may begin with `\n` — consuming it early would
    /// split one `\r\n` into two line breaks and dispatch a frame prematurely.
    private func nextLineEnd() -> LineEnd? {
        let bytes = buffer
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            let offset = bytes.distance(from: bytes.startIndex, to: index)

            if byte == 0x0a { // \n
                return LineEnd(lineLength: offset, consumed: offset + 1)
            }
            if byte == 0x0d { // \r
                let next = bytes.index(after: index)
                if next == bytes.endIndex {
                    // Might be the first half of \r\n; wait for more bytes.
                    return nil
                }
                if bytes[next] == 0x0a {
                    return LineEnd(lineLength: offset, consumed: offset + 2)
                }
                return LineEnd(lineLength: offset, consumed: offset + 1)
            }
            index = bytes.index(after: index)
        }
        return nil
    }

    /// Splits `field: value`, stripping exactly one leading space from the value.
    ///
    /// A line with no colon is a field name with an empty value, per the spec.
    static func splitField(_ line: String) -> (field: String, value: String) {
        guard let colon = line.firstIndex(of: ":") else {
            return (line, "")
        }
        let field = String(line[line.startIndex..<colon])
        var value = String(line[line.index(after: colon)...])
        if value.hasPrefix(" ") { value.removeFirst() }
        return (field, value)
    }
}

extension String {
    /// Lossy UTF-8 decode, so one malformed byte cannot kill a long-lived stream.
    fileprivate init(decoding data: Data) {
        if let s = String(data: data, encoding: .utf8) {
            self = s
        } else {
            self = String(decoding: data, as: UTF8.self)
        }
    }
}
