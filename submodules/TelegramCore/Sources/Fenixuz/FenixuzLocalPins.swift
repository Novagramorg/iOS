import Foundation
import Postbox
import SwiftSignalKit

// Fenixuz "Unlimited Pins" — the device-local half of the feature.
//
// The toggle alone only raises the client-side pre-check in TogglePeerChatPinned (so the Premium
// upsell stops appearing). The pins above the server's `dialogs_pinned_limit` were still written
// into the same list that the server later overwrites on sync, so they silently vanished — the
// user pinned 11 chats and kept 6.
//
// Pinned lists are newest-first (`itemIds.insert(itemId, at: 0)`), and the server keeps the head
// of the list, so the overflow is always the TAIL — which is why users saw the bottom-most pin
// disappear. This store remembers exactly that tail so the sync path can put it back.
//
// Scope is deliberately narrow:
//   * `.group` locations only (main list + archive). Chat filters pin through
//     `ChatListFilterData.includePeers` and are bounded by `maxFolderChatsCount`, a different
//     mechanism the toggle never touched.
//   * Keyed per account — this fork allows up to 999 logged-in accounts, so a global key would
//     leak one account's pins into another's chat list.
//   * Nothing is kept while the toggle is off. Turning it off clears the store, so there is no
//     state to drift out of sync with reality (chats deleted, unpinned elsewhere, and so on).
public enum FenixuzLocalPins {
    private static let suiteName = "pro_messager"
    private static let enabledKey = "unlimited_pins"

    public static var isEnabled: Bool {
        return UserDefaults(suiteName: suiteName)?.bool(forKey: enabledKey) ?? false
    }

    private static func key(accountPeerId: PeerId, groupId: PeerGroupId) -> String {
        return "unlimited_pins_local_\(accountPeerId.toInt64())_\(groupId.rawValue)"
    }

    /// The pins that live only on this device, in display order (they sit below the synced ones).
    public static func overflowPeerIds(accountPeerId: PeerId, groupId: PeerGroupId) -> [PeerId] {
        guard isEnabled, let defaults = UserDefaults(suiteName: suiteName) else {
            return []
        }
        guard let raw = defaults.array(forKey: key(accountPeerId: accountPeerId, groupId: groupId)) as? [NSNumber] else {
            return []
        }
        return raw.map { PeerId($0.int64Value) }
    }

    public static func setOverflowPeerIds(_ peerIds: [PeerId], accountPeerId: PeerId, groupId: PeerGroupId) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        let storeKey = key(accountPeerId: accountPeerId, groupId: groupId)
        if peerIds.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(peerIds.map { NSNumber(value: $0.toInt64()) }, forKey: storeKey)
        }
    }

    public static func removePeerId(_ peerId: PeerId, accountPeerId: PeerId, groupId: PeerGroupId) {
        let current = overflowPeerIds(accountPeerId: accountPeerId, groupId: groupId)
        guard current.contains(peerId) else {
            return
        }
        setOverflowPeerIds(current.filter { $0 != peerId }, accountPeerId: accountPeerId, groupId: groupId)
    }

    /// Drops every stored pin for one account — used when the toggle goes off and on logout.
    public static func clearAll(accountPeerId: PeerId) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        let prefix = "unlimited_pins_local_\(accountPeerId.toInt64())_"
        for storeKey in defaults.dictionaryRepresentation().keys where storeKey.hasPrefix(prefix) {
            defaults.removeObject(forKey: storeKey)
        }
    }

    /// Drops every stored pin for every account — used when the toggle goes off, since the
    /// settings screen has no reason to know which accounts are logged in.
    public static func clearAllAccounts() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return
        }
        let prefix = "unlimited_pins_local_"
        for storeKey in defaults.dictionaryRepresentation().keys where storeKey.hasPrefix(prefix) {
            defaults.removeObject(forKey: storeKey)
        }
    }

    /// Re-appends the device-local pins the server does not know about. Safe to call on any list
    /// the server just handed us: ids already present are left alone, so ordering is preserved and
    /// nothing is duplicated.
    public static func merged(serverItemIds: [PinnedItemId], accountPeerId: PeerId, groupId: PeerGroupId) -> [PinnedItemId] {
        let overflow = overflowPeerIds(accountPeerId: accountPeerId, groupId: groupId)
        guard !overflow.isEmpty else {
            return serverItemIds
        }
        var existing = Set<PeerId>()
        for item in serverItemIds {
            if case let .peer(peerId) = item {
                existing.insert(peerId)
            }
        }
        var result = serverItemIds
        for peerId in overflow where !existing.contains(peerId) {
            result.append(.peer(peerId))
        }
        return result
    }
}

// Turning the toggle off has to actually unpin the overflow, not just forget it. Clearing the
// store alone only stops the merge from re-adding those ids — the pinned list in Postbox still
// holds them, so the user sees every pin survive an "off" that promised to remove them.
func _internal_fenixuzTrimPinnedChatsToServerLimit(postbox: Postbox, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        let isPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
        let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
        let userLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: isPremium)

        for groupId in [PeerGroupId.root, Namespaces.PeerGroup.archive] {
            let limit: Int
            if case .root = groupId {
                limit = Int(userLimitsConfiguration.maxPinnedChatCount)
            } else {
                limit = Int(userLimitsConfiguration.maxArchivedPinnedChatCount)
            }
            let itemIds = transaction.getPinnedItemIds(groupId: groupId)
            guard itemIds.count > limit else {
                continue
            }
            // The list is newest-first and the server keeps its head, so keeping the first `limit`
            // leaves exactly what is already synced and drops only the device-local tail.
            transaction.setPinnedItemIds(groupId: groupId, itemIds: Array(itemIds.prefix(limit)))
            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
        }

        FenixuzLocalPins.clearAll(accountPeerId: accountPeerId)
    }
    |> ignoreValues
}
