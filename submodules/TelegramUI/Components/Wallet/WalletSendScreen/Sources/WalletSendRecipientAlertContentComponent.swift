import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AlertComponent
import MultilineTextComponent

final class WalletSendRecipientAlertContentComponent: Component {
    typealias EnvironmentType = AlertComponentEnvironment

    let title: String
    let recipientName: String?
    let address: String

    init(title: String, recipientName: String?, address: String) {
        self.title = title
        self.recipientName = recipientName
        self.address = address
    }

    static func ==(lhs: WalletSendRecipientAlertContentComponent, rhs: WalletSendRecipientAlertContentComponent) -> Bool {
        return lhs.title == rhs.title
            && lhs.recipientName == rhs.recipientName
            && lhs.address == rhs.address
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let addressBackground = UIView()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.addSubview(self.addressBackground)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletSendRecipientAlertContentComponent, availableSize: CGSize, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            let theme = environment[AlertComponentEnvironment.self].theme
            let textInset: CGFloat = -6.0
            let addressInset: CGFloat = -14.0
            let textWidth = availableSize.width - textInset * 2.0
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.bold(17.0), textColor: theme.actionSheet.primaryTextColor)),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.isAccessibilityElement = true
                titleView.accessibilityLabel = component.title
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: textInset, y: 0.0), size: titleSize))
            }

            let text = NSMutableAttributedString()
            if let recipientName = component.recipientName {
                //TODO:localize
                text.append(NSAttributedString(string: "This TON Blockchain address is linked to ", font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor))
                text.append(NSAttributedString(string: recipientName, font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor))
                text.append(NSAttributedString(string: " on Telegram.", font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor))
            } else {
                //TODO:localize
                text.append(NSAttributedString(string: "This TON Blockchain address has no linked Telegram account.", font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor))
            }
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(text),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: .greatestFiniteMagnitude)
            )
            let textFrame = CGRect(origin: CGPoint(x: textInset, y: titleSize.height + 12.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.isAccessibilityElement = true
                textView.accessibilityLabel = text.string
                transition.setFrame(view: textView, frame: textFrame)
            }

            let addressText = NSMutableAttributedString()
            let addressFont = Font.monospace(18.0)
            var index = component.address.startIndex
            var groupIndex = 0
            while index < component.address.endIndex {
                let row = groupIndex / 4
                let column = groupIndex % 4
                let color = (row + column).isMultiple(of: 2) ? theme.actionSheet.primaryTextColor : theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.32)
                if groupIndex != 0 {
                    addressText.append(NSAttributedString(string: column == 0 ? "\n" : " ", font: addressFont, textColor: color))
                }
                let endIndex = component.address.index(index, offsetBy: 4, limitedBy: component.address.endIndex) ?? component.address.endIndex
                addressText.append(NSAttributedString(string: String(component.address[index ..< endIndex]), font: addressFont, textColor: color))
                index = endIndex
                groupIndex += 1
            }
            let addressWidth = availableSize.width - addressInset * 2.0
            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(addressText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: addressWidth - 32.0, height: .greatestFiniteMagnitude)
            )
            let addressFrame = CGRect(x: addressInset, y: textFrame.maxY + 14.0, width: addressWidth, height: addressSize.height + 32.0)
            self.addressBackground.backgroundColor = theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1)
            transition.setFrame(view: self.addressBackground, frame: addressFrame)
            transition.setCornerRadius(layer: self.addressBackground.layer, cornerRadius: 14.0)
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                addressView.isAccessibilityElement = true
                addressView.accessibilityLabel = component.address
                transition.setFrame(view: addressView, frame: CGRect(origin: CGPoint(x: addressFrame.minX + floorToScreenPixels((addressFrame.width - addressSize.width) / 2.0), y: addressFrame.minY + 16.0), size: addressSize))
            }

            return CGSize(width: availableSize.width, height: addressFrame.maxY)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
