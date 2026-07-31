import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import ContextUI
import PhoneNumberFormat
import FenixuzLocalization

// Fenixuz "Accounts" screen.
//
// With the user-controlled pinned set (up to 5 simultaneous live accounts), this screen lets the
// user activate / put-to-sleep individual accounts. Every row is a chat-list shaped
// FenixAccountItem: 60pt avatar, bold name, a "@username" line, a phone line and a status pill.
// Pill states:
//   "Joriy"   (Current)  — the primary account, always live, blue pill.
//   "Active"  (Active)   — pinned non-primary account, kept live, green pill.
//   "Uyquda" (Sleeping)  — suspended account, tinted grey pill.
//
// Non-primary rows offer Activate / Put to Sleep three ways: long-press context menu, trailing
// swipe, and a VoiceOver custom action.
// Cap: at most 5 accounts live simultaneously (primary always counts). Attempting to activate
// a 6th shows a localized warning alert and does NOT activate.

private struct AccountRow: Equatable {
    let recordId: AccountRecordId
    let peerId: Int64
    let title: String
    let username: String   // "@handle" or ""
    let phone: String      // display-formatted "+998 90 123 45 67" or ""
    let isPrimary: Bool
    let isLive: Bool
    let isPinned: Bool
    let statusLabel: String
    // Live account's peer (for the real avatar); nil for suspended rows.
    let livePeer: EnginePeer?
}

private enum FenixAccountsSection: Int32 {
    case accounts
}

private enum FenixAccountsEntry: ItemListNodeEntry {
    case header(String)
    case account(Int, AccountRow, PresentationTheme, Bool)
    case footer(String)

    var section: ItemListSectionId {
        return FenixAccountsSection.accounts.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .account(index, _, _, _):
            return Int32(1000 + index)
        case .footer:
            return 1_000_000
        }
    }

    static func == (lhs: FenixAccountsEntry, rhs: FenixAccountsEntry) -> Bool {
        switch lhs {
        case let .header(text):
            if case .header(text) = rhs { return true }
            return false
        case let .account(index, row, lhsTheme, revealed):
            if case let .account(rhsIndex, rhsRow, rhsTheme, rhsRevealed) = rhs,
               index == rhsIndex, row == rhsRow, lhsTheme === rhsTheme, revealed == rhsRevealed { return true }
            return false
        case let .footer(text):
            if case .footer(text) = rhs { return true }
            return false
        }
    }

    static func < (lhs: FenixAccountsEntry, rhs: FenixAccountsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FenixAccountsArguments
        switch self {
        case let .header(text):
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: text,
                sectionId: self.section
            )

        case let .account(_, row, _, revealed):
            let l10n = FenixuzL10n(presentationData.strings)
            let status: FenixAccountStatus
            if row.isPrimary {
                status = .current
            } else if row.isLive && row.isPinned {
                status = .active
            } else {
                status = .sleeping
            }

            // The current account can't be activated or put to sleep, so it gets no toggle.
            var toggle: FenixAccountToggle?
            if !row.isPrimary {
                let kind: FenixAccountToggle.Kind = (row.isLive && row.isPinned) ? .putToSleep : .activate
                toggle = FenixAccountToggle(
                    kind: kind,
                    title: kind == .putToSleep ? l10n.accounts_putToSleep : l10n.accounts_activate,
                    action: { arguments.toggleAccount(row.recordId) }
                )
            }

            return FenixAccountItem(
                presentationData: presentationData,
                context: arguments.context,
                peerId: row.peerId,
                title: row.title,
                username: row.username,
                phone: row.phone,
                secondaryFallback: l10n.accounts_accountFallback,
                status: status,
                statusLabel: row.statusLabel,
                accessibilityHintText: l10n.accounts_a11ySwitchHint,
                livePeer: row.livePeer,
                revealed: revealed,
                sectionId: self.section,
                action: {
                    if !row.isPrimary {
                        arguments.switchAccount(row.recordId)
                    }
                },
                toggle: toggle,
                setRevealed: { revealed in
                    arguments.setRevealedAccount(revealed ? row.recordId : nil, row.recordId)
                }
            )

        case let .footer(text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        }
    }
}

// Formats a raw digit string ("998901234567") the way the rest of the app shows phone numbers.
// Accepts a leading "+" too, because the sleeping-account cache stores it that way.
//
// The context overload is the one the login screen uses: it groups digits by the server-supplied
// country pattern first, so a UZ number reads "+998 33 599 94 79" instead of libphonenumber's
// undifferentiated "+998 335999479".
private func fenixDisplayPhone(context: AccountContext, _ raw: String) -> String {
    let digits = raw.hasPrefix("+") ? String(raw.dropFirst()) : raw
    if digits.isEmpty {
        return ""
    }
    return formatPhoneNumber(context: context, number: digits)
}

private final class FenixAccountsArguments {
    let context: AccountContext
    let switchAccount: (AccountRecordId) -> Void
    let longTapAccount: (AccountRecordId, UIView) -> Void
    // Activate / Put to Sleep — shared by the context menu, the swipe action and VoiceOver.
    let toggleAccount: (AccountRecordId) -> Void
    let setRevealedAccount: (AccountRecordId?, AccountRecordId?) -> Void

    init(
        context: AccountContext,
        switchAccount: @escaping (AccountRecordId) -> Void,
        longTapAccount: @escaping (AccountRecordId, UIView) -> Void,
        toggleAccount: @escaping (AccountRecordId) -> Void,
        setRevealedAccount: @escaping (AccountRecordId?, AccountRecordId?) -> Void
    ) {
        self.context = context
        self.switchAccount = switchAccount
        self.longTapAccount = longTapAccount
        self.toggleAccount = toggleAccount
        self.setRevealedAccount = setRevealedAccount
    }
}

private func cachedAccountNames() -> [String: String] {
    (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_names") as? [String: String]) ?? [:]
}

private func cachedAccountUsernames() -> [String: String] {
    (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_usernames") as? [String: String]) ?? [:]
}

// Written alongside the username cache. The legacy username cache only ever kept one identity
// string per account, so sleeping accounts that have a username had no phone to show at all.
private func cachedAccountPhones() -> [String: String] {
    (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_phones") as? [String: String]) ?? [:]
}

public func fenixAccountsController(context: AccountContext) -> ViewController {
    // Shared mutable state: long-press handler needs a synchronous snapshot of rows.
    var currentRows: [AccountRow] = []
    var currentPrimaryRecordId: AccountRecordId?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?

    // Max live accounts cap (must match SharedAccountContextImpl.fenixuzMaxLiveAccounts).
    let maxLiveAccounts = 5

    // Which row currently shows its swipe actions. Kept out of the model signals so a swipe only
    // re-renders the list, never re-reads the account records.
    let revealedRecordIdPromise = ValuePromise<Int64?>(nil, ignoreRepeated: true)
    var revealedRecordIdValue: Int64?

    // Enforces the live-account cap before activating a sleeping account. Returns false — and shows
    // the warning alert — when activating would exceed it.
    func canActivateAccount(l10n: FenixuzL10n) -> Bool {
        let primaryId64 = currentPrimaryRecordId?.int64
        let liveNonPrimaryCount = currentRows.filter {
            !$0.isPrimary && $0.isLive && $0.isPinned && $0.recordId.int64 != primaryId64
        }.count
        // primary occupies slot 0; each pinned non-primary takes one more slot.
        if liveNonPrimaryCount < maxLiveAccounts - 1 {
            return true
        }
        // Cap reached — this is a genuine warning, so an alert is the right surface.
        let alert = UIAlertController(
            title: l10n.accounts_maxLiveTitle,
            message: l10n.accounts_maxLiveBody,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: l10n.accounts_maxLiveOk, style: .default))
        // Find the active window using the connected scenes API (avoids keyWindow deprecation).
        let rootVC = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
            .flatMap { $0.rootViewController }
        if let topVC = rootVC?.fenixTopmostVC() {
            topVC.present(alert, animated: true)
        }
        return false
    }

    // The single relevant action for a non-primary row: Put to Sleep (active) or Activate (sleeping).
    func toggleAccount(_ recordId: AccountRecordId) {
        guard let row = currentRows.first(where: { $0.recordId == recordId }), !row.isPrimary else {
            return
        }
        if !(row.isLive && row.isPinned) {
            let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
            guard canActivateAccount(l10n: FenixuzL10n(strings)) else {
                return
            }
        }
        context.sharedContext.fenixuzTogglePinnedAccount(
            recordId: recordId,
            primaryRecordId: currentPrimaryRecordId
        )
    }

    let arguments = FenixAccountsArguments(
        context: context,
        switchAccount: { recordId in
            context.sharedContext.switchToAccount(
                id: recordId,
                fromSettingsController: nil,
                withChatListController: nil
            )
        },
        longTapAccount: { recordId, sourceView in
            guard let row = currentRows.first(where: { $0.recordId == recordId }),
                  !row.isPrimary else { return }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let l10n = FenixuzL10n(presentationData.strings)

            let actionTitle: String
            let actionIconName: String
            if row.isLive && row.isPinned {
                actionTitle = l10n.accounts_putToSleep
                actionIconName = "Chat/Context Menu/NightMode"
            } else {
                // Account is sleeping — enforce the live cap before offering Activate.
                guard canActivateAccount(l10n: l10n) else { return }
                actionTitle = l10n.accounts_activate
                actionIconName = "Chat/Context Menu/Check"
            }

            // Native context menu (blurred overlay + actions), anchored to the pressed row —
            // the same surface used by the Settings tab-bar account switcher.
            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: actionTitle,
                    icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: actionIconName), color: theme.contextMenu.primaryColor)
                    },
                    action: { _, f in
                        f(.default)
                        toggleAccount(recordId)
                    }
                ))
            ]

            let contextController = makeContextController(
                presentationData: presentationData,
                source: .reference(FenixAccountContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            presentInGlobalOverlayImpl?(contextController)
        },
        toggleAccount: { recordId in
            toggleAccount(recordId)
        },
        setRevealedAccount: { revealed, previous in
            if let revealed = revealed {
                revealedRecordIdValue = revealed.int64
                revealedRecordIdPromise.set(revealed.int64)
            } else if revealedRecordIdValue == previous?.int64 {
                revealedRecordIdValue = nil
                revealedRecordIdPromise.set(nil)
            }
        }
    )

    // All logged-in records (record id + peerId + sortIndex) from the account manager.
    let allRecords = context.sharedContext.accountManager.accountRecords()
    |> map { view -> (current: AccountRecordId?, accounts: [(AccountRecordId, Int64, Int32)]) in
        var result: [(AccountRecordId, Int64, Int32)] = []
        for record in view.records {
            var isLoggedOut = false
            var peerId: Int64 = 0
            var sortIndex: Int32 = 0
            for attribute in record.attributes {
                if case .loggedOut = attribute {
                    isLoggedOut = true
                } else if case let .sortOrder(sortOrder) = attribute {
                    sortIndex = sortOrder.order
                } else if case let .backupData(backupData) = attribute {
                    peerId = backupData.data?.peerId ?? 0
                }
            }
            if isLoggedOut { continue }
            result.append((record.id, peerId, sortIndex))
        }
        result.sort(by: { $0.2 < $1.2 })
        return (view.currentRecord?.id, result)
    }

    // Combine records + live account info + pinned set — list re-renders on any pin change.
    let signal = combineLatest(
        context.sharedContext.presentationData,
        allRecords,
        context.sharedContext.activeAccountsWithInfo,
        context.sharedContext.fenixuzPinnedAccountsSignal,
        revealedRecordIdPromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, recordsData, activeInfo, pinnedIds, revealedRecordId -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let l10n = FenixuzL10n(presentationData.strings)
        let names = cachedAccountNames()
        let usernames = cachedAccountUsernames()
        let phones = cachedAccountPhones()
        let liveById: [AccountRecordId: AccountWithInfo] = Dictionary(
            activeInfo.accounts.map { ($0.account.id, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        var rows: [AccountRow] = []
        for (recordId, peerId, _) in recordsData.accounts {
            let live = liveById[recordId]
            let peerKey = String(peerId)

            let title: String
            if let live = live {
                title = live.peer.debugDisplayTitle
            } else if let cached = names[peerKey], !cached.isEmpty {
                title = cached
            } else {
                title = "\(l10n.accounts_accountFallback) \(peerId)"
            }

            // Username and phone occupy their own lines, so they are carried separately. A live
            // account exposes both. A sleeping one is served by two parallel caches; the legacy
            // username cache holds a single string that may be either, and the phone cache fills
            // the gap once the account has been live at least once since the cache was added.
            var username = ""
            var phone = ""
            if let live = live {
                if case let .user(user) = live.peer {
                    if let uname = user.usernames.first(where: { $0.isActive })?.username ?? user.username {
                        username = "@\(uname)"
                    }
                    if let userPhone = user.phone, !userPhone.isEmpty {
                        phone = fenixDisplayPhone(context: context, userPhone)
                    }
                }
            } else {
                if let cached = usernames[peerKey], !cached.isEmpty {
                    if cached.hasPrefix("@") {
                        username = cached
                    } else {
                        phone = fenixDisplayPhone(context: context, cached)
                    }
                }
                if phone.isEmpty, let cachedPhone = phones[peerKey], !cachedPhone.isEmpty {
                    phone = fenixDisplayPhone(context: context, cachedPhone)
                }
            }

            let isPrimary = recordId == recordsData.current
            let isPinned = pinnedIds.contains(recordId.int64)
            let isLive = live != nil

            let statusLabel: String
            if isPrimary {
                statusLabel = l10n.accounts_current
            } else if isLive && isPinned {
                statusLabel = l10n.accounts_active
            } else {
                statusLabel = l10n.accounts_sleeping
            }

            rows.append(AccountRow(
                recordId: recordId,
                peerId: peerId,
                title: title,
                username: username,
                phone: phone,
                isPrimary: isPrimary,
                isLive: isLive,
                isPinned: isPinned,
                statusLabel: statusLabel,
                livePeer: live?.peer
            ))
        }

        // Keep mutable snapshot in sync for the long-press handler.
        currentRows = rows
        currentPrimaryRecordId = recordsData.current

        var entries: [FenixAccountsEntry] = []
        let liveCount = rows.filter({ $0.isLive }).count
        entries.append(.header(l10n.accounts_summary(total: rows.count, active: liveCount)))
        for (index, row) in rows.enumerated() {
            entries.append(.account(index, row, presentationData.theme, revealedRecordId == row.recordId.int64))
        }
        entries.append(.footer(l10n.accounts_footer))

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(l10n.accounts_allAccounts),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries.sorted(),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    // Attach a long-press gesture recognizer. On trigger, iterate ItemListController's visible
    // item nodes to find which account row the user pressed, then call longTapAccount.
    controller.didAppear = { [weak controller] _ in
        guard let controller = controller else { return }
        let lpgr = FenixLongPressGestureRecognizer { [weak controller] recognizer in
            guard recognizer.state == .began, let controller = controller else { return }
            let location = recognizer.location(in: controller.view)

            // Walk visible item nodes to find the pressed account row (stableId ≥ 1000).
            var targetRecordId: AccountRecordId?
            var targetView: UIView?
            controller.forEachItemNode { itemNode in
                let nodeFrame = itemNode.view.convert(itemNode.view.bounds, to: controller.view)
                guard nodeFrame.contains(location), let idx = itemNode.index else { return }
                // Items are: [0]=header, [1..N]=accounts, [N+1]=footer.
                let accountListIndex = idx - 1   // 0-based account index
                if accountListIndex >= 0 && accountListIndex < currentRows.count {
                    targetRecordId = currentRows[accountListIndex].recordId
                    targetView = itemNode.view
                }
            }
            // Clear the highlight the list applied during the press so the row doesn't
            // stay stuck looking "selected" once the context menu is up.
            controller.clearItemNodesHighlight(animated: true)
            if let targetRecordId = targetRecordId, let targetView = targetView {
                arguments.longTapAccount(targetRecordId, targetView)
            }
        }
        lpgr.minimumPressDuration = 0.45
        // Cancel the touch in the list once we recognize, so the underlying row never
        // enters / sticks in a highlighted ("selected") state on long-press.
        lpgr.cancelsTouchesInView = true
        controller.view.addGestureRecognizer(lpgr)
    }

    presentInGlobalOverlayImpl = { [weak controller] c in
        controller?.presentInGlobalOverlay(c, with: nil)
    }

    return controller
}

// UILongPressGestureRecognizer with closure callback — avoids Objective-C selector noise.
private final class FenixLongPressGestureRecognizer: UILongPressGestureRecognizer {
    private let handler: (UILongPressGestureRecognizer) -> Void

    init(handler: @escaping (UILongPressGestureRecognizer) -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handleGesture))
    }

    @objc private func handleGesture() {
        handler(self)
    }
}

// Anchors the account context menu to the pressed row's view.
private final class FenixAccountContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

// Finds the topmost presented UIViewController for presenting UIAlertController.
private extension UIViewController {
    func fenixTopmostVC() -> UIViewController {
        if let presented = presentedViewController {
            return presented.fenixTopmostVC()
        }
        return self
    }
}
