import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import TextFormat
import ComponentFlow
import ViewControllerComponent
import ChatListHeaderComponent
import BundleIconComponent
import QrCodeUI
import ContextUI
import SwiftSignalKit
import TelegramCore
import TelegramNotices
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
import WalletPeerSelectionScreen
import TooltipUI
import SettingsUI
import UndoUI
import WalletAuthorizationUI

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

private final class WalletNavigationBalanceComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let balance: Int64?
    let fiatCurrency: WalletContext.FiatCurrency
    let fiatRate: WalletContext.FiatRate?
    let dateTimeFormat: PresentationDateTimeFormat

    init(
        theme: PresentationTheme,
        balance: Int64?,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat
    ) {
        self.theme = theme
        self.balance = balance
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
    }

    static func ==(lhs: WalletNavigationBalanceComponent, rhs: WalletNavigationBalanceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.fiatCurrency != rhs.fiatCurrency || lhs.fiatRate != rhs.fiatRate {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        return true
    }

    final class View: UIView {
        private let primaryCollapseContainerView = UIView()
        private let secondaryCollapseContainerView = UIView()
        private let primaryContainerView = UIView()
        private let secondaryContainerView = UIView()
        private let balanceText = ComponentView<Empty>()
        private let gramIcon = ComponentView<Empty>()
        private let fiatText = ComponentView<Empty>()

        var primaryTargetFrame: CGRect = .zero
        var secondaryTargetFrame: CGRect = .zero

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.clipsToBounds = false
            self.primaryCollapseContainerView.clipsToBounds = false
            self.secondaryCollapseContainerView.clipsToBounds = false
            self.primaryContainerView.clipsToBounds = false
            self.secondaryContainerView.clipsToBounds = false
            self.addSubview(self.primaryCollapseContainerView)
            self.addSubview(self.secondaryCollapseContainerView)
            self.primaryCollapseContainerView.addSubview(self.primaryContainerView)
            self.secondaryCollapseContainerView.addSubview(self.secondaryContainerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletNavigationBalanceComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let formattedBalance: String
            if let balance = component.balance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                formattedBalance = "0"
            }

            let formattedFiatBalance: String
            if let balance = component.balance, let fiatRate = component.fiatRate {
                formattedFiatBalance = formatTonFiatValue(
                    balance,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: balance == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                formattedFiatBalance = "—"
            }

            let primaryColor = component.theme.rootController.navigationBar.primaryTextColor
            let secondaryColor = component.theme.rootController.navigationBar.secondaryTextColor
            let iconSize = self.gramIcon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: "Wallet/TopGram",
                    tintColor: nil,
                    maxSize: CGSize(width: 20.0, height: 20.0)
                )),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 20.0)
            )
            let balanceSpacing: CGFloat = 2.0
            let balanceSize = self.balanceText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: formattedBalance,
                        font: Font.semibold(17.0),
                        textColor: primaryColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - balanceSpacing - iconSize.width),
                    height: availableSize.height
                )
            )
            let fiatSize = self.fiatText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: formattedFiatBalance,
                        font: Font.regular(13.0),
                        textColor: secondaryColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )

            let balanceRowSize = CGSize(
                width: balanceSize.width + balanceSpacing + iconSize.width,
                height: max(balanceSize.height, iconSize.height)
            )
            let verticalSpacing: CGFloat = 0.0
            let size = CGSize(
                width: max(balanceRowSize.width, fiatSize.width),
                height: balanceRowSize.height + verticalSpacing + fiatSize.height
            )

            for collapseContainerView in [self.primaryCollapseContainerView, self.secondaryCollapseContainerView] {
                ComponentTransition.immediate.setBounds(
                    view: collapseContainerView,
                    bounds: CGRect(origin: CGPoint(), size: size)
                )
                ComponentTransition.immediate.setPosition(
                    view: collapseContainerView,
                    position: CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                )
            }

            self.primaryTargetFrame = CGRect(
                origin: CGPoint(
                    x: floor((size.width - balanceRowSize.width) * 0.5),
                    y: 0.0
                ),
                size: balanceRowSize
            )
            self.secondaryTargetFrame = CGRect(
                origin: CGPoint(
                    x: floor((size.width - fiatSize.width) * 0.5),
                    y: balanceRowSize.height + verticalSpacing
                ),
                size: fiatSize
            )
            ComponentTransition.immediate.setBounds(
                view: self.primaryContainerView,
                bounds: CGRect(origin: CGPoint(), size: balanceRowSize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.primaryContainerView,
                position: self.primaryTargetFrame.center
            )
            ComponentTransition.immediate.setBounds(
                view: self.secondaryContainerView,
                bounds: CGRect(origin: CGPoint(), size: fiatSize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.secondaryContainerView,
                position: self.secondaryTargetFrame.center
            )

            if let balanceTextView = self.balanceText.view {
                if balanceTextView.superview !== self.primaryContainerView {
                    self.primaryContainerView.addSubview(balanceTextView)
                }
                transition.setFrame(
                    view: balanceTextView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: iconSize.width + balanceSpacing,
                            y: floor((balanceRowSize.height - balanceSize.height) * 0.5)
                        ),
                        size: balanceSize
                    )
                )
            }
            if let gramIconView = self.gramIcon.view {
                if gramIconView.superview !== self.primaryContainerView {
                    self.primaryContainerView.addSubview(gramIconView)
                }
                transition.setFrame(
                    view: gramIconView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: 0.0,
                            y: floor((balanceRowSize.height - iconSize.height) * 0.5) - UIScreenPixel
                        ),
                        size: iconSize
                    )
                )
            }
            if let fiatTextView = self.fiatText.view {
                if fiatTextView.superview !== self.secondaryContainerView {
                    self.secondaryContainerView.addSubview(fiatTextView)
                }
                transition.setFrame(
                    view: fiatTextView,
                    frame: CGRect(origin: CGPoint(), size: fiatSize)
                )
            }

            return size
        }

        func updateTransitionFrames(
            primaryFrame: CGRect?,
            secondaryFrame: CGRect?,
            isCollapsed: Bool,
            transition: ComponentTransition
        ) {
            self.updateTransitionContainer(
                self.primaryCollapseContainerView,
                self.primaryContainerView,
                targetFrame: self.primaryTargetFrame,
                currentFrame: primaryFrame,
                isCollapsed: isCollapsed,
                transition: transition
            )
            self.updateTransitionContainer(
                self.secondaryCollapseContainerView,
                self.secondaryContainerView,
                targetFrame: self.secondaryTargetFrame,
                currentFrame: secondaryFrame,
                isCollapsed: isCollapsed,
                transition: transition
            )
        }

        private func updateTransitionContainer(
            _ collapseContainerView: UIView,
            _ containerView: UIView,
            targetFrame: CGRect,
            currentFrame: CGRect?,
            isCollapsed: Bool,
            transition: ComponentTransition
        ) {
            guard !targetFrame.isEmpty,
                  let currentFrame,
                  !currentFrame.isEmpty,
                  currentFrame.width.isFinite,
                  currentFrame.height.isFinite else {
                ComponentTransition.immediate.setPosition(view: containerView, position: targetFrame.center)
                ComponentTransition.immediate.setTransform(view: containerView, transform: CATransform3DIdentity)
                transition.setTransform(view: collapseContainerView, transform: CATransform3DIdentity)
                return
            }

            let scaleX = currentFrame.width / targetFrame.width
            let scaleY = currentFrame.height / targetFrame.height
            ComponentTransition.immediate.setPosition(view: containerView, position: currentFrame.center)
            ComponentTransition.immediate.setTransform(
                view: containerView,
                transform: CATransform3DMakeScale(scaleX, scaleY, 1.0)
            )
            transition.setTransform(
                view: collapseContainerView,
                transform: isCollapsed ? self.collapseTransform(
                    in: collapseContainerView,
                    from: currentFrame,
                    to: targetFrame
                ) : CATransform3DIdentity
            )
        }

        private func collapseTransform(in containerView: UIView, from sourceFrame: CGRect, to targetFrame: CGRect) -> CATransform3D {
            let scaleX = targetFrame.width / sourceFrame.width
            let scaleY = targetFrame.height / sourceFrame.height
            let anchor = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
            var transform = CATransform3DMakeScale(scaleX, scaleY, 1.0)
            transform.m41 = targetFrame.midX - anchor.x - (sourceFrame.midX - anchor.x) * scaleX
            transform.m42 = targetFrame.midY - anchor.y - (sourceFrame.midY - anchor.y) * scaleY
            return transform
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
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

private final class WalletScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let twoStepAuthData: Promise<TwoStepAuthData?>
    let routeToSetup: ((ViewController) -> Void)?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        twoStepAuthData: Promise<TwoStepAuthData?>,
        routeToSetup: ((ViewController) -> Void)?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.twoStepAuthData = twoStepAuthData
        self.routeToSetup = routeToSetup
    }

    static func ==(lhs: WalletScreenComponent, rhs: WalletScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.walletContext === rhs.walletContext && lhs.twoStepAuthData === rhs.twoStepAuthData
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

        private let cardCollapseThreshold: CGFloat = 44.0
        private let cardCollapsedScale: CGFloat = 0.22
        private let cardMinimumScrollScale: CGFloat = 0.9

        private let scrollView: ScrollView
        private let topEdgeEffectView: EdgeEffectView
        private let header = ComponentView<Empty>()
        private let navigationTitle = ComponentView<Empty>()
        private let navigationBalance = ComponentView<Empty>()
        private let cardContainerView: UIView
        private let cardScrollContainerView: UIView
        private let cardBalanceCoordinateView: UIView
        private let cardVisualContainerView: UIView
        private let card = ComponentView<Empty>()
        private let addFundsButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let accountProtectionSection = ComponentView<Empty>()
        private let transactionTabsBackgroundView = GlassBackgroundView()
        private let transactionTabs = ComponentView<Empty>()
        private let transactionsSection = LazySectionView()
        private let collectiblesSection = LazySectionView()
        private let emptyTransactionsInfo = ComponentView<Empty>()
        private let emptyTransactionsFooter = ComponentView<Empty>()
        private let accountProtectionIcon = renderSettingsIcon(
            name: "Item List/Icons/Warning",
            backgroundColors: [UIColor(rgb: 0xff453a)]
        )

        private var component: WalletScreenComponent?
        private var environment: EnvironmentType?
        private var componentState: EmptyComponentState?

        private var walletContext: WalletContext?
        private var walletState: WalletContext.State?
        private var walletStateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private let gramTooltipDisposable = MetaDisposable()
        private let signingAccessDisposable = MetaDisposable()
        private var accountContext: AccountContext?
        private var accountName = ""
        private var accountPeerDisposable: Disposable?
        private var twoStepAuthData: Promise<TwoStepAuthData?>?
        private var twoStepAuthDataDisposable: Disposable?
        private var hasTwoStepAuth: Bool?
        private var isAwaitingAccountProtectionResult = false
        private var isUpdating = false
        private var isGramTooltipPresentationPending = false
        private var didPresentGramTooltip = false
        private var gramTooltipWalletAddress: String?
        private var isResolvingSigningAccess = false
        private var selectedSection: SelectedSection = .transactions
        private var isCardCollapsed = false
        private var cardExpandedFrame: CGRect?

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.topEdgeEffectView = EdgeEffectView()
            self.cardContainerView = UIView()
            self.cardScrollContainerView = UIView()
            self.cardBalanceCoordinateView = UIView()
            self.cardVisualContainerView = UIView()
            self.cardContainerView.clipsToBounds = false
            self.cardScrollContainerView.clipsToBounds = false
            self.cardBalanceCoordinateView.isUserInteractionEnabled = false
            self.cardVisualContainerView.clipsToBounds = false
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

            self.cardContainerView.addSubview(self.cardScrollContainerView)
            self.cardScrollContainerView.addSubview(self.cardBalanceCoordinateView)
            self.cardScrollContainerView.addSubview(self.cardVisualContainerView)
            self.addSubview(self.scrollView)
            self.addSubview(self.topEdgeEffectView)
            self.insertSubview(self.cardContainerView, aboveSubview: self.topEdgeEffectView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            guard result.isDescendant(of: self.cardVisualContainerView) else {
                return result
            }

            var currentView: UIView? = result
            while let current = currentView, current !== self.cardVisualContainerView {
                if current is UIControl {
                    return result
                }
                currentView = current.superview
            }
            return self.scrollView
        }

        deinit {
            self.walletStateDisposable?.dispose()
            self.accountPeerDisposable?.dispose()
            self.twoStepAuthDataDisposable?.dispose()
            self.loadMoreDisposable.dispose()
            self.gramTooltipDisposable.dispose()
            self.signingAccessDisposable.dispose()
        }

        func refreshTwoStepAuth() {
            guard let component = self.component, self.accountContext === component.context else {
                return
            }

            let updatedData = component.context.engine.auth.twoStepAuthData()
            |> map(Optional.init)
            |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                return .single(nil)
            }
            |> beforeNext { [weak self] data in
                guard let self, self.isAwaitingAccountProtectionResult else {
                    return
                }
                self.isAwaitingAccountProtectionResult = false

                guard data?.currentPasswordDerivation != nil else {
                    return
                }
                Queue.mainQueue().after(0.4) { [weak self] in
                    self?.presentPasswordSetToast()
                }
            }
            component.twoStepAuthData.set(
                .single(nil)
                |> then(updatedData)
            )
        }

        private func presentPasswordSetToast() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  controller.navigationController?.topViewController === controller else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: "Password set",
                        text: "Your account is now protected.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ),
                in: .current
            )
        }

        func scrollToTop() {
            self.updateCardCollapsedState(false)
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            if !self.isUpdating {
                self.updateCardCollapsedState(scrollView.contentOffset.y >= self.cardCollapseThreshold)
            }
            self.updateScrolling(transition: .immediate)
            self.updateVisibleSections(transition: .immediate)
            if scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - 240.0 {
                self.loadMoreItemsIfNeeded()
            }
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard scrollView === self.scrollView else {
                return
            }
            if targetContentOffset.pointee.y > 0.0 && targetContentOffset.pointee.y < self.cardCollapseThreshold {
                targetContentOffset.pointee.y = 0.0
            }
        }

        private func updateCardCollapsedState(_ isCollapsed: Bool) {
            guard self.isCardCollapsed != isCollapsed else {
                return
            }
            self.isCardCollapsed = isCollapsed
            self.componentState?.updated(transition: .spring(duration: 0.35))
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

        private func hideEmptyTransactionsFooter(transition: ComponentTransition) {
            guard let footerView = self.emptyTransactionsFooter.view, footerView.superview != nil else {
                return
            }
            transition.setAlpha(view: footerView, alpha: 0.0, completion: { [weak footerView] _ in
                guard let footerView, footerView.alpha == 0.0 else {
                    return
                }
                footerView.removeFromSuperview()
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

        private func maybePresentGramTooltip(cardView: WalletCardComponent.View) {
            guard let walletInfo = self.walletInfo else {
                return
            }
            if self.gramTooltipWalletAddress != walletInfo.address {
                self.gramTooltipWalletAddress = walletInfo.address
                self.isGramTooltipPresentationPending = false
                self.didPresentGramTooltip = false
                self.gramTooltipDisposable.set(nil)
            }
            
            guard !self.isGramTooltipPresentationPending,
                  !self.didPresentGramTooltip,
                  !self.isCardCollapsed,
                  self.environment?.isVisible == true,
                  !cardView.gramIconFrame.isEmpty else {
                return
            }

            guard let component = self.component else {
                return
            }
            let walletAddress = walletInfo.address
            self.isGramTooltipPresentationPending = true
            self.gramTooltipDisposable.set((ApplicationSpecificNotice.getWalletGramTooltip(accountManager: component.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self, weak cardView] count in
                guard let self else {
                    return
                }
                self.isGramTooltipPresentationPending = false

                guard self.gramTooltipWalletAddress == walletAddress,
                      self.walletInfo?.address == walletAddress,
                      !self.didPresentGramTooltip else {
                    return
                }
                if count >= 3 {
                    self.didPresentGramTooltip = true
                    return
                }
                
                guard !self.isCardCollapsed,
                      self.environment?.isVisible == true,
                      let cardView,
                      cardView.window != nil,
                      !cardView.gramIconFrame.isEmpty,
                      let controller = self.environment?.controller() else {
                    return
                }

                self.didPresentGramTooltip = true
                let sourceFrame = cardView.convert(cardView.gramIconFrame, to: nil).offsetBy(dx: 0.0, dy: -4.0)
                let tooltipScreen = TooltipScreen(
                    account: component.context.account,
                    sharedContext: component.context.sharedContext,
                    text: .attributedString(text: NSAttributedString(string: "Gram — Digital currency for Telegram", font: Font.medium(11.0), textColor: .white)),
                    style: .gradient(UIColor(rgb: 0x47bafe), UIColor(rgb: 0x44b5ff), -2.0),
                    arrowStyle: .small,
                    location: .point(sourceFrame, .bottom),
                    displayDuration: .default,
                    inset: 26.0,
                    shouldDismissOnTouch: { _, _ in
                        return .dismiss(consume: false)
                    }
                )
                controller.present(tooltipScreen, in: .current)
                let _ = ApplicationSpecificNotice.incrementWalletGramTooltip(accountManager: component.context.sharedContext.accountManager).startStandalone()
            }))
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
                    layout: .fill,
                    liftWhileSwitching: environment.deviceMetrics.type == .phone
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
            let headerTransitionFraction = max(0.0, min(1.0, self.scrollView.contentOffset.y / self.cardCollapseThreshold))
            if let navigationTitleView = self.navigationTitle.view {
                ComponentTransition.immediate.setAlpha(
                    view: navigationTitleView,
                    alpha: 1.0 - headerTransitionFraction
                )
                navigationTitleView.layer.removeAnimation(forKey: "filters.gaussianBlur.inputRadius")
                ComponentTransition.immediate.setBlur(
                    layer: navigationTitleView.layer,
                    radius: headerTransitionFraction * 8.0
                )
            }
            if let cardExpandedFrame = self.cardExpandedFrame {
                ComponentTransition.immediate.setFrame(
                    view: self.cardContainerView,
                    frame: cardExpandedFrame.offsetBy(dx: 0.0, dy: -self.scrollView.contentOffset.y)
                )
                let cardScrollFraction = max(0.0, min(1.0, self.scrollView.contentOffset.y / self.cardCollapseThreshold))
                let cardScrollScale = 1.0 - (1.0 - self.cardMinimumScrollScale) * cardScrollFraction
                let cardScrollOffset = cardExpandedFrame.height * (1.0 - cardScrollScale) * 0.5
                var cardScrollTransform = CATransform3DMakeScale(
                    cardScrollScale,
                    cardScrollScale,
                    1.0
                )
                cardScrollTransform.m42 = cardScrollOffset
                self.cardScrollContainerView.layer.removeAnimation(forKey: "sublayerTransform")
                ComponentTransition.immediate.setSublayerTransform(
                    view: self.cardScrollContainerView,
                    transform: cardScrollTransform
                )
            }
            self.updateBalanceTransition(fraction: headerTransitionFraction, transition: transition)
        }

        private func updateBalanceTransition(fraction: CGFloat, transition: ComponentTransition) {
            guard let cardView = self.card.view as? WalletCardComponent.View,
                  let navigationBalanceView = self.navigationBalance.view as? WalletNavigationBalanceComponent.View,
                  let cardExpandedFrame = self.cardExpandedFrame else {
                return
            }

            if self.scrollView.contentOffset.y <= 0.0 {
                let primaryFrame = cardView.convert(cardView.primaryBalanceSourceFrame, to: self)
                let secondaryFrame = cardView.convert(cardView.secondaryBalanceSourceFrame, to: self)
                navigationBalanceView.updateTransitionFrames(
                    primaryFrame: navigationBalanceView.convert(primaryFrame, from: self),
                    secondaryFrame: navigationBalanceView.convert(secondaryFrame, from: self),
                    isCollapsed: false,
                    transition: transition
                )
                cardView.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: 0.0,
                    isCollapsed: false,
                    transition: transition
                )
                return
            }

            let primarySourceFrame = cardView.primaryBalanceSourceFrame.offsetBy(
                dx: cardExpandedFrame.minX,
                dy: cardExpandedFrame.minY
            )
            let secondarySourceFrame = cardView.secondaryBalanceSourceFrame.offsetBy(
                dx: cardExpandedFrame.minX,
                dy: cardExpandedFrame.minY
            )
            let primaryTargetFrame = navigationBalanceView.convert(navigationBalanceView.primaryTargetFrame, to: self)
            let secondaryTargetFrame = navigationBalanceView.convert(navigationBalanceView.secondaryTargetFrame, to: self)

            guard !primarySourceFrame.isEmpty,
                  !secondarySourceFrame.isEmpty,
                  !primaryTargetFrame.isEmpty,
                  !secondaryTargetFrame.isEmpty else {
                navigationBalanceView.updateTransitionFrames(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    isCollapsed: self.isCardCollapsed,
                    transition: transition
                )
                cardView.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: fraction,
                    isCollapsed: self.isCardCollapsed,
                    transition: transition
                )
                return
            }

            // The inner containers follow scrolling through only this initial part
            // of the path. Separate outer containers cover the rest with a spring.
            let preCollapseFraction = 0.16 * fraction
            let primaryFrame = self.interpolateFrame(
                from: primarySourceFrame,
                to: primaryTargetFrame,
                fraction: preCollapseFraction
            )
            let secondaryFrame = self.interpolateFrame(
                from: secondarySourceFrame,
                to: secondaryTargetFrame,
                fraction: preCollapseFraction
            )
            navigationBalanceView.updateTransitionFrames(
                primaryFrame: navigationBalanceView.convert(primaryFrame, from: self),
                secondaryFrame: navigationBalanceView.convert(secondaryFrame, from: self),
                isCollapsed: self.isCardCollapsed,
                transition: transition
            )
            cardView.updateBalanceTransition(
                primaryFrame: self.cardBalanceCoordinateView.convert(primaryFrame, from: self),
                secondaryFrame: self.cardBalanceCoordinateView.convert(secondaryFrame, from: self),
                primaryCollapsedFrame: self.cardBalanceCoordinateView.convert(primaryTargetFrame, from: self),
                secondaryCollapsedFrame: self.cardBalanceCoordinateView.convert(secondaryTargetFrame, from: self),
                fraction: fraction,
                isCollapsed: self.isCardCollapsed,
                transition: transition
            )
        }

        private func interpolateFrame(from: CGRect, to: CGRect, fraction: CGFloat) -> CGRect {
            let inverseFraction = 1.0 - fraction
            return CGRect(
                x: from.minX * inverseFraction + to.minX * fraction,
                y: from.minY * inverseFraction + to.minY * fraction,
                width: from.width * inverseFraction + to.width * fraction,
                height: from.height * inverseFraction + to.height * fraction
            )
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
                        || WalletContext.transferAddress(from: value) != nil
                }
            ))
            scanner.completion = { [weak self, weak scanner] value in
                guard let self, let value else {
                    return
                }
                if WalletContext.isTonConnectUrl(value) {
                    Queue.mainQueue().after(0.15) {
                        scanner?.dismiss()
                        component.walletContext.processTonConnectUrl(value)
                    }
                } else if let address = WalletContext.transferAddress(from: value) {
                    Queue.mainQueue().after(0.15) {
                        scanner?.dismiss()
                        self.openSend(address: address)
                    }
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
                  let walletInfo = self.walletInfo,
                  !self.isResolvingSigningAccess else {
                return
            }
            if !walletInfo.canSign {
                if walletInfo.canExportPhrase {
                    self.isResolvingSigningAccess = true
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                        context: component.context,
                        present: { [weak controller] alert in
                            controller?.present(alert, in: .window(.root))
                        },
                        operation: { password in
                            component.walletContext.recoveryPhrase(password: password)
                        },
                        next: { [weak self] _ in
                            guard let self, self.component?.walletContext === component.walletContext else {
                                return
                            }
                            self.isResolvingSigningAccess = false
                            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                            self.routeToSend(address: address)
                        },
                        failed: { [weak self] error in
                            self?.finishResolvingSigningAccess(error: error)
                        }
                    ))
                } else {
                    self.presentRecoveryPhraseImportAlert()
                }
                return
            }
            self.routeToSend(address: address)
        }

        private func routeToSend(address: String?) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            if let address {
                let sendScreen = WalletSendScreen(context: component.context, walletContext: component.walletContext, address: address)
                sendScreen.navigationPresentation = .modal
                controller.push(sendScreen)
            } else {
                let peerSelectionScreen = WalletPeerSelectionScreen(
                    context: component.context,
                    walletContext: component.walletContext
                )
                peerSelectionScreen.navigationPresentation = .modal
                controller.push(peerSelectionScreen)
            }
        }

        private func finishResolvingSigningAccess(error: WalletContext.WalletError) {
            self.isResolvingSigningAccess = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard error != .authorizationCancelled,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Restore Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport()
                }
            ))
        }

        private func presentRecoveryPhraseImportAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Recovery Phrase Required",
                text: "To send funds, you’ll need to enter your 12- or 24-word recovery phrase to restore access to this wallet.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Proceed", action: { [weak self] in
                        Queue.mainQueue().after(0.25) { [weak self] in
                            self?.openRecoveryPhraseImport()
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func completeRecoveryPhraseImport() {
            guard let component = self.component,
                  let walletController = self.environment?.controller(),
                  let navigationController = walletController.navigationController as? NavigationController,
                  let walletControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === walletController }) else {
                return
            }
            let viewControllers = Array(navigationController.viewControllers.prefix(through: walletControllerIndex))
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            navigationController.setViewControllers(viewControllers, animated: true)
            Queue.mainQueue().after(0.4) { [weak walletController] in
                walletController?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: "Wallet Imported",
                        text: "Your wallet was restored from your recovery phrase.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
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

        private func openAccountProtection() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.isAwaitingAccountProtectionResult = true
            controller.push(component.context.sharedContext.makeSetupTwoFactorAuthController(context: component.context))
        }

        private func openPasscodeSettings() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let context = component.context
            let _ = passcodeOptionsAccessController(
                context: context,
                pushController: { [weak controller] passcodeController in
                    (controller?.navigationController as? NavigationController)?.replaceTopController(passcodeController, animated: true)
                },
                completion: { [weak controller] _ in
                    (controller?.navigationController as? NavigationController)?.replaceTopController(passcodeOptionsController(context: context), animated: true)
                }
            ).start(next: { [weak controller] passcodeController in
                if let passcodeController {
                    controller?.push(passcodeController)
                }
            })
        }

        private func openTerms(url: String) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            component.context.sharedContext.openExternalUrl(
                context: component.context,
                urlContext: .generic,
                url: url,
                forceExternal: false,
                presentationData: presentationData,
                navigationController: controller.navigationController as? NavigationController,
                dismissInput: {}
            )
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
                (.cny, "Chinese Yuan"),
                //TODO:localize
                (.aed, "UAE Dirham"),
                //TODO:localize
                (.afn, "Afghan Afghani"),
                //TODO:localize
                (.all, "Albanian Lek"),
                //TODO:localize
                (.amd, "Armenian Dram"),
                //TODO:localize
                (.ars, "Argentine Peso"),
                //TODO:localize
                (.aud, "Australian Dollar"),
                //TODO:localize
                (.azn, "Azerbaijani Manat"),
                //TODO:localize
                (.bam, "Bosnia-Herzegovina Convertible Mark"),
                //TODO:localize
                (.bdt, "Bangladeshi Taka"),
                //TODO:localize
                (.bgn, "Bulgarian Lev"),
                //TODO:localize
                (.bhd, "Bahraini Dinar"),
                //TODO:localize
                (.bnd, "Brunei Dollar"),
                //TODO:localize
                (.bob, "Bolivian Boliviano"),
                //TODO:localize
                (.brl, "Brazilian Real"),
                //TODO:localize
                (.byn, "Belarusian Ruble"),
                //TODO:localize
                (.cad, "Canadian Dollar"),
                //TODO:localize
                (.chf, "Swiss Franc"),
                //TODO:localize
                (.clp, "Chilean Peso"),
                //TODO:localize
                (.cop, "Colombian Peso"),
                //TODO:localize
                (.crc, "Costa Rican Colón"),
                //TODO:localize
                (.czk, "Czech Koruna"),
                //TODO:localize
                (.dkk, "Danish Krone"),
                //TODO:localize
                (.dop, "Dominican Peso"),
                //TODO:localize
                (.dzd, "Algerian Dinar"),
                //TODO:localize
                (.egp, "Egyptian Pound"),
                //TODO:localize
                (.etb, "Ethiopian Birr"),
                //TODO:localize
                (.gbp, "British Pound"),
                //TODO:localize
                (.gel, "Georgian Lari"),
                //TODO:localize
                (.ghs, "Ghanaian Cedi"),
                //TODO:localize
                (.gtq, "Guatemalan Quetzal"),
                //TODO:localize
                (.hkd, "Hong Kong Dollar"),
                //TODO:localize
                (.hnl, "Honduran Lempira"),
                //TODO:localize
                (.hrk, "Croatian Kuna"),
                //TODO:localize
                (.huf, "Hungarian Forint"),
                //TODO:localize
                (.idr, "Indonesian Rupiah"),
                //TODO:localize
                (.ils, "Israeli New Shekel"),
                //TODO:localize
                (.inr, "Indian Rupee"),
                //TODO:localize
                (.iqd, "Iraqi Dinar"),
                //TODO:localize
                (.irr, "Iranian Rial"),
                //TODO:localize
                (.isk, "Icelandic Króna"),
                //TODO:localize
                (.jmd, "Jamaican Dollar"),
                //TODO:localize
                (.jod, "Jordanian Dinar"),
                //TODO:localize
                (.jpy, "Japanese Yen"),
                //TODO:localize
                (.kes, "Kenyan Shilling"),
                //TODO:localize
                (.kgs, "Kyrgyzstani Som"),
                //TODO:localize
                (.krw, "South Korean Won"),
                //TODO:localize
                (.kzt, "Kazakhstani Tenge"),
                //TODO:localize
                (.lbp, "Lebanese Pound"),
                //TODO:localize
                (.lkr, "Sri Lankan Rupee"),
                //TODO:localize
                (.mad, "Moroccan Dirham"),
                //TODO:localize
                (.mdl, "Moldovan Leu"),
                //TODO:localize
                (.mmk, "Myanmar Kyat"),
                //TODO:localize
                (.mnt, "Mongolian Tögrög"),
                //TODO:localize
                (.mop, "Macanese Pataca"),
                //TODO:localize
                (.mur, "Mauritian Rupee"),
                //TODO:localize
                (.mvr, "Maldivian Rufiyaa"),
                //TODO:localize
                (.mxn, "Mexican Peso"),
                //TODO:localize
                (.myr, "Malaysian Ringgit"),
                //TODO:localize
                (.mzn, "Mozambican Metical"),
                //TODO:localize
                (.ngn, "Nigerian Naira"),
                //TODO:localize
                (.nio, "Nicaraguan Córdoba"),
                //TODO:localize
                (.nok, "Norwegian Krone"),
                //TODO:localize
                (.npr, "Nepalese Rupee"),
                //TODO:localize
                (.nzd, "New Zealand Dollar"),
                //TODO:localize
                (.pab, "Panamanian Balboa"),
                //TODO:localize
                (.pen, "Peruvian Sol"),
                //TODO:localize
                (.php, "Philippine Peso"),
                //TODO:localize
                (.pkr, "Pakistani Rupee"),
                //TODO:localize
                (.pln, "Polish Złoty"),
                //TODO:localize
                (.pyg, "Paraguayan Guaraní"),
                //TODO:localize
                (.qar, "Qatari Riyal"),
                //TODO:localize
                (.ron, "Romanian Leu"),
                //TODO:localize
                (.rsd, "Serbian Dinar"),
                //TODO:localize
                (.sar, "Saudi Riyal"),
                //TODO:localize
                (.sek, "Swedish Krona"),
                //TODO:localize
                (.sgd, "Singapore Dollar"),
                //TODO:localize
                (.syp, "Syrian Pound"),
                //TODO:localize
                (.thb, "Thai Baht"),
                //TODO:localize
                (.tjs, "Tajikistani Somoni"),
                //TODO:localize
                (.tryCurrency, "Turkish Lira"),
                //TODO:localize
                (.ttd, "Trinidad and Tobago Dollar"),
                //TODO:localize
                (.twd, "New Taiwan Dollar"),
                //TODO:localize
                (.tzs, "Tanzanian Shilling"),
                //TODO:localize
                (.uah, "Ukrainian Hryvnia"),
                //TODO:localize
                (.ugx, "Ugandan Shilling"),
                //TODO:localize
                (.uyu, "Uruguayan Peso"),
                //TODO:localize
                (.uzs, "Uzbekistani Som"),
                //TODO:localize
                (.vnd, "Vietnamese Đồng"),
                //TODO:localize
                (.yer, "Yemeni Rial"),
                //TODO:localize
                (.zar, "South African Rand")
            ]
            let selectedCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
            var orderedCurrencies = currencies
            let topCurrencies: Set<WalletContext.FiatCurrency> = [.usd, .eur, .rub, .cny, .aed]
            if !topCurrencies.contains(selectedCurrency),
               let selectedCurrencyIndex = orderedCurrencies.firstIndex(where: { $0.currency == selectedCurrency }) {
                let selectedCurrencyItem = orderedCurrencies.remove(at: selectedCurrencyIndex)
                orderedCurrencies.insert(selectedCurrencyItem, at: 0)
            }

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
                    action: { [weak self] contextController, _ in
                        let searchQueryPromise = ValuePromise<String>("")
                        let currencyItems: [ContextMenuItem] = [
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
                            .separator,
                            .custom(WalletCurrencySearchContextItem(
                                context: component.context,
                                placeholder: presentationData.strings.Common_Search,
                                valueChanged: { value in
                                    searchQueryPromise.set(value)
                                }
                            ), false),
                            .separator,
                            .custom(WalletCurrencyListContextItem(
                                context: component.context,
                                currencies: orderedCurrencies,
                                selectedCurrency: selectedCurrency,
                                searchQuery: searchQueryPromise.get(),
                                currencySelected: { [weak self] currency in
                                    self?.component?.walletContext.setFiatCurrency(currency)
                                }
                            ), false)
                        ]
                        contextController?.pushItems(items: .single(ContextController.Items(content: .list(currencyItems))))
                    }
                )),
                .action(ContextMenuActionItem(
                    text: passcode,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/FaceId"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openPasscodeSettings()
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
                    if !self.isUpdating {
                        self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    }
                })
            }

            if self.twoStepAuthData !== component.twoStepAuthData {
                self.twoStepAuthDataDisposable?.dispose()
                let subscribedTwoStepAuthData = component.twoStepAuthData
                self.twoStepAuthData = subscribedTwoStepAuthData
                self.hasTwoStepAuth = nil
                self.twoStepAuthDataDisposable = (subscribedTwoStepAuthData.get()
                |> deliverOnMainQueue).start(next: { [weak self, weak subscribedTwoStepAuthData] data in
                    guard let self, let subscribedTwoStepAuthData, self.twoStepAuthData === subscribedTwoStepAuthData else {
                        return
                    }
                    let hadTwoStepAuthValue = self.hasTwoStepAuth != nil
                    
                    let hasTwoStepAuth: Bool?
                    if let data {
                        hasTwoStepAuth = data.currentPasswordDerivation != nil || data.unconfirmedEmailPattern != nil
                    } else {
                        hasTwoStepAuth = nil
                    }
                    if self.hasTwoStepAuth != hasTwoStepAuth {
                        self.hasTwoStepAuth = hasTwoStepAuth
                        if !self.isUpdating {
                            self.componentState?.updated(transition: hadTwoStepAuthValue ? .easeInOut(duration: 0.2) : .immediate)
                        }
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

            let transactions = (self.walletState?.transactions.items ?? []).filter {
                $0.isVisibleInWalletHistory && $0.kind != .deployContract
            }
            let collectibles = self.walletState?.collectibles.items ?? []
            if collectibles.isEmpty && self.selectedSection == .collectibles {
                self.selectedSection = .transactions
            }
            let hasEmptyTransactions = self.selectedSection == .transactions && transactions.isEmpty
            if hasEmptyTransactions {
                self.isCardCollapsed = false
                if self.scrollView.contentOffset != CGPoint() {
                    self.scrollView.setContentOffset(CGPoint(), animated: false)
                }
            }
            self.scrollView.isScrollEnabled = !hasEmptyTransactions

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
                title: "",
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
                    self.insertSubview(headerView, aboveSubview: self.cardContainerView)
                }
                transition.setFrame(
                    view: headerView,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: headerOriginY),
                        size: headerSize
                    )
                )
            }

            self.navigationTitle.parentState = state
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: title,
                    font: Font.semibold(17.0),
                    color: environment.theme.rootController.navigationBar.primaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: headerSize.height)
            )
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    navigationTitleView.isUserInteractionEnabled = false
                    self.insertSubview(navigationTitleView, belowSubview: self.cardContainerView)
                }
                transition.setFrame(
                    view: navigationTitleView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: floor((availableSize.width - navigationTitleSize.width) * 0.5),
                            y: headerOriginY + floor((headerSize.height - navigationTitleSize.height) * 0.5)
                        ),
                        size: navigationTitleSize
                    )
                )
            }

            self.navigationBalance.parentState = state
            let navigationBalanceSize = self.navigationBalance.update(
                transition: transition,
                component: AnyComponent(WalletNavigationBalanceComponent(
                    theme: environment.theme,
                    balance: self.walletState?.balance.currentValue,
                    fiatCurrency: self.walletState?.fiat.selectedCurrency ?? .usd,
                    fiatRate: self.walletState?.fiat.selectedRate,
                    dateTimeFormat: environment.dateTimeFormat
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 200.0),
                    height: headerSize.height
                )
            )
            if let navigationBalanceView = self.navigationBalance.view {
                if navigationBalanceView.superview == nil {
                    navigationBalanceView.isUserInteractionEnabled = false
                    self.insertSubview(navigationBalanceView, belowSubview: self.cardContainerView)
                }
                transition.setFrame(
                    view: navigationBalanceView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: floor((availableSize.width - navigationBalanceSize.width) * 0.5),
                            y: headerOriginY + floor((headerSize.height - navigationBalanceSize.height) * 0.5)
                        ),
                        size: navigationBalanceSize
                    )
                )
                transition.setAlpha(view: navigationBalanceView, alpha: self.isCardCollapsed ? 1.0 : 0.0)
                transition.setSublayerTransform(
                    view: navigationBalanceView,
                    transform: CATransform3DIdentity
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
            let cardSpacing: CGFloat = 12.0
            let cardCollapseOffset = max(0.0, cardSize.height + cardSpacing - self.cardCollapseThreshold)
            self.cardExpandedFrame = CGRect(
                origin: CGPoint(
                    x: environment.safeInsets.left + sideInset,
                    y: cardOriginY
                ),
                size: cardSize
            )
            ComponentTransition.immediate.setFrame(
                view: self.cardScrollContainerView,
                frame: CGRect(origin: CGPoint(), size: cardSize)
            )
            ComponentTransition.immediate.setFrame(
                view: self.cardBalanceCoordinateView,
                frame: CGRect(origin: CGPoint(), size: cardSize)
            )
            transition.setFrame(
                view: self.cardVisualContainerView,
                frame: CGRect(
                    origin: CGPoint(x: 0.0, y: self.isCardCollapsed ? -cardCollapseOffset : 0.0),
                    size: cardSize
                )
            )
            transition.setAlpha(view: self.cardVisualContainerView, alpha: self.isCardCollapsed ? 0.0 : 1.0)
            transition.setSublayerTransform(
                view: self.cardVisualContainerView,
                transform: CATransform3DMakeScale(
                    self.isCardCollapsed ? self.cardCollapsedScale : 1.0,
                    self.isCardCollapsed ? self.cardCollapsedScale : 1.0,
                    1.0
                )
            )
            self.cardContainerView.isUserInteractionEnabled = !self.isCardCollapsed
            if let cardView = self.card.view {
                if cardView.superview !== self.cardVisualContainerView {
                    self.cardVisualContainerView.addSubview(cardView)
                }
                transition.setFrame(
                    view: cardView,
                    frame: CGRect(
                        origin: CGPoint(),
                        size: cardSize
                    )
                )
                if let cardView = cardView as? WalletCardComponent.View {
                    cardView.balanceGeometryUpdated = { [weak self, weak cardView] in
                        guard let self,
                              let cardView,
                              !self.isUpdating,
                              let currentCardView = self.card.view as? WalletCardComponent.View,
                              currentCardView === cardView else {
                            return
                        }
                        self.updateScrolling(transition: .immediate)
                    }
                    self.maybePresentGramTooltip(cardView: cardView)
                }
            }

            //TODO:localize
            let addFundsTitle = "Add Funds"
            //TODO:localize
            let sendTitle = "Send"
            let buttonsSpacing: CGFloat = 10.0
            let addFundsButtonWidth = floorToScreenPixels((cardWidth - buttonsSpacing) * 0.5)
            let sendButtonWidth = cardWidth - buttonsSpacing - addFundsButtonWidth
            let buttonsOriginY = cardOriginY + (self.isCardCollapsed ? self.cardCollapseThreshold : cardSize.height + cardSpacing)
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
                    isEnabled: self.walletInfo != nil && !self.isResolvingSigningAccess,
                    displaysProgress: self.isResolvingSigningAccess,
                    action: { [weak self] in
                        self?.openSend()
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

            if self.hasTwoStepAuth == false && !transactions.isEmpty {
                var transition = transition
                if self.accountProtectionSection.view?.superview == nil {
                    transition = .immediate
                }
                self.accountProtectionSection.parentState = state
                let accountProtectionSectionSize = self.accountProtectionSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "accountProtection", component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        //TODO:localize
                                        string: "Protect Your Account",
                                        font: Font.regular(17.0),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                )),
                                leftIcon: .custom(AnyComponentWithIdentity(
                                    id: "accountProtectionIcon",
                                    component: AnyComponent(Image(
                                        image: self.accountProtectionIcon,
                                        size: CGSize(width: 30.0, height: 30.0)
                                    ))
                                ), false),
                                accessory: .arrow,
                                action: { [weak self] _ in
                                    self?.openAccountProtection()
                                }
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: 10000.0)
                )
                if let accountProtectionSectionView = self.accountProtectionSection.view {
                    if accountProtectionSectionView.superview == nil {
                        self.scrollView.addSubview(accountProtectionSectionView)
                    }
                    let accountProtectionOriginY = contentHeight + 12.0
                    transition.setFrame(
                        view: accountProtectionSectionView,
                        frame: CGRect(
                            origin: CGPoint(x: environment.safeInsets.left + sideInset, y: accountProtectionOriginY),
                            size: accountProtectionSectionSize
                        )
                    )
                    contentHeight = accountProtectionOriginY + accountProtectionSectionSize.height
                }
            } else {
                self.accountProtectionSection.view?.removeFromSuperview()
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
                self.hideEmptyTransactionsFooter(transition: transition)
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else if self.selectedSection == .collectibles {
                self.hideSection(self.transactionsSection, transition: transition)
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view {
                    emptyTransactionsInfoView.removeFromSuperview()
                }
                self.hideEmptyTransactionsFooter(transition: transition)

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

                //TODO:localize
                let termsString = "By using Wallet you agree to Terms of Service."
                let termsLink = "Terms of Service"
                let termsText = NSMutableAttributedString(
                    string: termsString,
                    attributes: [
                        .font: Font.regular(13.0),
                        .foregroundColor: textColor
                    ]
                )
                let termsLinkRange = (termsString as NSString).range(of: termsLink)
                termsText.addAttributes(
                    [
                        .foregroundColor: accentColor,
                        NSAttributedString.Key(rawValue: TelegramTextAttributes.URL): environment.strings.Settings_Terms_URL
                    ],
                    range: termsLinkRange
                )

                self.emptyTransactionsFooter.parentState = state
                let emptyTransactionsFooterSize = self.emptyTransactionsFooter.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(termsText),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: accentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            guard let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String else {
                                return
                            }
                            self?.openTerms(url: url)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: 10000.0)
                )
                let emptyTransactionsFooterOriginY = max(
                    contentHeight + 24.0,
                    availableSize.height - environment.safeInsets.bottom - emptyTransactionsFooterSize.height - 16.0
                )
                if let emptyTransactionsFooterView = self.emptyTransactionsFooter.view {
                    var wasVisible = true
                    if emptyTransactionsFooterView.superview == nil {
                        wasVisible = false
                        self.addSubview(emptyTransactionsFooterView)
                    }
                    if !transition.animation.isImmediate && !wasVisible {
                        transition.animateAlpha(view: emptyTransactionsFooterView, from: 0.0, to: 1.0)
                    } else {
                        transition.setAlpha(view: emptyTransactionsFooterView, alpha: 1.0)
                    }

                    let layoutTransition: ComponentTransition = wasVisible ? transition : .immediate
                    layoutTransition.setFrame(
                        view: emptyTransactionsFooterView,
                        frame: CGRect(
                            origin: CGPoint(
                                x: floor((availableSize.width - emptyTransactionsFooterSize.width) * 0.5),
                                y: emptyTransactionsFooterOriginY
                            ),
                            size: emptyTransactionsFooterSize
                        )
                    )
                }
                contentHeight = emptyTransactionsFooterOriginY + emptyTransactionsFooterSize.height
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.plainBackgroundColor)
            }

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            contentHeight += 24.0 + environment.safeInsets.bottom
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + self.cardCollapseThreshold + 1.0)
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
        twoStepAuthData: Promise<TwoStepAuthData?>,
        routeToSetup: ((ViewController) -> Void)? = nil
    ) {
        super.init(
            context: context,
            component: WalletScreenComponent(
                context: context,
                walletContext: walletContext,
                twoStepAuthData: twoStepAuthData,
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

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let componentView = self.node.hostView.componentView as? WalletScreenComponent.View else {
            return
        }
        componentView.refreshTwoStepAuth()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WalletContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    let forceDisplayBelowKeyboard = true

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
