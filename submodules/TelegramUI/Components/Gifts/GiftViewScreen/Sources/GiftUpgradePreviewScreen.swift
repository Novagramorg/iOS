import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import AccountContext
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import Display
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ButtonComponent
import PlainButtonComponent
import Markdown
import BundleIconComponent
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import GiftItemComponent
import EdgeEffect
import AnimatedTextComponent
import SegmentControlComponent
import GiftAnimationComponent
import GlassBackgroundComponent

private final class GiftUpgradePreviewScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    static func ==(lhs: GiftUpgradePreviewScreenComponent, rhs: GiftUpgradePreviewScreenComponent) -> Bool {
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    enum SelectedSection {
        case models
        case backdrops
        case symbols
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let glassContainerView: GlassBackgroundContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
                
        private let backgroundHandleView: UIImageView
        
        private let header = ComponentView<Empty>()
        private let closeButton = ComponentView<Empty>()
        private let playbackButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private var attributeInfos: [ComponentView<Empty>] = []
        
        private let segmentControl = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        
        private var giftItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var selectedSection: SelectedSection = .models
        
        private let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
                
        fileprivate var starGiftsContext: ResaleGiftsContext?
        fileprivate var starGiftsState: ResaleGiftsContext.State?
        fileprivate var starGiftsDisposable: Disposable?
        
        private var previewTimer: SwiftSignalKit.Timer?
        private var isPlaying = true
        private var showRandomizeTip = false
        
        private var previewModelIndex: Int = 0
        private var previewBackdropIndex: Int = 0
        private var previewSymbolIndex: Int = 0
        
        private var previewModels: [StarGift.UniqueGift.Attribute] = []
        private var previewBackdrops: [StarGift.UniqueGift.Attribute] = []
        private var previewSymbols: [StarGift.UniqueGift.Attribute] = []
        
        private var selectedModel: StarGift.UniqueGift.Attribute?
        private var selectedBackdrop: StarGift.UniqueGift.Attribute?
        private var selectedSymbol: StarGift.UniqueGift.Attribute?
        
        private var modelCount: Int32 = 0
        private var backdropCount: Int32 = 0
        private var symbolCount: Int32 = 0
        
        private var ignoreScrolling: Bool = false
                
        private var component: GiftUpgradePreviewScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
                
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 40.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 40.0
                        
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            
            self.glassContainerView = GlassBackgroundContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
                                                
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.containerView.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.starGiftsDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let minScale: CGFloat = (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
            
            self.updateItems(transition: transition)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
        }
        
        private func timerTick() {
            guard !self.previewModels.isEmpty else { return }
            self.previewModelIndex = (self.previewModelIndex + 1) % self.previewModels.count
            
            let previousSymbolIndex = self.previewSymbolIndex
            var randomSymbolIndex = previousSymbolIndex
            while randomSymbolIndex == previousSymbolIndex && !self.previewSymbols.isEmpty {
                randomSymbolIndex = Int.random(in: 0 ..< self.previewSymbols.count)
            }
            if !self.previewSymbols.isEmpty { self.previewSymbolIndex = randomSymbolIndex }
            
            let previousBackdropIndex = self.previewBackdropIndex
            var randomBackdropIndex = previousBackdropIndex
            while randomBackdropIndex == previousBackdropIndex && !self.previewBackdrops.isEmpty {
                randomBackdropIndex = Int.random(in: 0 ..< self.previewBackdrops.count)
            }
            if !self.previewBackdrops.isEmpty { self.previewBackdropIndex = randomBackdropIndex }
            
            self.state?.updated(transition: .easeInOut(duration: 0.25))
        }
        
        private func updateTimer() {
            if self.isPlaying {
                self.previewTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: true, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.timerTick()
                }, queue: Queue.mainQueue())
                self.previewTimer?.start()
            } else {
                self.previewTimer?.invalidate()
                self.previewTimer = nil
            }
        }
        
        private var effectiveGifts: [[StarGift.UniqueGift.Attribute]] = []
        private func updateEffectiveGifts() {
            guard let starGiftsState = self.starGiftsState else {
                return
            }
            
            var effectiveGifts: [[StarGift.UniqueGift.Attribute]] = []
            switch self.selectedSection {
            case .models:
                let models = Array(starGiftsState.attributes.filter({ attribute in
                    if case .model = attribute {
                        return true
                    } else {
                        return false
                    }
                }))
                for model in models {
                    effectiveGifts.append([model])
                }
            case .backdrops:
                let selectedModel = self.selectedModel ?? self.previewModels[self.previewModelIndex]
                let selectedSymbol = self.selectedSymbol ?? self.previewSymbols[self.previewSymbolIndex]
                let backdrops = Array(starGiftsState.attributes.filter({ attribute in
                    if case .backdrop = attribute {
                        return true
                    } else {
                        return false
                    }
                }))
                for backdrop in backdrops {
                    effectiveGifts.append([
                        selectedModel,
                        backdrop,
                        selectedSymbol
                    ])
                }
            case .symbols:
                let selectedBackdrop = self.selectedBackdrop ?? self.previewBackdrops[self.previewBackdropIndex]
                let symbols = Array(starGiftsState.attributes.filter({ attribute in
                    if case .pattern = attribute {
                        return true
                    } else {
                        return false
                    }
                }))
                for symbol in symbols {
                    effectiveGifts.append([
                        selectedBackdrop,
                        symbol
                    ])
                }
            }
            self.effectiveGifts = effectiveGifts
        }
        
        private func updateItems(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
        
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            let optionSpacing: CGFloat = 10.0
            let optionWidth = (itemLayout.containerSize.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
            let optionSize = CGSize(width: optionWidth, height: 126.0)
            
            let topInset: CGFloat = 393.0
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + 9.0), size: optionSize)
            
            for attributeList in self.effectiveGifts {
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                
                var itemId = ""
                var title = ""
                var rarity: Int32 = 0
                
                var modelAttribute: StarGift.UniqueGift.Attribute?
                var backdropAttribute: StarGift.UniqueGift.Attribute?
                var symbolAttribute: StarGift.UniqueGift.Attribute?
                
                switch self.selectedSection {
                case .models:
                    itemId += "models_"
                case .backdrops:
                    itemId += "backdrops_"
                case .symbols:
                    itemId += "symbols_"
                }
                
                var isSelected = false
                for attribute in attributeList {
                    switch attribute {
                    case let .model(name, _, rarityValue):
                        itemId += name
                        if self.selectedSection == .models {
                            title = name
                            rarity = rarityValue
                            modelAttribute = attribute
                            
                            isSelected = self.selectedModel == attribute
                        }
                    case let .backdrop(name, _, _, _, _, _, rarityValue):
                        itemId += name
                        if self.selectedSection == .backdrops {
                            title = name
                            rarity = rarityValue
                            backdropAttribute = attribute
                            
                            isSelected = self.selectedBackdrop == attribute
                        }
                    case let .pattern(name, _, rarityValue):
                        itemId += name
                        if self.selectedSection == .symbols {
                            title = name
                            rarity = rarityValue
                            symbolAttribute = attribute
                            
                            isSelected = self.selectedSymbol == attribute
                        }
                    default:
                        break
                    }
                }
                
                if isVisible {
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.giftItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        self.giftItems[itemId] = visibleItem
                    }
                    
                    let subject: GiftItemComponent.Subject = .preview(attributes: attributeList, rarity: rarity)
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(
                            PlainButtonComponent(
                                content: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        peer: nil,
                                        subject: subject,
                                        title: title,
                                        ribbon: nil,
                                        isSelected: isSelected,
                                        mode: .upgradePreview
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self, let state = self.state else {
                                        return
                                    }
                                    if self.isPlaying {
                                        self.isPlaying = false
                                        self.showRandomizeTip = true
                                        Queue.mainQueue().after(2.0) {
                                            if self.showRandomizeTip {
                                                self.showRandomizeTip = false
                                                self.state?.updated(transition: .easeInOut(duration: 0.25))
                                            }
                                        }
                                    }
                                    
                                    switch self.selectedSection {
                                    case .models:
                                        self.selectedModel = modelAttribute
                                    case .backdrops:
                                        self.selectedBackdrop = backdropAttribute
                                    case .symbols:
                                        self.selectedSymbol = symbolAttribute
                                    }
                                    
                                    state.updated(transition: .easeInOut(duration: 0.25))
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: optionSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.scrollContentView.addSubview(itemView)
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + optionSpacing
                if itemFrame.maxX > itemLayout.containerSize.width {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += optionSize.height + optionSpacing
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.giftItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeIds {
                self.giftItems.removeValue(forKey: id)
            }
        }
      
        func update(component: GiftUpgradePreviewScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.updateTimer()
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = rawSideInset + 16.0
            
            if self.component == nil {
                let giftIds: [Int64] = [
                    6014675319464657779,
                    6042113507581755979,
                    5936013938331222567
                ]
                
                self.starGiftsContext = ResaleGiftsContext(account: component.context.account, giftId: giftIds.randomElement()!)
                self.starGiftsDisposable = (self.starGiftsContext!.state
                                            |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    let isFirstTime = self.starGiftsState?.attributes.isEmpty ?? true
                    self.starGiftsState = state
                    
                    var modelCount: Int32 = 0
                    var backdropCount: Int32 = 0
                    var symbolCount: Int32 = 0
                    for attribute in state.attributes {
                        switch attribute {
                        case .model:
                            modelCount += 1
                        case .backdrop:
                            backdropCount += 1
                        case .pattern:
                            symbolCount += 1
                        default:
                            break
                        }
                    }
                    self.modelCount = modelCount
                    self.backdropCount = backdropCount
                    self.symbolCount = symbolCount
                    
                    if isFirstTime {
                        let randomModels = Array(state.attributes.filter({ attribute in
                            if case .model = attribute {
                                return true
                            } else {
                                return false
                            }
                        }).shuffled().prefix(15))
                        self.previewModels = randomModels
                        
                        let randomBackdrops = Array(state.attributes.filter({ attribute in
                            if case .backdrop = attribute {
                                return true
                            } else {
                                return false
                            }
                        }).shuffled())
                        self.previewBackdrops = randomBackdrops
                        
                        let randomSymbols = Array(state.attributes.filter({ attribute in
                            if case .pattern = attribute {
                                return true
                            } else {
                                return false
                            }
                        }).shuffled().prefix(15))
                        self.previewSymbols = randomSymbols
                        
                        self.updateEffectiveGifts()
                    }
                    
                    self.state?.updated(transition: .immediate)
                })
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            let theme = environment.theme.withModalBlocksBackground()
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = theme.list.blocksBackgroundColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var buttonColor: UIColor = .white.withAlphaComponent(0.1)
            var secondaryTextColor: UIColor = .white.withAlphaComponent(0.4)
            
            var attributes: [StarGift.UniqueGift.Attribute] = []
            if !self.previewModels.isEmpty {
                if self.isPlaying {
                    attributes.append(self.previewModels[self.previewModelIndex])
                    attributes.append(self.previewBackdrops[self.previewBackdropIndex])
                    attributes.append(self.previewSymbols[self.previewSymbolIndex])
                } else {
                    if self.selectedModel == nil {
                        self.selectedModel = self.previewModels[self.previewModelIndex]
                    }
                    if self.selectedBackdrop == nil {
                        self.selectedBackdrop = self.previewBackdrops[self.previewBackdropIndex]
                    }
                    if self.selectedSymbol == nil {
                        self.selectedSymbol = self.previewSymbols[self.previewSymbolIndex]
                    }
                    if let model = self.selectedModel {
                        attributes.append(model)
                    }
                    if let backdrop = self.selectedBackdrop {
                        attributes.append(backdrop)
                    }
                    if let symbol = self.selectedSymbol {
                        attributes.append(symbol)
                    }
                }
            }
            
            if let backdropAttribute = attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, innerColor, outerColor, _, _, _) = backdropAttribute {
                let topColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultiplied(hue: 1.01, saturation: 1.22, brightness: 1.04)
                let bottomColor = UIColor(rgb: UInt32(bitPattern: outerColor)).withMultiplied(hue: 0.97, saturation: 1.45, brightness: 0.89)
                buttonColor = topColor.mixedWith(bottomColor, alpha: 0.8)
                
                secondaryTextColor = topColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
            }
            
            var contentHeight: CGFloat = 0.0
            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(GiftCompositionComponent(
                    context: component.context,
                    theme: environment.theme,
                    subject: .preview(attributes),
                    animationOffset: CGPoint(x: 0.0, y: 20.0),
                    animationScale: nil,
                    displayAnimationStars: false,
                    revealedAttributes: Set(),
                    externalState: self.giftCompositionExternalState,
                    requestUpdate: { [weak state] transition in
                        state?.updated(transition: transition)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 300.0),
            )
            let headerFrame = CGRect(origin: CGPoint(x: floor((fillingSize - headerSize.width) * 0.5), y: 0.0), size: headerSize)
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    headerView.isUserInteractionEnabled = false
                    headerView.clipsToBounds = true
                    headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    headerView.layer.cornerRadius = 38.0
                    self.navigationBarContainer.addSubview(headerView)
                }
                transition.setFrame(view: headerView, frame: headerFrame)
            }
            
            contentHeight += headerSize.height
            
            var titleText: String = ""
            if let gift = self.starGiftsState?.gifts.first, case let .unique(gift) = gift {
                titleText = gift.title
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.semibold(20.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((fillingSize - titleSize.width) * 0.5), y: contentHeight - 124.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(14.0),
                    color: secondaryTextColor,
                    items: [
                        AnimatedTextComponent.Item(id: self.isPlaying ? "random" : "selected", content: .text(self.isPlaying ? "Random" : "Selected")),
                        AnimatedTextComponent.Item(id: "traits", content: .text(" Traits"))
                    ],
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((fillingSize - subtitleSize.width) * 0.5), y: contentHeight - 97.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.navigationBarContainer.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            
            let attributeSpacing: CGFloat = 10.0
            let attributeWidth: CGFloat = floor((fillingSize - sideInset * 2.0 - attributeSpacing * CGFloat(attributes.count - 1)) / CGFloat(attributes.count))
            let attributeHeight: CGFloat = 45.0
            
            for i in 0 ..< attributes.count {
                var attributeFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * (attributeWidth + attributeSpacing), y: contentHeight - 60.0), size: CGSize(width: attributeWidth, height: attributeHeight))
                if i == attributes.count - 1 {
                    attributeFrame.size.width = max(0.0, availableSize.width - sideInset - attributeFrame.minX)
                }
                let attributeInfo: ComponentView<Empty>
                if self.attributeInfos.count > i {
                    attributeInfo = self.attributeInfos[i]
                } else {
                    attributeInfo = ComponentView()
                    self.attributeInfos.append(attributeInfo)
                }
                let attribute = attributes[i]
                let _ = attributeInfo.update(
                    transition: transition,
                    component: AnyComponent(AttributeInfoComponent(
                        strings: environment.strings,
                        backgroundColor: buttonColor,
                        secondaryTextColor: secondaryTextColor,
                        attribute: attribute
                    )),
                    environment: {},
                    containerSize: attributeFrame.size
                )
                if let attributeInfoView = attributeInfo.view {
                    if attributeInfoView.superview == nil {
                        self.navigationBarContainer.addSubview(attributeInfoView)
                    }
                    transition.setFrame(view: attributeInfoView, frame: attributeFrame)
                }
            }
            
            contentHeight += 16.0
            
            let segmentedSize = self.segmentControl.update(
                transition: transition,
                component: AnyComponent(SegmentControlComponent(
                    theme: environment.theme,
                    items: [
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.models), title: "Models"),
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.backdrops), title: "Backgrounds"),
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.symbols), title: "Symbols")
                    ],
                    selectedId: "models",
                    action: { [weak self] id in
                        guard let self, let id = id.base as? SelectedSection else {
                            return
                        }
                        self.selectedSection = id
                        self.isPlaying = false
                        
                        self.updateEffectiveGifts()
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))) //.withUserData(AnimationHint(value: .modeChanged)))
                    })),
                environment: {},
                containerSize: CGSize(width: fillingSize - 8.0 * 2.0, height: 100.0)
            )
            let segmentedControlFrame = CGRect(origin: CGPoint(x: floor((fillingSize - segmentedSize.width) * 0.5), y: contentHeight), size: segmentedSize)
            if let segmentedControlComponentView = self.segmentControl.view {
                if segmentedControlComponentView.superview == nil {
                    self.scrollContentView.addSubview(segmentedControlComponentView)
                }
                transition.setFrame(view: segmentedControlComponentView, frame: segmentedControlFrame)
            }
            contentHeight += segmentedSize.height
            contentHeight += 18.0
            
            
            let descriptionText: String
            switch self.selectedSection {
            case .models:
                descriptionText = "This collection features **\(self.modelCount)** unique models."
            case .backdrops:
                descriptionText = "This collection features **\(self.backdropCount)** unique backdrops."
            case .symbols:
                descriptionText = "This collection features **\(self.symbolCount)** unique symbols."
            }
            
            let descriptionFont = Font.regular(13.0)
            let descriptionBoldFont = Font.semibold(13.0)
            let descriptionTextColor = theme.list.itemSecondaryTextColor
            let descriptionMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionTextColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionTextColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionTextColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let descriptionSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: descriptionText, attributes: descriptionMarkdownAttributes)
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floor((fillingSize - descriptionSize.width) * 0.5), y: contentHeight), size: descriptionSize)
            if let descriptionView = self.descriptionText.view {
                if descriptionView.superview == nil {
                    self.scrollContentView.addSubview(descriptionView)
                }
                transition.setFrame(view: descriptionView, frame: descriptionFrame)
            }
            contentHeight += descriptionSize.height
            contentHeight += 26.0
            
            
            
            
            ////
            ////            var validKeys: Set<Int64> = Set()
            ////            for auctionState in self.auctionStates {
            ////                let id = auctionState.gift.giftId
            ////                validKeys.insert(id)
            ////
            ////                let itemView: ComponentView<Empty>
            ////                if let current = self.itemsViews[id] {
            ////                    itemView = current
            ////                } else {
            ////                    itemView = ComponentView()
            ////                    self.itemsViews[id] = itemView
            ////                }
            ////
            ////                let itemSize = itemView.update(
            ////                    transition: transition,
            ////                    component: AnyComponent(
            ////                        ActiveAuctionComponent(
            ////                            context: component.context,
            ////                            theme: theme,
            ////                            strings: environment.strings,
            ////                            dateTimeFormat: environment.dateTimeFormat,
            ////                            state: auctionState,
            ////                            currentTime: currentTime,
            ////                            action: { [weak self] in
            ////                                guard let self, let component = self.component else {
            ////                                    return
            ////                                }
            ////                                if let giftAuctionsManager = component.context.giftAuctionsManager {
            ////                                    let _ = (giftAuctionsManager.auctionContext(for: .giftId(id))
            ////                                    |> deliverOnMainQueue).start(next: { [weak self] auction in
            ////                                        guard let self, let component = self.component, let auction, let controller = environment.controller(), let navigationController = controller.navigationController as? NavigationController else {
            ////                                            return
            ////                                        }
            ////                                        let bidController = component.context.sharedContext.makeGiftAuctionBidScreen(context: component.context, toPeerId: auction.currentBidPeerId ?? component.context.account.peerId, text: nil, entities: nil, hideName: false, auctionContext: auction, acquiredGifts: nil)
            ////                                        navigationController.pushViewController(bidController)
            ////                                    })
            ////                                }
            ////                            }
            ////                        )
            ////                    ),
            ////                    environment: {},
            ////                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            ////                )
            ////                let itemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: itemSize)
            ////                if let view = itemView.view {
            ////                    if view.superview == nil {
            ////                        self.scrollContentView.addSubview(view)
            ////                    }
            ////                    view.frame = itemFrame
            ////                }
            ////                contentHeight += itemSize.height
            ////                contentHeight += 20.0
            ////            }
            ////            contentHeight -= 10.0
            //
            //            var removeKeys: [Int64] = []
            //            for (id, item) in self.itemsViews {
            //                if !validKeys.contains(id) {
            //                    removeKeys.append(id)
            //
            //                    if let itemView = item.view {
            //                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
            //                            itemView.removeFromSuperview()
            //                        })
            //                    }
            //                }
            //            }
            //            for id in removeKeys {
            //                self.itemsViews.removeValue(forKey: id)
            //            }
            
            if self.backgroundHandleView.image == nil {
                self.backgroundHandleView.image = generateStretchableFilledCircleImage(diameter: 5.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundHandleView.tintColor = UIColor.white.withAlphaComponent(0.4)
            let backgroundHandleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - 36.0) * 0.5), y: 5.0), size: CGSize(width: 36.0, height: 5.0))
            if self.backgroundHandleView.superview == nil {
                self.navigationBarContainer.addSubview(self.backgroundHandleView)
            }
            transition.setFrame(view: self.backgroundHandleView, frame: backgroundHandleFrame)
            
            self.glassContainerView.update(size: CGSize(width: fillingSize, height: 64.0), isDark: false, transition: .immediate)
            self.glassContainerView.frame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: fillingSize, height: 64.0))
                                           
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 40.0, height: 40.0),
                    backgroundColor: secondaryTextColor,
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Back",
                            tintColor: .white
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(self.glassContainerView)
                    self.glassContainerView.contentView.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            var playbackItems: [AnyComponentWithIdentity<Empty>] = []
            var playbackSize = CGSize(width: 40.0, height: 40.0)
            if self.isPlaying {
                playbackItems.append(AnyComponentWithIdentity(id: "pause", component: AnyComponent(
                    BundleIconComponent(
                        name: "Media Gallery/PictureInPicturePause",
                        tintColor: .white
                    )
                )))
            } else {
                if self.showRandomizeTip {
                    playbackItems.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: "Randomize Traits", font: Font.semibold(17.0), textColor: .white)))
                    )))
                    playbackSize.width = 186.0
                }
                playbackItems.append(AnyComponentWithIdentity(id: "play", component: AnyComponent(
                    BundleIconComponent(
                        name: "Media Gallery/PlayButton",
                        tintColor: .white
                    )
                )))
            }
            
            let playbackButtonSize = self.playbackButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: playbackSize,
                    backgroundColor: secondaryTextColor,
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "content", component: AnyComponent(
                        HStack(playbackItems, spacing: 1.0)
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isPlaying = !self.isPlaying
                        
                        if !self.isPlaying {
                            self.showRandomizeTip = true
                            Queue.mainQueue().after(2.0) {
                                if self.showRandomizeTip {
                                    self.showRandomizeTip = false
                                    self.state?.updated(transition: .easeInOut(duration: 0.25))
                                }
                            }
                        } else {
                            self.selectedModel = nil
                            self.selectedBackdrop = nil
                            self.selectedSymbol = nil
                            
                            self.showRandomizeTip = false
                            
                            self.timerTick()
                        }
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                )),
                environment: {},
                containerSize: playbackSize
            )
            let playbackButtonFrame = CGRect(origin: CGPoint(x: fillingSize - 16.0 - playbackButtonSize.width, y: 16.0), size: playbackButtonSize)
            if let playbackButtonView = self.playbackButton.view {
                if playbackButtonView.superview == nil {
                    playbackButtonView.clipsToBounds = true
                    self.glassContainerView.contentView.addSubview(playbackButtonView)
                }
                transition.setFrame(view: playbackButtonView, frame: playbackButtonFrame)
            }
            
            //TODO:release
            contentHeight += 126.0 * 17.0
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            contentHeight += environment.safeInsets.bottom
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
             
            initialContentHeight = contentHeight
            
            clippingY = availableSize.height
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: environment.deviceMetrics.screenCornerRadius, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
                        
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let bottomInset: CGFloat = contentHeight - 12.0
            
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class GiftUpgradePreviewScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(context: context, component: GiftUpgradePreviewScreenComponent(
            context: context
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? GiftUpgradePreviewScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
        
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? GiftUpgradePreviewScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private final class AttributeInfoComponent: Component {
    let strings: PresentationStrings
    let backgroundColor: UIColor
    let secondaryTextColor: UIColor
    let attribute: StarGift.UniqueGift.Attribute
    
    init(
        strings: PresentationStrings,
        backgroundColor: UIColor,
        secondaryTextColor: UIColor,
        attribute: StarGift.UniqueGift.Attribute
    ) {
        self.strings = strings
        self.backgroundColor = backgroundColor
        self.secondaryTextColor = secondaryTextColor
        self.attribute = attribute
    }
    
    static func ==(lhs: AttributeInfoComponent, rhs: AttributeInfoComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.attribute != rhs.attribute {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let background = SimpleLayer()
        let title = ComponentView<Empty>()
        let subtitle = ComponentView<Empty>()
        
        let badgeBackground = SimpleLayer()
        let badge = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AttributeInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let backgroundFrame = CGRect(origin: CGPoint(), size: availableSize)
            if self.background.superlayer == nil {
                self.background.cornerRadius = 16.0
                self.background.cornerCurve = .continuous
                self.layer.addSublayer(self.background)
                
                self.badgeBackground.cornerRadius = 9.5
                self.badgeBackground.cornerCurve = .continuous
                self.layer.addSublayer(self.badgeBackground)
            }
            self.background.frame = backgroundFrame
            transition.setBackgroundColor(layer: self.background, color: component.backgroundColor)
            
            let title: String
            let subtitle: String
            let rarity: Int32
            switch component.attribute {
            case let .model(name, _, rarityValue):
                title = name
                subtitle = "model"
                rarity = rarityValue
            case let .backdrop(name, _, _, _, _, _, rarityValue):
                title = name
                subtitle = "backdrop"
                rarity = rarityValue
            case let .pattern(name, _, rarityValue):
                title = name
                subtitle = "symbol"
                rarity = rarityValue
            default:
                title = ""
                subtitle = ""
                rarity = 0
            }
        
            let _ = rarity
            
            let titleSize = self.title.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(13.0),
                    color: UIColor.white,
                    items: [AnimatedTextComponent.Item(id: "title", content: .text(title))],
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: CGSize(width: backgroundFrame.size.width - 8.0, height: backgroundFrame.size.height)
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitle, font: Font.regular(11.0), textColor: .white)),
                    tintColor: component.secondaryTextColor
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            
            let spacing: CGFloat = 0.0
            let titleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - titleSize.width) * 0.5), y: floor((backgroundFrame.height - titleSize.height - spacing - subtitleSize.height) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + spacing), size: subtitleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            func formatPercentage(_ value: Float) -> String {
                return String(format: "%0.1f", value).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ",0", with: "")
            }
            let percentage = Float(rarity) * 0.1
            
            let badgeSize = self.badge.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 12.0, weight: .semibold, traits: .monospacedNumbers),
                    color: UIColor.white,
                    items: [
                        AnimatedTextComponent.Item(id: "value", content: .text(formatPercentage(percentage))),
                        AnimatedTextComponent.Item(id: "percent", content: .text("%")),
                    ],
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            let badgeFrame = CGRect(origin: CGPoint(x: backgroundFrame.width - badgeSize.width - 2.0, y: backgroundFrame.minY - 8.0), size: badgeSize)
            if let badgeView = self.badge.view {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                transition.setFrame(view: badgeView, frame: badgeFrame)
            }
            
            let badgeBackgroundFrame = badgeFrame.insetBy(dx: -5.5, dy: -2.0)
            transition.setFrame(layer: self.badgeBackground, frame: badgeBackgroundFrame)
            transition.setBackgroundColor(layer: self.badgeBackground, color: component.backgroundColor.mixedWith(component.secondaryTextColor, alpha: 0.5))
            
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
