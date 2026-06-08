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
import FenixuzLocalization

// Fenixuz "Accounts" screen.
//
// With the user-controlled pinned set (up to 5 simultaneous live accounts), this screen lets the
// user activate / put-to-sleep individual accounts. State labels:
//   "Joriy"   (Current)  — the primary account, always live, accent-color badge.
//   "Active"  (Active)   — pinned non-primary account, kept live, green badge.
//   "Uyquda" (Sleeping)  — suspended account, plain grey text label.
//
// Long-press a non-primary row to get the Activate / Put to Sleep context menu.
// Cap: at most 5 accounts live simultaneously (primary always counts). Attempting to activate
// a 6th shows a localized warning alert and does NOT activate.

private struct AccountRow: Equatable {
    let recordId: AccountRecordId
    let peerId: Int64
    let title: String
    let username: String   // "@handle" or "+phone" or ""
    let isPrimary: Bool
    let isLive: Bool
    let isPinned: Bool
    let statusLabel: String
    // Live account's peer (for real avatar via iconPeer); nil for suspended rows.
    let livePeer: EnginePeer?
}

private enum FenixAccountsSection: Int32 {
    case accounts
}

private enum FenixAccountsEntry: ItemListNodeEntry {
    case header(String)
    case account(Int, AccountRow, PresentationTheme)
    case footer(String)

    var section: ItemListSectionId {
        return FenixAccountsSection.accounts.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .account(index, _, _):
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
        case let .account(index, row, lhsTheme):
            if case let .account(rhsIndex, rhsRow, rhsTheme) = rhs,
               index == rhsIndex, row == rhsRow, lhsTheme === rhsTheme { return true }
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

        case let .account(_, row, theme):
            // Label badge colors:
            //   primary  → accent color (system blue / tint)
            //   active   → green (#4DC278)
            //   sleeping → plain text (no badge, secondary color via .text style)
            let labelStyle: ItemListDisclosureLabelStyle
            if row.isPrimary {
                labelStyle = .badge(theme.list.itemAccentColor)
            } else if row.isLive && row.isPinned {
                labelStyle = .badge(UIColor(red: 0.30, green: 0.76, blue: 0.47, alpha: 1.0))
            } else {
                labelStyle = .text
            }

            let subtitle = row.username.isEmpty ? nil : row.username
            let icon: UIImage? = row.livePeer == nil ? fenixInitialsAvatar(name: row.title) : nil

            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: icon,
                context: arguments.context,
                iconPeer: row.livePeer,
                title: row.title,
                label: row.statusLabel,
                labelStyle: labelStyle,
                additionalDetailLabel: subtitle,
                sectionId: self.section,
                style: .blocks,
                action: {
                    if !row.isPrimary {
                        arguments.switchAccount(row.recordId)
                    }
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

// Generates a round colored initials avatar for suspended accounts.
private func fenixInitialsAvatar(name: String) -> UIImage? {
    let size = CGSize(width: 40, height: 40)
    let initials = avatarInitials(from: name)
    let color = avatarColor(for: name)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        ctx.cgContext.setFillColor(color.cgColor)
        ctx.cgContext.fillEllipse(in: rect)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let text = initials as NSString
        let textSize = text.size(withAttributes: attrs)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
    }
}

private func avatarInitials(from name: String) -> String {
    let parts = name.split(separator: " ").prefix(2)
    if parts.isEmpty { return "?" }
    return parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

private let avatarPalette: [UIColor] = [
    UIColor(red: 0.48, green: 0.63, blue: 0.91, alpha: 1),
    UIColor(red: 0.55, green: 0.80, blue: 0.59, alpha: 1),
    UIColor(red: 0.89, green: 0.52, blue: 0.50, alpha: 1),
    UIColor(red: 0.97, green: 0.69, blue: 0.39, alpha: 1),
    UIColor(red: 0.57, green: 0.74, blue: 0.82, alpha: 1),
    UIColor(red: 0.80, green: 0.59, blue: 0.80, alpha: 1),
    UIColor(red: 0.40, green: 0.73, blue: 0.64, alpha: 1)
]

private func avatarColor(for name: String) -> UIColor {
    let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int(bitPattern: UInt(bitPattern: Int($1.value))) })
    return avatarPalette[hash % avatarPalette.count]
}

private final class FenixAccountsArguments {
    let context: AccountContext
    let switchAccount: (AccountRecordId) -> Void
    let longTapAccount: (AccountRecordId) -> Void

    init(
        context: AccountContext,
        switchAccount: @escaping (AccountRecordId) -> Void,
        longTapAccount: @escaping (AccountRecordId) -> Void
    ) {
        self.context = context
        self.switchAccount = switchAccount
        self.longTapAccount = longTapAccount
    }
}

private func cachedAccountNames() -> [String: String] {
    (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_names") as? [String: String]) ?? [:]
}

private func cachedAccountUsernames() -> [String: String] {
    (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_usernames") as? [String: String]) ?? [:]
}

public func fenixAccountsController(context: AccountContext) -> ViewController {
    // Shared mutable state: long-press handler needs a synchronous snapshot of rows.
    var currentRows: [AccountRow] = []
    var currentPrimaryRecordId: AccountRecordId?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?

    // Max live accounts cap (must match SharedAccountContextImpl.fenixuzMaxLiveAccounts).
    let maxLiveAccounts = 5

    let arguments = FenixAccountsArguments(
        context: context,
        switchAccount: { recordId in
            context.sharedContext.switchToAccount(
                id: recordId,
                fromSettingsController: nil,
                withChatListController: nil
            )
        },
        longTapAccount: { recordId in
            guard let row = currentRows.first(where: { $0.recordId == recordId }),
                  !row.isPrimary else { return }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let l10n = FenixuzL10n(presentationData.strings)

            if row.isLive && row.isPinned {
                // Account is active (pinned) — offer Put to Sleep.
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(
                            title: l10n.accounts_putToSleep,
                            color: .accent,
                            action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                context.sharedContext.fenixuzTogglePinnedAccount(
                                    recordId: recordId,
                                    primaryRecordId: currentPrimaryRecordId
                                )
                            }
                        )
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(
                            title: l10n.iap_block_cancel,
                            color: .accent,
                            font: .bold,
                            action: { [weak actionSheet] in actionSheet?.dismissAnimated() }
                        )
                    ])
                ])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                // Account is sleeping — check cap before offering Activate.
                // Count live non-primary pinned slots currently in use.
                let primaryId64 = currentPrimaryRecordId?.int64
                let liveNonPrimaryCount = currentRows.filter {
                    !$0.isPrimary && $0.isLive && $0.isPinned && $0.recordId.int64 != primaryId64
                }.count
                // primary occupies slot 0; each pinned non-primary takes one more slot.
                if liveNonPrimaryCount >= maxLiveAccounts - 1 {
                    // Cap reached — show warning alert. UIAlertController is fine here.
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
                    return
                }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(
                            title: l10n.accounts_activate,
                            color: .accent,
                            action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                context.sharedContext.fenixuzTogglePinnedAccount(
                                    recordId: recordId,
                                    primaryRecordId: currentPrimaryRecordId
                                )
                            }
                        )
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(
                            title: l10n.iap_block_cancel,
                            color: .accent,
                            font: .bold,
                            action: { [weak actionSheet] in actionSheet?.dismissAnimated() }
                        )
                    ])
                ])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
        context.sharedContext.fenixuzPinnedAccountsSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, recordsData, activeInfo, pinnedIds -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let l10n = FenixuzL10n(presentationData.strings)
        let names = cachedAccountNames()
        let usernames = cachedAccountUsernames()
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

            let username: String
            if let live = live {
                switch live.peer {
                case let .user(user):
                    if let uname = user.usernames.first(where: { $0.isActive })?.username ?? user.username {
                        username = "@\(uname)"
                    } else if let phone = user.phone, !phone.isEmpty {
                        username = "+\(phone)"
                    } else {
                        username = ""
                    }
                default:
                    username = ""
                }
            } else {
                username = usernames[peerKey] ?? ""
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
            entries.append(.account(index, row, presentationData.theme))
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

            // Walk visible item nodes. stableId ≥ 1000 means an account row.
            controller.forEachItemNode { itemNode in
                // Convert the tap location to this item node's coordinate system.
                let nodeFrame = itemNode.view.convert(itemNode.view.bounds, to: controller.view)
                guard nodeFrame.contains(location),
                      let idx = itemNode.index else { return }
                // Items are: [0]=header, [1..N]=accounts, [N+1]=footer
                // header stableId=0, accounts start at index 1.
                let accountListIndex = idx - 1   // 0-based account index
                if accountListIndex >= 0 && accountListIndex < currentRows.count {
                    arguments.longTapAccount(currentRows[accountListIndex].recordId)
                }
            }
        }
        lpgr.minimumPressDuration = 0.45
        lpgr.cancelsTouchesInView = false
        controller.view.addGestureRecognizer(lpgr)
    }

    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
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

// Finds the topmost presented UIViewController for presenting UIAlertController.
private extension UIViewController {
    func fenixTopmostVC() -> UIViewController {
        if let presented = presentedViewController {
            return presented.fenixTopmostVC()
        }
        return self
    }
}
