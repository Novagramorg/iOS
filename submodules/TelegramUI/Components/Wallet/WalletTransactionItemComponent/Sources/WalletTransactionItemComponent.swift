import Foundation
import UIKit
import Display
import ActivityIndicator
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import StarsAvatarComponent
import WalletContext
import WalletCollectibleImageComponent

public final class WalletTransactionItemComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let transaction: WalletContext.Transaction

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        transaction: WalletContext.Transaction
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.transaction = transaction
    }

    public static func ==(lhs: WalletTransactionItemComponent, rhs: WalletTransactionItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.transaction != rhs.transaction {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarContainer = UIView()
        private let avatarMask = CAShapeLayer()
        private let avatar = ComponentView<Empty>()
        private let activityIndicatorBackground = UIView()
        private var activityIndicator: ActivityIndicator?
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let date = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let amountIcon = ComponentView<Empty>()
        private let collectibleBackground = ComponentView<Empty>()
        private let collectibleImage = ComponentView<Empty>()
        private let collectibleTitle = ComponentView<Empty>()
        private let collectibleSubtitle = ComponentView<Empty>()

        private var component: WalletTransactionItemComponent?

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.avatarContainer.isUserInteractionEnabled = false
            self.activityIndicatorBackground.isUserInteractionEnabled = false
            self.activityIndicatorBackground.isHidden = true
            self.addSubview(self.avatarContainer)
            self.addSubview(self.activityIndicatorBackground)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransactionItemComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let subtitleText: String
            let formattedAmountValue: Int64
            let showAmountPlus: Bool
            var amountColor: UIColor
            var amountIconColor: UIColor?
            let avatarPeer: StarsAvatarComponent.Peer?
            switch component.transaction.direction {
            case .incoming:
                if component.transaction.collectible != nil {
                    //TODO:localize
                    subtitleText = "Incoming collectible"
                } else {
                    //TODO:localize
                    subtitleText = "Deposit"
                }
                formattedAmountValue = component.transaction.amount
                showAmountPlus = true
                if component.transaction.currency == .usdt {
                    amountColor = UIColor(rgb: 0x0B9696)
                } else {
                    amountColor = component.theme.list.itemDisclosureActions.constructive.fillColor
                }
                amountIconColor = component.transaction.collectible != nil ? amountColor : nil
                avatarPeer = .transaction(.incoming)
            case .outgoing:
                if component.transaction.collectible != nil {
                    //TODO:localize
                    subtitleText = "Outgoing collectible"
                } else {
                    //TODO:localize
                    subtitleText = "Withdrawal"
                }
                formattedAmountValue = -component.transaction.amount
                showAmountPlus = false
                amountColor = component.theme.list.itemPrimaryTextColor
                amountIconColor = component.transaction.collectible != nil
                    ? component.theme.list.itemSecondaryTextColor
                    : nil
                avatarPeer = .transaction(.outgoing)
            case .unknown:
                subtitleText = ""
                formattedAmountValue = component.transaction.amount
                showAmountPlus = false
                amountColor = component.theme.list.itemPrimaryTextColor
                amountIconColor = nil
                avatarPeer = nil
            }

            let isPending = component.transaction.status == .pending
                && component.transaction.collectible == nil
            if isPending {
                amountColor = component.theme.list.itemSecondaryTextColor
                amountIconColor = component.theme.list.itemSecondaryTextColor
            }

            let avatarSize = CGSize(width: 40.0, height: 40.0)
            let avatarFrame = CGRect(origin: CGPoint(x: -4.0, y: 2.0), size: avatarSize)
            if let avatarPeer {
                self.avatarContainer.isHidden = false
                self.avatar.parentState = state
                let _ = self.avatar.update(
                    transition: transition,
                    component: AnyComponent(StarsAvatarComponent(
                        context: component.context,
                        theme: component.theme,
                        peer: avatarPeer,
                        photo: nil,
                        media: [],
                        gift: nil,
                        backgroundColor: .clear,
                        size: avatarSize
                    )),
                    environment: {},
                    containerSize: avatarSize
                )
                if let avatarView = self.avatar.view {
                    if avatarView.superview == nil {
                        self.avatarContainer.addSubview(avatarView)
                    }
                    transition.setFrame(view: self.avatarContainer, frame: avatarFrame)
                    transition.setFrame(
                        view: avatarView,
                        frame: CGRect(origin: CGPoint(), size: avatarSize)
                    )
                }
            } else {
                self.avatarContainer.isHidden = true
            }

            if isPending, avatarPeer != nil {
                let backgroundDiameter: CGFloat = 14.0
                let indicatorDiameter: CGFloat = 9.0
                let circlePoint = CGPoint(
                    x: avatarSize.width / 2.0 + cos(CGFloat.pi / 4.0) * avatarSize.width / 2.0 + 1.0,
                    y: avatarSize.height / 2.0 - sin(CGFloat.pi / 4.0) * avatarSize.height / 2.0 - 1.0
                )
                let backgroundFrame = CGRect(
                    x: circlePoint.x - backgroundDiameter / 2.0,
                    y: circlePoint.y - backgroundDiameter / 2.0,
                    width: backgroundDiameter,
                    height: backgroundDiameter
                )
                let indicatorFrame = CGRect(
                    x: backgroundFrame.midX - indicatorDiameter / 2.0,
                    y: backgroundFrame.midY - indicatorDiameter / 2.0,
                    width: indicatorDiameter,
                    height: indicatorDiameter
                )

                self.avatarMask.frame = CGRect(origin: CGPoint(), size: avatarSize)
                self.avatarMask.fillRule = .evenOdd
                let maskPath = UIBezierPath(rect: self.avatarMask.bounds)
                maskPath.append(UIBezierPath(
                    ovalIn: backgroundFrame.insetBy(dx: -2.0, dy: -2.0)
                ))
                self.avatarMask.path = maskPath.cgPath
                self.avatarContainer.layer.mask = self.avatarMask

                self.activityIndicatorBackground.isHidden = false
                self.activityIndicatorBackground.backgroundColor = component.theme.list.itemSecondaryTextColor
                self.activityIndicatorBackground.layer.cornerRadius = backgroundDiameter / 2.0
                self.activityIndicatorBackground.frame = backgroundFrame.offsetBy(
                    dx: avatarFrame.minX,
                    dy: avatarFrame.minY
                )

                let activityIndicator: ActivityIndicator
                if let current = self.activityIndicator {
                    activityIndicator = current
                } else {
                    activityIndicator = ActivityIndicator(
                        type: .custom(
                            .white,
                            indicatorDiameter,
                            1.5,
                            true
                        ),
                        speed: .slow
                    )
                    activityIndicator.isUserInteractionEnabled = false
                    self.activityIndicator = activityIndicator
                    self.addSubview(activityIndicator.view)
                }
                activityIndicator.type = .custom(
                    .white,
                    indicatorDiameter,
                    1.5,
                    true
                )
                activityIndicator.frame = indicatorFrame.offsetBy(
                    dx: avatarFrame.minX,
                    dy: avatarFrame.minY
                )
            } else {
                self.avatarContainer.layer.mask = nil
                self.activityIndicatorBackground.isHidden = true
                if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    activityIndicator.view.removeFromSuperview()
                }
            }

            let textOriginX: CGFloat = 46.0
            let textAvailableWidth = max(0.0, availableSize.width - textOriginX)

            let amountText: String
            let amountIconName: String
            if component.transaction.collectible != nil {
                amountText = formattedAmountValue > 0 ? "+1 item" : "-1 item"
                amountIconName = "Wallet/TransactionCollectible"
            } else if component.transaction.currency == .ton {
                amountText = formatTonAmountText(
                    formattedAmountValue,
                    dateTimeFormat: component.dateTimeFormat,
                    showPlus: showAmountPlus,
                    maxDecimalPositions: 3
                )
                amountIconName = "Wallet/TransactionGram"
            } else {
                amountText = formatWalletTokenAmountText(
                    formattedAmountValue,
                    decimalDigits: 6,
                    dateTimeFormat: component.dateTimeFormat,
                    showPlus: showAmountPlus,
                    maxDecimalPositions: 2
                )
                amountIconName = "Wallet/TransactionUsdt"
            }
            let amountAttributedText = tonAmountAttributedString(
                amountText,
                integralFont: Font.semibold(15.0),
                fractionalFont: Font.semibold(12.0),
                color: amountColor,
                decimalSeparator: component.dateTimeFormat.decimalSeparator
            )
            let amountIconSize = self.amountIcon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: amountIconName,
                    tintColor: amountIconColor,
                    maxSize: CGSize(width: 18.0, height: 18.0)
                )),
                environment: {},
                containerSize: CGSize(width: 18.0, height: 18.0)
            )
            let amountSize = self.amount.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(amountAttributedText),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, textAvailableWidth - amountIconSize.width - 3.0), height: 100.0)
            )

            let amountSpacing: CGFloat = 1.0
            let amountContentWidth = amountSize.width + amountSpacing + amountIconSize.width
            let titleToAmountSpacing: CGFloat = 12.0
            let titleAvailableWidth = max(0.0, textAvailableWidth - amountContentWidth - titleToAmountSpacing)

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.transaction.counterpartyName
                            ?? walletTransactionCounterparty(component.transaction.counterparty),
                        font: Font.semibold(17.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
            )
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: subtitleText,
                        font: Font.regular(15.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            let dateComponents = getDateTimeComponents(timestamp: component.transaction.timestamp)
            let compactDate = stringForMediumCompactDate(
                timestamp: component.transaction.timestamp,
                strings: component.strings,
                dateTimeFormat: component.dateTimeFormat,
                withTime: false
            )
            let compactTime = stringForShortTimestamp(
                hours: dateComponents.hour,
                minutes: dateComponents.minutes,
                dateTimeFormat: component.dateTimeFormat
            )
            let dateText = component.strings.Time_MediumDate(compactDate, compactTime).string
            let dateSize = self.date.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: dateText,
                        font: Font.regular(14.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            var contentHeight: CGFloat = 2.0
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: titleSize)
                )
            }
            contentHeight += titleSize.height
            contentHeight += 2.0

            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(
                    view: subtitleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: subtitleSize)
                )
            }
            contentHeight += subtitleSize.height
            contentHeight += 4.0

            if let dateView = self.date.view {
                if dateView.superview == nil {
                    self.addSubview(dateView)
                }
                transition.setFrame(
                    view: dateView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: dateSize)
                )
            }
            contentHeight += dateSize.height
            contentHeight += 1.0

            if let collectible = component.transaction.collectible {
                contentHeight += 8.0
                let collectibleImageSize = CGSize(width: 40.0, height: 40.0)
                let collectibleTextOriginX: CGFloat = 50.0
                let collectibleTextAvailableWidth = max(0.0, textAvailableWidth - collectibleTextOriginX - 8.0)
                let collectibleTitleSize = self.collectibleTitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: collectible.name,
                            font: Font.semibold(14.0),
                            textColor: component.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: collectibleTextAvailableWidth, height: 100.0)
                )
                let collectibleTypeText: String
                switch collectible.kind {
                case .gift:
                    //TODO:localize
                    collectibleTypeText = "Collectible Gift"
                case .username:
                    //TODO:localize
                    collectibleTypeText = "Username"
                case .anonymousNumber:
                    //TODO:localize
                    collectibleTypeText = "Anonymous Number"
                }
                let collectibleSubtitleSize = self.collectibleSubtitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: collectibleTypeText,
                            font: Font.regular(13.0),
                            textColor: component.theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: collectibleTextAvailableWidth, height: 100.0)
                )
                let collectibleContentWidth = min(
                    textAvailableWidth,
                    collectibleTextOriginX + max(collectibleTitleSize.width, collectibleSubtitleSize.width) + 10.0
                )
                let collectibleFrame = CGRect(
                    x: textOriginX,
                    y: contentHeight,
                    width: collectibleContentWidth,
                    height: 44.0
                )
                let _ = self.collectibleBackground.update(
                    transition: transition,
                    component: AnyComponent(RoundedRectangle(
                        color: component.theme.list.itemSecondaryTextColor.withAlphaComponent(0.08),
                        cornerRadius: 10.0
                    )),
                    environment: {},
                    containerSize: collectibleFrame.size
                )
                if let collectibleBackgroundView = self.collectibleBackground.view {
                    if collectibleBackgroundView.superview == nil {
                        collectibleBackgroundView.isUserInteractionEnabled = false
                        self.addSubview(collectibleBackgroundView)
                    }
                    collectibleBackgroundView.isHidden = false
                    transition.setFrame(view: collectibleBackgroundView, frame: collectibleFrame)
                }

                let collectibleImageFrame = CGRect(
                    origin: CGPoint(x: collectibleFrame.minX + 2.0, y: collectibleFrame.minY + 2.0),
                    size: collectibleImageSize
                )
                let _ = self.collectibleImage.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleImageComponent(
                        context: component.context,
                        imageUrl: collectible.imageUrl,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        cornerRadius: 8.0
                    )),
                    environment: {},
                    containerSize: collectibleImageSize
                )
                if let collectibleImageView = self.collectibleImage.view {
                    if collectibleImageView.superview == nil {
                        collectibleImageView.isUserInteractionEnabled = false
                        self.addSubview(collectibleImageView)
                    }
                    collectibleImageView.isHidden = false
                    transition.setFrame(view: collectibleImageView, frame: collectibleImageFrame)
                }

                if let collectibleTitleView = self.collectibleTitle.view {
                    collectibleTitleView.isHidden = false
                    if collectibleTitleView.superview == nil {
                        self.addSubview(collectibleTitleView)
                    }
                    transition.setFrame(
                        view: collectibleTitleView,
                        frame: CGRect(
                            x: collectibleFrame.minX + collectibleTextOriginX,
                            y: collectibleFrame.minY + 5.0 + UIScreenPixel,
                            width: collectibleTitleSize.width,
                            height: collectibleTitleSize.height
                        )
                    )
                }
                if let collectibleSubtitleView = self.collectibleSubtitle.view {
                    collectibleSubtitleView.isHidden = false
                    if collectibleSubtitleView.superview == nil {
                        self.addSubview(collectibleSubtitleView)
                    }
                    transition.setFrame(
                        view: collectibleSubtitleView,
                        frame: CGRect(
                            x: collectibleFrame.minX + collectibleTextOriginX,
                            y: collectibleFrame.minY + 23.0,
                            width: collectibleSubtitleSize.width,
                            height: collectibleSubtitleSize.height
                        )
                    )
                }
                contentHeight += collectibleFrame.height
                contentHeight += 1.0
            } else {
                self.collectibleBackground.view?.isHidden = true
                if let collectibleImageView = self.collectibleImage.view {
                    let _ = self.collectibleImage.update(
                        transition: .immediate,
                        component: AnyComponent(WalletCollectibleImageComponent(
                            context: component.context,
                            imageUrl: nil,
                            placeholderColor: component.theme.list.mediaPlaceholderColor,
                            cornerRadius: 8.0
                        )),
                        environment: {},
                        containerSize: CGSize(width: 40.0, height: 40.0)
                    )
                    collectibleImageView.isHidden = true
                }
                self.collectibleTitle.view?.isHidden = true
                self.collectibleSubtitle.view?.isHidden = true
            }

            let amountOriginX = max(0.0, availableSize.width - amountContentWidth)
            let amountOriginY = floor((titleSize.height - amountSize.height) * 0.5)
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    self.addSubview(amountView)
                }
                transition.setFrame(
                    view: amountView,
                    frame: CGRect(origin: CGPoint(x: amountOriginX, y: amountOriginY), size: amountSize)
                )
            }
            if let amountIconView = self.amountIcon.view {
                if amountIconView.superview == nil {
                    self.addSubview(amountIconView)
                }
                transition.setFrame(
                    view: amountIconView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: amountOriginX + amountSize.width + amountSpacing,
                            y: floorToScreenPixels(amountOriginY + (amountSize.height - amountIconSize.height) * 0.5) + UIScreenPixel
                        ),
                        size: amountIconSize
                    )
                )
            }

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
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

private func walletTransactionCounterparty(_ address: String?) -> String {
    guard let address, !address.isEmpty else {
        //TODO:localize
        let unknownAddress = "Unknown Address"
        return unknownAddress
    }

    let edgeLength = 4
    guard address.count > edgeLength * 2 else {
        return address
    }

    return "\(address.prefix(edgeLength))...\(address.suffix(edgeLength))"
}

private func formatWalletTokenAmountText(
    _ value: Int64,
    decimalDigits: Int,
    dateTimeFormat: PresentationDateTimeFormat,
    showPlus: Bool,
    maxDecimalPositions: Int
) -> String {
    var digits = String(value.magnitude)
    while digits.count <= decimalDigits {
        digits.insert("0", at: digits.startIndex)
    }

    let fractionStart = digits.index(digits.endIndex, offsetBy: -decimalDigits)
    var integralPart = String(digits[..<fractionStart])
    var fractionalPart = String(digits[fractionStart...])
    while fractionalPart.last == "0" {
        fractionalPart.removeLast()
    }
    if fractionalPart.count > maxDecimalPositions {
        fractionalPart = String(fractionalPart.prefix(maxDecimalPositions))
    }

    if let integralValue = Int32(integralPart) {
        integralPart = presentationStringsFormattedNumber(integralValue, dateTimeFormat.groupingSeparator)
    }

    var result = integralPart
    if !fractionalPart.isEmpty {
        result.append(dateTimeFormat.decimalSeparator)
        result.append(fractionalPart)
    }
    if value < 0 {
        result.insert("-", at: result.startIndex)
    } else if showPlus {
        result.insert("+", at: result.startIndex)
    }
    return result
}
