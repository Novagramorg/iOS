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
import ResizableSheetComponent
import NavigationStackComponent
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

private final class WalletTransferSheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let request: WalletContext.TonConnectOperationRequest
    let walletState: WalletContext.State?
    let bottomInset: CGFloat
    let infoPressed: () -> Void

    init(
        context: AccountContext,
        request: WalletContext.TonConnectOperationRequest,
        walletState: WalletContext.State?,
        bottomInset: CGFloat,
        infoPressed: @escaping () -> Void
    ) {
        self.context = context
        self.request = request
        self.walletState = walletState
        self.bottomInset = bottomInset
        self.infoPressed = infoPressed
    }

    static func ==(lhs: WalletTransferSheetContent, rhs: WalletTransferSheetContent) -> Bool {
        return lhs.request == rhs.request
            && lhs.walletState == rhs.walletState
            && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private let appIcon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let domain = ComponentView<Empty>()
        private let card = ComponentView<Empty>()
        private let fee = ComponentView<Empty>()
        private let dataText = UITextView()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransferSheetContent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let theme = environment.theme
            transition.setBackgroundColor(view: self, color: theme.list.modalPlainBackgroundColor)

            let safeContentWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right
            )
            let contentCenterX = environment.safeInsets.left + safeContentWidth / 2.0
            let textWidth = max(1.0, safeContentWidth - 48.0)
            let primaryTextColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let accentColor = theme.actionSheet.controlAccentColor

            var contentHeight: CGFloat = 32.0

            self.appIcon.parentState = state
            let appIconSize = CGSize(width: 88.0, height: 88.0)
            let _ = self.appIcon.update(
                transition: transition,
                component: AnyComponent(WalletConnectAppIconComponent(
                    context: component.context,
                    applicationName: component.request.applicationName,
                    icon: component.request.icon
                )),
                environment: {},
                containerSize: appIconSize
            )
            if let appIconView = self.appIcon.view {
                if appIconView.superview == nil {
                    self.addSubview(appIconView)
                }
                appIconView.clipsToBounds = true
                transition.setCornerRadius(layer: appIconView.layer, cornerRadius: appIconSize.width * 0.5)
                transition.setFrame(
                    view: appIconView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - appIconSize.width / 2.0), y: contentHeight),
                        size: appIconSize
                    )
                )
            }
            contentHeight += appIconSize.height
            contentHeight += 18.0

            //TODO:localize
            let titleText = component.request.signData == nil ? "Confirm Action" : "Sign Data"
            self.title.parentState = state
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(22.0),
                        textColor: primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - titleSize.width / 2.0), y: contentHeight),
                        size: titleSize
                    )
                )
            }
            contentHeight += titleSize.height
            contentHeight += 4.0

            let domainItems: [AnyComponentWithIdentity<Empty>] = [AnyComponentWithIdentity(
                id: "domain",
                component: AnyComponent(Text(
                    text: component.request.domain,
                    font: Font.semibold(15.0),
                    color: accentColor
                ))
            )]
            self.domain.parentState = state
            let domainSize = self.domain.update(
                transition: .immediate,
                component: AnyComponent(HStack<Empty>(domainItems, spacing: 4.0)),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 30.0)
            )
            if let domainView = self.domain.view {
                if domainView.superview == nil {
                    self.addSubview(domainView)
                }
                transition.setFrame(
                    view: domainView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - domainSize.width / 2.0), y: contentHeight),
                        size: domainSize
                    )
                )
            }
            contentHeight += domainSize.height
            contentHeight += 20.0

            if let request = component.request.signData {
                self.card.view?.isHidden = true
                self.fee.view?.isHidden = true
                if self.dataText.superview == nil { self.addSubview(self.dataText) }
                self.dataText.isHidden = false
                self.dataText.isEditable = false
                self.dataText.isSelectable = true
                self.dataText.isScrollEnabled = true
                self.dataText.backgroundColor = .clear
                self.dataText.textColor = primaryTextColor
                self.dataText.font = UIFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
                self.dataText.textContainer.lineBreakMode = .byCharWrapping
                switch request.payload {
                case let .text(text): self.dataText.text = text
                case let .binary(bytes):
                    self.dataText.text = "You are signing unknown binary data.\n\n" + bytes.base64EncodedString()
                case let .cell(schema, boc):
                    self.dataText.text = "You are signing unknown cell data.\n\n" + schema + "\n\n" + boc.base64EncodedString()
                }
                let height = min(320.0, max(100.0, self.dataText.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height))
                transition.setFrame(view: self.dataText, frame: CGRect(x: contentCenterX - textWidth / 2.0, y: contentHeight, width: textWidth, height: height))
                return CGSize(width: availableSize.width, height: contentHeight + height + 20.0 + component.bottomInset)
            }
            self.dataText.isHidden = true
            self.card.view?.isHidden = false
            self.fee.view?.isHidden = false

            let presentation = WalletTransferPresentation(request: component.request, walletState: component.walletState)
            let fiatCurrency = component.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = component.walletState?.fiat.selectedRate
            let amountNanograms = presentation.amountNanograms
            let amount = amountNanograms.flatMap { Int64($0) }
            let cardWidth = min(361.0, max(1.0, safeContentWidth - 42.0))
            self.card.parentState = state
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletTransferCardComponent(
                    amount: amount ?? 0,
                    recipient: presentation.recipient,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    amountText: amount == nil ? formatTonConnectNanograms(amountNanograms ?? "", dateTimeFormat: environment.dateTimeFormat) : nil,
                    recipientTitle: presentation.recipientTitle,
                    infoPressed: component.infoPressed
                )),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: availableSize.height)
            )
            if let cardView = self.card.view {
                if cardView.superview == nil {
                    self.addSubview(cardView)
                }
                cardView.clipsToBounds = true
                transition.setFrame(
                    view: cardView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - cardSize.width / 2.0), y: contentHeight),
                        size: cardSize
                    )
                )
            }
            contentHeight += cardSize.height
            contentHeight += 18.0

            let feeText = presentation.feeText(dateTimeFormat: environment.dateTimeFormat, compact: true)
            self.fee.parentState = state
            let feeSize = self.fee.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: feeText,
                        font: Font.regular(15.0),
                        textColor: secondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: availableSize.height)
            )
            if let feeView = self.fee.view {
                if feeView.superview == nil {
                    self.addSubview(feeView)
                }
                transition.setFrame(
                    view: feeView,
                    frame: CGRect(
                        origin: CGPoint(x: floor(contentCenterX - feeSize.width / 2.0), y: contentHeight),
                        size: feeSize
                    )
                )
            }
            contentHeight += feeSize.height
            contentHeight += component.bottomInset

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
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

private final class WalletTransferActionsComponent: Component {
    let theme: PresentationTheme
    let isBusy: Bool
    let isConfirming: Bool
    let cancel: () -> Void
    let confirm: () -> Void

    init(
        theme: PresentationTheme,
        isBusy: Bool,
        isConfirming: Bool,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) {
        self.theme = theme
        self.isBusy = isBusy
        self.isConfirming = isConfirming
        self.cancel = cancel
        self.confirm = confirm
    }

    static func ==(lhs: WalletTransferActionsComponent, rhs: WalletTransferActionsComponent) -> Bool {
        return lhs.theme == rhs.theme
            && lhs.isBusy == rhs.isBusy
            && lhs.isConfirming == rhs.isConfirming
    }

    final class View: UIView {
        private let cancelButton = ComponentView<Empty>()
        private let confirmButton = ComponentView<Empty>()

        private var component: WalletTransferActionsComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransferActionsComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let buttonSpacing: CGFloat = 10.0
            let height = min(52.0, availableSize.height)
            let cancelButtonWidth = floorToScreenPixels((availableSize.width - buttonSpacing) / 2.0)
            let confirmButtonWidth = availableSize.width - buttonSpacing - cancelButtonWidth

            //TODO:localize
            let cancelTitle = "Cancel"
            let cancelSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: component.theme.list.itemPrimaryTextColor,
                        pressedColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.16),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "cancel",
                        component: AnyComponent(Text(
                            text: cancelTitle,
                            font: Font.semibold(17.0),
                            color: component.theme.list.itemPrimaryTextColor
                        ))
                    ),
                    isEnabled: !component.isBusy,
                    action: { [weak self] in
                        self?.component?.cancel()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: cancelButtonWidth, height: height)
            )
            if let cancelView = self.cancelButton.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                transition.setFrame(view: cancelView, frame: CGRect(origin: .zero, size: cancelSize))
            }

            //TODO:localize
            let confirmTitle = "Confirm"
            let confirmSize = self.confirmButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: component.theme.list.itemCheckColors.fillColor,
                        foreground: component.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: "confirm",
                        component: AnyComponent(Text(
                            text: confirmTitle,
                            font: Font.semibold(17.0),
                            color: component.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: !component.isBusy,
                    displaysProgress: component.isConfirming,
                    action: { [weak self] in
                        self?.component?.confirm()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: confirmButtonWidth, height: height)
            )
            if let confirmView = self.confirmButton.view {
                if confirmView.superview == nil {
                    self.addSubview(confirmView)
                }
                transition.setFrame(
                    view: confirmView,
                    frame: CGRect(
                        origin: CGPoint(x: cancelButtonWidth + buttonSpacing, y: 0.0),
                        size: confirmSize
                    )
                )
            }

            return CGSize(width: availableSize.width, height: height)
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
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletTransferSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let request: WalletContext.TonConnectOperationRequest
    let confirm: (@escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectOperationRequest,
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
        private let disposables = DisposableSet()
        private var isFinished = false

        fileprivate var walletState: WalletContext.State?
        fileprivate var isAuthorizing = false
        fileprivate var isConfirming = false
        fileprivate var isPreviewPresented = false

        fileprivate var isBusy: Bool {
            return self.isAuthorizing || self.isConfirming
        }

        init(walletContext: WalletContext) {
            super.init()

            self.disposables.add((walletContext.state
            |> deliverOnMainQueue).start(next: { [weak self] walletState in
                guard let self, !self.isFinished else {
                    return
                }
                self.walletState = walletState
                self.updated(transition: .easeInOut(duration: 0.25))
            }))
        }

        deinit {
            self.disposables.dispose()
        }

        func finish(
            _ result: WalletTransferFinishResult,
            getController: () -> ViewController?,
            animated: Bool,
            animateOut: ActionSlot<Action<Void>>?
        ) {
            guard !self.isFinished, let controller = getController() as? WalletTransferScreen else {
                return
            }
            self.isFinished = true
            controller.finish(result, animated: animated, animateOut: animateOut)
        }

        func confirm(
            component: WalletTransferSheetComponent,
            getController: @escaping () -> ViewController?,
            animateOut: ActionSlot<Action<Void>>
        ) {
            guard !self.isFinished, !self.isAuthorizing, !self.isConfirming else {
                return
            }
            self.isAuthorizing = true
            self.updated(transition: .easeInOut(duration: 0.2))

            self.isAuthorizing = false
            self.isConfirming = true
            getController()?.view.isUserInteractionEnabled = false
            self.updated(transition: .easeInOut(duration: 0.2))
            component.confirm({ [weak self] result in
                Queue.mainQueue().async {
                    guard let self, !self.isFinished, let controller = getController() as? WalletTransferScreen, !controller.isDismissed else {
                        return
                    }
                    getController()?.view.isUserInteractionEnabled = true
                    switch result {
                    case .success:
                        self.finish(
                            .confirmed,
                            getController: getController,
                            animated: true,
                            animateOut: animateOut
                        )
                    case let .failure(error):
                        self.isConfirming = false
                        self.updated(transition: .easeInOut(duration: 0.2))
                        guard error != .authorizationCancelled else { return }
                        guard let controller = getController() else {
                            return
                        }
                        //TODO:localize
                        let errorText = "Unable to complete this request. Please try again."
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(textAlertController(
                            context: component.context,
                            title: nil,
                            text: errorText,
                            actions: [
                                TextAlertAction(
                                    type: .defaultAction,
                                    title: presentationData.strings.Common_OK,
                                    action: {}
                                )
                            ]
                        ), in: .window(.root))
                    }
                }
            })
        }
    }

    func makeState() -> State {
        return State(walletContext: self.walletContext)
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)

        return { context in
            let component = context.component
            let componentState = context.state
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let theme = environment.theme.withModalBlocksBackground()

            let dismiss: (Bool) -> Void = { [weak componentState] animated in
                componentState?.finish(
                    .cancelled,
                    getController: controller,
                    animated: animated,
                    animateOut: animated ? animateOut : nil
                )
            }

            let bottomInsets = ContainerViewLayout.concentricInsets(
                bottomInset: environment.safeInsets.bottom,
                innerDiameter: 52.0,
                sideInset: 30.0
            )
            let contentBottomInset = bottomInsets.bottom + 52.0 + 16.0

            let popPreview: () -> Void = { [weak componentState] in
                guard let componentState, componentState.isPreviewPresented else {
                    return
                }
                componentState.isPreviewPresented = false
                componentState.updated(transition: .spring(duration: 0.45))
            }

            var navigationItems: [AnyComponentWithIdentity<EnvironmentType>] = [
                AnyComponentWithIdentity(
                    id: "transfer",
                    component: AnyComponent(WalletTransferSheetContent(
                        context: component.context,
                        request: component.request,
                        walletState: componentState.walletState,
                        bottomInset: contentBottomInset,
                        infoPressed: { [weak componentState] in
                            guard let componentState, !componentState.isPreviewPresented else {
                                return
                            }
                            componentState.isPreviewPresented = true
                            componentState.updated(transition: .spring(duration: 0.45))
                        }
                    ))
                )
            ]
            if componentState.isPreviewPresented {
                navigationItems.append(AnyComponentWithIdentity(
                    id: "preview",
                    component: AnyComponent(WalletTransferPreviewComponent(
                        context: component.context,
                        request: component.request,
                        walletState: componentState.walletState,
                        bottomInset: contentBottomInset
                    ))
                ))
            }

            let titleItem: AnyComponent<Empty>?
            let rightItem: AnyComponent<Empty>?
            if componentState.isPreviewPresented {
                titleItem = AnyComponent(VStack<Empty>([
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: "Confirm Action",
                            font: Font.semibold(17.0),
                            color: theme.actionSheet.primaryTextColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "domain",
                        component: AnyComponent(Text(
                            text: component.request.domain,
                            font: Font.regular(13.0),
                            color: theme.actionSheet.secondaryTextColor
                        ))
                    )
                ], spacing: 0.0))
                rightItem = AnyComponent(WalletTransferNavigationAppIconComponent(
                    context: component.context,
                    applicationName: component.request.applicationName,
                    icon: component.request.icon
                ))
            } else {
                titleItem = nil
                rightItem = nil
            }

            let sheetComponent = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(NavigationStackComponent(
                        items: navigationItems,
                        clipContent: true,
                        requestPop: popPreview
                    )),
                    titleItem: titleItem,
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(
                            id: componentState.isPreviewPresented ? "back" : "close",
                            component: AnyComponent(BundleIconComponent(
                                name: componentState.isPreviewPresented ? "Navigation/Back" : "Navigation/Close",
                                tintColor: theme.chat.inputPanel.panelControlColor
                            ))
                        ),
                        action: { [weak componentState] _ in
                            guard let componentState else {
                                return
                            }
                            if componentState.isPreviewPresented {
                                popPreview()
                            } else if !componentState.isBusy {
                                dismiss(true)
                            }
                        }
                    )),
                    rightItem: rightItem,
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(WalletTransferActionsComponent(
                        theme: theme,
                        isBusy: componentState.isBusy,
                        isConfirming: componentState.isConfirming,
                        cancel: {
                            dismiss(true)
                        },
                        confirm: { [weak componentState] in
                            componentState?.confirm(
                                component: component,
                                getController: controller,
                                animateOut: animateOut
                            )
                        }
                    )),
                    backgroundColor: .color(theme.list.plainBackgroundColor),
                    clipsContent: true,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: 0.0,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

            return context.availableSize
        }
    }
}

public final class WalletTransferScreen: ViewControllerComponentContainer {
    private let cancelled: () -> Void
    public var tonConnectClosed: (() -> Void)?
    private var finishResult: WalletTransferFinishResult?
    fileprivate var isDismissed = false

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.isDismissed = true
        super.dismiss(animated: flag, completion: completion)
    }

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        request: WalletContext.TonConnectOperationRequest,
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

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
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
            self.dismiss(completion: {
                callback()
                self.tonConnectClosed?()
            })
        }
        if animated, let animateOut {
            animateOut.invoke(Action { _ in
                dismissController()
            })
        } else if animated {
            dismissController()
        } else {
            self.dismiss(animated: false, completion: {
                callback()
                self.tonConnectClosed?()
            })
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.finish(.cancelled, animated: false, animateOut: nil)
        }
    }
}
