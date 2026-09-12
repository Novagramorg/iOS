import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import WalletContext
import Markdown
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import MultilineTextComponent
import LottieComponent
import GlassBarButtonComponent
import ButtonComponent
import InfoParagraphComponent

private struct WalletInfoLogo: Equatable {
    let name: String
    let loop: Bool
}

private struct WalletInfoItem: Equatable {
    let id: String
    let title: String?
    let text: String
    let iconName: String
}

private struct WalletInfoContent: Equatable {
    let logo: WalletInfoLogo
    let title: String
    let text: String
    let items: [WalletInfoItem]
    let buttonTitle: String
}

private func walletInfoContent(
    mode: WalletInfoScreenMode,
    fiatState: WalletContext.FiatState?,
    dateTimeFormat: PresentationDateTimeFormat
) -> WalletInfoContent {
    switch mode {
    case .wallet:
        //TODO:localize
        let title = "How It Works"
        //TODO:localize
        let text = "Only you control your funds —\nno one else has access."
        //TODO:localize
        let instantTransfersTitle = "Instant Transfers"
        //TODO:localize
        let instantTransfersText = "Send Grams in any chat, just like\nsharing a photo."
        //TODO:localize
        let zeroFeesTitle = "Zero Fees"
        //TODO:localize
        let zeroFeesText = "First 5 transfers each day are free, the\u{00a0}rest cost almost nothing."
        //TODO:localize
        let blockchainVerifiedTitle = "Blockchain Verified"
        //TODO:localize
        let blockchainVerifiedText = "All transactions are recorded\nand verifiable on a public ledger."
        //TODO:localize
        let buttonTitle = "Got it"

        return WalletInfoContent(
            logo: WalletInfoLogo(name: "Diamond", loop: true),
            title: title,
            text: text,
            items: [
                WalletInfoItem(
                    id: "instantTransfers",
                    title: instantTransfersTitle,
                    text: instantTransfersText,
                    iconName: "Wallet/InfoFast"
                ),
                WalletInfoItem(
                    id: "zeroFees",
                    title: zeroFeesTitle,
                    text: zeroFeesText,
                    iconName: "Wallet/InfoCheap"
                ),
                WalletInfoItem(
                    id: "blockchainVerified",
                    title: blockchainVerifiedTitle,
                    text: blockchainVerifiedText,
                    iconName: "Wallet/InfoVerified"
                )
            ],
            buttonTitle: buttonTitle
        )
    case .gram:
        //TODO:localize
        let title = "Gram"
        let text: String
        if let fiatState, let fiatRate = fiatState.selectedRate, fiatRate.unitsPerGram.isFinite, fiatRate.unitsPerGram > 0.0 {
            let fiatRateText = formatFiatValue(
                fiatRate.unitsPerGram,
                currencySymbol: fiatState.selectedCurrency.symbol,
                dateTimeFormat: dateTimeFormat
            )
            //TODO:localize
            text = "The native currency of the TON blockchain. **1 Gram** currently equals **\(fiatRateText)**."
        } else {
            //TODO:localize
            text = "The native currency of the TON blockchain."
        }
        //TODO:localize
        let fastTitle = "Fast"
        //TODO:localize
        let fastText = "Transfers confirm in seconds, anywhere in the world."
        //TODO:localize
        let cheapTitle = "Cheap"
        //TODO:localize
        let cheapText = "Fees are nearly zero, even on large transfers."
        //TODO:localize
        let usefulTitle = "Useful"
        //TODO:localize
        let usefulText = "Pay for apps, services, and fees across the TON ecosystem."
        //TODO:localize
        let buttonTitle = "Got it"

        return WalletInfoContent(
            logo: WalletInfoLogo(name: "Diamond", loop: true),
            title: title,
            text: text,
            items: [
                WalletInfoItem(
                    id: "fast",
                    title: fastTitle,
                    text: fastText,
                    iconName: "Wallet/InfoFast"
                ),
                WalletInfoItem(
                    id: "cheap",
                    title: cheapTitle,
                    text: cheapText,
                    iconName: "Wallet/InfoCheap"
                ),
                WalletInfoItem(
                    id: "useful",
                    title: usefulTitle,
                    text: usefulText,
                    iconName: "Wallet/InfoUseful"
                )
            ],
            buttonTitle: buttonTitle
        )
    case .recovery:
        //TODO:localize
        let title = "Recovery Phrase"
        //TODO:localize
        let text = "Your Secret Recovery Phrase is the key to\u{00a0}back up your wallet. Keep it secret and\u{00a0}secure at all times."
        //TODO:localize
        let neverShareText = "**Never share** your secret Recovery Phrase with anyone."
        //TODO:localize
        let canStealText = "If someone has your Recovery Phrase they **can steal your funds**."
        //TODO:localize
        let supportText = "Telegram Support **will never ask you** for your Recovery Phrase."
        //TODO:localize
        let buttonTitle = "Show Recovery Phrase"

        return WalletInfoContent(
            logo: WalletInfoLogo(name: "WalletWordList", loop: false),
            title: title,
            text: text,
            items: [
                WalletInfoItem(
                    id: "neverShare",
                    title: nil,
                    text: neverShareText,
                    iconName: "Wallet/InfoHidden"
                ),
                WalletInfoItem(
                    id: "canSteal",
                    title: nil,
                    text: canStealText,
                    iconName: "Wallet/InfoWarning"
                ),
                WalletInfoItem(
                    id: "support",
                    title: nil,
                    text: supportText,
                    iconName: "Wallet/InfoShield"
                )
            ],
            buttonTitle: buttonTitle
        )
    }
}

private final class WalletInfoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletInfoScreenMode
    let completion: (() -> Void)?
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletInfoSheetContent, rhs: WalletInfoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        fileprivate let playRecoveryAnimation = ActionSlot<Void>()
        private var didPlayRecoveryAnimation = false
        fileprivate var fiatState: WalletContext.FiatState?
        private var walletStateDisposable: Disposable?

        init(
            context: AccountContext,
            mode: WalletInfoScreenMode,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.animateOut = animateOut
            self.getController = getController

            super.init()

            if mode == .gram, let walletContext = context.walletContext {
                self.fiatState = walletContext.stateValue.fiat
                self.walletStateDisposable = (walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.fiatState != walletState.fiat else {
                        return
                    }
                    self.fiatState = walletState.fiat
                    self.updated(transition: .immediate)
                })
            }
        }

        deinit {
            self.walletStateDisposable?.dispose()
        }

        func playRecoveryAnimationIfNeeded() {
            guard !self.didPlayRecoveryAnimation else {
                return
            }
            self.didPlayRecoveryAnimation = true
            self.playRecoveryAnimation.invoke(Void())
        }

        func openTerms(context: AccountContext, url: String) {
            guard let controller = self.getController() else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            context.sharedContext.openExternalUrl(
                context: context,
                urlContext: .generic,
                url: url,
                forceExternal: false,
                presentationData: presentationData,
                navigationController: controller.navigationController as? NavigationController,
                dismissInput: {}
            )
        }

        func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            guard let controller = self.getController() as? WalletInfoScreen else {
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
    }

    func makeState() -> State {
        return State(
            context: self.context,
            mode: self.mode,
            animateOut: self.animateOut,
            getController: self.getController
        )
    }

    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let animation = Child(LottieComponent.self)
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let button = Child(ButtonComponent.self)
        let terms = Child(MultilineTextComponent.self)

        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let theme = environment.theme
            let content = walletInfoContent(
                mode: component.mode,
                fiatState: state.fiatState,
                dateTimeFormat: environment.dateTimeFormat
            )

            let sideInset: CGFloat = 30.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left

            let titleFont = Font.bold(24.0)
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)

            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor

            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 33.0)

            let animationSize = CGSize(width: 100.0, height: 100.0)
            let animation = animation.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: content.logo.name),
                    startingPosition: .begin,
                    size: animationSize,
                    loop: content.logo.loop,
                    playOnce: content.logo.loop ? nil : state.playRecoveryAnimation
                ),
                availableSize: animationSize,
                transition: context.transition
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + animation.size.height / 2.0))
            )
            if !content.logo.loop {
                state.playRecoveryAnimationIfNeeded()
            }
            contentSize.height += animation.size.height
            contentSize.height += 8.0

            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: content.title, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += spacing - 8.0

            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: content.text,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                            link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            linkAttribute: { _ in nil }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += spacing + 9.0

            let items: [AnyComponentWithIdentity<Empty>] = content.items.map { item in
                return AnyComponentWithIdentity(
                    id: item.id,
                    component: AnyComponent(InfoParagraphComponent(
                        title: item.title,
                        titleColor: textColor,
                        text: item.text,
                        textColor: item.title != nil ? secondaryTextColor : textColor,
                        accentColor: theme.list.itemAccentColor,
                        iconName: item.iconName,
                        iconColor: theme.list.itemAccentColor
                    ))
                )
            }

            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += spacing + 8.0

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

            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(Text(
                            text: content.buttonTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak state] in
                        state?.dismiss(animated: true, completion: component.completion)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 30.0 * 2.0, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height

            if case .wallet = component.mode {
                contentSize.height += 24.0

                //TODO:localize
                let termsString = "By using Wallet you agree to Terms of Service."
                let termsLink = "Terms of Service"
                let termsText = NSMutableAttributedString(
                    string: termsString,
                    attributes: [
                        .font: Font.regular(13.0),
                        .foregroundColor: secondaryTextColor
                    ]
                )
                let termsLinkRange = (termsString as NSString).range(of: termsLink)
                termsText.addAttributes(
                    [
                        .foregroundColor: theme.list.itemAccentColor,
                        NSAttributedString.Key(rawValue: TelegramTextAttributes.URL): environment.strings.Settings_Terms_URL
                    ],
                    range: termsLinkRange
                )

                let terms = terms.update(
                    component: MultilineTextComponent(
                        text: .plain(termsText),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak state] attributes, _ in
                            guard let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String else {
                                return
                            }
                            state?.openTerms(context: component.context, url: url)
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(terms
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + terms.size.height / 2.0))
                )
                contentSize.height += terms.size.height
            }
            contentSize.height += 30.0

            return contentSize
        }
    }
}

private final class WalletInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletInfoScreenMode
    let completion: (() -> Void)?

    init(
        context: AccountContext,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
    }

    static func ==(lhs: WalletInfoSheetComponent, rhs: WalletInfoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
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
                    content: AnyComponent<EnvironmentType>(WalletInfoSheetContent(
                        context: context.component.context,
                        mode: context.component.mode,
                        completion: context.component.completion,
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
                                if let controller = controller() as? WalletInfoScreen {
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? WalletInfoScreen {
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
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }

            return context.availableSize
        }
    }
}

public final class WalletInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init(
        context: AccountContext,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?
    ) {
        self.context = context

        super.init(
            context: context,
            component: WalletInfoSheetComponent(
                context: context,
                mode: mode,
                completion: completion
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
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
