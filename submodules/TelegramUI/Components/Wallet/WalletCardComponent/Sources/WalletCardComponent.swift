import Foundation
import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

public final class WalletCardComponent: Component {
    public let balance: Int64?
    public let fiatCurrency: WalletContext.FiatCurrency
    public let fiatRate: WalletContext.FiatRate?
    public let dateTimeFormat: PresentationDateTimeFormat
    public let name: String
    public let address: String
    public let qrPressed: () -> Void

    public init(
        balance: Int64?,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat,
        name: String,
        address: String,
        qrPressed: @escaping () -> Void
    ) {
        self.balance = balance
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
        self.name = name
        self.address = address
        self.qrPressed = qrPressed
    }

    public static func ==(lhs: WalletCardComponent, rhs: WalletCardComponent) -> Bool {
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.fiatCurrency != rhs.fiatCurrency || lhs.fiatRate != rhs.fiatRate {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView = WalletCardBackgroundView()

        private let integralBalance = ComponentView<Empty>()
        private let fractionalBalance = ComponentView<Empty>()
        private let currency = ComponentView<Empty>()
        private let secondaryBalance = ComponentView<Empty>()
        private let name = ComponentView<Empty>()
        private let addressOutline = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let qrButton = ComponentView<Empty>()

        private var component: WalletCardComponent?

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.backgroundView)

            self.clipsToBounds = true
            self.layer.cornerRadius = 20.0
            if #available(iOS 13.0, *) {
                self.layer.cornerCurve = .continuous
            }
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletCardComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let referenceSize = CGSize(width: 361.0, height: 220.0)
            let width = max(0.0, availableSize.width)
            let scale = width / referenceSize.width
            let size = CGSize(width: width, height: referenceSize.height * scale)

            self.backgroundColor = .clear
            self.layer.cornerRadius = 20.0 * width / 336.0

            let formattedBalance: String
            if let balance = component.balance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                formattedBalance = "0"
            }

            let integralText: String
            let fractionalText: String
            if component.balance == nil || component.balance == 0 {
                integralText = formattedBalance
                fractionalText = ""
            } else if let decimalRange = formattedBalance.range(of: component.dateTimeFormat.decimalSeparator) {
                integralText = String(formattedBalance[..<decimalRange.lowerBound])
                var fractionalDigits = String(formattedBalance[decimalRange.upperBound...])
                while fractionalDigits.count < 2 {
                    fractionalDigits.append("0")
                }
                fractionalText = component.dateTimeFormat.decimalSeparator + fractionalDigits
            } else {
                integralText = formattedBalance
                fractionalText = component.dateTimeFormat.decimalSeparator + "00"
            }

            let secondaryText: String
            if let balance = component.balance, let fiatRate = component.fiatRate {
                secondaryText = formatTonFiatValue(
                    balance,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: balance == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                secondaryText = "—"
            }

            let mainColor = UIColor.white
            let secondaryColor = UIColor(rgb: 0x6ddcff)
            let integralSize = self.integralBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(
                            id: "gramIcon",
                            content: .icon("Wallet/CardGram", tint: false, offset: CGPoint(x: 0.0, y: -1.0))
                        ),
                        AnimatedTextComponent.Item(id: "gramIntegral", content: .text(integralText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let fractionalSize = self.fractionalBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 18.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramFraction", content: .text(fractionalText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let currencySize = self.currency.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramCurrency", content: .text("GRAM"))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )

            let mainCenterY = 94.0
            let integralOriginY = floor(mainCenterY - integralSize.height * 0.5)
            let integralBottomY = integralOriginY + integralSize.height
            var mainOriginX = 20.0
            if let integralView = self.integralBalance.view {
                if integralView.superview == nil {
                    self.addSubview(integralView)
                }
                transition.setFrame(
                    view: integralView,
                    frame: CGRect(
                        origin: CGPoint(x: mainOriginX, y: integralOriginY),
                        size: integralSize
                    )
                )
            }
            mainOriginX += integralSize.width
            if !fractionalText.isEmpty {
                mainOriginX += 1.0
            }
            if let fractionalView = self.fractionalBalance.view {
                if fractionalView.superview == nil {
                    self.addSubview(fractionalView)
                }
                transition.setFrame(
                    view: fractionalView,
                    frame: CGRect(
                        origin: CGPoint(x: mainOriginX, y: floor(integralBottomY - fractionalSize.height - 2.0) - 1.0 - UIScreenPixel),
                        size: fractionalSize
                    )
                )
            }
            mainOriginX += fractionalSize.width
            mainOriginX += 5.0
            if let currencyView = self.currency.view {
                if currencyView.superview == nil {
                    self.addSubview(currencyView)
                }
                transition.setFrame(
                    view: currencyView,
                    frame: CGRect(
                        origin: CGPoint(x: mainOriginX, y: floor(integralBottomY - currencySize.height - 2.0)),
                        size: currencySize
                    )
                )
            }

            let secondarySize = self.secondaryBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 14.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "secondaryBalance", content: .text(secondaryText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            if let secondaryView = self.secondaryBalance.view {
                if secondaryView.superview == nil {
                    self.addSubview(secondaryView)
                }
                transition.setFrame(
                    view: secondaryView,
                    frame: CGRect(
                        origin: CGPoint(x: 24.0, y: 114.0),
                        size: secondarySize
                    )
                )
            }

            let nameSize = self.name.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.name,
                        font: Font.with(size: 14.0, design: .monospace, weight: .semibold),
                        textColor: mainColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: width - 96.0 * scale, height: 50.0)
            )
            if let nameView = self.name.view {
                if nameView.superview == nil {
                    self.addSubview(nameView)
                }
                transition.setFrame(
                    view: nameView,
                    frame: CGRect(
                        origin: CGPoint(x: 24.0, y: size.height - 32.0),
                        size: nameSize
                    )
                )
            }

            let qrSize = self.qrButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/CardQr",
                        tintColor: nil,
                        scaleFactor: scale
                    )),
                    minSize: CGSize(width: 50.0, height: 38.0),
                    action: { [weak self] in
                        self?.component?.qrPressed()
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: 80.0 * scale, height: 80.0)
            )
            if let qrView = self.qrButton.view {
                if qrView.superview == nil {
                    self.addSubview(qrView)
                }
                transition.setFrame(
                    view: qrView,
                    frame: CGRect(
                        origin: CGPoint(x: width - 96.0 * scale, y: 82.0 * scale),
                        size: qrSize
                    )
                )
            }

            let addressText = formattedWalletAddress(component.address)

            let _ = self.addressOutline.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0),
                        textColor: UIColor(rgb: 0xffffff, alpha: 0.1)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0),
                        textColor: UIColor(rgb: 0x005dda)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            if let addressView = self.addressOutline.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - 24.0, y: size.height * 0.5 + 1.0)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - 24.0, y: size.height * 0.5)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }

            var safeZones: [CGRect] = []
            let moneyViews: [UIView] = [
                self.integralBalance.view,
                self.fractionalBalance.view,
                self.currency.view,
                self.secondaryBalance.view
            ].compactMap { $0 }
            var moneyFrame = CGRect.null
            for view in moneyViews where !view.frame.isEmpty {
                moneyFrame = moneyFrame.union(view.frame)
            }
            if !moneyFrame.isNull {
                safeZones.append(moneyFrame)
            }
            if let nameView = self.name.view, !nameView.frame.isEmpty {
                safeZones.append(nameView.frame)
            }
            if let qrView = self.qrButton.view, !qrView.frame.isEmpty {
                safeZones.append(qrView.frame)
            }
            var addressFrame = CGRect.null
            if let addressOutlineView = self.addressOutline.view, !addressOutlineView.frame.isEmpty {
                addressFrame = addressFrame.union(addressOutlineView.frame)
            }
            if let addressView = self.address.view, !addressView.frame.isEmpty {
                addressFrame = addressFrame.union(addressView.frame)
            }
            if !addressFrame.isNull {
                safeZones.append(addressFrame)
            }

            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            self.backgroundView.update(size: size, safeZones: safeZones)

            return size
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

private func formattedWalletAddress(_ address: String) -> String {
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
