import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

// Saved and pinned global search queries, one JSON entry per account. A port of the Mac's
// NovagramSavedSearches on engine names: the suite, the key and the Codable fields must stay the
// same as the Mac's, so do not rename them.
public struct NovagramSavedSearch: Equatable {
    public let query: String
    public let isPinned: Bool
}

public enum NovagramSavedSearches {
    public static let recentLimit = 20
    private static let suiteName = "pro_messager"
    private static let keyPrefix = "novagram_saved_searches_"
    private static let changes = ValuePromise<Int>(0, ignoreRepeated: true)
    private static let revision = Atomic<Int>(value: 0)
    private static let knownAccounts = Atomic<Set<AccountRecordId>?>(value: nil)
    private static let accountsDisposable = MetaDisposable()

    private struct Stored: Codable {
        var accountRecordId: Int64
        var pinned: [String]
        var recent: [String]
    }

    public static func list(accountPeerId: EnginePeer.Id) -> [NovagramSavedSearch] {
        guard let stored = load(accountPeerId) else {
            return []
        }
        return stored.pinned.map { NovagramSavedSearch(query: $0, isPinned: true) } + stored.recent.map { NovagramSavedSearch(query: $0, isPinned: false) }
    }

    public static func signal(accountPeerId: EnginePeer.Id) -> Signal<[NovagramSavedSearch], NoError> {
        return changes.get() |> map { _ in list(accountPeerId: accountPeerId) } |> distinctUntilChanged
    }

    public static func record(_ query: String?, accountPeerId: EnginePeer.Id, accountRecordId: AccountRecordId) {
        guard let text = normalized(query) else {
            return
        }
        update(accountPeerId, accountRecordId) { stored in
            guard !stored.pinned.contains(where: { same($0, text) }) else {
                return
            }
            stored.recent.removeAll(where: { same($0, text) })
            stored.recent.insert(text, at: 0)
            stored.recent = Array(stored.recent.prefix(recentLimit))
        }
    }

    public static func setPinned(_ query: String, pinned: Bool, accountPeerId: EnginePeer.Id, accountRecordId: AccountRecordId) {
        guard let text = normalized(query) else {
            return
        }
        update(accountPeerId, accountRecordId) { stored in
            stored.pinned.removeAll(where: { same($0, text) })
            stored.recent.removeAll(where: { same($0, text) })
            if pinned {
                stored.pinned.insert(text, at: 0)
            } else {
                stored.recent.insert(text, at: 0)
                stored.recent = Array(stored.recent.prefix(recentLimit))
            }
        }
    }

    public static func remove(_ query: String, accountPeerId: EnginePeer.Id, accountRecordId: AccountRecordId) {
        update(accountPeerId, accountRecordId) { stored in
            stored.pinned.removeAll(where: { same($0, query) })
            stored.recent.removeAll(where: { same($0, query) })
        }
    }

    // Removes every entry written for this account record (the key is the peer id, so all keys are read).
    public static func clear(accountRecordId: AccountRecordId) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        let decoder = JSONDecoder()
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data, let stored = try? decoder.decode(Stored.self, from: data) else {
                continue
            }
            if stored.accountRecordId == accountRecordId.int64 {
                defaults.removeObject(forKey: key)
            }
        }
        notify()
    }

    // Called once at launch. An account that leaves the signed-in list was logged out, by the user or
    // remotely (session ended from another device, forced logout, account deleted), so its saved
    // searches go too.
    public static func start(sharedContext: SharedAccountContext) {
        accountsDisposable.set((sharedContext.activeAccountContexts
        |> deliverOnMainQueue).startStrict(next: { value in
            let accountIds = Set(value.accounts.map { $0.0 })
            let previous = knownAccounts.swap(accountIds)
            for accountId in (previous ?? accountIds).subtracting(accountIds) {
                clear(accountRecordId: accountId)
            }
        }))
    }

    private static func key(_ accountPeerId: EnginePeer.Id) -> String {
        return keyPrefix + "\(accountPeerId.toInt64())"
    }

    private static func normalized(_ query: String?) -> String? {
        let text = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func load(_ accountPeerId: EnginePeer.Id) -> Stored? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key(accountPeerId)) else {
            return nil
        }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private static func update(_ accountPeerId: EnginePeer.Id, _ accountRecordId: AccountRecordId, _ f: (inout Stored) -> Void) {
        var stored = load(accountPeerId) ?? Stored(accountRecordId: accountRecordId.int64, pinned: [], recent: [])
        stored.accountRecordId = accountRecordId.int64
        f(&stored)
        guard let data = try? JSONEncoder().encode(stored) else {
            return
        }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key(accountPeerId))
        notify()
    }

    private static func notify() {
        let next = revision.modify { $0 + 1 }
        changes.set(next)
    }
}
