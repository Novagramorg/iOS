import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI

// MARK: - Hex-color icon helper
//
// Draws a 30x30 rounded-square icon (corner 7pt) filled with the bot's brand color,
// with the SF Symbol centred in white. Mirrors fenixuzSettingsIcon() but accepts a
// hex color string directly from the JSON rather than a FenixuzIconColor enum value.

private extension UIColor {
    // Parses #RRGGBB or RRGGBB hex strings into a UIColor.
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(value & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

private func fenixBotIcon(systemName: String, hexColor: String) -> UIImage? {
    let color = UIColor(hex: hexColor) ?? .systemBlue
    let size = CGSize(width: 30, height: 30)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7)
        color.setFill()
        path.fill()
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            if let sym = UIImage(systemName: systemName, withConfiguration: cfg) {
                let symSize = sym.size
                let drawSize = CGSize(
                    width: min(symSize.width, 20),
                    height: min(symSize.height, 20)
                )
                let drawRect = CGRect(
                    x: (size.width - drawSize.width) / 2,
                    y: (size.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                sym.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: drawRect)
            }
        }
    }
}

// MARK: - Arguments

private final class FenixBotsArguments {
    let openBot: (String) -> Void

    init(openBot: @escaping (String) -> Void) {
        self.openBot = openBot
    }
}

// MARK: - List entries

private enum FenixBotsEntry: ItemListNodeEntry {
    // Section header for each bot category
    case categoryHeader(Int, String)
    // Individual bot row: (categoryIndex, botIndex, bot model, theme)
    case botRow(Int, Int, NovagramBot, PresentationTheme)

    var section: ItemListSectionId {
        switch self {
        case let .categoryHeader(catIndex, _): return ItemListSectionId(Int32(catIndex))
        case let .botRow(catIndex, _, _, _):   return ItemListSectionId(Int32(catIndex))
        }
    }

    var stableId: Int32 {
        // Category headers: catIndex * 1000 (e.g. 0, 1000, 2000, 3000)
        // Bot rows: catIndex * 1000 + 1 + botIndex (always < next header stableId)
        switch self {
        case let .categoryHeader(catIndex, _):      return Int32(catIndex * 1000)
        case let .botRow(catIndex, botIndex, _, _): return Int32(catIndex * 1000 + 1 + botIndex)
        }
    }

    static func == (lhs: FenixBotsEntry, rhs: FenixBotsEntry) -> Bool {
        switch lhs {
        case let .categoryHeader(lhsCat, lhsTitle):
            if case let .categoryHeader(rhsCat, rhsTitle) = rhs,
               lhsCat == rhsCat, lhsTitle == rhsTitle { return true }
            return false
        case let .botRow(lhsCat, lhsIdx, lhsBot, lhsTheme):
            if case let .botRow(rhsCat, rhsIdx, rhsBot, rhsTheme) = rhs,
               lhsCat == rhsCat,
               lhsIdx == rhsIdx,
               lhsBot.username == rhsBot.username,
               lhsTheme === rhsTheme { return true }
            return false
        }
    }

    static func < (lhs: FenixBotsEntry, rhs: FenixBotsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! FenixBotsArguments
        switch self {
        case let .categoryHeader(_, title):
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: title,
                sectionId: self.section
            )
        case let .botRow(_, _, bot, _):
            let langCode = presentationData.strings.primaryComponent.languageCode
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: fenixBotIcon(systemName: bot.icon, hexColor: bot.color),
                title: bot.name,
                label: bot.help.localized(langCode: langCode),
                labelStyle: .multilineDetailText,
                sectionId: self.section,
                style: .blocks,
                action: {
                    args.openBot(bot.username)
                }
            )
        }
    }
}

// MARK: - Entry builder

private func fenixBotsEntries(
    presentationData: PresentationData,
    categories: [NovagramBotCategory]
) -> [FenixBotsEntry] {
    let langCode = presentationData.strings.primaryComponent.languageCode
    var entries: [FenixBotsEntry] = []
    for (catIndex, category) in categories.enumerated() {
        entries.append(.categoryHeader(catIndex, category.title.localized(langCode: langCode)))
        for (botIndex, bot) in category.bots.enumerated() {
            entries.append(.botRow(catIndex, botIndex, bot, presentationData.theme))
        }
    }
    return entries.sorted()
}

// MARK: - Public factory

/// Pushes a categorised list of Novagram official bots.
/// Reachable from FenixSettingsController via the "Novagram Bots" disclosure row.
/// Tapping any bot row resolves its @username and opens the chat — reusing the same
/// resolvePeerByName + makeChatController pattern as AIChatbotTabController.swift:190.
public func fenixBotsController(context: AccountContext) -> ViewController {
    let categories = loadNovagramBots()?.categories ?? []

    var pushControllerImpl: ((ViewController) -> Void)?

    let openBotDisposable = MetaDisposable()

    let arguments = FenixBotsArguments(openBot: { username in
        // Resolve the bot peer by @username, then push its chat controller.
        // Pattern: context.engine.peers.resolvePeerByName — reused from
        // submodules/Fenixuz/AIChatbot/Sources/AIChatbotTabController.swift:190
        openBotDisposable.set((context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            switch result {
            case let .result(peer): return .single(peer)
            case .progress:         return .complete()
            }
        }
        |> deliverOnMainQueue).startStrict(next: { peer in
            guard let peer else { return }
            let chatController = context.sharedContext.makeChatController(
                context: context,
                chatLocation: .peer(id: peer.id),
                subject: nil,
                botStart: nil,
                mode: .standard(.default),
                params: nil
            )
            pushControllerImpl?(chatController)
        }))
    })

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let langCode = presentationData.strings.primaryComponent.languageCode
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(FenixBotsStrings.screenTitle(langCode: langCode)),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: fenixBotsEntries(
                presentationData: presentationData,
                categories: categories
            ),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
