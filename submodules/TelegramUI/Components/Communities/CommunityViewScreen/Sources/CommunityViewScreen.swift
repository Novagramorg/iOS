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
import GlassControls
import ResizableSheetComponent
import ListActionItemComponent
import ListSectionComponent
import ListItemComponentAdaptor
import PeerListItemComponent
import AlertComponent
import AlertUI
import SearchBarNode
import ChatListUI
import ItemListUI
import CommunityAdminApprovalScreen
import CommunityPrivateChatScreen

private struct CommunityChatPreviewData: Equatable {
    var messages: [EngineMessage]
    var readCounters: EnginePeerReadCounters
    
    var timestamp: Int32 {
        return self.messages.first?.timestamp ?? 0
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
            communityViewHasNext: self.hasNext
        )
    }
}

private final class CommunitySearchBarComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let query: String
    let queryUpdated: (String) -> Void
    let cancel: () -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        query: String,
        queryUpdated: @escaping (String) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.query = query
        self.queryUpdated = queryUpdated
        self.cancel = cancel
    }
    
    static func ==(lhs: CommunitySearchBarComponent, rhs: CommunitySearchBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.query != rhs.query {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var searchBarNode: SearchBarNode?
        private var didActivate = false
        private var component: CommunitySearchBarComponent?
        
        deinit {
            self.searchBarNode?.removeFromSupernode()
        }
        
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            
            if self.superview == nil {
                self.didActivate = false
            }
        }
        
        func update(component: CommunitySearchBarComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            let stringsUpdated = self.component?.strings !== component.strings
            self.component = component
            
            let searchBarNode: SearchBarNode
            if let current = self.searchBarNode {
                searchBarNode = current
            } else {
                let searchBarTheme = SearchBarNodeTheme(theme: component.theme, hasSeparator: false)
                searchBarNode = SearchBarNode(
                    theme: searchBarTheme,
                    presentationTheme: component.theme,
                    strings: component.strings,
                    fieldStyle: .glass,
                    displayBackground: false
                )
                searchBarNode.placeholderString = NSAttributedString(
                    string: component.strings.Common_Search,
                    font: Font.regular(17.0),
                    textColor: searchBarTheme.placeholder
                )
                searchBarNode.cancel = { [weak self] in
                    self?.component?.cancel()
                }
                searchBarNode.textUpdated = { [weak self] value, _ in
                    self?.component?.queryUpdated(value)
                }
                self.searchBarNode = searchBarNode
                self.addSubview(searchBarNode.view)
            }
            
            if themeUpdated || stringsUpdated {
                let searchBarTheme = SearchBarNodeTheme(theme: component.theme, hasSeparator: false)
                searchBarNode.updateThemeAndStrings(
                    theme: searchBarTheme,
                    presentationTheme: component.theme,
                    strings: component.strings
                )
                searchBarNode.placeholderString = NSAttributedString(
                    string: component.strings.Common_Search,
                    font: Font.regular(17.0),
                    textColor: searchBarTheme.placeholder
                )
            }
            
            if searchBarNode.text != component.query {
                searchBarNode.text = component.query
            }
            
            let size = CGSize(width: availableSize.width, height: 54.0)
            searchBarNode.updateLayout(
                boundingSize: size,
                leftInset: 0.0,
                rightInset: 0.0,
                transition: transition.containedViewLayoutTransition
            )
            transition.setFrame(view: searchBarNode.view, frame: CGRect(origin: .zero, size: size))
            
            if !self.didActivate {
                self.didActivate = true
                Queue.mainQueue().after(0.05) { [weak searchBarNode] in
                    searchBarNode?.activate()
                }
            }
            
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
    let isSearchActive: Bool
    let searchQuery: String
    let toggleCollapsed: (Bool) -> Void
    let setRequestApproval: (CommunityPeerRequest, Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openPendingRequests: () -> Void
    let dismiss: () -> Void
    let openEdit: () -> Void
    let activateSearch: () -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let searchQueryUpdated: (String) -> Void
    let cancelSearch: () -> Void
    
    init(
        context: AccountContext,
        communityId: EnginePeer.Id,
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
        isSearchActive: Bool,
        searchQuery: String,
        toggleCollapsed: @escaping (Bool) -> Void,
        setRequestApproval: @escaping (CommunityPeerRequest, Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openPendingRequests: @escaping () -> Void,
        dismiss: @escaping () -> Void,
        openEdit: @escaping () -> Void,
        activateSearch: @escaping () -> Void,
        removePeer: @escaping (EnginePeer.Id) -> Void,
        searchQueryUpdated: @escaping (String) -> Void,
        cancelSearch: @escaping () -> Void
    ) {
        self.context = context
        self.communityId = communityId
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
        self.isSearchActive = isSearchActive
        self.searchQuery = searchQuery
        self.toggleCollapsed = toggleCollapsed
        self.setRequestApproval = setRequestApproval
        self.openPeer = openPeer
        self.openPendingRequests = openPendingRequests
        self.dismiss = dismiss
        self.openEdit = openEdit
        self.activateSearch = activateSearch
        self.removePeer = removePeer
        self.searchQueryUpdated = searchQueryUpdated
        self.cancelSearch = cancelSearch
    }
    
    static func ==(lhs: CommunityViewContentComponent, rhs: CommunityViewContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
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
        if lhs.isSearchActive != rhs.isSearchActive {
            return false
        }
        if lhs.searchQuery != rhs.searchQuery {
            return false
        }
        return true
    }
        
    final class View: UIView {
        private let headerControls = ComponentView<Empty>()
        private let headerTitle = ComponentView<Empty>()
        private let headerSearch = ComponentView<Empty>()
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
            
            let query = component.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !query.isEmpty {
                result = result.filter { row in
                    if row.peer.compactDisplayTitle.lowercased().contains(query) {
                        return true
                    }
                    if component.previews[row.peer.id]?.searchText.lowercased().contains(query) == true {
                        return true
                    }
                    return false
                }
            }
            
            return result
        }
        
        private func memberCountString(component: CommunityViewContentComponent, peerId: EnginePeer.Id) -> String? {
            guard let count = communityCachedMemberCounts(component.cachedPeerData)[peerId] else {
                return nil
            }
            if count > 0 {
                return "\(count) members"
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
                            background: theme.list.itemBlocksBackgroundColor
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
                    style: .glass,
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
                    style: .glass,
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
                    style: .glass,
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
            
            let theme = environment.theme.withModalBlocksBackground()
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sideInset: CGFloat = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let sectionSpacing: CGFloat = 28.0
            let contentWidth = availableSize.width - sideInset * 2.0
            
            self.backgroundColor = .clear
            
            let isAdmin = component.community?.hasPermission(.manageLinkedPeers) == true
            var rightItems: [GlassControlGroupComponent.Item] = []
            if isAdmin {
                rightItems.append(GlassControlGroupComponent.Item(
                    id: AnyHashable("settings"),
                    content: .icon("Media Editor/Adjustments"),
                    action: {
                        component.openEdit()
                    }
                ))
            }
            rightItems.append(GlassControlGroupComponent.Item(
                id: AnyHashable("search"),
                content: .icon("Navigation/Search"),
                action: {
                    component.activateSearch()
                }
            ))
            
            var contentHeight: CGFloat = 16.0
            let headerControlsY = contentHeight
            let headerControlsSize = self.headerControls.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [
                            GlassControlGroupComponent.Item(
                                id: AnyHashable("close"),
                                content: .icon("Navigation/Close"),
                                action: {
                                    component.dismiss()
                                }
                            )
                        ],
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: rightItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                        items: rightItems,
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 44.0)
            )
            if let headerControlsView = self.headerControls.view {
                if headerControlsView.superview == nil {
                    self.addSubview(headerControlsView)
                }
                transition.setFrame(view: headerControlsView, frame: CGRect(
                    origin: CGPoint(x: sideInset, y: headerControlsY),
                    size: headerControlsSize
                ))
            }
                        
            if component.isSearchActive {
                let searchLeftInset: CGFloat = sideInset + 56.0
                let searchWidth = max(1.0, availableSize.width - searchLeftInset - sideInset)
                let searchSize = self.headerSearch.update(
                    transition: transition,
                    component: AnyComponent(CommunitySearchBarComponent(
                        theme: theme,
                        strings: environment.strings,
                        query: component.searchQuery,
                        queryUpdated: { value in
                            component.searchQueryUpdated(value)
                        },
                        cancel: {
                            component.cancelSearch()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: searchWidth, height: 44.0)
                )
                if let searchView = self.headerSearch.view {
                    if searchView.superview == nil {
                        self.addSubview(searchView)
                    }
                    transition.setFrame(view: searchView, frame: CGRect(
                        origin: CGPoint(x: searchLeftInset, y: headerControlsY - 5.0),
                        size: searchSize
                    ))
                    transition.setAlpha(view: searchView, alpha: 1.0)
                    self.bringSubviewToFront(searchView)
                }
                if let titleView = self.headerTitle.view {
                    transition.setAlpha(view: titleView, alpha: 0.0, completion: { [weak titleView] _ in
                        titleView?.removeFromSuperview()
                    })
                }
            } else {
                let titleSize = self.headerTitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.community?.title ?? "Community",
                            font: Font.semibold(17.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, contentWidth - 160.0), height: 44.0)
                )
                if let titleView = self.headerTitle.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: CGRect(
                        origin: CGPoint(
                            x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                            y: headerControlsY + floorToScreenPixels((44.0 - titleSize.height) / 2.0)
                        ),
                        size: titleSize
                    ))
                    transition.setAlpha(view: titleView, alpha: 1.0)
                    self.bringSubviewToFront(titleView)
                }
                if let searchView = self.headerSearch.view {
                    transition.setAlpha(view: searchView, alpha: 0.0, completion: { [weak searchView] _ in
                        searchView?.removeFromSuperview()
                    })
                }
            }
            contentHeight += 44.0 + 36.0
            
            let collapseSectionSize = self.collapseSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "collapse", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
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

            if isAdmin, let pendingRequestsSectionSize = self.updatePendingRequestsSection(
                component: component,
                theme: theme,
                presentationData: presentationData,
                availableWidth: contentWidth,
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
    
    init(context: AccountContext, communityId: EnginePeer.Id) {
        self.context = context
        self.communityId = communityId
    }
    
    static func ==(lhs: CommunityViewScreenComponent, rhs: CommunityViewScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(EnvironmentType, ResizableSheetComponentEnvironment)>()
        private let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()
        private let animateOut = ActionSlot<Action<()>>()
        
        private var component: CommunityViewScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var community: TelegramCommunity?
        private var cachedData: CachedCommunityData?
        private var peers: [EnginePeer.Id: EnginePeer] = [:]
        private var cachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var previews: [EnginePeer.Id: CommunityChatPreviewData] = [:]
        private var pendingRequests: CommunityPeerLinkRequests?
        private var pendingRequestsContext: CommunityPeerLinkRequestsContext?
        private var pendingRequestCachedPeerData: [EnginePeer.Id: CachedPeerData] = [:]
        private var joinedPeerIds = Set<EnginePeer.Id>()
        
        private var isSearchActive = false
        private var searchQuery = ""
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
        private let pendingRequestsDisposable = MetaDisposable()
        private let pendingRequestCachedDataDisposable = MetaDisposable()
        private var currentLinkedPeerIds: [EnginePeer.Id] = []
        private var currentPendingRequestsCount: Int32?
        private var currentPendingRequestCachedPeerIds: [EnginePeer.Id] = []
        private var requestedPendingRequestCachedPeerIds = Set<EnginePeer.Id>()
        
        deinit {
            self.dataDisposable?.dispose()
            self.linkedPeersDisposable.dispose()
            self.linkedPeerDataDisposable.dispose()
            self.previewsDisposable.dispose()
            self.joinedChatsDisposable.dispose()
            self.actionDisposable.dispose()
            self.removePeerDisposable.dispose()
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

        func update(component: CommunityViewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            self.ensureDataSignal(component: component)
            
            let theme = environment.theme.withModalBlocksBackground()
            
            let sheetSize = self.sheet.update(
                transition: transition,
                component: AnyComponent(ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(CommunityViewContentComponent(
                        context: component.context,
                        communityId: component.communityId,
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
                        isSearchActive: self.isSearchActive,
                        searchQuery: self.searchQuery,
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
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        },
                        openEdit: { [weak self] in
                            self?.openEdit()
                        },
                        activateSearch: { [weak self] in
                            guard let self else {
                                return
                            }
                            guard let community = self.community, let controller = self.environment?.controller else {
                                return
                            }
                            controller()?.present(CommunityAdminApprovalScreen(
                                context: component.context,
                                community: EnginePeer(community)
                            ), in: .window(.root))
                        },
                        removePeer: { [weak self] peerId in
                            self?.removePeer(peerId)
                        },
                        searchQueryUpdated: { [weak self] value in
                            guard let self else {
                                return
                            }
                            self.searchQuery = value
                            self.state?.updated(transition: .immediate)
                        },
                        cancelSearch: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.isSearchActive = false
                            self.searchQuery = ""
                            self.state?.updated(transition: .spring(duration: 0.35))
                        }
                    )),
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(CommunityViewBottomButtonComponent(
                        theme: theme,
                        title: self.isAdmin ? "Add a Chat to Community" : "OK",
                        iconName: self.isAdmin ? "Item List/Icons/Add" : nil,
                        safeInsets: environment.safeInsets,
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
                    )),
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
                        }
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
    public init(context: AccountContext, communityId: EnginePeer.Id) {
        super.init(
            context: context,
            component: CommunityViewScreenComponent(context: context, communityId: communityId),
            navigationBarAppearance: .none,
            theme: .default,
            updatedPresentationData: nil
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
