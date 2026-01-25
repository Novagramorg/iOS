import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AppBundle
import LocalMediaResources
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ButtonComponent
import PlainButtonComponent
import GiftItemComponent
import GiftAnimationComponent
import AccountContext
import GlassBarButtonComponent
import ResizableSheetComponent
import AnimatedTextComponent
import Markdown
import InfoParagraphComponent
import PresentationDataUtils
import GiftViewScreen
import PeerInfoCoverComponent
import LottieComponent
import TooltipUI
import TextFormat
import GlassBackgroundComponent
import SpaceWarpView
import ConfettiEffect
import TelegramNotices

private let backdropButtonTag = GenericComponentViewTag()
private let symbolButtonTag = GenericComponentViewTag()

private final class CraftGiftPageContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    class ExternalState {
        fileprivate(set) var giftMap: [Int64: GiftItem]
        
        fileprivate(set) var testFailOrSuccess: Bool?
        
        public init() {
            self.giftMap = [:]
        }
    }
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let resaleContext: () -> ResaleGiftsContext?
    let colors: (UIColor, UIColor, UIColor, UIColor, UIColor)
    let gift: StarGift.UniqueGift
    let selectedGiftIds: [Int32: Int64]
    let displayCraftInfo: Bool
    let isCrafting: Bool
    let inProgress: Bool
    let result: CraftTableComponent.Result?
    let screenSize: CGSize
    let externalState: ExternalState
    let selectGift: (Int32, GiftItem) -> Void
    let removeGift: (Int32) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        resaleContext: @escaping () -> ResaleGiftsContext?,
        colors: (UIColor, UIColor, UIColor, UIColor, UIColor),
        gift: StarGift.UniqueGift,
        selectedGiftIds: [Int32: Int64],
        displayCraftInfo: Bool,
        isCrafting: Bool,
        inProgress: Bool,
        result: CraftTableComponent.Result?,
        screenSize: CGSize,
        externalState: ExternalState,
        selectGift: @escaping (Int32, GiftItem) -> Void,
        removeGift: @escaping (Int32) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.craftContext = craftContext
        self.resaleContext = resaleContext
        self.colors = colors
        self.gift = gift
        self.selectedGiftIds = selectedGiftIds
        self.displayCraftInfo = displayCraftInfo
        self.isCrafting = isCrafting
        self.inProgress = inProgress
        self.result = result
        self.screenSize = screenSize
        self.externalState = externalState
        self.selectGift = selectGift
        self.removeGift = removeGift
        self.dismiss = dismiss
    }
    
    static func ==(lhs: CraftGiftPageContent, rhs: CraftGiftPageContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.colors.0 != rhs.colors.0 || lhs.colors.1 != rhs.colors.1 || lhs.colors.2 != rhs.colors.2 || lhs.colors.3 != rhs.colors.3 {
            return false
        }
        if lhs.selectedGiftIds != rhs.selectedGiftIds {
            return false
        }
        if lhs.displayCraftInfo != rhs.displayCraftInfo {
            return false
        }
        if lhs.isCrafting != rhs.isCrafting {
            return false
        }
        if lhs.inProgress != rhs.inProgress {
            return false
        }
        if lhs.screenSize != rhs.screenSize {
            return false
        }
        return true
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let tableContainer = UIView()
        private let background = SimpleGradientLayer()
        private let overlay = SimpleGradientLayer()
        private let pattern = ComponentView<Empty>()
    
        private let title = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        
        private let craftingTitle = ComponentView<Empty>()
        private let craftingSubtitle = ComponentView<Empty>()
        private let craftingDescription = ComponentView<Empty>()
        private let craftingProbability = ComponentView<Empty>()
        private var craftingProbabilityMeasure = ComponentView<Empty>()
        
        private var backdropDial = ComponentView<Empty>()
        private var symbolDial = ComponentView<Empty>()
        private var variantsButton = ComponentView<Empty>()
        private var variantsButtonMeasure = ComponentView<Empty>()
        
        private var craftTable = ComponentView<Empty>()
        private var selectedGifts: [AnyHashable: ComponentView<Empty>] = [:]
        
        private let infoContainer = UIView()
        private var infoBackground = SimpleLayer()
        private var infoHeader = ComponentView<Empty>()
        private let infoTitle = ComponentView<Empty>()
        private let infoDescription = ComponentView<Empty>()
        private var infoList = ComponentView<Empty>()
        
        private var actionButton = ComponentView<Empty>()
                        
        private var craftState: CraftGiftsContext.State?
        private var craftStateDisposable: Disposable?
        
        private let upgradePreviewDisposable = DisposableSet()
        private var upgradePreview: [StarGift.UniqueGift.Attribute]?
        private var starGiftsMap: [Int64: StarGift.Gift] = [:]
        
        private let starsTopUpOptionsPromise = Promise<[StarsTopUpOption]?>(nil)
        
        private var availableGifts: [GiftItem] = []
        private var giftMap: [Int64: GiftItem] = [:]
        private var isCrafting = false
        private var isFailing = false
                
        private var component: CraftGiftPageContent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
                                    
            self.background.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.background.cornerRadius = 40.0
            self.background.type = .axial
            self.background.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.background.endPoint = CGPoint(x: 0.5, y: 1.0)
            self.layer.addSublayer(self.background)
            
            self.overlay.type = .radial
            self.overlay.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.overlay.endPoint = CGPoint(x: 0.0, y: 1.0)
            self.layer.addSublayer(self.overlay)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.craftStateDisposable?.dispose()
            self.upgradePreviewDisposable.dispose()
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let component = self.component, let controller = self.environment?.controller() as? GiftCraftScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x + 1.0, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: component.context.account, sharedContext: component.context.sharedContext, text: .markdown(text: text), balancedTextLayout: true, style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openUpgradeVariants() {
            guard let component = self.component, let controller = self.environment?.controller(), let gift = self.starGiftsMap[component.gift.giftId] else {
                return
            }
            
            let _ = (component.context.engine.payments.getStarGiftUpgradeAttributes(giftId: component.gift.giftId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] attributes in
                guard let attributes else {
                    return
                }
                let variantsController = component.context.sharedContext.makeGiftUpgradeVariantsScreen(
                    context: component.context,
                    gift: .generic(gift),
                    onlyCrafted: true,
                    attributes: attributes,
                    selectedAttributes: nil,
                    focusedAttribute: nil
                )
                controller?.push(variantsController)
            })
        }
                
        func update(component: CraftGiftPageContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                let initialGiftItem = GiftItem(
                    gift: component.gift,
                    reference: .slug(slug: component.gift.slug)
                )
                self.availableGifts = [
                    initialGiftItem
                ]
                self.giftMap = [initialGiftItem.gift.id: initialGiftItem]
                component.externalState.giftMap = self.giftMap
                
                self.craftStateDisposable = (component.craftContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    //let isFirstTime = self.craftState == nil
                    self.craftState = state
                    
                    var items: [GiftItem] = []
                    var map: [Int64: GiftItem] = self.giftMap
                    var foundInitial = false
                    for gift in state.gifts {
                        guard let reference = gift.reference, case let .unique(uniqueGift) = gift.gift else {
                            continue
                        }
                        let giftItem = GiftItem(
                            gift: uniqueGift,
                            reference: reference
                        )
                        if uniqueGift.id == component.gift.id {
                            items.insert(giftItem, at: 0)
                            foundInitial = true
                        } else {
                            items.append(giftItem)
                        }
                        map[uniqueGift.id] = giftItem
                    }
                    
                    if !foundInitial {
                        items.insert(initialGiftItem, at: 0)
                        map[initialGiftItem.gift.id] = initialGiftItem
                    }
                    self.availableGifts = items
                    self.giftMap = map
                    self.component?.externalState.giftMap = self.giftMap
                    
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
                
                self.upgradePreviewDisposable.add((component.context.engine.payments.getStarGiftUpgradeAttributes(giftId: initialGiftItem.gift.giftId)
                |> deliverOnMainQueue).start(next: { [weak self] attributes in
                    guard let self, let attributes else {
                        return
                    }
                    var filteredAttributes: [StarGift.UniqueGift.Attribute] = []
                    for attribute in attributes {
                        if case let .model(_, file, _, crafted) = attribute {
                            if crafted {
                                filteredAttributes.append(attribute)
                                self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                            }
                        }
                    }
                    self.upgradePreview = filteredAttributes

                    self.state?.updated()
                }))
                
                self.upgradePreviewDisposable.add((.single(nil) |> then(component.context.engine.payments.cachedStarGifts())
                |> deliverOnMainQueue).start(next: { [weak self] starGifts in
                    guard let self, let starGifts else {
                        return
                    }
                    var starGiftsMap: [Int64: StarGift.Gift] = [:]
                    for gift in starGifts {
                        if case let .generic(gift) = gift {
                            starGiftsMap[gift.id] = gift
                        }
                    }
                    self.starGiftsMap = starGiftsMap
                }))
                
                self.starsTopUpOptionsPromise.set(component.context.engine.payments.starsTopUpOptions() |> map(Optional.init))
            }
            
            transition.setGradientColors(layer: self.background, colors: [component.colors.0, component.colors.1])
            transition.setGradientColors(layer: self.overlay, colors: [component.colors.2, component.colors.2.withAlphaComponent(0.0)])
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            self.component = component
            self.state = state
            self.environment = environment
            
            var selectedGifts: [Int32: GiftItem] = [:]
            for (index, giftId) in component.selectedGiftIds {
                if let gift = self.giftMap[giftId] {
                    selectedGifts[index] = gift
                }
            }
                                    
            var craftContentHeight: CGFloat = 0.0
            var infoContentHeight: CGFloat = 0.0
                        
            let anvilPath = getAppBundle().url(forResource: "Anvil", withExtension: "tgs")?.path ?? ""
            let anvilFile = TelegramMediaFile(
                fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: -123456789),
                partialReference: nil,
                resource: BundleResource(name: "Anvil", path: anvilPath),
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "application/x-tgsticker",
                size: nil,
                attributes: [
                    .FileName(fileName: "sticker.tgs"),
                    .CustomEmoji(isPremium: false, isSingleColor: true, alt: "", packReference: .animatedEmojiAnimations)
                ],
                alternativeRepresentations: []
            )
            
            var backgroundTransition = transition
            let backgroundSize = self.pattern.update(
                transition: backgroundTransition,
                component: AnyComponent(PeerInfoCoverComponent(
                    context: component.context,
                    subject: .custom(.clear, .clear, UIColor(rgb: 0x000000), anvilFile.fileId.id),
                    files: [anvilFile.fileId.id: anvilFile],
                    isDark: false,
                    avatarCenter: CGPoint(x: availableSize.width / 2.0, y: 169.0),
                    avatarSize: CGSize(width: 130.0, height: 130.0),
                    avatarScale: 1.0,
                    defaultHeight: 300.0,
                    gradientOnTop: true,
                    avatarTransitionFraction: self.isFailing ? 1.0 : 0.0,
                    patternTransitionFraction: 0.0,
                    patternIconScale: 1.5
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 169.0 * 2.0)
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: component.isCrafting ? floor((component.screenSize.height - backgroundSize.height) / 2.0) : 0.0), size: backgroundSize)
            if let backgroundView = self.pattern.view {
                if backgroundView.layer.superlayer == nil {
                    backgroundTransition = .immediate
                    backgroundView.clipsToBounds = true
                    backgroundView.isUserInteractionEnabled = false
                    self.layer.insertSublayer(backgroundView.layer, above: self.overlay)
                }
                backgroundTransition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
                                    
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: "Craft Gift", font: Font.semibold(17.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: 16.0 + 22.0 - titleSize.height * 0.5), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
                transition.setAlpha(view: titleView, alpha: component.isCrafting ? 0.0 : 1.0)
                transition.setBlur(layer: titleView.layer, radius: component.isCrafting ? 10.0 : 0.0)
            }
            
            let giftTitle = "\(component.gift.title) #\(formatCollectibleNumber(component.gift.number, dateTimeFormat: environment.dateTimeFormat))"
            
            //TODO:localize
            
            let descriptionFont = Font.regular(13.0)
            let descriptionBoldFont = Font.semibold(13.0)
            let descriptionColor = UIColor.white
            let rawDescriptionString = "Add up to **4 gifts** to craft new\n**$ \(giftTitle)**.\n\nIf crafting fails, all selected gifts\nwill be consumed."
            let descriptionString = parseMarkdownIntoAttributedString(rawDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), linkAttribute: { _ in return nil })).mutableCopy() as! NSMutableAttributedString
            
            if let gift = self.starGiftsMap[component.gift.giftId] {
                let range = (descriptionString.string as NSString).range(of: "$")
                if range.location != NSNotFound {
                    descriptionString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: gift.file.fileId.id, file: gift.file, custom: nil, enableAnimation: false), range: range)
                }
            }
            
            let descriptionTextSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white.withAlphaComponent(0.3),
                        text: .plain(descriptionString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            craftContentHeight += 276.0
            craftContentHeight += descriptionTextSize.height
            craftContentHeight += 25.0
            
            var attributes: [ResaleGiftsContext.Attribute: StarGift.UniqueGift.Attribute] = [:]
            var backdropAttributeCount: [ResaleGiftsContext.Attribute: Int32] = [:]
            var patternAttributeCount: [ResaleGiftsContext.Attribute: Int32] = [:]
            for gift in selectedGifts.values {
                for attribute in gift.gift.attributes {
                    switch attribute {
                    case let .backdrop(_, id, _, _, _, _, _):
                        let attributeId: ResaleGiftsContext.Attribute = .backdrop(id)
                        attributes[attributeId] = attribute
                        if let count = backdropAttributeCount[attributeId] {
                            backdropAttributeCount[attributeId] = count + 1
                        } else {
                            backdropAttributeCount[attributeId] = 1
                        }
                    case let .pattern(_, file, _):
                        let attributeId: ResaleGiftsContext.Attribute = .pattern(file.fileId.id)
                        attributes[attributeId] = attribute
                        if let count = patternAttributeCount[attributeId] {
                            patternAttributeCount[attributeId] = count + 1
                        } else {
                            patternAttributeCount[attributeId] = 1
                        }
                    default:
                        break
                    }
                }
            }
            
            func mostFrequentAttribute(from counts: [ResaleGiftsContext.Attribute: Int32]) -> (attribute: StarGift.UniqueGift.Attribute, count: Int32)? {
                guard let (id, count) = counts.max(by: { $0.value < $1.value }),
                      count > 1,
                      let attribute = attributes[id] else {
                    return nil
                }
                return (attribute, count)
            }
            
            var possibleBackdrop: (StarGift.UniqueGift.Attribute, Int32)?
            var possiblePattern: (StarGift.UniqueGift.Attribute, Int32)?

            var backdropColor: UIColor = .white
            var backdropPermille: Int = 0
            var backdropName = ""
            var symbolFile: TelegramMediaFile?
            var symbolPermille: Int = 0
            var symbolName = ""
            
            for attribute in component.gift.attributes {
                switch attribute {
                case .backdrop:
                    possibleBackdrop = (attribute, 1)
                case .pattern:
                    possiblePattern = (attribute, 1)
                default:
                    break
                }
            }
            
            if let betterBackdrop = mostFrequentAttribute(from: backdropAttributeCount) {
                possibleBackdrop = betterBackdrop
            }
            
            if let betterPattern = mostFrequentAttribute(from: patternAttributeCount) {
                possiblePattern = betterPattern
            }
            
            let appConfiguration = component.context.currentAppConfiguration.with { $0 }
            let giftCraftConfiguration = GiftCraftConfiguration.with(appConfiguration: appConfiguration)
            
            if case let .backdrop(name, _, innerColor, _, _, _, _) = possibleBackdrop?.0  {
                backdropColor = UIColor(rgb: UInt32(bitPattern: innerColor))
                backdropName = name
            }
            if let possibleBackdrop {
                backdropPermille = Int(giftCraftConfiguration.craftAttributePermilles[Int(possibleBackdrop.1 - 1)])
            }
            
            if case let .pattern(name, file, _) = possiblePattern?.0 {
                symbolFile = file
                symbolName = name
            }
            if let possiblePattern {
                symbolPermille = Int(giftCraftConfiguration.craftAttributePermilles[Int(possiblePattern.1 - 1)])
            }
            
            let backdropDialSize = self.backdropDial.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            DialIndicatorComponent(
                                content: AnyComponentWithIdentity(
                                    id: "color",
                                    component: AnyComponent(
                                        BundleIconComponent(name: "Components/ColorMask", tintColor: backdropColor)
                                    )
                                ),
                                backgroundColor: .white.withAlphaComponent(0.1),
                                foregroundColor: .white,
                                diameter: 48.0,
                                lineWidth: 4.0,
                                fontSize: 10.0,
                                percentage: backdropPermille / 10
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            #if DEBUG
                            self.component?.externalState.testFailOrSuccess = true
                            #endif
                            self.showAttributeInfo(tag: backdropButtonTag, text: "There's **\(backdropPermille / 10)%** chance the crafted gift will have **\(backdropName)** backdrop.")
                        },
                        tag: backdropButtonTag
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let symbolDialSize = self.symbolDial.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            DialIndicatorComponent(
                                content: symbolFile.flatMap { AnyComponentWithIdentity(
                                    id: "symbol",
                                    component: AnyComponent(
                                        LottieComponent(
                                            content: LottieComponent.ResourceContent(
                                                context: component.context,
                                                file: $0,
                                                attemptSynchronously: true,
                                                providesPlaceholder: true
                                            ),
                                            color: .white,
                                            size: CGSize(width: 32.0, height: 32.0)
                                        )
                                    )
                                ) } ?? AnyComponentWithIdentity(
                                    id: "empty", component: AnyComponent(Rectangle(color: .clear))),
                                backgroundColor: .white.withAlphaComponent(0.1),
                                foregroundColor: .white,
                                diameter: 48.0,
                                lineWidth: 4.0,
                                fontSize: 10.0,
                                percentage: symbolPermille / 10
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            #if DEBUG
                            self.component?.externalState.testFailOrSuccess = false
                            #endif
                            self.showAttributeInfo(tag: symbolButtonTag, text: "There's **\(symbolPermille / 10)%** chance the crafted gift will have **\(symbolName)** backdrop.")
                        },
                        tag: symbolButtonTag
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            craftContentHeight += backdropDialSize.height
            craftContentHeight += 15.0
            
            let variantsString = "View all new variants"
            let variantsButtonMeasure = self.variantsButtonMeasure.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: variantsString, font: Font.semibold(13.0), textColor: .clear)))),
                environment: {},
                containerSize: availableSize
            )
            
            let variantsButtonSize = CGSize(width: variantsButtonMeasure.width + 87.0, height: 24.0)
            if let gift = self.starGiftsMap[component.gift.giftId] {
                var variant1: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                var variant2: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                var variant3: GiftItemComponent.Subject = .starGift(gift: gift, price: "")
                
                if let upgradePreview = self.upgradePreview {
                    var i = 0
                    for attribute in upgradePreview {
                        if case .model = attribute {
                            switch i {
                            case 0:
                                variant1 = .preview(attributes: [attribute], rarity: nil)
                            case 1:
                                variant2 = .preview(attributes: [attribute], rarity: nil)
                            case 2:
                                variant3 = .preview(attributes: [attribute], rarity: nil)
                            default:
                                break
                            }
                            i += 1
                        }
                    }
                }
                
                let _ = self.variantsButton.update(
                    transition: transition,
                    component: AnyComponent(
                        GlassBarButtonComponent(
                            size: variantsButtonSize,
                            backgroundColor: component.colors.3,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "content", component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: "icon1", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        peer: nil,
                                        subject: variant1,
                                        isPlaceholder: false,
                                        mode: .tableIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "icon2", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        peer: nil,
                                        subject: variant2,
                                        isPlaceholder: false,
                                        mode: .tableIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "icon3", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        peer: nil,
                                        subject: variant3,
                                        isPlaceholder: false,
                                        mode: .tableIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: variantsString, font: Font.semibold(13.0), textColor: .white)))
                                )),
                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                    BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: .white)
                                ))
                            ], spacing: 3.0))),
                            action: { [weak self] _ in
                                self?.openUpgradeVariants()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
            }
            craftContentHeight += 160.0
            
            let originalCraftContentHeight = craftContentHeight
            if component.isCrafting {
                craftContentHeight = component.screenSize.height
            }
            
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - descriptionTextSize.width) * 0.5), y: craftContentHeight - 145.0 - 78.0 - 115.0), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
                transition.setAlpha(view: descriptionTextView, alpha: component.isCrafting ? 0.0 : 1.0)
                transition.setBlur(layer: descriptionTextView.layer, radius: component.isCrafting ? 10.0 : 0.0)
            }
            
            let backdropDialFrame = CGRect(origin: CGPoint(x: availableSize.width * 0.5 - 9.0 - backdropDialSize.width, y: craftContentHeight - 145.0 - 78.0), size: backdropDialSize)
            if let backdropDialView = self.backdropDial.view {
                if backdropDialView.superview == nil {
                    self.addSubview(backdropDialView)
                }
                transition.setFrame(view: backdropDialView, frame: backdropDialFrame)
                transition.setAlpha(view: backdropDialView, alpha: component.isCrafting ? 0.0 : 1.0)
                transition.setBlur(layer: backdropDialView.layer, radius: component.isCrafting ? 10.0 : 0.0)
            }
            
            let symbolDialFrame = CGRect(origin: CGPoint(x: availableSize.width * 0.5 + 9.0, y: craftContentHeight - 145.0 - 78.0), size: symbolDialSize)
            if let symbolDialView = self.symbolDial.view {
                if symbolDialView.superview == nil {
                    self.addSubview(symbolDialView)
                }
                transition.setFrame(view: symbolDialView, frame: symbolDialFrame)
                transition.setAlpha(view: symbolDialView, alpha: component.isCrafting ? 0.0 : 1.0)
                transition.setBlur(layer: symbolDialView.layer, radius: component.isCrafting ? 10.0 : 0.0)
            }
            
            let variantsButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - variantsButtonSize.width) / 2.0), y: craftContentHeight - 145.0), size: variantsButtonSize)
            var varitantsButtonTransition = transition
            if let variantsButtonView = self.variantsButton.view {
                if variantsButtonView.superview == nil && !component.isCrafting {
                    varitantsButtonTransition = .immediate
                    if let symbolDialView = self.symbolDial.view {
                        self.insertSubview(variantsButtonView, aboveSubview: symbolDialView)
                    } else {
                        self.addSubview(variantsButtonView)
                    }
                }
                varitantsButtonTransition.setFrame(view: variantsButtonView, frame: variantsButtonFrame)
                varitantsButtonTransition.setBlur(layer: variantsButtonView.layer, radius: component.isCrafting ? 10.0 : 0.0)
                if component.isCrafting {
                    variantsButtonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.41, removeOnCompletion: false, completion: { _ in
                        variantsButtonView.removeFromSuperview()
                    })
                }
            }
            
            
            let permilleValue = selectedGifts.reduce(0, { $0 + Int($1.value.gift.craftChancePermille ?? 0) })
            if component.isCrafting {
                var craftingOriginY = craftContentHeight * 0.5 + 160.0
                let offset = -(craftContentHeight - originalCraftContentHeight)
                
                let titleSize = self.craftingTitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: "Crafting", font: Font.bold(20.0), textColor: .white)))
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: craftingOriginY), size: titleSize)
                if let titleView = self.craftingTitle.view {
                    if titleView.superview == nil {
                        transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: titleView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: titleView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(titleView)
                    }
                    titleView.frame = titleFrame
                }
                craftingOriginY += titleSize.height
                craftingOriginY += 7.0
                
                let subtitleSize = self.craftingSubtitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: giftTitle, font: Font.semibold(13.0), textColor: .white.withAlphaComponent(0.5))))
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) * 0.5), y: craftingOriginY), size: subtitleSize)
                if let subtitleView = self.craftingSubtitle.view {
                    if subtitleView.superview == nil {
                        transition.animateAlpha(view: subtitleView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: subtitleView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: subtitleView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(subtitleView)
                    }
                    subtitleView.frame = subtitleFrame
                }
                craftingOriginY += subtitleSize.height
                craftingOriginY += 21.0
                
                let descriptionFont = Font.regular(13.0)
                let descriptionBoldFont = Font.semibold(13.0)
                let descriptionColor = UIColor.white.withAlphaComponent(0.5)
                let rawDescriptionString = "If crafting fails, all selected gifts\nwill be consumed."
                let descriptionString = parseMarkdownIntoAttributedString(rawDescriptionString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionColor), linkAttribute: { _ in return nil })).mutableCopy() as! NSMutableAttributedString
                                
                let craftingDescriptionSize = self.craftingDescription.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextWithEntitiesComponent(
                            context: component.context,
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer,
                            placeholderColor: .white.withAlphaComponent(0.3),
                            text: .plain(descriptionString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingDescriptionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingDescriptionSize.width) * 0.5), y: craftingOriginY), size: craftingDescriptionSize)
                if let craftingDescriptionView = self.craftingDescription.view {
                    if craftingDescriptionView.superview == nil {
                        transition.animateAlpha(view: craftingDescriptionView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingDescriptionView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingDescriptionView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingDescriptionView)
                    }
                    craftingDescriptionView.frame = craftingDescriptionFrame
                }
                craftingOriginY += craftingDescriptionSize.height
                craftingOriginY += 24.0
                
                let craftingProbabilityString = "\(permilleValue / 10)% Success Chance"
                let craftingProbabilityMeasure = self.craftingProbabilityMeasure.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: craftingProbabilityString, font: Font.semibold(13.0), textColor: .clear)))),
                    environment: {},
                    containerSize: availableSize
                )
                
                let craftingProbabilitySize = CGSize(width: craftingProbabilityMeasure.width + 18.0, height: 24.0)
                let _ = self.craftingProbability.update(
                    transition: transition,
                    component: AnyComponent(
                        GlassBarButtonComponent(
                            size: craftingProbabilitySize,
                            backgroundColor: component.colors.3.mixedWith(component.colors.1, alpha: 0.3),
                            isDark: true,
                            state: .tintedGlass,
                            component:  AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: craftingProbabilityString, font: Font.semibold(13.0), textColor: .white)))
                            )),
                            action: nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                let craftingProbabilityFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - craftingProbabilitySize.width) * 0.5), y: craftingOriginY), size: craftingProbabilitySize)
                if let craftingProbabilityView = self.craftingProbability.view {
                    if craftingProbabilityView.superview == nil {
                        transition.animateAlpha(view: craftingProbabilityView, from: 0.0, to: 1.0)
                        transition.animateBlur(layer: craftingProbabilityView.layer, fromRadius: 10.0, toRadius: 0.0)
                        transition.animatePosition(view: craftingProbabilityView, from: CGPoint(x: 0.0, y: offset), to: .zero, additive: true)
                        
                        self.addSubview(craftingProbabilityView)
                    }
                    craftingProbabilityView.frame = craftingProbabilityFrame
                }
            }
            
            let tableSize = CGSize(width: availableSize.width, height: 320.0)
            let craftTableSize = self.craftTable.update(
                transition: transition,
                component: AnyComponent(
                    CraftTableComponent(
                        context: component.context,
                        gifts: selectedGifts,
                        buttonColor: component.colors.3,
                        isCrafting: component.isCrafting,
                        result: component.result,
                        select: { [weak self] index in
                            guard let self, let component = self.component, let environment = self.environment, let genericGift = self.starGiftsMap[component.gift.giftId], let resaleContext = component.resaleContext() else {
                                return
                            }
                            let selectController = SelectCraftGiftScreen(
                                context: component.context,
                                craftContext: component.craftContext,
                                resaleContext: resaleContext,
                                gift: component.gift,
                                genericGift: genericGift,
                                selectedGiftIds: Set(component.selectedGiftIds.values),
                                starsTopUpOptions: self.starsTopUpOptionsPromise.get(),
                                selectGift: { [weak self] item in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if self.giftMap[item.gift.id] == nil {
                                        self.giftMap[item.gift.id] = item
                                    }
                                    component.selectGift(index, item)
                                }
                            )
                            environment.controller()?.push(selectController)
                        },
                        remove: { [weak self] index in
                            guard let self else {
                                return
                            }
                            self.component?.removeGift(index)
                        },
                        willFinish: { [weak self] success in
                            guard let self else {
                                return
                            }
                            if !success {
                                self.isFailing = true
                            }
                            self.state?.updated(transition: .easeInOut(duration: 0.5))
                        },
                        finished: { [weak self] view in
                            guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                                return
                            }
                            if let _ = view {
                                if case let .gift(gift) = component.result {
                                    let giftController = GiftViewScreen(context: component.context, subject: .profileGift(component.context.account.peerId, gift))
                                    if let navigationController = controller.navigationController {
                                        navigationController.pushViewController(giftController, animated: true)
                                        
                                        navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                                    }
                                }
                                controller.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { _ in
                                    controller.dismiss()
                                })
                            } else {
                                if let navigationController = controller.navigationController {
                                    controller.view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { _ in
                                        controller.dismiss()
                                    })
                                    let previousController = navigationController.viewControllers[max(0, navigationController.viewControllers.count - 2)]
                                    animateRipple(parentView: previousController.view, screenCornerRadius: environment.deviceMetrics.screenCornerRadius, location: CGPoint(x: previousController.view.bounds.midX, y: previousController.view.bounds.midY))
                                }
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: tableSize.height)
            )
            let craftTableFrame = CGRect(origin: CGPoint(x: 0.0, y: component.isCrafting ? floor((component.screenSize.height - craftTableSize.height) / 2.0) : 10.0), size: craftTableSize)
            if let craftTableView = self.craftTable.view {
                if craftTableView.superview == nil {
                    craftTableView.layer.cornerRadius = 40.0
                    craftTableView.clipsToBounds = true
                    craftTableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    self.addSubview(craftTableView)
                }
                transition.setFrame(view: craftTableView, frame: craftTableFrame)
            }
            
            transition.setAlpha(view: self.infoContainer, alpha: component.displayCraftInfo ? 1.0 : 0.0)
            
            let infoHeaderSize = self.infoHeader.update(
                transition: transition,
                component: AnyComponent(
                    GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: .unique(nil, component.gift),
                        animationOffset: nil,
                        animationScale: nil,
                        displayAnimationStars: false,
                        animateScaleOnTransition: false,
                        externalState: nil,
                        requestUpdate: { _ in
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 245.0)
            )
            let infoHeaderFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoHeaderSize.width) * 0.5), y: 0.0), size: infoHeaderSize)
            if let infoHeaderView = self.infoHeader.view {
                if infoHeaderView.superview == nil {
                    self.infoContainer.layer.allowsGroupOpacity = true
                    self.addSubview(self.infoContainer)
                    
                    self.infoContainer.layer.addSublayer(self.infoBackground)
                    
                    infoHeaderView.layer.cornerRadius = 40.0
                    infoHeaderView.clipsToBounds = true
                    infoHeaderView.layer.allowsGroupOpacity = true
                    infoHeaderView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    self.infoContainer.addSubview(infoHeaderView)
                }
                transition.setFrame(view: infoHeaderView, frame: infoHeaderFrame)
            }
            infoContentHeight += infoHeaderSize.height
            infoContentHeight += 16.0
            
            let infoTitleSize = self.infoTitle.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: "Craft Gift", font: Font.bold(20.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let infoTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoTitleSize.width) * 0.5), y: infoHeaderSize.height - 73.0), size: infoTitleSize)
            if let infoTitleView = self.infoTitle.view {
                if infoTitleView.superview == nil {
                    self.infoContainer.addSubview(infoTitleView)
                }
                transition.setFrame(view: infoTitleView, frame: infoTitleFrame)
            }
            
            let infoDescriptionTextSize = self.infoDescription.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(
                        text: "Use your existing gifts to craft new ones.",
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            bold: MarkdownAttributeSet(font: Font.semibold(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            link: MarkdownAttributeSet(font: Font.regular(14.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.6)),
                            linkAttribute: { _ in return nil }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let infoDescriptionTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - infoDescriptionTextSize.width) * 0.5), y: infoHeaderSize.height - 40.0), size: infoDescriptionTextSize)
            if let infoDescriptionTextView = self.infoDescription.view {
                if infoDescriptionTextView.superview == nil {
                    self.infoContainer.addSubview(infoDescriptionTextView)
                }
                transition.setFrame(view: infoDescriptionTextView, frame: infoDescriptionTextFrame)
            }
            
            
            self.infoBackground.backgroundColor = environment.theme.list.plainBackgroundColor.cgColor
            
            let infoBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 80.0), size: CGSize(width: availableSize.width, height: 1000.0))
            transition.setFrame(layer: self.infoBackground, frame: infoBackgroundFrame)
            
            let titleColor = environment.theme.list.itemPrimaryTextColor
            let textColor = environment.theme.list.itemSecondaryTextColor
            let accentColor = environment.theme.list.itemAccentColor
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "combine",
                    component: AnyComponent(InfoParagraphComponent(
                        title: "Combine Gifts",
                        titleColor: titleColor,
                        text: "Add up to 3 Gifts to attempt crafting a new upgraded model.",
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Collectible/Badge",
                        iconColor: environment.theme.list.itemAccentColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "input",
                    component: AnyComponent(InfoParagraphComponent(
                        title: "Input Matters",
                        titleColor: titleColor,
                        text: "Each craft has a success chance. Better combinations improve the outcome.",
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Collectible/Transferable",
                        iconColor: accentColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "exclusive",
                    component: AnyComponent(InfoParagraphComponent(
                        title: "Exclusive Look",
                        titleColor: titleColor,
                        text: "Reforge gifts into a rarer collectibles with a new look",
                        textColor: textColor,
                        accentColor: accentColor,
                        iconName: "Premium/Collectible/Unique",
                        iconColor: accentColor
                    ))
                )
            )
            
            let infoListSize = self.infoList.update(
                transition: transition,
                component: AnyComponent(
                    List(items)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 64.0, height: 10000)
            )
            let infoListFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - infoListSize.width) / 2.0), y: infoContentHeight), size: infoListSize)
            if let infoListView = self.infoList.view {
                if infoListView.superview == nil {
                    self.infoContainer.addSubview(infoListView)
                }
                transition.setFrame(view: infoListView, frame: infoListFrame)
            }
        
            if component.displayCraftInfo {
                infoContentHeight += infoListSize.height
                infoContentHeight += 95.0
            }
            transition.setFrame(view: self.infoContainer, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: infoContentHeight)))
                        
            transition.setFrame(layer: self.background, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: craftContentHeight)))
            transition.setFrame(layer: self.overlay, frame: CGRect(origin: CGPoint(x: 0.0, y: component.isCrafting ? floor((component.screenSize.height - availableSize.width) / 2.0) : 169.0 - availableSize.width * 0.5), size: CGSize(width: availableSize.width, height: availableSize.width)))
            
            let effectiveContentHeight: CGFloat
            if component.displayCraftInfo {
                effectiveContentHeight = infoContentHeight
            } else {
                effectiveContentHeight = craftContentHeight
            }
                        
            return CGSize(width: availableSize.width, height: effectiveContentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let craftContext: CraftGiftsContext
    let gift: StarGift.UniqueGift
    
    init(
        context: AccountContext,
        craftContext: CraftGiftsContext,
        gift: StarGift.UniqueGift
    ) {
        self.context = context
        self.craftContext = craftContext
        self.gift = gift
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
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
        private let giftId: Int64
        
        var displayCraftInfo = false
        var isCrafting = false
        var inProgress = false
        var result: CraftTableComponent.Result?
        var selectedGiftIds: [Int32: Int64] = [:]
                
        private var _resaleContext: ResaleGiftsContext?
        var resaleContext: ResaleGiftsContext {
            if let current = self._resaleContext {
                return current
            } else {
                let resaleContext = ResaleGiftsContext(account: self.context.account, giftId: self.giftId, forCrafting: true)
                self._resaleContext = resaleContext
                return resaleContext
            }
        }
        
        let preloadDisposable = DisposableSet()
        
        init(context: AccountContext, gift: StarGift.UniqueGift) {
            self.context = context
            self.giftId = gift.giftId
            self.selectedGiftIds[0] = gift.id
            
            super.init()
                        
            let _ = (ApplicationSpecificNotice.getGiftCraftingTips(accountManager: context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count in
                guard let self else {
                    return
                }
                if count < 1 {
                    self.displayCraftInfo = true
                    self.updated()
                    
                    let _ = ApplicationSpecificNotice.incrementGiftCraftingTips(accountManager: context.sharedContext.accountManager).start()
                }
            })
        }
        
        deinit {
            self.preloadDisposable.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, gift: self.gift)
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let externalState = CraftGiftPageContent.ExternalState()
                
        return { context in
            let component = context.component
            let environment = context.environment[EnvironmentType.self]
            let state = context.state
            
            let controller = environment.controller
            
            let craftContext = context.component.craftContext
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let theme = environment.theme
                        
            var colors: (UIColor, UIColor, UIColor, UIColor, UIColor) = (
                UIColor(rgb: 0x263245), UIColor(rgb: 0x232e3f), UIColor(rgb: 0x304059), UIColor(rgb: 0x425168),  theme.list.itemCheckColors.fillColor
            )
            var permilleValue: Int32 = 0
            for id in state.selectedGiftIds.values {
                if let gift = externalState.giftMap[id] {
                    permilleValue += gift.gift.craftChancePermille ?? 0
                }
            }
            if permilleValue > 900 {
                colors.0 = UIColor(rgb: 0x1b3b3d)
                colors.1 = UIColor(rgb: 0x1a2f38)
                colors.2 = UIColor(rgb: 0x22464a)
                colors.3 = UIColor(rgb: 0x2d4e50)
                if !state.displayCraftInfo {
                    colors.4 = UIColor(rgb: 0x33bf54)
                }
            }
            
            var buttonColor = colors.3
            if state.displayCraftInfo, let backdropAttribute = component.gift.attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, innerColor, _, _, _, _) = backdropAttribute {
                buttonColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultipliedBrightnessBy(1.05)
            }
            
            var backgroundColor = colors.1
            if state.displayCraftInfo {
                backgroundColor = environment.theme.list.plainBackgroundColor
            }
            
            let giftTitle = "\(component.gift.title) #\(formatCollectibleNumber(component.gift.number, dateTimeFormat: environment.dateTimeFormat))"
            
            let buttonContent: AnyComponentWithIdentity<Empty>
            if state.displayCraftInfo {
                buttonContent = AnyComponentWithIdentity(id: "info", component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: "Select Gifts", font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor)))
                ))
            } else {
                var buttonAnimatedItems: [AnimatedTextComponent.Item] = []
                buttonAnimatedItems.append(AnimatedTextComponent.Item(id: "percent", content: .number(Int(permilleValue / 10), minDigits: 1)))
                buttonAnimatedItems.append(AnimatedTextComponent.Item(id: "suffix", content: .text("% Success Chance")))
                
                buttonContent = AnyComponentWithIdentity(id: "craft", component: AnyComponent(
                    VStack([
                        AnyComponentWithIdentity(
                            id: AnyHashable("label"),
                            component: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable("label"),
                                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Craft \(giftTitle)", font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor))))
                                    )
                                ], spacing: 2.0)
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: AnyHashable("level"),
                            component: AnyComponent(
                                AnimatedTextComponent(
                                    font: Font.with(size: 13.0, weight: .medium, traits: .monospacedNumbers),
                                    color: environment.theme.list.itemCheckColors.foregroundColor,
                                    items: buttonAnimatedItems,
                                    noDelay: true
                                )
                            )
                        )
                    ], spacing: 0.0)
                ))
            }
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(
                        CraftGiftPageContent(
                            context: component.context,
                            craftContext: component.craftContext,
                            resaleContext: { [weak state] in
                                return state?.resaleContext
                            },
                            colors: colors,
                            gift: component.gift,
                            selectedGiftIds: state.selectedGiftIds,
                            displayCraftInfo: state.displayCraftInfo,
                            isCrafting: state.isCrafting,
                            inProgress: state.inProgress,
                            result: state.result,
                            screenSize: context.availableSize,
                            externalState: externalState,
                            selectGift: { [weak state] index, gift in
                                guard let state else {
                                    return
                                }
                                state.selectedGiftIds[index] = gift.gift.id
                                state.updated(transition: .spring(duration: 0.4))
                            },
                            removeGift: { [weak state] index in
                                guard let state else {
                                    return
                                }
                                state.selectedGiftIds[index] = nil
                                state.updated(transition: .spring(duration: 0.4))
                            },
                            dismiss: {
                                dismiss(true)
                            }
                        )
                    ),
                    leftItem: state.isCrafting ? nil : AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: buttonColor,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: .white
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    rightItem: state.isCrafting || state.displayCraftInfo ? nil : AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: buttonColor,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "info", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Question",
                                    tintColor: .white
                                )
                            )),
                            action: { [weak state] _ in
                                guard let state, !state.isCrafting else {
                                    return
                                }
                                state.displayCraftInfo = !state.displayCraftInfo
                                state.updated(transition: .spring(duration: 0.3))
                            }
                        )
                    ),
                    hasTopEdgeEffect: false,
                    bottomItem: state.isCrafting ? nil : AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: colors.4,
                                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: buttonContent,
                            isEnabled: state.displayCraftInfo ? true : state.selectedGiftIds.count > 0,
                            displaysProgress: state.inProgress,
                            action: { [weak state] in
                                guard let state else {
                                    return
                                }
                                if state.displayCraftInfo {
                                    state.displayCraftInfo = false
                                    state.updated(transition: .spring(duration: 0.3))
                                } else {
                                    state.inProgress = true
                                    state.updated(transition: .spring(duration: 0.3))
                                    
                                    if let testFailOrSuccess = externalState.testFailOrSuccess {
                                        Queue.mainQueue().after(0.5, {
                                            state.isCrafting = true
                                            if testFailOrSuccess {
                                                state.result = .gift(ProfileGiftsContext.State.StarGift(gift: .unique(component.gift), reference: nil, fromPeer: nil, date: 0, text: "", entities: nil, nameHidden: false, savedToProfile: false, pinnedToTop: false, convertStars: nil, canUpgrade: false, canExportDate: nil, upgradeStars: nil, transferStars: nil, canTransferDate: nil, canResaleDate: nil, collectionIds: nil, prepaidUpgradeHash: nil, upgradeSeparate: false, dropOriginalDetailsStars: nil, number: nil, isRefunded: false, canCraftAt: nil))
                                            } else {
                                                state.result = .fail
                                            }
                                            state.updated(transition: .spring(duration: 0.8))
                                        })
                                        return
                                    }
                                    
                                    var indices: [Int] = []
                                    for index in state.selectedGiftIds.keys.sorted() {
                                        indices.append(Int(index))
                                    }
                                    var references: [StarGiftReference] = []
                                    for index in indices {
                                        if let giftId = state.selectedGiftIds[Int32(index)], let gift = externalState.giftMap[giftId] {
                                            references.append(gift.reference)
                                        }
                                    }
                                    let _ = (craftContext.craft(references: references)
                                    |> deliverOnMainQueue).start(next: { [weak state] result in
                                        guard let state else {
                                            return
                                        }
                                        state.isCrafting = true
                                        state.result = .gift(result)
                                        state.updated(transition: .spring(duration: 0.8))
                                        
                                        if case let .unique(uniqueGift) = result.gift {
                                            for attribute in uniqueGift.attributes {
                                                switch attribute {
                                                case let .model(_, file, _, _):
                                                    state.preloadDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                                case let .pattern(_, file, _):
                                                    state.preloadDisposable.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }, error: { error in
                                        switch error {
                                        case .craftFailed:
                                            state.isCrafting = true
                                            state.result = .fail
                                            state.updated(transition: .spring(duration: 0.8))
                                        default:
                                            if let navigationController = controller()?.navigationController {
                                                dismiss(true)
                                                let alertController = textAlertController(context: component.context, title: nil, text: "Unknown Error", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})])
                                                (navigationController.topViewController as? ViewController)?.present(alertController, in: .window(.root))
                                            }
                                        }
                                    })
                                }
                            }
                        )
                    ),
                    backgroundColor: .color(backgroundColor),
                    isFullscreen: state.isCrafting,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
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
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
                        
            return context.availableSize
        }
    }
}


public class GiftCraftScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        gift: StarGift.UniqueGift
    ) {
        let craftContext = CraftGiftsContext(account: context.account, giftId: gift.giftId)
        
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                craftContext: craftContext,
                gift: gift
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    public func dismissAnimated() {
        self.dismissAllTooltips()
        
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}



private struct GiftCraftConfiguration {
    static var defaultValue: GiftCraftConfiguration {
        return GiftCraftConfiguration(
            craftAttributePermilles: [60, 180, 450, 1000]
        )
    }
    
    let craftAttributePermilles: [Int32]
        
    fileprivate init(
        craftAttributePermilles: [Int32]
    ) {
        self.craftAttributePermilles = craftAttributePermilles
    }
    
    static func with(appConfiguration: AppConfiguration) -> GiftCraftConfiguration {
        if let data = appConfiguration.data {
            var craftAttributePermilles: [Int32] = []
            if let value = data["stargifts_craft_attribute_permilles"] as? [Double] {
                craftAttributePermilles = value.map { Int32($0) }
            } else {
                craftAttributePermilles = GiftCraftConfiguration.defaultValue.craftAttributePermilles
            }
            
            return GiftCraftConfiguration(
                craftAttributePermilles: craftAttributePermilles
            )
        } else {
            return .defaultValue
        }
    }
}

private func animateRipple(parentView: UIView, screenCornerRadius: CGFloat, location: CGPoint) {
    if let snapshotView = parentView.snapshotView(afterScreenUpdates: false) {
        let wrappingNode = SpaceWarpNodeImpl()
        wrappingNode.isUserInteractionEnabled = false
        wrappingNode.frame = CGRect(origin: .zero, size: parentView.bounds.size)
        wrappingNode.update(size: parentView.bounds.size, cornerRadius: screenCornerRadius, transition: .immediate)
        parentView.addSubview(wrappingNode.view)
        wrappingNode.contentNode.view.addSubview(snapshotView)
        
        wrappingNode.triggerRipple(at: location)
        
        Queue.mainQueue().after(0.7, {
            wrappingNode.view.removeFromSuperview()
        })
    }
}
