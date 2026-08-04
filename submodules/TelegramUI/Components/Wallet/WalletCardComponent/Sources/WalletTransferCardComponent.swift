import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

public final class WalletTransferCardComponent: Component {
    public let amount: Int64
    public let recipient: String
    public let fiatCurrency: WalletContext.FiatCurrency
    public let fiatRate: WalletContext.FiatRate?
    public let dateTimeFormat: PresentationDateTimeFormat

    public init(
        amount: Int64,
        recipient: String,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat
    ) {
        self.amount = amount
        self.recipient = recipient
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
    }

    public static func ==(lhs: WalletTransferCardComponent, rhs: WalletTransferCardComponent) -> Bool {
        return lhs.amount == rhs.amount
            && lhs.recipient == rhs.recipient
            && lhs.fiatCurrency == rhs.fiatCurrency
            && lhs.fiatRate == rhs.fiatRate
            && lhs.dateTimeFormat == rhs.dateTimeFormat
    }

    public final class View: UIView {
        private let backgroundView = WalletCardBackgroundView()
        private let amountLabel = UILabel()
        private let fiatLabel = UILabel()
        private let addressLabel = UILabel()
        private let ribbonView = UIView()
        private let ribbonLabel = UILabel()

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.clipsToBounds = true
            self.backgroundView.layer.cornerRadius = 20.0
            if #available(iOS 13.0, *) {
                self.layer.cornerCurve = .continuous
            }

            self.amountLabel.textColor = .white
            self.amountLabel.adjustsFontSizeToFitWidth = true
            self.amountLabel.minimumScaleFactor = 0.65
            self.fiatLabel.textColor = UIColor(rgb: 0x6ddcff)
            self.addressLabel.textColor = .white
            self.addressLabel.numberOfLines = 2
            self.addressLabel.adjustsFontSizeToFitWidth = true
            self.addressLabel.minimumScaleFactor = 0.75

            self.ribbonView.backgroundColor = UIColor(rgb: 0x087be5)
            self.ribbonLabel.textColor = .white
            self.ribbonLabel.textAlignment = .center
            self.ribbonLabel.font = Font.semibold(11.0)
            //TODO:localize
            self.ribbonLabel.text = "TRANSFER"
            self.ribbonView.addSubview(self.ribbonLabel)

            self.addSubview(self.backgroundView)
            self.addSubview(self.amountLabel)
            self.addSubview(self.fiatLabel)
            self.addSubview(self.addressLabel)
            //self.addSubview(self.ribbonView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransferCardComponent, availableSize: CGSize) -> CGSize {
            let referenceSize = CGSize(width: 361.0, height: 220.0)
            let width = max(1.0, availableSize.width)
            let scale = width / referenceSize.width
            let size = CGSize(width: width, height: referenceSize.height * scale)

            self.layer.cornerRadius = 20.0 * width / 336.0

            let amountText = formatTonAmountText(
                component.amount,
                dateTimeFormat: component.dateTimeFormat,
                maxDecimalPositions: 9
            )
            //TODO:localize
            self.amountLabel.attributedText = NSAttributedString(
                string: "−\(amountText) GRAM",
                font: Font.with(
                    size: 28.0 * scale,
                    design: .round,
                    weight: .semibold,
                    traits: .monospacedNumbers
                ),
                textColor: .white
            )

            if let fiatRate = component.fiatRate {
                self.fiatLabel.text = formatTonFiatValue(
                    component.amount,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                self.fiatLabel.text = nil
            }
            self.fiatLabel.font = Font.with(
                size: 14.0 * scale,
                design: .round,
                weight: .semibold,
                traits: .monospacedNumbers
            )
            self.addressLabel.attributedText = NSAttributedString(
                string: formattedWalletTransferAddress(component.recipient),
                font: Font.with(size: 13.0 * scale, design: .monospace, weight: .semibold),
                textColor: .white
            )

            let contentInset = 24.0 * scale
            self.amountLabel.frame = CGRect(
                x: contentInset,
                y: 62.0 * scale,
                width: width - contentInset * 2.0,
                height: 38.0 * scale
            )
            self.fiatLabel.frame = CGRect(
                x: contentInset,
                y: 104.0 * scale,
                width: width - contentInset * 2.0,
                height: 20.0 * scale
            )
            self.addressLabel.frame = CGRect(
                x: contentInset,
                y: 157.0 * scale,
                width: width - contentInset * 2.0,
                height: 42.0 * scale
            )

            let ribbonSize = CGSize(width: 104.0 * scale, height: 28.0 * scale)
            self.ribbonView.bounds = CGRect(origin: .zero, size: ribbonSize)
            self.ribbonView.center = CGPoint(x: width - 30.0 * scale, y: 20.0 * scale)
            self.ribbonView.transform = CGAffineTransform(rotationAngle: .pi / 4.0)
            self.ribbonLabel.frame = CGRect(origin: .zero, size: ribbonSize)

            self.backgroundView.frame = CGRect(origin: .zero, size: size)
            self.backgroundView.update(size: size, safeZones: [
                self.amountLabel.frame,
                self.fiatLabel.frame,
                self.addressLabel.frame
            ])
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private func formattedWalletTransferAddress(_ address: String) -> String {
    var groups: [String] = []
    var currentIndex = address.startIndex
    while currentIndex < address.endIndex {
        let endIndex = address.index(currentIndex, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        groups.append(String(address[currentIndex ..< endIndex]))
        currentIndex = endIndex
    }
    let splitIndex = min(6, groups.count)
    let firstLine = groups[..<splitIndex].joined(separator: " ")
    let secondLine = groups.dropFirst(splitIndex).joined(separator: " ")
    if secondLine.isEmpty {
        return firstLine
    } else {
        return firstLine + "\n" + secondLine
    }
}
