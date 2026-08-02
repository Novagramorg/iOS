import Foundation

/// Persistent key-value storage the kit needs to survive a restart.
///
/// Deliberately minimal and `Sendable`, so a host app can back it with whatever it already
/// uses — `UserDefaults`, a file, SQLite, or the Keychain for anything sensitive.
///
/// The kit stores sessions and pending events here. Losing that store means losing
/// in-flight dApp requests and every connection, so a host implementation should treat it
/// as durable rather than a cache.
public protocol WalletKitStorage: Sendable {
    func get(_ key: String) async throws -> Data?
    func set(_ key: String, _ value: Data) async throws
    func remove(_ key: String) async throws
    /// Removes everything the kit stored. Used when a user resets the wallet.
    func clear() async throws
}

extension WalletKitStorage {
    /// Decodes a stored JSON value, returning nil when absent.
    ///
    /// A value that fails to decode is treated as absent rather than thrown: a schema
    /// change should degrade to "no data" rather than making the kit unusable until the
    /// user reinstalls.
    public func getJSON<T: Decodable>(_ key: String, as type: T.Type = T.self) async -> T? {
        guard let data = try? await get(key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func setJSON(_ key: String, _ value: some Encodable) async throws {
        try await set(key, try JSONEncoder().encode(value))
    }
}

/// In-memory storage, for tests and for sessions that need not survive a restart.
public actor InMemoryStorage: WalletKitStorage {
    private var contents: [String: Data] = [:]

    public init() {}

    public func get(_ key: String) async throws -> Data? { contents[key] }
    public func set(_ key: String, _ value: Data) async throws { contents[key] = value }
    public func remove(_ key: String) async throws { contents.removeValue(forKey: key) }
    public func clear() async throws { contents.removeAll() }

    /// Test affordance: how many keys are held.
    public var count: Int { contents.count }
}

/// File-backed storage.
///
/// Writes atomically, because the alternative is a half-written event queue after a crash
/// or a kill mid-write — which is exactly the case the durable event store exists to
/// survive.
public actor FileStorage: WalletKitStorage {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Storage inside the app's Application Support directory.
    public init(subdirectory: String = "TONWalletKit") throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try self.init(directory: base.appendingPathComponent(subdirectory))
    }

    private func url(for key: String) -> URL {
        // Percent-encode so a key cannot escape the directory or collide with a path
        // separator.
        let safe = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return directory.appendingPathComponent(safe)
    }

    public func get(_ key: String) async throws -> Data? {
        let path = url(for: key)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        return try Data(contentsOf: path)
    }

    public func set(_ key: String, _ value: Data) async throws {
        // .atomic writes to a temporary file and renames, so a reader never sees a partial
        // value and a crash mid-write leaves the previous value intact.
        try value.write(to: url(for: key), options: .atomic)
    }

    public func remove(_ key: String) async throws {
        let path = url(for: key)
        guard fileManager.fileExists(atPath: path.path) else { return }
        try fileManager.removeItem(at: path)
    }

    public func clear() async throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for file in contents {
            try fileManager.removeItem(at: file)
        }
    }
}

/// Storage keys the kit uses. Namespaced so a host app sharing a store cannot collide.
enum StorageKey {
    static let prefix = "walletkit."
    static let wallets = "\(prefix)wallets"
    static let sessions = "\(prefix)sessions"
    static let durableEvents = "\(prefix)durable_events"
    static let lastEventID = "\(prefix)bridge_last_event_id"
    /// Per-bridge resume cursor. Suffixed with the bridge URL, because a cursor from one
    /// bridge means nothing to another.
    static let bridgeCursorPrefix = "\(prefix)bridge_cursor."
    static let sessionSchemaVersion = "\(prefix)sessions_schema_version"
}
