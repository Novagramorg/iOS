import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

// Fenixuz Ghost mode — "read on send".
//
// Ghost mode suppresses passive read receipts: opening a chat does not tell the sender
// you saw their message (see the isFenixuzGhostModeActive guards in
// SynchronizePeerReadState.swift). But once you REPLY, hiding the read looks wrong — it
// appears you answered without reading. So sending a message in a chat explicitly pushes
// the read receipt for that chat, bypassing the Ghost suppression with a direct request.
//
// Called from the chat send path when Ghost mode is on. No-op when Ghost is off.
public func fenixuzForceReadHistory(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    guard isFenixuzGhostModeActive else {
        return .complete()
    }
    return account.postbox.transaction { transaction -> (Peer, Int32)? in
        guard let peer = transaction.getPeer(peerId) else {
            return nil
        }
        // LOCAL read — clear the unread badge. Use the top CLOUD index (incoming messages live in
        // the Cloud namespace). The namespace-agnostic top would return the just-sent PENDING
        // message (Local namespace) and mark the wrong read state, leaving Cloud incoming unread.
        guard let topCloudIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) else {
            return nil
        }
        _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: account.stateManager, index: topCloudIndex)
        return (peer, topCloudIndex.id.id)
    }
    |> mapToSignal { peerAndMaxId -> Signal<Never, NoError> in
        guard let (peer, maxId) = peerAndMaxId else {
            return .complete()
        }
        if let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxId))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> ignoreValues
        } else if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                if let result = result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        account.stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        } else {
            return .complete()
        }
    }
}
