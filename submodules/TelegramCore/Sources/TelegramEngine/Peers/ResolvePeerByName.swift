import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum ResolvePeerIdByNameResult {
    case progress
    case result(PeerId?)
}

public enum ResolvePeerResult {
    case progress
    case result(EnginePeer?)
}

func _internal_resolvePeerByName(account: Account, name: String, referrer: String?, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerIdByNameResult, NoError> {
    return _internal_resolvePeerByName(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, name: name, referrer: referrer, ageLimit: ageLimit)
}
    
func _internal_resolvePeerByName(postbox: Postbox, network: Network, accountPeerId: PeerId, name: String, referrer: String?, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerIdByNameResult, NoError> {
    var normalizedName = name
    if normalizedName.hasPrefix("@") {
       normalizedName = String(normalizedName[name.index(after: name.startIndex)...])
    }
    
    return postbox.transaction { transaction -> CachedResolvedByNamePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)))?.get(CachedResolvedByNamePeer.self)
    }
    |> mapToSignal { cachedEntry -> Signal<ResolvePeerIdByNameResult, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if referrer == nil, let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(.result(cachedEntry.peerId))
        } else {
            var flags: Int32 = 0
            if referrer != nil {
                flags |= 1 << 0
            }
            return .single(.progress)
            |> then(network.request(Api.functions.contacts.resolveUsername(flags: flags, username: normalizedName, referer: referrer))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<ResolvePeerIdByNameResult, Void> in
                return postbox.transaction { transaction -> ResolvePeerIdByNameResult in
                    var peerId: PeerId? = nil
                    
                    switch result {
                    case let .resolvedPeer(resolvedPeerData):
                        let (apiPeer, chats, users) = (resolvedPeerData.peer, resolvedPeerData.chats, resolvedPeerData.users)
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                        if let peer = parsedPeers.get(apiPeer.peerId) {
                            peerId = peer.id
                            
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByNamePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)), entry: entry)
                    }
                    return .result(peerId)
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<ResolvePeerIdByNameResult, NoError> in
                return .single(.result(nil))
            })
        }
    }
}

// A phone lookup has three outcomes, and collapsing the last two loses real information:
// the server answered and knows the user, the server answered and does not, or the request never
// got an answer at all (no connection, a frozen or bot session, a rejected method). The UI used to
// render all three as "this number is not on Telegram", which is a confident lie in the third case.
public enum ResolvedPeerByPhone {
    /// The server answered. `nil` means it genuinely reports no such user.
    case answered(PeerId?)
    /// The request failed. We do not know whether the number is on Telegram.
    case failed
}

func _internal_resolvePeerByPhoneWithStatus(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvedPeerByPhone, NoError> {
    var normalizedPhone = phone
    if normalizedPhone.hasPrefix("+") {
        normalizedPhone = String(normalizedPhone[normalizedPhone.index(after: normalizedPhone.startIndex)...])
    }
    
    let accountPeerId = account.peerId
    
    return account.postbox.transaction { transaction -> CachedResolvedByPhonePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)))?.get(CachedResolvedByPhonePeer.self)
    } |> mapToSignal { cachedEntry -> Signal<ResolvedPeerByPhone, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(.answered(cachedEntry.peerId))
        } else {
            return account.network.request(Api.functions.contacts.resolvePhone(phone: normalizedPhone))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<ResolvedPeerByPhone, Void> in
                return account.postbox.transaction { transaction -> ResolvedPeerByPhone in
                    var peerId: PeerId? = nil
                    
                    switch result {
                        case let .resolvedPeer(resolvedPeerData):
                            let (apiPeer, chats, users) = (resolvedPeerData.peer, resolvedPeerData.chats, resolvedPeerData.users)
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                            if let peer = parsedPeers.get(apiPeer.peerId) {
                                peerId = peer.id
                                
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByPhonePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)), entry: entry)
                    }
                    return .answered(peerId)
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<ResolvedPeerByPhone, NoError> in
                // Nothing is cached here on purpose: a failed request must not poison the 48h
                // cache with a "not on Telegram" answer the server never actually gave.
                return .single(.failed)
            }
        }
    }
}

func _internal_resolvePeerByPhone(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    return _internal_resolvePeerByPhoneWithStatus(account: account, phone: phone, ageLimit: ageLimit)
    |> map { result -> PeerId? in
        switch result {
        case let .answered(peerId):
            return peerId
        case .failed:
            return nil
        }
    }
}

/// Engine-level outcome of a phone lookup. Kept separate from `ResolvedPeerByPhone` so consumers
/// never see a raw `PeerId` and never have to guess what a `nil` meant.
public enum EngineResolvedPeerByPhone {
    /// The server resolved the number to this user.
    case peer(EnginePeer)
    /// The server answered and reports the number is not a Telegram account.
    case notRegistered
    /// The lookup did not complete. Whether the number is on Telegram is unknown.
    case failed
}
