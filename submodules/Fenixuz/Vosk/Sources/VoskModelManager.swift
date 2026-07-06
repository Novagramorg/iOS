import Foundation
import ZipArchive

public enum VoskModelError: Error {
    case badURL
    case downloadFailed
    case unzipFailed
}

/// Locates the Vosk model directory for a language, downloading + unzipping it on first
/// use into `Caches/vosk/`. The model (~49 MB) is fetched from Alpha Cephei's host; after
/// the first successful download it is cached and reused fully offline.
public enum VoskModelManager {
    private static let modelBaseURL = "https://alphacephei.com/vosk/models"

    private static var cacheRoot: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("vosk", isDirectory: true)
    }

    private static func modelDirectory(_ modelName: String) -> URL {
        return cacheRoot.appendingPathComponent(modelName, isDirectory: true)
    }

    /// On-disk path of the model directory (meaningful only once `isModelReady` is true).
    public static func modelPath(_ modelName: String) -> String {
        return modelDirectory(modelName).path
    }

    /// True when the model for `modelName` is already unpacked and usable on disk.
    /// `conf/model.conf` is a small file always present in a complete model directory.
    public static func isModelReady(_ modelName: String) -> Bool {
        let marker = modelDirectory(modelName).appendingPathComponent("conf/model.conf").path
        return FileManager.default.fileExists(atPath: marker)
    }

    /// Returns the on-disk directory path of the model, downloading + unzipping on first use.
    /// Throws on network / unzip failure so the caller can surface an actionable message.
    public static func ensureModel(_ modelName: String) async throws -> String {
        let directory = modelDirectory(modelName)
        if isModelReady(modelName) {
            return directory.path
        }

        try FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)

        guard let url = URL(string: "\(modelBaseURL)/\(modelName).zip") else {
            throw VoskModelError.badURL
        }

        // Download the zip to a stable temp path. (iOS 13-compatible: the async
        // URLSession.download(from:) API is iOS 15+, so wrap the completion-handler
        // downloadTask in a continuation below.)
        let zipURL = cacheRoot.appendingPathComponent("\(modelName).zip")
        try await downloadFile(from: url, to: zipURL)

        // The archive contains a top-level "<modelName>/" directory, so unzip into cacheRoot.
        // SSZipArchive reads the zip by content, so the temp file's missing .zip extension is fine.
        let unzipped = SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: cacheRoot.path)
        try? FileManager.default.removeItem(at: zipURL)

        guard unzipped, isModelReady(modelName) else {
            throw VoskModelError.unzipFailed
        }

        excludeFromBackup(directory)
        return directory.path
    }

    /// Downloads a file to `destination` using the completion-handler API wrapped in a
    /// continuation (the async `URLSession.download` is iOS 15+; this fork targets iOS 13).
    private static func downloadFile(from url: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let task = URLSession.shared.downloadTask(with: url) { location, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let location = location,
                      let http = response as? HTTPURLResponse,
                      (200 ..< 300).contains(http.statusCode) else {
                    continuation.resume(throwing: VoskModelError.downloadFailed)
                    return
                }
                // `location` is removed once this handler returns, so move it synchronously here.
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: location, to: destination)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }

    /// Re-downloadable content must be excluded from iCloud backup (Apple data-storage guideline).
    private static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
