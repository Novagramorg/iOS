import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import GlassControls
import TableComponent
import AvatarComponent
import ContextUI
import TextFormat
import TooltipUI
import UndoUI
import WalletContext
import WalletCollectibleHeaderComponent
import WalletPeerSelectionScreen

private func walletCollectibleRarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity?) -> String {
    guard let rarity else {
        return "—"
    }
    switch rarity {
    case let .permille(value):
        if value == 0 {
            return "<0.1%"
        }
        let percentage = Float(value) * 0.1
        return String(format: "%0.1f", percentage)
            .replacingOccurrences(of: ".0", with: "")
            .replacingOccurrences(of: ",0", with: "") + "%"
    case .rare:
        return "Rare"
    case .epic:
        return "Epic"
    case .legendary:
        return "Legendary"
    case .uncommon:
        return "Uncommon"
    }
}

private func walletCollectibleExplorerUrl(address: String) -> String? {
    guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          !encodedAddress.isEmpty else {
        return nil
    }
    return "https://tonviewer.com/\(encodedAddress)"
}

private func walletCollectibleFragmentUrl(collectible: WalletContext.Collectible) -> String? {
    let path: String
    let value: String
    switch collectible.kind {
    case .username:
        path = "username"
        value = collectible.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    case .anonymousNumber:
        path = "number"
        value = collectible.name.filter { $0.isNumber }
    case .gift:
        guard let giftSlug = collectible.giftSlug else {
            return nil
        }
        path = "gift"
        value = giftSlug
    case .other:
        return nil
    }
    guard !value.isEmpty else {
        return nil
    }
    var allowedCharacters = CharacterSet.urlPathAllowed
    allowedCharacters.remove(charactersIn: "/?#%")
    guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
        return nil
    }
    return "https://fragment.com/\(path)/\(encodedValue)"
}

private final class WalletCollectibleActionComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let title: String
    let iconName: String
    let action: () -> Void

    init(theme: PresentationTheme, title: String, iconName: String, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.iconName = iconName
        self.action = action
    }

    static func ==(lhs: WalletCollectibleActionComponent, rhs: WalletCollectibleActionComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.iconName == rhs.iconName
    }

    final class View: UIView {
        private let backgroundView = UIView()
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        private var component: WalletCollectibleActionComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.isUserInteractionEnabled = false
            self.backgroundView.layer.cornerRadius = 16.0
            self.addSubview(self.backgroundView)
            self.addSubview(self.button)
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.button.highligthedChanged = { [weak self] highlighted in
                self?.backgroundView.alpha = highlighted ? 0.55 : 1.0
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.component?.action()
        }

        func update(
            component: WalletCollectibleActionComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component
            let size = CGSize(width: availableSize.width, height: 60.0)
            self.backgroundView.backgroundColor = component.theme.list.itemModalBlocksBackgroundColor
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.button, frame: CGRect(origin: .zero, size: size))

            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 28.0)
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(
                    x: floorToScreenPixels((size.width - iconSize.width) / 2.0),
                    y: 7.0,
                    width: iconSize.width,
                    height: iconSize.height
                ))
            }

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.medium(11.0),
                        textColor: component.theme.list.itemAccentColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: size.width - 12.0, height: 18.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    x: floorToScreenPixels((size.width - titleSize.width) / 2.0),
                    y: 38.0 + UIScreenPixel,
                    width: titleSize.width,
                    height: titleSize.height
                ))
            }
            return size
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

private final class WalletCollectibleTraitValueComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let value: String
    let rarity: String

    init(theme: PresentationTheme, value: String, rarity: String) {
        self.theme = theme
        self.value = value
        self.rarity = rarity
    }

    static func ==(lhs: WalletCollectibleTraitValueComponent, rhs: WalletCollectibleTraitValueComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.value == rhs.value && lhs.rarity == rhs.rarity
    }

    final class View: UIView {
        private let value = ComponentView<Empty>()
        private let rarityBackground = UIView()
        private let rarity = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.rarityBackground.isUserInteractionEnabled = false
            self.rarityBackground.layer.cornerRadius = 9.0
            self.addSubview(self.rarityBackground)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletCollectibleTraitValueComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let valueSize = self.value.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.value,
                        font: Font.regular(15.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let raritySize = self.rarity.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.rarity,
                        font: Font.regular(11.0),
                        textColor: component.theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let spacing: CGFloat = 4.0
            let badgeSize = CGSize(width: raritySize.width + 10.0, height: 16.0)
            let displayedValueWidth = min(valueSize.width, max(0.0, availableSize.width - badgeSize.width - spacing))
            let badgeX = displayedValueWidth + spacing
            let totalWidth = min(availableSize.width, displayedValueWidth + spacing + badgeSize.width)
            if let valueView = self.value.view {
                if valueView.superview == nil {
                    valueView.isUserInteractionEnabled = false
                    self.addSubview(valueView)
                }
                transition.setFrame(view: valueView, frame: CGRect(
                    x: 0.0,
                    y: floorToScreenPixels((badgeSize.height - valueSize.height) / 2.0),
                    width: displayedValueWidth,
                    height: valueSize.height
                ))
            }
            self.rarityBackground.backgroundColor = component.theme.list.itemAccentColor.withAlphaComponent(0.1)
            transition.setFrame(view: self.rarityBackground, frame: CGRect(
                x: badgeX,
                y: 0.0,
                width: badgeSize.width,
                height: badgeSize.height
            ))
            if let rarityView = self.rarity.view {
                if rarityView.superview == nil {
                    rarityView.isUserInteractionEnabled = false
                    self.addSubview(rarityView)
                }
                transition.setFrame(view: rarityView, frame: CGRect(
                    x: badgeX + 5.0,
                    y: floorToScreenPixels((badgeSize.height - raritySize.height) / 2.0),
                    width: raritySize.width,
                    height: raritySize.height
                ))
            }
            return CGSize(width: totalWidth, height: badgeSize.height)
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

private final class WalletCollectibleContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectible: WalletContext.Collectible
    let openExternalUrl: (String) -> Void
    let openTransfer: () -> Void
    let animateOut: ActionSlot<Action<Void>>

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        openExternalUrl: @escaping (String) -> Void,
        openTransfer: @escaping () -> Void,
        animateOut: ActionSlot<Action<Void>>
    ) {
        self.context = context
        self.collectible = collectible
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
        self.animateOut = animateOut
    }

    static func ==(lhs: WalletCollectibleContentComponent, rhs: WalletCollectibleContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.collectible == rhs.collectible
    }

    final class View: UIView {
        private let controlButtons = ComponentView<Empty>()
        private let header = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let transferButton = ComponentView<Empty>()
        private let wearButton = ComponentView<Empty>()
        private let sellButton = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()

        private let giftDisposable = MetaDisposable()
        private let peerDisposable = MetaDisposable()
        private var component: WalletCollectibleContentComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var configuredAddress: String?
        private var uniqueGift: StarGift.UniqueGift?
        private var currentPeer: EnginePeer?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.giftDisposable.dispose()
            self.peerDisposable.dispose()
        }

        private func configure(component: WalletCollectibleContentComponent) {
            self.configuredAddress = component.collectible.address
            self.uniqueGift = nil
            self.currentPeer = nil
            self.giftDisposable.set(nil)
            self.peerDisposable.set((component.context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, self.configuredAddress == component.collectible.address else {
                    return
                }
                self.currentPeer = peer
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }))

            if component.collectible.kind == .gift, let slug = component.collectible.giftSlug {
                self.giftDisposable.set((component.context.engine.payments.getUniqueStarGift(slug: slug)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<StarGift.UniqueGift?, NoError> in
                    return .single(nil)
                }
                |> deliverOnMainQueue).start(next: { [weak self] gift in
                    guard let self, self.configuredAddress == component.collectible.address else {
                        return
                    }
                    self.uniqueGift = gift
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                }))
            }
        }

        private func close() {
            guard let component = self.component,
                  let controller = self.environment?.controller() as? WalletCollectibleScreen else {
                return
            }
            controller.dismissAllTooltips()
            controller.requestLayout(
                forceUpdate: true,
                transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
            )
            component.animateOut.invoke(Action { [weak controller] _ in
                controller?.dismiss(completion: nil)
            })
        }

        private func openExplorer(sourceView: UIView) {
            guard let component = self.component,
                  let controller = self.environment?.controller() as? WalletCollectibleScreen else {
                return
            }
            let explorerUrl = walletCollectibleExplorerUrl(address: component.collectible.address)
            let item = ContextMenuActionItem(
                text: "View In Explorer",
                icon: { theme in
                    return generateTintedImage(
                        image: UIImage(bundleImageName: "Chat/Context Menu/Search"),
                        color: theme.contextMenu.primaryColor
                    )
                },
                action: { [weak self] contextController, dismiss in
                    let open = {
                        guard let self, let explorerUrl else {
                            return
                        }
                        self.close()
                        component.openExternalUrl(explorerUrl)
                    }
                    if let contextController {
                        contextController.dismiss(result: .default, completion: open)
                    } else {
                        dismiss(.default)
                        open()
                    }
                }
            )
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                source: .reference(WalletCollectibleContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list([.action(item)]))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        private func giftTrait(
            key: String,
            collectible: WalletContext.Collectible
        ) -> (value: String, rarity: String) {
            if let uniqueGift = self.uniqueGift {
                for attribute in uniqueGift.attributes {
                    switch (key, attribute) {
                    case let ("model", .model(name, _, rarity, _)):
                        return (name, walletCollectibleRarityText(rarity))
                    case let ("symbol", .pattern(name, _, rarity)):
                        return (name, walletCollectibleRarityText(rarity))
                    case let ("backdrop", .backdrop(name, _, _, _, _, _, rarity)):
                        return (name, walletCollectibleRarityText(rarity))
                    default:
                        break
                    }
                }
            }
            return (collectible.attributes[key] ?? "—", "—")
        }

        private func giftValue() -> String {
            guard let uniqueGift = self.uniqueGift else {
                return "—"
            }
            var parts: [String] = []
            if let amount = uniqueGift.valueAmount, let currency = uniqueGift.valueCurrency {
                parts.append(formatCurrencyAmount(amount, currency: currency))
            }
            if let usdAmount = uniqueGift.valueUsdAmount {
                parts.append("~\(formatCurrencyAmount(usdAmount, currency: "USD"))")
            }
            return parts.isEmpty ? "—" : parts.joined(separator: " ")
        }

        private func giftTableItems(
            component: WalletCollectibleContentComponent,
            theme: PresentationTheme
        ) -> [TableComponent.Item] {
            var ownerItems: [AnyComponentWithIdentity<Empty>] = []
            if let currentPeer = self.currentPeer {
                ownerItems.append(AnyComponentWithIdentity(
                    id: "avatar",
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        theme: theme,
                        peer: currentPeer,
                        size: CGSize(width: 20.0, height: 20.0)
                    ))
                ))
            }
            ownerItems.append(AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "You",
                        font: Font.regular(15.0),
                        textColor: theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                ))
            ))

            let model = self.giftTrait(key: "model", collectible: component.collectible)
            let symbol = self.giftTrait(key: "symbol", collectible: component.collectible)
            let backdrop = self.giftTrait(key: "backdrop", collectible: component.collectible)
            return [
                TableComponent.Item(
                    id: "owner",
                    title: "Owner",
                    component: AnyComponent(HStack(ownerItems, spacing: 6.0))
                ),
                TableComponent.Item(
                    id: "model",
                    title: "Model",
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: model.value,
                        rarity: model.rarity
                    ))
                ),
                TableComponent.Item(
                    id: "symbol",
                    title: "Symbol",
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: symbol.value,
                        rarity: symbol.rarity
                    ))
                ),
                TableComponent.Item(
                    id: "backdrop",
                    title: "Backdrop",
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: backdrop.value,
                        rarity: backdrop.rarity
                    ))
                ),
                TableComponent.Item(
                    id: "value",
                    title: "Value",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.giftValue(),
                            font: Font.regular(15.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                )
            ]
        }

        func update(
            component: WalletCollectibleContentComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.environment = environment
            self.componentState = state
            if self.configuredAddress != component.collectible.address {
                self.configure(component: component)
            }

            let theme = environment.theme
            let controlsSize = self.controlButtons.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [GlassControlGroupComponent.Item(
                            id: AnyHashable("close"),
                            content: .icon("Navigation/Close"),
                            action: { [weak self] in
                                self?.close()
                            }
                        )],
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: GlassControlPanelComponent.Item(
                        items: [GlassControlGroupComponent.Item(
                            id: AnyHashable("more"),
                            content: .animation("anim_morewide"),
                            action: { [weak self] in
                                guard let self,
                                      let controlsView = self.controlButtons.view as? GlassControlPanelComponent.View,
                                      let sourceView = controlsView.rightItemView?.itemView(id: AnyHashable("more")) else {
                                    return
                                }
                                self.openExplorer(sourceView: sourceView)
                            }
                        )],
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 44.0)
            )
            if let controlsView = self.controlButtons.view {
                if controlsView.superview == nil {
                    self.addSubview(controlsView)
                }
                transition.setFrame(view: controlsView, frame: CGRect(x: 16.0, y: 16.0, width: controlsSize.width, height: controlsSize.height))
            }

            let displaysCollection: Bool
            switch component.collectible.kind {
            case .username, .anonymousNumber:
                displaysCollection = false
            case .gift, .other:
                displaysCollection = true
            }
            var contentHeight: CGFloat = 44.0
            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(WalletCollectibleHeaderComponent(
                    context: component.context,
                    theme: theme,
                    item: WalletCollectibleHeaderComponent.Item(
                        name: component.collectible.name,
                        imageUrl: component.collectible.imageUrl,
                        lottieUrl: component.collectible.lottieUrl,
                        collectionName: component.collectible.collectionName,
                        collectionUrl: component.collectible.collectionUrl
                    ),
                    displaysCollection: displaysCollection,
                    openCollection: component.openExternalUrl
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    self.addSubview(headerView)
                }
                transition.setFrame(view: headerView, frame: CGRect(x: 0.0, y: contentHeight, width: headerSize.width, height: headerSize.height))
                (headerView as? WalletCollectibleHeaderComponent.View)?.setAnimationVisible(true)
            }
            contentHeight += headerSize.height

            if component.collectible.kind != .gift,
               let description = component.collectible.description,
               !description.isEmpty {
                contentHeight += 12.0
                let descriptionSize = self.descriptionText.update(
                    transition: transition,
                    component: AnyComponent(BalancedTextComponent(
                        text: .plain(NSAttributedString(
                            string: description,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.secondaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 48.0, height: 1000.0)
                )
                if let descriptionView = self.descriptionText.view {
                    if descriptionView.superview == nil {
                        descriptionView.isUserInteractionEnabled = false
                        self.addSubview(descriptionView)
                    }
                    transition.setFrame(view: descriptionView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - descriptionSize.width) / 2.0),
                        y: contentHeight,
                        width: descriptionSize.width,
                        height: descriptionSize.height
                    ))
                    transition.setAlpha(view: descriptionView, alpha: 1.0)
                }
                contentHeight += descriptionSize.height
            } else if let descriptionView = self.descriptionText.view {
                transition.setAlpha(view: descriptionView, alpha: 0.0)
            }

            contentHeight += 28.0
            let buttonSpacing: CGFloat = 10.0
            let sideInset: CGFloat = 20.0
            let buttonCount: CGFloat = component.collectible.kind == .gift ? 3.0 : 2.0
            let buttonWidth = floor((availableSize.width - sideInset * 2.0 - buttonSpacing * (buttonCount - 1.0)) / buttonCount)
            var buttonX = sideInset
            let transferSize = self.transferButton.update(
                transition: transition,
                component: AnyComponent(WalletCollectibleActionComponent(
                    theme: theme,
                    title: "transfer",
                    iconName: "Premium/Collectible/Transfer",
                    action: {
                        component.openTransfer()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: 60.0)
            )
            if let transferView = self.transferButton.view {
                if transferView.superview == nil {
                    self.addSubview(transferView)
                }
                transition.setFrame(view: transferView, frame: CGRect(x: buttonX, y: contentHeight, width: transferSize.width, height: transferSize.height))
            }
            buttonX += buttonWidth + buttonSpacing

            if component.collectible.kind == .gift {
                let wearSize = self.wearButton.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleActionComponent(
                        theme: theme,
                        title: "wear",
                        iconName: "Premium/Collectible/Wear",
                        action: {
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: 60.0)
                )
                if let wearView = self.wearButton.view {
                    if wearView.superview == nil {
                        self.addSubview(wearView)
                    }
                    transition.setFrame(view: wearView, frame: CGRect(x: buttonX, y: contentHeight, width: wearSize.width, height: wearSize.height))
                    transition.setAlpha(view: wearView, alpha: 1.0)
                }
                buttonX += buttonWidth + buttonSpacing
            } else if let wearView = self.wearButton.view {
                transition.setAlpha(view: wearView, alpha: 0.0)
            }

            let sellSize = self.sellButton.update(
                transition: transition,
                component: AnyComponent(WalletCollectibleActionComponent(
                    theme: theme,
                    title: "sell",
                    iconName: "Premium/Collectible/Sell",
                    action: {
                        guard let url = walletCollectibleFragmentUrl(collectible: component.collectible) else {
                            return
                        }
                        component.openExternalUrl(url)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: 60.0)
            )
            if let sellView = self.sellButton.view {
                if sellView.superview == nil {
                    self.addSubview(sellView)
                }
                transition.setFrame(view: sellView, frame: CGRect(x: buttonX, y: contentHeight, width: sellSize.width, height: sellSize.height))
            }
            contentHeight += 60.0

            if component.collectible.kind == .gift {
                contentHeight += 20.0
                let tableSize = self.table.update(
                    transition: transition,
                    component: AnyComponent(TableComponent(
                        theme: theme,
                        items: self.giftTableItems(component: component, theme: theme),
                        semiTransparent: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 48.0, height: 1000.0)
                )
                if let tableView = self.table.view {
                    if tableView.superview == nil {
                        self.addSubview(tableView)
                    }
                    transition.setFrame(view: tableView, frame: CGRect(
                        x: sideInset,
                        y: contentHeight,
                        width: tableSize.width,
                        height: tableSize.height
                    ))
                    transition.setAlpha(view: tableView, alpha: 1.0)
                }
                contentHeight += tableSize.height
            } else if let tableView = self.table.view {
                transition.setAlpha(view: tableView, alpha: 0.0)
            }

            contentHeight += 30.0
            let actionSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(id: "OK", component: AnyComponent(Text(
                        text: "OK",
                        font: Font.semibold(17.0),
                        color: theme.list.itemCheckColors.foregroundColor
                    ))),
                    action: { [weak self] in
                        self?.close()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 60.0, height: 52.0)
            )
            if let actionView = self.actionButton.view {
                if actionView.superview == nil {
                    self.addSubview(actionView)
                }
                transition.setFrame(view: actionView, frame: CGRect(
                    x: floorToScreenPixels((availableSize.width - actionSize.width) / 2.0),
                    y: contentHeight,
                    width: actionSize.width,
                    height: actionSize.height
                ))
            }
            contentHeight += actionSize.height + 30.0

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

private final class WalletCollectiblePagerComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectibles: [WalletContext.Collectible]
    let initialIndex: Int
    let itemSpacing: CGFloat
    let openExternalUrl: (String) -> Void
    let openTransfer: (WalletContext.Collectible) -> Void
    let indexUpdated: (Int) -> Void
    let draggingBegan: (Int) -> Void

    init(
        context: AccountContext,
        collectibles: [WalletContext.Collectible],
        initialIndex: Int,
        itemSpacing: CGFloat,
        openExternalUrl: @escaping (String) -> Void,
        openTransfer: @escaping (WalletContext.Collectible) -> Void,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) {
        self.context = context
        self.collectibles = collectibles
        self.initialIndex = initialIndex
        self.itemSpacing = itemSpacing
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
        self.indexUpdated = indexUpdated
        self.draggingBegan = draggingBegan
    }

    static func ==(lhs: WalletCollectiblePagerComponent, rhs: WalletCollectiblePagerComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.collectibles == rhs.collectibles
            && lhs.initialIndex == rhs.initialIndex
            && lhs.itemSpacing == rhs.itemSpacing
    }

    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let scrollView: UIScrollView
        private var itemViews: [String: ComponentHostView<EnvironmentType>] = [:]

        private var component: WalletCollectiblePagerComponent?
        private var environment: Environment<EnvironmentType>?
        private var previousItemStride: CGFloat?
        private var previousIsDisplaying = false
        private var lastReportedIndex: Int?
        private var isUpdating = false
        private var ignoreContentOffsetChange = false
        private var isSwiping = false
        private var lastScrollTime: TimeInterval = 0.0

        override init(frame: CGRect) {
            self.dimView = UIView()
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)

            self.scrollView = UIScrollView(frame: frame)
            self.scrollView.clipsToBounds = true
            self.scrollView.isPagingEnabled = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.bounces = false
            self.scrollView.layer.cornerRadius = 10.0
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }

            super.init(frame: frame)

            self.addSubview(self.dimView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func itemStride(component: WalletCollectiblePagerComponent, availableWidth: CGFloat) -> CGFloat {
            return availableWidth + component.itemSpacing * 2.0
        }

        private func currentIndex(component: WalletCollectiblePagerComponent, itemStride: CGFloat) -> Int {
            guard !component.collectibles.isEmpty, itemStride > 0.0 else {
                return 0
            }
            return max(0, min(component.collectibles.count - 1, Int(round(self.scrollView.contentOffset.x / itemStride))))
        }

        private func reportCurrentIndex(force: Bool = false) {
            guard let component = self.component, !component.collectibles.isEmpty else {
                return
            }
            let itemStride = self.previousItemStride
                ?? self.itemStride(component: component, availableWidth: self.bounds.width)
            let index = self.currentIndex(component: component, itemStride: itemStride)
            if force || self.lastReportedIndex != index {
                self.lastReportedIndex = index
                component.indexUpdated(index)
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let component = self.component, !component.collectibles.isEmpty else {
                return
            }
            self.isSwiping = true
            self.lastScrollTime = CACurrentMediaTime()
            component.draggingBegan(self.currentIndex(
                component: component,
                itemStride: self.previousItemStride
                    ?? self.itemStride(component: component, availableWidth: self.bounds.width)
            ))
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.isSwiping = false
                self.reportCurrentIndex(force: true)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.isSwiping = false
            self.reportCurrentIndex(force: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component,
                  let environment = self.environment,
                  !self.ignoreContentOffsetChange,
                  !self.isUpdating else {
                return
            }
            if self.isSwiping {
                self.lastScrollTime = CACurrentMediaTime()
            }

            self.ignoreContentOffsetChange = true
            let _ = self.update(
                component: component,
                availableSize: self.bounds.size,
                environment: environment,
                transition: .immediate
            )
            self.ignoreContentOffsetChange = false
            self.reportCurrentIndex()
        }

        func update(
            component: WalletCollectiblePagerComponent,
            availableSize: CGSize,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))

            let previousComponent = self.component
            let previousItemStride = self.previousItemStride
            var anchorAddress: String?
            var anchorFraction: CGFloat = 0.0
            if let previousComponent,
               let previousItemStride,
               previousItemStride > 0.0,
               !previousComponent.collectibles.isEmpty {
                let previousIndex = self.currentIndex(component: previousComponent, itemStride: previousItemStride)
                anchorAddress = previousComponent.collectibles[previousIndex].address
                anchorFraction = self.scrollView.contentOffset.x / previousItemStride - CGFloat(previousIndex)
            }

            self.component = component
            self.environment = environment

            let itemWidth = availableSize.width
            let itemStride = self.itemStride(component: component, availableWidth: itemWidth)
            self.previousItemStride = itemStride
            let totalWidth = itemWidth * CGFloat(component.collectibles.count)
                + component.itemSpacing * 2.0 * CGFloat(component.collectibles.count)
            let contentSize = CGSize(width: totalWidth, height: availableSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollFrame = CGRect(
                x: -component.itemSpacing / 2.0,
                y: 0.0,
                width: availableSize.width + component.itemSpacing * 2.0,
                height: availableSize.height
            )
            if self.scrollView.frame != scrollFrame {
                self.scrollView.frame = scrollFrame
            }

            let isFirstUpdate = previousComponent == nil || self.itemViews.isEmpty
            var targetOffset: CGFloat?
            if isFirstUpdate {
                let initialIndex = max(0, min(component.collectibles.count - 1, component.initialIndex))
                targetOffset = CGFloat(initialIndex) * itemStride
            } else if let anchorAddress,
                      let anchorIndex = component.collectibles.firstIndex(where: { $0.address == anchorAddress }) {
                targetOffset = (CGFloat(anchorIndex) + anchorFraction) * itemStride
            }
            if let targetOffset {
                let maximumOffset = max(0.0, contentSize.width - scrollFrame.width)
                self.ignoreContentOffsetChange = true
                self.scrollView.contentOffset = CGPoint(x: max(0.0, min(maximumOffset, targetOffset)), y: 0.0)
                self.ignoreContentOffsetChange = false
            }

            let viewportCenter = self.scrollView.contentOffset.x + availableSize.width * 0.5
            let isSwipingActive = self.isSwiping || CACurrentMediaTime() - self.lastScrollTime < 0.5
            var validIds = Set<String>()

            for (index, collectible) in component.collectibles.enumerated() {
                let itemOriginX = component.itemSpacing * 0.5 + itemStride * CGFloat(index)
                let itemFrame = CGRect(x: itemOriginX, y: 0.0, width: itemWidth, height: availableSize.height)
                let position = (itemFrame.midX - viewportCenter) / (availableSize.width * 0.75)
                if (!isSwipingActive && abs(position) > 0.5) || (isSwipingActive && abs(position) > 1.5) {
                    continue
                }

                validIds.insert(collectible.address)
                let itemView: ComponentHostView<EnvironmentType>
                var itemTransition = transition
                if let current = self.itemViews[collectible.address] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<EnvironmentType>()
                    self.itemViews[collectible.address] = itemView
                    self.scrollView.addSubview(itemView)
                }

                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(WalletCollectibleSheetComponent(
                        context: component.context,
                        collectible: collectible,
                        openExternalUrl: component.openExternalUrl,
                        openTransfer: {
                            component.openTransfer(collectible)
                        }
                    )),
                    environment: { environment[EnvironmentType.self] },
                    containerSize: availableSize
                )
                itemView.frame = itemFrame
            }

            var removeIds: [String] = []
            for (id, itemView) in self.itemViews where !validIds.contains(id) {
                removeIds.append(id)
                itemView.removeFromSuperview()
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }

            let viewEnvironment = environment[EnvironmentType.self].value
            if let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            } else if self.previousIsDisplaying,
                      let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
                self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            self.previousIsDisplaying = viewEnvironment.isVisible

            if isFirstUpdate {
                self.reportCurrentIndex(force: true)
            }
            return availableSize
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
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class WalletCollectibleSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectible: WalletContext.Collectible
    let openExternalUrl: (String) -> Void
    let openTransfer: () -> Void

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        openExternalUrl: @escaping (String) -> Void,
        openTransfer: @escaping () -> Void
    ) {
        self.context = context
        self.collectible = collectible
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
    }

    static func ==(lhs: WalletCollectibleSheetComponent, rhs: WalletCollectibleSheetComponent) -> Bool {
        return lhs.context === rhs.context && lhs.collectible == rhs.collectible
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let sheetComponent = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletCollectibleContentComponent(
                        context: context.component.context,
                        collectible: context.component.collectible,
                        openExternalUrl: context.component.openExternalUrl,
                        openTransfer: context.component.openTransfer,
                        animateOut: animateOut
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    hasDimView: false,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        (controller() as? WalletCollectibleScreen)?.dismissAllTooltips()
                    },
                    willDismiss: {
                        (controller() as? WalletCollectibleScreen)?.requestLayout(
                            forceUpdate: true,
                            transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                        )
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
                            guard let controller = controller() as? WalletCollectibleScreen else {
                                return
                            }
                            controller.dismissAllTooltips()
                            if animated {
                                controller.requestLayout(
                                    forceUpdate: true,
                                    transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                                )
                                animateOut.invoke(Action { [weak controller] _ in
                                    controller?.dismiss(completion: nil)
                                })
                            } else {
                                controller.dismiss(animated: false)
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                controller.presentationContext.containerLayoutUpdated(
                    ContainerViewLayout(
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
                    ),
                    transition: context.transition.containedViewLayoutTransition
                )
            }
            return context.availableSize
        }
    }
}

public final class WalletCollectibleScreen: ViewControllerComponentContainer {
    private let accountContext: AccountContext
    private let walletContext: WalletContext
    private let openExternalUrl: (String) -> Void
    private let stateDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()

    private var collectiblesState: WalletContext.CollectiblesState
    private var collectibles: [WalletContext.Collectible]
    private var currentAddress: String
    private var requestedOffset: Int?
    private var failedOffset: Int?

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        collectible: WalletContext.Collectible
    ) {
        let initialState = walletContext.stateValue.collectibles
        var initialCollectibles = initialState.items
        if !initialCollectibles.contains(where: { $0.address == collectible.address }) {
            initialCollectibles.insert(collectible, at: 0)
        }
        let initialIndex = initialCollectibles.firstIndex(where: { $0.address == collectible.address }) ?? 0
        let openExternalUrl: (String) -> Void = { url in
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

        self.accountContext = context
        self.walletContext = walletContext
        self.openExternalUrl = openExternalUrl
        self.collectiblesState = initialState
        self.collectibles = initialCollectibles
        self.currentAddress = collectible.address

        var indexUpdatedImpl: ((Int) -> Void)?
        var draggingBeganImpl: ((Int) -> Void)?
        var openTransferImpl: ((WalletContext.Collectible) -> Void)?
        super.init(
            context: context,
            component: WalletCollectiblePagerComponent(
                context: context,
                collectibles: initialCollectibles,
                initialIndex: initialIndex,
                itemSpacing: 10.0,
                openExternalUrl: openExternalUrl,
                openTransfer: { collectible in
                    openTransferImpl?(collectible)
                },
                indexUpdated: { index in
                    indexUpdatedImpl?(index)
                },
                draggingBegan: { index in
                    draggingBeganImpl?(index)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        indexUpdatedImpl = { [weak self] index in
            self?.currentIndexUpdated(index)
        }
        draggingBeganImpl = { [weak self] index in
            self?.draggingBegan(index)
        }
        openTransferImpl = { [weak self] collectible in
            self?.openTransfer(collectible)
        }

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false

        self.stateDisposable.set((walletContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.collectiblesStateUpdated(state.collectibles)
        }))
        self.requestLoadMoreIfNeeded(index: initialIndex)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.stateDisposable.dispose()
        self.loadMoreDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }

    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }

    private func collectiblesStateUpdated(_ state: WalletContext.CollectiblesState) {
        if let requestedOffset = self.requestedOffset,
           state.offset != requestedOffset || !state.canLoadMore {
            self.requestedOffset = nil
            self.failedOffset = nil
        }

        var collectibles = state.items
        if !collectibles.contains(where: { $0.address == self.currentAddress }),
           let currentCollectible = self.collectibles.first(where: { $0.address == self.currentAddress }) {
            let previousIndex = self.collectibles.firstIndex(where: { $0.address == self.currentAddress }) ?? 0
            collectibles.insert(currentCollectible, at: min(previousIndex, collectibles.count))
        }
        if collectibles.isEmpty, let currentCollectible = self.collectibles.first {
            collectibles = [currentCollectible]
        }

        self.collectiblesState = state
        self.collectibles = collectibles
        let currentIndex = collectibles.firstIndex(where: { $0.address == self.currentAddress }) ?? 0
        self.updatePager(initialIndex: currentIndex)
        self.requestLoadMoreIfNeeded(index: currentIndex)
    }

    private func updatePager(initialIndex: Int) {
        self.updateComponent(
            component: AnyComponent(WalletCollectiblePagerComponent(
                context: self.accountContext,
                collectibles: self.collectibles,
                initialIndex: initialIndex,
                itemSpacing: 10.0,
                openExternalUrl: self.openExternalUrl,
                openTransfer: { [weak self] collectible in
                    self?.openTransfer(collectible)
                },
                indexUpdated: { [weak self] index in
                    self?.currentIndexUpdated(index)
                },
                draggingBegan: { [weak self] index in
                    self?.draggingBegan(index)
                }
            )),
            transition: .immediate
        )
    }

    private func openTransfer(_ collectible: WalletContext.Collectible) {
        let peerSelectionScreen = WalletPeerSelectionScreen(
            context: self.accountContext,
            walletContext: self.walletContext,
            mode: .collectible(collectible),
            dismissSourceScreen: { [weak self] in
                guard let self else {
                    return
                }
                if let navigationController = self.navigationController as? NavigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeAll(where: { $0 === self })
                    navigationController.setViewControllers(viewControllers, animated: false)
                } else {
                    self.dismiss(animated: false)
                }
            }
        )
        peerSelectionScreen.navigationPresentation = .modal
        self.push(peerSelectionScreen)
    }

    private func currentIndexUpdated(_ index: Int) {
        guard self.collectibles.indices.contains(index) else {
            return
        }
        self.currentAddress = self.collectibles[index].address
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func draggingBegan(_ index: Int) {
        if self.failedOffset == self.collectiblesState.offset {
            self.requestedOffset = nil
            self.failedOffset = nil
        }
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func requestLoadMoreIfNeeded(index: Int) {
        guard !self.collectibles.isEmpty,
              index >= max(0, self.collectibles.count - 2),
              self.collectiblesState.canLoadMore,
              !self.collectiblesState.isLoadingMore,
              self.collectiblesState.offset >= self.collectibles.count - 1,
              self.collectiblesState.error == nil || self.failedOffset == nil,
              self.walletContext.stateValue.activeOperation == nil else {
            return
        }
        let offset = self.collectiblesState.offset
        guard self.requestedOffset != offset else {
            return
        }
        self.requestedOffset = offset
        self.loadMoreDisposable.set((self.walletContext.loadMoreCollectibles()
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let self, self.requestedOffset == offset else {
                return
            }
            self.failedOffset = offset
        }))
    }
}

private final class WalletCollectibleContextReferenceContentSource: ContextReferenceContentSource {
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
