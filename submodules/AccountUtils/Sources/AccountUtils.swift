import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext

// Fenixuz: account limit raised 3 -> 20 (owner request). This is a CLIENT-SIDE cap only —
// Telegram's server does not limit how many independent login sessions one app holds, so no
// Premium is required. Premium constant kept in sync (it is currently unused in the add-account
// gate, which reads maximumNumberOfAccounts).
public let maximumNumberOfAccounts = 20
public let maximumPremiumNumberOfAccounts = 20

public func activeAccountsAndPeers(context: AccountContext, includePrimary: Bool = false) -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> {
    let sharedContext = context.sharedContext
    return context.sharedContext.activeAccountContexts
    |> mapToSignal { primary, activeAccounts, _ -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> in
        var accounts: [Signal<(AccountContext, EnginePeer, Int32)?, NoError>] = []
        func accountWithPeer(_ context: AccountContext) -> Signal<(AccountContext, EnginePeer, Int32)?, NoError> {
            return combineLatest(context.account.postbox.peerView(id: context.account.peerId), renderedTotalUnreadCount(accountManager: sharedContext.accountManager, engine: context.engine))
            |> map { view, totalUnreadCount -> (EnginePeer?, Int32) in
                return (view.peers[view.peerId].flatMap(EnginePeer.init), totalUnreadCount.0)
            }
            |> distinctUntilChanged { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            }
            |> map { peer, totalUnreadCount -> (AccountContext, EnginePeer, Int32)? in
                if let peer = peer {
                    return (context, peer, totalUnreadCount)
                } else {
                    return nil
                }
            }
        }
        for (_, context, _) in activeAccounts {
            accounts.append(accountWithPeer(context))
        }
        
        return combineLatest(accounts)
        |> map { accounts -> ((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]) in
            var primaryRecord: (AccountContext, EnginePeer)?
            if let first = accounts.filter({ $0?.0.account.id == primary?.account.id }).first, let (account, peer, _) = first {
                primaryRecord = (account, peer)
            }
            let accountRecords: [(AccountContext, EnginePeer, Int32)] = (includePrimary ? accounts : accounts.filter({ $0?.0.account.id != primary?.account.id })).compactMap({ $0 })
            return (primaryRecord, accountRecords)
        }
    }
}
