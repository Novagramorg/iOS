import Foundation
import Postbox
import TelegramCore
import AccountContext
import SwiftSignalKit

// Fenixuz Feature #45: auto-approve pending join requests for channels/groups the user admins.
// Enabled by "fenix_autoaccept_global" in the "pro_messager" UserDefaults suite.
//
// Two entry points:
//   1. autoApproveIfNeeded(...) — fast path from ChatController.viewDidAppear (opened chat).
//   2. startGlobalMonitor(...)  — proactive path: scans admin peers on launch + every 60s so
//      requests are approved even for chats the admin never opens.
// Both approve only when the peer actually has pending requests (inviteRequestsPending > 0),
// so we never spam messages.hideAllChatJoinRequests on empty chats.
// All access happens on the main queue.
public final class FenixAutoAcceptManager {

    // Keep importer contexts alive so their in-flight network requests aren't cancelled on dealloc.
    private static var retainedContexts: [PeerId: PeerInvitationImportersContext] = [:]

    // Short per-peer debounce so a genuinely-new request isn't suppressed for minutes.
    private static var lastApprovedAt: [PeerId: Int32] = [:]
    private static let cooldownSeconds: Int32 = 15

    // Global-monitor state.
    private static let monitorDisposable = MetaDisposable()
    private static var monitorActive = false
    private static weak var monitorContext: AccountContext?
    private static var monitorGeneration = 0
    private static let pollIntervalSeconds: Double = 60.0
    private static let chatListScanCount = 300

    private static var isEnabled: Bool {
        return UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_autoaccept_global") == true
    }

    // MARK: - Fast path (viewDidAppear)

    /// Call from ChatController.viewDidAppear. No-op if the flag is off or user is not an admin.
    public static func autoApproveIfNeeded(context: AccountContext, peerId: PeerId, peer: Peer?) {
        guard isEnabled else { return }

        if let peer = peer {
            if canApproveRequests(peer: peer) {
                approveIfPending(context: context, peerId: peerId)
            }
            return
        }

        // Cold viewDidAppear can pass a nil peer before it is populated — resolve it first.
        _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { resolved in
            guard isEnabled, let resolvedPeer = resolved?._asPeer(), canApproveRequests(peer: resolvedPeer) else { return }
            approveIfPending(context: context, peerId: peerId)
        })
    }

    // MARK: - Global monitor

    /// Start (or re-point) the proactive scan for the given authorized account.
    public static func startGlobalMonitor(context: AccountContext) {
        guard isEnabled else { return }
        if monitorActive && monitorContext === context { return }

        monitorContext = context
        monitorActive = true
        monitorGeneration += 1
        scheduleScan(generation: monitorGeneration, delay: 0.5)
    }

    /// Stop the proactive scan (called when the toggle is turned off or no account is active).
    public static func stopGlobalMonitor() {
        monitorActive = false
        monitorContext = nil
        monitorGeneration += 1 // invalidate any already-scheduled scans
        monitorDisposable.set(nil)
    }

    private static func scheduleScan(generation: Int, delay: Double) {
        Queue.mainQueue().after(delay, {
            guard monitorActive, generation == monitorGeneration, isEnabled, let context = monitorContext else { return }
            scanAdminPeers(context: context)
            scheduleScan(generation: generation, delay: pollIntervalSeconds)
        })
    }

    private static func scanAdminPeers(context: AccountContext) {
        let signal = context.engine.messages.chatList(group: .root, count: chatListScanCount)
        |> take(1)
        |> deliverOnMainQueue
        monitorDisposable.set(signal.startStrict(next: { chatList in
            guard monitorActive, isEnabled else { return }
            for item in chatList.items {
                guard let enginePeer = item.renderedPeer.chatMainPeer else { continue }
                if canApproveRequests(peer: enginePeer._asPeer()) {
                    approveIfPending(context: context, peerId: enginePeer.id)
                }
            }
        }))
    }

    // MARK: - Approve

    /// Read cached data for the peer and approve all requests only if some are pending.
    private static func approveIfPending(context: AccountContext, peerId: PeerId) {
        let now = Int32(Date().timeIntervalSince1970)
        if let last = lastApprovedAt[peerId], now - last < cooldownSeconds { return }

        _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.CachedData(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { cachedData in
            guard pendingRequestCount(cachedData) > 0 else { return }
            let now = Int32(Date().timeIntervalSince1970)
            if let last = lastApprovedAt[peerId], now - last < cooldownSeconds { return }
            lastApprovedAt[peerId] = now
            approveAll(context: context, peerId: peerId)
        })
    }

    private static func pendingRequestCount(_ cachedData: CachedPeerData?) -> Int32 {
        if let channel = cachedData as? CachedChannelData {
            return channel.inviteRequestsPending ?? 0
        } else if let group = cachedData as? CachedGroupData {
            return group.inviteRequestsPending ?? 0
        }
        return 0
    }

    private static func approveAll(context: AccountContext, peerId: PeerId) {
        let importersContext = context.engine.peers.peerInvitationImporters(
            peerId: peerId,
            subject: .requests(query: nil)
        )
        retainedContexts[peerId] = importersContext
        importersContext.updateAll(action: .approve)

        // Release 30 s later — comfortably after the Telegram API call finishes.
        Queue.mainQueue().after(30.0, {
            retainedContexts.removeValue(forKey: peerId)
        })
    }

    // MARK: - Gating

    // Returns true when the local peer object indicates the current user can approve requests.
    // Matches upstream's canManageInvitations gate (creator OR admin with canInviteUsers rights).
    private static func canApproveRequests(peer: Peer?) -> Bool {
        if let channel = peer as? TelegramChannel {
            return channel.hasPermission(.inviteMembers)
        } else if let group = peer as? TelegramGroup {
            switch group.role {
            case .creator:
                return true
            case let .admin(rights, _):
                return rights.rights.contains(.canInviteUsers)
            case .member:
                return false
            }
        }
        return false
    }
}
