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
// Pushed from the FenixPro settings screen ("About FenixPro" row). Distinct from the Tips /
// "Imkoniyatlar" modal sheet (a how-to-use guide): this page describes the product itself.
//
// Each feature gets its own section: an icon + title row (no chevron, not tappable) plus a
// section-footer paragraph with a short, honest description. Section footers wrap naturally,
// so the longer descriptions never truncate. Only features that are actually user-visible in
// this fork are listed (Ghost, multi-account, QR login, edited history, STT, chat lock,
// auto-text/translate). Hidden modules (AI chatbot, Tasks tab) are intentionally omitted.

private struct AboutFeature {
    let symbol: String
    let color: FenixuzIconColor
    let title: String
    let body: String
}

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
                     title: l10n.about_messaging_title, body: l10n.about_messaging_body),
    ]
}

private enum FenixAboutSection: Int32 {
    case intro
    // Each feature occupies its own section so the footer paragraph wraps cleanly.
    // Feature sections start at rawValue 1 (intro = 0); the closing footer sits last.
    case featureBase = 1
}

private enum FenixAboutEntry: ItemListNodeEntry {
    case introHeader(String)
    case introBody(String)
    case featureRow(Int, AboutFeature, PresentationTheme)
    case featureBody(Int, String)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .introHeader, .introBody:
            return FenixAboutSection.intro.rawValue
        case let .featureRow(index, _, _):
            return ItemListSectionId(FenixAboutSection.featureBase.rawValue + Int32(index))
        case let .featureBody(index, _):
            return ItemListSectionId(FenixAboutSection.featureBase.rawValue + Int32(index))
        case .footer:
            // A high, stable section id keeps the closing footer below every feature section.
            return 100000
        }
    }

    var stableId: Int32 {
        switch self {
        case .introHeader:
            return 0
        case .introBody:
            return 1
        case let .featureRow(index, _, _):
            // Two entries per feature: row then body. Reserve a 2-wide slot per index.
            return Int32(100 + index * 2)
        case let .featureBody(index, _):
            return Int32(100 + index * 2 + 1)
        case .footer:
            return 1_000_000
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
            if case let .featureBody(rhsIndex, rhsText) = rhs, index == rhsIndex, text == rhsText { return true }
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
            // Icon + title, no chevron and no action — this is a description, not a link.
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
    var entries: [FenixAboutEntry] = []

    entries.append(.introHeader(l10n.about_introHeader))
    entries.append(.introBody(l10n.about_introBody))

    for (index, feature) in aboutFeatures(l10n: l10n).enumerated() {
        entries.append(.featureRow(index, feature, presentationData.theme))
        entries.append(.featureBody(index, feature.body))
    }

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
