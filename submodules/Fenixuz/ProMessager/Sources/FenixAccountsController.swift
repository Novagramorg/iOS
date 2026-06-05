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

// Fenixuz "Accounts" screen.
//
// With the working-set cap (see SharedAccountContext: at most N accounts are kept LIVE at once), the
// built-in account switchers only show the live accounts. This screen lists EVERY logged-in account —
// live and suspended — so the user can hold and reach 50-100+ accounts. Tapping a suspended account
// switches to it (SharedAccountContext loads it and evicts the least-recently-used one).
//
// Suspended accounts have no live context, so their display name comes from the persisted name cache
// (UserDefaults "pro_messager" / "fenixuz_account_names", written by SharedAccountContext while live).

private struct AccountRow: Equatable {
    let recordId: AccountRecordId
    let peerId: Int64
    let title: String
    let isPrimary: Bool
    let isLive: Bool
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
            if case .header(text) = rhs {
                return true
            }
            return false
        case let .account(index, row, lhsTheme):
            if case let .account(rhsIndex, rhsRow, rhsTheme) = rhs, index == rhsIndex, row == rhsRow, lhsTheme === rhsTheme {
                return true
            }
            return false
        case let .footer(text):
            if case .footer(text) = rhs {
                return true
            }
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
            let label: String
            let labelStyle: ItemListDisclosureLabelStyle
            if row.isPrimary {
                label = "Joriy"
                labelStyle = .badge(theme.list.itemAccentColor)
            } else if row.isLive {
                label = "Faol"
                labelStyle = .text
            } else {
                label = "uyquda"
                labelStyle = .text
            }
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "person.crop.circle.fill", color: row.isPrimary ? .green : .blue), title: row.title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                if !row.isPrimary {
                    arguments.switchAccount(row.recordId)
                }
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class FenixAccountsArguments {
    let switchAccount: (AccountRecordId) -> Void

    init(switchAccount: @escaping (AccountRecordId) -> Void) {
        self.switchAccount = switchAccount
    }
}

private func cachedAccountNames() -> [String: String] {
    return (UserDefaults(suiteName: "pro_messager")?.dictionary(forKey: "fenixuz_account_names") as? [String: String]) ?? [:]
}

public func fenixAccountsController(context: AccountContext) -> ViewController {
    let arguments = FenixAccountsArguments(switchAccount: { recordId in
        context.sharedContext.switchToAccount(id: recordId, fromSettingsController: nil, withChatListController: nil)
    })

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
        let names = cachedAccountNames()
        let liveById: [AccountRecordId: AccountWithInfo] = Dictionary(activeInfo.accounts.map { ($0.account.id, $0) }, uniquingKeysWith: { a, _ in a })

        var rows: [AccountRow] = []
        for (recordId, peerId, _) in recordsData.accounts {
            let live = liveById[recordId]
            let title: String
            if let live = live {
                title = live.peer.debugDisplayTitle
            } else if let cached = names[String(peerId)], !cached.isEmpty {
                title = cached
            } else {
                title = "Account \(peerId)"
            }
            rows.append(AccountRow(recordId: recordId, peerId: peerId, title: title, isPrimary: recordId == recordsData.current, isLive: live != nil))
        }

        var entries: [FenixAccountsEntry] = []
        let liveCount = rows.filter({ $0.isLive }).count
        entries.append(.header("JAMI: \(rows.count) ta account · \(liveCount) ta faol"))
        for (index, row) in rows.enumerated() {
            entries.append(.account(index, row, presentationData.theme))
        }
        entries.append(.footer("Tezkor ishlash uchun bir vaqtda eng so'nggi 3 ta account jonli ushlab turiladi. Qolganlari uyquda bo'ladi — ammo ularga ham bildirishnomalar (push) to'xtovsiz kelaveradi. Istalgan accountga bossangiz, bir lahzada jonlanadi. Shu tarzda 100+ account ham telefonni qotirmaydi."))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Accountlar"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries.sorted(), style: .blocks)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
