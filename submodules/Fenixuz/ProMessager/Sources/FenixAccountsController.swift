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
// With the working-set cap (see SharedAccountContext: at most N accounts are kept LIVE at once), the
// built-in account switchers only show the live accounts. This screen lists EVERY logged-in account —
// live and suspended — so the user can hold and reach 50-100+ accounts. Tapping a suspended account
// switches to it (SharedAccountContext loads it and evicts the least-recently-used one).
//
// Suspended accounts have no live context, so their display name comes from the persisted name cache
// (UserDefaults "pro_messager" / "fenixuz_account_names", written by SharedAccountContext while live).
// Username is cached separately under "fenixuz_account_usernames" (added 2026-06-08).
// Avatar for suspended accounts is a colored initials monogram generated locally.

private struct AccountRow: Equatable {
    let recordId: AccountRecordId
    let peerId: Int64
    let title: String
    let username: String   // "@handle" or "+phone" or ""
    let isPrimary: Bool
    let isLive: Bool
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
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)

        case let .account(_, row, theme):
            let labelStyle: ItemListDisclosureLabelStyle = row.isPrimary ? .badge(theme.list.itemAccentColor) : .text

            // Subtitle: @username or phone, shown under the name in secondary color.
            let subtitle = row.username.isEmpty ? nil : row.username

            // Icon: real peer avatar for live accounts; colored initials monogram for suspended ones.
            // ItemListDisclosureItem renders avatarNode when both context + iconPeer are set.
            // For suspended accounts we fall back to a pre-rendered initials image.
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
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// Generates a round colored initials avatar image for suspended accounts.
// Color is derived from the name so the same account always gets the same color.
private func fenixInitialsAvatar(name: String) -> UIImage? {
    let size = CGSize(width: 40, height: 40)
    let initials = avatarInitials(from: name)
    let color = avatarColor(for: name)

    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        // Circle background
        ctx.cgContext.setFillColor(color.cgColor)
        ctx.cgContext.fillEllipse(in: rect)
        // Initials text
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

// Palette matches Telegram's built-in peer avatar colors (7 hues).
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

    init(context: AccountContext, switchAccount: @escaping (AccountRecordId) -> Void) {
        self.context = context
        self.switchAccount = switchAccount
    }
}

private func cachedAccountNames() -> [String: String] {
    return (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_names") as? [String: String]) ?? [:]
}

private func cachedAccountUsernames() -> [String: String] {
    return (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_usernames") as? [String: String]) ?? [:]
}

public func fenixAccountsController(context: AccountContext) -> ViewController {
    let arguments = FenixAccountsArguments(
        context: context,
        switchAccount: { recordId in
            context.sharedContext.switchToAccount(id: recordId, fromSettingsController: nil, withChatListController: nil)
        }
    )

    // All logged-in records (record id + peerId + sortIndex) plus the current record id.
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
            if isLoggedOut {
                continue
            }
            result.append((record.id, peerId, sortIndex))
        }
        result.sort(by: { $0.2 < $1.2 })
        return (view.currentRecord?.id, result)
    }

    let signal = combineLatest(
        context.sharedContext.presentationData,
        allRecords,
        context.sharedContext.activeAccountsWithInfo
    )
    |> deliverOnMainQueue
    |> map { presentationData, recordsData, activeInfo -> (ItemListControllerState, (ItemListNodeState, Any)) in
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

            // Display name: live peer > name cache > fallback
            let title: String
            if let live = live {
                title = live.peer.debugDisplayTitle
            } else if let cached = names[peerKey], !cached.isEmpty {
                title = cached
            } else {
                title = "\(l10n.accounts_accountFallback) \(peerId)"
            }

            // Username / phone: live peer > username cache > empty
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
            let statusLabel: String
            if isPrimary {
                statusLabel = l10n.accounts_current
            } else if live != nil {
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
                isLive: live != nil,
                statusLabel: statusLabel,
                livePeer: live?.peer
            ))
        }

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
    return controller
}
