import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import ButtonComponent
import ResizableSheetComponent
import ListActionItemComponent
import ListSectionComponent
import ListItemComponentAdaptor
import PeerListItemComponent
import AlertComponent
import AlertUI
import ChatListUI
import ChatListHeaderComponent
import ChatListTitleView
import SearchUI
import ItemListUI
import CommunityPrivateChatScreen

private struct CommunityChatPreviewData: Equatable {
    var messages: [EngineMessage]
    var readCounters: EnginePeerReadCounters

    var timestamp: Int32 {
        return self.messages.map(\.timestamp).max() ?? 0
    }

    var searchText: String {
        return self.messages.map(\.text).joined(separator: " ")
    }
}

private enum CommunityViewSection: Int {
    case joined
    case visible
    case requestable
}

private struct CommunityViewRow: Equatable {
    let peer: EnginePeer
    let linkedPeer: CachedCommunityData.CommunityLinkedPeer
}

private struct CommunityViewRequestRow: Equatable {
    let request: CommunityPeerRequest
    let peer: EnginePeer
    let requestedBy: EnginePeer?
    let memberCount: Int32?
    let isPrivate: Bool
    let isVisible: Bool
}

private final class CommunityViewPendingAccessoryComponent: Component {
    let count: Int32?
    let theme: PresentationTheme

    init(count: Int32?, theme: PresentationTheme) {
        self.count = count
        self.theme = theme
    }

    static func ==(lhs: CommunityViewPendingAccessoryComponent, rhs: CommunityViewPendingAccessoryComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private let badgeBackgroundView = UIView()
        private let chevronView = UIImageView()
        private var component: CommunityViewPendingAccessoryComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.badgeBackgroundView)
            self.addSubview(self.chevronView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: CommunityViewPendingAccessoryComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            if themeUpdated || self.chevronView.image == nil {
                self.chevronView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
            }

            let countValue = component.count.flatMap { $0 > 0 ? Int($0) : nil }
            var textSize = CGSize()
            if let countValue {
                textSize = self.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "\(countValue)",
                            font: Font.medium(12.0),
                            textColor: component.theme.list.itemCheckColors.foregroundColor
                        )),
                        horizontalAlignment: .center,
                        verticalAlignment: .middle
                    )),
                    environment: {},
                    containerSize: CGSize(width: 80.0, height: 20.0)
                )
                if let textView = self.text.view {
                    if textView.superview == nil {
                        self.insertSubview(textView, aboveSubview: self.badgeBackgroundView)
                    }
                    textView.isHidden = false
                    textView.backgroundColor = nil
                }
                self.badgeBackgroundView.isHidden = false
                self.badgeBackgroundView.backgroundColor = component.theme.list.itemCheckColors.fillColor
                self.badgeBackgroundView.layer.cornerRadius = 10.0
                self.badgeBackgroundView.clipsToBounds = true
            } else {
                self.text.view?.isHidden = true
                self.badgeBackgroundView.isHidden = true
            }

            let chevronSize = self.chevronView.image?.size ?? CGSize(width: 8.0, height: 13.0)
            let spacing: CGFloat = countValue == nil ? 0.0 : 4.0
            let size = CGSize(width: textSize.width + spacing + chevronSize.width - 9.0, height: max(20.0, chevronSize.height))

            var currentX: CGFloat = 0.0
            if countValue != nil {
                let badgeBackgroundSize = CGSize(width: max(20.0, textSize.width), height: 20.0)
                transition.setFrame(view: self.badgeBackgroundView, frame: CGRect(
                    origin: CGPoint(x: currentX + textSize.width * 0.5 - badgeBackgroundSize.width * 0.5, y: floor((size.height - badgeBackgroundSize.height) * 0.5)),
                    size: badgeBackgroundSize
                ))
                if let textView = self.text.view {
                    transition.setFrame(view: textView, frame: CGRect(
                        origin: CGPoint(x: currentX, y: floor((size.height - textSize.height) * 0.5)),
                        size: textSize
                    ))
                }
                currentX += textSize.width + spacing
            }
            transition.setFrame(view: self.chevronView, frame: CGRect(
                origin: CGPoint(x: currentX, y: floor((size.height - chevronSize.height) * 0.5)),
                size: chevronSize
            ))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private func communityChatPreviewSignal(context: AccountContext, peerId: EnginePeer.Id) -> Signal<(EnginePeer.Id, CommunityChatPreviewData), NoError> {
    var ignoredNamespaces = Set<Int32>()
    ignoredNamespaces = ignoredNamespaces.union(Namespaces.Message.allNonRegular)
    ignoredNamespaces = ignoredNamespaces.union(Namespaces.Message.allEphemeral)

    return combineLatest(
        context.account.postbox.aroundMessageHistoryViewForLocation(
            .peer(peerId: peerId, threadId: nil),
            anchor: .upperBound,
            ignoreMessagesInTimestampRange: nil,
            ignoreMessageIds: Set(),
            count: 10,
            clipHoles: false,
            fixedCombinedReadStates: nil,
            topTaggedMessageIdNamespaces: Set(),
            tag: nil,
            appendMessagesFromTheSameGroup: false,
            namespaces: .not(ignoredNamespaces),
            orderStatistics: []
        ),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.PeerReadCounters(id: peerId))
    )
    |> map { viewData, readCounters -> (EnginePeer.Id, CommunityChatPreviewData) in
        let (view, _, _) = viewData
        var messages: [EngineMessage] = []
        for i in (0 ..< view.entries.count).reversed() {
            if messages.isEmpty {
                messages.append(EngineMessage(view.entries[i].message))
            } else if messages[0].groupingKey != nil && messages[0].groupingKey == view.entries[i].message.groupingKey {
                messages.append(EngineMessage(view.entries[i].message))
            }
        }
        messages = messages.reversed()

        return (peerId, CommunityChatPreviewData(messages: messages, readCounters: readCounters))
    }
}

private func communityChatPreviewsSignal(context: AccountContext, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: CommunityChatPreviewData], NoError> {
    if peerIds.isEmpty {
        return .single([:])
    }

    return combineLatest(peerIds.map { peerId in
        return communityChatPreviewSignal(context: context, peerId: peerId)
    })
    |> map { values -> [EnginePeer.Id: CommunityChatPreviewData] in
        var result: [EnginePeer.Id: CommunityChatPreviewData] = [:]
        for (peerId, preview) in values {
            result[peerId] = preview
        }
        return result
    }
}

private func communityCachedMemberCounts(_ data: [EnginePeer.Id: CachedPeerData]) -> [EnginePeer.Id: Int32] {
    var result: [EnginePeer.Id: Int32] = [:]
    for (peerId, cachedData) in data {
        if let cachedData = cachedData as? CachedChannelData, let count = cachedData.participantsSummary.memberCount {
            result[peerId] = count
        } else if let cachedData = cachedData as? CachedGroupData {
            result[peerId] = Int32(cachedData.participants?.participants.count ?? 0)
        }
    }
    return result
}

private func communityChatListContextActionsEqual(_ lhs: ChatListItem.EnabledContextActions?, _ rhs: ChatListItem.EnabledContextActions?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (.auto?, .auto?):
        return true
    case let (.custom(lhsActions)?, .custom(rhsActions)?):
        return lhsActions.rawValue == rhsActions.rawValue
    default:
        return false
    }
}

private final class CommunityChatListItemGenerator: ListItemComponentAdaptor.ItemGenerator {
    let context: AccountContext
    let presentationData: ChatListPresentationData
    let peer: EnginePeer
    let preview: CommunityChatPreviewData
    let interaction: ChatListNodeInteraction
    let enabledContextActions: ChatListItem.EnabledContextActions?
    let hasActiveRevealControls: Bool
    let hasNext: Bool

    init(
        context: AccountContext,
        presentationData: ChatListPresentationData,
        peer: EnginePeer,
        preview: CommunityChatPreviewData,
        interaction: ChatListNodeInteraction,
        enabledContextActions: ChatListItem.EnabledContextActions?,
        hasActiveRevealControls: Bool,
        hasNext: Bool
    ) {
        self.context = context
        self.presentationData = presentationData
        self.peer = peer
        self.preview = preview
        self.interaction = interaction
        self.enabledContextActions = enabledContextActions
        self.hasActiveRevealControls = hasActiveRevealControls
        self.hasNext = hasNext
    }

    static func ==(lhs: CommunityChatListItemGenerator, rhs: CommunityChatListItemGenerator) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.preview != rhs.preview {
            return false
        }
        if !communityChatListContextActionsEqual(lhs.enabledContextActions, rhs.enabledContextActions) {
            return false
        }
        if lhs.hasActiveRevealControls != rhs.hasActiveRevealControls {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        if lhs.presentationData.theme !== rhs.presentationData.theme {
            return false
        }
        if lhs.presentationData.fontSize != rhs.presentationData.fontSize {
            return false
        }
        if lhs.presentationData.strings !== rhs.presentationData.strings {
            return false
        }
        if lhs.presentationData.dateTimeFormat != rhs.presentationData.dateTimeFormat {
            return false
        }
        if lhs.presentationData.nameSortOrder != rhs.presentationData.nameSortOrder {
            return false
        }
        if lhs.presentationData.nameDisplayOrder != rhs.presentationData.nameDisplayOrder {
            return false
        }
        if lhs.presentationData.disableAnimations != rhs.presentationData.disableAnimations {
            return false
        }
        return true
    }

    func item() -> ListViewItem {
        let messageIndex: EngineMessage.Index
        if let message = self.preview.messages.first {
            messageIndex = message.index
        } else {
            messageIndex = EngineMessage.Index(
                id: EngineMessage.Id(peerId: self.peer.id, namespace: Namespaces.Message.Cloud, id: 0),
                timestamp: 0
            )
        }

        return ChatListItem(
            presentationData: self.presentationData,
            context: self.context,
            chatListLocation: .chatList(groupId: .root),
            filterData: nil,
            index: .chatList(EngineChatListIndex(pinningIndex: nil, messageIndex: messageIndex)),
            content: .peer(ChatListItemContent.PeerData(
                messages: self.preview.messages,
                peer: EngineRenderedPeer(peer: self.peer),
                threadInfo: nil,
                combinedReadState: self.preview.readCounters,
                isRemovedFromTotalUnreadCount: self.preview.readCounters.isMuted,
                presence: nil,
                hasUnseenMentions: false,
                hasUnseenReactions: false,
                hasUnseenPollVotes: false,
                draftState: nil,
                mediaDraftContentType: nil,
                inputActivities: [],
                promoInfo: nil,
                ignoreUnreadBadge: false,
                displayAsMessage: false,
                hasFailedMessages: false,
                forumTopicData: nil,
                topForumTopicItems: [],
                autoremoveTimeout: nil,
                storyState: nil,
                requiresPremiumForMessaging: false,
                displayAsTopicList: false,
                tags: []
            )),
            editing: false,
            hasActiveRevealControls: self.hasActiveRevealControls,
            selected: false,
            header: nil,
            enabledContextActions: self.enabledContextActions,
            hiddenOffset: false,
            interaction: self.interaction,
            useCommunityViewLayout: true,
            communityViewHasNext: false
        )
    }
}

private final class CommunityViewBottomButtonComponent: Component {
    let theme: PresentationTheme
    let title: String
    let iconName: String?
    let safeInsets: UIEdgeInsets
    let isEnabled: Bool
    let displaysProgress: Bool
    let action: () -> Void

    init(
        theme: PresentationTheme,
        title: String,
        iconName: String?,
        safeInsets: UIEdgeInsets,
        isEnabled: Bool,
        displaysProgress: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.title = title
        self.iconName = iconName
        self.safeInsets = safeInsets
        self.isEnabled = isEnabled
        self.displaysProgress = displaysProgress
        self.action = action
    }

    static func ==(lhs: CommunityViewBottomButtonComponent, rhs: CommunityViewBottomButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.displaysProgress != rhs.displaysProgress {
            return false
        }
        return true
    }

    final class View: UIView {
        private let button = ComponentView<Empty>()

        func update(component: CommunityViewBottomButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            var buttonItems: [AnyComponentWithIdentity<Empty>] = []
            if let iconName = component.iconName {
                buttonItems.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(
                    name: iconName,
                    tintColor: component.theme.list.itemCheckColors.foregroundColor
                ))))
            }
            buttonItems.append(AnyComponentWithIdentity(id: "title", component: AnyComponent(Text(
                text: component.title,
                font: Font.semibold(17.0),
                color: component.theme.list.itemCheckColors.foregroundColor
            ))))

            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: component.title, component: AnyComponent(HStack(buttonItems, spacing: 8.0))),
                    isEnabled: component.isEnabled,
                    displaysProgress: component.displaysProgress,
                    action: component.action
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 52.0)
            )

            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: CGRect(
                    origin: CGPoint(x: 0.0, y: 0.0),
                    size: CGSize(width: availableSize.width, height: buttonSize.height)
                ))
            }

            return CGSize(width: availableSize.width, height: buttonSize.height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class CommunityViewContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id
    let style: CommunityViewScreenStyle
    let presentation: CommunityViewScreenPresentation
    let topInset: CGFloat
    let community: TelegramCommunity?
    let cachedData: CachedCommunityData?
    let peers: [EnginePeer.Id: EnginePeer]
    let cachedPeerData: [EnginePeer.Id: CachedPeerData]
    let previews: [EnginePeer.Id: CommunityChatPreviewData]
    let pendingRequests: CommunityPeerLinkRequests?
    let pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData]
    let pendingRequestInFlightPeerId: EnginePeer.Id?
    let pendingRequestInFlightApprove: Bool?
    let joinedPeerIds: Set<EnginePeer.Id>
    let toggleCollapsed: (Bool) -> Void
    let setRequestApproval: (CommunityPeerRequest, Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openPendingRequests: () -> Void
    let removePeer: (EnginePeer.Id) -> Void

    init(
        context: AccountContext,
        communityId: EnginePeer.Id,
        style: CommunityViewScreenStyle,
        presentation: CommunityViewScreenPresentation,
        topInset: CGFloat,
        community: TelegramCommunity?,
        cachedData: CachedCommunityData?,
        peers: [EnginePeer.Id: EnginePeer],
        cachedPeerData: [EnginePeer.Id: CachedPeerData],
        previews: [EnginePeer.Id: CommunityChatPreviewData],
        pendingRequests: CommunityPeerLinkRequests?,
        pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData],
        pendingRequestInFlightPeerId: EnginePeer.Id?,
        pendingRequestInFlightApprove: Bool?,
        joinedPeerIds: Set<EnginePeer.Id>,
        toggleCollapsed: @escaping (Bool) -> Void,
        setRequestApproval: @escaping (CommunityPeerRequest, Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openPendingRequests: @escaping () -> Void,
        removePeer: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.communityId = communityId
        self.style = style
        self.presentation = presentation
        self.topInset = topInset
        self.community = community
        self.cachedData = cachedData
        self.peers = peers
        self.cachedPeerData = cachedPeerData
        self.previews = previews
        self.pendingRequests = pendingRequests
        self.pendingRequestCachedPeerData = pendingRequestCachedPeerData
        self.pendingRequestInFlightPeerId = pendingRequestInFlightPeerId
        self.pendingRequestInFlightApprove = pendingRequestInFlightApprove
        self.joinedPeerIds = joinedPeerIds
        self.toggleCollapsed = toggleCollapsed
        self.setRequestApproval = setRequestApproval
        self.openPeer = openPeer
        self.openPendingRequests = openPendingRequests
        self.removePeer = removePeer
    }

    static func ==(lhs: CommunityViewContentComponent, rhs: CommunityViewContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.presentation != rhs.presentation {
            return false
        }
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.community != rhs.community {
            return false
        }
        if lhs.cachedData !== rhs.cachedData {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if communityCachedMemberCounts(lhs.cachedPeerData) != communityCachedMemberCounts(rhs.cachedPeerData) {
            return false
        }
        if lhs.previews != rhs.previews {
            return false
        }
        if lhs.pendingRequests != rhs.pendingRequests {
            return false
        }
        if communityCachedMemberCounts(lhs.pendingRequestCachedPeerData) != communityCachedMemberCounts(rhs.pendingRequestCachedPeerData) {
            return false
        }
        if lhs.pendingRequestInFlightPeerId != rhs.pendingRequestInFlightPeerId {
            return false
        }
        if lhs.pendingRequestInFlightApprove != rhs.pendingRequestInFlightApprove {
            return false
        }
        if lhs.joinedPeerIds != rhs.joinedPeerIds {
            return false
        }
        return true
    }

    final class View: UIView {
        private let collapseSection = ComponentView<Empty>()
        private let collapseFooter = ComponentView<Empty>()
        private let pendingRequestsSection = ComponentView<Empty>()
        private var sectionViews: [CommunityViewSection: ComponentView<Empty>] = [:]

        private var component: CommunityViewContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var interaction: ChatListNodeInteraction?
        private var revealedPeerId: EnginePeer.Id?
        private let pendingRequestsIcon = renderSettingsIcon(name: "Item List/Icons/Requests", backgroundColors: [UIColor(rgb: 0x0079ff)])

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func makeInteraction(component: CommunityViewContentComponent) -> ChatListNodeInteraction {
            if let current = self.interaction {
                return current
            }

            let interaction = ChatListNodeInteraction(
                context: component.context,
                animationCache: component.context.animationCache,
                animationRenderer: component.context.animationRenderer,
                activateSearch: {},
                peerSelected: { [weak self] peer, _, _, _, _ in
                    self?.component?.openPeer(peer)
                },
                disabledPeerSelected: { _, _, _ in },
                togglePeerSelected: { _, _ in },
                togglePeersSelection: { _, _ in },
                additionalCategorySelected: { _ in },
                messageSelected: { _, _, _, _ in },
                groupSelected: { _ in },
                addContact: { _ in },
                setPeerIdWithRevealedOptions: { [weak self] peerId, fromPeerId in
                    guard let self else {
                        return
                    }
                    if (peerId == nil && fromPeerId == self.revealedPeerId) || (peerId != nil && fromPeerId == nil) || (peerId == nil && fromPeerId == nil) {
                        self.revealedPeerId = peerId
                        self.state?.updated(transition: .immediate)
                    }
                },
                setItemPinned: { _, _ in },
                setPeerMuted: { _, _ in },
                setPeerThreadMuted: { _, _, _ in },
                deletePeer: { [weak self] peerId, _ in
                    guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                        return
                    }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    //TODO:localize
                    let title = "Remove chat from community?"
                    //TODO:localize
                    let text = "This chat will be removed from the community."
                    controller.present(textAlertController(
                        context: component.context,
                        title: title,
                        text: text,
                        actions: [
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                            TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                                component.removePeer(peerId)
                            })
                        ]
                    ), in: .window(.root))
                },
                deletePeerThread: { _, _ in },
                setPeerThreadStopped: { _, _, _ in },
                setPeerThreadPinned: { _, _, _ in },
                setPeerThreadHidden: { _, _, _ in },
                updatePeerGrouping: { _, _ in },
                togglePeerMarkedUnread: { _, _ in },
                toggleArchivedFolderHiddenByDefault: {},
                toggleThreadsSelection: { _, _ in },
                hidePsa: { _ in },
                activateChatPreview: { _, _, _, gesture, _ in
                    gesture?.cancel()
                },
                present: { _ in },
                openForumThread: { _, _ in },
                openStorageManagement: {},
                openPasswordSetup: {},
                openPremiumIntro: {},
                openPremiumGift: { _, _ in },
                openPremiumManagement: {},
                openActiveSessions: {},
                openBirthdaySetup: {},
                performActiveSessionAction: { _, _ in },
                performBotConnectionReviewAction: { _, _ in },
                openChatFolderUpdates: {},
                hideChatFolderUpdates: {},
                openStories: { _, _ in },
                openStarsTopup: { _ in },
                editPeer: { _ in },
                openWebApp: { _ in },
                openPhotoSetup: {},
                openAdInfo: { _, _ in },
                openAccountFreezeInfo: {},
                openUrl: { _ in }
            )
            self.interaction = interaction
            return interaction
        }

        private func rows(component: CommunityViewContentComponent, section: CommunityViewSection) -> [CommunityViewRow] {
            guard let cachedData = component.cachedData else {
                return []
            }

            var result: [CommunityViewRow] = []
            for linkedPeer in cachedData.linkedPeers {
                guard let peer = component.peers[linkedPeer.peerId] else {
                    continue
                }
                var isJoined = false
                if case let .channel(channel) = peer, case .member = channel.participationStatus {
                    isJoined = true
                }
                switch section {
                case .joined:
                    if isJoined {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                case .visible:
                    if !isJoined && peer.addressName != nil {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                case .requestable:
                    if !isJoined && peer.addressName == nil {
                        result.append(CommunityViewRow(peer: peer, linkedPeer: linkedPeer))
                    }
                }
            }

            return result.enumerated().sorted { lhs, rhs in
                let lhsTimestamp = component.previews[lhs.element.peer.id]?.timestamp ?? 0
                let rhsTimestamp = component.previews[rhs.element.peer.id]?.timestamp ?? 0
                if lhsTimestamp != rhsTimestamp {
                    return lhsTimestamp > rhsTimestamp
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }

        private func memberCountString(component: CommunityViewContentComponent, peerId: EnginePeer.Id) -> String? {
            guard let count = communityCachedMemberCounts(component.cachedPeerData)[peerId] else {
                return nil
            }
            if count > 1 {
                return "\(count) members"
            } else if count == 1 {
                return "\(count) member"
            }
            return nil
        }

        private func memberCount(peerId: EnginePeer.Id, cachedPeerData: [EnginePeer.Id: CachedPeerData]) -> Int32? {
            guard let cachedData = cachedPeerData[peerId] else {
                return nil
            }
            if let cachedData = cachedData as? CachedChannelData {
                return cachedData.participantsSummary.memberCount
            } else if let cachedData = cachedData as? CachedGroupData, let participants = cachedData.participants {
                return Int32(participants.participants.count)
            } else {
                return nil
            }
        }

        private func pendingRequestRows(component: CommunityViewContentComponent) -> [CommunityViewRequestRow] {
            guard let pendingRequests = component.pendingRequests else {
                return []
            }
            var result: [CommunityViewRequestRow] = []
            for request in pendingRequests.requests {
                if let peer = pendingRequests.peers[request.peerId] {
                    var isPrivate = true
                    if let addressName = peer.addressName, !addressName.isEmpty {
                        isPrivate = false
                    }
                    result.append(CommunityViewRequestRow(
                        request: request,
                        peer: peer,
                        requestedBy: pendingRequests.peers[request.requestedBy],
                        memberCount: self.memberCount(peerId: request.peerId, cachedPeerData: component.pendingRequestCachedPeerData),
                        isPrivate: isPrivate,
                        isVisible: request.isVisible
                    ))
                }
            }
            return result
        }

        private func openRequest(row: CommunityViewRequestRow) {
            if !row.isPrivate {
                self.component?.openPeer(row.peer)
                return
            }

            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = CommunityPrivateChatScreen(
                context: component.context,
                chatPeer: row.peer,
                requestedByPeer: row.requestedBy,
                memberCount: row.memberCount,
                messageOwner: { [weak self, requestedBy = row.requestedBy] in
                    if let requestedBy {
                        self?.component?.openPeer(requestedBy)
                    }
                }
            )
            environment.controller()?.present(controller, in: .window(.root))
        }

        private func sectionTitle(_ section: CommunityViewSection) -> String {
            switch section {
            case .joined:
                return "CHATS YOU ARE IN"
            case .visible:
                return "CHATS YOU CAN JOIN"
            case .requestable:
                return "CHATS YOU CAN REQUEST TO JOIN"
            }
        }

        private func updateSection(
            component: CommunityViewContentComponent,
            section: CommunityViewSection,
            rows: [CommunityViewRow],
            theme: PresentationTheme,
            presentationData: PresentationData,
            availableWidth: CGFloat,
            sectionStyle: ListSectionComponent.Style,
            transition: ComponentTransition
        ) -> CGSize {
            let sectionView: ComponentView<Empty>
            if let current = self.sectionViews[section] {
                sectionView = current
            } else {
                sectionView = ComponentView<Empty>()
                self.sectionViews[section] = sectionView
            }

            var items: [AnyComponentWithIdentity<Empty>] = []
            let chatListPresentationData = ChatListPresentationData(
                theme: theme,
                fontSize: presentationData.listsFontSize,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameSortOrder: presentationData.nameSortOrder,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                disableAnimations: true
            )
            let interaction = self.makeInteraction(component: component)
            let canManageLinkedPeers = component.community?.hasPermission(.manageLinkedPeers) == true

            for index in rows.indices {
                let row = rows[index]
                switch section {
                case .joined, .visible:
                    let preview = component.previews[row.peer.id] ?? CommunityChatPreviewData(messages: [], readCounters: EnginePeerReadCounters())
                    items.append(AnyComponentWithIdentity(id: row.peer.id, component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: CommunityChatListItemGenerator(
                            context: component.context,
                            presentationData: chatListPresentationData,
                            peer: row.peer,
                            preview: preview,
                            interaction: interaction,
                            enabledContextActions: canManageLinkedPeers ? .custom([.delete]) : nil,
                            hasActiveRevealControls: self.revealedPeerId == row.peer.id,
                            hasNext: index != rows.count - 1
                        ),
                        params: ListViewItemLayoutParams(
                            width: availableWidth,
                            leftInset: 0.0,
                            rightInset: 0.0,
                            availableHeight: 10000.0,
                            isStandalone: true
                        ),
                        action: { [weak self] in
                            guard let self, self.revealedPeerId == nil else {
                                return
                            }
                            self.component?.openPeer(row.peer)
                        },
                        actionMode: .gesture
                    ))))
                case .requestable:
                    let subtitle = self.memberCountString(component: component, peerId: row.peer.id).flatMap {
                        PeerListItemComponent.Subtitle(text: $0, color: .neutral)
                    }
                    items.append(AnyComponentWithIdentity(id: row.peer.id, component: AnyComponent(PeerListItemComponent(
                        context: component.context,
                        theme: theme,
                        strings: presentationData.strings,
                        style: .list,
                        sideInset: 0.0,
                        title: row.peer.compactDisplayTitle,
                        peer: row.peer,
                        subtitle: subtitle,
                        subtitleAccessory: .none,
                        presence: nil,
                        rightAccessory: .disclosure,
                        selectionState: .none,
                        isEnabled: true,
                        hasNext: false,
                        extractedTheme: PeerListItemComponent.ExtractedTheme(
                            inset: 2.0,
                            background: component.style == .plain ? theme.chatList.itemBackgroundColor : theme.list.itemBlocksBackgroundColor
                        ),
                        insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0),
                        action: { peer, _, _ in
                            component.openPeer(peer)
                        }
                    ))))
                }
            }

            return sectionView.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: sectionStyle,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.sectionTitle(section),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 10000.0)
            )
        }

        private func updatePendingRequestsSection(
            component: CommunityViewContentComponent,
            theme: PresentationTheme,
            presentationData: PresentationData,
            availableWidth: CGFloat,
            sectionStyle: ListSectionComponent.Style,
            actionItemStyle: ListActionItemComponent.Style,
            transition: ComponentTransition
        ) -> CGSize? {
            let totalCount: Int32
            if let pendingRequests = component.pendingRequests {
                totalCount = pendingRequests.totalCount
            } else {
                totalCount = component.cachedData?.pendingRequests ?? 0
            }
            guard totalCount > 0 else {
                return nil
            }

            var items: [AnyComponentWithIdentity<Empty>] = []
            let rows = self.pendingRequestRows(component: component)
            if totalCount == 1 {
                guard let row = rows.first else {
                    return nil
                }
                let isInFlight = component.pendingRequestInFlightPeerId == row.request.peerId
                items.append(AnyComponentWithIdentity(id: row.request.peerId, component: AnyComponent(CommunityRequestItemComponent(
                    context: component.context,
                    theme: theme,
                    strings: presentationData.strings,
                    chatPeer: row.peer,
                    requestedByPeer: row.requestedBy,
                    memberCount: row.memberCount,
                    isPrivate: row.isPrivate,
                    isVisible: row.isVisible,
                    isEnabled: component.pendingRequestInFlightPeerId == nil,
                    declineDisplaysProgress: isInFlight && component.pendingRequestInFlightApprove == false,
                    addDisplaysProgress: isInFlight && component.pendingRequestInFlightApprove == true,
                    hasNext: false,
                    open: { [weak self] _ in
                        self?.openRequest(row: row)
                    },
                    add: { _ in
                        component.setRequestApproval(row.request, true)
                    },
                    decline: { _ in
                        component.setRequestApproval(row.request, false)
                    }
                ))))
            } else {
                items.append(AnyComponentWithIdentity(id: "pendingRequests", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: actionItemStyle,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Pending Requests",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .custom(AnyComponentWithIdentity(
                        id: "pendingRequestsIcon",
                        component: AnyComponent(Image(image: self.pendingRequestsIcon, size: CGSize(width: 30.0, height: 30.0)))
                    ), false),
                    accessory: .custom(ListActionItemComponent.CustomAccessory(
                        component: AnyComponentWithIdentity(id: "pendingRequests-accessory-\(totalCount)", component: AnyComponent(CommunityViewPendingAccessoryComponent(
                            count: totalCount,
                            theme: theme
                        ))),
                        insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0),
                        isInteractive: false
                    )),
                    action: { _ in
                        component.openPendingRequests()
                    }
                ))))
            }

            let header: AnyComponent<Empty>?
            if totalCount == 1 {
                header = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "PENDING REQUEST",
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        textColor: theme.list.freeTextColor
                    )),
                    maximumNumberOfLines: 1
                ))
            } else {
                header = nil
            }

            return self.pendingRequestsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: sectionStyle,
                    header: header,
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: availableWidth, height: 10000.0)
            )
        }

        func update(component: CommunityViewContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            var transition = transition
            if "".isEmpty {
                transition = .immediate
            }

            let theme: PresentationTheme
            let sectionStyle: ListSectionComponent.Style
            let actionItemStyle: ListActionItemComponent.Style
            let sideInset: CGFloat
            switch component.style {
            case .grouped:
                theme = environment.theme.withModalBlocksBackground()
                sectionStyle = .glass
                actionItemStyle = .glass
                sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            case .plain:
                theme = environment.theme
                sectionStyle = .legacy
                actionItemStyle = .legacy
                sideInset = max(environment.safeInsets.left, environment.safeInsets.right)
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sectionSpacing: CGFloat = component.style == .grouped ? 28.0 : 12.0
            let contentWidth = availableSize.width - sideInset * 2.0

            self.backgroundColor = .clear

            let isAdmin = component.community?.hasPermission(.manageLinkedPeers) == true
            var contentHeight: CGFloat = component.topInset + 16.0

            if component.style == .grouped {
                let collapseSectionSize = self.collapseSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: sectionStyle,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "collapse", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: actionItemStyle,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: "Show as One Chat",
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: theme.list.itemPrimaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                )),
                                accessory: .toggle(ListActionItemComponent.Toggle(
                                    style: .regular,
                                    isOn: component.community?.collapsedInDialogs == true,
                                    isInteractive: true,
                                    isEnabled: true,
                                    action: { [weak self] value in
                                        self?.component?.toggleCollapsed(value)
                                    }
                                )),
                                action: nil
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 10000.0)
                )
                if let collapseSectionView = self.collapseSection.view {
                    if collapseSectionView.superview == nil {
                        self.addSubview(collapseSectionView)
                    }
                    transition.setFrame(view: collapseSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: collapseSectionSize))
                }
                contentHeight += collapseSectionSize.height + 10.0

                let footerSize = self.collapseFooter.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Group all community chats into one item in the chat list.",
                            font: Font.regular(13.0),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 32.0, height: 10000.0)
                )
                if let footerView = self.collapseFooter.view {
                    if footerView.superview == nil {
                        self.addSubview(footerView)
                    }
                    transition.setFrame(view: footerView, frame: CGRect(origin: CGPoint(x: sideInset + 16.0, y: contentHeight), size: footerSize))
                }
                contentHeight += footerSize.height + sectionSpacing
            } else {
                self.collapseSection.view?.removeFromSuperview()
                self.collapseFooter.view?.removeFromSuperview()
            }

            if component.style == .grouped, isAdmin, let pendingRequestsSectionSize = self.updatePendingRequestsSection(
                component: component,
                theme: theme,
                presentationData: presentationData,
                availableWidth: contentWidth,
                sectionStyle: sectionStyle,
                actionItemStyle: actionItemStyle,
                transition: transition
            ) {
                if let pendingRequestsSectionView = self.pendingRequestsSection.view {
                    if pendingRequestsSectionView.superview == nil {
                        self.addSubview(pendingRequestsSectionView)
                    }
                    transition.setAlpha(view: pendingRequestsSectionView, alpha: 1.0)
                    transition.setFrame(view: pendingRequestsSectionView, frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: pendingRequestsSectionSize
                    ))
                }
                contentHeight += pendingRequestsSectionSize.height + sectionSpacing
            } else if let pendingRequestsSectionView = self.pendingRequestsSection.view {
                transition.setAlpha(view: pendingRequestsSectionView, alpha: 0.0, completion: { [weak pendingRequestsSectionView] _ in
                    pendingRequestsSectionView?.removeFromSuperview()
                })
            }


            let sections: [CommunityViewSection] = [.joined, .visible, .requestable]
            for section in sections {
                let rows = self.rows(component: component, section: section)
                guard !rows.isEmpty else {
                    if let sectionView = self.sectionViews[section]?.view {
                        transition.setAlpha(view: sectionView, alpha: 0.0, completion: { [weak sectionView] _ in
                            sectionView?.removeFromSuperview()
                        })
                    }
                    continue
                }

                let size = self.updateSection(
                    component: component,
                    section: section,
                    rows: rows,
                    theme: theme,
                    presentationData: presentationData,
                    availableWidth: contentWidth,
                    sectionStyle: sectionStyle,
                    transition: transition
                )
                if let sectionView = self.sectionViews[section]?.view {
                    if sectionView.superview == nil {
                        self.addSubview(sectionView)
                    }
                    transition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: size))
                }
                contentHeight += size.height + sectionSpacing
            }

            contentHeight += 16.0
            contentHeight += 60.0

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class CommunityViewScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id
    let style: CommunityViewScreenStyle
    let presentation: CommunityViewScreenPresentation

    init(context: AccountContext, communityId: EnginePeer.Id, style: CommunityViewScreenStyle, presentation: CommunityViewScreenPresentation) {
        self.context = context
        self.communityId = communityId
        self.style = style
        self.presentation = presentation
    }

    static func ==(lhs: CommunityViewScreenComponent, rhs: CommunityViewScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.presentation != rhs.presentation {
            return false
        }
        return true
    }

    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        private let animateOut = ActionSlot<Action<()>>()
        private let scrollView = UIScrollView()
        private let fullscreenContent = ComponentView<EnvironmentType>()
        private let fullscreenBottomItem = ComponentView<Empty>()
        private let navigationBarView = ComponentView<Empty>()
        private let searchOverlayNode = ASDisplayNode()
        private let sheetBoundsUpdated = ActionSlot<ResizableSheetComponentEnvironment.BoundsUpdate>()
        private let sheetNavigationTopInset: CGFloat = 16.0

        private var component: CommunityViewScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var validLayout: (ContainerViewLayout, CGFloat)?
        private var isSearchDisplayControllerActive: ChatListNavigationBar.ActiveSearch?
        private var searchDisplayController: SearchDisplayController?
        private var disappearingSearchDisplayController: SearchDisplayController?
        private var currentSheetBounds: CGRect?
        private var currentAvailableSize: CGSize = .zero
        private var lastInactiveNavigationHeight: CGFloat?
        private var sheetNavigationFrame: CGRect = .zero
        private var sheetTopInset: CGFloat = 0.0
        private var sheetContainerInset: CGFloat = 0.0

        private var community: TelegramCommunity?
        private var cachedData: CachedCommunityData?
        private var peers: [EnginePeer.Id: EnginePeer] = [:]
        private var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var previews: [EnginePeer.Id: CommunityChatPreviewData] = [:]
        private var pendingRequests: CommunityPeerLinkRequests?
        private var pendingRequestsContext: CommunityPeerLinkRequestsContext?
        private var pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var joinedPeerIds = Set<EnginePeer.Id>()

        private var isAddActionInProgress = false
        private var removingPeerId: EnginePeer.Id?
        private var didRequestInitialData = false
        private var didRequestJoinedChats = false

        private var dataDisposable: Disposable?
        private let linkedPeersDisposable = MetaDisposable()
        private let linkedPeerDataDisposable = MetaDisposable()
        private let previewsDisposable = MetaDisposable()
        private let joinedChatsDisposable = MetaDisposable()
        private let actionDisposable = MetaDisposable()
        private let removePeerDisposable = MetaDisposable()
        private let openSearchResultDisposable = MetaDisposable()
        private let pendingRequestsDisposable = MetaDisposable()
        private let pendingRequestCachedDataDisposable = MetaDisposable()
        private var currentLinkedPeerIds: [EnginePeer.Id] = []
        private var currentPendingRequestsCount: Int32?
        private var currentPendingRequestCachedPeerIds: [EnginePeer.Id] = []
        private var requestedPendingRequestCachedPeerIds = Set<EnginePeer.Id>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true

            self.sheetBoundsUpdated.connect { [weak self] update in
                guard let self else {
                    return
                }
                self.currentSheetBounds = update.bounds
                self.updateSheetNavigationBarFrame(bounds: update.bounds, transition: .immediate)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.dataDisposable?.dispose()
            self.linkedPeersDisposable.dispose()
            self.linkedPeerDataDisposable.dispose()
            self.previewsDisposable.dispose()
            self.joinedChatsDisposable.dispose()
            self.actionDisposable.dispose()
            self.removePeerDisposable.dispose()
            self.openSearchResultDisposable.dispose()
            self.pendingRequestsDisposable.dispose()
            self.pendingRequestCachedDataDisposable.dispose()
        }

        private var isAdmin: Bool {
            return self.community?.hasPermission(.manageLinkedPeers) == true
        }

        private func presentError() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            environment.controller()?.present(AlertScreen(
                context: component.context,
                title: nil,
                text: "Something went wrong.",
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_OK, type: .default)
                ]
            ), in: .window(.root))
        }

        private func updateLinkedPeerSignals(component: CommunityViewScreenComponent, ids: [EnginePeer.Id]) {
            if self.currentLinkedPeerIds == ids {
                return
            }
            self.currentLinkedPeerIds = ids

            if ids.isEmpty {
                self.peers = [:]
                self.cachedPeerData = [:]
                self.previews = [:]
                self.linkedPeersDisposable.set(nil)
                self.linkedPeerDataDisposable.set(nil)
                self.previewsDisposable.set(nil)
                self.state?.updated(transition: .immediate)
                return
            }

            self.linkedPeersDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peersById in
                guard let self else {
                    return
                }
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for id in ids {
                    if let maybePeer = peersById[id], let peer = maybePeer {
                        peers[id] = peer
                    }
                }
                self.peers = peers
                self.state?.updated(transition: .spring(duration: 0.35))
            }))

            self.linkedPeerDataDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
                for id in ids {
                    if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                        cachedPeerData[id] = cachedData
                    }
                }
                self.cachedPeerData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            }))

            self.previewsDisposable.set((communityChatPreviewsSignal(context: component.context, peerIds: ids)
            |> deliverOnMainQueue).startStrict(next: { [weak self] previews in
                guard let self else {
                    return
                }
                self.previews = previews
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func updatePendingRequestCachedData(component: CommunityViewScreenComponent) {
            let ids = self.pendingRequests?.requests.map(\.peerId) ?? []
            if self.currentPendingRequestCachedPeerIds == ids {
                return
            }
            self.currentPendingRequestCachedPeerIds = ids

            if ids.isEmpty {
                self.pendingRequestCachedPeerData = [:]
                self.pendingRequestCachedDataDisposable.set(nil)
                self.state?.updated(transition: .spring(duration: 0.35))
                return
            }

            for peerId in ids {
                if !self.requestedPendingRequestCachedPeerIds.contains(peerId) {
                    self.requestedPendingRequestCachedPeerIds.insert(peerId)
                    component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
                }
            }

            self.pendingRequestCachedDataDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
                for id in ids {
                    if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                        cachedPeerData[id] = cachedData
                    }
                }
                self.pendingRequestCachedPeerData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func updatePendingRequestsSignal(component: CommunityViewScreenComponent, force: Bool = false) {
            let pendingCount: Int32
            if self.isAdmin {
                pendingCount = self.cachedData?.pendingRequests ?? 0
            } else {
                pendingCount = 0
            }

            if pendingCount <= 0 {
                if self.currentPendingRequestsCount != 0 || self.pendingRequests != nil || !self.pendingRequestCachedPeerData.isEmpty {
                    self.currentPendingRequestsCount = 0
                    self.pendingRequests = nil
                    self.pendingRequestsContext = nil
                    self.pendingRequestCachedPeerData = [:]
                    self.currentPendingRequestCachedPeerIds = []
                    self.pendingRequestsDisposable.set(nil)
                    self.pendingRequestCachedDataDisposable.set(nil)
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
                return
            }

            if !force && self.pendingRequestsContext != nil {
                self.currentPendingRequestsCount = pendingCount
                return
            }
            self.currentPendingRequestsCount = pendingCount

            let requestsContext: CommunityPeerLinkRequestsContext
            if let current = self.pendingRequestsContext {
                requestsContext = current
                if force {
                    requestsContext.reload(limit: 2)
                }
            } else {
                requestsContext = component.context.engine.peers.communityPeerLinkRequestsContext(communityId: component.communityId, initialLimit: 2)
                self.pendingRequestsContext = requestsContext
            }

            self.pendingRequestsDisposable.set((requestsContext.state
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.pendingRequests = CommunityPeerLinkRequests(
                    totalCount: result.count,
                    requests: result.requests,
                    nextOffset: nil,
                    peers: result.peers
                )
                self.updatePendingRequestCachedData(component: component)
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func updateJoinedChatsSignal(component: CommunityViewScreenComponent, force: Bool = false) {
            if !force && self.didRequestJoinedChats {
                return
            }
            self.didRequestJoinedChats = true

            self.joinedChatsDisposable.set((component.context.engine.peers.communityParticipantJoinedChats(
                communityId: component.communityId,
                participantId: component.context.account.peerId
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.joinedPeerIds = Set(result.creatorChatIds + result.joinedChatIds)
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func ensureDataSignal(component: CommunityViewScreenComponent) {
            if self.dataDisposable == nil {
                self.dataDisposable = (component.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.communityId),
                    TelegramEngine.EngineData.Item.Peer.CachedData(id: component.communityId)
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                    guard let self else {
                        return
                    }

                    if let peer, case let .community(community) = peer {
                        self.community = community
                    } else {
                        self.community = nil
                    }
                    self.cachedData = cachedData as? CachedCommunityData

                    let ids = self.cachedData?.linkedPeers.map(\.peerId) ?? []
                    self.updateLinkedPeerSignals(component: component, ids: ids)
                    self.updatePendingRequestsSignal(component: component)
                    self.state?.updated(transition: .spring(duration: 0.35))
                })
            }

            if !self.didRequestInitialData {
                self.didRequestInitialData = true
                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
            }
            self.updateJoinedChatsSignal(component: component)
        }

        private func dismiss(animated: Bool) {
            guard let controller = self.environment?.controller else {
                return
            }
            if self.component?.presentation == .fullScreen {
                if let navigationController = controller()?.navigationController as? NavigationController {
                    let _ = navigationController.popViewController(animated: animated)
                } else {
                    controller()?.dismiss(completion: nil)
                }
                return
            }
            if animated {
                self.animateOut.invoke(Action { _ in
                    controller()?.dismiss(completion: nil)
                })
            } else {
                controller()?.dismiss(completion: nil)
            }
        }

        private func openEdit() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
            controller.navigationPresentation = .modal
            environment.controller()?.push(controller)
        }

        private func openPendingRequests() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityRequestsScreen(context: component.context, communityId: component.communityId, existingContext: self.pendingRequestsContext)
            controller.navigationPresentation = .modal
            environment.controller()?.push(controller)
        }

        private func openPeer(_ peer: EnginePeer) {
            guard let component = self.component, let environment = self.environment, let navigationController = environment.controller()?.navigationController as? NavigationController else {
                return
            }
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: component.context,
                chatLocation: .peer(peer),
                keepStack: .always,
                forceOpenChat: true
            ))
        }

        private func openPeerFromSearch(peer: EnginePeer, threadId: Int64?, dismissSearch: Bool) {
            guard let component = self.component, let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                return
            }
            self.openSearchResultDisposable.set((component.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actualPeer in
                guard let self, let component = self.component else {
                    return
                }
                if dismissSearch {
                    self.deactivateSearch(animated: true)
                }

                if case let .channel(channel) = actualPeer, channel.isForumOrMonoForum, let threadId {
                    self.deactivateSearch(animated: false)
                    let _ = component.context.sharedContext.navigateToForumThread(context: component.context, peerId: actualPeer.id, threadId: threadId, messageId: nil, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .never, animated: true).startStandalone()
                } else {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: component.context,
                        chatLocation: .peer(actualPeer),
                        keepStack: .always,
                        purposefulAction: { [weak self] in
                            self?.deactivateSearch(animated: false)
                        },
                        forceOpenChat: true
                    ))
                }
            }))
        }

        private func openMessageFromSearch(peer: EnginePeer, threadId: Int64?, messageId: EngineMessage.Id, deactivateOnAction: Bool) {
            guard let component = self.component, let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                return
            }
            self.openSearchResultDisposable.set((component.context.engine.peers.ensurePeerIsLocallyAvailable(peer: peer)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actualPeer in
                guard let self, let component = self.component else {
                    return
                }

                if case let .channel(channel) = actualPeer, channel.isForumOrMonoForum, let threadId {
                    self.deactivateSearch(animated: false)
                    let _ = component.context.sharedContext.navigateToForumThread(context: component.context, peerId: actualPeer.id, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .never, animated: true).startStandalone()
                } else {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: component.context,
                        chatLocation: .peer(actualPeer),
                        subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
                        keepStack: .always,
                        purposefulAction: { [weak self] in
                            if deactivateOnAction {
                                self?.deactivateSearch(animated: false)
                            }
                        },
                        forceOpenChat: true
                    ))
                }
            }))
        }

        private func activateSearch(searchContentNode: NavigationBarSearchContentNode) {
            guard let component = self.component, let environment = self.environment, let (layout, navigationHeight) = self.validLayout, self.searchDisplayController == nil else {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let contentNode = ChatListSearchContainerNode(
                context: component.context,
                animationCache: component.context.animationCache,
                animationRenderer: component.context.animationRenderer,
                filter: [],
                requestPeerType: nil,
                location: .chatList(groupId: .root),
                communityId: component.communityId,
                folder: nil,
                displaySearchFilters: false,
                hasDownloads: false,
                initialFilter: .chats,
                openPeer: { [weak self] peer, _, threadId, dismissSearch in
                    self?.openPeerFromSearch(peer: peer, threadId: threadId, dismissSearch: dismissSearch)
                },
                openDisabledPeer: { _, _, _ in
                },
                openRecentPeerOptions: { _ in
                },
                openMessage: { [weak self] peer, threadId, messageId, deactivateOnAction in
                    self?.openMessageFromSearch(peer: peer, threadId: threadId, messageId: messageId, deactivateOnAction: deactivateOnAction)
                },
                addContact: nil,
                peerContextAction: nil,
                present: { [weak self] controller, arguments in
                    self?.environment?.controller()?.present(controller, in: .window(.root), with: arguments)
                },
                presentInGlobalOverlay: { [weak self] controller, arguments in
                    self?.environment?.controller()?.presentInGlobalOverlay(controller, with: arguments)
                },
                navigationController: environment.controller()?.navigationController as? NavigationController,
                parentController: { [weak self] in
                    return self?.environment?.controller()
                }
            )
            contentNode.dismissSearch = { [weak self] in
                self?.deactivateSearch(animated: true)
            }
            contentNode.dismissSearchImmediately = { [weak self] in
                self?.deactivateSearch(animated: false)
            }

            let searchDisplayController = SearchDisplayController(
                presentationData: presentationData,
                mode: .list,
                contentNode: contentNode,
                cancel: { [weak self] in
                    self?.deactivateSearch(animated: true)
                },
                fieldStyle: searchContentNode.placeholderNode.fieldStyle,
                searchBarIsExternal: false
            )
            self.searchDisplayController = searchDisplayController
            self.isSearchDisplayControllerActive = ChatListNavigationBar.ActiveSearch(isExternal: false)
            self.searchOverlayNode.view.isUserInteractionEnabled = true
            self.state?.updated(transition: .spring(duration: 0.4))

            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
            searchDisplayController.activate(insertSubnode: { [weak self] subnode, isSearchBar in
                guard let self else {
                    return
                }
                if isSearchBar {
                    if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                        navigationBarComponentView.searchContentNode?.addSubnode(subnode)
                    }
                } else {
                    self.searchOverlayNode.addSubnode(subnode)
                }
            }, placeholder: searchContentNode.placeholderNode)
        }

        private func deactivateSearch(animated: Bool) {
            self.isSearchDisplayControllerActive = nil
            if let searchDisplayController = self.searchDisplayController {
                self.searchDisplayController = nil
                self.disappearingSearchDisplayController = searchDisplayController
                let placeholderNode = (self.navigationBarView.view as? ChatListNavigationBar.View)?.searchContentNode?.placeholderNode
                searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated, completion: { [weak self, weak searchDisplayController] in
                    guard let self, let searchDisplayController else {
                        return
                    }
                    if self.disappearingSearchDisplayController === searchDisplayController {
                        self.disappearingSearchDisplayController = nil
                        self.searchOverlayNode.view.isUserInteractionEnabled = false
                    }
                })
            }
            self.state?.updated(transition: .spring(duration: 0.4))
        }

        private func removePeer(_ peerId: EnginePeer.Id) {
            guard let component = self.component, self.isAdmin, self.removingPeerId == nil else {
                return
            }
            self.removingPeerId = peerId
            self.state?.updated(transition: .immediate)

            self.removePeerDisposable.set((component.context.engine.peers.toggleCommunityPeerLink(
                communityId: component.communityId,
                peerId: peerId,
                action: .unlink
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.removingPeerId = nil
                self.state?.updated(transition: .spring(duration: 0.35))
                self.presentError()
            }, completed: { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                self.removingPeerId = nil
                if let cachedData = self.cachedData {
                    self.cachedData = cachedData.withUpdatedLinkedPeers(cachedData.linkedPeers.filter { $0.peerId != peerId })
                }
                self.peers.removeValue(forKey: peerId)
                self.cachedPeerData.removeValue(forKey: peerId)
                self.previews.removeValue(forKey: peerId)
                self.joinedPeerIds.remove(peerId)
                self.currentLinkedPeerIds.removeAll(where: { $0 == peerId })

                let _ = component.context.account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([component.communityId]), update: { _, current in
                        guard let current = current as? CachedCommunityData else {
                            return current
                        }
                        return current.withUpdatedLinkedPeers(current.linkedPeers.filter { $0.peerId != peerId })
                    })
                }.startStandalone()

                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func setPendingRequestApproval(request: CommunityPeerRequest, approve: Bool) {
            guard let pendingRequestsContext = self.pendingRequestsContext else {
                return
            }
            pendingRequestsContext.update(request, action: approve ? .approve : .deny)
        }

        private func toggleCollapsed(_ collapsed: Bool) {
            guard let component = self.component else {
                return
            }
            self.state?.updated(transition: .spring(duration: 0.35))

            self.actionDisposable.set((component.context.engine.peers.toggleCommunityCollapsedInDialogs(
                communityId: component.communityId,
                collapsed: collapsed
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.state?.updated(transition: .spring(duration: 0.35))
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func openAddChat() {
            guard let component = self.component, let environment = self.environment, !self.isAddActionInProgress else {
                return
            }

            let excludedPeerIds = Set((self.cachedData?.linkedPeers ?? []).map(\.peerId))
            let selectionController = component.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
                context: component.context,
                filter: [.excludeRecent, .doNotSearchMessages],
                requestPeerType: [.group(.init(isCreator: true, hasUsername: nil, isForum: nil, botParticipant: false, userAdminRights: nil, botAdminRights: nil))],
                showPeerTypeRequirements: false,
                hasContactSelector: false,
                hasGlobalSearch: true,
                title: "Add a Chat",
                excludedPeerIds: excludedPeerIds
            ))
            selectionController.peerSelected = { [weak self, weak selectionController] peer, _ in
                guard let self, let component = self.component, !self.isAddActionInProgress else {
                    return
                }
                let controller = component.context.sharedContext.makeCommunityAddScreen(
                    context: component.context,
                    communityId: component.communityId,
                    peerId: peer.id,
                    completed: { [weak self, weak selectionController] in
                        guard let self, let component = self.component else {
                            return
                        }
                        selectionController?.dismiss()
                        component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
                        self.updateJoinedChatsSignal(component: component, force: true)
                        self.state?.updated(transition: .spring(duration: 0.35))
                    }
                )
                if let selectionController {
                    selectionController.present(controller, in: .window(.root))
                } else {
                    environment.controller()?.present(controller, in: .window(.root))
                }
            }
            environment.controller()?.push(selectionController)
        }

        private func containerLayout(availableSize: CGSize, environment: EnvironmentType, presentation: CommunityViewScreenPresentation, safeInsets: UIEdgeInsets? = nil) -> ContainerViewLayout {
            let effectiveSafeInsets = safeInsets ?? environment.safeInsets
            return ContainerViewLayout(
                size: availableSize,
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: effectiveSafeInsets.bottom, right: 0.0),
                safeInsets: effectiveSafeInsets,
                additionalInsets: environment.additionalInsets,
                statusBarHeight: presentation == .fullScreen ? environment.statusBarHeight : 0.0,
                inputHeight: environment.inputHeight > 0.0 ? environment.inputHeight : nil,
                inputHeightIsInteractivellyChanging: false,
                inVoiceOver: false
            )
        }

        private func sheetMetrics(availableSize: CGSize, environment: EnvironmentType) -> (fillingSize: CGFloat, rawSideInset: CGFloat) {
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }

            return (fillingSize, floor((availableSize.width - fillingSize) * 0.5))
        }

        private func updateNavigationBar(component: CommunityViewScreenComponent, availableSize: CGSize, statusBarHeight: CGFloat, sideInset: CGFloat, environment: EnvironmentType, transition: ComponentTransition) -> CGSize {
            let theme: PresentationTheme
            switch component.style {
            case .grouped:
                theme = environment.theme.withModalBlocksBackground()
            case .plain:
                theme = environment.theme
            }

            let title = self.community?.title ?? "Community"
            let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment>?
            let backPressed: (() -> Void)?
            let navigationBackTitle: String?
            switch component.presentation {
            case .sheet:
                leftButton = AnyComponentWithIdentity(id: "close", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Navigation/Close"),
                    pressed: { [weak self] _ in
                        self?.dismiss(animated: true)
                    }
                )))
                backPressed = nil
                navigationBackTitle = nil
            case .fullScreen:
                leftButton = nil
                backPressed = { [weak self] in
                    self?.dismiss(animated: true)
                }
                navigationBackTitle = environment.strings.Common_Back
            }

            var rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = []
            if self.isAdmin {
                rightButtons.append(AnyComponentWithIdentity(id: "settings", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Media Editor/Adjustments"),
                    pressed: { [weak self] _ in
                        self?.openEdit()
                    }
                ))))
            }

            let primaryContent = ChatListHeaderComponent.Content(
                title: title,
                navigationBackTitle: navigationBackTitle,
                titleComponent: nil,
                chatListTitle: NetworkStatusTitle(text: title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false, peerStatus: nil),
                leftButton: leftButton,
                rightButtons: rightButtons,
                backPressed: backPressed
            )

            let navigationBarSize = self.navigationBarView.update(
                transition: transition,
                component: AnyComponent(ChatListNavigationBar(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    statusBarHeight: statusBarHeight,
                    sideInset: sideInset,
                    search: ChatListNavigationBar.Search(isEnabled: true),
                    activeSearch: self.isSearchDisplayControllerActive,
                    primaryContent: primaryContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    storySubscriptions: nil,
                    storiesIncludeHidden: true,
                    uploadProgress: [:],
                    headerPanels: nil,
                    tabsNode: nil,
                    tabsNodeIsSearch: false,
                    accessoryPanelContainer: nil,
                    accessoryPanelContainerHeight: 0.0,
                    hasEdgeEffect: component.style == .plain,
                    activateSearch: { [weak self] searchContentNode in
                        self?.activateSearch(searchContentNode: searchContentNode)
                    },
                    openStatusSetup: { _ in
                    },
                    allowAutomaticOrder: {
                    }
                )),
                environment: {},
                containerSize: availableSize
            )

            return navigationBarSize
        }

        private func currentSheetNavigationBarFrame(bounds: CGRect?) -> CGRect? {
            if self.sheetNavigationFrame.size.width <= 0.0 || self.sheetNavigationFrame.size.height <= 0.0 {
                return nil
            }

            var frame = self.sheetNavigationFrame
            if let bounds {
                let topOffset = max(0.0, -bounds.minY + self.sheetTopInset)
                frame.origin.y = topOffset + self.sheetContainerInset + self.sheetNavigationTopInset
            }

            return frame
        }

        private func sheetSearchOverlayFrame(navigationBarFrame: CGRect, availableSize: CGSize) -> CGRect {
            return CGRect(
                origin: navigationBarFrame.origin,
                size: CGSize(width: navigationBarFrame.width, height: max(1.0, availableSize.height - navigationBarFrame.minY))
            )
        }

        private func updateSearchDisplayControllers(containerLayout: ContainerViewLayout, navigationHeight: CGFloat, transition: ComponentTransition) {
            self.validLayout = (containerLayout, navigationHeight)
            if let searchDisplayController = self.searchDisplayController {
                searchDisplayController.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationHeight, transition: transition.containedViewLayoutTransition)
            }
            if let disappearingSearchDisplayController = self.disappearingSearchDisplayController {
                disappearingSearchDisplayController.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationHeight, transition: transition.containedViewLayoutTransition)
            }
        }

        private func updateSheetNavigationBarFrame(bounds: CGRect?, transition: ComponentTransition) {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View, let frame = self.currentSheetNavigationBarFrame(bounds: bounds) else {
                return
            }

            transition.setFrame(view: navigationBarComponentView, frame: frame)
            navigationBarComponentView.applyScroll(offset: 0.0, allowAvatarsExpansion: false, transition: transition)

            if self.searchOverlayNode.view.superview === navigationBarComponentView.superview, let component = self.component, let environment = self.environment, component.presentation == .sheet {
                let overlayFrame = self.sheetSearchOverlayFrame(navigationBarFrame: frame, availableSize: self.currentAvailableSize)
                self.searchOverlayNode.frame = overlayFrame
                transition.setFrame(view: self.searchOverlayNode.view, frame: overlayFrame)

                let containerLayout = self.containerLayout(
                    availableSize: overlayFrame.size,
                    environment: environment,
                    presentation: .sheet,
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
                )
                self.updateSearchDisplayControllers(containerLayout: containerLayout, navigationHeight: frame.height, transition: transition)
            }
        }

        private func placeSearchOverlay(in superview: UIView, frame: CGRect, transition: ComponentTransition) {
            self.searchOverlayNode.frame = frame
            if self.searchOverlayNode.view.superview !== superview {
                self.searchOverlayNode.view.removeFromSuperview()
                superview.addSubview(self.searchOverlayNode.view)
            }
            transition.setFrame(view: self.searchOverlayNode.view, frame: frame)
            self.searchOverlayNode.view.isUserInteractionEnabled = self.searchDisplayController != nil || self.disappearingSearchDisplayController != nil
        }

        private func placeFullscreenNavigationBar(navigationBarSize: CGSize, transition: ComponentTransition) {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                return
            }
            if navigationBarComponentView.superview !== self {
                navigationBarComponentView.removeFromSuperview()
                self.addSubview(navigationBarComponentView)
            }

            self.sheetNavigationFrame = .zero
            transition.setFrame(view: navigationBarComponentView, frame: CGRect(origin: .zero, size: navigationBarSize))
            navigationBarComponentView.applyScroll(offset: 0.0, allowAvatarsExpansion: false, transition: transition)
        }

        private func placeSheetNavigationBar(sheetView: ResizableSheetComponent<EnvironmentType>.View, availableSize: CGSize, navigationBarSize: CGSize, sheetMetrics: (fillingSize: CGFloat, rawSideInset: CGFloat), environment: EnvironmentType, transition: ComponentTransition) -> CGRect? {
            guard let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                return nil
            }
            if navigationBarComponentView.superview !== sheetView.containerView {
                navigationBarComponentView.removeFromSuperview()
                sheetView.containerView.addSubview(navigationBarComponentView)
            }

            let containerInset = environment.statusBarHeight + 10.0
            let defaultHeight: CGFloat = self.isAdmin ? 620.0 : 700.0
            let contentHeight = self.sheetExternalState.contentHeight
            let initialContentHeight = min(contentHeight, max(0.0, defaultHeight))
            let topInset = max(0.0, availableSize.height - containerInset - initialContentHeight)

            self.sheetTopInset = topInset
            self.sheetContainerInset = containerInset
            self.sheetNavigationFrame = CGRect(
                origin: CGPoint(x: sheetMetrics.rawSideInset, y: topInset + containerInset + self.sheetNavigationTopInset),
                size: navigationBarSize
            )

            self.updateSheetNavigationBarFrame(bounds: self.currentSheetBounds, transition: transition)
            sheetView.containerView.bringSubviewToFront(navigationBarComponentView)
            return self.currentSheetNavigationBarFrame(bounds: self.currentSheetBounds)
        }

        private func makeContentComponent(component: CommunityViewScreenComponent, topInset: CGFloat) -> CommunityViewContentComponent {
            return CommunityViewContentComponent(
                context: component.context,
                communityId: component.communityId,
                style: component.style,
                presentation: component.presentation,
                topInset: topInset,
                community: self.community,
                cachedData: self.cachedData,
                peers: self.peers,
                cachedPeerData: self.cachedPeerData,
                previews: self.previews,
                pendingRequests: self.pendingRequests,
                pendingRequestCachedPeerData: self.pendingRequestCachedPeerData,
                pendingRequestInFlightPeerId: nil,
                pendingRequestInFlightApprove: nil,
                joinedPeerIds: self.joinedPeerIds,
                toggleCollapsed: { [weak self] value in
                    self?.toggleCollapsed(value)
                },
                setRequestApproval: { [weak self] request, approve in
                    self?.setPendingRequestApproval(request: request, approve: approve)
                },
                openPeer: { [weak self] peer in
                    self?.openPeer(peer)
                },
                openPendingRequests: { [weak self] in
                    self?.openPendingRequests()
                },
                removePeer: { [weak self] peerId in
                    self?.removePeer(peerId)
                }
            )
        }

        private func makeBottomButtonComponent(theme: PresentationTheme, safeInsets: UIEdgeInsets) -> CommunityViewBottomButtonComponent {
            return CommunityViewBottomButtonComponent(
                theme: theme,
                title: self.isAdmin ? "Add a Chat to Community" : "OK",
                iconName: self.isAdmin ? "Item List/Icons/Add" : nil,
                safeInsets: safeInsets,
                isEnabled: !self.isAddActionInProgress,
                displaysProgress: self.isAddActionInProgress,
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.isAdmin {
                        self.openAddChat()
                    } else {
                        self.dismiss(animated: true)
                    }
                }
            )
        }

        func update(component: CommunityViewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.currentAvailableSize = availableSize

            self.ensureDataSignal(component: component)

            let currentSheetMetrics = self.sheetMetrics(availableSize: availableSize, environment: environment)
            let navigationAvailableSize: CGSize
            let navigationStatusBarHeight: CGFloat
            let navigationSideInset: CGFloat
            switch component.presentation {
            case .sheet:
                navigationAvailableSize = CGSize(width: currentSheetMetrics.fillingSize, height: availableSize.height)
                navigationStatusBarHeight = 0.0
                navigationSideInset = 0.0
            case .fullScreen:
                navigationAvailableSize = availableSize
                navigationStatusBarHeight = environment.statusBarHeight
                navigationSideInset = environment.safeInsets.left
            }

            let navigationBarSize = self.updateNavigationBar(
                component: component,
                availableSize: navigationAvailableSize,
                statusBarHeight: navigationStatusBarHeight,
                sideInset: navigationSideInset,
                environment: environment,
                transition: transition
            )
            let navigationHeight = navigationBarSize.height
            if self.isSearchDisplayControllerActive == nil {
                self.lastInactiveNavigationHeight = navigationHeight
            }
            let contentNavigationHeight = self.lastInactiveNavigationHeight ?? navigationHeight

            switch component.presentation {
            case .sheet:
                self.scrollView.removeFromSuperview()
                self.fullscreenContent.view?.removeFromSuperview()
                self.fullscreenBottomItem.view?.removeFromSuperview()

                let theme = environment.theme.withModalBlocksBackground()
                let contentTopInset = contentNavigationHeight + self.sheetNavigationTopInset
                let sheetSize = self.sheet.update(
                    transition: transition,
                    component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                        content: AnyComponent<EnvironmentType>(self.makeContentComponent(component: component, topInset: contentTopInset)),
                        hasTopEdgeEffect: false,
                        bottomItem: AnyComponent(self.makeBottomButtonComponent(theme: theme, safeInsets: environment.safeInsets)),
                        backgroundColor: .color(theme.list.modalBlocksBackgroundColor),
                        defaultHeight: self.isAdmin ? 620.0 : 700.0,
                        externalState: self.sheetExternalState,
                        animateOut: self.animateOut
                    )),
                    environment: {
                        environment
                        ResizableSheetComponentEnvironment(
                            theme: theme,
                            statusBarHeight: environment.statusBarHeight,
                            safeInsets: environment.safeInsets,
                            inputHeight: 0.0,
                            metrics: environment.metrics,
                            deviceMetrics: environment.deviceMetrics,
                            isDisplaying: environment.isVisible,
                            isCentered: environment.metrics.widthClass == .regular,
                            screenSize: availableSize,
                            regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                            dismiss: { [weak self] animated in
                                self?.dismiss(animated: animated)
                            },
                            boundsUpdated: self.sheetBoundsUpdated
                        )
                    },
                    containerSize: availableSize
                )
                if let sheetView = self.sheet.view {
                    if sheetView.superview == nil {
                        self.addSubview(sheetView)
                    }
                    transition.setFrame(view: sheetView, frame: CGRect(origin: .zero, size: sheetSize))
                }
                if let sheetView = self.sheet.view as? ResizableSheetComponent<EnvironmentType>.View {
                    let navigationBarFrame = self.placeSheetNavigationBar(
                        sheetView: sheetView,
                        availableSize: availableSize,
                        navigationBarSize: navigationBarSize,
                        sheetMetrics: currentSheetMetrics,
                        environment: environment,
                        transition: transition
                    )
                    if let navigationBarFrame {
                        let searchOverlayFrame = self.sheetSearchOverlayFrame(navigationBarFrame: navigationBarFrame, availableSize: availableSize)
                        self.placeSearchOverlay(in: sheetView.containerView, frame: searchOverlayFrame, transition: transition)

                        let searchContainerLayout = self.containerLayout(
                            availableSize: searchOverlayFrame.size,
                            environment: environment,
                            presentation: component.presentation,
                            safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
                        )
                        self.updateSearchDisplayControllers(containerLayout: searchContainerLayout, navigationHeight: navigationHeight, transition: transition)

                        sheetView.containerView.bringSubviewToFront(self.searchOverlayNode.view)
                        if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                            sheetView.containerView.bringSubviewToFront(navigationBarComponentView)
                        }
                    }
                }
            case .fullScreen:
                self.sheet.view?.removeFromSuperview()
                self.currentSheetBounds = nil
                self.placeSearchOverlay(in: self, frame: CGRect(origin: .zero, size: availableSize), transition: transition)
                self.placeFullscreenNavigationBar(navigationBarSize: navigationBarSize, transition: transition)

                let searchContainerLayout = self.containerLayout(availableSize: availableSize, environment: environment, presentation: component.presentation)
                self.updateSearchDisplayControllers(containerLayout: searchContainerLayout, navigationHeight: navigationHeight, transition: transition)

                let theme = environment.theme
                self.backgroundColor = theme.chatList.backgroundColor

                let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                let bottomPanelHeight = 52.0 + buttonInsets.bottom
                let bottomPanelWidth = max(1.0, availableSize.width - environment.safeInsets.left * 2.0 - buttonInsets.left - buttonInsets.right)
                let bottomSize = self.fullscreenBottomItem.update(
                    transition: transition,
                    component: AnyComponent(self.makeBottomButtonComponent(theme: theme, safeInsets: UIEdgeInsets())),
                    environment: {},
                    containerSize: CGSize(width: bottomPanelWidth, height: 52.0)
                )
                let bottomFrame = CGRect(
                    origin: CGPoint(
                        x: environment.safeInsets.left + buttonInsets.left,
                        y: availableSize.height - bottomPanelHeight
                    ),
                    size: bottomSize
                )
                if let bottomView = self.fullscreenBottomItem.view {
                    if bottomView.superview == nil {
                        self.addSubview(bottomView)
                    }
                    transition.setFrame(view: bottomView, frame: bottomFrame)
                }

                if self.scrollView.superview == nil {
                    if let bottomView = self.fullscreenBottomItem.view {
                        self.insertSubview(self.scrollView, belowSubview: bottomView)
                    } else {
                        self.addSubview(self.scrollView)
                    }
                }
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: availableSize))

                let contentSize = self.fullscreenContent.update(
                    transition: transition,
                    component: AnyComponent(self.makeContentComponent(component: component, topInset: contentNavigationHeight)),
                    environment: {
                        environment
                    },
                    containerSize: CGSize(width: availableSize.width, height: 10000.0)
                )
                if let contentView = self.fullscreenContent.view {
                    if contentView.superview == nil {
                        self.scrollView.addSubview(contentView)
                    }
                    transition.setFrame(view: contentView, frame: CGRect(origin: .zero, size: contentSize))
                }

                let scrollInsets = UIEdgeInsets(top: contentNavigationHeight, left: 0.0, bottom: availableSize.height - bottomFrame.minY + 8.0, right: 0.0)
                if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                    self.scrollView.verticalScrollIndicatorInsets = scrollInsets
                }
                let scrollContentSize = CGSize(width: availableSize.width, height: contentSize.height)
                if self.scrollView.contentSize != scrollContentSize {
                    self.scrollView.contentSize = scrollContentSize
                }
                self.bringSubviewToFront(self.searchOverlayNode.view)
                if let navigationBarComponentView = self.navigationBarView.view as? ChatListNavigationBar.View {
                    self.bringSubviewToFront(navigationBarComponentView)
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityViewScreen: ViewControllerComponentContainer {
    public convenience init(context: AccountContext, communityId: EnginePeer.Id) {
        self.init(context: context, communityId: communityId, style: .grouped, presentation: .sheet)
    }

    public init(context: AccountContext, communityId: EnginePeer.Id, style: CommunityViewScreenStyle, presentation: CommunityViewScreenPresentation) {
        super.init(
            context: context,
            component: CommunityViewScreenComponent(context: context, communityId: communityId, style: style, presentation: presentation),
            navigationBarAppearance: .none,
            theme: .default,
            updatedPresentationData: nil
        )

        switch presentation {
        case .sheet:
            self.statusBar.statusBarStyle = .Ignore
            self.navigationPresentation = .flatModal
            self.blocksBackgroundWhenInOverlay = true
        case .fullScreen:
            self.statusBar.statusBarStyle = .Ignore
            self.navigationPresentation = .default
            self.blocksBackgroundWhenInOverlay = false
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if self.navigationPresentation == .flatModal {
            self.view.disablesInteractiveModalDismiss = true
        }
    }

    public func dismissAnimated() {
        guard self.navigationPresentation == .flatModal else {
            self.dismiss(completion: nil)
            return
        }
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
