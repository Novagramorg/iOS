import Foundation

struct CachedResponse: Codable {
    let url: String
    let status: Int
    let statusText: String
    let headers: [String: String]
    let body: Data

    func toDictionary() -> [String: Any] {
        return [
            "url": url,
            "status": status,
            "statusText": statusText,
            "headers": headers,
            "bodyBase64": body.base64EncodedString()
        ]
    }
}

class CacheStorage {
    static let shared = CacheStorage()

    // [origin: [cacheName: [url: CachedResponse]]]
    private var storage: [String: [String: [String: CachedResponse]]] = [:]
    private let queue = DispatchQueue(label: "com.workershim.cache", attributes: .concurrent)

    // Persistence layer (optional, nil during some tests)
    var persistence: CachePersistence?

    private init() {}

    // MARK: - Persistence Integration

    func loadFromDisk() {
        guard let persistence = persistence else { return }

        // Load all origins (without creating ServiceWorkerRegistration objects
        // which have deallocation issues)
        let origins = persistence.loadAllOrigins()
        for origin in origins {
            let caches = persistence.loadCache(origin: origin)

            queue.async(flags: .barrier) {
                if self.storage[origin] == nil {
                    self.storage[origin] = [:]
                }
                for (cacheName, entries) in caches {
                    self.storage[origin]?[cacheName] = entries
                }
            }
        }
    }

    func open(origin: String, name: String) {
        queue.async(flags: .barrier) {
            if self.storage[origin] == nil {
                self.storage[origin] = [:]
            }
            if self.storage[origin]![name] == nil {
                self.storage[origin]![name] = [:]
            }
        }
    }

    func keys(origin: String) -> [String] {
        queue.sync {
            guard let originStorage = self.storage[origin] else { return [] }
            return Array(originStorage.keys)
        }
    }

    func delete(origin: String, name: String) -> Bool {
        let result = queue.sync(flags: .barrier) {
            return self.storage[origin]?.removeValue(forKey: name) != nil
        }
        persistence?.deleteCache(origin: origin, name: name)
        return result
    }

    func put(origin: String, cacheName: String, url: String, response: CachedResponse) {
        print("[CacheStorage] PUT origin: \(origin), cache: \(cacheName), url: \(url)")
        queue.async(flags: .barrier) {
            // Ensure nested structure exists
            if self.storage[origin] == nil {
                self.storage[origin] = [:]
            }
            if self.storage[origin]![cacheName] == nil {
                self.storage[origin]![cacheName] = [:]
            }
            self.storage[origin]![cacheName]![url] = response
        }
        persistence?.saveCacheEntry(origin: origin, cacheName: cacheName, url: url, response: response)
    }

    func match(origin: String, cacheName: String?, url: String) -> CachedResponse? {
        queue.sync {
            print("[CacheStorage] match origin: \(origin), url: \(url)")
            if let caches = self.storage[origin] {
                print("[CacheStorage] Available caches for origin: \(caches.keys)")
                for (name, cache) in caches {
                    print("[CacheStorage] Cache '\(name)' has \(cache.count) entries: \(Array(cache.keys).prefix(5))")
                }
            } else {
                print("[CacheStorage] No caches for origin \(origin)")
            }

            if let cacheName = cacheName {
                return self.storage[origin]?[cacheName]?[url]
            }
            // Search all caches for this origin
            guard let caches = self.storage[origin] else { return nil }
            for (_, cache) in caches {
                if let response = cache[url] {
                    return response
                }
            }
            return nil
        }
    }

    func deleteEntry(origin: String, cacheName: String, url: String) -> Bool {
        let result = queue.sync(flags: .barrier) {
            return self.storage[origin]?[cacheName]?.removeValue(forKey: url) != nil
        }
        persistence?.deleteCacheEntry(origin: origin, cacheName: cacheName, url: url)
        return result
    }

    func cacheKeys(origin: String, cacheName: String) -> [String] {
        queue.sync {
            guard let cache = self.storage[origin]?[cacheName] else { return [] }
            return Array(cache.keys)
        }
    }

    func clear(origin: String) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: origin)
        }
        persistence?.deleteOrigin(origin)
    }

    func clearAll() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
        // Note: clearAll doesn't delete from disk - that's intentional for test isolation
    }
}
