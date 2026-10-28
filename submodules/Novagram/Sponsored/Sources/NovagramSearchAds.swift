import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import NovagramAds

/// A promoted channel or bot resolved for the current search query.
public struct NovagramPromotedPeer: Equatable {
    public let peer: EnginePeer
    /// The ad's `random_id`, used for the view / click events and the report sheet.
    public let token: String
}

/// SEARCH slot: one sponsored row in global search, after "my results" and before the global
/// results (contract §3.1). `view` when the row becomes visible, `click` when it is opened.
public enum NovagramSearchAds {
    /// The sponsored part of global search by the product rule: OUR promoted peer when the backend has
    /// an ad for this exact query; Telegram's `telegramAdPeers` only when ours has none, never for Premium
    /// users; nothing while "Remove all ads" is on. Emits ([], nil) at once, so the search results
    /// never wait for us, and Telegram's row never flashes before ours resolves.
    public static func adPeers(context: AccountContext, query: String, telegramAdPeers: Signal<[AdPeer], NoError>) -> Signal<([AdPeer], NovagramPromotedPeer?), NoError> {
        let empty: ([AdPeer], NovagramPromotedPeer?) = ([], nil)
        return NovagramSponsored.oursFirst(context: context, surface: "SEARCH", ours: self.promotedPeer(context: context, query: query), fallback: telegramAdPeers |> map { adPeers -> ([AdPeer], NovagramPromotedPeer?) in
            return (adPeers, nil)
        }, empty: empty, isEmpty: { $0.0.isEmpty }, map: { promoted -> ([AdPeer], NovagramPromotedPeer?) in
            return ([], promoted)
        })
    }

    /// After the user stops typing for ~0.5 s, the promoted peer when the backend has an ad for this exact
    /// query (normalized 3–32 characters), else nil.
    static func promotedPeer(context: AccountContext, query: String) -> Signal<NovagramPromotedPeer?, NoError> {
        let normalizedLength = SDKAdSlot.normalizedSearchQuery(query).count
        guard NovagramSponsored.isConfigured, (3 ... 32).contains(normalizedLength) else {
            return .single(nil)
        }

        let request = NovagramSponsored.visibleAd(context: context, slot: .search(query: query))
        |> mapToSignal { served -> Signal<NovagramPromotedPeer?, NoError> in
            guard let served else {
                return .single(nil)
            }
            let username = SDKAdSlot.bareBotUsername(served.ad.promoted.username) ?? SDKAdSlot.bareBotUsername(served.ad.url)
            guard let username else {
                return .single(nil)
            }
            return context.engine.peers.resolvePeerByName(name: username, referrer: nil)
            |> mapToSignal { result -> Signal<NovagramPromotedPeer?, NoError> in
                guard case let .result(peer) = result else {
                    return .complete()
                }
                return .single(peer.map { NovagramPromotedPeer(peer: $0, token: served.ad.randomId) })
            }
        }
        return Signal<Void, NoError>.single(Void())
        |> delay(SDKAdsLimits.searchDebounce, queue: .mainQueue())
        |> mapToSignal { _ -> Signal<NovagramPromotedPeer?, NoError> in
            return request
        }
    }

    /// The row entered the visible zone.
    public static func recordView(token: String) {
        NovagramSponsored.recordView(token: token)
    }

    /// The row was tapped: queues the click, then calls `open` (which opens the peer) on the main queue.
    public static func recordClick(token: String, thenOpen open: @escaping () -> Void) {
        NovagramSponsored.recordClick(token: token, thenOpen: open)
    }

    /// The row's "Ad" button: About / Report.
    public static func presentMenu(token: String, context: AccountContext, present: @escaping (ViewController) -> Void) {
        NovagramAdMenu.presentSheet(token: token, context: context, present: present)
    }
}
