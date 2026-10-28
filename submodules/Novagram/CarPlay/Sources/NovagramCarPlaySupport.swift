import Foundation
import UIKit
import CarPlay
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import LocalizedPeerData
import NovagramLocalization
import NovagramSecretVault
import NovagramChatLock

// Novagram holds the CarPlay Communication entitlement, so CarPlay opens it as a template app:
// tapping the icon creates a CarPlay scene and the app has to fill it. This module provides that
// scene, a list of recent chats. A chat row has no tap handler of its own: CarPlay hands the
// chat to Siri, which reads its unread messages or takes a reply through the Intents extension.
public enum NovagramCarPlaySupport {
    private static let sharedContextPromise = Promise<SharedAccountContext>()

    // Called from AppDelegate once the shared context exists.
    public static func start(sharedContext: SharedAccountContext) {
        self.sharedContextPromise.set(.single(sharedContext))
    }

    // Without a delegate for this role UIKit throws "Application does not implement CarPlay
    // template application lifecycle methods" and the app dies on every tap in CarPlay.
    public static func configure(_ configuration: UISceneConfiguration, for session: UISceneSession) {
        guard session.role == .carTemplateApplication else {
            return
        }
        configuration.sceneClass = CPTemplateApplicationScene.self
        configuration.delegateClass = NovagramCarPlaySceneDelegate.self
    }

    static var sharedContext: Signal<SharedAccountContext, NoError> {
        return self.sharedContextPromise.get()
    }
}

struct NovagramCarPlayChat: Equatable {
    let peerId: EnginePeer.Id
    let title: String
    let isUnread: Bool
    let isMuted: Bool
    let timestamp: Int32
}

enum NovagramCarPlayContent: Equatable {
    case loggedOut
    case locked
    case chats([NovagramCarPlayChat])
}

// The Siri extension reads a picked chat directly (unreadMessages(account:peerIds:)), so the list
// can look further than its 20-chat "read my messages" scan once channels are left out.
private let novagramCarPlayChatListCount = 50

// Only conversations Siri can read and answer: private chats and groups. Broadcast channels
// cannot be replied to and would crowd personal chats out of the car's short list; secret
// chats are out of Siri's reach. Saved Messages, hidden (vault) and locked chats never show.
private func novagramCarPlayIncludes(peer: EnginePeer, accountPeerId: EnginePeer.Id) -> Bool {
    switch peer {
    case .user, .legacyGroup:
        break
    case let .channel(channel):
        if case .broadcast = channel.info {
            return false
        }
    default:
        return false
    }
    if peer.id == accountPeerId {
        return false
    }
    if SecretVaultManager.shared.isVaulted(peer.id) || ChatPincodeManager.shared.isLocked(peer.id) {
        return false
    }
    return true
}

func novagramCarPlayContent(sharedContext: SharedAccountContext, maximumItemCount: Int) -> Signal<NovagramCarPlayContent, NoError> {
    let primaryContext = sharedContext.activeAccountContexts
    |> map { primary, _, _ -> AccountContext? in
        return primary
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs?.account.id == rhs?.account.id
    })

    return combineLatest(primaryContext, sharedContext.appLockContext.isPasscodeLocked)
    |> mapToSignal { context, isLocked -> Signal<NovagramCarPlayContent, NoError> in
        guard let context else {
            return .single(.loggedOut)
        }
        // A locked app shows no chat names in the car either.
        if isLocked {
            return .single(.locked)
        }
        let accountPeerId = context.account.peerId
        return context.engine.messages.chatList(group: .root, count: novagramCarPlayChatListCount)
        |> map { chatList -> NovagramCarPlayContent in
            let presentationData = sharedContext.currentPresentationData.with { $0 }
            var chats: [NovagramCarPlayChat] = []
            // The view lists the oldest chat first; the phone shows pinned and newest chats first.
            for item in chatList.items.reversed() {
                guard case .chatList = item.id, let peer = item.renderedPeer.peer, let mainPeer = item.renderedPeer.chatMainPeer else {
                    continue
                }
                guard novagramCarPlayIncludes(peer: peer, accountPeerId: accountPeerId) else {
                    continue
                }
                let readCounters = item.readCounters
                let isUnread = (readCounters?.count ?? 0) > 0 || (readCounters?.markedUnread ?? false)
                chats.append(NovagramCarPlayChat(
                    peerId: peer.id,
                    title: mainPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder),
                    isUnread: isUnread,
                    isMuted: item.isMuted,
                    timestamp: item.messages.last?.timestamp ?? 0
                ))
            }
            // Muted chats (mostly busy groups) go after the rest, so groups that post every minute
            // do not push private chats and bots off the car's short list.
            let ordered = chats.filter { !$0.isMuted } + chats.filter { $0.isMuted }
            return .chats(Array(ordered.prefix(maximumItemCount)))
        }
    }
    |> distinctUntilChanged
}

private let novagramCarPlayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

private let novagramCarPlayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

private func novagramCarPlayTrailingText(_ timestamp: Int32) -> String? {
    guard timestamp > 0 else {
        return nil
    }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    if Calendar.current.isDateInToday(date) {
        return novagramCarPlayTimeFormatter.string(from: date)
    } else {
        return novagramCarPlayDateFormatter.string(from: date)
    }
}

@objc(NovagramCarPlaySceneDelegate)
final class NovagramCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var listTemplate: CPListTemplate?
    private let contentDisposable = MetaDisposable()

    deinit {
        self.contentDisposable.dispose()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        let listTemplate = CPListTemplate(title: "Novagram", sections: [])
        // Starts a new message through Siri; the button has no handler of its own.
        listTemplate.trailingNavigationBarButtons = [CPMessageComposeBarButton()]
        self.listTemplate = listTemplate
        interfaceController.setRootTemplate(listTemplate, animated: false, completion: nil)

        let maximumItemCount = Int(CPListTemplate.maximumItemCount)
        let content = NovagramCarPlaySupport.sharedContext
        |> take(1)
        |> mapToSignal { sharedContext -> Signal<(NovagramCarPlayContent, PresentationStrings), NoError> in
            return novagramCarPlayContent(sharedContext: sharedContext, maximumItemCount: maximumItemCount)
            |> map { content -> (NovagramCarPlayContent, PresentationStrings) in
                return (content, sharedContext.currentPresentationData.with { $0 }.strings)
            }
        }
        self.contentDisposable.set((content |> deliverOnMainQueue).start(next: { [weak self] content, strings in
            self?.apply(content, strings: strings)
        }))
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.contentDisposable.set(nil)
        self.listTemplate = nil
    }

    private func apply(_ content: NovagramCarPlayContent, strings: PresentationStrings) {
        guard let listTemplate = self.listTemplate else {
            return
        }
        let langCode = NovagramL10n.languageKey(for: strings)
        switch content {
        case .loggedOut:
            listTemplate.emptyViewTitleVariants = [NovagramCarPlaySceneStrings.loggedOutTitle(langCode: langCode)]
            listTemplate.emptyViewSubtitleVariants = [NovagramCarPlaySceneStrings.loggedOutSubtitle(langCode: langCode)]
            listTemplate.updateSections([])
        case .locked:
            listTemplate.emptyViewTitleVariants = [NovagramCarPlaySceneStrings.lockedTitle(langCode: langCode)]
            listTemplate.emptyViewSubtitleVariants = [NovagramCarPlaySceneStrings.lockedSubtitle(langCode: langCode)]
            listTemplate.updateSections([])
        case let .chats(chats):
            listTemplate.emptyViewTitleVariants = [NovagramCarPlaySceneStrings.noChatsTitle(langCode: langCode)]
            listTemplate.emptyViewSubtitleVariants = []
            let makeItem: (NovagramCarPlayChat) -> CPMessageListItem = { chat in
                return CPMessageListItem(
                    conversationIdentifier: "\(chat.peerId.toInt64())",
                    text: chat.title,
                    leadingConfiguration: CPMessageListItemLeadingConfiguration(leadingItem: .none, leadingImage: nil, unread: chat.isUnread),
                    trailingConfiguration: CPMessageListItemTrailingConfiguration(trailingItem: chat.isMuted ? .mute : .none, trailingImage: nil),
                    detailText: nil,
                    trailingText: novagramCarPlayTrailingText(chat.timestamp)
                )
            }
            let unmutedItems = chats.filter { !$0.isMuted }.map(makeItem)
            let mutedItems = chats.filter { $0.isMuted }.map(makeItem)
            var sections: [CPListSection] = []
            if !unmutedItems.isEmpty {
                sections.append(CPListSection(items: unmutedItems))
            }
            if !mutedItems.isEmpty {
                sections.append(CPListSection(items: mutedItems, header: NovagramCarPlaySceneStrings.mutedHeader(langCode: langCode), sectionIndexTitle: nil))
            }
            listTemplate.updateSections(sections)
        }
    }
}

private enum NovagramCarPlaySceneStrings {
    static func mutedHeader(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ovozsiz"
        case "ru": return "Без звука"
        case "zh": return "已静音"
        default:   return "Muted"
        }
    }

    static func noChatsTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Chatlar yo'q"
        case "ru": return "Нет чатов"
        case "zh": return "没有聊天"
        default:   return "No chats"
        }
    }

    static func loggedOutTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram'ga kiring"
        case "ru": return "Войдите в Novagram"
        case "zh": return "请登录 Novagram"
        default:   return "Log in to Novagram"
        }
    }

    static func loggedOutSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Akkauntga iPhone'da kiring"
        case "ru": return "Войдите в аккаунт на iPhone"
        case "zh": return "请在 iPhone 上登录账号"
        default:   return "Log in on your iPhone"
        }
    }

    static func lockedTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram qulflangan"
        case "ru": return "Novagram заблокирован"
        case "zh": return "Novagram 已锁定"
        default:   return "Novagram is locked"
        }
    }

    static func lockedSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qulfni iPhone'da oching"
        case "ru": return "Разблокируйте его на iPhone"
        case "zh": return "请在 iPhone 上解锁"
        default:   return "Unlock it on your iPhone"
        }
    }
}
