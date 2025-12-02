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
import ButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import StarsAvatarComponent
import EmojiTextAttachmentView
import EmojiStatusComponent
import UndoUI
import ConfettiEffect
import PlainButtonComponent
import CheckComponent
import TooltipUI
import LottieComponent
import ContextUI
import TelegramNotices
import PremiumLockButtonSubtitleComponent
import StarsBalanceOverlayComponent
import BalanceNeededScreen
import GiftItemComponent
import GiftAnimationComponent
import ChatThemeScreen
import ProfileLevelRatingBarComponent
import AnimatedTextComponent

private final class GiftAuctionUpgradePreviewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: StarGift
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        gift: StarGift,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.gift = gift
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftAuctionUpgradePreviewSheetContent, rhs: GiftAuctionUpgradePreviewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
                        
        private var peerDisposable: Disposable?
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        var upgradePreviewTimer: SwiftSignalKit.Timer?
                
        init(
            context: AccountContext
        ) {
            self.context = context
            
            super.init()
            
            let peerIds: [EnginePeer.Id] = [context.account.peerId]
                
            self.peerDisposable = (
                context.engine.data.get(EngineDataMap(
                    peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    }
                ))
                |> deliverOnMainQueue
            ).startStrict(next: { [weak self] peers in
                if let strongSelf = self {
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for (peerId, maybePeer) in peers {
                        if let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    strongSelf.peerMap = peersMap
                    strongSelf.updated(transition: .immediate)
                }
            })
            
            self.upgradePreviewTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: true, completion: { [weak self] in
                self?.upgradePreviewTimerTick()
            }, queue: Queue.mainQueue())
            self.upgradePreviewTimer?.start()
            self.upgradePreviewTimerTick()
        }
        
        deinit {
            self.peerDisposable?.dispose()
            self.upgradePreviewTimer?.invalidate()
        }
        
        private func upgradePreviewTimerTick() {
            
        }
    }


    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let animation = Child(GiftCompositionComponent.self)
        let avatar = Child(AvatarComponent.self)
        let peerName = Child(MultilineTextComponent.self)
        //let description = Child(MultilineTextComponent.self)
        
        //let initialGift = Child(GiftItemComponent.self)
        //let upgradedGift = Child(GiftItemComponent.self)
        
        let button = Child(ButtonComponent.self)
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let nameDisplayOrder = component.context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder
            let controller = environment.controller
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var contentHeight: CGFloat = 0.0
                        
            let headerHeight: CGFloat = 226.0
            let headerSubject: GiftCompositionComponent.Subject = .preview([])
                    
            var peerNameString = ""
            if let peer = state.peerMap[component.context.account.peerId] {
                peerNameString = peer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            }
            
            let peerName = peerName.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: peerNameString,
                        font: Font.bold(20.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let animationOffset: CGPoint? = CGPoint(x: peerName.size.width / 2.0 + 20.0 - 12.0, y: 79.0)
            let animationScale: CGFloat = 0.19

            let animation = animation.update(
                component: GiftCompositionComponent(
                    context: component.context,
                    theme: environment.theme,
                    subject: headerSubject,
                    animationOffset: animationOffset,
                    animationScale: animationScale,
                    displayAnimationStars: true,
                    externalState: giftCompositionExternalState,
                    requestUpdate: { [weak state] transition in
                        state?.updated(transition: transition)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                transition: context.transition
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
            )
            contentHeight += headerHeight
            
            if let peer = state.peerMap[component.context.account.peerId] {
                let avatar = avatar.update(
                    component: AvatarComponent(
                        context: component.context,
                        theme: theme,
                        peer: peer
                    ),
                    environment: {},
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: context.transition
                )
                context.add(avatar
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 86.0))
                )
            }
            context.add(peerName
                .position(CGPoint(x: context.availableSize.width / 2.0 - 12.0, y: 167.0))
            )
            
//            let vibrantColor: UIColor
//            if let previewPatternColor = giftCompositionExternalState.previewPatternColor {
//                vibrantColor = previewPatternColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
//            } else {
//                vibrantColor = UIColor.white.withAlphaComponent(0.6)
//            }
            

            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let buttonSize = CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: theme.list.itemCheckColors.fillColor,
                foreground: theme.list.itemCheckColors.foregroundColor,
                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            let button = button.update(
                component: ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: AnyHashable("ok"),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Common_OK, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        if let controller = controller() as? GiftAuctionUpgradePreviewScreen {
                            controller.dismissAnimated()
                        }
                    }),
                availableSize: buttonSize,
                transition: context.transition
            )
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonInsets.left, y: contentHeight), size: button.size)
            context.add(button
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
            )
            contentHeight += button.size.height
            contentHeight += 7.0
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: contentHeight + 5.0 + effectiveBottomInset)
        }
    }
}

final class GiftAuctionUpgradePreviewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: StarGift
    
    init(
        context: AccountContext,
        gift: StarGift
    ) {
        self.context = context
        self.gift = gift
    }
    
    static func ==(lhs: GiftAuctionUpgradePreviewSheetComponent, rhs: GiftAuctionUpgradePreviewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
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
                    content: AnyComponent<EnvironmentType>(GiftAuctionUpgradePreviewSheetContent(
                        context: context.component.context,
                        gift: context.component.gift,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    hasDimView: false,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                        if let controller = controller() as? GiftAuctionUpgradePreviewScreen {
                            controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                        }
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
                                if let controller = controller() as? GiftAuctionUpgradePreviewScreen {
                                    controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftAuctionUpgradePreviewScreen {
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

public class GiftAuctionUpgradePreviewScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        gift: StarGift
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: GiftAuctionUpgradePreviewSheetComponent(context: context, gift: gift),
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
