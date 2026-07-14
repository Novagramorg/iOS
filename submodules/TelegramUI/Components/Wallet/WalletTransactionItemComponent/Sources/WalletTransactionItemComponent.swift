import Foundation
import UIKit
import Display
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import StarsAvatarComponent
import WalletContext

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
        private let avatar = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let date = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let amountIcon = ComponentView<Empty>()

        private var component: WalletTransactionItemComponent?

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
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
            let amountColor: UIColor
            let avatarPeer: StarsAvatarComponent.Peer?
            switch component.transaction.direction {
            case .incoming:
                //TODO:localize
                subtitleText = "Deposit"
                formattedAmountValue = component.transaction.amount
                showAmountPlus = true
                amountColor = component.theme.list.itemDisclosureActions.constructive.fillColor
                avatarPeer = .transaction(.incoming)
            case .outgoing:
                //TODO:localize
                subtitleText = "Withdrawal"
                formattedAmountValue = -component.transaction.amount
                showAmountPlus = false
                amountColor = component.theme.list.itemPrimaryTextColor
                avatarPeer = .transaction(.outgoing)
            case .unknown:
                subtitleText = ""
                formattedAmountValue = component.transaction.amount
                showAmountPlus = false
                amountColor = component.theme.list.itemPrimaryTextColor
                avatarPeer = nil
            }

            let avatarSize = CGSize(width: 40.0, height: 40.0)
            if let avatarPeer {
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
                        self.addSubview(avatarView)
                    }
                    transition.setFrame(
                        view: avatarView,
                        frame: CGRect(origin: CGPoint(x: -4.0, y: 2.0), size: avatarSize)
                    )
                }
            }

            let textOriginX: CGFloat = 46.0
            let textAvailableWidth = max(0.0, availableSize.width - textOriginX)

            let amountText = formatTonAmountText(
                formattedAmountValue,
                dateTimeFormat: component.dateTimeFormat,
                showPlus: showAmountPlus,
                maxDecimalPositions: 2
            )
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
                    name: "Ads/TonMedium",
                    tintColor: UIColor(rgb: 0x30a1f5),
                    maxSize: CGSize(width: 13.0, height: 13.0)
                )),
                environment: {},
                containerSize: CGSize(width: 13.0, height: 13.0)
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

            let amountSpacing: CGFloat = 3.0
            let amountContentWidth = amountSize.width + amountSpacing + amountIconSize.width
            let titleToAmountSpacing: CGFloat = 12.0
            let titleAvailableWidth = max(0.0, textAvailableWidth - amountContentWidth - titleToAmountSpacing)

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: walletTransactionCounterparty(component.transaction.counterparty),
                        font: Font.medium(17.0),
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
                            y: floor(amountOriginY + (amountSize.height - amountIconSize.height) * 0.5)
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

    let edgeLength = 8
    guard address.count > edgeLength * 2 else {
        return address
    }

    return "\(address.prefix(edgeLength))...\(address.suffix(edgeLength))"
}
