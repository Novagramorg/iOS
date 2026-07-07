import Foundation
import Postbox
import FenixuzChatLock

public extension Notification.Name {
    /// Posted whenever the vaulted-peer set changes so any open chat list rebuilds
    /// its entries (hide/show the affected chats immediately).
    static let fenixSecretVaultChanged = Notification.Name("FenixSecretVaultChanged")
}

/// Owns the set of chats hidden inside the Secret Vault. The credential that gates
/// access lives in `ChatPincodeManager` (reserved account `__fenix_vault__`); this
/// manager holds only the *set of hidden peerIds* plus a cached enabled-flag so the
/// chat-list filter hot path never touches the keychain per row.
///
/// Muting of vaulted chats is NOT done here — it is a side effect applied by the
/// call sites that have engine access (see `ChatListController` / settings), so this
/// store stays free of TelegramCore.
public final class SecretVaultManager {
    public static let shared = SecretVaultManager()

    private let suiteName = "pro_messager"
    private let vaultedKey = "fenix_vault_peer_ids"

    private let lock = NSLock()
    private var cachedIds: Set<Int64>?
    private var cachedEnabled: Bool?

    private init() {}

    private var defaults: UserDefaults? {
        return UserDefaults(suiteName: self.suiteName)
    }

    // MARK: - Feature state

    /// True when a vault pincode has been set. Cached so the chat-list filter does
    /// not hit the keychain on every row; call `invalidateEnabledCache()` after the
    /// vault pincode is created or removed.
    public var isEnabled: Bool {
        self.lock.lock()
        if let cached = self.cachedEnabled {
            self.lock.unlock()
            return cached
        }
        self.lock.unlock()
        let value = ChatPincodeManager.shared.isVaultEnabled()
        self.lock.lock()
        // Only memoize a positive result. A false read can happen transiently when the
        // keychain is unreadable (device locked while the chat-list pipeline refreshes in
        // the background); caching it would keep the vault disabled for the whole process
        // lifetime and leak vaulted chats into the main list until relaunch.
        if value {
            self.cachedEnabled = true
        }
        self.lock.unlock()
        return value
    }

    public func invalidateEnabledCache() {
        self.lock.lock()
        self.cachedEnabled = nil
        self.lock.unlock()
    }

    // MARK: - Vaulted set

    public func isVaulted(_ peerId: PeerId) -> Bool {
        return self.rawIds().contains(peerId.toInt64())
    }

    public func vaultedPeerIds() -> Set<PeerId> {
        return Set(self.rawIds().map { PeerId($0) })
    }

    public func count() -> Int {
        return self.rawIds().count
    }

    public func addToVault(_ peerIds: [PeerId]) {
        guard !peerIds.isEmpty else { return }
        self.mutate { ids in
            for peerId in peerIds {
                ids.insert(peerId.toInt64())
            }
        }
    }

    public func removeFromVault(_ peerIds: [PeerId]) {
        guard !peerIds.isEmpty else { return }
        self.mutate { ids in
            for peerId in peerIds {
                ids.remove(peerId.toInt64())
            }
        }
    }

    public func clearVault() {
        self.mutate { $0.removeAll() }
    }

    // MARK: - Internal

    private func rawIds() -> Set<Int64> {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let cached = self.cachedIds {
            return cached
        }
        let stored = self.defaults?.array(forKey: self.vaultedKey) as? [NSNumber] ?? []
        let ids = Set(stored.map { $0.int64Value })
        self.cachedIds = ids
        return ids
    }

    private func mutate(_ transform: (inout Set<Int64>) -> Void) {
        self.lock.lock()
        var ids = self.cachedIds ?? {
            let stored = self.defaults?.array(forKey: self.vaultedKey) as? [NSNumber] ?? []
            return Set(stored.map { $0.int64Value })
        }()
        let before = ids
        transform(&ids)
        self.cachedIds = ids
        let changed = ids != before
        if changed {
            self.defaults?.set(ids.map { NSNumber(value: $0) }, forKey: self.vaultedKey)
        }
        self.lock.unlock()

        if changed {
            NotificationCenter.default.post(name: .fenixSecretVaultChanged, object: nil)
        }
    }
}
