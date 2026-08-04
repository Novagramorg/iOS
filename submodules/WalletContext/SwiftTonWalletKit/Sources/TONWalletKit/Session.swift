import Foundation
import TONCore
import TONConnect

/// What a wallet knows about a connected dApp.
public struct DAppInfo: Codable, Sendable, Equatable {
    public let manifestURL: String
    public let name: String?
    public let iconURL: String?
    /// Host from the manifest's `url`. This is what `signData` and TON Proof bind to, so it
    /// must come from the manifest rather than from anything the dApp asserts at runtime.
    public let domain: String?

    public init(manifestURL: String, name: String? = nil, iconURL: String? = nil, domain: String? = nil) {
        self.manifestURL = manifestURL
        self.name = name
        self.iconURL = iconURL
        self.domain = domain
    }
}

/// A live connection between one wallet and one dApp.
public struct TONConnectSession: Codable, Sendable, Equatable {
    /// The dApp's session public key, hex. Also the bridge routing key.
    public let id: String
    public let walletID: WalletID
    public let dApp: DAppInfo
    /// Our side of the session keypair, hex. Persisted because losing it makes every
    /// pending request undecryptable.
    public let sessionPublicKey: String
    public let sessionSecretKey: String
    /// Which bridge this dApp is reachable on.
    ///
    /// Stored per session rather than configured globally: the bridge comes from the dApp's
    /// connect link, and different dApps routinely use different ones. Sending a reply to the
    /// wrong bridge silently never reaches the dApp.
    public let bridgeURL: String
    /// Unix milliseconds.
    public let createdAt: Int64
    public var lastActivityAt: Int64

    public init(
        id: String,
        walletID: WalletID,
        dApp: DAppInfo,
        sessionPublicKey: String,
        sessionSecretKey: String,
        bridgeURL: String,
        createdAt: Int64,
        lastActivityAt: Int64
    ) {
        self.id = id
        self.walletID = walletID
        self.dApp = dApp
        self.sessionPublicKey = sessionPublicKey
        self.sessionSecretKey = sessionSecretKey
        self.bridgeURL = bridgeURL
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
    }

    /// Decodes, tolerating a record written before ``bridgeURL`` existed.
    ///
    /// An old session decodes with an empty bridge URL, which the kit reads as "use the
    /// configured default" — the same behaviour it had before the field was added.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.walletID = try container.decode(WalletID.self, forKey: .walletID)
        self.dApp = try container.decode(DAppInfo.self, forKey: .dApp)
        self.sessionPublicKey = try container.decode(String.self, forKey: .sessionPublicKey)
        self.sessionSecretKey = try container.decode(String.self, forKey: .sessionSecretKey)
        self.bridgeURL = try container.decodeIfPresent(String.self, forKey: .bridgeURL) ?? ""
        self.createdAt = try container.decode(Int64.self, forKey: .createdAt)
        self.lastActivityAt = try container.decode(Int64.self, forKey: .lastActivityAt)
    }

    /// Rebuilds the crypto for this session.
    public func crypto() throws -> SessionCrypto {
        do {
            return try SessionCrypto(
                publicKeyHex: sessionPublicKey,
                secretKeyHex: sessionSecretKey
            )
        } catch {
            throw WalletKitError.cryptoFailure(underlying: error)
        }
    }

    /// The dApp's public key, for sealing replies.
    public func peerPublicKey() throws -> Data {
        guard let data = Data(hexString: id) else {
            throw WalletKitError.validationFailed(reason: "Session id \(id) is not hex")
        }
        return data
    }
}

/// Persisted sessions.
///
/// An actor because sessions are read on every inbound bridge message and written on
/// connect and disconnect, from whichever task the bridge delivers on.
public actor SessionManager {
    /// Bumped when the stored shape changes. Migration runs on load.
    static let currentSchemaVersion = 1

    private let storage: any WalletKitStorage
    private let now: @Sendable () -> Int64
    private var sessions: [String: TONConnectSession] = [:]
    private var isLoaded = false

    public init(
        storage: any WalletKitStorage,
        now: @Sendable @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.storage = storage
        self.now = now
    }

    // MARK: - Persistence

    /// Loads and migrates.
    ///
    /// A session that fails to migrate is **dropped rather than thrown on**: one unreadable
    /// record must not make every other connection unusable. The dApp will simply have to
    /// reconnect.
    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true

        let storedVersion: Int = await storage.getJSON(StorageKey.sessionSchemaVersion) ?? 0
        guard let stored: [String: TONConnectSession] = await storage.getJSON(StorageKey.sessions)
        else {
            await persistSchemaVersion()
            return
        }

        sessions = stored
        if storedVersion < Self.currentSchemaVersion {
            await migrate(from: storedVersion)
        }
    }

    private func migrate(from version: Int) async {
        // Version 0 predates schema tracking. Its records are shape-compatible with v1, so
        // migration only stamps the version; the guard exists so a future incompatible
        // change has an obvious place to hook in.
        await persistSchemaVersion()
        await persist()
    }

    private func persist() async {
        try? await storage.setJSON(StorageKey.sessions, sessions)
    }

    private func persistSchemaVersion() async {
        try? await storage.setJSON(StorageKey.sessionSchemaVersion, Self.currentSchemaVersion)
    }

    // MARK: - Access

    public func session(id: String) async -> TONConnectSession? {
        await loadIfNeeded()
        return sessions[id]
    }

    public func allSessions() async -> [TONConnectSession] {
        await loadIfNeeded()
        return sessions.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func sessions(forWallet walletID: WalletID) async -> [TONConnectSession] {
        await loadIfNeeded()
        return sessions.values
            .filter { $0.walletID == walletID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func sessionIDs(forWallet walletID: WalletID) async -> [String] {
        await sessions(forWallet: walletID).map(\.id)
    }

    public func count() async -> Int {
        await loadIfNeeded()
        return sessions.count
    }

    // MARK: - Mutation

    @discardableResult
    public func create(
        id: String,
        walletID: WalletID,
        dApp: DAppInfo,
        crypto: SessionCrypto,
        bridgeURL: String = ""
    ) async -> TONConnectSession {
        await loadIfNeeded()
        let keys = crypto.storedKeys
        let timestamp = now()
        let session = TONConnectSession(
            id: id,
            walletID: walletID,
            dApp: dApp,
            sessionPublicKey: keys.publicKey,
            sessionSecretKey: keys.secretKey,
            bridgeURL: bridgeURL,
            createdAt: timestamp,
            lastActivityAt: timestamp
        )
        sessions[id] = session
        await persist()
        return session
    }

    /// Records that a session was used, for inactivity cleanup.
    public func touch(id: String) async {
        await loadIfNeeded()
        guard var session = sessions[id] else { return }
        session.lastActivityAt = now()
        sessions[id] = session
        await persist()
    }

    public func remove(id: String) async {
        await loadIfNeeded()
        guard sessions.removeValue(forKey: id) != nil else { return }
        await persist()
    }

    /// Removes every session for a wallet — used when that wallet is deleted.
    ///
    /// Leaving them behind would keep the bridge delivering requests for a wallet that can
    /// no longer sign.
    @discardableResult
    public func removeAll(forWallet walletID: WalletID) async -> Int {
        await loadIfNeeded()
        let doomed = sessions.values.filter { $0.walletID == walletID }.map(\.id)
        for id in doomed { sessions.removeValue(forKey: id) }
        if !doomed.isEmpty { await persist() }
        return doomed.count
    }

    /// Removes every session for a dApp domain.
    @discardableResult
    public func removeAll(forDomain domain: String) async -> Int {
        await loadIfNeeded()
        let doomed = sessions.values.filter { $0.dApp.domain == domain }.map(\.id)
        for id in doomed { sessions.removeValue(forKey: id) }
        if !doomed.isEmpty { await persist() }
        return doomed.count
    }

    public func clear() async {
        await loadIfNeeded()
        sessions.removeAll()
        await persist()
    }

    /// Drops sessions unused for longer than `maxInactivity`. Returns how many went.
    @discardableResult
    public func cleanupInactive(maxInactivity: TimeInterval) async -> Int {
        await loadIfNeeded()
        let cutoff = now() - Int64(maxInactivity * 1000)
        let before = sessions.count
        sessions = sessions.filter { $0.value.lastActivityAt >= cutoff }
        let removed = before - sessions.count
        if removed > 0 { await persist() }
        return removed
    }
}
