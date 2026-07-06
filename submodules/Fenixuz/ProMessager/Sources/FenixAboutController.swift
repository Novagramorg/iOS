import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import FenixuzLocalization

// Fenixuz "About FenixPro" screen.
//
// A read-only overview of what FenixPro is and which extra tools it adds on top of Telegram.
// Pushed from the FenixPro settings screen ("About FenixPro" row).
//
// Layout:
//   • Intro section  — header + one-paragraph product description
//   • Feature rows   — icon + title (no chevron) + footer body paragraph, one section each
//   • How-to section — the feature tips list (was separate "Features" screen before merge),
//                      icon + title (no chevron) + footer how-to paragraph, one section each
//   • Closing footer — attribution paragraph
//
// Each feature/tip occupies its own section so the footer paragraph wraps cleanly.

// MARK: - Shared row model

private struct AboutFeature {
    let symbol: String
    let color: FenixuzIconColor
    let title: String
    let body: String
}

// MARK: - Feature rows (what FenixPro is)

private func aboutFeatures(l10n: FenixuzL10n) -> [AboutFeature] {
    return [
        AboutFeature(symbol: "eye.slash.fill", color: .gray,
                     title: l10n.about_ghost_title, body: l10n.about_ghost_body),
        AboutFeature(symbol: "person.2.fill", color: .blue,
                     title: l10n.about_multiAccount_title, body: l10n.about_multiAccount_body),
        AboutFeature(symbol: "qrcode", color: .violet,
                     title: l10n.about_qrLogin_title, body: l10n.about_qrLogin_body),
        AboutFeature(symbol: "clock.arrow.circlepath", color: .teal,
                     title: l10n.about_editedHistory_title, body: l10n.about_editedHistory_body),
        AboutFeature(symbol: "mic.fill", color: .red,
                     title: l10n.about_stt_title, body: l10n.about_stt_body),
        AboutFeature(symbol: "lock.fill", color: .green,
                     title: l10n.about_chatLock_title, body: l10n.about_chatLock_body),
        AboutFeature(symbol: "text.append", color: .orange,
                     title: l10n.about_messaging_title, body: l10n.about_messaging_body)
    ]
}

// MARK: - Tips rows (how to use each feature — was the separate "Features" screen)

private func aboutTips(l10n: FenixuzL10n, langCode: String) -> [AboutFeature] {
    // Reuse AboutFeature as the row model — same icon/title/body shape.
    // "character.bubble.fill" is iOS 13+ safe; "translate" symbol is iOS 14+ only.
    //
    // Folder-unlock entries use inline strings (no FenixuzL10n key needed — these
    // describe just-shipped behavior and are self-contained).
    // "folder.fill" and "tag.fill" are both iOS 13+ available.
    let unlimitedFoldersTitle: String
    let unlimitedFoldersBody: String
    let folderTagsTitle: String
    let folderTagsBody: String
    switch langCode {
    case "uz":
        unlimitedFoldersTitle = "Cheksiz jildlar"
        unlimitedFoldersBody  = "Premium cheklovisiz jild yarating."
        folderTagsTitle       = "Jild teglari"
        folderTagsBody        = "Har bir chatda jild teg nomini ko'rsatish — Premium shart emas."
    case "ru":
        unlimitedFoldersTitle = "Безлимитные папки"
        unlimitedFoldersBody  = "Создавайте папки без ограничения Premium."
        folderTagsTitle       = "Теги папок"
        folderTagsBody        = "Показывать теги папок на чатах — без Premium."
    default:
        unlimitedFoldersTitle = "Unlimited Folders"
        unlimitedFoldersBody  = "Create folders without the Premium limit."
        folderTagsTitle       = "Folder Tags"
        folderTagsBody        = "Show folder name tags on each chat — no Premium needed."
    }

    return [
        AboutFeature(symbol: "eye.slash.fill", color: .gray,
                     title: l10n.tips_ghost_title, body: l10n.tips_ghost_body),
        AboutFeature(symbol: "mic.fill", color: .red,
                     title: l10n.tips_stt_title, body: l10n.tips_stt_body),
        AboutFeature(symbol: "person.2.fill", color: .blue,
                     title: l10n.tips_multiAccount_title, body: l10n.tips_multiAccount_body),
        AboutFeature(symbol: "clock.arrow.circlepath", color: .teal,
                     title: l10n.tips_editedHistory_title, body: l10n.tips_editedHistory_body),
        AboutFeature(symbol: "lock.fill", color: .green,
                     title: l10n.tips_chatLock_title, body: l10n.tips_chatLock_body),
        AboutFeature(symbol: "text.append", color: .orange,
                     title: l10n.tips_autoText_title, body: l10n.tips_autoText_body),
        AboutFeature(symbol: "character.bubble.fill", color: .pink,
                     title: l10n.tips_translate_title, body: l10n.tips_translate_body),
        AboutFeature(symbol: "flame.fill", color: .gold,
                     title: l10n.tips_fenixHub_title, body: l10n.tips_fenixHub_body),
        // Folder unlock features — shipped with the Premium folder-limit bypass.
        AboutFeature(symbol: "folder.fill", color: .blue,
                     title: unlimitedFoldersTitle, body: unlimitedFoldersBody),
        AboutFeature(symbol: "tag.fill", color: .teal,
                     title: folderTagsTitle, body: folderTagsBody)
    ]
}

// MARK: - Section ID layout
//
// Stable section IDs ensure the list renders in the correct visual order.
// Ranges are non-overlapping; each feature/tip occupies its own section so
// the footer paragraph wraps cleanly under its row.
//
//   0          → intro
//   1 …  99    → feature sections (max 99 features)
//   500        → tips header (its own section, distinct from feature sections)
//   501 … 599  → tip sections  (max 99 tips)
//   100000     → closing footer

private enum FenixAboutEntry: ItemListNodeEntry {
    case introHeader(String)
    case introBody(String)
    // "what FenixPro is" rows — index 0…N
    case featureRow(Int, AboutFeature, PresentationTheme)
    case featureBody(Int, String)
    // "how to use" section (merged from the old Features/Tips screen)
    case tipsHeader(String)
    case tipRow(Int, AboutFeature, PresentationTheme)
    case tipBody(Int, String)
    // Closing attribution
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .introHeader, .introBody:
            return 0
        case let .featureRow(index, _, _), let .featureBody(index, _):
            // Feature sections: 1 … 99
            return ItemListSectionId(1 + Int32(index))
        case .tipsHeader:
            return 500
        case let .tipRow(index, _, _), let .tipBody(index, _):
            // Tip sections: 501 … 599
            return ItemListSectionId(501 + Int32(index))
        case .footer:
            return 100000
        }
    }

    var stableId: Int32 {
        switch self {
        case .introHeader:    return 0
        case .introBody:      return 1
        case let .featureRow(index, _, _):
            // 2 entries per feature: row then body. Slots 100, 102, 104 …
            return Int32(100 + index * 2)
        case let .featureBody(index, _):
            return Int32(100 + index * 2 + 1)
        case .tipsHeader:     return 500
        case let .tipRow(index, _, _):
            // 2 entries per tip. Slots 600, 602, 604 …
            return Int32(600 + index * 2)
        case let .tipBody(index, _):
            return Int32(600 + index * 2 + 1)
        case .footer:         return 1_000_000
        }
    }

    static func == (lhs: FenixAboutEntry, rhs: FenixAboutEntry) -> Bool {
        switch lhs {
        case let .introHeader(text):
            if case .introHeader(text) = rhs { return true }
            return false
        case let .introBody(text):
            if case .introBody(text) = rhs { return true }
            return false
        case let .featureRow(index, feature, lhsTheme):
            if case let .featureRow(rhsIndex, rhsFeature, rhsTheme) = rhs,
               index == rhsIndex,
               feature.title == rhsFeature.title,
               feature.body == rhsFeature.body,
               feature.symbol == rhsFeature.symbol,
               lhsTheme === rhsTheme { return true }
            return false
        case let .featureBody(index, text):
            if case let .featureBody(rhsIndex, rhsText) = rhs,
               index == rhsIndex, text == rhsText { return true }
            return false
        case let .tipsHeader(text):
            if case .tipsHeader(text) = rhs { return true }
            return false
        case let .tipRow(index, tip, lhsTheme):
            if case let .tipRow(rhsIndex, rhsTip, rhsTheme) = rhs,
               index == rhsIndex,
               tip.title == rhsTip.title,
               tip.body == rhsTip.body,
               tip.symbol == rhsTip.symbol,
               lhsTheme === rhsTheme { return true }
            return false
        case let .tipBody(index, text):
            if case let .tipBody(rhsIndex, rhsText) = rhs,
               index == rhsIndex, text == rhsText { return true }
            return false
        case let .footer(text):
            if case .footer(text) = rhs { return true }
            return false
        }
    }

    static func < (lhs: FenixAboutEntry, rhs: FenixAboutEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .introHeader(text):
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: text,
                sectionId: self.section
            )
        case let .introBody(text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        case let .featureRow(_, feature, _):
            // Icon + title, no chevron and no action — this is a description row.
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: fenixuzSettingsIcon(systemName: feature.symbol, color: feature.color),
                title: feature.title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case let .featureBody(_, text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        case let .tipsHeader(text):
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: text,
                sectionId: self.section
            )
        case let .tipRow(_, tip, _):
            // Same presentation as featureRow — icon + title, no action.
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: fenixuzSettingsIcon(systemName: tip.symbol, color: tip.color),
                title: tip.title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case let .tipBody(_, text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
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

private func fenixAboutEntries(presentationData: PresentationData) -> [FenixAboutEntry] {
    let l10n = FenixuzL10n(presentationData.strings)
    let langCode = presentationData.strings.primaryComponent.languageCode
    var entries: [FenixAboutEntry] = []

    // Intro
    entries.append(.introHeader(l10n.about_introHeader))
    entries.append(.introBody(l10n.about_introBody))

    // "What FenixPro is" feature rows
    for (index, feature) in aboutFeatures(l10n: l10n).enumerated() {
        entries.append(.featureRow(index, feature, presentationData.theme))
        entries.append(.featureBody(index, feature.body))
    }

    // "How to use" tips section — content from the old Features/Tips screen
    entries.append(.tipsHeader(l10n.about_featuresHeader))
    for (index, tip) in aboutTips(l10n: l10n, langCode: langCode).enumerated() {
        entries.append(.tipRow(index, tip, presentationData.theme))
        entries.append(.tipBody(index, tip.body))
    }

    // Closing attribution
    entries.append(.footer(l10n.about_footer))

    return entries.sorted()
}

public func fenixAboutController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let l10n = FenixuzL10n(presentationData.strings)
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(l10n.about_screenTitle),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: fenixAboutEntries(presentationData: presentationData),
            style: .blocks
        )
        return (controllerState, (listState, ()))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
