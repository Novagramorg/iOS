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
import ListSectionComponent
import ListActionItemComponent
import ListTextFieldItemComponent
import AlertComponent
import ItemListUI
import PeerInfoUI

private enum CommunityAddChatsMode: Equatable {
    case allMembers
    case onlyAdmins

    init(defaultBannedRights: TelegramChatBannedRights?) {
        if defaultBannedRights?.flags.contains(.banManageLinkedPeers) == true {
            self = .onlyAdmins
        } else {
            self = .allMembers
        }
    }
}

private enum CommunityEditSaveError {
    case generic
}

private let navigationCheckImage: UIImage = {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 4.0, y: 10.5))
        context.addLine(to: CGPoint(x: 8.0, y: 14.5))
        context.addLine(to: CGPoint(x: 16.5, y: 5.5))
        context.strokePath()
    })!.withRenderingMode(.alwaysTemplate)
}()

private final class ItemAccessoryComponent: Component {
    enum CountStyle: Equatable {
        case plain
        case badge
    }

    let count: Int32?
    let countStyle: CountStyle
    let theme: PresentationTheme

    init(count: Int32?, countStyle: CountStyle, theme: PresentationTheme) {
        self.count = count
        self.countStyle = countStyle
        self.theme = theme
    }

    static func ==(lhs: ItemAccessoryComponent, rhs: ItemAccessoryComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.countStyle != rhs.countStyle {
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
        private var component: ItemAccessoryComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.badgeBackgroundView)
            self.addSubview(self.chevronView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ItemAccessoryComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            if themeUpdated || self.chevronView.image == nil {
                self.chevronView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
            }

            let countValue = component.count.flatMap { $0 > 0 ? Int($0) : nil }
            var textSize = CGSize()
            if let countValue {
                let textColor: UIColor
                let font: UIFont
                let backgroundColor: UIColor?
                let textConstrainedSize: CGSize
                switch component.countStyle {
                case .plain:
                    textColor = component.theme.list.itemSecondaryTextColor
                    font = Font.regular(17.0)
                    backgroundColor = nil
                    textConstrainedSize = CGSize(width: 80.0, height: 30.0)
                case .badge:
                    textColor = component.theme.list.itemCheckColors.foregroundColor
                    font = Font.medium(12.0)
                    backgroundColor = component.theme.list.itemCheckColors.fillColor
                    textConstrainedSize = CGSize(width: 80.0, height: 20.0)
                }

                let measuredSize = self.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(countValue)", font: font, textColor: textColor)),
                        horizontalAlignment: .center,
                        verticalAlignment: .middle
                    )),
                    environment: {},
                    containerSize: textConstrainedSize
                )
                textSize = measuredSize

                if let textView = self.text.view {
                    if textView.superview == nil {
                        self.insertSubview(textView, aboveSubview: self.badgeBackgroundView)
                    }
                    textView.isHidden = false
                    textView.backgroundColor = nil
                    textView.layer.cornerRadius = 0.0
                    textView.clipsToBounds = false
                }
                if let backgroundColor {
                    self.badgeBackgroundView.isHidden = false
                    self.badgeBackgroundView.backgroundColor = backgroundColor
                    self.badgeBackgroundView.layer.cornerRadius = 10.0
                    self.badgeBackgroundView.clipsToBounds = true
                } else {
                    self.badgeBackgroundView.isHidden = true
                }
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
                transition.setFrame(view: self.badgeBackgroundView, frame: CGRect(origin: CGPoint(x: currentX + textSize.width * 0.5 - badgeBackgroundSize.width * 0.5, y: floor((size.height - badgeBackgroundSize.height) * 0.5)), size: badgeBackgroundSize))
                if let textView = self.text.view {
                    transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: currentX, y: floor((size.height - textSize.height) * 0.5)), size: textSize))
                }
                currentX += textSize.width + spacing
            }
            transition.setFrame(view: self.chevronView, frame: CGRect(origin: CGPoint(x: currentX, y: floor((size.height - chevronSize.height) * 0.5)), size: chevronSize))

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

private final class CommunityEditScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let communityId: EnginePeer.Id

    init(context: AccountContext, communityId: EnginePeer.Id) {
        self.context = context
        self.communityId = communityId
    }

    static func ==(lhs: CommunityEditScreenComponent, rhs: CommunityEditScreenComponent) -> Bool {
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

        private let titleSection = ComponentView<Empty>()
        private let permissionsSection = ComponentView<Empty>()
        private let managementSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()

        private var component: CommunityEditScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var isUpdating = false
        private var ignoreScrolling = false

        private let titleFieldTag = NSObject()
        private var resetTitleText: String?

        private var community: TelegramCommunity?
        private var cachedData: CachedCommunityData?
        private var currentTitle = ""
        private var initialTitle = ""
        private var selectedMode: CommunityAddChatsMode = .allMembers
        private var initialMode: CommunityAddChatsMode = .allMembers
        private var didInitializeState = false
        private var isSaving = false
        private var isDeleting = false

        private var dataDisposable: Disposable?
        private let saveDisposable = MetaDisposable()
        private let deleteDisposable = MetaDisposable()

        private let cachedAdminsIcon = renderSettingsIcon(name: "Item List/Icons/Admin", backgroundColors: [UIColor(rgb: 0x34C759)])
        private let cachedRequestsIcon = renderSettingsIcon(name: "Item List/Icons/Requests", backgroundColors: [UIColor(rgb: 0x0079ff)])
        private let cachedBannedIcon = renderSettingsIcon(name: "Item List/Icons/Block", backgroundColors: [UIColor(rgb: 0xFF453A)])

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
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.dataDisposable?.dispose()
            self.saveDisposable.dispose()
            self.deleteDisposable.dispose()
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

        private var trimmedTitle: String {
            return self.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private var hasChanges: Bool {
            if self.trimmedTitle != self.initialTitle {
                return true
            }
            if self.selectedMode != self.initialMode {
                return true
            }
            return false
        }

        private func ensureDataSignal(component: CommunityEditScreenComponent) {
            if self.dataDisposable != nil {
                return
            }
            component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: component.communityId)
            self.dataDisposable = (combineLatest(
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: component.communityId)),
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CachedData(id: component.communityId))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                guard let self else {
                    return
                }

                let community: TelegramCommunity?
                if let peer {
                    switch peer {
                    case let .community(value):
                        community = value
                    default:
                        community = nil
                    }
                } else {
                    community = nil
                }
                self.community = community
                self.cachedData = cachedData as? CachedCommunityData

                if let community {
                    let mode = CommunityAddChatsMode(defaultBannedRights: community.defaultBannedRights)
                    if !self.didInitializeState || (!self.hasChanges && !self.isSaving) {
                        self.didInitializeState = true
                        self.initialTitle = community.title
                        self.currentTitle = community.title
                        self.initialMode = mode
                        self.selectedMode = mode
                        self.resetTitleText = community.title
                    }
                }

                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func dismissController() {
            self.environment?.controller()?.dismiss()
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

        private func confirmDeleteCommunity() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }
            environment.controller()?.present(AlertScreen(
                context: component.context,
                title: "Delete Community",
                text: "Are you sure you want to delete this community?",
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_Cancel, type: .generic),
                    AlertScreen.Action(title: "Delete", type: .defaultDestructive, action: { [weak self] in
                        self?.deleteCommunity()
                    })
                ]
            ), in: .window(.root))
        }

        private func deleteCommunity() {
            guard let component = self.component else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }

            self.isDeleting = true
            self.state?.updated(transition: .easeInOut(duration: 0.2))

            let signal = component.context.engine.peers.deleteChannel(peerId: component.communityId)
            |> mapError { _ -> CommunityEditSaveError in
                return .generic
            }
            |> ignoreValues
            |> then(
                component.context.engine.peers.joinedCommunities()
                |> castError(CommunityEditSaveError.self)
                |> ignoreValues
            )

            self.deleteDisposable.set((signal
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isDeleting = false
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isDeleting = false
                self.dismissController()
            }))
        }

        private func pushController(_ controller: ViewController) {
            guard let environment = self.environment else {
                return
            }
            if let navigationController = environment.controller()?.navigationController as? NavigationController {
                navigationController.pushViewController(controller)
            } else {
                environment.controller()?.present(controller, in: .window(.root))
            }
        }

        private func openAdministrators() {
            guard let component = self.component else {
                return
            }
            let controller = channelAdminsController(
                context: component.context,
                updatedPresentationData: nil,
                peerId: component.communityId
            )
            self.pushController(controller)
        }

        private func openRemovedUsers() {
            guard let component = self.component else {
                return
            }
            let controller = channelBlacklistController(
                context: component.context,
                updatedPresentationData: nil,
                peerId: component.communityId
            )
            self.pushController(controller)
        }

        private func openPendingRequests() {
            guard let component = self.component else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityRequestsScreen(context: component.context, communityId: component.communityId)
            self.pushController(controller)
        }

        private func rightsWithUpdatedMode(_ mode: CommunityAddChatsMode, current: TelegramChatBannedRights?) -> TelegramChatBannedRights {
            var flags = current?.flags ?? TelegramChatBannedRightsFlags()
            switch mode {
            case .allMembers:
                flags.remove(.banManageLinkedPeers)
            case .onlyAdmins:
                flags.insert(.banManageLinkedPeers)
            }
            return TelegramChatBannedRights(flags: flags, untilDate: current?.untilDate ?? Int32.max)
        }

        func save() {
            guard let component = self.component, let community = self.community else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }

            let title = self.trimmedTitle
            if title.isEmpty {
                return
            }

            if !self.hasChanges {
                self.dismissController()
                return
            }

            self.isSaving = true

            let titleChanged = title != self.initialTitle
            let modeChanged = self.selectedMode != self.initialMode

            var signal: Signal<Never, CommunityEditSaveError> = .complete()
            if titleChanged {
                signal = signal
                |> then(component.context.engine.peers.updatePeerTitle(peerId: component.communityId, title: title)
                |> mapError { _ -> CommunityEditSaveError in
                    return .generic
                }
                |> ignoreValues)
            }
            if modeChanged {
                let rights = self.rightsWithUpdatedMode(self.selectedMode, current: community.defaultBannedRights)
                signal = signal
                |> then(component.context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: component.communityId, rights: rights)
                |> castError(CommunityEditSaveError.self))
            }

            self.saveDisposable.set((signal
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.dismissController()
            }))
        }

        private func selectMode(_ mode: CommunityAddChatsMode) {
            if self.isSaving || self.isDeleting {
                return
            }
            if self.selectedMode != mode {
                self.selectedMode = mode
                self.state?.updated(transition: .spring(duration: 0.35))
            }
        }

        private func permissionItem(
            id: String,
            title: String,
            subtitle: String,
            mode: CommunityAddChatsMode,
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                    AnyComponentWithIdentity(id: "subtitle", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: subtitle,
                            font: Font.regular(13.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    )))
                ], alignment: .left, spacing: 4.0)),
                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0),
                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                    style: .tick,
                    isSelected: self.selectedMode == mode,
                    toggle: { [weak self] in
                        self?.selectMode(mode)
                    }
                )),
                accessory: nil,
                action: { [weak self] _ in
                    self?.selectMode(mode)
                },
                highlighting: self.isSaving ? .disabled : .default
            )))
        }

        private func managementItem(
            id: String,
            title: String,
            icon: UIImage?,
            count: Int32?,
            countStyle: ItemAccessoryComponent.CountStyle,
            theme: PresentationTheme,
            presentationData: PresentationData,
            action: (() -> Void)?
        ) -> AnyComponentWithIdentity<Empty> {
            let itemAction: ((UIView) -> Void)? = action.map { action in
                return { _ in
                    action()
                }
            }
            return AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: title,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: icon, component: AnyComponent(Image(image: icon, size: CGSize(width: 30.0, height: 30.0)))), false),
                accessory: .custom(ListActionItemComponent.CustomAccessory(
                    component: AnyComponentWithIdentity(id: "\(id)-accessory-\(count ?? 0)", component: AnyComponent(ItemAccessoryComponent(
                        count: count,
                        countStyle: countStyle,
                        theme: theme
                    ))),
                    insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0),
                    isInteractive: false
                )),
                action: itemAction,
                highlighting: itemAction == nil ? .disabled : .default
            )))
        }

        private func deleteItem(
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: "delete", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "Delete Community",
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemDestructiveColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                titleAlignment: .center,
                contentInsets: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0),
                leftIcon: nil,
                accessory: self.isDeleting ? .activity : nil,
                action: { [weak self] _ in
                    self?.confirmDeleteCommunity()
                },
                highlighting: (self.isSaving || self.isDeleting) ? .disabled : .default
            )))
        }

        func update(component: CommunityEditScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.component = component
            self.state = state

            self.ensureDataSignal(component: component)

            let theme = environment.theme
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 28.0

            self.backgroundColor = theme.list.blocksBackgroundColor
            self.scrollView.backgroundColor = theme.list.blocksBackgroundColor

            var contentHeight = environment.navigationHeight + 16.0

            let resetTitleText = self.resetTitleText
            self.resetTitleText = nil

            let titleSectionSize = self.titleSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "title", component: AnyComponent(ListTextFieldItemComponent(
                            style: .glass,
                            theme: theme,
                            initialText: self.currentTitle,
                            resetText: resetTitleText.flatMap { ListTextFieldItemComponent.ResetText(value: $0) },
                            placeholder: "",
                            autocapitalizationType: .words,
                            autocorrectionType: .yes,
                            updated: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                self.currentTitle = value
                            },
                            tag: self.titleFieldTag
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let titleSectionView = self.titleSection.view {
                if titleSectionView.superview == nil {
                    self.scrollView.addSubview(titleSectionView)
                }
                transition.setFrame(view: titleSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: titleSectionSize))
            }
            contentHeight += titleSectionSize.height + sectionSpacing

            let permissionsSectionSize = self.permissionsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "WHO CAN ADD CHATS",
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: nil,
                    items: [
                        self.permissionItem(
                            id: "allMembers",
                            title: "All Members",
                            subtitle: "Allow members to add their groups and channels to the community.",
                            mode: .allMembers,
                            theme: theme,
                            presentationData: presentationData
                        ),
                        self.permissionItem(
                            id: "onlyAdmins",
                            title: "Only Admins",
                            subtitle: "Chats suggested by community members require admin approval.",
                            mode: .onlyAdmins,
                            theme: theme,
                            presentationData: presentationData
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let permissionsSectionView = self.permissionsSection.view {
                if permissionsSectionView.superview == nil {
                    self.scrollView.addSubview(permissionsSectionView)
                }
                transition.setFrame(view: permissionsSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: permissionsSectionSize))
            }
            contentHeight += permissionsSectionSize.height + 46.0

            let adminsCount = self.cachedData?.adminsCount
            let pendingRequests = self.cachedData?.pendingRequests
            let managementSectionSize = self.managementSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        self.managementItem(
                            id: "administrators",
                            title: "Administrators",
                            icon: self.cachedAdminsIcon,
                            count: adminsCount,
                            countStyle: .plain,
                            theme: theme,
                            presentationData: presentationData,
                            action: { [weak self] in
                                self?.openAdministrators()
                            }
                        ),
                        self.managementItem(
                            id: "pendingRequests",
                            title: "Pending Requests",
                            icon: self.cachedRequestsIcon,
                            count: pendingRequests,
                            countStyle: .badge,
                            theme: theme,
                            presentationData: presentationData,
                            action: { [weak self] in
                                self?.openPendingRequests()
                            }
                        ),
                        self.managementItem(
                            id: "removedUsers",
                            title: "Removed Users",
                            icon: self.cachedBannedIcon,
                            count: nil,
                            countStyle: .plain,
                            theme: theme,
                            presentationData: presentationData,
                            action: { [weak self] in
                                self?.openRemovedUsers()
                            }
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let managementSectionView = self.managementSection.view {
                if managementSectionView.superview == nil {
                    self.scrollView.addSubview(managementSectionView)
                }
                transition.setFrame(view: managementSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: managementSectionSize))
            }
            contentHeight += managementSectionSize.height
            contentHeight += sectionSpacing

            let deleteSectionSize = self.deleteSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        self.deleteItem(
                            theme: theme,
                            presentationData: presentationData
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            if let deleteSectionView = self.deleteSection.view {
                if deleteSectionView.superview == nil {
                    self.scrollView.addSubview(deleteSectionView)
                }
                transition.setFrame(view: deleteSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: deleteSectionSize))
            }
            contentHeight += deleteSectionSize.height
            contentHeight += 32.0 + environment.safeInsets.bottom

            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            self.ignoreScrolling = true
            if self.scrollView.frame.size != availableSize {
                self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
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

public final class CommunityEditScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, communityId: EnginePeer.Id) {
        super.init(
            context: context,
            component: CommunityEditScreenComponent(context: context, communityId: communityId),
            navigationBarAppearance: .transparent,
            theme: .default,
            updatedPresentationData: nil
        )

        self.title = "Edit Community"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "___done", style: .plain, target: self, action: #selector(self.savePressed))

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? CommunityEditScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func savePressed() {
        guard let componentView = self.node.hostView.componentView as? CommunityEditScreenComponent.View else {
            return
        }
        componentView.save()
    }
}
