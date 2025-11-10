import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import Markdown
import BalancedTextComponent
import TextFormat
import TelegramStringFormatting
import StarsAvatarComponent
import PlainButtonComponent
import TooltipUI
import GiftAnimationComponent
import ContextUI
import GiftItemComponent
import GlassBarButtonComponent

private final class GiftAuctionViewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.auctionContext = auctionContext
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftAuctionViewSheetContent, rhs: GiftAuctionViewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let lastSalePriceTag = GenericComponentViewTag()
        let floorPriceTag = GenericComponentViewTag()
        let averagePriceTag = GenericComponentViewTag()
        
        private let context: AccountContext
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        var initialized = false
                
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedSmallStarImage: (UIImage, PresentationTheme)?
        var cachedSubtitleStarImage: (UIImage, PresentationTheme)?
        var cachedTonImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
                                        
        init(
            context: AccountContext,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
            
//            if case let .starGift(gift, _) = component.subject, gift.flags.contains(.isAuction), let giftAuctionsManager = component.context.giftAuctionsManager, let giftAuction = giftAuctionsManager.auctionContext(for: .giftId(gift.id)) {
//                self.giftAuction = giftAuction
//                self.giftAuctionDisposable = (giftAuction.state
//                |> deliverOnMainQueue).start(next: { [weak self] state in
//                    guard let self else {
//                        return
//                    }
//                    self.giftAuctionState = state
//                    self.state?.updated()
//                })
//                
//                self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
//                    self?.state?.updated()
//                }, queue: Queue.mainQueue())
//                self.giftAuctionTimer?.start()
//            }
            
//            if let _ = self.giftAuction {
//                //TODO:localize
//                let buttonAttributedString = NSMutableAttributedString(string: "Place a Bid", font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
//                buttonTitleItems.append(AnyComponentWithIdentity(id: "bid", component: AnyComponent(
//                    MultilineTextComponent(text: .plain(buttonAttributedString))
//                )))
//                if let giftAuctionState = self.giftAuctionState {
//                    switch giftAuctionState.auctionState {
//                    case let .ongoing(_, _, _, _, nextDropDate, _, _, _):
//                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
//                        let dropTimeout = nextDropDate - currentTime
//                        
//                        let minutes = Int(dropTimeout / 60)
//                        let seconds = Int(dropTimeout % 60)
//                        
//                        let rawString = environment.strings.Gift_Setup_NextDropIn
//                        var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
//                        var startIndex = rawString.startIndex
//                        while true {
//                            if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
//                                if range.lowerBound != startIndex {
//                                    buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .text(String(rawString[startIndex ..< range.lowerBound]))))
//                                }
//                                
//                                startIndex = range.upperBound
//                                if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
//                                    let controlString = rawString[range.upperBound ..< endRange.lowerBound]
//                                    if controlString == "m" {
//                                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .number(minutes, minDigits: 2)))
//                                    } else if controlString == "s" {
//                                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .number(seconds, minDigits: 2)))
//                                    }
//                                    
//                                    startIndex = endRange.upperBound
//                                }
//                            } else {
//                                break
//                            }
//                        }
//                        if startIndex != rawString.endIndex {
//                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
//                        }
//                        
//                        buttonTitleItems.append(AnyComponentWithIdentity(id: "timer", component: AnyComponent(AnimatedTextComponent(
//                            font: Font.with(size: 12.0, weight: .medium, traits: .monospacedNumbers),
//                            color: environment.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
//                            items: buttonAnimatedTitleItems,
//                            noDelay: true
//                        ))))
//                    case .finished:
//                        buttonIsEnabled = false
//                    }
//                } else {
//                    buttonIsLoading = true
//                }
//            } else {
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .markdown(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openGiftResale(gift: StarGift.Gift) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            let storeController = self.context.sharedContext.makeGiftStoreController(
                context: self.context,
                peerId: self.context.account.peerId,
                gift: gift
            )
            controller.push(storeController)
        }
        
        func openGiftFragmentResale(url: String) {
            guard let controller = self.getController() as? GiftAuctionViewScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            if animated {
                controller.dismissAllTooltips()
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        
        let titleBackground = Child(RoundedRectangle.self)
        let title = Child(MultilineTextComponent.self)
        
        let description = Child(MultilineTextComponent.self)
        
        let table = Child(TableComponent.self)
        
//        let telegramSaleButton = Child(PlainButtonComponent.self)
//        let fragmentSaleButton = Child(PlainButtonComponent.self)
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let titleString: String = "Gift Name"
            var animationFile: TelegramMediaFile?
            var giftIconSubject: GiftItemComponent.Subject?
            var genericGift: StarGift.Gift?
            
            switch component.auctionContext.gift {
            case let .generic(gift):
                animationFile = gift.file
                giftIconSubject = .starGift(gift: gift, price: "")
                genericGift = gift
            default:
                break
            }
            
            let _ = giftIconSubject
            let _ = genericGift
                 
            var originY: CGFloat = 0.0
                        
            let headerHeight: CGFloat = 210.0
            let headerSubject: GiftCompositionComponent.Subject?
            if let animationFile {
                headerSubject = .generic(animationFile)
            } else {
                headerSubject = nil
            }
            if let headerSubject {
                let animation = animation.update(
                    component: GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: headerSubject,
                        animationOffset: nil,
                        animationScale: nil,
                        displayAnimationStars: false,
                        externalState: giftCompositionExternalState,
                        requestUpdate: { [weak state] _ in
                            state?.updated()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                    transition: context.transition
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
                )
            }
            originY += headerHeight
                       
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleString,
                        font: Font.with(size: 24.0, design: .round, weight: .bold),
                        textColor: theme.list.itemCheckColors.foregroundColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            let titleBackground = titleBackground.update(
                component: RoundedRectangle(color: theme.actionSheet.controlAccentColor, cornerRadius: 24.0),
                environment: {},
                availableSize: CGSize(width: title.size.width + 32.0, height: 48.0),
                transition: .immediate
            )
            context.add(titleBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 187.0))
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 187.0))
            )
                       
            let descriptionText: String = "description"
            let description = description.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: descriptionText))
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 231.0 + description.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            originY += description.size.height
            originY += 42.0
            
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
    
            var tableItems: [TableComponent.Item] = []
            tableItems.append(.init(
                id: "firstSale",
                title: "First Sale",
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: 0, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
            tableItems.append(.init(
                id: "lastSale",
                title: "Last Sale",
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: 0, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            originY += table.size.height + 23.0
            
//            if component.valueInfo.listedCount != nil || component.valueInfo.fragmentListedCount != nil {
//                originY += 5.0
//            }
//                                      
//            if let listedCount = component.valueInfo.listedCount, let giftIconSubject {
//                let telegramSaleButton = telegramSaleButton.update(
//                    component: PlainButtonComponent(
//                        content: AnyComponent(
//                            HStack([
//                                AnyComponentWithIdentity(id: "count", component: AnyComponent(
//                                    MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(listedCount, dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
//                                )),
//                                AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
//                                    Rectangle(color: .clear, width: 8.0, height: 1.0)
//                                )),
//                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
//                                    GiftItemComponent(
//                                        context: component.context,
//                                        theme: theme,
//                                        strings: strings,
//                                        peer: nil,
//                                        subject: giftIconSubject,
//                                        mode: .buttonIcon
//                                    )
//                                )),
//                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
//                                    MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(strings.Gift_Value_ForSaleOnTelegram)", font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
//                                )),
//                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
//                                    BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: theme.actionSheet.controlAccentColor)
//                                ))
//                            ], spacing: 0.0)
//                        ),
//                        action: { [weak state] in
//                            guard let state, let genericGift else {
//                                return
//                            }
//                            state.openGiftResale(gift: genericGift)
//                        },
//                        animateScale: false
//                    ),
//                    environment: {},
//                    availableSize: context.availableSize,
//                    transition: .immediate
//                )
//                context.add(telegramSaleButton
//                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + telegramSaleButton.size.height / 2.0))
//                )
//                originY += telegramSaleButton.size.height
//                originY += 12.0
//            }
//            
//            if let listedCount = component.valueInfo.fragmentListedCount, let fragmentListedUrl = component.valueInfo.fragmentListedUrl, let giftIconSubject {
//                if component.valueInfo.listedCount != nil {
//                    originY += 18.0
//                }
//                
//                let fragmentSaleButton = fragmentSaleButton.update(
//                    component: PlainButtonComponent(
//                        content: AnyComponent(
//                            HStack([
//                                AnyComponentWithIdentity(id: "count", component: AnyComponent(
//                                    MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(listedCount, dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
//                                )),
//                                AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
//                                    Rectangle(color: .clear, width: 8.0, height: 1.0)
//                                )),
//                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
//                                    GiftItemComponent(
//                                        context: component.context,
//                                        theme: theme,
//                                        strings: strings,
//                                        peer: nil,
//                                        subject: giftIconSubject,
//                                        mode: .buttonIcon
//                                    )
//                                )),
//                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
//                                    MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(strings.Gift_Value_ForSaleOnFragment)", font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
//                                )),
//                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
//                                    BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: theme.actionSheet.controlAccentColor)
//                                ))
//                            ], spacing: 0.0)
//                        ),
//                        action: { [weak state] in
//                            state?.openGiftFragmentResale(url: fragmentListedUrl)
//                        },
//                        animateScale: false
//                    ),
//                    environment: {},
//                    availableSize: context.availableSize,
//                    transition: .immediate
//                )
//                context.add(fragmentSaleButton
//                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + fragmentSaleButton.size.height / 2.0))
//                )
//                originY += fragmentSaleButton.size.height
//                originY += 12.0
//            }
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 40.0, height: 40.0),
                    backgroundColor: theme.rootController.navigationBar.glassBarButtonBackgroundColor,
                    isDark: theme.overallDarkAppearance,
                    state: .generic,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.rootController.navigationBar.glassBarButtonForegroundColor
                        )
                    )),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        state.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 40.0, height: 40.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: originY + 5.0 + effectiveBottomInset)
        }
    }
}

final class GiftAuctionViewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext
    ) {
        self.context = context
        self.auctionContext = auctionContext
    }
    
    static func ==(lhs: GiftAuctionViewSheetComponent, rhs: GiftAuctionViewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
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
                    content: AnyComponent<EnvironmentType>(GiftAuctionViewSheetContent(
                        context: context.component.context,
                        auctionContext: context.component.auctionContext,
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
                        if let controller = controller() as? GiftAuctionViewScreen {
                            controller.dismissAllTooltips()
                        }
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? GiftAuctionViewScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftAuctionViewScreen {
                                    controller.dismissAllTooltips()
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

public final class GiftAuctionViewScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        auctionContext: GiftAuctionContext
    ) {
        super.init(
            context: context,
            component: GiftAuctionViewSheetComponent(
                context: context,
                auctionContext: auctionContext
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
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
        
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
            
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            return true
        })
    }
}
