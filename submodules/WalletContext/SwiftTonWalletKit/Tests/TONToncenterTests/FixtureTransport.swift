import Foundation
import TONTestVectors
@testable import TONToncenter

/// Replays recorded Toncenter responses, so the client is exercised against real server
/// output with no network and no API key.
///
/// Recorded by `Tools/fixturegen`. Each fixture carries the call arguments, every HTTP
/// request the reference issued, and either the mapped result or the error.
struct FixtureTransport: Transport {
    /// Recorded responses keyed by path (query ignored), in recording order.
    private let byPath: [String: [Recorded]]
    /// Tracks how many times each path has been served, so repeated calls walk the
    /// recorded sequence rather than replaying the first response forever.
    private let cursor: Cursor

    final class Cursor: @unchecked Sendable {
        private var counts: [String: Int] = [:]
        private let lock = NSLock()

        func next(_ path: String) -> Int {
            lock.lock()
            defer { lock.unlock() }
            let value = counts[path] ?? 0
            counts[path] = value + 1
            return value
        }
    }

    struct Recorded {
        let status: Int
        let body: Data
    }

    enum FixtureError: Error, CustomStringConvertible {
        case noRecordingForPath(String, available: [String])

        var description: String {
            switch self {
            case .noRecordingForPath(let path, let available):
                return """
                No recorded response for "\(path)". Recorded paths: \
                \(available.sorted().joined(separator: ", "))
                """
            }
        }
    }

    init(network: String) throws {
        var collected: [String: [Recorded]] = [:]

        for file in Self.fixtureFiles {
            guard let data = try? Vectors.rawFixture("toncenter/\(network)/\(file)") else { continue }
            let decoded = try JSONDecoder().decode(FixtureFile.self, from: data)
            for fixture in decoded.fixtures {
                for request in fixture.requests {
                    // Key on the path alone: query strings vary with discovered accounts,
                    // and the client under test builds its own.
                    let path = String(request.url.split(separator: "?")[0])
                    let body = try JSONSerialization.data(withJSONObject: request.body.value)
                    collected[path, default: []].append(
                        Recorded(status: request.status, body: body)
                    )
                }
            }
        }

        self.byPath = collected
        self.cursor = Cursor()
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        guard let recordings = byPath[request.path], !recordings.isEmpty else {
            throw FixtureError.noRecordingForPath(request.path, available: Array(byPath.keys))
        }
        // Walk the recorded sequence, then hold at the last entry.
        let index = min(cursor.next(request.path), recordings.count - 1)
        let recorded = recordings[index]
        return TransportResponse(status: recorded.status, body: recorded.body)
    }

    /// Serves one specific recorded body, for tests that need a known response.
    static func serving(_ json: Any, status: Int = 200) throws -> some Transport {
        SingleResponseTransport(
            response: TransportResponse(
                status: status,
                body: try JSONSerialization.data(withJSONObject: json)
            )
        )
    }

    static func failing(status: Int, body: String = "{}") -> some Transport {
        SingleResponseTransport(
            response: TransportResponse(status: status, body: Data(body.utf8))
        )
    }

    static let fixtureFiles = [
        "masterchain-info", "account-state", "account-states", "balance",
        "transactions", "traces", "events", "jettons", "nfts", "get-method", "dns",
    ]
}

/// Always returns the same response — for error paths and hand-built cases.
struct SingleResponseTransport: Transport {
    let response: TransportResponse

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        response
    }
}

/// Counts requests, to verify retry behaviour.
final class CountingTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    let response: TransportResponse

    init(response: TransportResponse) {
        self.response = response
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        // NSLock is unavailable from async contexts, so the mutation is confined to a
        // non-async helper.
        increment()
        return response
    }

    private func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

// MARK: - Fixture file shape

private struct FixtureFile: Decodable {
    let source: String
    let network: String
    let fixtures: [Fixture]

    struct Fixture: Decodable {
        let label: String
        let method: String
        let requests: [Request]
    }

    struct Request: Decodable {
        let method: String
        let url: String
        let status: Int
        let body: AnyJSON
    }
}

/// Minimal JSON box, so a recorded body can be re-serialized without modelling it.
struct AnyJSON: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: AnyKey.self) {
            var dict: [String: Any] = [:]
            for key in container.allKeys {
                dict[key.stringValue] = try container.decode(AnyJSON.self, forKey: key).value
            }
            value = dict
        } else if var container = try? decoder.unkeyedContainer() {
            var array: [Any] = []
            while !container.isAtEnd {
                array.append(try container.decode(AnyJSON.self).value)
            }
            value = array
        } else {
            let single = try decoder.singleValueContainer()
            if let v = try? single.decode(Bool.self) { value = v }
            else if let v = try? single.decode(Int.self) { value = v }
            else if let v = try? single.decode(Double.self) { value = v }
            else if let v = try? single.decode(String.self) { value = v }
            else { value = NSNull() }
        }
    }

    struct AnyKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
