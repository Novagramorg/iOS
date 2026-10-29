import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display
import AppBundle
import ContextUI
import AccountContext
import TelegramPresentationData
import ChatScheduleTimeController
import NovagramLocalization

/// The Messages section filters a user picked in the "From All Chats" menu of global search.
/// Lives only while the search pane does: nothing is persisted.
public struct NovagramSearchFilterState: Equatable {
    /// Start of the first day, local time.
    public var minDate: Int32?
    /// Last second of the last day, local time.
    public var maxDate: Int32?

    public init() {}

    var hasDates: Bool {
        return self.minDate != nil || self.maxDate != nil
    }
}

/// One search pane's filters: the menu items, the header title and the dated search locations.
public final class NovagramSearchFilter {
    private let statePromise = ValuePromise(NovagramSearchFilterState(), ignoreRepeated: true)
    private let lock = NSLock()
    private var stateValue = NovagramSearchFilterState()

    public init() {}

    public var state: NovagramSearchFilterState {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.stateValue
    }

    func update(_ transform: (inout NovagramSearchFilterState) -> Void) {
        self.lock.lock()
        var state = self.stateValue
        transform(&state)
        self.stateValue = state
        self.lock.unlock()
        self.statePromise.set(state)
    }

    /// Emits `signal`'s values again whenever a filter changes, so the search restarts from page one
    /// (new search state, no old pages).
    public func restarting<T>(_ signal: Signal<T, NoError>) -> Signal<T, NoError> {
        return combineLatest(signal, self.statePromise.get())
        |> map { value, _ -> T in
            return value
        }
    }

    // MARK: - Dates

    /// The location with the picked dates. A date typed into the search bar stays: both apply
    /// (the later start, the earlier end). Public posts have no dates.
    public func dated(_ location: SearchMessagesLocation) -> SearchMessagesLocation {
        let state = self.state
        guard state.hasDates else {
            return location
        }
        switch location {
        case let .general(scope, groupId, tags, minDate, maxDate, folderId, communityId):
            if case .globalPosts = scope {
                return location
            }
            return .general(
                scope: scope, groupId: groupId, tags: tags,
                minDate: novagramLater(minDate, state.minDate), maxDate: novagramEarlier(maxDate, state.maxDate),
                folderId: folderId, communityId: communityId
            )
        case let .peer(peerId, fromId, tags, reactions, threadId, minDate, maxDate):
            return .peer(
                peerId: peerId, fromId: fromId, tags: tags, reactions: reactions, threadId: threadId,
                minDate: novagramLater(minDate, state.minDate), maxDate: novagramEarlier(maxDate, state.maxDate)
            )
        case .sentMedia:
            return location
        }
    }

    /// `engine.messages.searchMessages` with the filters applied. Paging passes the same location
    /// again, so it keeps the range.
    public func searchMessages(
        engine: TelegramEngine,
        location: SearchMessagesLocation,
        query: String,
        state: SearchMessagesState?,
        limit: Int32
    ) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
        return engine.messages.searchMessages(location: self.dated(location), query: query, state: state, limit: limit)
    }

    func setDay(_ timestamp: Int32, isEnd: Bool) {
        // The picker's "Remove date" answers with 0.
        guard timestamp > 0 else {
            self.update { state in
                if isEnd {
                    state.maxDate = nil
                } else {
                    state.minDate = nil
                }
            }
            return
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: Double(timestamp)))
        self.update { state in
            if isEnd {
                let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(novagramSecondsPerDay)
                state.maxDate = Int32(nextDayStart.timeIntervalSince1970) - 1
            } else {
                state.minDate = Int32(dayStart.timeIntervalSince1970)
            }
        }
    }

    // MARK: - Menu

    /// Our items for the end of the "From All Chats" menu. `isAvailable` is false where search has no
    /// message dates (Channels and Apps tabs).
    public func menuItems(context: AccountContext, presentationData: PresentationData, isAvailable: Bool, push: @escaping (ViewController) -> Void) -> [ContextMenuItem] {
        guard isAvailable else {
            return []
        }
        let l10n = NovagramL10n(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
        let state = self.state
        var items: [ContextMenuItem] = [.separator]

        let fromText = state.minDate.map { l10n.search_fromDateValue(novagramDayString($0)) } ?? l10n.search_fromDate
        items.append(.action(ContextMenuActionItem(text: fromText, icon: { _ in UIImage() }, action: { [weak self] _, dismiss in
            dismiss(.default)
            self?.pickDay(isEnd: false, context: context, presentationData: presentationData, push: push)
        })))
        let toText = state.maxDate.map { l10n.search_toDateValue(novagramDayString($0)) } ?? l10n.search_toDate
        items.append(.action(ContextMenuActionItem(text: toText, icon: { _ in UIImage() }, action: { [weak self] _, dismiss in
            dismiss(.default)
            self?.pickDay(isEnd: true, context: context, presentationData: presentationData, push: push)
        })))
        if state.hasDates {
            items.append(.action(ContextMenuActionItem(text: l10n.search_clearDates, icon: { _ in UIImage() }, action: { [weak self] _, dismiss in
                dismiss(.default)
                self?.update { state in
                    state.minDate = nil
                    state.maxDate = nil
                }
            })))
        }
        return items
    }

    private func pickDay(isEnd: Bool, context: AccountContext, presentationData: PresentationData, push: (ViewController) -> Void) {
        let state = self.state
        let controller = ChatScheduleTimeScreen(
            context: context,
            mode: .search,
            currentTime: isEnd ? state.maxDate : state.minDate,
            isDark: presentationData.theme.overallDarkAppearance,
            completion: { [weak self] result in
                self?.setDay(result.time, isEnd: isEnd)
            }
        )
        push(controller)
    }

    // MARK: - Header title

    private static let ownersLock = NSLock()
    private static let owners = NSMapTable<AnyObject, NovagramSearchFilter>(keyOptions: .weakMemory, valueOptions: .weakMemory)

    /// Links the filter to an object the list items can see (the pane's `ChatListNodeInteraction`),
    /// so the section header can show it.
    public func attach(to owner: AnyObject) {
        NovagramSearchFilter.ownersLock.lock()
        NovagramSearchFilter.owners.setObject(self, forKey: owner)
        NovagramSearchFilter.ownersLock.unlock()
    }

    /// Telegram's "From All Chats  <" title with the active filters after it, joined by " · ".
    public static func headerTitle(_ title: String?, owner: AnyObject, strings: PresentationStrings) -> String? {
        guard let title else {
            return nil
        }
        NovagramSearchFilter.ownersLock.lock()
        let filter = NovagramSearchFilter.owners.object(forKey: owner)
        NovagramSearchFilter.ownersLock.unlock()
        guard let filter else {
            return title
        }
        let parts = filter.titleParts(strings: strings)
        guard !parts.isEmpty else {
            return title
        }
        let chevron = "  <"
        let hasChevron = title.hasSuffix(chevron)
        let base = hasChevron ? String(title.dropLast(chevron.count)) : title
        return ([base] + parts).joined(separator: " · ") + (hasChevron ? chevron : "")
    }

    func titleParts(strings: PresentationStrings) -> [String] {
        let l10n = NovagramL10n(languageCode: NovagramL10n.languageKey(for: strings))
        let state = self.state
        var parts: [String] = []
        switch (state.minDate, state.maxDate) {
        case let (minDate?, maxDate?):
            parts.append("\(novagramDayString(minDate))–\(novagramDayString(maxDate))")
        case let (minDate?, nil):
            parts.append(l10n.search_fromDateValue(novagramDayString(minDate)))
        case let (nil, maxDate?):
            parts.append(l10n.search_toDateValue(novagramDayString(maxDate)))
        case (nil, nil):
            break
        }
        return parts
    }
}

private let novagramSecondsPerDay: TimeInterval = 24 * 60 * 60

private func novagramLater(_ lhs: Int32?, _ rhs: Int32?) -> Int32? {
    guard let lhs else {
        return rhs
    }
    guard let rhs else {
        return lhs
    }
    return max(lhs, rhs)
}

private func novagramEarlier(_ lhs: Int32?, _ rhs: Int32?) -> Int32? {
    guard let lhs else {
        return rhs
    }
    guard let rhs else {
        return lhs
    }
    return min(lhs, rhs)
}

/// "01.10.26" in the local time zone.
func novagramDayString(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
}
