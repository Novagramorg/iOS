import Foundation
import Postbox
import TelegramCore
import AccountContext
import SwiftSignalKit

// Fenixuz Feature #45: auto-approve pending join requests when a channel/group chat opens.
// Enabled by "fenix_autoaccept_global" in the "pro_messager" UserDefaults suite.
// Only fires when the user has admin invite rights on the peer.
// All access must happen on the main queue (callers are viewDidAppear, which is main-thread).
public final class FenixAutoAcceptManager {

    // Keep contexts alive so their in-flight network requests aren't cancelled on dealloc.
    private static var retainedContexts: [PeerId: PeerInvitationImportersContext] = [:]

    // Track last approve time to avoid hammering the API on rapid navigation.
    private static var lastApprovedAt: [PeerId: Int32] = [:]
    private static let cooldownSeconds: Int32 = 300 // 5 minutes

    /// Call from ChatController.viewDidAppear. No-op if the flag is off or user is not an admin.
    public static func autoApproveIfNeeded(context: AccountContext, peerId: PeerId, peer: Peer?) {
        guard UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_autoaccept_global") == true else { return }
        guard canApproveRequests(peer: peer) else { return }

        let now = Int32(Date().timeIntervalSince1970)
        if let last = lastApprovedAt[peerId], now - last < cooldownSeconds { return }
        lastApprovedAt[peerId] = now

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

    // Returns true when the local peer object indicates the current user can approve requests.
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
