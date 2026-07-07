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
    let context: AccountContext
    let openBot: (String) -> Void

    init(context: AccountContext, openBot: @escaping (String) -> Void) {
        self.context = context
        self.openBot = openBot
    }
}

// MARK: - List entries

private enum FenixBotsEntry: ItemListNodeEntry {
    // Section header for each bot category
    case categoryHeader(Int, String)
    // Individual bot row: (categoryIndex, botIndex, bot model, theme, resolved Telegram peer for its real avatar)
    case botRow(Int, Int, NovagramBot, PresentationTheme, EnginePeer?)

    var section: ItemListSectionId {
        switch self {
        case let .categoryHeader(catIndex, _): return ItemListSectionId(Int32(catIndex))
        case let .botRow(catIndex, _, _, _, _): return ItemListSectionId(Int32(catIndex))
        }
    }

    var stableId: Int32 {
        // Category headers: catIndex * 1000 (e.g. 0, 1000, 2000, 3000)
        // Bot rows: catIndex * 1000 + 1 + botIndex (always < next header stableId)
        switch self {
        case let .categoryHeader(catIndex, _):         return Int32(catIndex * 1000)
        case let .botRow(catIndex, botIndex, _, _, _): return Int32(catIndex * 1000 + 1 + botIndex)
        }
    }

    static func == (lhs: FenixBotsEntry, rhs: FenixBotsEntry) -> Bool {
        switch lhs {
        case let .categoryHeader(lhsCat, lhsTitle):
            if case let .categoryHeader(rhsCat, rhsTitle) = rhs,
               lhsCat == rhsCat, lhsTitle == rhsTitle { return true }
            return false
        case let .botRow(lhsCat, lhsIdx, lhsBot, lhsTheme, lhsPeer):
            if case let .botRow(rhsCat, rhsIdx, rhsBot, rhsTheme, rhsPeer) = rhs,
               lhsCat == rhsCat,
               lhsIdx == rhsIdx,
               lhsBot.username == rhsBot.username,
               lhsTheme === rhsTheme,
               lhsPeer?.id == rhsPeer?.id { return true }
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
        case let .botRow(_, _, bot, _, peer):
            let langCode = presentationData.strings.primaryComponent.languageCode
            // Real avatar takes over via iconPeer once resolved; until then (or if the
            // bot has no profile photo) the brand-color icon is the visible fallback.
            // Pattern mirrors FenixAccountsController.swift's live/suspended avatar rows.
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: peer == nil ? fenixBotIcon(systemName: bot.icon, hexColor: bot.color) : nil,
                context: args.context,
                iconPeer: peer,
                iconPeerSize: 56.0,
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
    categories: [NovagramBotCategory],
    avatarPeers: [String: EnginePeer]
) -> [FenixBotsEntry] {
    let langCode = presentationData.strings.primaryComponent.languageCode
    var entries: [FenixBotsEntry] = []
    for (catIndex, category) in categories.enumerated() {
        entries.append(.categoryHeader(catIndex, category.title.localized(langCode: langCode)))
        for (botIndex, bot) in category.bots.enumerated() {
            entries.append(.botRow(catIndex, botIndex, bot, presentationData.theme, avatarPeers[bot.username]))
        }
    }
    return entries.sorted()
}

// MARK: - Avatar resolution

/// Resolves every unique bot @username to its EnginePeer once. Any peer that resolves
/// is kept — the row's avatarNode fetches the actual photo from the peer itself, so we
/// must NOT pre-filter on smallProfileImage (a freshly resolved peer has none cached
/// yet, which previously hid every real avatar). Usernames that fail to resolve are
/// simply absent from the map, so their rows keep the brand-icon fallback (fenixBotIcon).
/// Reuses the resolvePeerByName pattern from openBot(_:) below.
private func resolveBotAvatarPeers(
    context: AccountContext,
    categories: [NovagramBotCategory]
) -> Signal<[String: EnginePeer], NoError> {
    var usernames = Set<String>()
    for category in categories {
        for bot in category.bots {
            usernames.insert(bot.username)
        }
    }
    guard !usernames.isEmpty else {
        return .single([:])
    }

    let perBotSignals: [Signal<(String, EnginePeer?), NoError>] = usernames.map { username in
        context.engine.peers.resolvePeerByName(name: username, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            switch result {
            case let .result(peer): return .single(peer)
            case .progress:         return .complete()
            }
        }
        |> map { (username, $0) }
    }

    return combineLatest(perBotSignals)
    |> map { pairs -> [String: EnginePeer] in
        var result: [String: EnginePeer] = [:]
        for (username, peer) in pairs {
            // Keep any resolved peer. A freshly resolved peer often has no cached
            // smallProfileImage yet even when the bot HAS a profile photo, so the old
            // `smallProfileImage != nil` guard hid every real avatar. The row's
            // avatarNode.setPeer(peer:) fetches the photo from the peer itself.
            if let peer {
                result[username] = peer
            }
        }
        return result
    }
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

    let arguments = FenixBotsArguments(context: context, openBot: { username in
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

    // Avatars are resolved once in the background; the list renders immediately with
    // brand-icon fallbacks (empty map) and swaps in real avatars when this resolves.
    let avatarPeersSignal: Signal<[String: EnginePeer], NoError> = .single([:])
    |> then(resolveBotAvatarPeers(context: context, categories: categories))

    let signal = combineLatest(
        context.sharedContext.presentationData,
        avatarPeersSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, avatarPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
                categories: categories,
                avatarPeers: avatarPeers
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
