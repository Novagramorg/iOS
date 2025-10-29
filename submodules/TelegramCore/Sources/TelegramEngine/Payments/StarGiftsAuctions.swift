import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

private func _internal_getStarGiftAuctionState(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id, giftId: Int64, version: Int32) -> Signal<(state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> {
    return network.request(Api.functions.payments.getStarGiftAuctionState(giftId: giftId, version: version))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.StarGiftAuctionState?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<(state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> in
        guard let result else {
            return .single(nil)
        }
        return postbox.transaction { transaction -> (state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)? in
            switch result {
            case let .starGiftAuctionState(state, userState, timeout, users):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                
                return (
                    state: GiftAuctionContext.State.AuctionState(apiAuctionState: state),
                    myState: GiftAuctionContext.State.MyState(apiAuctionUserState: userState),
                    timeout: timeout
                )
            }
        }
    }
}

public final class GiftAuctionContext {
    public struct State: Equatable {
        public struct BidLevel: Equatable {
            public var position: Int32
            public var amount: Int64
            public var date: Int32
        }
        
        public enum AuctionState: Equatable {
            case ongoing(version: Int32, minBidAmount: Int64, bidLevels: [BidLevel], topBidders: [EnginePeer.Id], dropSize: Int32, nextDropDate: Int32, dropsLeft: Int32, dropsTotal: Int32)
            case finished
        }
        
        public struct MyState: Equatable {
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var acquiredCount: Int32
        }
        
        public var auctionState: AuctionState
        public var myState: MyState
    }
    
    private let queue: Queue = .mainQueue()
    private let account: Account
    private let giftId: Int64
    
    private let disposable = MetaDisposable()
    
    private var auctionState: State.AuctionState?
    private var myState: State.MyState?
    private var timeout: Int32?
    
    private var updateAuctionStateDisposable: Disposable?
    private var updateMyStateDisposable: Disposable?
    private var updateTimer: SwiftSignalKit.Timer?
    
    private let stateValue = Promise<State?>()
    public var state: Signal<State?, NoError> {
        return self.stateValue.get()
    }
    
    public init(account: Account, giftId: Int64) {
        self.account = account
        self.giftId = giftId
        
        self.load()
        
        self.updateAuctionStateDisposable = (self.account.stateManager.updatedStarGiftAuctionState()
        |> mapToSignal { updates in
            if let update = updates[giftId] {
                return .single(update)
            }
            return .complete()
        }
        |> deliverOnMainQueue).start(next: { [weak self] auctionState in
            guard let self else {
                return
            }
            if case let .ongoing(version, _, _, _, _, _, _, _) = auctionState, version < self.currentVersion {
            } else {
                self.auctionState = auctionState
            }
            self.pushState()
        })
        
        self.updateMyStateDisposable = (self.account.stateManager.updatedStarGiftAuctionMyState()
        |> mapToSignal { updates in
            if let update = updates[giftId] {
                return .single(update)
            }
            return .complete()
        }
        |> deliverOnMainQueue).start(next: { [weak self] myState in
            guard let self else {
                return
            }
            self.myState = myState
            self.pushState()
        })
    }
    
    deinit {
        self.updateAuctionStateDisposable?.dispose()
        self.updateMyStateDisposable?.dispose()
        self.updateTimer?.invalidate()
        self.disposable.dispose()
    }
    
    private var currentVersion: Int32 {
        var currentVersion: Int32 = 0
        if case let  .ongoing(version, _, _, _, _, _, _, _) = self.auctionState {
            currentVersion = version
        }
        return currentVersion
    }
        
    public func load() {
        self.pushState()

        self.disposable.set((_internal_getStarGiftAuctionState(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, giftId: self.giftId, version: self.currentVersion)
        |> deliverOn(self.queue)).start(next: { [weak self] data in
            guard let self else {
                return
            }
            guard let (auctionState, myState, timeout) = data else {
                return
            }
            
            if case let .ongoing(version, _, _, _, _, _, _, _) = auctionState, version < self.currentVersion {
            } else if let auctionState {
                self.auctionState = auctionState
            }
            self.myState = myState
            self.timeout = timeout
            
            self.pushState()
            
            self.updateTimer?.invalidate()
            self.updateTimer = SwiftSignalKit.Timer(timeout: Double(timeout), repeat: false, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.load()
            }, queue: Queue.mainQueue())
            self.updateTimer?.start()
        }))
    }
    
    private func pushState() {
        if let auctionState = self.auctionState, let myState = self.myState {
            self.stateValue.set(.single(
                State(auctionState: auctionState, myState: myState)
            ))
        } else {
            self.stateValue.set(.single(nil))
        }
    }
}

extension GiftAuctionContext.State.BidLevel {
    init(apiBidLevel: Api.AuctionBidLevel) {
        switch apiBidLevel {
        case let .auctionBidLevel(pos, amount, date):
            self.position = pos
            self.amount = amount
            self.date = date
        }
    }
}

extension GiftAuctionContext.State.AuctionState {
    init?(apiAuctionState: Api.StarGiftAuctionState) {
        switch apiAuctionState {
        case let .starGiftAuctionState(version, minBidAmount, bidLevels, topBidders, dropSize, nextDropAt, dropsLeft, dropsTotal):
            self = .ongoing(version: version, minBidAmount: minBidAmount, bidLevels: bidLevels.map(GiftAuctionContext.State.BidLevel.init(apiBidLevel:)), topBidders: topBidders.map { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }, dropSize: dropSize, nextDropDate: nextDropAt, dropsLeft: dropsLeft, dropsTotal: dropsTotal)
        case .starGiftAuctionStateFinished:
            self = .finished
        case .starGiftAuctionStateNotModified:
            return nil
        }
    }
}

extension GiftAuctionContext.State.MyState {
    init(apiAuctionUserState: Api.StarGiftAuctionUserState) {
        switch apiAuctionUserState {
        case let .starGiftAuctionUserState(_, bidAmount, bidDate, minBidAmount, acquiredCount):
            self.bidAmount = bidAmount
            self.bidDate = bidDate
            self.minBidAmount = minBidAmount
            self.acquiredCount = acquiredCount
        }
    }
}
