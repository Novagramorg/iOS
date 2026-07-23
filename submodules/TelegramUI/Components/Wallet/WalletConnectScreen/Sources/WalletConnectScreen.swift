import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import WalletContext
import WalletCardComponent

fileprivate enum WalletConnectFinishResult {
    case cancelled
    case connected
}

private final class WalletConnectSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let application: WalletConnectApplication
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        application: WalletConnectApplication,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.application = application
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletConnectSheetContent, rhs: WalletConnectSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        if lhs.application != rhs.application {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let getController: () -> ViewController?
        private let disposables = DisposableSet()

        fileprivate var walletState: WalletContext.State?
        fileprivate var accountName = ""

        init(
            context: AccountContext,
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

            self.disposables.add((context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self else {
                    return
                }
                let accountName = peer?.debugDisplayTitle.uppercased() ?? ""
                if self.accountName != accountName {
                    self.accountName = accountName
                    self.updated(transition: .immediate)
                }
            }))
        }

        deinit {
            self.disposables.dispose()
        }

        func finish(_ result: WalletConnectFinishResult, animated: Bool, animateOut: ActionSlot<Action<Void>>) {
            guard let controller = self.getController() as? WalletConnectScreen else {
                return
            }
            controller.finish(result, animated: animated, animateOut: animateOut)
        }

        func openReceive(context: AccountContext, address: String) {
            guard let controller = self.getController() else {
                return
            }
            let receiveController = context.sharedContext.makeWalletReceiveScreen(
                context: context,
                address: address
            )
            if controller.navigationController != nil {
                controller.push(receiveController)
            } else {
                controller.window?.present(
                    receiveController,
                    on: .root,
                    blockInteraction: false,
                    completion: {
                    }
                )
            }
        }
    }

    func makeState() -> State {
        return State(
            context: self.context,
            walletContext: self.walletContext,
            getController: self.getController
        )
    }

    static var body: Body {
        let appIconBackground = Child(RoundedRectangle.self)
        let appIcon = Child(BundleIconComponent.self)
        let title = Child(BalancedTextComponent.self)
        let domain = Child(HStack<Empty>.self)
        let permission = Child(BalancedTextComponent.self)
        let card = Child(WalletCardComponent.self)
        let disclaimer = Child(BalancedTextComponent.self)
        let cancelButton = Child(ButtonComponent.self)
        let connectButton = Child(ButtonComponent.self)
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
            let appIconBackground = appIconBackground.update(
                component: RoundedRectangle(
                    color: component.application.iconBackgroundColor,
                    cornerRadius: appIconSize.height / 2.0,
                    size: appIconSize
                ),
                availableSize: appIconSize,
                transition: context.transition
            )
            let appIconCenter = CGPoint(
                x: contentCenterX,
                y: contentHeight + appIconSize.height / 2.0
            )
            context.add(appIconBackground.position(appIconCenter))

            let appIcon = appIcon.update(
                component: BundleIconComponent(
                    name: component.application.iconName,
                    tintColor: nil
                ),
                availableSize: appIconSize,
                transition: context.transition
            )
            context.add(appIcon.position(appIconCenter))
            contentHeight += appIconSize.height
            contentHeight += 18.0

            //TODO:localize
            let titleText = "Connect to \(component.application.name)"
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(24.0),
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

            var domainItems: [AnyComponentWithIdentity<Empty>] = []
            if component.application.isVerified {
                domainItems.append(AnyComponentWithIdentity(
                    id: "verified",
                    component: AnyComponent(BundleIconComponent(
                        name: "Instant View/Verified",
                        tintColor: accentColor
                    ))
                ))
            }
            domainItems.append(AnyComponentWithIdentity(
                id: "domain",
                component: AnyComponent(Text(
                    text: component.application.domain,
                    font: Font.semibold(17.0),
                    color: accentColor
                ))
            ))
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

            //TODO:localize
            let permissionText = "It will be able to view your wallet address, balance and activity."
            let permission = permission.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: permissionText,
                        font: Font.regular(17.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(permission.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + permission.size.height / 2.0
            )))
            contentHeight += permission.size.height
            contentHeight += 18.0

            let cardWidth = min(361.0, max(1.0, safeContentWidth - 42.0))
            let walletInfo: WalletContext.WalletInfo?
            if let walletState = state.walletState, case let .wallet(value) = walletState.phase {
                walletInfo = value
            } else {
                walletInfo = nil
            }
            let fiatCurrency = state.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = state.walletState?.fiat.selectedRate
            let card = card.update(
                component: WalletCardComponent(
                    balance: state.walletState?.balance.currentValue,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: state.accountName,
                    address: walletInfo?.address ?? "",
                    qrPressed: { [weak state] in
                        guard let walletInfo else {
                            return
                        }
                        state?.openReceive(
                            context: component.context,
                            address: walletInfo.address
                        )
                    }
                ),
                availableSize: CGSize(width: cardWidth, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(card.position(
                CGPoint(
                    x: contentCenterX,
                    y: contentHeight + card.size.height / 2.0
                ))
                .clipsToBounds(true)
                //.cornerRadius(24.0)
            )
            contentHeight += card.size.height
            contentHeight += 18.0

            //TODO:localize
            let disclaimerText = "\(component.application.name) won’t be able to move funds without permission."
            let disclaimer = disclaimer.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: disclaimerText,
                        font: Font.regular(15.0),
                        textColor: secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: textWidth, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(disclaimer.position(CGPoint(
                x: contentCenterX,
                y: contentHeight + disclaimer.size.height / 2.0
            )))
            contentHeight += disclaimer.size.height
            contentHeight += 20.0

            let buttonSpacing: CGFloat = 10.0
            let buttonInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let buttonsWidth = max(2.0, safeContentWidth - buttonInsets.left - buttonInsets.right)
            let cancelButtonWidth = floorToScreenPixels((buttonsWidth - buttonSpacing) / 2.0)
            let connectButtonWidth = buttonsWidth - buttonSpacing - cancelButtonWidth

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
            let connectTitle = "Connect"
            let connectButton = connectButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "connect",
                        component: AnyComponent(Text(
                            text: connectTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    action: { [weak state] in
                        state?.finish(.connected, animated: true, animateOut: component.animateOut)
                    }
                ),
                availableSize: CGSize(width: connectButtonWidth, height: 52.0),
                transition: context.transition
            )
            context.add(connectButton.position(CGPoint(
                x: contentCenterX + buttonSpacing / 2.0 + connectButton.size.width / 2.0,
                y: contentHeight + connectButton.size.height / 2.0
            )))
            contentHeight += max(cancelButton.size.height, connectButton.size.height)
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
                        state?.finish(.cancelled, animated: true, animateOut: component.animateOut)
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

private final class WalletConnectSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let application: WalletConnectApplication

    init(
        context: AccountContext,
        walletContext: WalletContext,
        application: WalletConnectApplication
    ) {
        self.context = context
        self.walletContext = walletContext
        self.application = application
    }

    static func ==(lhs: WalletConnectSheetComponent, rhs: WalletConnectSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        if lhs.application != rhs.application {
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
                    content: AnyComponent<EnvironmentType>(WalletConnectSheetContent(
                        context: context.component.context,
                        walletContext: context.component.walletContext,
                        application: context.component.application,
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
                            if let controller = controller() as? WalletConnectScreen {
                                controller.finish(
                                    .cancelled,
                                    animated: animated,
                                    animateOut: animateOut
                                )
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

public final class WalletConnectScreen: ViewControllerComponentContainer {
    private let cancelled: () -> Void
    private let connected: () -> Void
    private var finishResult: WalletConnectFinishResult?

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        application: WalletConnectApplication,
        cancelled: @escaping () -> Void,
        connected: @escaping () -> Void
    ) {
        self.cancelled = cancelled
        self.connected = connected

        super.init(
            context: context,
            component: WalletConnectSheetComponent(
                context: context,
                walletContext: walletContext,
                application: application
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
        _ result: WalletConnectFinishResult,
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
        case .connected:
            callback = self.connected
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
