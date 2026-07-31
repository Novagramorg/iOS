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
import WalletCollectibleItemComponent
import WalletTransactionItemComponent
import InfoParagraphComponent
import MultilineTextComponent
import HorizontalTabsComponent
import GlassBackgroundComponent
import WalletSendScreen

private let walletSectionOverscan: CGFloat = 100.0
private let walletTransactionItemHeight: CGFloat = 79.0
private let walletCollectibleTransactionItemHeight: CGFloat = 132.0
private let walletCollectibleItemHeight: CGFloat = 58.0

private struct WalletItemsLayout {
    let itemOffsets: [CGFloat]

    var itemCount: Int {
        return self.itemOffsets.count - 1
    }

    var contentHeight: CGFloat {
        return self.itemOffsets.last ?? 0.0
    }

    init(itemHeights: [CGFloat]) {
        var itemOffsets: [CGFloat] = [0.0]
        itemOffsets.reserveCapacity(itemHeights.count + 1)
        for itemHeight in itemHeights {
            itemOffsets.append(itemOffsets[itemOffsets.count - 1] + itemHeight)
        }
        self.itemOffsets = itemOffsets
    }

    func itemOffset(at index: Int) -> CGFloat {
        return self.itemOffsets[index]
    }

    func visibleItems(for rect: CGRect) -> Range<Int>? {
        guard self.itemCount != 0, rect.maxY > 0.0, rect.minY < self.contentHeight else {
            return nil
        }

        let minY = max(0.0, rect.minY)
        let maxY = min(self.contentHeight, rect.maxY)

        var lowerBound = 0
        var upperBound = self.itemCount
        while lowerBound < upperBound {
            let index = (lowerBound + upperBound) / 2
            if self.itemOffsets[index + 1] <= minY {
                lowerBound = index + 1
            } else {
                upperBound = index
            }
        }
        let minIndex = lowerBound

        lowerBound = minIndex
        upperBound = self.itemCount
        while lowerBound < upperBound {
            let index = (lowerBound + upperBound) / 2
            if self.itemOffsets[index] < maxY {
                lowerBound = index + 1
            } else {
                upperBound = index
            }
        }
        let maxIndex = lowerBound

        if minIndex < maxIndex {
            return minIndex ..< maxIndex
        } else {
            return nil
        }
    }
}

private final class LazySectionView: UIView {
    struct Item {
        let id: AnyHashable
        let height: CGFloat
        let component: () -> AnyComponent<Empty>
    }

    private enum PlaceholderId: Hashable {
        case top
        case bottom
    }

    private let contentView: ListSectionContentView
    private let topPlaceholderView: ListSectionContentView.ItemView
    private let bottomPlaceholderView: ListSectionContentView.ItemView
    private var footer: ComponentView<Empty>?

    private var items: [Item] = []
    private var itemLayout = WalletItemsLayout(itemHeights: [])
    private var configuration: ListSectionContentView.Configuration?
    private weak var state: EmptyComponentState?
    private var width: CGFloat = 0.0
    private var currentVisibleRange: Range<Int>?

    override init(frame: CGRect) {
        self.contentView = ListSectionContentView(frame: CGRect())
        self.topPlaceholderView = ListSectionContentView.ItemView()
        self.bottomPlaceholderView = ListSectionContentView.ItemView()

        super.init(frame: frame)

        self.addSubview(self.contentView.externalContentBackgroundView)
        self.addSubview(self.contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        theme: PresentationTheme,
        state: EmptyComponentState,
        items: [Item],
        footer footerComponent: AnyComponent<Empty>?,
        width: CGFloat,
        visibleBounds: CGRect,
        transition: ComponentTransition
    ) -> CGSize {
        self.items = items
        self.itemLayout = WalletItemsLayout(itemHeights: items.map(\.height))
        self.configuration = ListSectionContentView.Configuration(
            theme: theme,
            style: .glass,
            displaySeparators: true,
            extendsItemHighlightToSection: false,
            background: .all
        )
        self.state = state
        self.width = width

        self.updateVisibleBounds(visibleBounds, force: true, transition: transition)

        var contentHeight = self.itemLayout.contentHeight
        if let footerComponent {
            let footer: ComponentView<Empty>
            var footerTransition = transition
            if let current = self.footer {
                footer = current
            } else {
                footer = ComponentView()
                self.footer = footer
                footerTransition = footerTransition.withAnimation(.none)
            }
            footer.parentState = state
            let footerSize = footer.update(
                transition: footerTransition,
                component: footerComponent,
                environment: {},
                containerSize: CGSize(width: max(0.0, width - 32.0), height: 1000.0)
            )
            if contentHeight != 0.0 {
                contentHeight += 8.0 - UIScreenPixel
            }
            if let footerView = footer.view {
                if footerView.superview == nil {
                    self.addSubview(footerView)
                }
                footerTransition.setFrame(
                    view: footerView,
                    frame: CGRect(
                        origin: CGPoint(x: 16.0, y: contentHeight),
                        size: footerSize
                    )
                )
            }
            contentHeight += footerSize.height
        } else if let footer = self.footer {
            self.footer = nil
            footer.view?.removeFromSuperview()
        }

        return CGSize(width: width, height: contentHeight)
    }

    func updateVisibleBounds(_ visibleBounds: CGRect, force: Bool = false, transition: ComponentTransition) {
        guard let configuration = self.configuration, let state = self.state else {
            return
        }

        let visibleRange = self.itemLayout.visibleItems(for: visibleBounds)
        if !force && self.currentVisibleRange == visibleRange {
            return
        }
        self.currentVisibleRange = visibleRange
        var readyItems: [ListSectionContentView.ReadyItem] = []
        if let visibleRange {
            let topHeight = self.itemLayout.itemOffset(at: visibleRange.lowerBound)
            if topHeight != 0.0 {
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: AnyHashable(PlaceholderId.top),
                    itemView: self.topPlaceholderView,
                    size: CGSize(width: self.width, height: topHeight),
                    transition: .immediate
                ))
            }

            for index in visibleRange {
                let item = self.items[index]
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.contentView.itemViews[item.id] {
                    itemView = current
                } else {
                    itemView = ListSectionContentView.ItemView()
                    self.contentView.itemViews[item.id] = itemView
                    itemView.contents.parentState = state
                    itemTransition = .immediate
                }

                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component(),
                    environment: {},
                    containerSize: CGSize(width: self.width, height: item.height)
                )
                assert(
                    abs(itemSize.height - item.height) <= UIScreenPixel,
                    "Unexpected wallet item height: expected \(item.height), got \(itemSize.height)"
                )
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: item.id,
                    itemView: itemView,
                    size: CGSize(width: self.width, height: item.height),
                    transition: itemTransition
                ))
            }

            let bottomHeight = self.itemLayout.contentHeight - self.itemLayout.itemOffset(at: visibleRange.upperBound)
            if bottomHeight != 0.0 {
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: AnyHashable(PlaceholderId.bottom),
                    itemView: self.bottomPlaceholderView,
                    size: CGSize(width: self.width, height: bottomHeight),
                    transition: .immediate
                ))
            }
        } else if self.itemLayout.contentHeight != 0.0 {
            readyItems.append(ListSectionContentView.ReadyItem(
                id: AnyHashable(PlaceholderId.top),
                itemView: self.topPlaceholderView,
                size: CGSize(width: self.width, height: self.itemLayout.contentHeight),
                transition: .immediate
            ))
        }

        let updateResult = self.contentView.update(
            configuration: configuration,
            width: self.width,
            leftInset: 0.0,
            readyItems: readyItems,
            transition: transition
        )
        transition.setFrame(
            view: self.contentView,
            frame: CGRect(origin: CGPoint(), size: updateResult.size)
        )
    }

    func clearVisibleItems() {
        self.updateVisibleBounds(
            CGRect(x: 0.0, y: self.itemLayout.contentHeight, width: self.width, height: 0.0),
            force: true,
            transition: .immediate
        )
    }
}

private final class WalletScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let routeToSetup: ((ViewController) -> Void)?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        routeToSetup: ((ViewController) -> Void)?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.routeToSetup = routeToSetup
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
        private enum SelectedSection: Equatable {
            case transactions
            case collectibles
        }

        private let scrollView: ScrollView
        private let topEdgeEffectView: EdgeEffectView
        private let header = ComponentView<Empty>()
        private let card = ComponentView<Empty>()
        private let addFundsButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let transactionTabsBackgroundView = GlassBackgroundView()
        private let transactionTabs = ComponentView<Empty>()
        private let transactionsSection = LazySectionView()
        private let collectiblesSection = LazySectionView()
        private let emptyTransactionsInfo = ComponentView<Empty>()

        private var component: WalletScreenComponent?
        private var environment: EnvironmentType?
        private var componentState: EmptyComponentState?

        private var walletContext: WalletContext?
        private var walletState: WalletContext.State?
        private var walletStateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private var accountContext: AccountContext?
        private var accountName = ""
        private var accountPeerDisposable: Disposable?
        private var isUpdating = false
        private var didRequestSetup = false
        private var selectedSection: SelectedSection = .transactions

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
            self.loadMoreDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            self.updateScrolling(transition: .immediate)
            self.updateVisibleSections(transition: .immediate)
            if scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - 240.0 {
                self.loadMoreItemsIfNeeded()
            }
        }

        private func visibleBounds(for sectionFrame: CGRect, viewportSize: CGSize) -> CGRect {
            return CGRect(origin: self.scrollView.contentOffset, size: viewportSize)
                .insetBy(dx: 0.0, dy: -walletSectionOverscan)
                .offsetBy(dx: -sectionFrame.minX, dy: -sectionFrame.minY)
        }

        private func updateVisibleSections(transition: ComponentTransition) {
            switch self.selectedSection {
            case .transactions:
                if self.transactionsSection.superview != nil {
                    self.transactionsSection.updateVisibleBounds(
                        self.visibleBounds(for: self.transactionsSection.frame, viewportSize: self.scrollView.bounds.size),
                        transition: transition
                    )
                }
            case .collectibles:
                if self.collectiblesSection.superview != nil {
                    self.collectiblesSection.updateVisibleBounds(
                        self.visibleBounds(for: self.collectiblesSection.frame, viewportSize: self.scrollView.bounds.size),
                        transition: transition
                    )
                }
            }
        }

        private func hideSection(_ section: LazySectionView, transition: ComponentTransition) {
            guard section.superview != nil else {
                section.clearVisibleItems()
                return
            }
            transition.setAlpha(view: section, alpha: 0.0, completion: { [weak section] _ in
                guard let section, section.alpha == 0.0 else {
                    return
                }
                section.removeFromSuperview()
                section.clearVisibleItems()
            })
        }

        private var walletInfo: WalletContext.WalletInfo? {
            guard let walletState = self.walletState else {
                return nil
            }
            if case let .wallet(info) = walletState.phase {
                return info
            }
            return nil
        }

        private func routeToSetupIfNeeded() {
            guard !self.didRequestSetup,
                  let walletState = self.walletState,
                  case .empty = walletState.phase,
                  let component = self.component,
                  let routeToSetup = component.routeToSetup,
                  let controller = self.environment?.controller() else {
                return
            }
            self.didRequestSetup = true
            Queue.mainQueue().after(0.0) { [weak self, weak controller] in
                guard let self, let controller,
                      let walletState = self.walletState,
                      case .empty = walletState.phase else {
                    self?.didRequestSetup = false
                    return
                }
                routeToSetup(controller)
            }
        }

        private func loadMoreItemsIfNeeded() {
            guard let component = self.component,
                  let walletState = self.walletState,
                  walletState.activeOperation == nil else {
                return
            }
            switch self.selectedSection {
            case .transactions:
                guard walletState.transactions.canLoadMore, !walletState.transactions.isLoadingMore else {
                    return
                }
                self.loadMoreDisposable.set(component.walletContext.loadMoreTransactions().start())
            case .collectibles:
                guard walletState.collectibles.canLoadMore, !walletState.collectibles.isLoadingMore else {
                    return
                }
                self.loadMoreDisposable.set(component.walletContext.loadMoreCollectibles().start())
            }
        }

        private func updateTransactionTabs(
            component: WalletScreenComponent,
            environment: EnvironmentType,
            state: EmptyComponentState,
            availableWidth: CGFloat,
            containerWidth: CGFloat,
            originY: CGFloat,
            transition: ComponentTransition
        ) -> CGSize {
            var tabsTransition = transition
            if self.transactionTabs.view?.superview == nil {
                tabsTransition = .immediate
            }

            //TODO:localize
            let transactionsTitle = "Transactions"
            //TODO:localize
            let collectiblesTitle = "Collectibles"
            let transactionsTabId = AnyHashable("transactions")
            let collectiblesTabId = AnyHashable("collectibles")
            self.transactionTabs.parentState = state
            let tabsSize = self.transactionTabs.update(
                transition: tabsTransition,
                component: AnyComponent(HorizontalTabsComponent(
                    context: component.context,
                    theme: environment.theme,
                    tabs: [
                        HorizontalTabsComponent.Tab(
                            id: transactionsTabId,
                            content: .title(HorizontalTabsComponent.Tab.Title(
                                text: transactionsTitle,
                                entities: [],
                                enableAnimations: false
                            )),
                            badge: nil,
                            action: { [weak self] in
                                guard let self, self.selectedSection != .transactions else {
                                    return
                                }
                                self.selectedSection = .transactions
                                self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        ),
                        HorizontalTabsComponent.Tab(
                            id: collectiblesTabId,
                            content: .title(HorizontalTabsComponent.Tab.Title(
                                text: collectiblesTitle,
                                entities: [],
                                enableAnimations: false
                            )),
                            badge: nil,
                            action: { [weak self] in
                                guard let self, self.selectedSection != .collectibles else {
                                    return
                                }
                                self.selectedSection = .collectibles
                                self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        )
                    ],
                    selectedTab: self.selectedSection == .transactions ? transactionsTabId : collectiblesTabId,
                    isEditing: false,
                    layout: .fit,
                    liftWhileSwitching: false
                )),
                environment: {},
                containerSize: CGSize(width: containerWidth, height: 40.0)
            )
            let tabsFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableWidth - tabsSize.width) / 2.0),
                    y: originY
                ),
                size: tabsSize
            )
            let backgroundFrame = CGRect(
                x: tabsFrame.minX,
                y: tabsFrame.minY + floorToScreenPixels((tabsFrame.height - 40.0) / 2.0),
                width: tabsFrame.width,
                height: 40.0
            )
            let wasVisible = self.transactionTabsBackgroundView.superview != nil
            if self.transactionTabsBackgroundView.superview == nil {
                self.scrollView.addSubview(self.transactionTabsBackgroundView)
            }
            tabsTransition.setFrame(view: self.transactionTabsBackgroundView, frame: backgroundFrame)
            self.transactionTabsBackgroundView.update(
                size: backgroundFrame.size,
                cornerRadius: 20.0,
                isDark: environment.theme.overallDarkAppearance,
                tintColor: .init(kind: .panel),
                isInteractive: true,
                transition: tabsTransition
            )
            if !wasVisible && !transition.animation.isImmediate {
                transition.animateAlpha(view: self.transactionTabsBackgroundView, from: 0.0, to: 1.0)
            } else {
                transition.setAlpha(view: self.transactionTabsBackgroundView, alpha: 1.0)
            }
            if let tabsView = self.transactionTabs.view as? HorizontalTabsComponent.View {
                if tabsView.superview !== self.transactionTabsBackgroundView.contentView {
                    self.transactionTabsBackgroundView.contentView.addSubview(tabsView)
                    tabsView.setOverlayContainerView(overlayContainerView: self.scrollView)
                }
                tabsTransition.setFrame(
                    view: tabsView,
                    frame: CGRect(
                        x: tabsFrame.minX - backgroundFrame.minX,
                        y: tabsFrame.minY - backgroundFrame.minY,
                        width: tabsFrame.width,
                        height: tabsFrame.height
                    )
                )
                if !wasVisible && !transition.animation.isImmediate {
                    transition.animateAlpha(view: tabsView, from: 0.0, to: 1.0)
                } else {
                    transition.setAlpha(view: tabsView, alpha: 1.0)
                }
            }
            return tabsSize
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
            //TODO:localize
            let scannerInfo = "Find QR that contains a wallet address\nor connect an app"
            let scanner = QrCodeScanScreen(context: component.context, subject: .customValidated(
                info: scannerInfo,
                validate: { value in
                    return WalletContext.isTonConnectUrl(value)
                        || QrCodeScanScreen.normalizedCryptoAddress(value) != nil
                }
            ))
            scanner.completion = { [weak self] value in
                guard let value else {
                    return
                }
                if WalletContext.isTonConnectUrl(value) {
                    Queue.mainQueue().after(0.25) {
                        component.walletContext.processTonConnectUrl(value)
                    }
                    return
                }
                guard let value = QrCodeScanScreen.normalizedCryptoAddress(value) else {
                    return
                }
                Queue.mainQueue().after(0.25) { [weak self] in
                    self?.openSend(address: value)
                }
            }
            controller.push(scanner)
        }

        private func openReceive() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            guard let walletInfo = self.walletInfo else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: walletInfo.address
            ))
        }

        private func openSend(address: String? = nil) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.walletInfo != nil else {
                return
            }
            let sendScreen = WalletSendScreen(context: component.context, walletContext: component.walletContext, address: address)
            sendScreen.navigationPresentation = .modal
            controller.push(sendScreen)
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
                walletContext: component.walletContext,
                mode: .transaction(transaction)
            ))
        }

        private func openCollectible(_ collectible: WalletContext.Collectible) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletCollectibleScreen(
                context: component.context,
                walletContext: component.walletContext,
                collectible: collectible
            ))
        }

        private func openContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

            //TODO:localize
            let currency = "Currency"
            //TODO:localize
            let passcode = "Passcode & Face ID"
            //TODO:localize
            let keysAndBackup = "Keys & Backup"
            //TODO:localize
            let howItWorks = "How It Works"

            let currencies: [(currency: WalletContext.FiatCurrency, name: String)] = [
                //TODO:localize
                (.usd, "US Dollar"),
                //TODO:localize
                (.eur, "Euro"),
                //TODO:localize
                (.rub, "Russian Ruble"),
                //TODO:localize
                (.cny, "Chinese Yuan")
            ]
            let selectedCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
            var currencyItems: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: presentationData.strings.Common_Back,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/Back"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    iconPosition: .left,
                    action: { contextController, _ in
                        contextController?.popItems()
                    }
                )),
                .separator
            ]
            currencyItems.append(contentsOf: currencies.map { currency -> ContextMenuItem in
                return .action(ContextMenuActionItem(
                    text: currency.currency.rawValue,
                    textLayout: .secondLineWithValue(currency.name),
                    icon: { _ in
                        return nil
                    },
                    additionalLeftIcon: { theme in
                        if currency.currency == selectedCurrency {
                            return generateTintedImage(
                                image: UIImage(bundleImageName: "Chat/Context Menu/Check"),
                                color: theme.contextMenu.primaryColor
                            )
                        } else {
                            return UIImage()
                        }
                    },
                    action: { [weak self] _, dismiss in
                        self?.component?.walletContext.setFiatCurrency(currency.currency)
                        dismiss(.default)
                    }
                ))
            })

            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: currency,
                    textLayout: .secondLineWithValue(selectedCurrency.rawValue),
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Globe"), color: theme.contextMenu.primaryColor)
                    },
                    additionalLeftIcon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Arrow"), color: theme.contextMenu.primaryColor)
                    },
                    action: { contextController, _ in
                        contextController?.pushItems(items: .single(ContextController.Items(content: .list(currencyItems))))
                    }
                )),
                .action(ContextMenuActionItem(
                    text: passcode,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FaceId"), color: theme.contextMenu.primaryColor)
                    },
                    action: { _, dismiss in
                        dismiss(.default)
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
                presentationData: presentationData,
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
                    self.routeToSetupIfNeeded()
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
                origin: CGPoint(x: 0.0, y: -20.0),
                size: CGSize(width: availableSize.width, height: 20.0 + topEdgeEffectHeight + 24.0)
            )
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(
                content: environment.theme.list.blocksBackgroundColor,
                blur: true,
                rect: CGRect(origin: CGPoint(), size: topEdgeEffectFrame.size),
                edge: .top,
                edgeSize: 64.0,
                transition: transition
            )

            let sideInset: CGFloat = 16.0
            let cardWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right - sideInset * 2.0
            )
            let cardOriginY = headerOriginY + headerSize.height + 10.0
            let walletInfo = self.walletInfo
            let fiatCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = self.walletState?.fiat.selectedRate
            self.card.parentState = state
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletCardComponent(
                    balance: self.walletState?.balance.currentValue,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: self.accountName,
                    address: walletInfo?.address ?? "",
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
                    action: { [weak self] in
                        #if DEBUG
                        self?.openSend(address: "")
                        #else
                        self?.openSend()
                        #endif
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

            let buttonsHeight = max(addFundsButtonSize.height, sendButtonSize.height)
            var contentHeight = buttonsOriginY + buttonsHeight

            let transactions = (self.walletState?.transactions.items ?? []).filter(\.isVisibleInWalletHistory)
            let collectibles = self.walletState?.collectibles.items ?? []
            if collectibles.isEmpty && self.selectedSection == .collectibles {
                self.selectedSection = .transactions
            }
            if !collectibles.isEmpty {
                let transactionTabsOriginY = contentHeight + 12.0
                let transactionTabsSize = self.updateTransactionTabs(
                    component: component,
                    environment: environment,
                    state: state,
                    availableWidth: availableSize.width,
                    containerWidth: cardWidth,
                    originY: transactionTabsOriginY,
                    transition: transition
                )
                contentHeight = transactionTabsOriginY + transactionTabsSize.height
            } else if self.transactionTabsBackgroundView.superview != nil {
                self.transactionTabsBackgroundView.removeFromSuperview()
            }

            if self.selectedSection == .transactions && !transactions.isEmpty {
                self.hideSection(self.collectiblesSection, transition: transition)

                let itemContext = component.context
                let itemTheme = environment.theme
                let itemStrings = environment.strings
                let itemDateTimeFormat = environment.dateTimeFormat
                let items: [LazySectionView.Item] = transactions.map { transaction in
                    return LazySectionView.Item(
                        id: AnyHashable(transaction.id),
                        height: transaction.collectible == nil ? walletTransactionItemHeight : walletCollectibleTransactionItemHeight,
                        component: { [weak self] in
                            return AnyComponent(ListActionItemComponent(
                                theme: itemTheme,
                                style: .glass,
                                title: AnyComponent(WalletTransactionItemComponent(
                                    context: itemContext,
                                    theme: itemTheme,
                                    strings: itemStrings,
                                    dateTimeFormat: itemDateTimeFormat,
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
                        }
                    )
                }

                let transactionsOriginY = contentHeight + 12.0
                let transactionsFrame = CGRect(
                    origin: CGPoint(x: environment.safeInsets.left + sideInset, y: transactionsOriginY),
                    size: CGSize(width: cardWidth, height: 0.0)
                )
                let wasVisible = self.transactionsSection.superview != nil
                let transactionsSectionSize = self.transactionsSection.update(
                    theme: environment.theme,
                    state: state,
                    items: items,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Tap on a transaction to view details.",
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    width: cardWidth,
                    visibleBounds: self.visibleBounds(for: transactionsFrame, viewportSize: availableSize),
                    transition: wasVisible ? transition : .immediate
                )
                if !wasVisible {
                    self.transactionsSection.alpha = 1.0
                    self.scrollView.addSubview(self.transactionsSection)
                }
                if !wasVisible && !transition.animation.isImmediate {
                    self.transactionsSection.layer.allowsGroupOpacity = true
                    transition.animateAlpha(view: self.transactionsSection, from: 0.0, to: 1.0, completion: { [weak transactionsSection = self.transactionsSection] _ in
                        transactionsSection?.layer.allowsGroupOpacity = false
                    })
                } else {
                    transition.setAlpha(view: self.transactionsSection, alpha: 1.0)
                }
                let transactionsLayoutTransition: ComponentTransition = wasVisible ? transition : .immediate
                transactionsLayoutTransition.setFrame(
                    view: self.transactionsSection,
                    frame: CGRect(origin: transactionsFrame.origin, size: transactionsSectionSize)
                )
                contentHeight = transactionsOriginY + transactionsSectionSize.height
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view, emptyTransactionsInfoView.superview != nil {
                    transition.setAlpha(view: emptyTransactionsInfoView, alpha: 0.0, completion: { [weak emptyTransactionsInfoView] _ in
                        emptyTransactionsInfoView?.removeFromSuperview()
                    })
                }
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else if self.selectedSection == .collectibles {
                self.hideSection(self.transactionsSection, transition: transition)
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view {
                    emptyTransactionsInfoView.removeFromSuperview()
                }

                let itemContext = component.context
                let itemTheme = environment.theme
                let items: [LazySectionView.Item] = collectibles.map { collectible in
                    return LazySectionView.Item(
                        id: AnyHashable(collectible.address),
                        height: walletCollectibleItemHeight,
                        component: { [weak self] in
                            return AnyComponent(ListActionItemComponent(
                                theme: itemTheme,
                                style: .glass,
                                title: AnyComponent(WalletCollectibleItemComponent(
                                    context: itemContext,
                                    theme: itemTheme,
                                    collectible: collectible
                                )),
                                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0),
                                separatorInset: 60.0,
                                icon: nil,
                                accessory: nil,
                                action: { [weak self] _ in
                                    self?.openCollectible(collectible)
                                },
                                highlighting: .default
                            ))
                        }
                    )
                }

                let collectiblesOriginY = contentHeight + 12.0
                let collectiblesFrame = CGRect(
                    origin: CGPoint(x: environment.safeInsets.left + sideInset, y: collectiblesOriginY),
                    size: CGSize(width: cardWidth, height: 0.0)
                )
                let wasVisible = self.collectiblesSection.superview != nil
                let collectiblesSectionSize = self.collectiblesSection.update(
                    theme: environment.theme,
                    state: state,
                    items: items,
                    footer: nil,
                    width: cardWidth,
                    visibleBounds: self.visibleBounds(for: collectiblesFrame, viewportSize: availableSize),
                    transition: wasVisible ? transition : .immediate
                )
                if !wasVisible {
                    self.collectiblesSection.alpha = 1.0
                    self.scrollView.addSubview(self.collectiblesSection)
                }
                if !wasVisible && !transition.animation.isImmediate {
                    self.collectiblesSection.layer.allowsGroupOpacity = true
                    transition.animateAlpha(view: self.collectiblesSection, from: 0.0, to: 1.0, completion: { [weak collectiblesSection = self.collectiblesSection] _ in
                        collectiblesSection?.layer.allowsGroupOpacity = false
                    })
                } else {
                    transition.setAlpha(view: self.collectiblesSection, alpha: 1.0)
                }
                let collectiblesLayoutTransition: ComponentTransition = wasVisible ? transition : .immediate
                collectiblesLayoutTransition.setFrame(
                    view: self.collectiblesSection,
                    frame: CGRect(origin: collectiblesFrame.origin, size: collectiblesSectionSize)
                )
                contentHeight = collectiblesOriginY + collectiblesSectionSize.height

                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else {
                if collectibles.isEmpty && self.transactionTabsBackgroundView.superview != nil {
                    self.transactionTabsBackgroundView.removeFromSuperview()
                }
                self.collectiblesSection.removeFromSuperview()
                self.collectiblesSection.clearVisibleItems()
                self.hideSection(self.transactionsSection, transition: transition)

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
            self.updateVisibleSections(transition: .immediate)

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
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        routeToSetup: ((ViewController) -> Void)? = nil
    ) {
        super.init(
            context: context,
            component: WalletScreenComponent(
                context: context,
                walletContext: walletContext,
                routeToSetup: routeToSetup
            ),
            navigationBarAppearance: .transparent,
            statusBarStyle: .default,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)

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
