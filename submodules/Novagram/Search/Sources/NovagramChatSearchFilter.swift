import Foundation
import SwiftSignalKit
import TelegramCore

/// Exact phrase and regular expression search inside one chat (the Mac's `NovagramChatSearchFilter`).
///
/// - `"two words"` sends the words without the quotes and keeps only messages containing that exact
///   phrase (case- and diacritic-insensitive).
/// - `re:pattern` scans the chat history (empty server query, 100 per page, at most 2000 messages) and
///   keeps the messages a case-insensitive `NSRegularExpression` matches. An invalid pattern is a plain
///   search for the text after `re:`.
/// - Any other query is exactly the same single request as before.
///
/// While a request adds fewer than 10 matches and the server has more, the next page is read (at most
/// 5 extra pages per request). `totalCount` is the number of matches loaded so far. Disposing the
/// signal stops the paging and the filtering.
public enum NovagramChatSearchFilter {
    public typealias Search = (String, SearchMessagesState?, Int32) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError>

    // Matched case-insensitively (unlike the Mac): the iOS search field capitalizes the first letter, so
    // a typed "re:" arrives as "Re:".
    private static let regexPrefix = "re:"
    private static let openingQuotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "\u{201E}"]
    private static let closingQuotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]
    private static let minimumQuotedLength = 3
    private static let regexPageSize: Int32 = 100
    private static let maxExtraPages = 5
    private static let minimumNewMatches = 10
    private static let maxScannedMessages = 2000
    private static let cacheSize = 8
    private static let regexTimeLimit: CFAbsoluteTime = 0.05
    private static let pageTimeLimit: CFAbsoluteTime = 1

    enum Mode {
        case phrase(String)
        case regex(NSRegularExpression)
        case plain(String)
    }

    /// One remembered paging state: the matches so far and whether the search is done.
    private struct Progress {
        let query: String
        let state: SearchMessagesState
        let result: SearchMessagesResult
        let matched: Int
        let finished: Bool
        let checked: [EngineMessage.Id: Bool]
    }

    /// The outcome of filtering one (merged) page.
    private struct FilteredPage {
        let kept: [EngineRawMessage]
        let checked: [EngineMessage.Id: Bool]
        let timedOut: Bool
    }

    private static let recent = Atomic<[Progress]>(value: [])

    /// Drop-in for `engine.messages.searchMessages(location:query:state:limit:)` in a chat's search.
    public static func searchMessages(engine: TelegramEngine, location: SearchMessagesLocation, query: String, state: SearchMessagesState?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
        return wrap(query: query, state: state, limit: limit, search: { query, state, limit in
            return engine.messages.searchMessages(location: location, query: query, state: state, limit: limit)
        })
    }

    public static func wrap(query: String, state: SearchMessagesState?, limit: Int32, search: @escaping Search) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
        // "Search features" off: quotes and re: are plain text again.
        guard NovagramSearchFeatures.isEnabled, let mode = mode(for: query) else {
            return search(query, state, limit)
        }
        let request: Request
        switch mode {
        case let .plain(text):
            return search(text, state, limit)
        case let .phrase(phrase):
            request = Request(query: query, serverQuery: phrase, limit: limit, scanLimit: nil, matches: { message in
                return message.text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }, search: search)
        case let .regex(regex):
            request = Request(query: query, serverQuery: "", limit: regexPageSize, scanLimit: maxScannedMessages, matches: { message in
                return regexMatches(regex, in: message.text)
            }, search: search)
        }
        let previous = state.flatMap { cached(query: query, state: $0) }
        if let previous, previous.finished {
            // "Load more" after the end: the same result, no request.
            return .single((previous.result, previous.state))
        }
        return request.page(state: state, previousMatched: previous?.matched ?? 0, checked: previous?.checked ?? [:], extraPages: 0)
    }

    static func mode(for query: String) -> Mode? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: regexPrefix, options: [.caseInsensitive, .anchored]) != nil {
            let pattern = String(trimmed.dropFirst(regexPrefix.count)).trimmingCharacters(in: .whitespaces)
            guard !pattern.isEmpty else {
                return nil
            }
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                return .regex(regex)
            }
            return .plain(pattern)
        }
        guard trimmed.count >= minimumQuotedLength, let first = trimmed.first, let last = trimmed.last, openingQuotes.contains(first), closingQuotes.contains(last) else {
            return nil
        }
        let phrase = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else {
            return nil
        }
        return .phrase(phrase)
    }

    /// One filtered search: reads pages until enough new matches pass, the server is done, the scan
    /// limit is reached or the extra pages run out.
    private struct Request {
        let query: String
        let serverQuery: String
        let limit: Int32
        let scanLimit: Int?
        let matches: (EngineRawMessage) -> Bool
        let search: Search

        func page(state: SearchMessagesState?, previousMatched: Int, checked: [EngineMessage.Id: Bool], extraPages: Int) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
            return self.search(self.serverQuery, state, self.limit)
            |> mapToSignal { result, updatedState -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
                // The search state is merged: every page comes back with all messages so far.
                return NovagramChatSearchFilter.filtered(result.messages, checked: checked, matches: self.matches)
                |> mapToSignal { filtered -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> in
                    let capped = self.scanLimit.map { result.messages.count >= $0 } ?? false
                    let finished = result.completed || capped || filtered.timedOut || updatedState == state
                    let isShort = filtered.kept.count - previousMatched < NovagramChatSearchFilter.minimumNewMatches
                    if isShort && !finished && extraPages < NovagramChatSearchFilter.maxExtraPages {
                        return self.page(state: updatedState, previousMatched: previousMatched, checked: filtered.checked, extraPages: extraPages + 1)
                    }
                    let kept = SearchMessagesResult(
                        messages: filtered.kept,
                        readStates: result.readStates,
                        threadInfo: result.threadInfo,
                        totalCount: Int32(filtered.kept.count),
                        completed: finished
                    )
                    NovagramChatSearchFilter.remember(Progress(query: self.query, state: updatedState, result: kept, matched: filtered.kept.count, finished: finished, checked: filtered.checked))
                    return .single((kept, updatedState))
                }
            }
        }
    }

    /// Filters off the main thread. Disposing stops the loop before the next message.
    private static func filtered(_ messages: [EngineRawMessage], checked: [EngineMessage.Id: Bool], matches: @escaping (EngineRawMessage) -> Bool) -> Signal<FilteredPage, NoError> {
        return Signal { subscriber in
            let cancelled = Atomic<Bool>(value: false)
            Queue.concurrentDefaultQueue().async {
                let deadline = CFAbsoluteTimeGetCurrent() + pageTimeLimit
                var checked = checked
                var kept: [EngineRawMessage] = []
                var timedOut = false
                for message in messages {
                    if cancelled.with({ $0 }) {
                        return
                    }
                    if let known = checked[message.id] {
                        if known {
                            kept.append(message)
                        }
                        continue
                    }
                    // Past the page's time limit unchecked messages are skipped and the search ends.
                    guard CFAbsoluteTimeGetCurrent() < deadline else {
                        timedOut = true
                        continue
                    }
                    let hit = matches(message)
                    checked[message.id] = hit
                    if hit {
                        kept.append(message)
                    }
                }
                subscriber.putNext(FilteredPage(kept: kept, checked: checked, timedOut: timedOut))
                subscriber.putCompletion()
            }
            return ActionDisposable {
                _ = cancelled.swap(true)
            }
        }
    }

    // Each message gets at most `regexTimeLimit`; `.reportProgress` lets a slow pattern be stopped.
    private static func regexMatches(_ regex: NSRegularExpression, in text: String) -> Bool {
        let deadline = CFAbsoluteTimeGetCurrent() + regexTimeLimit
        var found = false
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { match, _, stop in
            if match != nil {
                found = true
                stop.pointee = true
            } else if CFAbsoluteTimeGetCurrent() > deadline {
                stop.pointee = true
            }
        }
        return found
    }

    private static func cached(query: String, state: SearchMessagesState) -> Progress? {
        return recent.with { $0.last(where: { $0.query == query && $0.state == state }) }
    }

    private static func remember(_ progress: Progress) {
        _ = recent.modify { current in
            var updated = current.filter { !($0.query == progress.query && $0.state == progress.state) }
            updated.append(progress)
            if updated.count > cacheSize {
                updated.removeFirst(updated.count - cacheSize)
            }
            return updated
        }
    }
}
