import Foundation
import SwiftSignalKit

// Minimal Firebase Realtime Database REST client — no Firebase SDK.
// Hits the same RTDB the Android app uses so the analytics numbers match.
final class FenixuzFirebaseClient {
    static let shared = FenixuzFirebaseClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15.0
        configuration.allowsCellularAccess = true
        self.session = URLSession(configuration: configuration)
    }

    private func url(forPath path: String) -> URL? {
        guard FenixuzAnalyticsConfig.isConfigured else {
            return nil
        }
        var string = FenixuzAnalyticsConfig.databaseURL
        if string.hasSuffix("/") {
            string.removeLast()
        }
        string += "/" + path + ".json"
        if !FenixuzAnalyticsConfig.authToken.isEmpty {
            string += "?auth=" + FenixuzAnalyticsConfig.authToken
        }
        return URL(string: string)
    }

    private static func isSuccess(_ response: URLResponse?, _ error: Error?) -> Bool {
        if error != nil {
            return false
        }
        guard let http = response as? HTTPURLResponse else {
            return false
        }
        return (200 ..< 300).contains(http.statusCode)
    }

    // Atomically increments a numeric node using RTDB's server-side increment value
    // ({".sv": {"increment": N}}) — no read-modify-write race between clients.
    func increment(path: String, by delta: Int, completion: @escaping (Bool) -> Void) {
        guard let url = self.url(forPath: path) else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [".sv": ["increment": delta]]
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(false)
            return
        }
        request.httpBody = data
        let task = self.session.dataTask(with: request) { _, response, error in
            completion(FenixuzFirebaseClient.isSuccess(response, error))
        }
        task.resume()
    }

    // Idempotent presence record: devices/<deviceId> = true.
    func markPresent(path: String, completion: @escaping (Bool) -> Void) {
        guard let url = self.url(forPath: path) else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "true".data(using: .utf8)
        let task = self.session.dataTask(with: request) { _, response, error in
            completion(FenixuzFirebaseClient.isSuccess(response, error))
        }
        task.resume()
    }

    // Reads an integer counter node (nil if not configured / missing / unreachable).
    func readInt(path: String) -> Signal<Int?, NoError> {
        return Signal { subscriber in
            guard let url = self.url(forPath: path) else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let task = self.session.dataTask(with: url) { data, _, _ in
                var result: Int?
                if let data = data, let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]), let number = object as? NSNumber {
                    result = number.intValue
                }
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            task.resume()
            return ActionDisposable {
                task.cancel()
            }
        }
    }
}
