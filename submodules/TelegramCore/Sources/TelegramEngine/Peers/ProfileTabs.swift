import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_reorderProfileTabs(account: Account, peerId: PeerId, order: [TelegramProfileTab]) -> Signal<Never, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        return account.postbox.transaction { transaction -> Signal<Never, NoError> in
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedProfileTabsOrder(order)
                } else if let current = current as? CachedChannelData {
                    return current.withUpdatedProfileTabsOrder(order)
                } else {
                    return current
                }
            })
            if let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.reorderProfileTabs(channel: inputChannel, order: order.map { $0.apiTab }))
                |> `catch` { error in
                    return .complete()
                }
                |> mapToSignal { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            } else {
                return account.network.request(Api.functions.account.reorderProfileTabs(order: order.map { $0.apiTab }))
                |> `catch` { error in
                    return .complete()
                }
                |> mapToSignal { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            }
        } |> switchToLatest
    }
}
