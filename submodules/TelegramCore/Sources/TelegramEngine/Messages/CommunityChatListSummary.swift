import Foundation
import Postbox
import SwiftSignalKit

public struct CommunityChatListItemSummary: Equatable {
    public let topMessage: EngineMessage?
    public let readCounters: EnginePeerReadCounters?
    public let topTimestamp: Int32?
    public let hasLinkedPeers: Bool

    public init(topMessage: EngineMessage?, readCounters: EnginePeerReadCounters?, topTimestamp: Int32?, hasLinkedPeers: Bool) {
        self.topMessage = topMessage
        self.readCounters = readCounters
        self.topTimestamp = topTimestamp
        self.hasLinkedPeers = hasLinkedPeers
    }
}

private struct CommunityChatListLinkedPeers: Equatable {
    let communityIds: [PeerId]
    let peerIds: [PeerId: [PeerId]]
}

private func uniquePeerIds(_ peerIds: [PeerId]) -> [PeerId] {
    var seen = Set<PeerId>()
    var result: [PeerId] = []
    for peerId in peerIds {
        if seen.insert(peerId).inserted {
            result.append(peerId)
        }
    }
    return result
}

private func communityChatListLinkedPeers(postbox: Postbox, communityIds: [PeerId]) -> Signal<CommunityChatListLinkedPeers, NoError> {
    let communityIds = uniquePeerIds(communityIds)
    if communityIds.isEmpty {
        return .single(CommunityChatListLinkedPeers(communityIds: [], peerIds: [:]))
    }

    let keys: [PostboxViewKey] = communityIds.map { communityId in
        return .cachedPeerData(peerId: communityId)
    }

    return postbox.combinedView(keys: keys)
    |> map { views -> CommunityChatListLinkedPeers in
        var peerIds: [PeerId: [PeerId]] = [:]
        for communityId in communityIds {
            guard let view = views.views[.cachedPeerData(peerId: communityId)] as? CachedPeerDataView else {
                peerIds[communityId] = []
                continue
            }
            guard let cachedData = view.cachedPeerData as? CachedCommunityData else {
                peerIds[communityId] = []
                continue
            }
            peerIds[communityId] = uniquePeerIds(cachedData.linkedPeers.compactMap { linkedPeer -> PeerId? in
                if linkedPeer.peerId == communityId {
                    return nil
                }
                return linkedPeer.peerId
            })
        }
        return CommunityChatListLinkedPeers(communityIds: communityIds, peerIds: peerIds)
    }
    |> distinctUntilChanged
}

private func aggregateCommunityReadCounters(peerIds: [PeerId], readStates: [PeerId: CombinedPeerReadState], topMessage: Message?) -> EnginePeerReadCounters {
    var count: Int32 = 0
    var markedUnread = false

    for peerId in peerIds {
        if let state = readStates[peerId] {
            count += state.count
            if state.markedUnread {
                markedUnread = true
            }
        }
    }

    let namespace = topMessage?.id.namespace ?? Namespaces.Message.Cloud
    let peerReadState: PeerReadState
    if let topMessage, let topPeerState = readStates[topMessage.id.peerId], let topNamespaceState = topPeerState.states.first(where: { item in
        return item.0 == topMessage.id.namespace
    })?.1 {
        switch topNamespaceState {
        case let .idBased(maxIncomingReadId, maxOutgoingReadId, maxKnownId, _, _):
            peerReadState = .idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread)
        case let .indexBased(maxIncomingReadIndex, maxOutgoingReadIndex, _, _):
            peerReadState = .indexBased(maxIncomingReadIndex: maxIncomingReadIndex, maxOutgoingReadIndex: maxOutgoingReadIndex, count: count, markedUnread: markedUnread)
        }
    } else {
        peerReadState = .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 1, count: count, markedUnread: markedUnread)
    }

    return EnginePeerReadCounters(state: CombinedPeerReadState(states: [(namespace, peerReadState)]), isMuted: false)
}

public func communityChatListItemSummaries(postbox: Postbox, communityIds: [PeerId]) -> Signal<[PeerId: CommunityChatListItemSummary], NoError> {
    return communityChatListLinkedPeers(postbox: postbox, communityIds: communityIds)
    |> mapToSignal { linkedPeers -> Signal<[PeerId: CommunityChatListItemSummary], NoError> in
        let allPeerIds = uniquePeerIds(linkedPeers.communityIds.flatMap { communityId in
            return linkedPeers.peerIds[communityId] ?? []
        })

        if allPeerIds.isEmpty {
            var result: [PeerId: CommunityChatListItemSummary] = [:]
            for communityId in linkedPeers.communityIds {
                result[communityId] = CommunityChatListItemSummary(topMessage: nil, readCounters: nil, topTimestamp: nil, hasLinkedPeers: false)
            }
            return .single(result)
        }

        let topMessageKey: PostboxViewKey = .topChatMessage(peerIds: allPeerIds)
        let topMessages = postbox.combinedView(keys: [topMessageKey])
        |> map { views -> [PeerId: Message] in
            guard let view = views.views[topMessageKey] as? TopChatMessageView else {
                return [:]
            }
            return view.messages
        }

        let readCounts = postbox.unreadMessageCountsView(items: allPeerIds.map { peerId in
            return .peer(id: peerId, handleThreads: true)
        })
        |> map { view -> [PeerId: CombinedPeerReadState] in
            var result: [PeerId: CombinedPeerReadState] = [:]
            for entry in view.entries {
                switch entry {
                case let .peer(peerId, state):
                    if let state {
                        result[peerId] = state
                    }
                case .total, .totalInGroup:
                    break
                }
            }
            return result
        }

        return combineLatest(topMessages, readCounts)
        |> map { topMessages, readCounts -> [PeerId: CommunityChatListItemSummary] in
            var result: [PeerId: CommunityChatListItemSummary] = [:]

            for communityId in linkedPeers.communityIds {
                let peerIds = linkedPeers.peerIds[communityId] ?? []
                let topMessage = peerIds.compactMap { peerId in
                    return topMessages[peerId]
                }.max(by: { lhs, rhs in
                    return lhs.index < rhs.index
                })

                let readCounters: EnginePeerReadCounters?
                if peerIds.isEmpty {
                    readCounters = nil
                } else {
                    readCounters = aggregateCommunityReadCounters(peerIds: peerIds, readStates: readCounts, topMessage: topMessage)
                }

                result[communityId] = CommunityChatListItemSummary(
                    topMessage: topMessage.map { message in
                        return EngineMessage(message)
                    },
                    readCounters: readCounters,
                    topTimestamp: topMessage?.index.timestamp,
                    hasLinkedPeers: !peerIds.isEmpty
                )
            }

            return result
        }
    }
    |> distinctUntilChanged
}

private func refreshCommunityCachedData(accountPeerId: PeerId, postbox: Postbox, network: Network, communityIds: [PeerId]) -> Signal<Never, NoError> {
    if communityIds.isEmpty {
        return .complete()
    }

    let signals: [Signal<Bool, NoError>] = communityIds.map { communityId in
        return _internal_fetchAndUpdateCachedPeerData(accountPeerId: accountPeerId, peerId: communityId, network: network, postbox: postbox)
    }

    return combineLatest(signals)
    |> ignoreValues
}

func managedCommunityChatListItemSummaries(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return _internal_updatedCommunitiesState(postbox: postbox)
    |> map { state -> [PeerId] in
        return state.communityIds ?? []
    }
    |> distinctUntilChanged
    |> mapToSignal { communityIds -> Signal<[PeerId: CommunityChatListItemSummary], NoError> in
        if communityIds.isEmpty {
            return .single([:])
        }

        return Signal { subscriber in
            let disposable = DisposableSet()
            disposable.add(refreshCommunityCachedData(accountPeerId: accountPeerId, postbox: postbox, network: network, communityIds: communityIds).start())
            disposable.add(communityChatListItemSummaries(postbox: postbox, communityIds: communityIds).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion))
            return disposable
        }
    }
    |> map { summaries -> [PeerId: Int32?] in
        return summaries.mapValues { summary in
            return summary.topTimestamp
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { timestamps -> Signal<Never, NoError> in
        if timestamps.isEmpty {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            for (communityId, timestamp) in timestamps {
                guard let community = transaction.getPeer(communityId) as? TelegramCommunity else {
                    continue
                }
                updateCommunityChatListInclusion(transaction: transaction, community: community, minTimestamp: timestamp)
            }
        }
        |> ignoreValues
    }
}
