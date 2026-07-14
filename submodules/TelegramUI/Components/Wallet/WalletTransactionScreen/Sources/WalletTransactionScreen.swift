import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import GlassBarButtonComponent
import TableComponent
import ContextUI
import TelegramStringFormatting
import TextFormat
import WalletContext
import LottieComponent

private final class WalletTransactionSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let transaction: WalletContext.Transaction
    let usdRate: Double?
    let explorerUrl: String?
    let openExplorer: (String) -> Void
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        transaction: WalletContext.Transaction,
        usdRate: Double?,
        explorerUrl: String?,
        openExplorer: @escaping (String) -> Void,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.transaction = transaction
        self.usdRate = usdRate
        self.explorerUrl = explorerUrl
        self.openExplorer = openExplorer
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletTransactionSheetContent, rhs: WalletTransactionSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.transaction != rhs.transaction {
            return false
        }
        if lhs.usdRate != rhs.usdRate {
            return false
        }
        if lhs.explorerUrl != rhs.explorerUrl {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        private let hapticFeedback = HapticFeedback()

        init(
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.animateOut = animateOut
            self.getController = getController

            super.init()
        }

        func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            guard let controller = self.getController() as? WalletTransactionScreen else {
                return
            }
            if animated {
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                    completion?()
                })
            } else {
                controller.dismiss(animated: false)
                completion?()
            }
        }

        func copyAddress(_ address: String) {
            UIPasteboard.general.string = address
            self.hapticFeedback.tap()
        }
    }

    func makeState() -> State {
        return State(animateOut: self.animateOut, getController: self.getController)
    }

    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let moreButton = Child(GlassBarButtonComponent.self)
        let amount = Child(HStack<Empty>.self)
        let usdValue = Child(MultilineTextComponent.self)
        let commentBackground = Child(RoundedRectangle.self)
        let comment = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let actionButton = Child(ButtonComponent.self)

        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let component = context.component
            let state = context.state
            let theme = environment.theme

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak state] _ in
                        state?.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )

            let moreButton = moreButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "more", component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: "anim_morewide"
                            ),
                            color: theme.chat.inputPanel.panelControlColor,
                            size: CGSize(width: 34.0, height: 34.0),
                            playOnce: nil
                        )
                    )),
                    action: { [weak state] sourceView in
                        guard let controller = component.getController() else {
                            return
                        }

                        //TODO:localize
                        let viewInExplorer = "View In Explorer"
                        let item = ContextMenuActionItem(
                            text: viewInExplorer,
                            icon: { theme in
                                return generateTintedImage(
                                    image: UIImage(bundleImageName: "Chat/Context Menu/Search"),
                                    color: theme.contextMenu.primaryColor
                                )
                            },
                            action: { contextController, dismiss in
                                let openExplorer = {
                                    guard let explorerUrl = component.explorerUrl else {
                                        return
                                    }
                                    state?.dismiss(animated: true, completion: {
                                        component.openExplorer(explorerUrl)
                                    })
                                }
                                if let contextController {
                                    contextController.dismiss(result: .default, completion: openExplorer)
                                } else {
                                    dismiss(.default)
                                    openExplorer()
                                }
                            }
                        )
                        let contextController = makeContextController(
                            presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                            source: .reference(WalletTransactionContextReferenceContentSource(sourceView: sourceView)),
                            items: .single(ContextController.Items(content: .list([
                                .action(item)
                            ]))),
                            gesture: nil
                        )
                        controller.presentInGlobalOverlay(contextController)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(moreButton
                .position(CGPoint(
                    x: context.availableSize.width - 16.0 - moreButton.size.width / 2.0,
                    y: 16.0 + moreButton.size.height / 2.0
                ))
            )

            let amountColor: UIColor
            let amountText: String
            let formattedAmount = formatTonAmountText(
                component.transaction.amount,
                dateTimeFormat: environment.dateTimeFormat,
                maxDecimalPositions: nil
            )
            switch component.transaction.direction {
            case .incoming:
                amountColor = theme.list.itemDisclosureActions.constructive.fillColor
                amountText = "+\(formattedAmount)"
            case .outgoing:
                amountColor = theme.actionSheet.primaryTextColor
                amountText = "−\(formattedAmount)"
            case .unknown:
                amountColor = theme.actionSheet.primaryTextColor
                amountText = formattedAmount
            }

            let amountAttributedString = tonAmountAttributedString(
                amountText,
                integralFont: Font.with(size: 48.0, design: .round, weight: .semibold),
                fractionalFont: Font.with(size: 32.0, design: .round, weight: .semibold),
                color: amountColor,
                decimalSeparator: environment.dateTimeFormat.decimalSeparator
            )
            let amount = amount.update(
                component: HStack([
                    AnyComponentWithIdentity(
                        id: "amount",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(amountAttributedString),
                            maximumNumberOfLines: 1
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "icon",
                        component: AnyComponent(BundleIconComponent(
                            name: "Ads/TonBig",
                            tintColor: UIColor(rgb: 0x30a1f5),
                            maxSize: CGSize(width: 32.0, height: 32.0)
                        ))
                    )
                ], spacing: 8.0),
                availableSize: CGSize(width: context.availableSize.width - 64.0, height: 100.0),
                transition: .immediate
            )

            var contentSize = CGSize(width: context.availableSize.width, height: 104.0)
            context.add(amount
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + amount.size.height / 2.0))
            )
            contentSize.height += amount.size.height
            contentSize.height += 2.0

            let usdText: String
            if let usdRate = component.usdRate, usdRate.isFinite, usdRate > 0.0 {
                usdText = formatTonUsdValue(
                    component.transaction.amount,
                    rate: usdRate,
                    dateTimeFormat: environment.dateTimeFormat
                )
            } else {
                //TODO:localize
                usdText = "—"
            }
            let usdValue = usdValue.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: usdText,
                        font: Font.regular(15.0),
                        textColor: theme.actionSheet.secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - 64.0, height: 100.0),
                transition: .immediate
            )
            context.add(usdValue
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + usdValue.size.height / 2.0))
            )
            contentSize.height += usdValue.size.height

            if let commentText = walletTransactionComment(component.transaction.comment) {
                contentSize.height += 28.0
                let comment = comment.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: commentText,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.primaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 112.0, height: 1000.0),
                    transition: .immediate
                )
                let commentBackgroundSize = CGSize(
                    width: comment.size.width + 24.0,
                    height: comment.size.height + 14.0
                )
                let commentBackground = commentBackground.update(
                    component: RoundedRectangle(
                        color: theme.list.itemInputField.backgroundColor,
                        cornerRadius: min(18.0, commentBackgroundSize.height / 2.0),
                        size: commentBackgroundSize
                    ),
                    availableSize: commentBackgroundSize,
                    transition: .immediate
                )
                let commentCenter = CGPoint(
                    x: context.availableSize.width / 2.0,
                    y: contentSize.height + commentBackgroundSize.height / 2.0
                )
                context.add(commentBackground.position(commentCenter))
                context.add(comment.position(commentCenter))
                contentSize.height += commentBackgroundSize.height
                contentSize.height += 32.0
            } else {
                contentSize.height += 44.0
            }

            let valueFont = Font.regular(15.0)
            let valueColor = theme.list.itemPrimaryTextColor
            let secondaryValueColor = theme.list.itemSecondaryTextColor

            let counterpartyTitle: String
            switch component.transaction.direction {
            case .incoming:
                //TODO:localize
                counterpartyTitle = "Sender"
            case .outgoing:
                //TODO:localize
                counterpartyTitle = "Recipient"
            case .unknown:
                //TODO:localize
                counterpartyTitle = "Address"
            }

            let counterpartyText: String
            let counterpartyFont: UIFont
            if let counterparty = component.transaction.counterparty {
                counterpartyText = walletTransactionFormattedAddress(counterparty)
                counterpartyFont = Font.monospace(15.0)
            } else {
                //TODO:localize
                counterpartyText = "Unknown Address"
                counterpartyFont = valueFont
            }

            let counterpartyTextComponent: AnyComponent<Empty> = AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: counterpartyText,
                    font: counterpartyFont,
                    textColor: valueColor
                )),
                maximumNumberOfLines: 0,
                lineSpacing: 0.12
            ))
            let counterpartyComponent: AnyComponent<Empty>
            if let counterparty = component.transaction.counterparty {
                counterpartyComponent = AnyComponent(Button(
                    content: counterpartyTextComponent,
                    action: { [weak state] in
                        state?.copyAddress(counterparty)
                    }
                ))
            } else {
                counterpartyComponent = counterpartyTextComponent
            }

            var feeItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "icon",
                    component: AnyComponent(BundleIconComponent(
                        name: "Ads/TonAbout",
                        tintColor: UIColor(rgb: 0x30a1f5),
                        maxSize: CGSize(width: 14.0, height: 14.0)
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "amount",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: formatTonAmountText(
                                component.transaction.fee,
                                dateTimeFormat: environment.dateTimeFormat,
                                maxDecimalPositions: nil
                            ),
                            font: valueFont,
                            textColor: valueColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                )
            ]
            if let usdRate = component.usdRate, usdRate.isFinite, usdRate > 0.0 {
                //TODO:localize
                let approximately = "~ \(formatTonUsdValue(component.transaction.fee, rate: usdRate, dateTimeFormat: environment.dateTimeFormat))"
                feeItems.append(AnyComponentWithIdentity(
                    id: "usd",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: approximately,
                            font: valueFont,
                            textColor: secondaryValueColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                ))
            }

            //TODO:localize
            let feeTitle = "Fee"
            //TODO:localize
            let dateTitle = "Date"
            let tableItems: [TableComponent.Item] = [
                TableComponent.Item(
                    id: "counterparty",
                    title: counterpartyTitle,
                    component: counterpartyComponent
                ),
                TableComponent.Item(
                    id: "fee",
                    title: feeTitle,
                    component: AnyComponent(HStack(feeItems, spacing: 3.0))
                ),
                TableComponent.Item(
                    id: "date",
                    title: dateTitle,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: walletTransactionDateText(
                                timestamp: component.transaction.timestamp,
                                strings: environment.strings,
                                dateTimeFormat: environment.dateTimeFormat
                            ),
                            font: valueFont,
                            textColor: valueColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                )
            ]
            let tableSideInset: CGFloat = 32.0 + environment.safeInsets.left
            let table = table.update(
                component: TableComponent(theme: theme, items: tableItems),
                availableSize: CGSize(
                    width: context.availableSize.width - tableSideInset * 2.0,
                    height: .greatestFiniteMagnitude
                ),
                transition: .immediate
            )
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + table.size.height / 2.0))
            )
            contentSize.height += table.size.height
            contentSize.height += 30.0

            //TODO:localize
            let actionTitle = "OK"
            let actionButton = actionButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: actionTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    action: { [weak state] in
                        state?.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 60.0, height: 52.0),
                transition: .immediate
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
            )
            contentSize.height += actionButton.size.height
            contentSize.height += 30.0

            return contentSize
        }
    }
}

private final class WalletTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let transaction: WalletContext.Transaction
    let usdRate: Double?
    let explorerUrl: String?
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        transaction: WalletContext.Transaction,
        usdRate: Double?,
        explorerUrl: String?,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.transaction = transaction
        self.usdRate = usdRate
        self.explorerUrl = explorerUrl
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionSheetComponent, rhs: WalletTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.transaction != rhs.transaction {
            return false
        }
        if lhs.usdRate != rhs.usdRate {
            return false
        }
        if lhs.explorerUrl != rhs.explorerUrl {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletTransactionSheetContent(
                        context: context.component.context,
                        transaction: context.component.transaction,
                        usdRate: context.component.usdRate,
                        explorerUrl: context.component.explorerUrl,
                        openExplorer: context.component.openExplorer,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? WalletTransactionScreen {
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? WalletTransactionScreen {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )

            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }

                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(
                        top: 0.0,
                        left: max(sideInset, environment.safeInsets.left),
                        bottom: 0.0,
                        right: max(sideInset, environment.safeInsets.right)
                    ),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(
                    layout,
                    transition: context.transition.containedViewLayoutTransition
                )
            }

            return context.availableSize
        }
    }
}

public final class WalletTransactionScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, transaction: WalletContext.Transaction) {
        let usdRate = context.currentAppConfiguration.with { configuration -> Double? in
            return configuration.data?["ton_usd_rate"] as? Double
        }
        let explorerUrl = walletTransactionExplorerUrl(id: transaction.id)

        super.init(
            context: context,
            component: WalletTransactionSheetComponent(
                context: context,
                transaction: transaction,
                usdRate: usdRate,
                explorerUrl: explorerUrl,
                openExplorer: { url in
                    context.sharedContext.openExternalUrl(
                        context: context,
                        urlContext: .generic,
                        url: url,
                        forceExternal: true,
                        presentationData: context.sharedContext.currentPresentationData.with { $0 },
                        navigationController: nil,
                        dismissInput: {
                        }
                    )
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private func walletTransactionComment(_ value: String?) -> String? {
    guard let value else {
        return nil
    }
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedValue.isEmpty else {
        return nil
    }
    return trimmedValue
}

private func walletTransactionFormattedAddress(_ address: String) -> String {
    var groups: [String] = []
    var index = address.startIndex
    while index < address.endIndex {
        let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        groups.append(String(address[index ..< endIndex]))
        index = endIndex
    }

    var lines: [String] = []
    for lineStart in stride(from: 0, to: groups.count, by: 4) {
        let lineEnd = min(lineStart + 4, groups.count)
        lines.append(groups[lineStart ..< lineEnd].joined(separator: " "))
    }
    return lines.joined(separator: "\n")
}

private func walletTransactionDateText(
    timestamp: Int32,
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat
) -> String {
    let dateComponents = getDateTimeComponents(timestamp: timestamp)
    let date = stringForMediumCompactDate(
        timestamp: timestamp,
        strings: strings,
        dateTimeFormat: dateTimeFormat,
        withTime: false
    )
    let time = stringForShortTimestamp(
        hours: dateComponents.hour,
        minutes: dateComponents.minutes,
        dateTimeFormat: dateTimeFormat
    )
    return strings.Time_MediumDate(date, time).string
}

private func walletTransactionExplorerUrl(id: String) -> String? {
    let hash: String
    if id.count == 64 && id.unicodeScalars.allSatisfy({ scalar in
        switch scalar.value {
        case 48 ... 57, 65 ... 70, 97 ... 102:
            return true
        default:
            return false
        }
    }) {
        hash = id.lowercased()
    } else {
        var base64 = id
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64), data.count == 32 else {
            return nil
        }
        hash = data.map { String(format: "%02x", $0) }.joined()
    }
    return "https://tonviewer.com/transaction/\(hash)"
}

private final class WalletTransactionContextReferenceContentSource: ContextReferenceContentSource {
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
