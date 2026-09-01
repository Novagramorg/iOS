import Foundation
import UIKit
import Display
import AccountContext
import ComponentFlow
import ViewControllerComponent
import TelegramPresentationData
import WalletContext

func formatTonConnectNanograms(_ value: String) -> String {
    guard value != "all" else { return "Complete balance" }
    guard !value.isEmpty, value.allSatisfy(\.isNumber) else { return value }
    let normalized = String(value.drop(while: { $0 == "0" }))
    let digits = normalized.isEmpty ? "0" : normalized
    if digits.count <= 9 {
        let fraction = String(repeating: "0", count: 9 - digits.count) + digits
        let trimmed = fraction.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return trimmed.isEmpty ? "0" : "0.\(trimmed)"
    }
    let index = digits.index(digits.endIndex, offsetBy: -9)
    let integer = digits[..<index]
    let fraction = digits[index...].replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    return fraction.isEmpty ? String(integer) : "\(integer).\(fraction)"
}

private func compactTonConnectValue(_ value: String) -> String {
    value.count > 30 ? "\(value.prefix(14))…\(value.suffix(10))" : value
}

final class WalletTransferNavigationAppIconComponent: Component {
    let applicationName: String
    let iconUrl: String?

    init(applicationName: String, iconUrl: String?) {
        self.applicationName = applicationName
        self.iconUrl = iconUrl
    }

    static func ==(lhs: WalletTransferNavigationAppIconComponent, rhs: WalletTransferNavigationAppIconComponent) -> Bool {
        lhs.applicationName == rhs.applicationName && lhs.iconUrl == rhs.iconUrl
    }

    final class View: UIView {
        private let icon = ComponentView<Empty>()
        func update(component: WalletTransferNavigationAppIconComponent, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 44, height: 44)
            self.icon.parentState = state
            _ = self.icon.update(
                transition: transition,
                component: AnyComponent(WalletConnectAppIconComponent(applicationName: component.applicationName, url: component.iconUrl)),
                environment: {},
                containerSize: size
            )
            if let view = self.icon.view {
                if view.superview == nil { self.addSubview(view) }
                view.clipsToBounds = true
                view.layer.borderWidth = 3
                view.layer.borderColor = UIColor.white.cgColor
                transition.setCornerRadius(layer: view.layer, cornerRadius: 22)
                transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
            }
            return size
        }
    }

    func makeView() -> View { View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, state: state, transition: transition)
    }
}

final class WalletTonConnectMessagesComponent: Component {
    let request: WalletContext.TonConnectOperationRequest
    let theme: PresentationTheme
    let compact: Bool

    init(request: WalletContext.TonConnectOperationRequest, theme: PresentationTheme, compact: Bool) {
        self.request = request
        self.theme = theme
        self.compact = compact
    }

    static func ==(lhs: WalletTonConnectMessagesComponent, rhs: WalletTonConnectMessagesComponent) -> Bool {
        lhs.request == rhs.request && lhs.theme == rhs.theme && lhs.compact == rhs.compact
    }

    final class View: UIView {
        private var labels: [UILabel] = []

        private func label(text: String, font: UIFont, color: UIColor, lines: Int = 0) -> UILabel {
            let label = UILabel()
            label.text = text
            label.font = font
            label.textColor = color
            label.numberOfLines = lines
            self.addSubview(label)
            self.labels.append(label)
            return label
        }

        func update(component: WalletTonConnectMessagesComponent, availableSize: CGSize) -> CGSize {
            self.labels.forEach { $0.removeFromSuperview() }
            self.labels.removeAll()
            let primary = component.theme.list.itemPrimaryTextColor
            let secondary = component.theme.list.itemSecondaryTextColor
            let warning = component.theme.list.itemDestructiveColor
            let width = max(1, availableSize.width)
            let inset: CGFloat = component.compact ? 14 : 16
            let textWidth = max(1, width - inset * 2)
            var y: CGFloat = inset

            let title = component.request.method == .signMessage
                ? "Sign \(component.request.messages.count) message\(component.request.messages.count == 1 ? "" : "s")"
                : "Send \(component.request.messages.count) message\(component.request.messages.count == 1 ? "" : "s")"
            let titleLabel = self.label(text: title, font: Font.semibold(17), color: primary)
            let titleSize = titleLabel.sizeThatFits(CGSize(width: textWidth, height: 1000))
            titleLabel.frame = CGRect(x: inset, y: y, width: textWidth, height: titleSize.height)
            y += titleSize.height + 12

            for (index, message) in component.request.messages.enumerated() {
                let payload: String
                switch message.payload {
                case .empty: payload = "Empty body"
                case let .comment(text): payload = text.isEmpty ? "Empty comment" : "Comment: \(text)"
                case let .raw(value): payload = "Raw payload: \(value)"
                }
                let details = [
                    "Message \(index + 1) of \(component.request.messages.count)",
                    "\(formatTonConnectNanograms(message.amountNanograms)) Gram",
                    "To \(compactTonConnectValue(message.destination))",
                    payload,
                    message.stateInit.map { "StateInit: \($0)" }
                ].compactMap { $0 }.joined(separator: "\n")
                let label = self.label(text: details, font: Font.regular(15), color: primary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 14
            }

            if let fee = component.request.feeNanograms {
                let label = self.label(text: "Network fee: \(formatTonConnectNanograms(fee)) Gram", font: Font.regular(14), color: secondary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            } else if component.request.relayerWillSubmit {
                let label = self.label(text: "Network fee is paid by the relayer. Telegram will not broadcast this message.", font: Font.regular(14), color: secondary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            }
            if let validUntil = component.request.validUntil {
                let label = self.label(text: "Valid until: \(Date(timeIntervalSince1970: TimeInterval(validUntil)).description)", font: Font.regular(13), color: secondary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            }
            if component.request.needsWalletStateInit {
                let label = self.label(text: "Wallet StateInit will be included", font: Font.regular(14), color: secondary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            }
            for value in component.request.warnings {
                let label = self.label(text: "⚠︎ \(value)", font: Font.regular(14), color: warning)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            }
            if !component.request.actions.isEmpty {
                let actions = component.request.actions.map { action in
                    let accounts = action.accounts.map(compactTonConnectValue).joined(separator: ", ")
                    let suffix = accounts.isEmpty ? "" : " — \(accounts)"
                    return "\(action.succeeded ? "✓" : "⚠︎") \(action.kind.replacingOccurrences(of: "_", with: " "))\(suffix)"
                }.joined(separator: "\n")
                let label = self.label(text: actions, font: Font.regular(14), color: secondary)
                let size = label.sizeThatFits(CGSize(width: textWidth, height: 1000))
                label.frame = CGRect(x: inset, y: y, width: textWidth, height: size.height)
                y += size.height + 8
            }
            return CGSize(width: width, height: y + inset)
        }
    }

    func makeView() -> View { View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize)
    }
}

final class WalletTransferPreviewComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    let context: AccountContext
    let request: WalletContext.TonConnectOperationRequest
    let walletState: WalletContext.State?
    let bottomInset: CGFloat

    init(context: AccountContext, request: WalletContext.TonConnectOperationRequest, walletState: WalletContext.State?, bottomInset: CGFloat) {
        self.context = context
        self.request = request
        self.walletState = walletState
        self.bottomInset = bottomInset
    }

    static func ==(lhs: WalletTransferPreviewComponent, rhs: WalletTransferPreviewComponent) -> Bool {
        lhs.context === rhs.context && lhs.request == rhs.request && lhs.walletState == rhs.walletState && lhs.bottomInset == rhs.bottomInset
    }

    final class View: UIView {
        private let content = ComponentView<Empty>()
        func update(component: WalletTransferPreviewComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            transition.setBackgroundColor(view: self, color: environment.theme.list.modalBlocksBackgroundColor)
            let width = min(382, max(1, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 48))
            self.content.parentState = state
            let size = self.content.update(
                transition: transition,
                component: AnyComponent(WalletTonConnectMessagesComponent(request: component.request, theme: environment.theme.withModalBlocksBackground(), compact: false)),
                environment: {},
                containerSize: CGSize(width: width, height: 2000)
            )
            if let view = self.content.view {
                if view.superview == nil { self.addSubview(view) }
                view.layer.cornerRadius = 14
                view.clipsToBounds = true
                view.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
                transition.setFrame(view: view, frame: CGRect(x: floor((availableSize.width - width) / 2), y: 72, width: width, height: size.height))
            }
            return CGSize(width: availableSize.width, height: 72 + size.height + component.bottomInset)
        }
    }

    func makeView() -> View { View(frame: .zero) }
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
