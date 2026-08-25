import Foundation
import UIKit
import Display
import AccountContext
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import ListActionItemComponent
import ListSectionComponent
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext
import WalletTransactionItemComponent

final class WalletTransferNavigationAppIconComponent: Component {
    let applicationName: String
    let iconUrl: String?

    init(applicationName: String, iconUrl: String?) {
        self.applicationName = applicationName
        self.iconUrl = iconUrl
    }

    static func ==(lhs: WalletTransferNavigationAppIconComponent, rhs: WalletTransferNavigationAppIconComponent) -> Bool {
        return lhs.applicationName == rhs.applicationName && lhs.iconUrl == rhs.iconUrl
    }

    final class View: UIView {
        private let icon = ComponentView<Empty>()

        func update(
            component: WalletTransferNavigationAppIconComponent,
            state: EmptyComponentState,
            transition: ComponentTransition
        ) -> CGSize {
            let size = CGSize(width: 44.0, height: 44.0)
            self.icon.parentState = state
            let _ = self.icon.update(
                transition: transition,
                component: AnyComponent(WalletConnectAppIconComponent(
                    applicationName: component.applicationName,
                    url: component.iconUrl
                )),
                environment: {},
                containerSize: size
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.clipsToBounds = true
                iconView.layer.borderWidth = 3.0
                iconView.layer.borderColor = UIColor.white.cgColor
                transition.setCornerRadius(layer: iconView.layer, cornerRadius: size.width * 0.5)
                transition.setFrame(view: iconView, frame: CGRect(origin: .zero, size: size))
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
        return view.update(component: self, state: state, transition: transition)
    }
}

private final class WalletTransferPreviewIconComponent: Component {
    enum Kind: Equatable {
        case transfer
        case outgoing
        case incoming
        case contract
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    static func ==(lhs: WalletTransferPreviewIconComponent, rhs: WalletTransferPreviewIconComponent) -> Bool {
        return lhs.kind == rhs.kind
    }

    final class View: UIView {
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.iconView.contentMode = .scaleAspectFit
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransferPreviewIconComponent) -> CGSize {
            let size = CGSize(width: 48.0, height: 48.0)
            let colors: [CGColor]
            let iconName: String
            let iconInset: CGFloat
            let rotation: CGFloat
            switch component.kind {
            case .transfer:
                colors = [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor]
                iconName = "Wallet/CardGram"
                iconInset = 4.0
                rotation = 0.0
            case .incoming:
                colors = [UIColor(rgb: 0x32b83b).cgColor, UIColor(rgb: 0x87d93b).cgColor]
                iconName = "Wallet/TransactionArrow"
                iconInset = 8.0
                rotation = .pi
            case .outgoing:
                colors = [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor]
                iconName = "Wallet/TransactionArrow"
                iconInset = 8.0
                rotation = 0.0
            case .contract:
                colors = [UIColor(rgb: 0x9aa0ac).cgColor, UIColor(rgb: 0xb8bdc7).cgColor]
                iconName = "Chat List/Tabs/IconSettings"
                iconInset = 8.0
                rotation = 0.0
            }

            self.backgroundView.image = generateGradientFilledCircleImage(
                diameter: size.width,
                colors: colors as NSArray,
                direction: .vertical
            )
            self.iconView.image = generateTintedImage(
                image: UIImage(bundleImageName: iconName),
                color: .white
            )
            self.iconView.transform = CGAffineTransform(rotationAngle: rotation)
            self.backgroundView.frame = CGRect(origin: .zero, size: size)
            self.iconView.frame = CGRect(origin: .zero, size: size).insetBy(dx: iconInset, dy: iconInset)
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
        return view.update(component: self)
    }
}

private final class WalletTransferPreviewCommentComponent: Component {
    let text: String
    let presentationData: PresentationData
    let incoming: Bool
    let fillColor: UIColor
    let textColor: UIColor

    init(
        text: String,
        presentationData: PresentationData,
        incoming: Bool,
        fillColor: UIColor,
        textColor: UIColor
    ) {
        self.text = text
        self.presentationData = presentationData
        self.incoming = incoming
        self.fillColor = fillColor
        self.textColor = textColor
    }

    static func ==(lhs: WalletTransferPreviewCommentComponent, rhs: WalletTransferPreviewCommentComponent) -> Bool {
        return lhs.text == rhs.text
            && lhs.presentationData == rhs.presentationData
            && lhs.incoming == rhs.incoming
            && lhs.fillColor == rhs.fillColor
            && lhs.textColor == rhs.textColor
    }

    final class View: UIView {
        private let backgroundView = UIImageView()
        private let text = ComponentView<Empty>()

        private var cachedBubbleImage: (
            presentationData: PresentationData,
            incoming: Bool,
            fillColor: UIColor,
            image: UIImage
        )?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.isUserInteractionEnabled = false
            self.backgroundView.contentMode = .scaleToFill
            self.addSubview(self.backgroundView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func bubbleImage(
            presentationData: PresentationData,
            incoming: Bool,
            fillColor: UIColor
        ) -> UIImage {
            if let cachedBubbleImage = self.cachedBubbleImage,
               cachedBubbleImage.presentationData == presentationData,
               cachedBubbleImage.incoming == incoming,
               cachedBubbleImage.fillColor == fillColor {
                return cachedBubbleImage.image
            }
            let image = messageBubbleImage(
                maxCornerRadius: presentationData.chatBubbleCorners.mainRadius,
                minCornerRadius: presentationData.chatBubbleCorners.auxiliaryRadius,
                incoming: incoming,
                fillColor: fillColor,
                strokeColor: .clear,
                neighbors: .none,
                shadow: nil,
                wallpaper: presentationData.chatWallpaper,
                knockout: false
            )
            self.cachedBubbleImage = (presentationData, incoming, fillColor, image)
            return image
        }

        func update(
            component: WalletTransferPreviewCommentComponent,
            state: EmptyComponentState,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let horizontalInset: CGFloat = 17.0
            let verticalInset: CGFloat = 7.0
            let bubbleImage = self.bubbleImage(
                presentationData: component.presentationData,
                incoming: component.incoming,
                fillColor: component.fillColor
            )
            self.text.parentState = state
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.text,
                        font: Font.regular(15.0),
                        textColor: component.textColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - horizontalInset * 2.0),
                    height: 1000.0
                )
            )
            let size = CGSize(
                width: min(availableSize.width, textSize.width + horizontalInset * 2.0),
                height: max(textSize.height + verticalInset * 2.0, bubbleImage.size.height)
            )
            self.backgroundView.image = bubbleImage
            transition.setFrame(
                view: self.backgroundView,
                frame: CGRect(
                    x: component.incoming ? -3.0 : 3.0,
                    y: 0.0,
                    width: size.width,
                    height: size.height
                )
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(
                    view: textView,
                    frame: CGRect(
                        x: floorToScreenPixels((size.width - textSize.width) * 0.5),
                        y: floorToScreenPixels((size.height - textSize.height) * 0.5),
                        width: textSize.width,
                        height: textSize.height
                    )
                )
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
        return view.update(
            component: self,
            state: state,
            availableSize: availableSize,
            transition: transition
        )
    }
}

final class WalletTransferPreviewComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let request: WalletContext.TonConnectTransferRequest
    let walletState: WalletContext.State?
    let bottomInset: CGFloat

    init(
        context: AccountContext,
        request: WalletContext.TonConnectTransferRequest,
        walletState: WalletContext.State?,
        bottomInset: CGFloat
    ) {
        self.context = context
        self.request = request
        self.walletState = walletState
        self.bottomInset = bottomInset
    }

    static func ==(lhs: WalletTransferPreviewComponent, rhs: WalletTransferPreviewComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.request == rhs.request
            && lhs.walletState == rhs.walletState
            && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private let transferSection = ComponentView<Empty>()
        private let previewSection = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func text(
            _ value: String,
            font: UIFont,
            color: UIColor,
            maximumNumberOfLines: Int = 1
        ) -> AnyComponent<Empty> {
            return AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: value, font: font, textColor: color)),
                maximumNumberOfLines: maximumNumberOfLines
            ))
        }

        private func trailingContent(
            item: WalletContext.TonConnectTransferRequest.PreviewItem,
            theme: PresentationTheme,
            dateTimeFormat: PresentationDateTimeFormat
        ) -> AnyComponent<Empty>? {
            guard let amount = item.amount, let direction = item.direction else {
                return nil
            }
            let signedAmount: Int64
            let showPlus: Bool
            let color: UIColor
            switch direction {
            case .incoming:
                signedAmount = amount
                showPlus = true
                color = theme.list.itemDisclosureActions.constructive.fillColor
            case .outgoing:
                signedAmount = -amount
                showPlus = false
                color = theme.list.itemPrimaryTextColor
            }
            let amountText = formatTonAmountText(
                signedAmount,
                dateTimeFormat: dateTimeFormat,
                showPlus: showPlus,
                maxDecimalPositions: 3
            )
            return AnyComponent(HStack<Empty>([
                AnyComponentWithIdentity(
                    id: "amount",
                    component: self.text(amountText, font: Font.semibold(15.0), color: color)
                ),
                AnyComponentWithIdentity(
                    id: "icon",
                    component: AnyComponent(BundleIconComponent(
                        name: "Wallet/TransactionGram",
                        tintColor: nil,
                        maxSize: CGSize(width: 18.0, height: 18.0)
                    ))
                )
            ], spacing: 2.0))
        }

        private func itemContent(
            component: WalletTransferPreviewComponent,
            item: WalletContext.TonConnectTransferRequest.PreviewItem,
            theme: PresentationTheme,
            environment: EnvironmentType
        ) -> WalletTransactionItemComponent.Content {
            let title: String
            let subtitle: String?
            let iconKind: WalletTransferPreviewIconComponent.Kind
            switch item.kind {
            case .transfer:
                switch item.direction {
                case .some(.outgoing):
                    title = walletTransferShortAddress(item.address ?? component.request.recipient)
                    //TODO:localize
                    subtitle = "Withdraw"
                    iconKind = .outgoing
                case .some(.incoming):
                    title = item.address.map(walletTransferShortAddress) ?? "Transfer"
                    //TODO:localize
                    subtitle = "Deposit"
                    iconKind = .incoming
                case nil:
                    //TODO:localize
                    title = "Transfer"
                    subtitle = item.address.map(walletTransferShortAddress)
                    iconKind = .transfer
                }
            case .callContract:
                //TODO:localize
                title = "Call Contract"
                subtitle = nil
                iconKind = .contract
            case .deployContract:
                //TODO:localize
                title = "Deploy Contract"
                subtitle = nil
                iconKind = .contract
            case .excess:
                //TODO:localize
                title = "Excess"
                subtitle = nil
                iconKind = .incoming
            case .unknown:
                //TODO:localize
                title = "Unknown Operation"
                subtitle = nil
                iconKind = .contract
            }

            let comment = item.comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            let additionalContent: AnyComponent<Empty>?
            if let comment, !comment.isEmpty {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                additionalContent = AnyComponent(WalletTransferPreviewCommentComponent(
                    text: comment,
                    presentationData: presentationData,
                    incoming: item.direction == .incoming,
                    fillColor: theme.list.itemInputField.backgroundColor,
                    textColor: theme.actionSheet.primaryTextColor
                ))
            } else {
                additionalContent = nil
            }

            return WalletTransactionItemComponent.Content(
                avatar: AnyComponent(WalletTransferPreviewIconComponent(kind: iconKind)),
                title: self.text(title, font: Font.semibold(17.0), color: theme.list.itemPrimaryTextColor),
                subtitle: subtitle.map {
                    self.text($0, font: Font.regular(15.0), color: theme.list.itemPrimaryTextColor)
                },
                trailingContent: self.trailingContent(
                    item: item,
                    theme: theme,
                    dateTimeFormat: environment.dateTimeFormat
                ),
                additionalContent: additionalContent,
                minimumHeight: 68.0,
                insets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                spacing: 12.0
            )
        }

        private func listItem(
            component: WalletTransferPreviewComponent,
            content: WalletTransactionItemComponent.Content,
            theme: PresentationTheme,
            environment: EnvironmentType
        ) -> AnyComponent<Empty> {
            return AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(WalletTransactionItemComponent(
                    context: component.context,
                    theme: theme,
                    strings: environment.strings,
                    dateTimeFormat: environment.dateTimeFormat,
                    content: content
                )),
                contentInsets: .zero,
                separatorInset: 76.0,
                accessory: nil,
                action: nil,
                highlighting: .disabled
            ))
        }

        func update(
            component: WalletTransferPreviewComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let theme = environment.theme.withModalBlocksBackground()
            transition.setBackgroundColor(view: self, color: environment.theme.list.modalBlocksBackgroundColor)
            let safeWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right
            )
            let contentWidth = min(382.0, max(1.0, safeWidth - 48.0))
            let contentX = environment.safeInsets.left + floor((safeWidth - contentWidth) * 0.5)
            let sectionTitleColor = theme.list.itemSecondaryTextColor

            var contentHeight: CGFloat = 94.0
            let formattedAmount = formatTonAmountText(
                component.request.amount,
                dateTimeFormat: environment.dateTimeFormat,
                maxDecimalPositions: 9
            )
            let transferContent = WalletTransactionItemComponent.Content(
                avatar: AnyComponent(WalletTransferPreviewIconComponent(kind: .transfer)),
                title: self.text(
                    "\(formattedAmount) Grams",
                    font: Font.semibold(17.0),
                    color: theme.list.itemPrimaryTextColor
                ),
                subtitle: self.text(
                    "to \(walletTransferShortAddress(component.request.recipient))",
                    font: Font.regular(15.0),
                    color: theme.list.itemPrimaryTextColor
                ),
                minimumHeight: 68.0,
                insets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                spacing: 12.0
            )
            self.transferSection.parentState = state
            let transferSectionSize = self.transferSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: self.text("TRANSFER", font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), color: sectionTitleColor),
                    footer: nil,
                    items: [AnyComponentWithIdentity(
                        id: "transfer",
                        component: self.listItem(
                            component: component,
                            content: transferContent,
                            theme: theme,
                            environment: environment
                        )
                    )]
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let transferSectionView = self.transferSection.view {
                if transferSectionView.superview == nil {
                    self.addSubview(transferSectionView)
                }
                transition.setFrame(
                    view: transferSectionView,
                    frame: CGRect(
                        x: contentX,
                        y: contentHeight,
                        width: transferSectionSize.width,
                        height: transferSectionSize.height
                    )
                )
            }
            contentHeight += transferSectionSize.height + 28.0

            let displayItems: [WalletContext.TonConnectTransferRequest.PreviewItem]
            if component.request.previewItems.isEmpty {
                displayItems = [WalletContext.TonConnectTransferRequest.PreviewItem(
                    id: "empty",
                    kind: .unknown,
                    direction: nil,
                    address: nil,
                    amount: nil,
                    comment: nil
                )]
            } else {
                displayItems = component.request.previewItems
            }

            let formattedFee = formatTonAmountText(
                component.request.fee,
                dateTimeFormat: environment.dateTimeFormat,
                maxDecimalPositions: 9
            )
            let feeText: String
            let fiatCurrency = component.walletState?.fiat.selectedCurrency ?? .usd
            if let fiatRate = component.walletState?.fiat.selectedRate {
                let fiatValue = Double(component.request.fee) / 1_000_000_000.0 * fiatRate.unitsPerGram
                let fiatText: String
                if fiatValue > 0.0 && fiatValue < 0.01 {
                    fiatText = "<\(fiatCurrency.symbol)0\(environment.dateTimeFormat.decimalSeparator)01"
                } else {
                    fiatText = formatTonFiatValue(
                        component.request.fee,
                        divide: true,
                        rate: fiatRate.unitsPerGram,
                        currencySymbol: fiatCurrency.symbol,
                        maxDecimalPositions: 2,
                        dateTimeFormat: environment.dateTimeFormat
                    )
                }
                feeText = "Fee: \(formattedFee) Gram (\(fiatText))."
            } else {
                feeText = "Fee: \(formattedFee) Gram."
            }

            let previewItems = displayItems.map { item in
                return AnyComponentWithIdentity<Empty>(
                    id: item.id,
                    component: self.listItem(
                        component: component,
                        content: self.itemContent(
                            component: component,
                            item: item,
                            theme: theme,
                            environment: environment
                        ),
                        theme: theme,
                        environment: environment
                    )
                )
            }
            self.previewSection.parentState = state
            let previewSectionSize = self.previewSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: self.text("PREVIEW", font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize), color: sectionTitleColor),
                    footer: self.text(
                        feeText,
                        font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                        color: theme.list.itemSecondaryTextColor,
                        maximumNumberOfLines: 0
                    ),
                    items: previewItems
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let previewSectionView = self.previewSection.view {
                if previewSectionView.superview == nil {
                    self.addSubview(previewSectionView)
                }
                transition.setFrame(
                    view: previewSectionView,
                    frame: CGRect(
                        x: contentX,
                        y: contentHeight,
                        width: previewSectionSize.width,
                        height: previewSectionSize.height
                    )
                )
            }
            contentHeight += previewSectionSize.height + 8.0 + component.bottomInset

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

private func walletTransferShortAddress(_ address: String) -> String {
    let edgeLength = 4
    guard address.count > edgeLength * 2 else {
        return address
    }
    return "\(address.prefix(edgeLength))...\(address.suffix(edgeLength))"
}
