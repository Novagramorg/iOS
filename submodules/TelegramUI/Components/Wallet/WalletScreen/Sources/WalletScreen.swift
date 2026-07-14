import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import ChatListHeaderComponent
import QrCodeUI
import ContextUI
import SwiftSignalKit
import TelegramCore
import WalletContext
import WalletCardComponent
import EdgeEffect
import ButtonComponent
import ListSectionComponent
import ListActionItemComponent
import WalletTransactionItemComponent
import InfoParagraphComponent
import MultilineTextComponent

private let walletVisibleTransactionLimit = 10
private let walletIncomingDustThreshold: Int64 = 10_000_000

private final class WalletScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext

    init(context: AccountContext, walletContext: WalletContext) {
        self.context = context
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletScreenComponent, rhs: WalletScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.walletContext === rhs.walletContext
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        private let topEdgeEffectView: EdgeEffectView
        private let header = ComponentView<Empty>()
        private let card = ComponentView<Empty>()
        private let addFundsButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let transactionsSection = ComponentView<Empty>()
        private let emptyTransactionsInfo = ComponentView<Empty>()

        private var component: WalletScreenComponent?
        private var environment: EnvironmentType?
        private var componentState: EmptyComponentState?

        private var walletContext: WalletContext?
        private var walletState: WalletContext.State?
        private var walletStateDisposable: Disposable?
        private var accountContext: AccountContext?
        private var accountName = ""
        private var accountPeerDisposable: Disposable?
        private var isUpdating = false

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.topEdgeEffectView = EdgeEffectView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.topEdgeEffectView.alpha = 0.0
            self.topEdgeEffectView.isUserInteractionEnabled = false

            self.addSubview(self.scrollView)
            self.addSubview(self.topEdgeEffectView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.walletStateDisposable?.dispose()
            self.accountPeerDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            self.updateScrolling(transition: .immediate)
        }

        private func updateScrolling(transition: ComponentTransition) {
            let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / 20.0))
            transition.setAlpha(view: self.topEdgeEffectView, alpha: edgeEffectAlpha)
        }

        private func dismiss() {
            self.environment?.controller()?.dismiss()
        }

        private func openQrCodeScanner() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(QrCodeScanScreen(context: component.context, subject: .cryptoAddress))
        }

        private func openReceive() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: component.walletContext.address
            ))
        }

        private func openWalletInfo() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletInfoScreen(
                context: component.context,
                mode: .wallet,
                completion: nil
            ))
        }

        private func openWalletSettings() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletSettingsScreen(context: component.context))
        }

        private func openTransaction(_ transaction: WalletContext.Transaction) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletTransactionScreen(
                context: component.context,
                transaction: transaction
            ))
        }

        private func openContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            //TODO:localize
            let currency = "Currency"
            //TODO:localize
            let passcode = "Passcode & Face ID"
            //TODO:localize
            let keysAndBackup = "Keys & Backup"
            //TODO:localize
            let howItWorks = "How It Works"

            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: currency,
                    textLayout: .secondLineWithValue("USD"),
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Globe"), color: theme.contextMenu.primaryColor)
                    },
                    additionalLeftIcon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Arrow"), color: theme.contextMenu.primaryColor)
                    },
                    action: { _, dismiss in
                        dismiss(.default)
                    }
                )),
                .action(ContextMenuActionItem(
                    text: passcode,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FaceId"), color: theme.contextMenu.primaryColor)
                    },
                    action: { _, dismiss in
                        dismiss(.default)
                        component.walletContext.activate()
                    }
                )),
                .action(ContextMenuActionItem(
                    text: keysAndBackup,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Cloud"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openWalletSettings()
                    }
                )),
                .separator,
                .action(ContextMenuActionItem(
                    text: howItWorks,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Help"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openWalletInfo()
                    }
                ))
            ]

            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                source: .reference(WalletContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        func update(
            component: WalletScreenComponent,
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
            self.component = component
            self.environment = environment
            self.componentState = state

            if self.walletContext !== component.walletContext {
                self.walletStateDisposable?.dispose()
                let subscribedContext = component.walletContext
                self.walletContext = subscribedContext
                self.walletState = nil
                self.walletStateDisposable = (subscribedContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === subscribedContext else {
                        return
                    }
                    self.walletState = walletState
                    if !self.isUpdating {
                        self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    }
                })
            }

            if self.accountContext !== component.context {
                self.accountPeerDisposable?.dispose()
                let subscribedContext = component.context
                self.accountContext = subscribedContext
                self.accountName = ""
                self.accountPeerDisposable = (subscribedContext.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: subscribedContext.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, self.accountContext === subscribedContext else {
                        return
                    }
                    let accountName = peer?.debugDisplayTitle.uppercased() ?? ""
                    if self.accountName != accountName {
                        self.accountName = accountName
                        if !self.isUpdating {
                            self.componentState?.updated(transition: .immediate)
                        }
                    }
                })
            }

            //TODO:localize
            let title = "Wallet"
            let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment> = AnyComponentWithIdentity(
                id: "back",
                component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: "Navigation/Back"),
                    pressed: { [weak self] _ in
                        self?.dismiss()
                    }
                ))
            )
            let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "more",
                    component: AnyComponent(NavigationButtonComponent(
                        content: .more,
                        pressed: { [weak self] sourceView in
                            self?.openContextMenu(sourceView: sourceView)
                        }
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "scanQr",
                    component: AnyComponent(NavigationButtonComponent(
                        content: .icon(imageName: "Navigation/ScanQr"),
                        pressed: { [weak self] _ in
                            self?.openQrCodeScanner()
                        }
                    ))
                )
            ]
            let primaryContent = ChatListHeaderComponent.Content(
                title: title,
                navigationBackTitle: nil,
                titleComponent: nil,
                chatListTitle: nil,
                leftButton: leftButton,
                rightButtons: rightButtons,
                backPressed: nil
            )

            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(ChatListHeaderComponent(
                    sideInset: 16.0 + environment.safeInsets.left,
                    primaryContent: primaryContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    networkStatus: nil,
                    storySubscriptions: nil,
                    storiesIncludeHidden: false,
                    storiesFraction: 0.0,
                    storiesUnlocked: false,
                    uploadProgress: [:],
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    openStatusSetup: { _ in
                    },
                    toggleIsLocked: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            let headerOriginY: CGFloat
            if environment.statusBarHeight < 1.0 {
                headerOriginY = 0.0
            } else {
                headerOriginY = environment.statusBarHeight + 10.0
            }
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    self.addSubview(headerView)
                }
                transition.setFrame(
                    view: headerView,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: headerOriginY),
                        size: headerSize
                    )
                )
            }

            let topEdgeEffectHeight = environment.navigationHeight
            let topEdgeEffectFrame = CGRect(
                origin: CGPoint(),
                size: CGSize(width: availableSize.width, height: topEdgeEffectHeight)
            )
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(
                content: environment.theme.list.blocksBackgroundColor,
                blur: true,
                alpha: 1.0,
                rect: topEdgeEffectFrame,
                edge: .top,
                edgeSize: topEdgeEffectFrame.height,
                transition: transition
            )

            let sideInset: CGFloat = 16.0
            let cardWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right - sideInset * 2.0
            )
            let cardOriginY = headerOriginY + headerSize.height + 10.0
            let usdRate = component.context.currentAppConfiguration.with { configuration -> Double? in
                return configuration.data?["ton_usd_rate"] as? Double
            }
            self.card.parentState = state
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletCardComponent(
                    balance: self.walletState?.balance,
                    usdRate: usdRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: self.accountName,
                    address: component.walletContext.address,
                    qrPressed: { [weak self] in
                        self?.openReceive()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: availableSize.height)
            )
            if let cardView = self.card.view {
                if cardView.superview == nil {
                    self.scrollView.addSubview(cardView)
                }
                transition.setFrame(
                    view: cardView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: environment.safeInsets.left + sideInset,
                            y: cardOriginY
                        ),
                        size: cardSize
                    )
                )
            }

            //TODO:localize
            let addFundsTitle = "Add Funds"
            //TODO:localize
            let sendTitle = "Send"
            let buttonsSpacing: CGFloat = 10.0
            let addFundsButtonWidth = floorToScreenPixels((cardWidth - buttonsSpacing) * 0.5)
            let sendButtonWidth = cardWidth - buttonsSpacing - addFundsButtonWidth
            let buttonsOriginY = cardOriginY + cardSize.height + 12.0
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: environment.theme.list.itemCheckColors.fillColor,
                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            self.addFundsButton.parentState = state
            let addFundsButtonSize = self.addFundsButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: addFundsTitle,
                            font: Font.semibold(17.0),
                            color: environment.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    action: { [weak self] in
                        self?.openReceive()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: addFundsButtonWidth, height: 52.0)
            )
            if let addFundsButtonView = self.addFundsButton.view {
                if addFundsButtonView.superview == nil {
                    self.scrollView.addSubview(addFundsButtonView)
                }
                transition.setFrame(
                    view: addFundsButtonView,
                    frame: CGRect(
                        origin: CGPoint(x: environment.safeInsets.left + sideInset, y: buttonsOriginY),
                        size: addFundsButtonSize
                    )
                )
            }

            self.sendButton.parentState = state
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: sendTitle,
                            font: Font.semibold(17.0),
                            color: environment.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    action: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: sendButtonWidth, height: 52.0)
            )
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.scrollView.addSubview(sendButtonView)
                }
                transition.setFrame(
                    view: sendButtonView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: environment.safeInsets.left + sideInset + addFundsButtonWidth + buttonsSpacing,
                            y: buttonsOriginY
                        ),
                        size: sendButtonSize
                    )
                )
            }

            let transactions = Array((self.walletState?.transactions ?? []).lazy.filter { transaction in
                switch transaction.direction {
                case .incoming:
                    return transaction.amount >= walletIncomingDustThreshold
                case .outgoing:
                    return true
                case .unknown:
                    return false
                }
            }.prefix(walletVisibleTransactionLimit))
            let buttonsHeight = max(addFundsButtonSize.height, sendButtonSize.height)
            var contentHeight = buttonsOriginY + buttonsHeight

            if !transactions.isEmpty {
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.reserveCapacity(transactions.count)
                for transaction in transactions {
                    items.append(AnyComponentWithIdentity(
                        id: "\(transaction.id):\(transaction.logicalTime)",
                        component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            style: .glass,
                            title: AnyComponent(WalletTransactionItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                dateTimeFormat: environment.dateTimeFormat,
                                transaction: transaction
                            )),
                            contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 8.0, right: 0.0),
                            separatorInset: 62.0,
                            icon: nil,
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.openTransaction(transaction)
                            },
                            highlighting: .default
                        ))
                    ))
                }
                
                var wasVisible = true
                if self.transactionsSection.view?.superview == nil {
                    wasVisible = false
                }

                let transactionsOriginY = contentHeight + 16.0
                self.transactionsSection.parentState = state
                let transactionsSectionSize = self.transactionsSection.update(
                    transition: wasVisible ? transition : .immediate,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Tap on a transaction to view details.",
                                font: Font.regular(13.0),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: items
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: 10000.0)
                )
                if let transactionsSectionView = self.transactionsSection.view {
                    if transactionsSectionView.superview == nil {
                        self.scrollView.addSubview(transactionsSectionView)
                    }
                    if !transition.animation.isImmediate {
                        transactionsSectionView.layer.allowsGroupOpacity = true
                        transition.animateAlpha(view: transactionsSectionView, from: 0.0, to: 1.0, completion: { _ in
                            transactionsSectionView.layer.allowsGroupOpacity = false
                        })
                    }

                    var transition = transition
                    if !wasVisible {
                        transition = .immediate
                    }
                    transition.setFrame(
                        view: transactionsSectionView,
                        frame: CGRect(
                            origin: CGPoint(x: environment.safeInsets.left + sideInset, y: transactionsOriginY),
                            size: transactionsSectionSize
                        )
                    )
                }
                contentHeight = transactionsOriginY + transactionsSectionSize.height
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view, emptyTransactionsInfoView.superview != nil {
                    transition.setAlpha(view: emptyTransactionsInfoView, alpha: 0.0, completion: { [weak emptyTransactionsInfoView] _ in
                        emptyTransactionsInfoView?.removeFromSuperview()
                    })
                }
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else {
                if let transactionsSectionView = self.transactionsSection.view, transactionsSectionView.superview != nil {
                    transition.setAlpha(view: transactionsSectionView, alpha: 0.0, completion: { [weak transactionsSectionView] _ in
                        transactionsSectionView?.removeFromSuperview()
                    })
                }

                //TODO:localize
                let instantTransfersTitle = "Send Money Instantly"
                //TODO:localize
                let instantTransfersText = "Send Grams in any chat, just like\nsharing a photo."
                //TODO:localize
                let zeroFeesTitle = "No Fees"
                //TODO:localize
                let zeroFeesText = "First 5 transfers each day are free, the\u{00a0}rest cost almost nothing."
                //TODO:localize
                let blockchainVerifiedTitle = "Blockchain Verified"
                //TODO:localize
                let blockchainVerifiedText = "All transactions are recorded\nand verifiable on a public ledger."

                let titleColor = environment.theme.actionSheet.primaryTextColor
                let textColor = environment.theme.actionSheet.secondaryTextColor
                let accentColor = environment.theme.list.itemAccentColor
                let emptyItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(
                        id: "instantTransfers",
                        component: AnyComponent(InfoParagraphComponent(
                            title: instantTransfersTitle,
                            titleColor: titleColor,
                            text: instantTransfersText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoFast",
                            iconColor: accentColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "zeroFees",
                        component: AnyComponent(InfoParagraphComponent(
                            title: zeroFeesTitle,
                            titleColor: titleColor,
                            text: zeroFeesText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoCheap",
                            iconColor: accentColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "blockchainVerified",
                        component: AnyComponent(InfoParagraphComponent(
                            title: blockchainVerifiedTitle,
                            titleColor: titleColor,
                            text: blockchainVerifiedText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoVerified",
                            iconColor: accentColor
                        ))
                    )
                ]

                let emptyTransactionsOriginY = contentHeight + 36.0
                self.emptyTransactionsInfo.parentState = state
                let emptyTransactionsInfoSize = self.emptyTransactionsInfo.update(
                    transition: transition,
                    component: AnyComponent(List(emptyItems)),
                    environment: {},
                    containerSize: CGSize(width: cardWidth - 64.0, height: 10000.0)
                )
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view {
                    var wasVisible = true
                    if emptyTransactionsInfoView.superview == nil {
                        wasVisible = false
                        self.scrollView.addSubview(emptyTransactionsInfoView)
                    }
                    if !transition.animation.isImmediate && !wasVisible {
                        transition.animateAlpha(view: emptyTransactionsInfoView, from: 0.0, to: 1.0)
                    } else {
                        transition.setAlpha(view: emptyTransactionsInfoView, alpha: 1.0)
                    }

                    var layoutTransition = transition
                    if !wasVisible {
                        layoutTransition = .immediate
                    }
                    layoutTransition.setFrame(
                        view: emptyTransactionsInfoView,
                        frame: CGRect(
                            origin: CGPoint(x: floor((availableSize.width - emptyTransactionsInfoSize.width) / 2.0), y: emptyTransactionsOriginY),
                            size: emptyTransactionsInfoSize
                        )
                    )
                }
                contentHeight = emptyTransactionsOriginY + emptyTransactionsInfoSize.height
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.plainBackgroundColor)
            }

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            contentHeight += 24.0 + environment.safeInsets.bottom
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(
                top: headerOriginY + headerSize.height,
                left: 0.0,
                bottom: environment.safeInsets.bottom,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }

            self.updateScrolling(transition: transition)

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
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

public final class WalletScreen: ViewControllerComponentContainer {
    public init(context: AccountContext) {
        super.init(
            context: context,
            component: WalletScreenComponent(
                context: context,
                walletContext: WalletContext(address: "UQDYzZmfsrGzhObKJUw4gzdeIxEai3jAFbiGKGwxvxHinf4K")
            ),
            navigationBarAppearance: .transparent,
            statusBarStyle: .default,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? WalletScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WalletContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            actionsPosition: .bottom
        )
    }
}
