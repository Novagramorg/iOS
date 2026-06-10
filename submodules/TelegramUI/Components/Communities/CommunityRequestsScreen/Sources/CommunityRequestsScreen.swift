import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import Markdown
import ListSectionComponent
import PeerListItemComponent
import AlertComponent
import ButtonComponent
import EdgeEffect
import CommunityEditScreen
import CommunityPrivateChatScreen

private struct CommunityRequestRow: Equatable {
    let request: CommunityPeerRequest
    let peer: EnginePeer
    let requestedBy: EnginePeer?
    let memberCount: Int32?
    let isPrivate: Bool
    let isVisible: Bool
}

private final class CommunityRequestsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id

    init(context: AccountContext, communityId: EnginePeer.Id) {
        self.context = context
        self.communityId = communityId
    }

    static func ==(lhs: CommunityRequestsScreenComponent, rhs: CommunityRequestsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.communityId != rhs.communityId {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        private let approvalInfoText = ComponentView<Empty>()
        private let requestsSection = ComponentView<Empty>()
        private let emptyText = ComponentView<Empty>()
        private let declineAllButton = ComponentView<Empty>()
        private let addAllButton = ComponentView<Empty>()
        private let bottomEdgeEffectView = EdgeEffectView()

        private var component: CommunityRequestsScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var ignoreScrolling = false

        private var community: TelegramCommunity?
        private var requests: [CommunityPeerRequest]?
        private var peers: [EnginePeer.Id: EnginePeer] = [:]
        private var cachedPeerData: [EnginePeer.Id: EngineCachedPeerData] = [:]
        private var inFlightPeerActions: [EnginePeer.Id: Bool] = [:]
        private var bulkAction: Bool?
        private var cachedChevronImage: (UIImage, PresentationTheme)?

        private var communityDisposable: Disposable?
        private var loadDisposable: Disposable?
        private var cachedDataDisposable: Disposable?
        private var cachedDataPeerIds = Set<EnginePeer.Id>()
        private var requestedCachedPeerIds = Set<EnginePeer.Id>()
        private var bulkActionDisposable = MetaDisposable()
        private var actionDisposables: [EnginePeer.Id: Disposable] = [:]

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)

            self.bottomEdgeEffectView.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.communityDisposable?.dispose()
            self.loadDisposable?.dispose()
            self.cachedDataDisposable?.dispose()
            self.bulkActionDisposable.dispose()
            for (_, disposable) in self.actionDisposables {
                disposable.dispose()
            }
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let navigationBar = controller.navigationBar, let edgeEffectView = navigationBar.edgeEffectView else {
                return
            }
            let alphaDistance: CGFloat = 16.0
            let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / alphaDistance))
            transition.setAlpha(view: edgeEffectView, alpha: edgeEffectAlpha)
        }

        private var rows: [CommunityRequestRow] {
            guard let requests = self.requests else {
                return []
            }
            var result: [CommunityRequestRow] = []
            for request in requests {
                if let peer = self.peers[request.peerId] {
                    result.append(CommunityRequestRow(
                        request: request,
                        peer: peer,
                        requestedBy: self.peers[request.requestedBy],
                        memberCount: self.memberCount(peerId: request.peerId),
                        isPrivate: self.isPrivate(peer),
                        isVisible: request.isVisible
                    ))
                }
            }
            return result
        }

        private func memberCount(peerId: EnginePeer.Id) -> Int32? {
            guard let cachedData = self.cachedPeerData[peerId] else {
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

        private func isPrivate(_ peer: EnginePeer) -> Bool {
            if let addressName = peer.addressName, !addressName.isEmpty {
                return false
            }
            if peer.usernames.contains(where: { $0.flags.contains(.isActive) && !$0.username.isEmpty }) {
                return false
            }
            return true
        }

        private var displaysApprovalInfo: Bool {
            return self.community?.defaultBannedRights?.flags.contains(.banManageLinkedPeers) == true
        }

        private func ensureCommunitySignal(component: CommunityRequestsScreenComponent) {
            if self.communityDisposable != nil {
                return
            }
            self.communityDisposable = (component.context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.communityId)
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self else {
                    return
                }
                if let peer, case let .community(community) = peer {
                    self.community = community
                } else {
                    self.community = nil
                }
                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func ensureLoaded(component: CommunityRequestsScreenComponent) {
            if self.loadDisposable != nil {
                return
            }
            self.loadDisposable = (component.context.engine.peers.communityPeerLinkRequests(
                communityId: component.communityId,
                offset: nil,
                limit: 100
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                self.requests = result.requests
                self.peers = result.peers
                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func ensureCachedData(component: CommunityRequestsScreenComponent) {
            guard let requests = self.requests else {
                return
            }

            var orderedPeerIds: [EnginePeer.Id] = []
            var peerIds = Set<EnginePeer.Id>()
            for request in requests {
                if !peerIds.contains(request.peerId) {
                    peerIds.insert(request.peerId)
                    orderedPeerIds.append(request.peerId)
                }
            }

            if peerIds == self.cachedDataPeerIds {
                return
            }
            self.cachedDataPeerIds = peerIds

            if orderedPeerIds.isEmpty {
                self.cachedDataDisposable?.dispose()
                self.cachedDataDisposable = nil
                self.cachedPeerData = [:]
                return
            }

            for peerId in orderedPeerIds {
                if !self.requestedCachedPeerIds.contains(peerId) {
                    self.requestedCachedPeerIds.insert(peerId)
                    component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerId)
                }
            }

            self.cachedDataDisposable?.dispose()
            self.cachedDataDisposable = (component.context.engine.data.subscribe(
                EngineDataMap(orderedPeerIds.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: EngineCachedPeerData] = [:]
                for peerId in orderedPeerIds {
                    if let maybeCachedData = cachedDataById[peerId], let cachedData = maybeCachedData {
                        cachedPeerData[peerId] = cachedData
                    }
                }
                self.cachedPeerData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            })
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

        private func alertText(_ text: String, boldText: String, presentationData: PresentationData) -> NSAttributedString {
            let result = NSMutableAttributedString(string: text, font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
            if let range = text.range(of: boldText) {
                result.addAttribute(.font, value: Font.semibold(13.0), range: NSRange(range, in: text))
            }
            return result
        }

        private func openCommunitySettings() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            if let navigationController = controller.navigationController as? NavigationController {
                if let editController = navigationController.viewControllers.last(where: { $0 is CommunityEditScreen }) {
                    let _ = navigationController.popToViewController(editController, animated: true)
                } else {
                    let editController = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
                    navigationController.pushViewController(editController)
                }
            } else {
                let editController = component.context.sharedContext.makeCommunityEditScreen(context: component.context, communityId: component.communityId)
                controller.present(editController, in: .window(.root))
            }
        }

        private func presentBulkConfirmation(approve: Bool, count: Int) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            if self.bulkAction != nil {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let countText = "\(count)"
            let title: String
            let text: String
            let actionTitle: String
            let actionType: AlertScreen.Action.ActionType
            if approve {
                title = "Add All Chats"
                text = "Do you want to add \(countText) chats to the community?"
                actionTitle = "Add"
                actionType = .default
            } else {
                title = "Decline All"
                text = "Do you want to decline all \(countText) requests to join the community?"
                actionTitle = "Decline"
                actionType = .defaultDestructive
            }

            environment.controller()?.present(AlertScreen(
                context: component.context,
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(title: title))
                    ),
                    AnyComponentWithIdentity(
                        id: "text",
                        component: AnyComponent(AlertTextComponent(
                            content: .attributed(self.alertText(text, boldText: countText, presentationData: presentationData))
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_Cancel),
                    AlertScreen.Action(title: actionTitle, type: actionType, action: { [weak self] in
                        self?.performBulkApproval(approve: approve)
                    })
                ]
            ), in: .window(.root))
        }

        private func performBulkApproval(approve: Bool) {
            guard let component = self.component else {
                return
            }
            if self.bulkAction != nil {
                return
            }

            self.bulkAction = approve
            self.state?.updated(transition: .immediate)

            self.bulkActionDisposable.set((component.context.engine.peers.toggleAllCommunityPeerLinkRequestApproval(
                communityId: component.communityId,
                approve: approve
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.bulkAction = nil
                self.state?.updated(transition: .spring(duration: 0.35))
                self.presentError()
            }, completed: { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                self.bulkAction = nil
                self.requests = []
                self.inFlightPeerActions.removeAll()
                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func setRequestApproval(request: CommunityPeerRequest, approve: Bool) {
            guard let component = self.component else {
                return
            }
            if self.inFlightPeerActions[request.peerId] != nil || self.bulkAction != nil {
                return
            }
            self.inFlightPeerActions[request.peerId] = approve
            self.state?.updated(transition: .immediate)

            self.actionDisposables[request.peerId]?.dispose()
            self.actionDisposables[request.peerId] = (component.context.engine.peers.toggleCommunityPeerLinkRequestApproval(
                communityId: component.communityId,
                peerId: request.peerId,
                approve: approve
            )
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.inFlightPeerActions.removeValue(forKey: request.peerId)
                self.actionDisposables[request.peerId]?.dispose()
                self.actionDisposables.removeValue(forKey: request.peerId)
                self.state?.updated(transition: .spring(duration: 0.35))
                self.presentError()
            }, completed: { [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                self.inFlightPeerActions.removeValue(forKey: request.peerId)
                self.actionDisposables[request.peerId]?.dispose()
                self.actionDisposables.removeValue(forKey: request.peerId)
                self.requests = self.requests?.filter { $0.peerId != request.peerId }
                component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
                self.state?.updated(transition: .spring(duration: 0.35))
            })
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

        private func openRequest(row: CommunityRequestRow) {
            if !row.isPrivate {
                self.openPeer(row.peer)
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
                        self?.openPeer(requestedBy)
                    }
                }
            )
            environment.controller()?.present(controller, in: .window(.root))
        }

        private func requestItem(component: CommunityRequestsScreenComponent, row: CommunityRequestRow, hasNext: Bool, theme: PresentationTheme, presentationData: PresentationData) -> AnyComponentWithIdentity<Empty> {
            let inFlightAction = self.inFlightPeerActions[row.request.peerId]
            let isEnabled = inFlightAction == nil && self.bulkAction == nil

            return AnyComponentWithIdentity(id: row.request.peerId, component: AnyComponent(CommunityRequestItemComponent(
                context: component.context,
                theme: theme,
                strings: presentationData.strings,
                chatPeer: row.peer,
                requestedByPeer: row.requestedBy,
                memberCount: row.memberCount,
                isPrivate: row.isPrivate,
                isVisible: row.isVisible,
                isEnabled: isEnabled,
                declineDisplaysProgress: inFlightAction == false,
                addDisplaysProgress: inFlightAction == true,
                hasNext: hasNext,
                open: { [weak self] _ in
                    self?.openRequest(row: row)
                },
                add: { [weak self] _ in
                    self?.setRequestApproval(request: row.request, approve: true)
                },
                decline: { [weak self] _ in
                    self?.setRequestApproval(request: row.request, approve: false)
                }
            )))
        }

        func update(component: CommunityRequestsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment

            self.ensureCommunitySignal(component: component)
            self.ensureLoaded(component: component)
            self.ensureCachedData(component: component)

            let theme = environment.theme
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sideInset: CGFloat = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let contentWidth = availableSize.width - sideInset * 2.0

            self.backgroundColor = theme.list.blocksBackgroundColor
            self.scrollView.backgroundColor = theme.list.blocksBackgroundColor

            var contentHeight = environment.navigationHeight + 16.0

            if self.displaysApprovalInfo {
                contentHeight += 2.0

                var transition = transition
                if self.approvalInfoText.view == nil {
                    transition = .immediate
                }

                if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== theme {
                    if let chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor) {
                        self.cachedChevronImage = (chevronImage, theme)
                    }
                }

                let linkAttributeKey = NSAttributedString.Key(rawValue: "URL")
                let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.freeTextColor)
                let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor)
                let approvalInfoRawText = "Chats require admin approval before they're added to the community. [Change Settings >](settings)".replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let approvalInfoAttributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(approvalInfoRawText, attributes: MarkdownAttributes(
                    body: body,
                    bold: body,
                    link: link,
                    linkAttribute: { contents in
                        return ("URL", contents)
                    }
                )))
                if let range = approvalInfoAttributedText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    approvalInfoAttributedText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: approvalInfoAttributedText.string))
                }

                let approvalInfoSize = self.approvalInfoText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(approvalInfoAttributedText),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[linkAttributeKey] {
                                return linkAttributeKey
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            if let _ = attributes[linkAttributeKey] {
                                self?.openCommunitySettings()
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 32.0, height: 10000.0)
                )
                if let approvalInfoView = self.approvalInfoText.view {
                    if approvalInfoView.superview == nil {
                        self.scrollView.addSubview(approvalInfoView)
                    }
                    transition.setFrame(view: approvalInfoView, frame: CGRect(
                        origin: CGPoint(x: sideInset + 16.0, y: contentHeight),
                        size: approvalInfoSize
                    ))
                    transition.setAlpha(view: approvalInfoView, alpha: 1.0)
                }
                contentHeight += approvalInfoSize.height + 26.0
            } else if let approvalInfoView = self.approvalInfoText.view {
                transition.setAlpha(view: approvalInfoView, alpha: 0.0, completion: { [weak approvalInfoView] _ in
                    approvalInfoView?.removeFromSuperview()
                })
            }

            let rows = self.rows
            let displaysBulkActions = rows.count > 1
            let bottomButtonHeight: CGFloat = 50.0
            let bottomButtonSpacing: CGFloat = 10.0
            let bottomButtonSideInset: CGFloat = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let bottomPanelHeight: CGFloat = displaysBulkActions ? (16.0 + bottomButtonHeight + 12.0 + environment.safeInsets.bottom) : 0.0

            if !rows.isEmpty {
                var items: [AnyComponentWithIdentity<Empty>] = []
                for i in 0 ..< rows.count {
                    items.append(self.requestItem(
                        component: component,
                        row: rows[i],
                        hasNext: i != rows.count - 1,
                        theme: theme,
                        presentationData: presentationData
                    ))
                }

                var requestsSectionTitle: String
                if rows.count == 1 {
                    requestsSectionTitle = "1 CHAT SUGGESTED FOR THIS COMMUNITY"
                } else {
                    requestsSectionTitle = "\(rows.count) CHATS SUGGESTED FOR THIS COMMUNITY"
                }

                var sectionTransition = transition
                if self.requestsSection.view == nil {
                    sectionTransition = .immediate
                }

                let sectionSize = self.requestsSection.update(
                    transition: sectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: requestsSectionTitle,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        footer: nil,
                        items: items
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 10000.0)
                )
                if let sectionView = self.requestsSection.view {
                    if sectionView.superview == nil {
                        sectionView.alpha = 0.0
                        self.scrollView.addSubview(sectionView)
                    }
                    sectionTransition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: sectionSize))
                    transition.setAlpha(view: sectionView, alpha: 1.0)
                }
                if let emptyView = self.emptyText.view {
                    transition.setAlpha(view: emptyView, alpha: 0.0, completion: { [weak emptyView] _ in
                        emptyView?.removeFromSuperview()
                    })
                }
                contentHeight += sectionSize.height + 24.0
            } else {
                if let sectionView = self.requestsSection.view {
                    transition.setAlpha(view: sectionView, alpha: 0.0, completion: { [weak sectionView] _ in
                        sectionView?.removeFromSuperview()
                    })
                }

                let emptyString = self.requests == nil ? "Loading..." : "No pending requests"
                let emptySize = self.emptyText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: emptyString,
                            font: Font.regular(15.0),
                            textColor: theme.list.freeTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: contentWidth - 32.0, height: 10000.0)
                )
                if let emptyView = self.emptyText.view {
                    if emptyView.superview == nil {
                        self.scrollView.addSubview(emptyView)
                    }
                    transition.setFrame(view: emptyView, frame: CGRect(
                        origin: CGPoint(x: sideInset + 16.0 + floorToScreenPixels((contentWidth - 32.0 - emptySize.width) / 2.0), y: contentHeight),
                        size: emptySize
                    ))
                    transition.setAlpha(view: emptyView, alpha: 1.0)
                }
                contentHeight += emptySize.height + 24.0
            }

            if displaysBulkActions {
                let bottomEdgeEffectFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight),
                    size: CGSize(width: availableSize.width, height: bottomPanelHeight)
                )
                transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
                self.bottomEdgeEffectView.update(
                    content: theme.list.blocksBackgroundColor,
                    blur: true,
                    alpha: 1.0,
                    rect: bottomEdgeEffectFrame,
                    edge: .bottom,
                    edgeSize: bottomPanelHeight,
                    transition: transition
                )
                if self.bottomEdgeEffectView.superview == nil {
                    self.addSubview(self.bottomEdgeEffectView)
                }
                transition.setAlpha(view: self.bottomEdgeEffectView, alpha: 1.0)

                var buttonsTransition = transition
                if self.declineAllButton.view == nil {
                    buttonsTransition = .immediate
                }

                let buttonY = availableSize.height - environment.safeInsets.bottom - 12.0 - bottomButtonHeight
                let buttonsWidth = availableSize.width - bottomButtonSideInset * 2.0
                let buttonWidth = floorToScreenPixels((buttonsWidth - bottomButtonSpacing) / 2.0)
                let declineButtonSize = self.declineAllButton.update(
                    transition: buttonsTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                            foreground: theme.list.itemPrimaryTextColor,
                            pressedColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                            cornerRadius: 25.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(ButtonTextContentComponent(
                                text: "Decline All",
                                badge: 0,
                                textColor: theme.list.itemPrimaryTextColor,
                                badgeBackground: theme.list.itemPrimaryTextColor,
                                badgeForeground: theme.list.blocksBackgroundColor
                            ))
                        ),
                        isEnabled: self.bulkAction == nil,
                        displaysProgress: self.bulkAction == false,
                        action: { [weak self] in
                            self?.presentBulkConfirmation(approve: false, count: rows.count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: bottomButtonHeight)
                )
                let addButtonSize = self.addAllButton.update(
                    transition: buttonsTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                            cornerRadius: 25.0
                        ),
                        content: AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(ButtonTextContentComponent(
                                text: "Add All",
                                badge: 0,
                                textColor: theme.list.itemCheckColors.foregroundColor,
                                badgeBackground: theme.list.itemCheckColors.foregroundColor,
                                badgeForeground: theme.list.itemCheckColors.fillColor
                            ))
                        ),
                        isEnabled: self.bulkAction == nil,
                        displaysProgress: self.bulkAction == true,
                        action: { [weak self] in
                            self?.presentBulkConfirmation(approve: true, count: rows.count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: bottomButtonHeight)
                )

                if let declineButtonView = self.declineAllButton.view {
                    if declineButtonView.superview == nil {
                        self.addSubview(declineButtonView)
                    }
                    buttonsTransition.setFrame(view: declineButtonView, frame: CGRect(
                        origin: CGPoint(x: bottomButtonSideInset, y: buttonY),
                        size: CGSize(width: buttonWidth, height: declineButtonSize.height)
                    ))
                    transition.setAlpha(view: declineButtonView, alpha: 1.0)
                }
                if let addButtonView = self.addAllButton.view {
                    if addButtonView.superview == nil {
                        self.addSubview(addButtonView)
                    }
                    buttonsTransition.setFrame(view: addButtonView, frame: CGRect(
                        origin: CGPoint(x: bottomButtonSideInset + buttonWidth + bottomButtonSpacing, y: buttonY),
                        size: CGSize(width: buttonWidth, height: addButtonSize.height)
                    ))
                    transition.setAlpha(view: addButtonView, alpha: 1.0)
                }
            } else {
                if let declineButtonView = self.declineAllButton.view {
                    transition.setAlpha(view: declineButtonView, alpha: 0.0, completion: { [weak declineButtonView] _ in
                        declineButtonView?.removeFromSuperview()
                    })
                }
                if let addButtonView = self.addAllButton.view {
                    transition.setAlpha(view: addButtonView, alpha: 0.0, completion: { [weak addButtonView] _ in
                        addButtonView?.removeFromSuperview()
                    })
                }
                transition.setAlpha(view: self.bottomEdgeEffectView, alpha: 0.0, completion: { [weak self] _ in
                    self?.bottomEdgeEffectView.removeFromSuperview()
                })
            }

            contentHeight += 24.0 + (displaysBulkActions ? bottomPanelHeight : environment.safeInsets.bottom)

            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            self.ignoreScrolling = true
            if self.scrollView.frame.size != availableSize {
                self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: bottomPanelHeight, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            self.ignoreScrolling = false

            self.updateScrolling(transition: transition)

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

public final class CommunityRequestsScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, communityId: EnginePeer.Id) {
        super.init(
            context: context,
            component: CommunityRequestsScreenComponent(context: context, communityId: communityId),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: nil
        )

        self.title = "Pending Requests"
        self.navigationItem.title = "Pending Requests"
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? CommunityRequestsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
