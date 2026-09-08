import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

func pendingWalletTransferResolution(_ result: Api.wallet.Transactions, peerId: PeerId) -> (id: String, failed: Bool)? {
    switch result {
    case let .transactions(result):
        var matches: [(id: String, failed: Bool)] = []
        for item in result.transactions {
            switch item {
            case let .walletTransaction(item):
                guard (item.flags & (1 << 0)) == 0,
                      case let .walletTransactionPeerUser(peer) = item.peer,
                      PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(peer.userId)) == peerId else {
                    continue
                }
                matches.append((item.id, (item.flags & (1 << 2)) != 0))
            }
        }
        // A single-user send has one outgoing transfer to this peer. Never guess if
        // the response is ambiguous (or match a relayer's fee transfer by amount).
        return matches.count == 1 ? matches[0] : nil
    }
}

private final class WalletTransferStoreMessageAction: StoreOrUpdateMessageAction {
    let id: MessageId

    init(id: MessageId) {
        self.id = id
    }

    func addOrUpdate(messages: [StoreMessage], transaction: Transaction) {
        for message in messages {
            if replacePendingWalletTransferMessage(transaction: transaction, localId: self.id, serverMessage: message) {
                break
            }
        }
    }
}

private func managedPendingWalletTransferMessage(postbox: Postbox, network: Network, id: MessageId, pending: PendingWalletTransferMessageAttribute) -> Disposable {
    let disposables = DisposableSet()
    // Install first, then inspect stored history, covering updates that arrived
    // before the hash was resolved or while this account was restarting.
    disposables.add(postbox.installStoreOrUpdateMessageAction(peerId: id.peerId, action: WalletTransferStoreMessageAction(id: id)))
    disposables.add(postbox.transaction { transaction in
        guard let current = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute else {
            return
        }
        if current.expiresAt <= pendingWalletTransferTimestamp() {
            removePendingWalletTransferMessage(transaction: transaction, id: id)
        } else {
            reconcileStoredWalletTransferMessage(transaction: transaction, id: id, pending: current)
        }
    }.start())

    let remaining = max(0.0, Double(pending.expiresAt) - Date().timeIntervalSince1970)
    disposables.add((Signal<Void, NoError>.single(Void())
    |> delay(remaining, queue: Queue.concurrentDefaultQueue())
    |> mapToSignal { _ in
        return postbox.transaction { transaction in
            if let current = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute,
               current.expiresAt <= pendingWalletTransferTimestamp() {
                removePendingWalletTransferMessage(transaction: transaction, id: id)
            }
        }
    }).start())

    if let msgHash = pending.msgHash, pending.transactionId == nil, remaining > 0.0 {
        let resolve = network.request(Api.functions.wallet.getTransactionsByMsgHash(msgHash: [msgHash]), automaticFloodWait: false)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.wallet.Transactions?, NoError> in
            return .single(nil)
        }
        |> timeout(10.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
        |> mapToSignal { result -> Signal<Void, NoError> in
            return postbox.transaction { transaction in
                guard let current = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute,
                      current.isEqual(to: pending) else {
                    return
                }
                guard current.expiresAt > pendingWalletTransferTimestamp() else {
                    removePendingWalletTransferMessage(transaction: transaction, id: id)
                    return
                }
                guard let result, let resolution = pendingWalletTransferResolution(result, peerId: id.peerId) else {
                    return
                }
                if resolution.failed {
                    removePendingWalletTransferMessage(transaction: transaction, id: id)
                } else {
                    let updated = current.resolving(transactionId: resolution.id)
                    updatePendingWalletTransferMessage(transaction: transaction, id: id, attribute: updated)
                    reconcileStoredWalletTransferMessage(transaction: transaction, id: id, pending: updated)
                }
            }
        }
        disposables.add((resolve
        |> then(Signal<Void, NoError>.complete() |> delay(2.0, queue: Queue.concurrentDefaultQueue()))
        |> restart).start())
    }
    return disposables
}

private final class PendingWalletTransferMessagesHelper {
    var operations: [MessageId: (PendingWalletTransferMessageAttribute, MetaDisposable)] = [:]

    func update(_ entries: [PendingMessageActionsEntry]) -> (dispose: [Disposable], start: [(MessageId, PendingWalletTransferMessageAttribute, MetaDisposable)]) {
        var dispose: [Disposable] = []
        var start: [(MessageId, PendingWalletTransferMessageAttribute, MetaDisposable)] = []
        let validIds = Set(entries.map(\.id))
        for id in Array(self.operations.keys) where !validIds.contains(id) {
            if let previous = self.operations.removeValue(forKey: id) {
                dispose.append(previous.1)
            }
        }
        for entry in entries {
            guard let pending = entry.action as? PendingWalletTransferMessageAttribute else {
                continue
            }
            if let previous = self.operations[entry.id] {
                if previous.0.isEqual(to: pending) {
                    continue
                }
                dispose.append(previous.1)
            }
            let disposable = MetaDisposable()
            self.operations[entry.id] = (pending, disposable)
            start.append((entry.id, pending, disposable))
        }
        return (dispose, start)
    }
}

func managedPendingWalletTransferMessages(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let helper = Atomic(value: PendingWalletTransferMessagesHelper())
        let key = PostboxViewKey.pendingMessageActions(type: .walletTransfer)
        let disposable = postbox.combinedView(keys: [key]).start(next: { views in
            guard let view = views.views[key] as? PendingMessageActionsView else {
                return
            }
            let changes = helper.with { $0.update(view.entries) }
            for disposable in changes.dispose {
                disposable.dispose()
            }
            for (id, pending, disposable) in changes.start {
                disposable.set(managedPendingWalletTransferMessage(postbox: postbox, network: network, id: id, pending: pending))
            }
        })
        return ActionDisposable {
            disposable.dispose()
            for disposable in helper.with({ $0.update([]).dispose }) {
                disposable.dispose()
            }
        }
    }
}
