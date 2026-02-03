import Foundation
import CryptoKit

class CachePersistence {
    static let shared = CachePersistence()

    let baseDirectory: URL
    private let ioQueue = DispatchQueue(label: "com.workershim.persistence", qos: .utility)

    init(baseDirectory: URL? = nil) {
        if let dir = baseDirectory {
            self.baseDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("WorkerShim_v5")
        }

        // Create base directory if needed
        try? FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Helpers

    func originHash(_ origin: String) -> String {
        let data = Data(origin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func originDirectory(for origin: String) -> URL {
        baseDirectory.appendingPathComponent(originHash(origin))
    }

    // MARK: - Registration Persistence

    func saveRegistration(_ snapshot: RegistrationSnapshot) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let originDir = self.originDirectory(for: snapshot.origin)
            try? FileManager.default.createDirectory(at: originDir, withIntermediateDirectories: true)

            // Save origin.txt for debugging
            let originFile = originDir.appendingPathComponent("origin.txt")
            try? snapshot.origin.write(to: originFile, atomically: true, encoding: .utf8)

            // Save registration.json
            let registrationFile = originDir.appendingPathComponent("registration.json")
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(snapshot)
                try data.write(to: registrationFile, options: .atomic)
            } catch {
                print("[CachePersistence] Failed to save registration: \(error)")
            }
        }
    }

    func loadAllRegistrations() -> [RegistrationSnapshot] {
        var registrations: [RegistrationSnapshot] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return registrations
        }

        for originDir in contents {
            let registrationFile = originDir.appendingPathComponent("registration.json")
            guard let data = try? Data(contentsOf: registrationFile),
                  let snapshot = try? JSONDecoder().decode(RegistrationSnapshot.self, from: data) else {
                continue
            }
            registrations.append(snapshot)
        }

        return registrations
    }

    // Returns list of origins without creating full registration objects
    func loadAllOrigins() -> [String] {
        var origins: [String] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return origins
        }

        for originDir in contents {
            // Read origin.txt for the actual origin string
            let originFile = originDir.appendingPathComponent("origin.txt")
            if let origin = try? String(contentsOf: originFile, encoding: .utf8) {
                origins.append(origin.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return origins
    }

    // MARK: - Script Persistence

    func saveScript(_ script: String, for origin: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let originDir = self.originDirectory(for: origin)
            try? FileManager.default.createDirectory(at: originDir, withIntermediateDirectories: true)

            let scriptFile = originDir.appendingPathComponent("sw-script.js")
            do {
                try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            } catch {
                print("[CachePersistence] Failed to save script: \(error)")
            }
        }
    }

    func loadScript(for origin: String) -> String? {
        let scriptFile = originDirectory(for: origin).appendingPathComponent("sw-script.js")
        return try? String(contentsOf: scriptFile, encoding: .utf8)
    }

    // MARK: - Cache Entry Persistence

    struct CacheManifestEntry: Codable {
        let bodyFile: String
        let status: Int
        let statusText: String
        let headers: [String: String]
    }

    struct CacheManifest: Codable {
        var entries: [String: CacheManifestEntry] = [:]
    }

    func saveCacheEntry(origin: String, cacheName: String, url: String, response: CachedResponse) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let cacheDir = self.originDirectory(for: origin)
                .appendingPathComponent("caches")
                .appendingPathComponent(cacheName)
            let bodiesDir = cacheDir.appendingPathComponent("bodies")

            try? FileManager.default.createDirectory(at: bodiesDir, withIntermediateDirectories: true)

            // Generate body filename from URL hash
            let urlHash = self.originHash(url)
            let bodyFile = "\(urlHash).body"
            let bodyPath = bodiesDir.appendingPathComponent(bodyFile)

            // Write body
            do {
                try response.body.write(to: bodyPath, options: .atomic)
            } catch {
                print("[CachePersistence] Failed to write body: \(error)")
                return
            }

            // Update manifest
            let manifestPath = cacheDir.appendingPathComponent("manifest.json")
            var manifest = self.loadManifest(at: manifestPath)
            manifest.entries[url] = CacheManifestEntry(
                bodyFile: bodyFile,
                status: response.status,
                statusText: response.statusText,
                headers: response.headers
            )

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(manifest)
                try data.write(to: manifestPath, options: .atomic)
            } catch {
                print("[CachePersistence] Failed to write manifest: \(error)")
            }
        }
    }

    private func loadManifest(at path: URL) -> CacheManifest {
        guard let data = try? Data(contentsOf: path),
              let manifest = try? JSONDecoder().decode(CacheManifest.self, from: data) else {
            return CacheManifest()
        }
        return manifest
    }

    func loadCache(origin: String) -> [String: [String: CachedResponse]] {
        var result: [String: [String: CachedResponse]] = [:]

        let cachesDir = originDirectory(for: origin).appendingPathComponent("caches")
        guard let cacheNames = try? FileManager.default.contentsOfDirectory(
            at: cachesDir,
            includingPropertiesForKeys: nil
        ) else {
            return result
        }

        for cacheDir in cacheNames {
            let cacheName = cacheDir.lastPathComponent
            let manifestPath = cacheDir.appendingPathComponent("manifest.json")
            let manifest = loadManifest(at: manifestPath)

            var cacheEntries: [String: CachedResponse] = [:]
            for (url, entry) in manifest.entries {
                let bodyPath = cacheDir.appendingPathComponent("bodies").appendingPathComponent(entry.bodyFile)
                guard let body = try? Data(contentsOf: bodyPath) else {
                    continue
                }
                cacheEntries[url] = CachedResponse(
                    url: url,
                    status: entry.status,
                    statusText: entry.statusText,
                    headers: entry.headers,
                    body: body
                )
            }

            if !cacheEntries.isEmpty {
                result[cacheName] = cacheEntries
            }
        }

        return result
    }

    // MARK: - Delete Operations

    func deleteCacheEntry(origin: String, cacheName: String, url: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let cacheDir = self.originDirectory(for: origin)
                .appendingPathComponent("caches")
                .appendingPathComponent(cacheName)
            let manifestPath = cacheDir.appendingPathComponent("manifest.json")

            var manifest = self.loadManifest(at: manifestPath)
            guard let entry = manifest.entries.removeValue(forKey: url) else { return }

            // Delete body file
            let bodyPath = cacheDir.appendingPathComponent("bodies").appendingPathComponent(entry.bodyFile)
            try? FileManager.default.removeItem(at: bodyPath)

            // Update manifest
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(manifest)
                try data.write(to: manifestPath, options: .atomic)
            } catch {
                print("[CachePersistence] Failed to update manifest: \(error)")
            }
        }
    }

    func deleteCache(origin: String, name: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let cacheDir = self.originDirectory(for: origin)
                .appendingPathComponent("caches")
                .appendingPathComponent(name)

            try? FileManager.default.removeItem(at: cacheDir)
        }
    }

    func deleteOrigin(_ origin: String) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let originDir = self.originDirectory(for: origin)
            try? FileManager.default.removeItem(at: originDir)
        }
    }
}
