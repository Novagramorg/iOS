import XCTest
import TONCore
import TONConnect
@testable import TONWalletKit

/// Verifies session persistence.
///
/// A session holds the keypair that decrypts every inbound request from one dApp. Losing it
/// means every pending request from that dApp becomes unreadable and the connection has to
/// be rebuilt, so durability across restarts is the property that matters.
final class SessionTests: XCTestCase {
    final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var millis: Int64 = 1_700_000_000_000

        var now: Int64 {
            lock.lock(); defer { lock.unlock() }
            return millis
        }
        func advance(seconds: TimeInterval) {
            lock.lock(); millis += Int64(seconds * 1000); lock.unlock()
        }
        var reader: @Sendable () -> Int64 { { [self] in self.now } }
    }

    private func dApp(_ domain: String = "example.com") -> DAppInfo {
        DAppInfo(
            manifestURL: "https://\(domain)/tonconnect-manifest.json",
            name: "Example",
            iconURL: "https://\(domain)/icon.png",
            domain: domain
        )
    }

    private let walletA = WalletID("wallet-a")
    private let walletB = WalletID("wallet-b")

    // MARK: - Basics

    func testCreateAndRetrieve() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        let crypto = try SessionCrypto()

        let created = await manager.create(
            id: "dapp-1",
            walletID: walletA,
            dApp: dApp(),
            crypto: crypto
        )
        XCTAssertEqual(created.id, "dapp-1")
        XCTAssertEqual(created.walletID, walletA)
        XCTAssertEqual(created.sessionPublicKey, crypto.storedKeys.publicKey)

        let fetched = await manager.session(id: "dapp-1")
        XCTAssertEqual(fetched, created)
    }

    /// The stored keys must reconstruct working crypto, or the session is useless.
    func testStoredKeysReconstructWorkingCrypto() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        let walletCrypto = try SessionCrypto()
        let session = await manager.create(
            id: "dapp-1",
            walletID: walletA,
            dApp: dApp(),
            crypto: walletCrypto
        )

        // A dApp seals a request to the wallet's session key.
        let appCrypto = try SessionCrypto()
        let envelope = try appCrypto.encryptToBase64(
            #"{"id":"1","method":"disconnect","params":[]}"#,
            receiverPublicKey: walletCrypto.publicKey
        )

        // Reconstructed crypto must open it.
        let restored = try session.crypto()
        let plaintext = try restored.decrypt(base64: envelope, senderPublicKey: appCrypto.publicKey)
        XCTAssertTrue(plaintext.contains("disconnect"))
    }

    /// The session id is the dApp's public key, so it must decode to the key used for
    /// sealing replies.
    func testPeerPublicKeyComesFromTheSessionID() async throws {
        let appCrypto = try SessionCrypto()
        let manager = SessionManager(storage: InMemoryStorage())
        let session = await manager.create(
            id: appCrypto.sessionID,
            walletID: walletA,
            dApp: dApp(),
            crypto: try SessionCrypto()
        )
        XCTAssertEqual(try session.peerPublicKey(), appCrypto.publicKey)
    }

    func testNonHexSessionIDIsRejectedWhenSealing() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        let session = await manager.create(
            id: "not-hex",
            walletID: walletA,
            dApp: dApp(),
            crypto: try SessionCrypto()
        )
        XCTAssertThrowsError(try session.peerPublicKey())
    }

    // MARK: - Querying

    func testSessionsAreScopedByWallet() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        _ = await manager.create(id: "a1", walletID: walletA, dApp: dApp("a.com"), crypto: try SessionCrypto())
        _ = await manager.create(id: "a2", walletID: walletA, dApp: dApp("b.com"), crypto: try SessionCrypto())
        _ = await manager.create(id: "b1", walletID: walletB, dApp: dApp("c.com"), crypto: try SessionCrypto())

        let forA = await manager.sessions(forWallet: walletA)
        XCTAssertEqual(Set(forA.map(\.id)), ["a1", "a2"])

        let idsForB = await manager.sessionIDs(forWallet: walletB)
        XCTAssertEqual(idsForB, ["b1"])
    }

    func testSessionsAreOrderedByCreation() async throws {
        let clock = TestClock()
        let manager = SessionManager(storage: InMemoryStorage(), now: clock.reader)
        for id in ["first", "second", "third"] {
            _ = await manager.create(id: id, walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())
            clock.advance(seconds: 1)
        }
        let all = await manager.allSessions()
        XCTAssertEqual(all.map(\.id), ["first", "second", "third"])
    }

    // MARK: - Removal

    /// Deleting a wallet must take its sessions with it, or the bridge keeps delivering
    /// requests for a wallet that can no longer sign.
    func testRemovingAWalletRemovesItsSessions() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        _ = await manager.create(id: "a1", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())
        _ = await manager.create(id: "a2", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())
        _ = await manager.create(id: "b1", walletID: walletB, dApp: dApp(), crypto: try SessionCrypto())

        let removed = await manager.removeAll(forWallet: walletA)
        XCTAssertEqual(removed, 2)

        let remaining = await manager.allSessions()
        XCTAssertEqual(remaining.map(\.id), ["b1"], "the other wallet's session must survive")
    }

    /// Disconnecting a dApp should drop every session it holds, across wallets.
    func testRemovingByDomain() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        _ = await manager.create(id: "s1", walletID: walletA, dApp: dApp("evil.com"), crypto: try SessionCrypto())
        _ = await manager.create(id: "s2", walletID: walletB, dApp: dApp("evil.com"), crypto: try SessionCrypto())
        _ = await manager.create(id: "s3", walletID: walletA, dApp: dApp("good.com"), crypto: try SessionCrypto())

        let value1 = await manager.removeAll(forDomain: "evil.com")
        XCTAssertEqual(value1, 2)
        let remaining = await manager.allSessions()
        XCTAssertEqual(remaining.map(\.id), ["s3"])
    }

    func testRemovingAnUnknownSessionIsHarmless() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        await manager.remove(id: "nope")
        let value2 = await manager.count()
        XCTAssertEqual(value2, 0)
    }

    // MARK: - Inactivity

    func testInactiveSessionsAreCleanedUp() async throws {
        let clock = TestClock()
        let manager = SessionManager(storage: InMemoryStorage(), now: clock.reader)
        _ = await manager.create(id: "old", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())

        clock.advance(seconds: 3600)
        _ = await manager.create(id: "fresh", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())

        let removed = await manager.cleanupInactive(maxInactivity: 1800)
        XCTAssertEqual(removed, 1)
        let remaining = await manager.allSessions()
        XCTAssertEqual(remaining.map(\.id), ["fresh"])
    }

    /// Using a session must keep it alive — otherwise an actively used connection could be
    /// reaped mid-conversation.
    func testTouchPreventsCleanup() async throws {
        let clock = TestClock()
        let manager = SessionManager(storage: InMemoryStorage(), now: clock.reader)
        _ = await manager.create(id: "used", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())

        clock.advance(seconds: 1700)
        await manager.touch(id: "used")
        clock.advance(seconds: 1700)

        let reaped = await manager.cleanupInactive(maxInactivity: 1800)
        XCTAssertEqual(reaped, 0, "a session used recently must not be reaped")
    }

    // MARK: - Durability

    /// The core promise: a restart must not lose sessions, or every dApp has to reconnect.
    func testSessionsSurviveARestart() async throws {
        let storage = InMemoryStorage()
        let crypto = try SessionCrypto()

        do {
            let manager = SessionManager(storage: storage)
            _ = await manager.create(id: "dapp-1", walletID: walletA, dApp: dApp(), crypto: crypto)
        }

        let reopened = SessionManager(storage: storage)
        let restored = await reopened.session(id: "dapp-1")
        let session = try XCTUnwrap(restored)
        XCTAssertEqual(session.walletID, walletA)
        XCTAssertEqual(
            session.sessionSecretKey,
            crypto.storedKeys.secretKey,
            "the secret key must survive, or pending requests become unreadable"
        )
    }

    /// A schema stamp is written on first use, so a future incompatible change has a version
    /// to migrate from rather than having to guess.
    func testSchemaVersionIsStamped() async throws {
        let storage = InMemoryStorage()
        let manager = SessionManager(storage: storage)
        _ = await manager.create(id: "s1", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())

        let version: Int? = await storage.getJSON(StorageKey.sessionSchemaVersion)
        XCTAssertEqual(version, SessionManager.currentSchemaVersion)
    }

    /// Version-0 records predate schema tracking *and* the `bridgeURL` field, so they must
    /// load rather than be discarded.
    ///
    /// Written as raw JSON rather than by encoding the current struct, which is the point:
    /// encoding the current type would silently include every field and prove nothing about
    /// what an older build actually wrote.
    func testUnversionedRecordsAreAdopted() async throws {
        let storage = InMemoryStorage()
        let crypto = try SessionCrypto()
        let legacyJSON = """
        {"legacy":{
          "id":"legacy",
          "walletID":{"value":"wallet-a"},
          "dApp":{"manifestURL":"https://example.com/tonconnect-manifest.json"},
          "sessionPublicKey":"\(crypto.storedKeys.publicKey)",
          "sessionSecretKey":"\(crypto.storedKeys.secretKey)",
          "createdAt":1,
          "lastActivityAt":1
        }}
        """
        // Written without a schema version, as an older build would have.
        try await storage.set(StorageKey.sessions, Data(legacyJSON.utf8))

        let manager = SessionManager(storage: storage)
        let legacySession = await manager.session(id: "legacy")
        let loaded = try XCTUnwrap(legacySession)
        XCTAssertEqual(loaded.id, "legacy")
        XCTAssertEqual(loaded.walletID, walletA)
        XCTAssertEqual(
            loaded.bridgeURL,
            "",
            "a record from before bridgeURL existed must read as empty, meaning 'use the default'"
        )
        // The keys must still work — a migration that loses them silently breaks the session.
        XCTAssertNoThrow(try loaded.crypto())

        // And the version is stamped forward.
        let version: Int? = await storage.getJSON(StorageKey.sessionSchemaVersion)
        XCTAssertEqual(version, SessionManager.currentSchemaVersion)
    }

    /// An unreadable store must not make the kit unusable — it degrades to "no sessions"
    /// rather than throwing on every access.
    func testCorruptStoreDegradesToEmpty() async throws {
        let storage = InMemoryStorage()
        try await storage.set(StorageKey.sessions, Data("not json at all".utf8))

        let manager = SessionManager(storage: storage)
        let count = await manager.count()
        XCTAssertEqual(count, 0, "a corrupt store should read as empty rather than failing every call")

        // And it must still be usable afterwards.
        _ = await manager.create(id: "new", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())
        let value3 = await manager.count()
        XCTAssertEqual(value3, 1)
    }

    func testClearRemovesEverything() async throws {
        let manager = SessionManager(storage: InMemoryStorage())
        _ = await manager.create(id: "s1", walletID: walletA, dApp: dApp(), crypto: try SessionCrypto())
        _ = await manager.create(id: "s2", walletID: walletB, dApp: dApp(), crypto: try SessionCrypto())
        await manager.clear()
        let value4 = await manager.count()
        XCTAssertEqual(value4, 0)
    }
}

/// Verifies the storage implementations the kit relies on.
final class StorageTests: XCTestCase {
    func testInMemoryRoundTrip() async throws {
        let storage = InMemoryStorage()
        let value5 = try await storage.get("k")
        XCTAssertNil(value5)

        try await storage.set("k", Data("v".utf8))
        let value6 = try await storage.get("k")
        XCTAssertEqual(value6, Data("v".utf8))

        try await storage.remove("k")
        let value7 = try await storage.get("k")
        XCTAssertNil(value7)
    }

    func testJSONHelpers() async throws {
        struct Payload: Codable, Equatable { let a: Int; let b: String }
        let storage = InMemoryStorage()
        let value = Payload(a: 1, b: "two")

        try await storage.setJSON("p", value)
        let loaded: Payload? = await storage.getJSON("p")
        XCTAssertEqual(loaded, value)
    }

    /// A schema change must degrade to "no data" rather than making the kit unusable until
    /// reinstall.
    func testUndecodableJSONReadsAsNil() async throws {
        struct Payload: Codable { let a: Int }
        let storage = InMemoryStorage()
        try await storage.set("p", Data(#"{"unexpected":"shape"}"#.utf8))
        let loaded: Payload? = await storage.getJSON("p")
        XCTAssertNil(loaded)
    }

    func testFileStorageRoundTripAndPersistence() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("walletkit-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let storage = try FileStorage(directory: directory)
            try await storage.set(StorageKey.sessions, Data("persisted".utf8))
        }

        // A fresh instance over the same directory stands in for a relaunch.
        let reopened = try FileStorage(directory: directory)
        let value8 = try await reopened.get(StorageKey.sessions)
        XCTAssertEqual(value8, Data("persisted".utf8))
    }

    /// Keys are percent-encoded, so a key containing a path separator cannot escape the
    /// storage directory.
    func testKeysCannotEscapeTheDirectory() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("walletkit-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try FileStorage(directory: directory)
        try await storage.set("../escaped", Data("x".utf8))

        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(contents.count, 1)
        XCTAssertFalse(contents[0].contains("/"), "the key must not create a path")
        let value9 = try await storage.get("../escaped")
        XCTAssertEqual(value9, Data("x".utf8))
    }

    func testFileStorageClear() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("walletkit-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = try FileStorage(directory: directory)
        try await storage.set("a", Data("1".utf8))
        try await storage.set("b", Data("2".utf8))
        try await storage.clear()

        let value10 = try await storage.get("a")
        XCTAssertNil(value10)
        let value11 = try await storage.get("b")
        XCTAssertNil(value11)
    }
}
