import Foundation
import UIKit
import AppBundle
import Display
import AccountContext
import TelegramCore
import LocalizedPeerData
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import GlassControls
import PlainButtonComponent
import ContextUI
import AttachmentUI
import AlertComponent
import AlertInputFieldComponent
import WalletContext
import QrCodeUI

private enum WalletSendInputMode: Equatable {
    case gram
    case fiat
}

private func walletSendShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

private func walletSendPlainDateTimeFormat(_ value: PresentationDateTimeFormat) -> PresentationDateTimeFormat {
    return PresentationDateTimeFormat(
        timeFormat: value.timeFormat,
        dateFormat: value.dateFormat,
        dateSeparator: "",
        dateSuffix: "",
        requiresFullYear: false,
        decimalSeparator: value.decimalSeparator,
        groupingSeparator: ""
    )
}

private func walletSendInputText(
    amount: Int64,
    mode: WalletSendInputMode,
    rate: Double?,
    dateTimeFormat: PresentationDateTimeFormat
) -> String {
    guard amount > 0 else {
        return ""
    }
    switch mode {
    case .gram:
        return formatTonAmountText(
            amount,
            dateTimeFormat: walletSendPlainDateTimeFormat(dateTimeFormat),
            maxDecimalPositions: 9
        )
    case .fiat:
        guard let rate, rate.isFinite, rate > 0.0 else {
            return ""
        }
        let value = Double(amount) / 1_000_000_000.0 * rate
        guard value.isFinite else {
            return ""
        }
        return String(
            format: "%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        ).replacingOccurrences(
            of: ".",
            with: dateTimeFormat.decimalSeparator
        )
    }
}

private func walletSendNanograms(
    text: String,
    mode: WalletSendInputMode,
    rate: Double?,
    decimalSeparator: String
) -> Int64? {
    guard !text.isEmpty else {
        return 0
    }

    let normalizedText = text.replacingOccurrences(of: decimalSeparator, with: ".")
    switch mode {
    case .gram:
        let parts = normalizedText.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            return nil
        }
        let wholeText = parts.first.map(String.init) ?? ""
        let whole: Int64
        if wholeText.isEmpty {
            whole = 0
        } else if let value = Int64(wholeText) {
            whole = value
        } else {
            return nil
        }
        guard whole >= 0 else {
            return nil
        }
        let scale: Int64 = 1_000_000_000
        let (scaledWhole, didOverflow) = whole.multipliedReportingOverflow(by: scale)
        guard !didOverflow else {
            return nil
        }

        var fractionalText = parts.count == 2 ? String(parts[1]) : ""
        guard fractionalText.count <= 9 else {
            return nil
        }
        fractionalText = fractionalText.padding(toLength: 9, withPad: "0", startingAt: 0)
        let fractional = Int64(fractionalText) ?? 0
        let (result, didAddOverflow) = scaledWhole.addingReportingOverflow(fractional)
        return didAddOverflow ? nil : result
    case .fiat:
        guard let rate, rate.isFinite, rate > 0.0,
              let fiatValue = Double(normalizedText), fiatValue.isFinite, fiatValue >= 0.0 else {
            return nil
        }
        let nanograms = fiatValue / rate * 1_000_000_000.0
        let roundedNanograms = nanograms.rounded()
        guard roundedNanograms.isFinite,
              roundedNanograms >= 0.0,
              roundedNanograms < Double(Int64.max) else {
            return nil
        }
        return Int64(roundedNanograms)
    }
}

private final class WalletSendAmountField: UIView, UITextFieldDelegate {
    private let gramIcon = ComponentView<Empty>()
    private let fiatIcon = ComponentView<Empty>()
    private let textField = UITextField()
    private let suffix = ComponentView<Empty>()
    private let integralFont = Font.with(
        size: 48.0,
        design: .round,
        weight: .semibold,
        traits: .monospacedNumbers
    )
    private let fractionalFont = Font.with(size: 32.0, design: .round, weight: .semibold)

    private var gramIconSize: CGSize = .zero
    private var fiatIconSize: CGSize = .zero
    private var suffixSize: CGSize = .zero

    private var mode: WalletSendInputMode = .gram
    private var amount: Int64 = 0
    private var rate: Double?
    private var dateTimeFormat: PresentationDateTimeFormat?
    private var isApplyingText = false

    var amountUpdated: ((Int64) -> Void)?
    var focusUpdated: ((Bool) -> Void)?

    var isInputActive: Bool {
        return self.textField.isFirstResponder
    }

    var hasInputText: Bool {
        return !(self.textField.text ?? "").isEmpty
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.textField.delegate = self
        self.textField.keyboardType = .decimalPad
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.textAlignment = .left
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.addSubview(self.textField)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.activateInput))
        self.addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func activateInput() {
        self.textField.becomeFirstResponder()
    }

    private func amountAttributedText(_ text: String) -> NSAttributedString {
        let textColor = self.textField.textColor ?? UIColor.black
        guard let dateTimeFormat = self.dateTimeFormat else {
            return NSAttributedString(
                string: text,
                font: self.integralFont,
                textColor: textColor
            )
        }
        return tonAmountAttributedString(
            text,
            integralFont: self.integralFont,
            fractionalFont: self.fractionalFont,
            color: textColor,
            decimalSeparator: dateTimeFormat.decimalSeparator
        )
    }

    @objc private func textChanged() {
        guard !self.isApplyingText, let dateTimeFormat = self.dateTimeFormat else {
            return
        }
        if let amount = walletSendNanograms(
            text: self.textField.text ?? "",
            mode: self.mode,
            rate: self.rate,
            decimalSeparator: dateTimeFormat.decimalSeparator
        ) {
            self.amount = amount
            self.amountUpdated?(amount)
        }
        self.setNeedsLayout()
    }

    func update(
        mode: WalletSendInputMode,
        amount: Int64,
        rate: Double?,
        fiatCurrency: WalletContext.FiatCurrency,
        dateTimeFormat: PresentationDateTimeFormat,
        theme: PresentationTheme,
        transition: ComponentTransition
    ) {
        let modeChanged = self.mode != mode
        let amountChanged = self.amount != amount
        let rateChanged = self.rate != rate
        let decimalSeparatorChanged = self.dateTimeFormat?.decimalSeparator != dateTimeFormat.decimalSeparator
        let textColorChanged = self.textField.textColor?.isEqual(theme.list.itemPrimaryTextColor) != true
        self.mode = mode
        self.amount = amount
        self.rate = rate
        self.dateTimeFormat = dateTimeFormat

        self.textField.font = self.integralFont
        self.textField.textColor = theme.list.itemPrimaryTextColor
        self.textField.tintColor = theme.list.itemAccentColor
        //TODO:localize
        let zeroPlaceholder = "0"
        self.textField.attributedPlaceholder = NSAttributedString(
            string: zeroPlaceholder,
            font: self.integralFont,
            textColor: theme.list.itemSecondaryTextColor
        )

        let suffixText: String
        switch mode {
        case .gram:
            //TODO:localize
            suffixText = "GRAM"
        case .fiat:
            suffixText = fiatCurrency.rawValue
        }

        self.gramIconSize = self.gramIcon.update(
            transition: transition,
            component: AnyComponent(BundleIconComponent(
                name: "Ads/TonBig",
                tintColor: UIColor(rgb: 0x30A1F5),
                maxSize: CGSize(width: 40.0, height: 40.0)
            )),
            environment: {},
            containerSize: CGSize(width: 40.0, height: 74.0)
        )
        if let gramIconView = self.gramIcon.view {
            if gramIconView.superview == nil {
                self.addSubview(gramIconView)
            }
            transition.setAlpha(view: gramIconView, alpha: mode == .gram ? 1.0 : 0.0)
        }

        let currencySymbol = fiatCurrency.symbol
        self.fiatIconSize = self.fiatIcon.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: currencySymbol,
                    font: Font.with(size: 48.0, design: .round, weight: .bold),
                    textColor: theme.list.itemSecondaryTextColor
                )),
                maximumNumberOfLines: 1
            )),
            environment: {},
            containerSize: CGSize(width: 40.0, height: 74.0)
        )
        if let fiatIconView = self.fiatIcon.view {
            if fiatIconView.superview == nil {
                self.addSubview(fiatIconView)
            }
            transition.setAlpha(view: fiatIconView, alpha: mode == .fiat ? 1.0 : 0.0)
        }

        self.suffixSize = self.suffix.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: suffixText,
                    font: self.fractionalFont,
                    textColor: theme.list.itemSecondaryTextColor
                )),
                maximumNumberOfLines: 1
            )),
            environment: {},
            containerSize: CGSize(width: 150.0, height: 74.0)
        )
        if let suffixView = self.suffix.view, suffixView.superview == nil {
            self.addSubview(suffixView)
        }

        if modeChanged || ((amountChanged || rateChanged || decimalSeparatorChanged) && !self.textField.isFirstResponder) {
            self.isApplyingText = true
            let inputText = walletSendInputText(
                amount: amount,
                mode: mode,
                rate: rate,
                dateTimeFormat: dateTimeFormat
            )
            self.textField.attributedText = self.amountAttributedText(inputText)
            self.isApplyingText = false
            self.textField.reloadInputViews()
        } else if textColorChanged {
            self.textField.attributedText = self.amountAttributedText(self.textField.text ?? "")
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconLayoutSize = CGSize(width: 40.0, height: 40.0)
        let iconSpacing: CGFloat = 11.0
        let suffixSpacing: CGFloat = 2.0
        let displayText = (self.textField.text ?? "").isEmpty ? "0" : (self.textField.text ?? "")
        let displayTextBounds = self.amountAttributedText(displayText).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.bounds.height),
            options: [],
            context: nil
        )
        let textWidth = min(
            max(31.0, ceil(displayTextBounds.width) + 5.0),
            max(31.0, self.bounds.width - 190.0)
        )
        let totalWidth = iconLayoutSize.width + iconSpacing + textWidth + suffixSpacing + self.suffixSize.width
        var x = floorToScreenPixels((self.bounds.width - totalWidth) / 2.0)
        let centerY = self.bounds.height / 2.0

        if let gramIconView = self.gramIcon.view {
            gramIconView.frame = CGRect(
                origin: CGPoint(
                    x: x + floorToScreenPixels((iconLayoutSize.width - self.gramIconSize.width) / 2.0),
                    y: floorToScreenPixels(centerY - self.gramIconSize.height / 2.0)
                ),
                size: self.gramIconSize
            )
        }
        if let fiatIconView = self.fiatIcon.view {
            fiatIconView.frame = CGRect(
                origin: CGPoint(
                    x: x + floorToScreenPixels((iconLayoutSize.width - self.fiatIconSize.width) / 2.0),
                    y: floorToScreenPixels(centerY - self.fiatIconSize.height / 2.0)
                ),
                size: self.fiatIconSize
            )
        }
        x += iconLayoutSize.width + iconSpacing
        self.textField.frame = CGRect(
            origin: CGPoint(x: x, y: 0.0),
            size: CGSize(width: textWidth, height: self.bounds.height)
        )
        x += textWidth + suffixSpacing
        if let suffixView = self.suffix.view {
            suffixView.frame = CGRect(
                origin: CGPoint(x: x, y: floorToScreenPixels(centerY - self.suffixSize.height / 2.0 + 6.0)),
                size: self.suffixSize
            )
        }
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.focusUpdated?(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        self.focusUpdated?(false)
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let dateTimeFormat = self.dateTimeFormat else {
            return false
        }

        var replacement = string
        if replacement == "." || replacement == "," {
            replacement = dateTimeFormat.decimalSeparator
        }
        var updatedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: replacement)
        let decimalSeparator = dateTimeFormat.decimalSeparator

        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: decimalSeparator))
        guard updatedText.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return false
        }
        guard updatedText.components(separatedBy: decimalSeparator).count <= 2 else {
            return false
        }
        let maximumFractionalDigits = self.mode == .gram ? 9 : 2
        if let range = updatedText.range(of: decimalSeparator) {
            let fractionalCount = updatedText[range.upperBound...].count
            guard fractionalCount <= maximumFractionalDigits else {
                return false
            }
        }
        if updatedText == decimalSeparator {
            updatedText = "0" + decimalSeparator
        }
        if updatedText.count > 1 && updatedText.hasPrefix("0") && !updatedText.hasPrefix("0" + decimalSeparator) {
            updatedText.removeFirst()
        }
        guard walletSendNanograms(
            text: updatedText,
            mode: self.mode,
            rate: self.rate,
            decimalSeparator: decimalSeparator
        ) != nil else {
            return false
        }

        self.isApplyingText = true
        textField.attributedText = self.amountAttributedText(updatedText)
        self.isApplyingText = false
        self.textChanged()
        return false
    }
}

private final class WalletSendScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer?
    let initialAddress: String
    let walletContext: WalletContext

    init(
        context: AccountContext,
        peer: EnginePeer?,
        initialAddress: String,
        walletContext: WalletContext
    ) {
        self.context = context
        self.peer = peer
        self.initialAddress = initialAddress
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletSendScreenComponent, rhs: WalletSendScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.initialAddress != rhs.initialAddress {
            return false
        }
        if lhs.walletContext !== rhs.walletContext {
            return false
        }
        return true
    }

    final class View: UIView {
        private let controlButtons = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let amountField = WalletSendAmountField()
        private let emptyHint = ComponentView<Empty>()
        private let rateButton = ComponentView<Empty>()
        private let insufficientText = ComponentView<Empty>()
        private let depositButton = ComponentView<Empty>()
        private let balanceText = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let commentBackgroundView = UIImageView()
        private let commentText = ComponentView<Empty>()

        private var component: WalletSendScreenComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var isUpdating = false

        private var walletContext: WalletContext?
        private let walletDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private var walletBalance: Int64?
        private var walletAddress: String?
        private var walletIsLoading = true
        private var isPreparingTransfer = false

        private var inputMode: WalletSendInputMode = .gram
        private var amount: Int64 = 0
        private var comment: String?
        private var currentFiatCurrency: WalletContext.FiatCurrency = .usd
        private var currentRate: Double?
        private var recipientAddress = ""
        private var initialAddress: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.amountField)
            self.amountField.amountUpdated = { [weak self] amount in
                guard let self else {
                    return
                }
                self.amount = amount
                if !self.isUpdating {
                    self.componentState?.updated(transition: .immediate)
                }
            }
            self.amountField.focusUpdated = { [weak self] focused in
                guard let self else {
                    return
                }
                if focused, let controller = self.environment?.controller() as? WalletSendScreen {
                    controller.requestAttachmentMenuExpansion()
                    controller.cancelPanGesture()
                }
                if !self.isUpdating {
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
            }

            self.commentBackgroundView.contentMode = .scaleToFill
            self.addSubview(self.commentBackgroundView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.walletDisposable.dispose()
            self.transferDisposable.dispose()
        }

        func isPanGestureEnabled() -> Bool {
            return !self.amountField.isInputActive
        }

        private func applyRecipient(_ value: String) {
            var address = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let components = URLComponents(string: address), components.scheme?.lowercased() == "ton" {
                if components.host?.lowercased() == "transfer" {
                    address = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                } else if let host = components.host, !host.isEmpty {
                    address = host
                }
                if let amountValue = components.queryItems?.first(where: { $0.name == "amount" })?.value,
                   let amount = Int64(amountValue), amount > 0 {
                    self.amount = amount
                }
                if let comment = components.queryItems?.first(where: { $0.name == "text" })?.value, !comment.isEmpty {
                    self.comment = comment
                }
            }
            self.recipientAddress = address
            if !self.isUpdating {
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }
        }

        private func toggleInputMode() {
            guard let rate = self.currentRate, rate.isFinite, rate > 0.0 else {
                return
            }
            switch self.inputMode {
            case .gram:
                self.inputMode = .fiat
            case .fiat:
                self.inputMode = .gram
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func dismiss() {
            (self.environment?.controller() as? WalletSendScreen)?.dismiss()
        }

        private func openReceive() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            guard let walletAddress = self.walletAddress else {
                return
            }
            let receiveController = component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: walletAddress
            )
            if let parentController = (controller as? AttachmentContainable)?.parentController() {
                parentController.push(receiveController)
            } else {
                controller.push(receiveController)
            }
        }

        private func showCommentAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            let inputState = AlertInputFieldComponent.ExternalState()
            //TODO:localize
            let title = "Add public comment"
            //TODO:localize
            let placeholder = "Optional message"
            //TODO:localize
            let cancel = "Cancel"
            //TODO:localize
            let add = "Add"

            let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: title))
                ),
                AnyComponentWithIdentity(
                    id: "input",
                    component: AnyComponent(AlertInputFieldComponent(
                        context: component.context,
                        initialValue: self.comment ?? "",
                        placeholder: placeholder,
                        hasClearButton: true,
                        returnKeyType: .done,
                        keyboardType: .default,
                        autocapitalizationType: .sentences,
                        autocorrectionType: .default,
                        isInitiallyFocused: true,
                        externalState: inputState
                    ))
                )
            ]

            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(allowInputInset: true),
                content: content,
                actions: [
                    AlertScreen.Action(title: cancel),
                    AlertScreen.Action(title: add, type: .default, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        let value = inputState.value.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.comment = value.isEmpty ? nil : value
                        self.componentState?.updated(transition: .spring(duration: 0.35))
                    })
                ]
            )
            controller.present(alertController, in: .window(.root))
        }

        private func openMoreMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            //TODO:localize
            let depositFunds = "Deposit funds"
            var items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: depositFunds,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/AddCircle"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openReceive()
                    }
                ))
            ]
            if component.peer != nil {
                //TODO:localize
                let addComment = "Add comment"
                items.append(.action(ContextMenuActionItem(
                    text: addComment,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.showCommentAlert()
                    }
                )))
            }
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                source: .reference(WalletSendContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        private func send() {
            guard let component = self.component,
                  self.amount > 0,
                  !self.isPreparingTransfer,
                  !self.walletIsLoading,
                  let balance = self.walletBalance,
                  self.amount <= balance else {
                return
            }
            guard !self.recipientAddress.isEmpty else {
                return
            }
            self.isPreparingTransfer = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.transferDisposable.set((component.walletContext.prepareTransfer(
                address: self.recipientAddress,
                amount: self.amount,
                comment: self.comment
            )
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self, let controller = self.environment?.controller() else {
                    return
                }
                self.isPreparingTransfer = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))

                let dismissSendScreen: () -> Void = { [weak controller] in
                    guard let controller else {
                        return
                    }
                    if let navigationController = controller.navigationController as? NavigationController {
                        var viewControllers = navigationController.viewControllers
                        viewControllers.removeAll(where: { $0 === controller })
                        navigationController.setViewControllers(viewControllers, animated: false)
                    } else {
                        controller.dismiss(animated: false)
                    }
                }
                controller.push(component.context.sharedContext.makeWalletTransactionScreen(
                    context: component.context,
                    mode: .preview(
                        walletContext: component.walletContext,
                        preparedTransfer: prepared,
                        dismissSendScreen: dismissSendScreen
                    )
                ))
            }, error: { [weak self] _ in
                self?.isPreparingTransfer = false
                self?.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self?.presentTransferError()
            }))
        }

        private func presentTransferError() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            //TODO:localize
            let title = "Transfer Failed"
            //TODO:localize
            let text = "The transfer could not be prepared or sent. Check the address, balance and network connection, then try again."
            //TODO:localize
            let ok = "OK"
            controller.present(standardTextAlertController(
                theme: AlertControllerTheme(presentationData: presentationData),
                title: title,
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: ok, action: {
                })]
            ), in: .window(.root))
        }

        func update(
            component: WalletSendScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.environment = environment
            self.componentState = state

            var shouldFocusAmountField = false
            if self.initialAddress != component.initialAddress {
                self.initialAddress = component.initialAddress
                if !component.initialAddress.isEmpty {
                    self.applyRecipient(component.initialAddress)
                    shouldFocusAmountField = true
                }
            }

            if self.walletContext !== component.walletContext {
                self.walletContext = component.walletContext
                self.walletBalance = nil
                self.walletAddress = nil
                self.walletIsLoading = true
                self.currentFiatCurrency = .usd
                self.currentRate = nil
                self.inputMode = .gram
                let observedWalletContext = component.walletContext
                self.walletDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === observedWalletContext else {
                        return
                    }
                    self.walletBalance = walletState.balance.currentValue
                    if case let .wallet(info) = walletState.phase {
                        self.walletAddress = info.address
                    } else {
                        self.walletAddress = nil
                    }
                    switch walletState.balance {
                    case .loading:
                        self.walletIsLoading = walletState.balance.currentValue == nil || walletState.activeOperation != nil
                    default:
                        self.walletIsLoading = walletState.activeOperation != nil
                    }
                    self.currentFiatCurrency = walletState.fiat.selectedCurrency
                    if let rate = walletState.fiat.selectedRate,
                       rate.unitsPerGram.isFinite,
                       rate.unitsPerGram > 0.0 {
                        self.currentRate = rate.unitsPerGram
                    } else {
                        self.currentRate = nil
                        self.inputMode = .gram
                    }
                    if !self.isUpdating {
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    }
                }))
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.plainBackgroundColor

            let peerName = component.peer?.compactDisplayTitle
            let addressTitle = self.recipientAddress.isEmpty ? nil : walletSendShortAddress(self.recipientAddress)
            let recipientTitle = peerName ?? addressTitle
            let titlePrefix: String
            if recipientTitle == nil {
                //TODO:localize
                titlePrefix = "Send Money"
            } else {
                //TODO:localize
                titlePrefix = "Send Money to "
            }
            let titleText = NSMutableAttributedString()
            titleText.append(NSAttributedString(
                string: titlePrefix,
                font: Font.semibold(17.0),
                textColor: theme.list.itemPrimaryTextColor
            ))
            if let recipientTitle {
                titleText.append(NSAttributedString(
                    string: recipientTitle,
                    font: Font.semibold(17.0),
                    textColor: theme.list.itemAccentColor
                ))
            }

            let headerButtonSize = CGSize(width: 44.0, height: 44.0)
            let headerOriginY = environment.safeInsets.top + 16.0
            let controlButtonsWidth = max(
                1.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0
            )
            let controlButtonsSize = self.controlButtons.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [
                            GlassControlGroupComponent.Item(
                                id: AnyHashable("close"),
                                content: .icon("Navigation/Close"),
                                action: { [weak self] in
                                    self?.dismiss()
                                }
                            )
                        ],
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: GlassControlPanelComponent.Item(
                        items: [
                            GlassControlGroupComponent.Item(
                                id: AnyHashable("more"),
                                content: .animation("anim_morewide"),
                                action: { [weak self] in
                                    guard let self,
                                          let controlsView = self.controlButtons.view as? GlassControlPanelComponent.View,
                                          let sourceView = controlsView.rightItemView?.itemView(id: AnyHashable("more")) else {
                                        return
                                    }
                                    self.openMoreMenu(sourceView: sourceView)
                                }
                            )
                        ],
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: controlButtonsWidth, height: headerButtonSize.height)
            )
            if let controlButtonsView = self.controlButtons.view {
                if controlButtonsView.superview == nil {
                    self.addSubview(controlButtonsView)
                }
                transition.setFrame(
                    view: controlButtonsView,
                    frame: CGRect(
                        origin: CGPoint(x: environment.safeInsets.left + 16.0, y: headerOriginY),
                        size: controlButtonsSize
                    )
                )
            }

            let titleInset = environment.safeInsets.left + 72.0
            let titleAvailableWidth = max(0.0, availableSize.width - titleInset * 2.0)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: headerButtonSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        x: titleInset + floorToScreenPixels((titleAvailableWidth - titleSize.width) / 2.0),
                        y: headerOriginY + floorToScreenPixels((headerButtonSize.height - titleSize.height) / 2.0),
                        width: titleSize.width,
                        height: titleSize.height
                    )
                )
            }

            let keyboardHeight = environment.inputHeight
            let effectiveBottomInset = max(
                keyboardHeight,
                environment.additionalInsets.bottom + environment.safeInsets.bottom
            )
            let usableBottom = availableSize.height - effectiveBottomInset
            let hasAmount = self.amount > 0
            let isInsufficient = hasAmount
                && !self.walletIsLoading
                && self.walletBalance.map { self.amount > $0 } == true
            let hasPositiveBalance = self.walletBalance.map { $0 > 0 } == true
            let displaysComment = component.peer != nil && self.comment != nil
            let amountBottomReserve: CGFloat
            if displaysComment {
                amountBottomReserve = 330.0
            } else {
                amountBottomReserve = 290.0
            }
            let minimumAmountHeaderSpacing: CGFloat
            if displaysComment {
                minimumAmountHeaderSpacing = 55.0
            } else {
                minimumAmountHeaderSpacing = 75.0
            }
            let amountWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0)
            let amountCenterY = max(
                headerOriginY + headerButtonSize.height + minimumAmountHeaderSpacing,
                min(availableSize.height * 0.39, usableBottom - amountBottomReserve)
            )
            let amountFrame = CGRect(
                x: environment.safeInsets.left + 16.0,
                y: floorToScreenPixels(amountCenterY - 37.0),
                width: amountWidth,
                height: 74.0
            )
            transition.setFrame(view: self.amountField, frame: amountFrame)
            self.amountField.update(
                mode: self.inputMode,
                amount: self.amount,
                rate: self.currentRate,
                fiatCurrency: self.currentFiatCurrency,
                dateTimeFormat: environment.dateTimeFormat,
                theme: theme,
                transition: transition
            )
            if shouldFocusAmountField {
                self.amountField.activateInput()
            }

            //TODO:localize
            let emptyHint = "Tap to set amount"
            let emptyHintSize = self.emptyHint.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: emptyHint,
                        font: Font.regular(15.0),
                        textColor: theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            if let emptyHintView = self.emptyHint.view {
                if emptyHintView.superview == nil {
                    self.addSubview(emptyHintView)
                }
                transition.setFrame(
                    view: emptyHintView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - emptyHintSize.width) / 2.0),
                        y: amountFrame.maxY + 5.0,
                        width: emptyHintSize.width,
                        height: emptyHintSize.height
                    )
                )
                let showEmptyHint = !self.amountField.isInputActive && !self.amountField.hasInputText
                transition.setAlpha(view: emptyHintView, alpha: showEmptyHint ? 1.0 : 0.0)
            }

            var rateText = ""
            if hasAmount, let rate = self.currentRate {
                switch self.inputMode {
                case .gram:
                    let fiatSwitchSuffix = " \(self.currentFiatCurrency.rawValue)"
                    let formattedFiatValue = formatTonFiatValue(
                        self.amount,
                        divide: true,
                        rate: rate,
                        currencySymbol: "",
                        dateTimeFormat: environment.dateTimeFormat
                    )
                    rateText = "~" + formattedFiatValue + fiatSwitchSuffix
                case .fiat:
                    let gramValue = formatTonAmountText(
                        self.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 3
                    )
                    //TODO:localize
                    let gramSuffix = " GRAM"
                    rateText = gramValue + gramSuffix
                }
            }
            let showRate = hasAmount && !rateText.isEmpty
            let rateItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: rateText,
                            font: Font.with(size: 13.0, design: .round, weight: .semibold),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "icon",
                    component: AnyComponent(BundleIconComponent(
                        name: "Wallet/Swap",
                        tintColor: theme.list.itemSecondaryTextColor,
                        maxSize: CGSize(width: 18.0, height: 18.0)
                    ))
                )
            ]
            let rateButtonSize = self.rateButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack(rateItems, spacing: 3.0)),
                    background: AnyComponent(RoundedRectangle(
                        color: theme.list.itemInputField.backgroundColor,
                        cornerRadius: 13.0
                    )),
                    minSize: CGSize(width: 22.0, height: 26.0),
                    contentInsets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0),
                    action: { [weak self] in
                        self?.toggleInputMode()
                    },
                    isEnabled: showRate
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 64.0, height: 26.0)
            )
            let rateButtonFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - rateButtonSize.width) / 2.0),
                y: amountFrame.maxY + 7.0,
                width: rateButtonSize.width,
                height: rateButtonSize.height
            )
            if let rateButtonView = self.rateButton.view {
                if rateButtonView.superview == nil {
                    self.addSubview(rateButtonView)
                }
                transition.setFrame(view: rateButtonView, frame: rateButtonFrame)
                transition.setAlpha(view: rateButtonView, alpha: showRate ? 1.0 : 0.0)
            }

            //TODO:localize
            let insufficientText = "Insufficient funds."
            let insufficientTextSize = self.insufficientText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: insufficientText,
                        font: Font.regular(13.0),
                        textColor: theme.list.itemDestructiveColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 22.0)
            )
            let insufficientSlotFrame = CGRect(
                x: 16.0,
                y: rateButtonFrame.maxY + 10.0,
                width: availableSize.width - 32.0,
                height: 22.0
            )
            if let insufficientTextView = self.insufficientText.view {
                if insufficientTextView.superview == nil {
                    self.addSubview(insufficientTextView)
                }
                transition.setFrame(
                    view: insufficientTextView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - insufficientTextSize.width) / 2.0),
                        y: insufficientSlotFrame.minY + floorToScreenPixels((insufficientSlotFrame.height - insufficientTextSize.height) / 2.0),
                        width: insufficientTextSize.width,
                        height: insufficientTextSize.height
                    )
                )
                transition.setAlpha(view: insufficientTextView, alpha: isInsufficient ? 1.0 : 0.0)
            }

            //TODO:localize
            let depositTitle = "Deposit funds"
            let depositY: CGFloat
            if isInsufficient {
                depositY = insufficientSlotFrame.maxY + 4.0
            } else {
                depositY = usableBottom - 68.0
            }
            let showDeposit = isInsufficient || (!hasAmount && !hasPositiveBalance)
            let depositItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: depositTitle,
                            font: Font.regular(13.0),
                            textColor: theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "arrow",
                    component: AnyComponent(BundleIconComponent(
                        name: "Item List/InlineTextRightArrow",
                        tintColor: theme.list.itemAccentColor,
                        maxSize: CGSize(width: 8.0, height: 14.0)
                    ))
                )
            ]
            let depositButtonSize = self.depositButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack(depositItems, spacing: 3.0)),
                    minSize: CGSize(width: availableSize.width - 32.0, height: 40.0),
                    action: { [weak self] in
                        self?.openReceive()
                    },
                    isEnabled: showDeposit
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 40.0)
            )
            let depositButtonFrame = CGRect(
                x: 16.0,
                y: depositY,
                width: depositButtonSize.width,
                height: depositButtonSize.height
            )
            if let depositButtonView = self.depositButton.view {
                if depositButtonView.superview == nil {
                    self.addSubview(depositButtonView)
                }
                transition.setFrame(view: depositButtonView, frame: depositButtonFrame)
                transition.setAlpha(view: depositButtonView, alpha: showDeposit ? 1.0 : 0.0)
            }

            if component.peer != nil, let comment = self.comment {
                var commentTransition = transition
                if self.commentText.view?.superview == nil {
                    commentTransition = .immediate
                }

                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }

                self.commentBackgroundView.image = messageBubbleImage(
                    maxCornerRadius: presentationData.chatBubbleCorners.mainRadius,
                    minCornerRadius: presentationData.chatBubbleCorners.auxiliaryRadius,
                    incoming: false,
                    fillColor: theme.list.itemSecondaryTextColor,
                    strokeColor: theme.list.itemSecondaryTextColor,
                    neighbors: .none,
                    shadow: nil,
                    wallpaper: presentationData.chatWallpaper,
                    knockout: false,
                    onlyOutline: true
                )
                let commentSize = self.commentText.update(
                    transition: commentTransition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: comment,
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 120.0, height: 24.0)
                )
                let bubbleSize = CGSize(width: commentSize.width + 34.0, height: max(34.0, commentSize.height + 14.0))
                let commentOriginY: CGFloat
                if isInsufficient {
                    commentOriginY = depositButtonFrame.maxY + 8.0
                } else {
                    commentOriginY = rateButtonFrame.maxY + 15.0
                }
                let bubbleFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - bubbleSize.width) / 2.0 + 3.0),
                    y: commentOriginY,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )
                commentTransition.setFrame(view: self.commentBackgroundView, frame: bubbleFrame)
                if let commentTextView = self.commentText.view {
                    if commentTextView.superview == nil {
                        self.addSubview(commentTextView)
                    }
                    commentTransition.setFrame(
                        view: commentTextView,
                        frame: CGRect(
                            x: bubbleFrame.minX + 12.0,
                            y: bubbleFrame.minY + floorToScreenPixels((bubbleFrame.height - commentSize.height) / 2.0),
                            width: commentSize.width,
                            height: commentSize.height
                        )
                    )
                    transition.setAlpha(view: commentTextView, alpha: 1.0)
                }
                transition.setAlpha(view: self.commentBackgroundView, alpha: 1.0)
            } else {
                transition.setAlpha(view: self.commentBackgroundView, alpha: 0.0)
                if let commentTextView = self.commentText.view {
                    transition.setAlpha(view: commentTextView, alpha: 0.0)
                }
            }

            let formattedBalance: String
            if let balance = self.walletBalance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                //TODO:localize
                let unavailableBalance = "—"
                formattedBalance = unavailableBalance
            }
            //TODO:localize
            let balancePrefix = "Balance: "
            //TODO:localize
            let balanceSuffix = " Grams"
            let balanceText = balancePrefix + formattedBalance + balanceSuffix

            let sendButtonY = usableBottom - 68.0
            let showBalance = hasAmount || hasPositiveBalance
            let balanceTextSize = self.balanceText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: balanceText,
                        font: Font.regular(13.0),
                        textColor: theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            if let balanceTextView = self.balanceText.view {
                if balanceTextView.superview == nil {
                    self.addSubview(balanceTextView)
                }
                transition.setFrame(
                    view: balanceTextView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - balanceTextSize.width) / 2.0),
                        y: sendButtonY - 42.0 + floorToScreenPixels((24.0 - balanceTextSize.height) / 2.0),
                        width: balanceTextSize.width,
                        height: balanceTextSize.height
                    )
                )
                transition.setAlpha(view: balanceTextView, alpha: showBalance ? 1.0 : 0.0)
            }

            let amountTitle: String
            if self.inputMode == .fiat, self.currentRate != nil {
                amountTitle = walletSendInputText(
                    amount: self.amount,
                    mode: .fiat,
                    rate: self.currentRate,
                    dateTimeFormat: environment.dateTimeFormat
                ) + " " + self.currentFiatCurrency.rawValue
            } else {
                amountTitle = formatTonAmountText(
                    self.amount,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: 9,
                    formatString: environment.strings.Currency_Grams
                )
            }

            let sendTitle: String
            if component.peer == nil {
                //TODO:localize
                sendTitle = "Continue"
            } else {
                //TODO:localize
                let sendPrefix = "Send "
                sendTitle = sendPrefix + amountTitle
            }
            let hasRecipient = !self.recipientAddress.isEmpty
            let canSend = hasAmount
                && hasRecipient
                && !self.isPreparingTransfer
                && !self.walletIsLoading
                && !isInsufficient
                && self.walletBalance != nil
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: sendTitle,
                                font: Font.semibold(17.0),
                                textColor: theme.list.itemCheckColors.foregroundColor
                            )),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 1
                        ))
                    ),
                    isEnabled: canSend,
                    displaysProgress: self.isPreparingTransfer,
                    action: { [weak self] in
                        self?.send()
                    }
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0),
                    height: 52.0
                )
            )
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.addSubview(sendButtonView)
                }
                transition.setFrame(
                    view: sendButtonView,
                    frame: CGRect(
                        x: environment.safeInsets.left + 16.0,
                        y: sendButtonY,
                        width: sendButtonSize.width,
                        height: sendButtonSize.height
                    )
                )
                transition.setAlpha(view: sendButtonView, alpha: hasAmount || !component.initialAddress.isEmpty ? 1.0 : 0.0)
                sendButtonView.isUserInteractionEnabled = hasAmount
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
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletSendScreen: ViewControllerComponentContainer, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {
    }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in
    }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in
    }
    public var cancelPanGesture: () -> Void = {
    }
    public var isContainerPanning: () -> Bool = {
        return false
    }
    public var isContainerExpanded: () -> Bool = {
        return false
    }
    public var mediaPickerContext: AttachmentMediaPickerContext?
    public var isMinimized = false

    public var isPanGestureEnabled: (() -> Bool)? {
        return { [weak self] in
            guard let self,
                  let componentView = self.node.hostView.componentView as? WalletSendScreenComponent.View else {
                return true
            }
            return componentView.isPanGestureEnabled()
        }
    }

    public init(
        context: AccountContext,
        peer: EnginePeer,
        walletContext: WalletContext,
        address: String
    ) {
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                peer: peer,
                initialAddress: address,
                walletContext: walletContext
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    public init(context: AccountContext, walletContext: WalletContext, address: String) {
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                peer: nil,
                initialAddress: address,
                walletContext: walletContext
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WalletSendContextReferenceContentSource: ContextReferenceContentSource {
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
