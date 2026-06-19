import Foundation
import Postbox
import SwiftSignalKit

public struct CommunityPeerLinkRequestsState: Equatable {
    public var requests: [CommunityPeerRequest]
    public var peers: [EnginePeer.Id: EnginePeer]
    public var isLoadingMore: Bool
    public var hasLoadedOnce: Bool
    public var canLoadMore: Bool
    public var count: Int32

    public static var Loading = CommunityPeerLinkRequestsState(
        requests: [],
        peers: [:],
        isLoadingMore: false,
        hasLoadedOnce: false,
        canLoadMore: false,
        count: 0
    )

    public static var Empty = CommunityPeerLinkRequestsState(
        requests: [],
        peers: [:],
        isLoadingMore: false,
        hasLoadedOnce: true,
        canLoadMore: false,
        count: 0
    )
}

private final class CommunityPeerLinkRequestsContextImpl {
    private let queue: Queue
    private let account: Account
    private let communityId: PeerId
    private let initialLimit: Int32
    private let disposable = MetaDisposable()
    private let actionDisposables = DisposableSet()
    private let updateDisposables = DisposableSet()

    private var requests: [CommunityPeerRequest] = []
    private var peers: [EnginePeer.Id: EnginePeer] = [:]
    private var nextOffset: String?
    private var isLoadingMore = false
    private var hasLoadedOnce = false
    private var canLoadMore = true
    private var count: Int32 = 0

    let state = Promise<CommunityPeerLinkRequestsState>()

    init(queue: Queue, account: Account, communityId: PeerId, initialLimit: Int32) {
        self.queue = queue
        self.account = account
        self.communityId = communityId
        self.initialLimit = initialLimit

        self.updateState()
        self.loadMore(limit: initialLimit)
    }

    deinit {
        self.disposable.dispose()
        self.actionDisposables.dispose()
        self.updateDisposables.dispose()
    }

    func loadMore(limit: Int32?) {
        if self.isLoadingMore || !self.canLoadMore {
            return
        }
        self.isLoadingMore = true
        self.updateState()

        let account = self.account
        let communityId = self.communityId
        let offset = self.nextOffset
        let requestLimit = limit ?? self.initialLimit

        self.disposable.set((_internal_communityPeerLinkRequests(
            account: account,
            communityId: communityId,
            offset: offset,
            limit: requestLimit
        )
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }

            var existingIds = Set(strongSelf.requests.map(\.peerId))
            for request in result.requests {
                if existingIds.contains(request.peerId) {
                    continue
                }
                existingIds.insert(request.peerId)
                strongSelf.requests.append(request)
            }
            for (peerId, peer) in result.peers {
                strongSelf.peers[peerId] = peer
            }

            strongSelf.nextOffset = result.nextOffset
            strongSelf.count = max(result.totalCount, Int32(strongSelf.requests.count))
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = result.nextOffset != nil && !result.requests.isEmpty
            if !strongSelf.canLoadMore {
                strongSelf.count = Int32(strongSelf.requests.count)
            }
            strongSelf.updateState()
        }))
    }

    func reload(limit: Int32?) {
        self.disposable.set(nil)
        self.requests = []
        self.peers = [:]
        self.nextOffset = nil
        self.isLoadingMore = false
        self.hasLoadedOnce = false
        self.canLoadMore = true
        self.count = 0
        self.updateState()
        self.loadMore(limit: limit ?? self.initialLimit)
    }

    func update(_ request: CommunityPeerRequest, action: CommunityPeerLinkRequestsContext.UpdateAction) {
        self.actionDisposables.add(_internal_toggleCommunityPeerLinkRequestApproval(
            account: self.account,
            communityId: self.communityId,
            peerId: request.peerId,
            approve: action == .approve
        ).start())

        self.requests.removeAll(where: { $0.peerId == request.peerId })
        self.count = max(0, self.count - 1)
        self.updateCachedData(approvedRequests: action == .approve ? [request] : [], pendingRequestsCount: self.count)
        self.updateState()
    }

    func updateAll(action: CommunityPeerLinkRequestsContext.UpdateAction) {
        self.actionDisposables.add(_internal_toggleAllCommunityPeerLinkRequestApproval(
            account: self.account,
            communityId: self.communityId,
            approve: action == .approve
        ).start())

        let approvedRequests = action == .approve ? self.requests : []
        self.requests = []
        self.count = 0
        self.canLoadMore = false
        self.nextOffset = nil
        self.updateCachedData(approvedRequests: approvedRequests, pendingRequestsCount: 0)
        self.updateState()
    }

    private func updateCachedData(approvedRequests: [CommunityPeerRequest], pendingRequestsCount: Int32) {
        let communityId = self.communityId
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            transaction.updatePeerCachedData(peerIds: Set([communityId]), update: { _, current in
                guard let current = current as? CachedCommunityData else {
                    return current
                }

                var linkedPeers = current.linkedPeers
                if !approvedRequests.isEmpty {
                    var existingIds = Set(linkedPeers.map(\.peerId))
                    for request in approvedRequests {
                        if existingIds.contains(request.peerId) {
                            continue
                        }
                        existingIds.insert(request.peerId)
                        linkedPeers.append(CachedCommunityData.CommunityLinkedPeer(peerId: request.peerId, visible: request.isVisible))
                    }
                }

                return current
                    .withUpdatedLinkedPeers(linkedPeers)
                    .withUpdatedPendingRequests(pendingRequestsCount)
            })
        }).start())
    }

    private func updateState() {
        self.state.set(.single(CommunityPeerLinkRequestsState(
            requests: self.requests,
            peers: self.peers,
            isLoadingMore: self.isLoadingMore,
            hasLoadedOnce: self.hasLoadedOnce,
            canLoadMore: self.canLoadMore,
            count: self.count
        )))
    }
}

public final class CommunityPeerLinkRequestsContext {
    public enum UpdateAction {
        case approve
        case deny
    }

    private let queue = Queue()
    private let impl: QueueLocalObject<CommunityPeerLinkRequestsContextImpl>

    public var state: Signal<CommunityPeerLinkRequestsState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }

    init(account: Account, communityId: PeerId, initialLimit: Int32) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return CommunityPeerLinkRequestsContextImpl(queue: queue, account: account, communityId: communityId, initialLimit: initialLimit)
        })
    }

    public func loadMore(limit: Int32 = 100) {
        self.impl.with { impl in
            impl.loadMore(limit: limit)
        }
    }

    public func reload(limit: Int32? = nil) {
        self.impl.with { impl in
            impl.reload(limit: limit)
        }
    }

    public func update(_ request: CommunityPeerRequest, action: UpdateAction) {
        self.impl.with { impl in
            impl.update(request, action: action)
        }
    }

    public func updateAll(action: UpdateAction) {
        self.impl.with { impl in
            impl.updateAll(action: action)
        }
    }
}
