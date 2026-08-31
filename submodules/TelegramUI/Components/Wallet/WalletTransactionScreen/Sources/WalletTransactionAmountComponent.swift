import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import ShimmeringMask
import WalletContext

final class WalletTransactionAmountComponent: Component {
    let theme: PresentationTheme
    let dateTimeFormat: PresentationDateTimeFormat
    let amount: Int64
    let direction: WalletContext.Transaction.Direction
    let currency: WalletContext.Transaction.Currency
    let pending: Bool

    init(
        theme: PresentationTheme,
        dateTimeFormat: PresentationDateTimeFormat,
        amount: Int64,
        direction: WalletContext.Transaction.Direction,
        currency: WalletContext.Transaction.Currency,
        pending: Bool
    ) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.amount = amount
        self.direction = direction
        self.currency = currency
        self.pending = pending
    }

    static func ==(lhs: WalletTransactionAmountComponent, rhs: WalletTransactionAmountComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.amount != rhs.amount {
            return false
        }
        if lhs.direction != rhs.direction {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.pending != rhs.pending {
            return false
        }
        return true
    }

    final class View: UIView {
        private let contentContainer = UIView()
        private let shimmerView = ShimmeringMaskView(peakAlpha: 0.3, duration: 1.0)
        private let amount = ComponentView<Empty>()
        private let iconView = UIImageView()
        private var currentIconName: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.contentContainer.isUserInteractionEnabled = false
            self.shimmerView.isUserInteractionEnabled = false
            self.iconView.isUserInteractionEnabled = false
            self.iconView.contentMode = .scaleAspectFit
            self.addSubview(self.contentContainer)
            self.contentContainer.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransactionAmountComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let formattedAmountText: String
            var normalizedAmount: Int64 = component.amount
            if case .outgoing = component.direction, normalizedAmount > 0 {
                normalizedAmount *= -1
            }
            let iconName: String
            switch component.currency {
            case .ton:
                formattedAmountText = formatTonAmountText(
                    normalizedAmount,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 3
                )
                iconName = "Wallet/TransactionGramLarge"
            case .usdt:
                formattedAmountText = formatWalletTransactionTokenAmountText(
                    normalizedAmount,
                    decimalDigits: 6,
                    dateTimeFormat: component.dateTimeFormat
                )
                iconName = "Wallet/TransactionUsdtLarge"
            }
            if self.currentIconName != iconName {
                self.currentIconName = iconName
                self.iconView.image = UIImage(bundleImageName: iconName)?.withRenderingMode(.alwaysOriginal)
            }

            let amountText: String
            let regularTextColor: UIColor
            switch component.direction {
            case .incoming:
                amountText = "+\(formattedAmountText)"
                if component.currency == .usdt {
                    regularTextColor = UIColor(rgb: 0x0B9696)
                } else {
                    regularTextColor = component.theme.list.itemDisclosureActions.constructive.fillColor
                }
            case .outgoing:
                amountText = "\(formattedAmountText)".replacingOccurrences(of: "-", with: "−")
                regularTextColor = component.theme.actionSheet.primaryTextColor
            case .unknown:
                amountText = formattedAmountText
                regularTextColor = component.theme.actionSheet.primaryTextColor
            }

            let textColor = component.pending ? component.theme.actionSheet.secondaryTextColor : regularTextColor
            let amountAttributedString = tonAmountAttributedString(
                amountText,
                integralFont: Font.with(size: 48.0, design: .round, weight: .semibold),
                fractionalFont: Font.with(size: 32.0, design: .round, weight: .semibold),
                color: .white,
                decimalSeparator: component.dateTimeFormat.decimalSeparator
            )

            let amountSize = self.amount.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(amountAttributedString),
                    maximumNumberOfLines: 1,
                    tintColor: textColor
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, availableSize.width - 104.0), height: 100.0)
            )
            let iconSize = (self.iconView.image?.size ?? CGSize()).aspectFitted(
                CGSize(width: 44.0, height: 44.0)
            )

            let spacing: CGFloat = 2.0 - UIScreenPixel
            let size = CGSize(
                width: amountSize.width + spacing + iconSize.width,
                height: max(amountSize.height, iconSize.height)
            )
            let bounds = CGRect(origin: .zero, size: size)

            self.contentContainer.frame = bounds
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    self.contentContainer.addSubview(amountView)
                }
                transition.setFrame(
                    view: amountView,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: floor((size.height - amountSize.height) / 2.0)),
                        size: amountSize
                    )
                )
            }
            transition.setAlpha(view: self.iconView, alpha: component.pending ? 0.5 : 1.0)
            transition.setFrame(
                view: self.iconView,
                frame: CGRect(
                    origin: CGPoint(
                        x: amountSize.width + spacing,
                        y: floor((size.height - iconSize.height) / 2.0) + 5.0 + UIScreenPixel
                    ),
                    size: iconSize
                )
            )

            self.shimmerView.frame = bounds
            self.shimmerView.update(
                size: size,
                containerWidth: size.width,
                offsetX: 0.0,
                gradientWidth: 80.0,
                transition: .immediate
            )

            if component.pending {
                if self.shimmerView.superview == nil {
                    self.addSubview(self.shimmerView)
                }
                if self.contentContainer.superview !== self.shimmerView.contentView {
                    self.shimmerView.contentView.addSubview(self.contentContainer)
                }
            } else {
                if self.contentContainer.superview !== self {
                    self.addSubview(self.contentContainer)
                }
                self.shimmerView.removeFromSuperview()
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
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private func formatWalletTransactionTokenAmountText(
    _ value: Int64,
    decimalDigits: Int,
    dateTimeFormat: PresentationDateTimeFormat
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

    if let integralValue = Int32(integralPart) {
        integralPart = presentationStringsFormattedNumber(integralValue, dateTimeFormat.groupingSeparator)
    }

    var result = integralPart
    if !fractionalPart.isEmpty {
        result.append(dateTimeFormat.decimalSeparator)
        result.append(fractionalPart)
    }
    return result
}
