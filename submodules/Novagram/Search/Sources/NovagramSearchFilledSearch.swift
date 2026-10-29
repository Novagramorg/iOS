import Foundation
import SwiftSignalKit
import TelegramCore

// "Unread only" and "Mentions only" drop most of a page. Keep reading the next pages until enough
// messages pass, so the list does not stop short (a short list cannot scroll to load more).
let novagramFilledResultCount = 20
let novagramExtraPagesPerLoad = 5
let novagramAutoLoads = 3

/// Decides one message for "Unread only" / "Mentions only". Built per filtered page with the read
/// counters of every peer on it.
struct NovagramSearchMessageFilterPass {
    let filter: NovagramSearchFilterState
    let readCounters: [EnginePeer.Id: EnginePeerReadCounters]

    func keeps(_ message: EngineRawMessage) -> Bool {
        if self.filter.unreadOnly && !self.isUnread(message) {
            return false
        }
        if self.filter.mentionsOnly && !novagramMentionsAccount(message) {
            return false
        }
        return true
    }

    // Unread: an incoming message after the chat's max incoming read id.
    private func isUnread(_ message: EngineRawMessage) -> Bool {
        guard message.flags.contains(.Incoming), let counters = self.readCounters[message.id.peerId] else {
            return false
        }
        return !counters.isIncomingMessageRead(message.index)
    }
}

// The server marks a message that mentions the account with ConsumablePersonalMentionMessageAttribute;
// an unseen one also carries the unseenPersonalMessage tag.
private func novagramMentionsAccount(_ message: EngineRawMessage) -> Bool {
    if message.tags.contains(.unseenPersonalMessage) {
        return true
    }
    return message.attributes.contains(where: { $0 is ConsumablePersonalMentionMessageAttribute })
}

/// One search request with the client filters: filters each page and reads further pages while
/// fewer than `novagramFilledResultCount` messages pass and the server has more.
struct NovagramFilledSearch {
    let engine: TelegramEngine
    let location: SearchMessagesLocation
    let query: String
    let limit: Int32
    let filter: NovagramSearchFilterState

    /// `extraPagesLeft` pages may follow in this load; after that, `autoLoadsLeft` more loads may
    /// follow, each shown first (the pane shows every value) and then filled the same way.
    func load(page: Signal<(SearchMessagesResult, SearchMessagesState), NoError>, extraPagesLeft: Int, autoLoadsLeft: Int) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
        return page
        |> mapToSignal { result, searchState -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
            return self.kept(result)
            |> mapToSignal { kept -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
                let isShort = kept.messages.count < novagramFilledResultCount && !result.completed
                guard isShort else {
                    return .single((kept, searchState))
                }
                // The search state is merged: the next page comes back with every message so far.
                let next = self.engine.messages.searchMessages(location: self.location, query: self.query, state: searchState, limit: self.limit)
                if extraPagesLeft > 0 {
                    return self.load(page: next, extraPagesLeft: extraPagesLeft - 1, autoLoadsLeft: autoLoadsLeft)
                }
                if autoLoadsLeft > 0 {
                    return .single((kept, searchState))
                    |> then(self.load(page: next, extraPagesLeft: novagramExtraPagesPerLoad, autoLoadsLeft: autoLoadsLeft - 1))
                }
                return .single((kept, searchState))
            }
        }
    }

    /// The page without the messages the filters drop. The read counters come from the engine for
    /// every peer on the page: the merged search state keeps read states only for the last page's peers.
    private func kept(_ result: SearchMessagesResult) -> Signal<SearchMessagesResult, NoError> {
        let readCounters: Signal<[EnginePeer.Id: EnginePeerReadCounters], NoError>
        if self.filter.unreadOnly {
            let peerIds = Set(result.messages.filter { $0.flags.contains(.Incoming) }.map { $0.id.peerId })
            readCounters = self.engine.data.get(EngineDataMap(peerIds.map { peerId -> TelegramEngine.EngineData.Item.Messages.PeerReadCounters in
                return TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId)
            }))
        } else {
            readCounters = .single([:])
        }
        let filter = self.filter
        return readCounters
        |> map { readCounters -> SearchMessagesResult in
            let pass = NovagramSearchMessageFilterPass(filter: filter, readCounters: readCounters)
            let messages = result.messages.filter { pass.keeps($0) }
            let removed = Int32(result.messages.count - messages.count)
            return SearchMessagesResult(messages: messages, readStates: result.readStates, threadInfo: result.threadInfo, totalCount: max(0, result.totalCount - removed), completed: result.completed)
        }
    }
}
