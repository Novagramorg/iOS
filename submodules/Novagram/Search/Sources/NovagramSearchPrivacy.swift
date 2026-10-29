import Foundation
import TelegramCore
import NovagramChatLock
import NovagramSecretVault

// Search privacy: what global search may show of hidden and locked chats.
//
// - A chat in the Secret Vault never shows in search: not as a peer, not with its messages, and
//   also not while the vault list is revealed. This reads the stored vault list, so it also works
//   while the vault has no PIN (`SecretVaultManager.removingVaulted` does nothing then).
// - A chat locked with Chat Lock may show its name (like in the chat list), but never its messages.
//
// Every check is pure: callers build a new pass for each emission and keep nothing between them.

/// One search emission's view of the vault and the chat locks.
///
/// `ChatPincodeManager.isLocked` reads the keychain, so the answer is cached per peer for the life of
/// the pass. Make one pass per emission and use it on one thread only.
public final class NovagramSearchPrivacyPass {
    private let vaultedPeerIds: Set<EnginePeer.Id>
    private var lockedByPeer: [EnginePeer.Id: Bool] = [:]

    public init() {
        self.vaultedPeerIds = SecretVaultManager.shared.vaultedPeerIds()
    }

    /// True when the peer must not show as a search row (it is in the Secret Vault).
    public func hidesPeer(_ peer: EnginePeer) -> Bool {
        return self.isVaulted(anyOf: novagramRelatedPeerIds(peer))
    }

    /// True when the peer must not show as a search row (it is in the Secret Vault).
    public func hidesPeer(id peerId: EnginePeer.Id) -> Bool {
        return self.vaultedPeerIds.contains(peerId)
    }

    /// True when the message must not show in search (its chat is hidden or locked).
    public func hidesMessage(_ message: EngineMessage) -> Bool {
        return self.hidesMessage(message._asMessage())
    }

    /// True when the message must not show in search (its chat is hidden or locked).
    public func hidesMessage(_ message: EngineRawMessage) -> Bool {
        var peerIds: [EnginePeer.Id] = [message.id.peerId]
        if let peer = message.peers[message.id.peerId] {
            peerIds = novagramRelatedPeerIds(EnginePeer(peer))
        }
        if self.isVaulted(anyOf: peerIds) {
            return true
        }
        return peerIds.contains(where: { self.isLocked($0) })
    }

    private func isVaulted(anyOf peerIds: [EnginePeer.Id]) -> Bool {
        guard !self.vaultedPeerIds.isEmpty else {
            return false
        }
        return peerIds.contains(where: { self.vaultedPeerIds.contains($0) })
    }

    private func isLocked(_ peerId: EnginePeer.Id) -> Bool {
        if let cached = self.lockedByPeer[peerId] {
            return cached
        }
        // Not gated on the master PIN: removing the master keeps the per-chat locks, and opening such a
        // chat still asks for its PIN (NavigateToChatController), so its messages stay private too.
        let locked = ChatPincodeManager.shared.isLocked(peerId)
        self.lockedByPeer[peerId] = locked
        return locked
    }
}

/// The chat itself plus the chats that stand for it: a secret chat's user, and the supergroup a basic
/// group was migrated to (old group messages show under the supergroup in search).
private func novagramRelatedPeerIds(_ peer: EnginePeer) -> [EnginePeer.Id] {
    switch peer {
    case let .secretChat(secretChat):
        return [peer.id, secretChat.regularPeerId]
    case let .legacyGroup(group):
        if let migrationReference = group.migrationReference {
            return [peer.id, migrationReference.peerId]
        }
        return [peer.id]
    default:
        return [peer.id]
    }
}

// A found-messages page as the search pane passes it around: messages, total count, has more.
// swiftlint:disable:next large_tuple
public typealias NovagramSearchMessagePage = ([EngineMessage], Int32, Bool) // the pane's own signal type, kept as is

/// List helpers for search sources that are not built inside one emission closure. Each call makes
/// its own pass.
public enum NovagramSearchPrivacy {
    /// For filters that look at one peer at a time (the top peers row).
    public static func hidesPeer(_ peer: EnginePeer) -> Bool {
        return NovagramSearchPrivacyPass().hidesPeer(peer)
    }

    /// Peers without vaulted ones (the peer filter chips above the results).
    public static func keptPeers(_ peers: [EnginePeer]) -> [EnginePeer] {
        let pass = NovagramSearchPrivacyPass()
        return peers.filter { !pass.hidesPeer($0) }
    }

    /// Recent searches without vaulted chats; a secret chat also goes when its user is vaulted.
    public static func keptRecentlySearchedPeers(_ peers: [RecentlySearchedPeer]) -> [RecentlySearchedPeer] {
        let pass = NovagramSearchPrivacyPass()
        return peers.filter { recent in
            let renderedPeer = EngineRenderedPeer(recent.peer)
            if pass.hidesPeer(id: renderedPeer.peerId) {
                return false
            }
            if let peer = renderedPeer.peer, pass.hidesPeer(peer) {
                return false
            }
            if let mainPeer = renderedPeer.chatMainPeer, pass.hidesPeer(mainPeer) {
                return false
            }
            return true
        }
    }

    /// Rows keyed by a peer id without vaulted ones. Rows without a peer id are kept.
    public static func kept<T>(_ items: [T], peerId: (T) -> EnginePeer.Id?) -> [T] {
        let pass = NovagramSearchPrivacyPass()
        return items.filter { item in
            guard let peerId = peerId(item) else {
                return true
            }
            return !pass.hidesPeer(id: peerId)
        }
    }

    /// Rows that carry a message, without those of hidden or locked chats.
    public static func kept<T>(_ items: [T], message: (T) -> EngineRawMessage) -> [T] {
        let pass = NovagramSearchPrivacyPass()
        return items.filter { !pass.hidesMessage(message($0)) }
    }

    /// A found-messages page (messages, total count, has more) for the gallery and the music player
    /// opened from search. The total count drops by the number of messages taken out.
    public static func keptMessagePage(_ page: NovagramSearchMessagePage) -> NovagramSearchMessagePage {
        let pass = NovagramSearchPrivacyPass()
        let messages = page.0.filter { !pass.hidesMessage($0) }
        let removed = Int32(page.0.count - messages.count)
        if removed == 0 {
            return page
        }
        return (messages, max(0, page.1 - removed), page.2)
    }
}
