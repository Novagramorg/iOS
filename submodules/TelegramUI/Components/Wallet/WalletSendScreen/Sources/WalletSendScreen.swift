import Foundation
import UIKit
import AppBundle
import Display
import AccountContext
import TelegramCore
import LocalizedPeerData
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import BundleIconComponent
import MultilineTextComponent
import AnimatedTextComponent
import ButtonComponent
import GlassControls
import PlainButtonComponent
import ContextUI
import AttachmentUI
import AlertComponent
import AlertCheckComponent
import AlertMultilineInputFieldComponent
import WalletContext
import WalletAuthorizationUI
import QrCodeUI
import UndoUI

private enum WalletSendInputMode: Equatable {
    case gram
    case fiat
}

private enum WalletSendAmountSource: Equatable {
    case manual
    case transferLink
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

    func setAmount(_ amount: Int64) {
        self.amount = amount
        guard let dateTimeFormat = self.dateTimeFormat else {
            return
        }
        self.isApplyingText = true
        let inputText = walletSendInputText(
            amount: amount,
            mode: self.mode,
            rate: self.rate,
            dateTimeFormat: dateTimeFormat
        )
        self.textField.attributedText = self.amountAttributedText(inputText)
        self.textField.selectedTextRange = self.textField.textRange(
            from: self.textField.endOfDocument,
            to: self.textField.endOfDocument
        )
        self.isApplyingText = false
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
            suffixText = fiatCurrency.code
        }

        self.gramIconSize = self.gramIcon.update(
            transition: transition,
            component: AnyComponent(BundleIconComponent(
                name: "Wallet/SendGram",
                tintColor: UIColor(rgb: 0x30A1F5),
                maxSize: CGSize(width: 44.0, height: 44.0)
            )),
            environment: {},
            containerSize: CGSize(width: 44.0, height: 74.0)
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
            self.setAmount(amount)
            self.textField.reloadInputViews()
        } else if textColorChanged {
            self.textField.attributedText = self.amountAttributedText(self.textField.text ?? "")
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconLayoutSize = CGSize(width: 40.0, height: 40.0)
        let iconSpacing: CGFloat = self.mode == .fiat ? 0.0 : 2.0
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
        let shouldAppendDecimalSeparator = !replacement.isEmpty && updatedText == "0"
        if shouldAppendDecimalSeparator {
            updatedText += decimalSeparator
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
        if shouldAppendDecimalSeparator {
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
        }
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
    let displaySuccessToast: Bool
    let completed: (() -> Void)?

    init(
        context: AccountContext,
        peer: EnginePeer?,
        initialAddress: String,
        walletContext: WalletContext,
        displaySuccessToast: Bool,
        completed: (() -> Void)?
    ) {
        self.context = context
        self.peer = peer
        self.initialAddress = initialAddress
        self.walletContext = walletContext
        self.displaySuccessToast = displaySuccessToast
        self.completed = completed
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
        if lhs.displaySuccessToast != rhs.displaySuccessToast {
            return false
        }
        return true
    }

    final class View: UIView {
        private enum PeerAddressState {
            case notRequested
            case loading
            case resolved
            case failed
            case errorPresented
            case cancelled
        }

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
        private let peerAddressDisposable = MetaDisposable()
        private var peerAddressState: PeerAddressState = .notRequested
        private var isVisible = false
        private let transferDisposable = MetaDisposable()
        private let signingAccessDisposable = MetaDisposable()
        private let discardTransferDisposables = DisposableSet()
        private var peerPreparedTransfer: WalletContext.PreparedTransfer?
        private var walletInfo: WalletContext.WalletInfo?
        private var walletBalance: Int64?
        private var walletAddress: String?
        private var walletIsLoading = true
        private var isPreparingTransfer = false
        private var isResolvingSigningAccess = false
        private var continueSendingAfterSigningAccess = false
        private weak var recoveryPhraseImportController: ViewController?

        private var inputMode: WalletSendInputMode = .gram
        private var amount: Int64 = 0
        private var amountSource: WalletSendAmountSource = .manual
        private var comment: String?
        private var isCommentPublic = false
        private var currentFiatCurrency: WalletContext.FiatCurrency = .usd
        private var currentRate: Double?
        private var lastRateText = ""
        private var recipientAddress = ""
        private var initialAddress: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.amountField)
            self.amountField.amountUpdated = { [weak self] amount in
                guard let self else {
                    return
                }
                let previousAmount = self.amount
                let previousSendAll = self.shouldSendAll
                self.amountSource = .manual
                self.amount = amount
                if self.inputMode == .gram, !self.validateTransferAmount() {
                    return
                }
                if previousAmount != self.amount || previousSendAll != self.shouldSendAll {
                    self.discardPeerPreparedTransfer()
                }
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
            self.commentBackgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.commentPressed)))
            self.addSubview(self.commentBackgroundView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.discardPeerPreparedTransfer()
            self.walletDisposable.dispose()
            self.peerAddressDisposable.dispose()
            self.transferDisposable.dispose()
            self.signingAccessDisposable.dispose()
            self.discardTransferDisposables.dispose()
        }

        func isPanGestureEnabled() -> Bool {
            return !self.amountField.isInputActive
        }

        func viewDidAppear() {
            self.isVisible = true
            self.resolvePeerAddressIfNeeded()
            self.presentRecipientErrorIfNeeded()
        }

        func viewWillDisappear() {
            self.isVisible = false
        }

        private func resolvePeerAddressIfNeeded() {
            guard self.peerAddressState == .notRequested,
                  let component = self.component,
                  let peer = component.peer else {
                return
            }
            self.peerAddressState = .loading
            self.peerAddressDisposable.set((component.context.engine.wallet.getUserAddresses(
                userIds: [peer.id],
                force: true
            )
            |> deliverOnMainQueue).start(next: { [weak self] addresses in
                self?.completePeerAddressResolution(address: addresses.first(where: { $0.userId == peer.id })?.address)
            }, error: { [weak self] _ in
                self?.completePeerAddressResolution(address: nil)
            }))
        }

        private func completePeerAddressResolution(address: String?) {
            guard self.peerAddressState == .loading,
                  let component = self.component,
                  let peer = component.peer else {
                return
            }
            if let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
                self.peerAddressState = .resolved
                self.recipientAddress = address
                self.discardPeerPreparedTransfer()
                component.walletContext.rememberWalletPeer(peer, address: address)
            } else {
                self.peerAddressState = .failed
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.presentRecipientErrorIfNeeded()
        }

        private func presentRecipientErrorIfNeeded() {
            guard self.isVisible,
                  self.peerAddressState == .failed,
                  let component = self.component,
                  let environment = self.environment,
                  let controller = environment.controller() as? WalletSendScreen else {
                return
            }
            self.peerAddressState = .errorPresented
            //TODO:localize
            let text = "An unknown error occurred. Please try again later."
            controller.present(textAlertController(
                context: component.context,
                title: nil,
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: { [weak self] in
                    self?.dismiss()
                })],
                dismissOnOutsideTap: false
            ), in: .window(.root))
        }

        private var shouldSendAll: Bool {
            guard self.amountSource == .manual, self.amount > 0, let walletBalance = self.walletBalance else {
                return false
            }
            return self.amount == walletBalance
        }

        private func applyRecipient(_ value: String) {
            let previousAddress = self.recipientAddress
            let previousAmount = self.amount
            let previousSendAll = self.shouldSendAll
            let previousComment = self.comment
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
                    self.amountSource = .transferLink
                }
                if let comment = components.queryItems?.first(where: { $0.name == "text" })?.value, !comment.isEmpty {
                    self.comment = comment
                }
            }
            self.recipientAddress = address
            if previousAddress != self.recipientAddress
                || previousAmount != self.amount
                || previousSendAll != self.shouldSendAll
                || previousComment != self.comment {
                self.discardPeerPreparedTransfer()
            }
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
                guard self.validateTransferAmount() else {
                    return
                }
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func dismiss() {
            self.isVisible = false
            self.peerAddressState = .cancelled
            self.peerAddressDisposable.set(nil)
            guard let controller = self.environment?.controller() as? WalletSendScreen else {
                return
            }
            if let parentController = controller.parentController() {
                parentController.dismiss(animated: true)
            } else {
                controller.dismiss()
            }
        }

        @objc private func commentPressed() {
            guard self.component?.peer != nil, let comment = self.comment, !comment.isEmpty else {
                return
            }
            self.showCommentAlert()
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
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess,
                  let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            let inputState = AlertMultilineInputFieldComponent.ExternalState()
            let publicCommentState = AlertCheckComponent.ExternalState()
            let isEditingComment = self.comment?.isEmpty == false
            //TODO:localize
            let title = isEditingComment ? "Edit Comment" : "Add comment"
            //TODO:localize
            let placeholder = "Optional message"
            //TODO:localize
            let publicCommentTitle = "Make comment public"
            //TODO:localize
            let cancel = "Cancel"
            //TODO:localize
            let actionTitle = isEditingComment ? "Save" : "Add"

            let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: title))
                ),
                AnyComponentWithIdentity(
                    id: "input",
                    component: AnyComponent(AlertMultilineInputFieldComponent(
                        context: component.context,
                        initialValue: NSAttributedString(string: self.comment ?? ""),
                        placeholder: placeholder,
                        returnKeyType: .default,
                        keyboardType: .default,
                        autocapitalizationType: .sentences,
                        autocorrectionType: .default,
                        isInitiallyFocused: true,
                        externalState: inputState
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "publicComment",
                    component: AnyComponent(AlertCheckComponent(
                        title: publicCommentTitle,
                        initialValue: self.isCommentPublic,
                        externalState: publicCommentState
                    ))
                )
            ]

            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(allowInputInset: true),
                content: content,
                actions: [
                    AlertScreen.Action(title: cancel),
                    AlertScreen.Action(title: actionTitle, type: .default, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        let value = inputState.value.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        let comment = value.isEmpty ? nil : value
                        if self.comment != comment || self.isCommentPublic != publicCommentState.value {
                            self.discardPeerPreparedTransfer()
                            self.comment = comment
                            self.isCommentPublic = publicCommentState.value
                        }
                        self.componentState?.updated(transition: .spring(duration: 0.35))
                    })
                ]
            )
            controller.present(alertController, in: .window(.root))
        }

        private func openMoreMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller(), !self.isPreparingTransfer else {
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
                let commentActionTitle = self.comment?.isEmpty == false ? "Edit Comment" : "Add comment"
                items.append(.action(ContextMenuActionItem(
                    text: commentActionTitle,
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

        private func validateTransferAmount() -> Bool {
            guard let component = self.component, self.amount > 0 else {
                return true
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            guard self.amount < configuration.transferMinAmount else {
                return true
            }

            self.amount = configuration.transferMinAmount
            self.discardPeerPreparedTransfer()
            self.amountField.setAmount(self.amount)
            self.amountField.layer.addShakeAnimation()
            HapticFeedback().error()
            if !self.isUpdating {
                self.componentState?.updated(transition: .immediate)
            }
            return false
        }

        private func send() {
            guard let component = self.component,
                  self.amount > 0,
                  !self.isPreparingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  let walletInfo = self.walletInfo,
                  let balance = self.walletBalance,
                  self.amount <= balance else {
                return
            }
            guard !self.recipientAddress.isEmpty else {
                return
            }
            guard self.validateTransferAmount() else {
                return
            }
            guard walletInfo.canSign else {
                self.resolveSigningAccess(walletInfo: walletInfo)
                return
            }
            self.performSend(component: component)
        }

        private func resolveSigningAccess(walletInfo: WalletContext.WalletInfo) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  !self.isResolvingSigningAccess else {
                return
            }
            self.continueSendingAfterSigningAccess = false
            if walletInfo.canExportPhrase {
                self.isResolvingSigningAccess = true
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { password in
                        component.walletContext.recoveryPhrase(password: password)
                    },
                    next: { [weak self] _ in
                        guard let self, self.component?.walletContext === component.walletContext else {
                            return
                        }
                        self.isResolvingSigningAccess = false
                        self.continueSendingAfterSigningAccess = true
                        self.resumeSendingAfterSigningAccessIfReady()
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    },
                    failed: { [weak self] error in
                        self?.finishResolvingSigningAccess(error: error)
                    }
                ))
            } else {
                self.presentRecoveryPhraseImportAlert()
            }
        }

        private func resumeSendingAfterSigningAccessIfReady() {
            guard self.continueSendingAfterSigningAccess,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  self.walletInfo?.canSign == true,
                  let component = self.component else {
                return
            }
            self.continueSendingAfterSigningAccess = false
            self.performSend(component: component)
        }

        private func finishResolvingSigningAccess(error: WalletContext.WalletError) {
            self.isResolvingSigningAccess = false
            self.continueSendingAfterSigningAccess = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard error != .authorizationCancelled,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Restore Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func presentRecoveryPhraseImportAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Recovery Phrase Required",
                text: "To send funds, you’ll need to enter your 12- or 24-word recovery phrase to restore access to this wallet.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Proceed", action: { [weak self] in
                        Queue.mainQueue().after(0.25) { [weak self] in
                            self?.openRecoveryPhraseImport()
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let hostController: ViewController
            if controller.navigationController != nil {
                hostController = controller
            } else if let parentController = (controller as? AttachmentContainable)?.parentController(),
                      parentController.navigationController != nil {
                hostController = parentController
            } else {
                return
            }
            let importController = component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport()
                }
            )
            self.recoveryPhraseImportController = importController
            hostController.push(importController)
        }

        private func completeRecoveryPhraseImport() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let importController = self.recoveryPhraseImportController else {
                return
            }
            self.recoveryPhraseImportController = nil
            importController.dismiss(animated: true)
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            Queue.mainQueue().after(0.4) { [weak controller] in
                controller?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: "Wallet Imported",
                        text: "Your wallet was restored from your recovery phrase.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
        }

        private func performSend(component: WalletSendScreenComponent) {
            guard self.amount > 0,
                  !self.isPreparingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  self.walletInfo?.canSign == true,
                  let balance = self.walletBalance,
                  self.amount <= balance,
                  !self.recipientAddress.isEmpty else {
                return
            }
            guard self.validateTransferAmount() else {
                return
            }
            let sendAll = self.shouldSendAll
            if let peer = component.peer {
                self.isPreparingTransfer = true
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                let preparation: Signal<WalletContext.PreparedTransfer, WalletContext.WalletError>
                if let prepared = self.peerPreparedTransfer,
                   prepared.recipient == self.recipientAddress,
                   prepared.requestedAmount == self.amount,
                   prepared.isSendAll == sendAll,
                   prepared.comment == self.comment,
                   prepared.commentEncrypted == (self.comment != nil && !self.isCommentPublic),
                   prepared.collectible == nil,
                   prepared.expiresAt > Int32(clamping: Int64(Date().timeIntervalSince1970)) {
                    preparation = .single(prepared)
                } else {
                    self.discardPeerPreparedTransfer()
                    preparation = component.walletContext.prepareTransfer(
                        address: self.recipientAddress,
                        amount: self.amount,
                        sendAll: sendAll,
                        comment: self.comment,
                        commentEncrypted: !self.isCommentPublic
                    )
                }
                self.transferDisposable.set((preparation
                |> mapToSignal { [weak self] prepared in
                    self?.peerPreparedTransfer = prepared
                    return component.walletContext.submitTransfer(prepared)
                }
                |> deliverOnMainQueue).start(next: { [weak self] pendingTransfer in
                    guard let self, let controller = self.environment?.controller() else {
                        return
                    }
                    self.peerPreparedTransfer = nil
                    self.isPreparingTransfer = false
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))

                    switch pendingTransfer.status {
                    case .submissionUnknown:
                        self.presentSubmissionUnknown(on: controller, context: component.context)
                        component.completed?()
                        controller.dismiss()
                    case .broadcasting, .pending, .confirmed:
                        var navigationController: NavigationController?
                        var parentController: ViewController?
                        if let current = controller.navigationController as? NavigationController {
                            navigationController = current
                        } else if let current = (controller as? AttachmentContainable)?.parentController() {
                            parentController = current
                            navigationController = current.navigationController as? NavigationController
                        }
                        component.completed?()
                        controller.dismiss()
                        if component.displaySuccessToast {
                            Queue.mainQueue().after(0.4, { [weak navigationController] in
                                guard let navigationController else {
                                    return
                                }
                                if let controller = navigationController.viewControllers.reversed().first(where: { $0 !== parentController }) as? ViewController {
                                    self.presentTransferSuccess(on: controller, context: component.context, peer: peer)
                                }
                            })
                        }
                    }
                }, error: { [weak self] error in
                    if error == .preparedTransferExpired || error == .preparedTransferNotFound {
                        self?.discardPeerPreparedTransfer()
                    }
                    self?.isPreparingTransfer = false
                    self?.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self?.presentTransferError(error)
                }))
                return
            }

            guard let controller = self.environment?.controller() else {
                return
            }
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
                component.completed?()
            }
            controller.push(component.context.sharedContext.makeWalletTransactionPreviewScreen(
                context: component.context,
                walletContext: component.walletContext,
                address: self.recipientAddress,
                amount: self.amount,
                sendAll: sendAll,
                comment: self.comment,
                dismissSendScreen: dismissSendScreen
            ))
        }

        private func discardPeerPreparedTransfer() {
            guard let walletContext = self.walletContext,
                  let preparedTransfer = self.peerPreparedTransfer else {
                return
            }
            self.peerPreparedTransfer = nil
            self.discardTransferDisposables.add(
                walletContext.discardPreparedTransfer(preparedTransfer).start()
            )
        }

        private func presentTransferSuccess(on controller: ViewController, context: AccountContext, peer: EnginePeer) {
            //TODO:localize
            let text = "Grams have been sent to **\(peer.compactDisplayTitle)**."
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .emoji(name: "Celebrate", text: text),
                    position: .bottom,
                    action: { _ in
                        return false
                    }
                ),
                in: .current
            )
        }

        private func presentSubmissionUnknown(on controller: ViewController, context: AccountContext) {
            //TODO:localize
            let title = "Transfer Pending"
            //TODO:localize
            let text = "The transfer may have been sent. Don’t send it again while its status is being checked."
            //TODO:localize
            let ok = "OK"
            controller.present(textAlertController(
                context: context,
                title: title,
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: ok, action: {
                })]
            ), in: .window(.root))
        }

        private func presentTransferError(_ error: WalletContext.WalletError? = nil) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let title: String
            let text: String
            switch error {
            case .commentTooLong:
                title = "Comment Too Long"
                text = "The encrypted comment is too long. Shorten it and try again."
            case .commentEncryptionRecipientUnavailable:
                title = "Couldn't Encrypt Comment"
                text = "This user can't receive encrypted messages now."
            case .commentEncryptionFailed:
                title = "Couldn't Encrypt Comment"
                text = "The comment could not be encrypted for this wallet. Check the network connection and try again."
            default:
                title = "Transfer Failed"
                text = "The transfer could not be prepared or sent. Check the address, balance and network connection, then try again."
            }
            //TODO:localize
            let ok = "OK"
            controller.present(textAlertController(
                context: component.context,
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
                }
                shouldFocusAmountField = component.peer != nil || !component.initialAddress.isEmpty
            }

            if self.walletContext !== component.walletContext {
                self.discardPeerPreparedTransfer()
                self.walletContext = component.walletContext
                self.signingAccessDisposable.set(nil)
                self.walletInfo = nil
                self.walletBalance = nil
                self.walletAddress = nil
                self.walletIsLoading = true
                self.isResolvingSigningAccess = false
                self.continueSendingAfterSigningAccess = false
                self.currentFiatCurrency = .usd
                self.currentRate = nil
                self.inputMode = .gram
                let observedWalletContext = component.walletContext
                self.walletDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === observedWalletContext else {
                        return
                    }
                    let previousSendAll = self.shouldSendAll
                    self.walletBalance = walletState.balance.currentValue
                    if previousSendAll != self.shouldSendAll {
                        self.discardPeerPreparedTransfer()
                    }
                    if case let .wallet(info) = walletState.phase {
                        self.walletInfo = info
                        self.walletAddress = info.address
                    } else {
                        self.walletInfo = nil
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
                    self.resumeSendingAfterSigningAccessIfReady()
                    if !self.isUpdating {
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    }
                }))
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.modalPlainBackgroundColor

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
                    let fiatSwitchSuffix = " \(self.currentFiatCurrency.code)"
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
            if showRate {
                self.lastRateText = rateText
            }
            let rateItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.with(size: 13.0, design: .round, weight: .semibold),
                        color: theme.list.itemSecondaryTextColor,
                        items: [
                            AnimatedTextComponent.Item(id: "rate", content: .text(self.lastRateText))
                        ],
                        noDelay: true
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
                transition: .easeInOut(duration: 0.2),
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
                var rateVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if rateButtonView.superview == nil {
                    self.addSubview(rateButtonView)
                    rateVisibilityTransition = .immediate
                }
                rateButtonView.bounds = CGRect(origin: .zero, size: rateButtonFrame.size)
                transition.setPosition(view: rateButtonView, position: rateButtonFrame.center)
                rateVisibilityTransition.setAlpha(view: rateButtonView, alpha: showRate ? 1.0 : 0.0)
                rateVisibilityTransition.setScale(view: rateButtonView, scale: showRate ? 1.0 : 0.01)
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
                var insufficientVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if insufficientTextView.superview == nil {
                    self.addSubview(insufficientTextView)
                    insufficientVisibilityTransition = .immediate
                }
                ComponentTransition.immediate.setFrame(
                    view: insufficientTextView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - insufficientTextSize.width) / 2.0),
                        y: insufficientSlotFrame.minY + floorToScreenPixels((insufficientSlotFrame.height - insufficientTextSize.height) / 2.0),
                        width: insufficientTextSize.width,
                        height: insufficientTextSize.height
                    )
                )
                insufficientVisibilityTransition.setAlpha(view: insufficientTextView, alpha: isInsufficient ? 1.0 : 0.0)
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
                let isNewlyAdded = depositButtonView.superview == nil
                var depositVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if depositButtonView.superview == nil {
                    self.addSubview(depositButtonView)
                    depositVisibilityTransition = .immediate
                }
                if isNewlyAdded || showDeposit {
                    ComponentTransition.immediate.setFrame(view: depositButtonView, frame: depositButtonFrame)
                }
                depositVisibilityTransition.setAlpha(view: depositButtonView, alpha: showDeposit ? 1.0 : 0.0)
            }

            if component.peer != nil, let comment = self.comment, !comment.isEmpty {
                let isInitialCommentLayout = self.commentText.view?.superview == nil
                var commentTransition = transition
                if isInitialCommentLayout {
                    commentTransition = .immediate
                }
                let commentPositionTransition: ComponentTransition = isInitialCommentLayout ? .immediate : .easeInOut(duration: 0.2)

                self.commentBackgroundView.isUserInteractionEnabled = true

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
                        horizontalAlignment: .natural,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 120.0, height: 1000.0)
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
                ComponentTransition.immediate.setBounds(
                    view: self.commentBackgroundView,
                    bounds: CGRect(origin: .zero, size: bubbleFrame.size)
                )
                commentPositionTransition.setPosition(view: self.commentBackgroundView, position: bubbleFrame.center)
                if let commentTextView = self.commentText.view {
                    if commentTextView.superview == nil {
                        commentTextView.isUserInteractionEnabled = false
                        self.addSubview(commentTextView)
                    }
                    let commentTextFrame = CGRect(
                        x: bubbleFrame.minX + 12.0,
                        y: bubbleFrame.minY + floorToScreenPixels((bubbleFrame.height - commentSize.height) / 2.0),
                        width: commentSize.width,
                        height: commentSize.height
                    )
                    ComponentTransition.immediate.setBounds(
                        view: commentTextView,
                        bounds: CGRect(origin: .zero, size: commentTextFrame.size)
                    )
                    commentPositionTransition.setPosition(view: commentTextView, position: commentTextFrame.center.offsetBy(dx: 2.0 - UIScreenPixel, dy: 0.0))
                    transition.setAlpha(view: commentTextView, alpha: 1.0)
                }
                transition.setAlpha(view: self.commentBackgroundView, alpha: 1.0)
            } else {
                self.commentBackgroundView.isUserInteractionEnabled = false
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

            var sendIdentifier: String
            let amountTitle: String
            if self.inputMode == .fiat, self.currentRate != nil {
                if self.amount > 0 {
                    amountTitle = walletSendInputText(
                        amount: self.amount,
                        mode: .fiat,
                        rate: self.currentRate,
                        dateTimeFormat: environment.dateTimeFormat
                    ) + " " + self.currentFiatCurrency.code
                } else {
                    amountTitle = self.currentFiatCurrency.code
                }
                sendIdentifier = "fiat"
            } else {
                if self.amount > 0 {
                    amountTitle = formatTonAmountText(
                        self.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 9,
                        formatString: environment.strings.Currency_Grams
                    )
                } else {
                    amountTitle = "Grams"
                }
                sendIdentifier = "grams"
            }

            let sendTitle: String
            if component.peer == nil {
                //TODO:localize
                sendTitle = "Continue"
                sendIdentifier = "continue"
            } else {
                //TODO:localize
                let sendPrefix = "Send "
                sendTitle = sendPrefix + amountTitle
            }
            let hasRecipient = !self.recipientAddress.isEmpty
            let isResolvingPeerAddress = component.peer != nil
                && (self.peerAddressState == .notRequested || self.peerAddressState == .loading)
            let canSend = hasAmount
                && hasRecipient
                && !self.isPreparingTransfer
                && !self.isResolvingSigningAccess
                && !self.walletIsLoading
                && !isInsufficient
                && self.walletInfo != nil
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
                        id: sendIdentifier,
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
                    displaysProgress: isResolvingPeerAddress || self.isResolvingSigningAccess || (component.peer != nil && self.isPreparingTransfer),
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
                transition.setAlpha(view: sendButtonView, alpha: hasAmount || component.peer != nil || !component.initialAddress.isEmpty ? 1.0 : 0.0)
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
    private let walletContext: WalletContext
    private var balanceRefreshDisposable: Disposable?
    private var refreshBalanceOnOpen: Bool

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
        refreshBalanceOnOpen: Bool = true,
        displaySuccessToast: Bool = true,
        completed: (() -> Void)? = nil
    ) {
        self.walletContext = walletContext
        self.refreshBalanceOnOpen = refreshBalanceOnOpen
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                peer: peer,
                initialAddress: "",
                walletContext: walletContext,
                displaySuccessToast: displaySuccessToast,
                completed: completed
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        address: String,
        refreshBalanceOnOpen: Bool = true,
        completed: (() -> Void)? = nil
    ) {
        self.walletContext = walletContext
        self.refreshBalanceOnOpen = refreshBalanceOnOpen
        super.init(
            context: context,
            component: WalletSendScreenComponent(
                context: context,
                peer: nil,
                initialAddress: address,
                walletContext: walletContext,
                displaySuccessToast: true,
                completed: completed
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.refreshBalanceOnOpen {
            self.refreshBalanceOnOpen = false
            self.balanceRefreshDisposable = self.walletContext.refreshBalance()
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.balanceRefreshDisposable?.dispose()
        self.balanceRefreshDisposable = nil
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewDidAppear()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewWillDisappear()

        super.viewWillDisappear(animated)
    }

    deinit {
        self.balanceRefreshDisposable?.dispose()
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
