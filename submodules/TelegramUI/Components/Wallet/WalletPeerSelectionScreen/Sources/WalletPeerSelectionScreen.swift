import Foundation
import UIKit
import AppBundle
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import ChatListHeaderComponent
import SearchBarNode
import QrCodeUI
import MultilineTextComponent
import ButtonComponent
import LottieComponent
import WalletContext
import WalletSendScreen

public enum WalletPeerSelectionScreenMode: Equatable {
    case transfer
    case collectible(WalletContext.Collectible)
}

private func walletPeerSelectionShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

private final class WalletPeerSelectionRecipientView: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronView = UIImageView()

    var pressed: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.iconView.contentMode = .scaleAspectFit
        self.iconView.image = UIImage(bundleImageName: "Wallet/Ton")
        self.addSubview(self.iconView)

        self.titleLabel.numberOfLines = 1
        self.titleLabel.lineBreakMode = .byTruncatingMiddle
        self.addSubview(self.titleLabel)

        self.subtitleLabel.numberOfLines = 1
        self.subtitleLabel.lineBreakMode = .byTruncatingMiddle
        self.addSubview(self.subtitleLabel)

        self.chevronView.contentMode = .center
        self.addSubview(self.chevronView)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            self.alpha = self.isHighlighted ? 0.55 : 1.0
        }
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }

    func update(
        recipient: WalletContext.ResolvedTransferRecipient,
        theme: PresentationTheme,
        size: CGSize,
        transition: ComponentTransition
    ) {
        let title: String
        let subtitle: String?
        if let displayName = recipient.displayName {
            title = displayName
            subtitle = walletPeerSelectionShortAddress(recipient.address)
        } else {
            title = walletPeerSelectionShortAddress(recipient.address)
            subtitle = nil
        }

        self.titleLabel.text = title
        self.titleLabel.font = Font.medium(16.0)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.subtitleLabel.text = subtitle
        self.subtitleLabel.font = Font.regular(14.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.isHidden = subtitle == nil
        self.chevronView.image = generateTintedImage(
            image: UIImage(bundleImageName: "Wallet/Chevron"),
            color: theme.list.itemSecondaryTextColor
        )
        self.accessibilityLabel = title
        self.accessibilityValue = subtitle

        let sideInset: CGFloat = 16.0
        let iconSize = CGSize(width: 40.0, height: 40.0)
        transition.setFrame(
            view: self.iconView,
            frame: CGRect(
                x: sideInset,
                y: floorToScreenPixels((size.height - iconSize.height) * 0.5),
                width: iconSize.width,
                height: iconSize.height
            )
        )

        let chevronSize = CGSize(width: 10.0, height: 20.0)
        transition.setFrame(
            view: self.chevronView,
            frame: CGRect(
                x: size.width - sideInset - chevronSize.width,
                y: floorToScreenPixels((size.height - chevronSize.height) * 0.5),
                width: chevronSize.width,
                height: chevronSize.height
            )
        )

        let textOriginX = sideInset + iconSize.width + 11.0
        let textWidth = max(1.0, size.width - textOriginX - chevronSize.width - sideInset - 8.0)
        if subtitle != nil {
            let titleHeight: CGFloat = 20.0
            let subtitleHeight: CGFloat = 18.0
            let textSpacing: CGFloat = 1.0
            let textOriginY = floorToScreenPixels(
                (size.height - titleHeight - textSpacing - subtitleHeight) * 0.5
            )
            transition.setFrame(
                view: self.titleLabel,
                frame: CGRect(x: textOriginX, y: textOriginY, width: textWidth, height: titleHeight)
            )
            transition.setFrame(
                view: self.subtitleLabel,
                frame: CGRect(
                    x: textOriginX,
                    y: textOriginY + titleHeight + textSpacing,
                    width: textWidth,
                    height: subtitleHeight
                )
            )
        } else {
            let titleHeight: CGFloat = 20.0
            transition.setFrame(
                view: self.titleLabel,
                frame: CGRect(
                    x: textOriginX,
                    y: floorToScreenPixels((size.height - titleHeight) * 0.5),
                    width: textWidth,
                    height: titleHeight
                )
            )
        }
    }
}

private final class WalletPeerSelectionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let mode: WalletPeerSelectionScreenMode
    let dismissSourceScreen: () -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletPeerSelectionScreenMode,
        dismissSourceScreen: @escaping () -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.mode = mode
        self.dismissSourceScreen = dismissSourceScreen
    }

    static func ==(lhs: WalletPeerSelectionScreenComponent, rhs: WalletPeerSelectionScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.mode == rhs.mode
    }

    final class View: UIView {
        private let navigationBarView = ComponentView<Empty>()
        private var searchBarNode: SearchBarNode?
        private var activeSearch: ChatListNavigationBar.ActiveSearch?
        private let scanQrButton = UIButton(type: .custom)

        private let recipientSectionTitle = UILabel()
        private let recipientView = WalletPeerSelectionRecipientView()
        private let emptyResultsAnimation = ComponentView<Empty>()
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let continueButton = ComponentView<Empty>()

        private var component: WalletPeerSelectionScreenComponent?
        private var environment: EnvironmentType?
        private(set) weak var state: EmptyComponentState?
        private var isUpdating = false

        private var walletContext: WalletContext?
        private let walletStateDisposable = MetaDisposable()
        private let resolveDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private var resolveTimer: SwiftSignalKit.Timer?
        private var resolveGeneration: Int = 0
        private var query: String = ""
        private var recipient: WalletContext.ResolvedTransferRecipient?
        private var noResultsQuery: String?
        private var isPreparingTransfer = false

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.recipientSectionTitle.text = "Recipient".uppercased()
            self.addSubview(self.recipientSectionTitle)

            self.recipientView.pressed = { [weak self] in
                self?.openRecipient()
            }
            self.addSubview(self.recipientView)

            self.scanQrButton.accessibilityLabel = "Scan QR Code"
            self.scanQrButton.accessibilityTraits = .button
            self.scanQrButton.addTarget(self, action: #selector(self.scanQrPressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.resolveTimer?.invalidate()
            self.resolveDisposable.dispose()
            self.transferDisposable.dispose()
            self.walletStateDisposable.dispose()
        }

        private func clearNoResults() {
            self.noResultsQuery = nil
            self.emptyResultsAnimation.view?.removeFromSuperview()
            self.emptyResultsTitle.view?.removeFromSuperview()
            self.emptyResultsText.view?.removeFromSuperview()
        }

        private func resetQuery() {
            self.resolveGeneration &+= 1
            self.resolveTimer?.invalidate()
            self.resolveTimer = nil
            self.resolveDisposable.set(nil)
            self.query = ""
            self.recipient = nil
            self.clearNoResults()
            self.searchBarNode?.activity = false
        }

        private func updateQuery(_ value: String) {
            let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.query != query else {
                return
            }

            self.resolveGeneration &+= 1
            let generation = self.resolveGeneration
            self.resolveTimer?.invalidate()
            self.resolveTimer = nil
            self.resolveDisposable.set(nil)
            self.query = query
            self.recipient = nil
            self.clearNoResults()
            self.searchBarNode?.activity = false
            self.state?.updated(transition: .easeInOut(duration: 0.2))

            guard !query.isEmpty else {
                return
            }

            let timer = SwiftSignalKit.Timer(timeout: 0.4, repeat: false, completion: { [weak self] in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.resolveTimer = nil
                self.resolve(query: query, generation: generation)
            }, queue: Queue.mainQueue())
            self.resolveTimer = timer
            timer.start()
        }

        private func resolve(query: String, generation: Int) {
            guard let component = self.component else {
                return
            }
            self.searchBarNode?.activity = true
            self.clearNoResults()
            if !self.isUpdating {
                self.state?.updated(transition: .easeInOut(duration: 0.2))
            }
            self.resolveDisposable.set((component.walletContext.resolveTransferRecipient(query)
            |> deliverOnMainQueue).start(next: { [weak self] recipient in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.searchBarNode?.activity = false
                self.recipient = recipient
                self.noResultsQuery = recipient == nil ? query : nil
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                }
            }, error: { [weak self] _ in
                guard let self, self.resolveGeneration == generation, self.query == query else {
                    return
                }
                self.searchBarNode?.activity = false
                self.recipient = nil
                self.noResultsQuery = query
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                }
            }))
        }

        private func cancelSearch() {
            self.searchBarNode?.deactivate()
            self.resetQuery()
            self.activeSearch = nil
            self.state?.updated(transition: .spring(duration: 0.4))
        }

        @objc private func scanQrPressed() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let scanner = QrCodeScanScreen(context: component.context, subject: .customValidated(
                info: "Find QR that contains a wallet address",
                validate: { value in
                    return WalletContext.transferAddress(from: value) != nil
                }
            ))
            scanner.completion = { [weak self, weak scanner] value in
                guard let self,
                      let value,
                      let address = WalletContext.transferAddress(from: value) else {
                    return
                }
                Queue.mainQueue().after(0.15) {
                    scanner?.dismiss()
                    self.openRecipient(WalletContext.ResolvedTransferRecipient(
                        address: address,
                        displayName: nil
                    ))
                }
            }
            controller.push(scanner)
        }

        private func openRecipient() {
            guard let recipient = self.recipient else {
                return
            }
            self.openRecipient(recipient)
        }

        private func openRecipient(_ recipient: WalletContext.ResolvedTransferRecipient) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  !self.isPreparingTransfer else {
                return
            }

            self.searchBarNode?.deactivate(clear: false)
            switch component.mode {
            case .transfer:
                let sendScreen = WalletSendScreen(
                    context: component.context,
                    walletContext: component.walletContext,
                    address: recipient.address
                )
                sendScreen.navigationPresentation = .modal
                if let navigationController = controller.navigationController as? NavigationController {
                    navigationController.replaceController(controller, with: sendScreen, animated: true)
                } else {
                    controller.push(sendScreen)
                }
            case let .collectible(collectible):
                self.isPreparingTransfer = true
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                self.transferDisposable.set((component.walletContext.prepareCollectibleTransfer(
                    address: recipient.address,
                    collectible: collectible,
                    comment: nil
                )
                |> deliverOnMainQueue).start(next: { [weak self, weak controller] preparedTransfer in
                    guard let self, let controller, let component = self.component else {
                        return
                    }
                    self.isPreparingTransfer = false
                    self.state?.updated(transition: .easeInOut(duration: 0.2))

                    let dismissSourceScreens: () -> Void = { [weak controller] in
                        if let controller {
                            if let navigationController = controller.navigationController as? NavigationController {
                                var viewControllers = navigationController.viewControllers
                                viewControllers.removeAll(where: { $0 === controller })
                                navigationController.setViewControllers(viewControllers, animated: false)
                            } else {
                                controller.dismiss(animated: false)
                            }
                        }
                        component.dismissSourceScreen()
                    }
                    controller.push(component.context.sharedContext.makeWalletTransactionScreen(
                        context: component.context,
                        mode: .preview(
                            walletContext: component.walletContext,
                            preparedTransfer: preparedTransfer,
                            dismissSendScreen: dismissSourceScreens
                        )
                    ))
                }, error: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.isPreparingTransfer = false
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                    self.presentTransferError()
                }))
            }
        }

        private func presentTransferError() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let title = "Transfer Failed"
            //TODO:localize
            let text = "The transfer could not be prepared or sent. Check the address, balance and network connection, then try again."
            //TODO:localize
            let ok = "OK"
            controller.present(textAlertController(
                context: component.context,
                title: title,
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: ok, action: {
                })]
            ), in: .window(.root))
        }

        private func updateNavigationBar(
            component: WalletPeerSelectionScreenComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            size: CGSize,
            insets: UIEdgeInsets,
            statusBarHeight: CGFloat,
            isModal: Bool,
            transition: ComponentTransition,
            deferScrollApplication: Bool
        ) -> CGFloat {
            let headerContent = ChatListHeaderComponent.Content(
                title: "",
                navigationBackTitle: nil,
                titleComponent: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "Choose Recipient",
                        font: Font.semibold(17.0),
                        textColor: theme.rootController.navigationBar.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                chatListTitle: nil,
                leftButton: isModal ? AnyComponentWithIdentity(id: "close", component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Navigation/Close"),
                    pressed: { [weak self] _ in
                        self?.environment?.controller()?.dismiss()
                    }
                ))) : nil,
                rightButtons: [],
                backPressed: isModal ? nil : { [weak self] in
                    self?.environment?.controller()?.dismiss()
                }
            )

            let navigationBarSize = self.navigationBarView.update(
                transition: transition,
                component: AnyComponent(ChatListNavigationBar(
                    context: component.context,
                    theme: theme,
                    strings: strings,
                    statusBarHeight: statusBarHeight,
                    sideInset: insets.left,
                    search: ChatListNavigationBar.Search(
                        isEnabled: true,
                        placeholder: "Name or wallet address",
                        displayGlassBackgroundWhenInactive: true,
                        alignPlaceholderToLeftWhenInactive: true
                    ),
                    activeSearch: self.activeSearch,
                    primaryContent: headerContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    storySubscriptions: nil,
                    storiesIncludeHidden: false,
                    uploadProgress: [:],
                    headerPanels: nil,
                    tabsNode: nil,
                    tabsNodeIsSearch: false,
                    accessoryPanelContainer: nil,
                    accessoryPanelContainerHeight: 0.0,
                    activateSearch: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.activeSearch = ChatListNavigationBar.ActiveSearch(isExternal: false)
                        self.state?.updated(transition: .spring(duration: 0.4))
                    },
                    openStatusSetup: { _ in
                    },
                    allowAutomaticOrder: {
                    }
                )),
                environment: {},
                containerSize: size
            )
            if let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View {
                if deferScrollApplication {
                    navigationBarView.deferScrollApplication = true
                }
                if navigationBarView.superview == nil {
                    self.addSubview(navigationBarView)
                }
                transition.setFrame(view: navigationBarView, frame: CGRect(origin: CGPoint(), size: navigationBarSize))
                return navigationBarSize.height
            }
            return 0.0
        }

        private func updateNavigationScrolling(transition: ComponentTransition) {
            guard let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View else {
                return
            }
            navigationBarView.applyScroll(
                offset: 0.0,
                allowAvatarsExpansion: false,
                forceUpdate: false,
                transition: transition.withUserData(ChatListNavigationBar.AnimationHint(
                    disableStoriesAnimations: false,
                    crossfadeStoryPeers: false
                ))
            )
        }

        func update(
            component: WalletPeerSelectionScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.component = component
            self.environment = environment
            self.state = state

            if self.walletContext !== component.walletContext {
                self.walletContext = component.walletContext
                self.walletStateDisposable.set(component.walletContext.state.start(next: { _ in
                }))
            }

            if themeUpdated {
                self.backgroundColor = environment.theme.list.plainBackgroundColor
            }

            let isModal = environment.controller()?.navigationPresentation == .modal
            var statusBarHeight = environment.statusBarHeight
            if isModal {
                statusBarHeight = max(statusBarHeight, 1.0)
            }

            let navigationHeight = self.updateNavigationBar(
                component: component,
                theme: environment.theme,
                strings: environment.strings,
                size: availableSize,
                insets: environment.safeInsets,
                statusBarHeight: statusBarHeight,
                isModal: isModal,
                transition: transition,
                deferScrollApplication: true
            )

            if self.scanQrButton.superview == nil {
                self.addSubview(self.scanQrButton)
            }
            self.scanQrButton.setImage(
                generateTintedImage(
                    image: UIImage(bundleImageName: "Wallet/ScanQr"),
                    color: environment.theme.list.itemAccentColor
                ),
                for: .normal
            )
            let scanQrFrame = CGRect(
                x: availableSize.width - environment.safeInsets.right - 16.0 - 46.0,
                y: navigationHeight - 57.0,
                width: 44.0,
                height: 44.0
            )
            transition.setFrame(view: self.scanQrButton, frame: scanQrFrame)
            transition.setAlpha(view: self.scanQrButton, alpha: self.activeSearch == nil ? 1.0 : 0.0)
            self.scanQrButton.isUserInteractionEnabled = self.activeSearch == nil

            var removedSearchBar: SearchBarNode?
            if self.activeSearch != nil {
                let searchBarNode: SearchBarNode
                var searchBarTransition = transition
                if let current = self.searchBarNode {
                    searchBarNode = current
                } else {
                    searchBarTransition = .immediate
                    let searchBarTheme = SearchBarNodeTheme(theme: environment.theme, hasSeparator: false)
                    searchBarNode = SearchBarNode(
                        theme: searchBarTheme,
                        presentationTheme: environment.theme,
                        strings: environment.strings,
                        fieldStyle: .glass,
                        displayBackground: false
                    )
                    searchBarNode.placeholderString = NSAttributedString(
                        string: "Name or wallet address",
                        font: Font.regular(17.0),
                        textColor: searchBarTheme.placeholder
                    )
                    searchBarNode.autocapitalization = .none
                    searchBarNode.cancel = { [weak self] in
                        self?.cancelSearch()
                    }
                    searchBarNode.textUpdated = { [weak self] query, _ in
                        self?.updateQuery(query)
                    }
                    searchBarNode.textReturned = { [weak self] _ in
                        guard let self, self.recipient != nil else {
                            return
                        }
                        self.openRecipient()
                    }
                    self.searchBarNode = searchBarNode
                    DispatchQueue.main.async { [weak self, weak searchBarNode] in
                        guard let self, let searchBarNode, self.searchBarNode === searchBarNode else {
                            return
                        }
                        searchBarNode.activate()
                    }
                }

                var searchBarFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: navigationHeight - 52.0),
                    size: CGSize(width: availableSize.width, height: 54.0)
                )
                if isModal {
                    searchBarFrame.origin.y += 2.0
                }
                searchBarNode.updateThemeAndStrings(
                    theme: SearchBarNodeTheme(theme: environment.theme, hasSeparator: false),
                    presentationTheme: environment.theme,
                    strings: environment.strings
                )
                searchBarNode.updateLayout(
                    boundingSize: searchBarFrame.size,
                    leftInset: environment.safeInsets.left + 6.0,
                    rightInset: environment.safeInsets.right,
                    transition: searchBarTransition.containedViewLayoutTransition
                )
                searchBarTransition.setFrame(view: searchBarNode.view, frame: searchBarFrame)
                if searchBarNode.view.superview == nil {
                    self.addSubview(searchBarNode.view)
                    if case let .curve(duration, curve) = transition.animation,
                       let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View,
                       let placeholderNode = navigationBarView.searchContentNode?.placeholderNode {
                        let timingFunction: String
                        switch curve {
                        case .easeInOut:
                            timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
                        case .easeIn:
                            timingFunction = CAMediaTimingFunctionName.easeIn.rawValue
                        case .linear:
                            timingFunction = CAMediaTimingFunctionName.linear.rawValue
                        case .spring, .custom, .bounce:
                            timingFunction = kCAMediaTimingFunctionSpring
                        }
                        searchBarNode.animateIn(from: placeholderNode, duration: duration, timingFunction: timingFunction)
                    }
                }
            } else if let searchBarNode = self.searchBarNode {
                searchBarNode.deactivate()
                self.searchBarNode = nil
                removedSearchBar = searchBarNode
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            self.recipientSectionTitle.font = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            self.recipientSectionTitle.textColor = environment.theme.list.freeTextColor
            let contentSideInset = environment.safeInsets.left + 16.0
            let hasRecipient = self.recipient != nil
            let sectionTitleFrame = CGRect(
                x: contentSideInset,
                y: navigationHeight + 18.0,
                width: max(1.0, availableSize.width - contentSideInset - environment.safeInsets.right - 16.0),
                height: 24.0
            )
            transition.setFrame(view: self.recipientSectionTitle, frame: sectionTitleFrame)
            transition.setAlpha(view: self.recipientSectionTitle, alpha: hasRecipient ? 1.0 : 0.0)

            let recipientFrame = CGRect(
                x: environment.safeInsets.left,
                y: sectionTitleFrame.maxY + 4.0,
                width: max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right),
                height: 56.0
            )
            transition.setFrame(view: self.recipientView, frame: recipientFrame)
            transition.setAlpha(view: self.recipientView, alpha: hasRecipient ? 1.0 : 0.0)
            self.recipientView.isUserInteractionEnabled = hasRecipient && !self.isPreparingTransfer
            if let recipient = self.recipient {
                self.recipientView.update(
                    recipient: recipient,
                    theme: environment.theme,
                    size: recipientFrame.size,
                    transition: transition
                )
            }

            let emptyResultsFadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if let noResultsQuery = self.noResultsQuery {
                let sideInset: CGFloat = 44.0
                let animationHeight: CGFloat = 148.0
                let animationSpacing: CGFloat = 8.0
                let textSpacing: CGFloat = 8.0

                //TODO:localize
                let title = "No Results"
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.semibold(17.0),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center
                    )),
                    environment: {},
                    containerSize: availableSize
                )

                //TODO:localize
                let text = "There were no results for “\(noResultsQuery)”.\nTry another address."
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: text,
                            font: Font.regular(15.0),
                            textColor: environment.theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(
                        width: max(1.0, availableSize.width - sideInset * 2.0),
                        height: availableSize.height
                    )
                )

                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: animationHeight, height: animationHeight)
                )

                let topInset = environment.safeInsets.top
                let bottomInset = max(environment.safeInsets.bottom, environment.inputHeight)
                let emptyResultsHeight = animationHeight
                    + animationSpacing
                    + emptyResultsTitleSize.height
                    + textSpacing
                    + emptyResultsTextSize.height
                let animationY = topInset + floorToScreenPixels(
                    (availableSize.height - topInset - bottomInset - emptyResultsHeight) * 0.5
                )
                let emptyResultsAnimationFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsAnimationSize.width) * 0.5),
                    y: animationY,
                    width: emptyResultsAnimationSize.width,
                    height: emptyResultsAnimationSize.height
                )
                let emptyResultsTitleFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsTitleSize.width) * 0.5),
                    y: emptyResultsAnimationFrame.maxY + animationSpacing,
                    width: emptyResultsTitleSize.width,
                    height: emptyResultsTitleSize.height
                )
                let emptyResultsTextFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - emptyResultsTextSize.width) * 0.5),
                    y: emptyResultsTitleFrame.maxY + textSpacing,
                    width: emptyResultsTextSize.width,
                    height: emptyResultsTextSize.height
                )

                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                        view.playOnce()
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        self.addSubview(view)
                    }
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 1.0)
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsTextFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.noResultsQuery == nil else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.noResultsQuery == nil else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsText.view {
                    emptyResultsFadeTransition.setAlpha(view: view, alpha: 0.0, completion: { [weak self, weak view] _ in
                        guard self?.noResultsQuery == nil else {
                            return
                        }
                        view?.removeFromSuperview()
                    })
                }
            }

            let buttonSideInset = environment.safeInsets.left + 16.0
            let buttonWidth = max(
                1.0,
                availableSize.width - buttonSideInset - environment.safeInsets.right - 16.0
            )
            let buttonHeight: CGFloat = 50.0
            let keyboardTop = availableSize.height - environment.inputHeight
            let buttonBottomInset: CGFloat
            if environment.inputHeight > 0.0 {
                buttonBottomInset = 12.0
            } else {
                buttonBottomInset = max(environment.safeInsets.bottom, environment.additionalInsets.bottom) + 16.0
            }
            let buttonSize = self.continueButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Continue",
                                font: Font.semibold(17.0),
                                textColor: environment.theme.list.itemCheckColors.foregroundColor
                            )),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 1
                        ))
                    ),
                    isEnabled: hasRecipient && !self.isPreparingTransfer,
                    displaysProgress: self.isPreparingTransfer,
                    action: { [weak self] in
                        self?.openRecipient()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            if let buttonView = self.continueButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(
                    view: buttonView,
                    frame: CGRect(
                        x: buttonSideInset,
                        y: keyboardTop - buttonBottomInset - buttonSize.height,
                        width: buttonSize.width,
                        height: buttonSize.height
                    )
                )
                transition.setAlpha(view: buttonView, alpha: hasRecipient ? 1.0 : 0.0)
                buttonView.isUserInteractionEnabled = hasRecipient && !self.isPreparingTransfer
            }

            self.updateNavigationScrolling(transition: transition)
            if let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View {
                navigationBarView.deferScrollApplication = false
                navigationBarView.applyCurrentScroll(transition: transition)
            }

            if let removedSearchBar {
                if !transition.animation.isImmediate,
                   let navigationBarView = self.navigationBarView.view as? ChatListNavigationBar.View,
                   let placeholderNode = navigationBarView.searchContentNode?.placeholderNode {
                    removedSearchBar.transitionOut(
                        to: placeholderNode,
                        transition: transition.containedViewLayoutTransition,
                        completion: { [weak removedSearchBar] in
                            removedSearchBar?.view.removeFromSuperview()
                        }
                    )
                } else {
                    removedSearchBar.view.removeFromSuperview()
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletPeerSelectionScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletPeerSelectionScreenMode = .transfer,
        dismissSourceScreen: @escaping () -> Void = {}
    ) {
        super.init(
            context: context,
            component: WalletPeerSelectionScreenComponent(
                context: context,
                walletContext: walletContext,
                mode: mode,
                dismissSourceScreen: dismissSourceScreen
            ),
            navigationBarAppearance: .none,
            theme: .default
        )
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
