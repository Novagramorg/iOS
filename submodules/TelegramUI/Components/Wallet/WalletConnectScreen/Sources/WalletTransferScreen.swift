import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import WalletContext
import WalletCardComponent
import AlertUI

fileprivate enum WalletTransferFinishResult {
    case cancelled
    case confirmed
}

private final class WalletTransferSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectTransferRequest
    let confirm: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    let updateIsBusy: (Bool) -> Void
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectTransferRequest,
        confirm: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void,
        updateIsBusy: @escaping (Bool) -> Void,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.request = request
        self.confirm = confirm
        self.updateIsBusy = updateIsBusy
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletTransferSheetContent, rhs: WalletTransferSheetContent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.request == rhs.request
    }

    final class State: ComponentState {
        private let getController: () -> ViewController?
        private let disposables = DisposableSet()

        fileprivate var walletState: WalletContext.State?
        fileprivate var isAuthorizing = false
        fileprivate var isConfirming = false

        init(
            walletContext: WalletContext,
            getController: @escaping () -> ViewController?
        ) {
            self.getController = getController

            super.init()

            self.disposables.add((walletContext.state
            |> deliverOnMainQueue).start(next: { [weak self] walletState in
                guard let self else {
                    return
                }
                self.walletState = walletState
                self.updated(transition: .easeInOut(duration: 0.25))
            }))
        }

        deinit {
            self.disposables.dispose()
        }

        func finish(_ result: WalletTransferFinishResult, animated: Bool, animateOut: ActionSlot<Action<Void>>) {
            guard let controller = self.getController() as? WalletTransferScreen else {
                return
            }
            controller.finish(result, animated: animated, animateOut: animateOut)
        }

        func confirm(component: WalletTransferSheetContent) {
            guard !self.isAuthorizing, !self.isConfirming else {
                return
            }
            self.isAuthorizing = true
            component.updateIsBusy(true)
            self.updated(transition: .easeInOut(duration: 0.2))

            component.context.sharedContext.authorizeWalletAccess(context: component.context, completion: { [weak self] authorized in
                Queue.mainQueue().async {
                    guard let self, self.isAuthorizing else {
                        return
                    }
                    self.isAuthorizing = false
                    guard authorized else {
                        component.updateIsBusy(false)
                        self.updated(transition: .easeInOut(duration: 0.2))
                        return
                    }

                    self.isConfirming = true
                    self.updated(transition: .easeInOut(duration: 0.2))
                    component.confirm({ [weak self] result in
                        guard let self else {
                            return
                        }
                        switch result {
                        case .success:
                            self.finish(.confirmed, animated: true, animateOut: component.animateOut)
                        case .failure:
                            self.isConfirming = false
                            component.updateIsBusy(false)
                            self.updated(transition: .easeInOut(duration: 0.2))
                            guard let controller = self.getController() else {
                                return
                            }
                            //TODO:localize
                            let errorText = "Unable to send this transaction. Please try again."
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(textAlertController(
                                context: component.context,
                                title: nil,
                                text: errorText,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                ]
                            ), in: .window(.root))
                        }
                    })
                }
            })
        }
    }

    func makeState() -> State {
        return State(walletContext: self.walletContext, getController: self.getController)
    }

    static var body: Body {
        let appIcon = Child(WalletConnectAppIconComponent.self)
        let title = Child(BalancedTextComponent.self)
        let domain = Child(HStack<Empty>.self)
        let card = Child(WalletTransferCardComponent.self)
        let fee = Child(BalancedTextComponent.self)
        let cancelButton = Child(ButtonComponent.self)
        let confirmButton = Child(ButtonComponent.self)
        let closeButton = Child(GlassBarButtonComponent.self)

        return { context in
            let component = context.component
            let state = context.state
            let environment = context.environment[EnvironmentType.self].value
            let theme = environment.theme

            let safeContentWidth = max(
                0.0,
                context.availableSize.width - environment.safeInsets.left - environment.safeInsets.right
            )
            let contentCenterX = environment.safeInsets.left + safeContentWidth / 2.0
            let textWidth = max(1.0, safeContentWidth - 48.0)
            let primaryTextColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let accentColor = theme.actionSheet.controlAccentColor

            var contentHeight: CGFloat = 32.0

            let appIconSize = CGSize(width: 88.0, height: 88.0)
            let appIconCenter = CGPoint(
                x: contentCenterX,
                y: contentHeight + appIconSize.height / 2.0
            )
            let appIcon = appIcon.update(
                component: WalletConnectAppIconComponent(
                    applicationName: component.request.applicationName,
                    url: component.request.iconUrl
                ),
                availableSize: appIconSize,
                transition: context.transition
            )
            context.add(appIcon
                .position(appIconCenter)
                .cornerRadius(appIconSize.width * 0.5)
                .clipsToBounds(true)
            )
            contentHeight += appIconSize.height
            contentHeight += 18.0

            //TODO:localize
            let titleText = "\(component.request.applicationName) requests a transfer"
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(22.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + title.size.height / 2.0
            )))
            contentHeight += title.size.height
            contentHeight += 4.0

            let domainItems: [AnyComponentWithIdentity<Empty>] = [AnyComponentWithIdentity(
                id: "domain",
                component: AnyComponent(Text(
                    text: component.request.domain,
                    font: Font.semibold(15.0),
                    color: accentColor
                ))
            )]
            let domain = domain.update(
                component: HStack<Empty>(domainItems, spacing: 4.0),
                availableSize: CGSize(width: textWidth, height: 30.0),
                transition: .immediate
            )
            context.add(domain.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + domain.size.height / 2.0
            )))
            contentHeight += domain.size.height
            contentHeight += 20.0

            let fiatCurrency = state.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = state.walletState?.fiat.selectedRate
            let cardWidth = min(361.0, max(1.0, safeContentWidth - 42.0))
            let card = card.update(
                component: WalletTransferCardComponent(
                    amount: component.request.amount,
                    recipient: component.request.recipient,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat
                ),
                availableSize: CGSize(width: cardWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(card
                .position(CGPoint(
                    x: contentCenterX,
                    y: contentHeight + card.size.height / 2.0
                ))
                .clipsToBounds(true)
            )
            contentHeight += card.size.height
            contentHeight += 18.0

            let formattedFee = formatTonAmountText(
                component.request.fee,
                dateTimeFormat: environment.dateTimeFormat,
                maxDecimalPositions: 9
            )
            let feeText: String
            if let fiatRate {
                let fiatFee = formatTonFiatValue(
                    component.request.fee,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: fiatCurrency.symbol,
                    maxDecimalPositions: 4,
                    dateTimeFormat: environment.dateTimeFormat
                )
                //TODO:localize
                feeText = "Network fee: \(formattedFee) Grams (≈\(fiatFee))."
            } else {
                //TODO:localize
                feeText = "Network fee: \(formattedFee) Grams."
            }
            let fee = fee.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: feeText,
                        font: Font.regular(13.0),
                        textColor: secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(fee.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + fee.size.height / 2.0
            )))
            contentHeight += fee.size.height
            contentHeight += 20.0

            let buttonSpacing: CGFloat = 10.0
            let buttonInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let buttonsWidth = max(2.0, safeContentWidth - buttonInsets.left - buttonInsets.right)
            let cancelButtonWidth = floorToScreenPixels((buttonsWidth - buttonSpacing) / 2.0)
            let confirmButtonWidth = buttonsWidth - buttonSpacing - cancelButtonWidth
            let isBusy = state.isAuthorizing || state.isConfirming

            //TODO:localize
            let cancelTitle = "Cancel"
            let cancelButton = cancelButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: theme.list.itemPrimaryTextColor,
                        pressedColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "cancel",
                        component: AnyComponent(Text(
                            text: cancelTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemPrimaryTextColor
                        ))
                    ),
                    isEnabled: !isBusy,
                    action: { [weak state] in
                        state?.finish(.cancelled, animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: cancelButtonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(cancelButton.position(CGPoint(
                x: contentCenterX - buttonSpacing / 2.0 - cancelButton.size.width / 2.0,
                y: contentHeight + cancelButton.size.height / 2.0
            )))

            //TODO:localize
            let confirmTitle = "Confirm"
            let confirmButton = confirmButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "confirm",
                        component: AnyComponent(Text(
                            text: confirmTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: !isBusy,
                    displaysProgress: state.isConfirming,
                    action: { [weak state] in
                        state?.confirm(component: component)
                    }
                ),
                availableSize: CGSize(width: confirmButtonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(confirmButton.position(CGPoint(
                x: contentCenterX + buttonSpacing / 2.0 + confirmButton.size.width / 2.0,
                y: contentHeight + confirmButton.size.height / 2.0
            )))
            contentHeight += max(cancelButton.size.height, confirmButton.size.height)
            contentHeight += buttonInsets.bottom

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(
                        id: "close",
                        component: AnyComponent(BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        ))
                    ),
                    action: { [weak state] _ in
                        guard let state, !state.isAuthorizing, !state.isConfirming else {
                            return
                        }
                        state.finish(.cancelled, animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton.position(CGPoint(
                x: environment.safeInsets.left + 16.0 + closeButton.size.width / 2.0,
                y: 16.0 + closeButton.size.height / 2.0
            )))

            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class WalletTransferSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectTransferRequest
    let confirm: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectTransferRequest,
        confirm: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.request = request
        self.confirm = confirm
    }

    static func ==(lhs: WalletTransferSheetComponent, rhs: WalletTransferSheetComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.request == rhs.request
    }

    final class State: ComponentState {
        fileprivate var isBusy = false

        func updateIsBusy(_ value: Bool) {
            guard self.isBusy != value else {
                return
            }
            self.isBusy = value
            self.updated(transition: .easeInOut(duration: 0.2))
        }
    }

    func makeState() -> State {
        return State()
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let componentState = context.state

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletTransferSheetContent(
                        context: context.component.context,
                        walletContext: context.component.walletContext,
                        request: context.component.request,
                        confirm: context.component.confirm,
                        updateIsBusy: { [weak componentState] value in
                            componentState?.updateIsBusy(value)
                        },
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    isScrollEnabled: !componentState.isBusy,
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
                            guard !componentState.isBusy else {
                                return
                            }
                            if let controller = controller() as? WalletTransferScreen {
                                controller.finish(.cancelled, animated: animated, animateOut: animateOut)
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

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

public final class WalletTransferScreen: ViewControllerComponentContainer {
    private let cancelled: () -> Void
    private var finishResult: WalletTransferFinishResult?

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectTransferRequest,
        cancelled: @escaping () -> Void,
        confirm: @escaping (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void
    ) {
        self.cancelled = cancelled

        super.init(
            context: context,
            component: WalletTransferSheetComponent(
                context: context,
                walletContext: walletContext,
                request: request,
                confirm: confirm
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

    fileprivate func finish(
        _ result: WalletTransferFinishResult,
        animated: Bool,
        animateOut: ActionSlot<Action<Void>>?
    ) {
        guard self.finishResult == nil else {
            return
        }
        self.finishResult = result

        let callback: () -> Void
        switch result {
        case .cancelled:
            callback = self.cancelled
        case .confirmed:
            callback = {}
        }

        let dismissController: () -> Void = { [weak self] in
            guard let self else {
                callback()
                return
            }
            self.dismiss(completion: callback)
        }
        if animated, let animateOut {
            animateOut.invoke(Action { _ in
                dismissController()
            })
        } else if animated {
            dismissController()
        } else {
            self.dismiss(animated: false, completion: nil)
            callback()
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.finish(.cancelled, animated: false, animateOut: nil)
        }
    }
}
