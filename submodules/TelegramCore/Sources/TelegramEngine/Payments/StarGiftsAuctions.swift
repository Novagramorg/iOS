import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum StarGiftAuctionReference: Equatable {
    case giftId(Int64)
    case slug(String)
    
    var apiAuction: Api.InputStarGiftAuction {
        switch self {
        case let .giftId(giftId):
            return .inputStarGiftAuction(giftId: giftId)
        case let .slug(slug):
            return .inputStarGiftAuctionSlug(slug: slug)
        }
    }
}

private func _internal_getStarGiftAuctionState(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id, reference: StarGiftAuctionReference, version: Int32) -> Signal<(gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> {
    return network.request(Api.functions.payments.getStarGiftAuctionState(auction: reference.apiAuction, version: version))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.StarGiftAuctionState?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<(gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)?, NoError> in
        guard let result else {
            return .single(nil)
        }
        return postbox.transaction { transaction -> (gift: StarGift, state: GiftAuctionContext.State.AuctionState?, myState: GiftAuctionContext.State.MyState, timeout: Int32)? in
            switch result {
            case let .starGiftAuctionState(apiGift, state, userState, timeout, users):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                guard let gift = StarGift(apiStarGift: apiGift) else {
                    return nil
                }
                return (
                    gift: gift,
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
            case ongoing(version: Int32, minBidAmount: Int64, bidLevels: [BidLevel], topBidders: [EnginePeer.Id], nextRoundDate: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32)
            case finished(startDate: Int32, endDate: Int32, averagePrice: Int64)
        }
        
        public struct MyState: Equatable {
            public var isOutbid: Bool
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var acquiredCount: Int32
        }
        
        public var gift: StarGift
        public var auctionState: AuctionState
        public var myState: MyState
    }
    
    private let queue: Queue = .mainQueue()
    private let account: Account
    public let gift: StarGift
    
    private let disposable = MetaDisposable()
    
    private var auctionState: State.AuctionState?
    private var myState: State.MyState?
    private var timeout: Int32?
    
    private var updateTimer: SwiftSignalKit.Timer?
    
    private let stateValue = Promise<State?>()
    public var state: Signal<State?, NoError> {
        return self.stateValue.get()
    }
    
    public convenience init(account: Account, gift: StarGift) {
        self.init(account: account, gift: gift, initialAuctionState: nil, initialMyState: nil, initialTimeout: nil)
    }
    
    init(account: Account, gift: StarGift, initialAuctionState: State.AuctionState?, initialMyState: State.MyState?, initialTimeout: Int32?) {
        self.account = account
        self.gift = gift
        
        self.auctionState = initialAuctionState
        self.myState = initialMyState
        self.timeout = initialTimeout
        
        self.load()
    }
    
    deinit {
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

        self.disposable.set((_internal_getStarGiftAuctionState(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, reference: .giftId(self.gift.giftId), version: self.currentVersion)
        |> deliverOn(self.queue)).start(next: { [weak self] data in
            guard let self else {
                return
            }
            guard let (_, auctionState, myState, timeout) = data else {
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
        
    func updateAuctionState(_ auctionState: GiftAuctionContext.State.AuctionState) {
        self.auctionState = auctionState
        self.pushState()
    }
    
    func updateMyState(_ myState: GiftAuctionContext.State.MyState) {
        self.myState = myState
        self.pushState()
    }
    
    private func pushState() {
        if let auctionState = self.auctionState, let myState = self.myState {
            self.stateValue.set(
                .single(State(
                    gift: self.gift,
                    auctionState: auctionState,
                    myState: myState
                ))
            )
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
        case let .starGiftAuctionState(version, startDate, endDate, minBidAmount, bidLevels, topBidders, nextRoundAt, giftsLeft, currentRound, totalRounds):
            let _ = startDate
            let _ = endDate
            self = .ongoing(version: version, minBidAmount: minBidAmount, bidLevels: bidLevels.map(GiftAuctionContext.State.BidLevel.init(apiBidLevel:)), topBidders: topBidders.map { EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }, nextRoundDate: nextRoundAt, giftsLeft: giftsLeft, currentRound: currentRound, totalRounds: totalRounds)
        case let .starGiftAuctionStateFinished(startDate, endDate, averagePrice):
            self = .finished(startDate: startDate, endDate: endDate, averagePrice: averagePrice)
        case .starGiftAuctionStateNotModified:
            return nil
        }
    }
}

extension GiftAuctionContext.State.MyState {
    init(apiAuctionUserState: Api.StarGiftAuctionUserState) {
        switch apiAuctionUserState {
        case let .starGiftAuctionUserState(flags, bidAmount, bidDate, minBidAmount, acquiredCount):
            self.isOutbid = (flags & (1 << 1)) != 0
            self.bidAmount = bidAmount
            self.bidDate = bidDate
            self.minBidAmount = minBidAmount
            self.acquiredCount = acquiredCount
        }
    }
}

public struct GiftAuctionAcquiredGift {
    public var nameHidden: Bool
    public let peer: EnginePeer
    public let date: Int32
    public let bidAmount: Int64
    public let round: Int32
    public let position: Int32
    public let text: String?
    public let entities: [MessageTextEntity]?
}

func _internal_getGiftAuctionAcquiredGifts(account: Account, giftId: Int64) -> Signal<[GiftAuctionAcquiredGift], NoError> {
    return account.network.request(Api.functions.payments.getStarGiftAuctionAcquiredGifts(giftId: giftId))
    |> map(Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
    |> mapToSignal { result in
        guard let result else {
            return .single([])
        }
        return account.postbox.transaction { transaction -> [GiftAuctionAcquiredGift] in
            switch result {
            case let .starGiftAuctionAcquiredGifts(gifts, users, chats):
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                var mappedGifts: [GiftAuctionAcquiredGift] = []
                for gift in gifts {
                    switch gift {
                    case let .starGiftAuctionAcquiredGift(flags, peerId, date, bidAmount, round, pos, message):
                        if let peer = transaction.getPeer(peerId.peerId) {
                            var text: String?
                            var entities: [MessageTextEntity]?
                            switch message {
                            case let .textWithEntities(textValue, entitiesValue):
                                text = textValue
                                entities = messageTextEntitiesFromApiEntities(entitiesValue)
                            default:
                                break
                            }
                            mappedGifts.append(GiftAuctionAcquiredGift(
                                nameHidden: (flags & (1 << 0)) != 0,
                                peer: EnginePeer(peer),
                                date: date,
                                bidAmount: bidAmount,
                                round: round,
                                position: pos,
                                text: text,
                                entities: entities
                            ))
                        }
                    }
                }
                return mappedGifts
            }
        }
    }
}

func _internal_getActiveGiftAuctions(account: Account, hash: Int64) -> Signal<[GiftAuctionContext]?, NoError> {
    return account.network.request(Api.functions.payments.getStarGiftActiveAuctions(hash: hash))
    |> retryRequest
    |> mapToSignal { result in
        return account.postbox.transaction { transaction -> [GiftAuctionContext]? in
            switch result {
            case let .starGiftActiveAuctions(auctions, users):
                let parsedPeers = AccumulatedPeers(users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                var auctionContexts: [GiftAuctionContext] = []
                for auction in auctions {
                    switch auction {
                    case let .starGiftActiveAuctionState(apiGift, auctionState, userState):
                        guard let gift = StarGift(apiStarGift: apiGift) else {
                            continue
                        }
                        auctionContexts.append(GiftAuctionContext(
                            account: account,
                            gift: gift,
                            initialAuctionState: GiftAuctionContext.State.AuctionState(apiAuctionState: auctionState),
                            initialMyState: GiftAuctionContext.State.MyState(apiAuctionUserState: userState),
                            initialTimeout: nil
                        ))
                    }
                }

                return auctionContexts
            case .starGiftActiveAuctionsNotModified:
                return nil
            }
        }
    }
}

public class GiftAuctionsManager {
    private let account: Account
    private var auctionContexts: [Int64 : GiftAuctionContext] = [:]
    
    private let disposable = MetaDisposable()
    private var updateAuctionStateDisposable: Disposable?
    private var updateMyStateDisposable: Disposable?
        
    private let statePromise = Promise<[GiftAuctionContext.State]>([])
    public var state: Signal<[GiftAuctionContext.State], NoError> {
        return self.statePromise.get()
    }
    
    public init(account: Account) {
        self.account = account
        
        self.updateAuctionStateDisposable = (self.account.stateManager.updatedStarGiftAuctionState()
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let self else {
                return
            }
            var reload = false
            for (giftId, update) in updates {
                if let auctionContext = self.auctionContexts[giftId] {
                    auctionContext.updateAuctionState(update)
                } else {
                    reload = true
                    break
                }
            }
            if reload {
                self.reload()
            }
        })
        
        self.updateMyStateDisposable = (self.account.stateManager.updatedStarGiftAuctionMyState()
        |> deliverOnMainQueue).start(next: { [weak self] updates in
            guard let self else {
                return
            }
            var reload = false
            for (giftId, update) in updates {
                if let auctionContext = self.auctionContexts[giftId] {
                    auctionContext.updateMyState(update)
                } else {
                    reload = true
                    break
                }
            }
            if reload {
                self.reload()
            }
        })
        
        self.reload()
    }
    
    deinit {
        self.disposable.dispose()
        self.updateAuctionStateDisposable?.dispose()
        self.updateMyStateDisposable?.dispose()
    }
    
    public func reload() {
        self.disposable.set((_internal_getActiveGiftAuctions(account: self.account, hash: 0)
        |> deliverOnMainQueue).startStrict(next: { [weak self] activeAuctions in
            guard let self, let activeAuctions else {
                return
            }
            var auctionContexts: [Int64 : GiftAuctionContext] = [:]
            for auction in activeAuctions {
                auctionContexts[auction.gift.giftId] = auction
            }
            self.auctionContexts = auctionContexts
            self.updateState()
        }))
    }
    
    public func auctionContext(for reference: StarGiftAuctionReference) -> Signal<GiftAuctionContext?, NoError> {
        if case let .giftId(id) = reference, let current = self.auctionContexts[id] {
            return .single(current)
        } else {
            return _internal_getStarGiftAuctionState(
                postbox: self.account.postbox,
                network: self.account.network,
                accountPeerId: self.account.peerId,
                reference: reference,
                version: 0
            ) |> mapToSignal { [weak self] result in
                if let self, let result {
                    let auctionContext = GiftAuctionContext(account: self.account, gift: result.gift, initialAuctionState: result.state, initialMyState: result.myState, initialTimeout: result.timeout)
                    self.auctionContexts[result.gift.giftId] = auctionContext
                    self.updateState()
                    return .single(auctionContext)
                } else {
                    return .single(nil)
                }
            }
        }
    }

    func storeAuctionContext(auctionContext: GiftAuctionContext) {
        self.auctionContexts[auctionContext.gift.giftId] = auctionContext
        self.updateState()
    }
    
    private func updateState() {
        var signals: [Signal<GiftAuctionContext.State, NoError>] = []
        for (_, auction) in self.auctionContexts {
            signals.append(auction.state
            |> mapToSignal { state in
                if let state {
                    return .single(state)
                } else {
                    return .complete()
                }
            })
        }
        self.statePromise.set(combineLatest(signals))
    }
}

public extension GiftAuctionContext.State {
    var place: Int32? {
        guard case let .ongoing(_, _, bidLevels, _, _, _, _, _) = self.auctionState, let myBid = self.myState.bidAmount, let myBidDate = self.myState.bidDate else {
            return nil
        }
        var place: Int32 = 1
        for level in bidLevels {
            if myBid < level.amount || (myBid == level.amount && myBidDate > level.date) {
                place = level.position + 1
            }
        }
        return place
    }
}
