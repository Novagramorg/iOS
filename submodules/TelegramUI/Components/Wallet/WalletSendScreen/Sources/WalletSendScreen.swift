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
import PasscodeCore
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

private enum WalletSendFeeDisplayState: Equatable {
    case hidden
    case loading
    case value(Int64)
    case unavailable
}

private struct WalletSendFeeRequest: Equatable {
    let address: String
    let publicKey: Data?
    let amount: Int64
    let sendAll: Bool
    let comment: String?
    let commentEncrypted: Bool
    let balance: Int64
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
        let keyboardAppearance: UIKeyboardAppearance = theme.overallDarkAppearance ? .dark : .light
        if self.textField.keyboardAppearance != keyboardAppearance {
            self.textField.keyboardAppearance = keyboardAppearance
            if self.textField.isFirstResponder {
                self.textField.reloadInputViews()
            }
        }
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

@MainActor
private func walletPresentTransferSuccess(on controller: ViewController, context: AccountContext, peer: EnginePeer) {
    //TODO:localize
    let text = "Grams have been sent to **\(peer.compactDisplayTitle)**."
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    controller.present(
        UndoOverlayController(
            presentationData: presentationData,
            content: .emoji(name: "Celebrate", text: text, interactive: true),
            position: .bottom,
            action: { [weak controller] action in
                guard case .info = action,
                      let navigationController = controller?.navigationController as? NavigationController else {
                    return false
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    chatController: nil,
                    context: context,
                    chatLocation: .peer(peer),
                    subject: nil,
                    botStart: nil,
                    updateTextInputState: nil,
                    keepStack: .always,
                    useExisting: true,
                    purposefulAction: nil,
                    scrollToEndIfExists: false,
                    activateMessageSearch: nil,
                    animated: true
                ))
                return true
            }
        ),
        in: .current
    )
}

@MainActor
private func walletPresentSubmissionUnknown(on controller: ViewController, context: AccountContext) -> ViewController {
    //TODO:localize
    let title = "Transfer Pending"
    //TODO:localize
    let text = "The transfer may have been sent. Don’t send it again while its status is being checked."
    //TODO:localize
    let ok = "OK"
    let alert = textAlertController(
        context: context,
        title: title,
        text: text,
        actions: [TextAlertAction(type: .defaultAction, title: ok, action: {
        })]
    )
    controller.present(alert, in: .window(.root))
    return alert
}

@MainActor
private func walletPresentTransferError(_ error: WalletContext.WalletError?, on controller: ViewController, context: AccountContext) {
    guard error != .authorizationCancelled else { return }
    //TODO:localize
    let title: String
    let text: String
    switch error {
    case .commentTooLong:
        title = "Comment Too Long"
        text = "The encrypted comment is too long. Shorten it and try again."
    case .commentEncryptionRecipientUnavailable:
        title = "Couldn't Encrypt Comment"
        text = "This wallet can't receive encrypted comments now."
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
        context: context,
        title: title,
        text: text,
        actions: [TextAlertAction(type: .defaultAction, title: ok, action: {
        })]
    ), in: .window(.root))
}

@MainActor
fileprivate final class WalletPeerTransferSubmission {
    private let context: AccountContext
    private let peer: EnginePeer
    private let displaySuccessToast: Bool
    private weak var controller: WalletSendScreen?
    private weak var navigationController: NavigationController?
    private weak var parentController: ViewController?
    private weak var walletContext: WalletContext?
    private var commentSession: PasscodeSession?
    private weak var submissionUnknownController: ViewController?
    private var walletAddress: String?
    private let observationDisposable = MetaDisposable()
    private var hasObservedTransfer = false
    private var confirmationObserved = false
    private var observationStopped = false
    private var isInvalidated = false
    private let closeForm: () -> Void
    private let presentErrorOnForm: (WalletContext.WalletError) -> Bool
    private var closeRequested = false
    private var isClosingForm = false
    private var formDisappeared = false
    private var result: Result<WalletContext.PendingTransfer, WalletContext.WalletError>?
    private var resultPresentationRequested = false
    private var successPresentationRequested = false

    init(
        context: AccountContext,
        peer: EnginePeer,
        displaySuccessToast: Bool,
        controller: WalletSendScreen,
        closeForm: @escaping () -> Void,
        presentErrorOnForm: @escaping (WalletContext.WalletError) -> Bool
    ) {
        self.context = context
        self.peer = peer
        self.displaySuccessToast = displaySuccessToast
        self.controller = controller
        self.closeForm = closeForm
        self.presentErrorOnForm = presentErrorOnForm
        if let navigationController = controller.navigationController as? NavigationController {
            self.navigationController = navigationController
        } else if let parentController = controller.parentController() {
            self.parentController = parentController
            self.navigationController = parentController.navigationController as? NavigationController
        }
        controller.peerTransferSubmission = self
    }

    func start(walletContext: WalletContext, prepared: WalletContext.PreparedTransfer, session: PasscodeSession?) {
        self.walletContext = walletContext
        self.commentSession = session
        if case let .wallet(info) = walletContext.stateValue.phase {
            self.walletAddress = info.address
        }
        self.observationDisposable.set((combineLatest(
            walletContext.state,
            self.context.sharedContext.activeAccountContexts
        )
        |> deliverOnMainQueue).start(next: { [self] state, accounts in
            guard !self.observationStopped else { return }
            guard accounts.primary?.account.id == self.context.account.id,
                  case let .wallet(info) = state.phase,
                  info.address == self.walletAddress else {
                self.invalidate()
                return
            }
            let transaction = state.transactions.items.first(where: {
                $0.presentationId == "pending:\(prepared.id)"
            })
            let hasTransfer = transaction != nil || state.pendingTransfers.contains(where: { $0.id == prepared.id })
            if transaction?.status == .completed {
                self.confirmationObserved = true
                self.stopObserving()
                self.presentResultIfReady()
            } else if transaction?.status == .failed || (self.hasObservedTransfer && !hasTransfer) {
                self.stopObserving()
            }
            self.hasObservedTransfer = self.hasObservedTransfer || hasTransfer
        }))

        let _ = walletContext.submitTransfer(prepared, recipientPeerId: self.peer.id, pendingMessageCreated: { [weak self] in
            self?.pendingMessageCreated()
        }, session: session).startStandalone(next: { [self] pending in
            self.finish(.success(pending))
        }, error: { [self] error in
            self.finish(.failure(error))
        })
    }

    private func withCurrentAccount(_ action: @escaping () -> Void) {
        guard !self.isInvalidated else { return }
        let _ = (self.context.sharedContext.activeAccountContexts
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [self] primary, _, _ in
            guard !self.isInvalidated else { return }
            guard primary?.account.id == self.context.account.id,
                  let walletContext = self.walletContext,
                  case let .wallet(info) = walletContext.stateValue.phase,
                  info.address == self.walletAddress else {
                self.invalidate()
                return
            }
            action()
        })
    }

    private func pendingMessageCreated() {
        self.withCurrentAccount { [self] in
            guard self.result == nil else { return }
            self.closeRequested = true
            self.closeFormIfNeeded()
        }
    }

    func formWillDisappear() {
        self.isClosingForm = true
    }

    func formDidDisappear() {
        self.formDisappeared = true
        self.presentResultIfReady()
    }

    func formDidAppear() {
        self.isClosingForm = false
        self.withCurrentAccount { [self] in
            if self.closeRequested {
                self.closeFormIfNeeded()
            }
            self.presentResultIfReady()
        }
    }

    private func closeFormIfNeeded() {
        guard !self.isClosingForm, !self.formDisappeared else { return }
        self.isClosingForm = true
        if self.controller == nil {
            self.formDisappeared = true
        } else {
            self.closeForm()
        }
    }

    private func finish(_ result: Result<WalletContext.PendingTransfer, WalletContext.WalletError>) {
        guard self.result == nil else { return }
        self.commentSession?.invalidate()
        self.commentSession = nil
        self.result = result
        if case .failure = result {
            self.stopObserving()
        }
        self.withCurrentAccount { [self] in
            if case .success = result {
                self.closeRequested = true
                self.closeFormIfNeeded()
            }
            self.presentResultIfReady()
        }
    }

    private func presentResultIfReady() {
        if self.controller == nil {
            self.formDisappeared = true
        }
        guard !self.isInvalidated,
              !self.isClosingForm || self.formDisappeared else { return }
        if self.confirmationObserved {
            guard self.formDisappeared, !self.successPresentationRequested else { return }
            self.successPresentationRequested = true
            self.withCurrentAccount { [self] in
                self.detachFromForm()
                self.dismissSubmissionUnknown()
                if self.displaySuccessToast, let presenter = self.resultPresenter {
                    walletPresentTransferSuccess(on: presenter, context: self.context, peer: self.peer)
                }
            }
            return
        }
        guard let result = self.result, !self.resultPresentationRequested else { return }
        self.resultPresentationRequested = true
        self.withCurrentAccount { [self] in
            guard !self.confirmationObserved else {
                self.presentResultIfReady()
                return
            }
            self.detachFromForm()
            if case let .failure(error) = result, !self.formDisappeared,
               self.presentErrorOnForm(error) {
                return
            }
            guard let presenter = self.resultPresenter else { return }
            switch result {
            case let .success(pending):
                if pending.status == .submissionUnknown, !self.observationStopped {
                    self.submissionUnknownController = walletPresentSubmissionUnknown(on: presenter, context: self.context)
                }
            case let .failure(error):
                walletPresentTransferError(error, on: presenter, context: self.context)
            }
        }
    }

    private var resultPresenter: ViewController? {
        let navigationController = self.navigationController
            ?? self.context.sharedContext.mainWindow?.viewController as? NavigationController
        return navigationController?.viewControllers.reversed().first(where: {
            $0 !== self.controller && $0 !== self.parentController
        }) as? ViewController
    }

    private func stopObserving() {
        self.observationStopped = true
        self.observationDisposable.dispose()
    }

    private func dismissSubmissionUnknown() {
        self.submissionUnknownController?.dismiss()
        self.submissionUnknownController = nil
    }

    private func invalidate() {
        self.isInvalidated = true
        self.stopObserving()
        self.dismissSubmissionUnknown()
        self.detachFromForm()
    }

    private func detachFromForm() {
        if self.controller?.peerTransferSubmission === self {
            self.controller?.peerTransferSubmission = nil
        }
    }
}

private final class WalletSendScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let peer: EnginePeer?
    let initialAddress: String
    let initialAmountNanograms: Int64?
    let walletContext: WalletContext
    let displaySuccessToast: Bool
    let completed: (() -> Void)?

    init(
        context: AccountContext,
        peer: EnginePeer?,
        initialAddress: String,
        initialAmountNanograms: Int64?,
        walletContext: WalletContext,
        displaySuccessToast: Bool,
        completed: (() -> Void)?
    ) {
        self.context = context
        self.peer = peer
        self.initialAddress = initialAddress
        self.initialAmountNanograms = initialAmountNanograms
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
        if lhs.initialAmountNanograms != rhs.initialAmountNanograms {
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
        private let feeText = ComponentView<Empty>()
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
        private var restorationSession: PasscodeSession?
        private var restorationGeneration = 0
        private let discardTransferDisposables = DisposableSet()
        private var cachedPreparedTransfer: WalletContext.PreparedTransfer?
        private var submittingTransfer: WalletContext.PreparedTransfer?
        private var feeRequest: WalletSendFeeRequest?
        private var feeRevision = 0
        private var isEstimatingFee = false
        private var feePreparationFailed = false
        private var commentSession: PasscodeSession?
        private var commentSessionGeneration = 0
        private var commentSessionAvailable = true
        private var isAuthorizingComment = false
        private let commentSessionDisposable = MetaDisposable()
        private let commentEnvironmentDisposable = MetaDisposable()
        private let commentCredentialChangesDisposable = MetaDisposable()
        private var walletInfo: WalletContext.WalletInfo?
        private var walletBalance: Int64?
        private var gaslessInfo: WalletContext.Resource<WalletGaslessInfo> = .idle
        private var walletAddress: String?
        private var walletIsLoading = true
        private var isPreparingTransfer = false
        private var isSubmittingTransfer = false
        private var isResolvingSigningAccess = false
        private var continueSendingAfterSigningAccess = false
        private weak var recoveryPhraseImportController: ViewController?

        private var inputMode: WalletSendInputMode = .gram
        private var amount: Int64 = 0
        private var amountSource: WalletSendAmountSource = .manual
        private var didApplyInitialAmount = false
        private var comment: String?
        private var isCommentPublic = false
        private var currentFiatCurrency: WalletContext.FiatCurrency = .usd
        private var currentRate: Double?
        private var lastRateText = ""
        private var recipientAddress = ""
        private var recipientPublicKey: Data?
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
                    self.invalidateFeePreparation()
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

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // PlainButtonComponent expands its hit area by 8 pt; keep it off the adjacent error text.
            if let insufficientTextView = self.insufficientText.view,
               insufficientTextView.alpha > 0.0, insufficientTextView.frame.contains(point) {
                return self
            }
            return super.hitTest(point, with: event)
        }

        deinit {
            self.restorationSession?.invalidate()
            self.commentSession?.invalidate()
            self.commentSessionDisposable.dispose()
            self.commentEnvironmentDisposable.dispose()
            self.commentCredentialChangesDisposable.dispose()
            self.invalidateFeePreparation()
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
            self.feePreparationFailed = false
            self.updateFeePreparation()
            self.componentState?.updated(transition: .immediate)
        }

        func viewWillDisappear() {
            self.isVisible = false
            if !self.isSubmittingTransfer {
                self.invalidateFeePreparation()
            }
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
                guard let self, self.component?.walletContext === component.walletContext else {
                    return
                }
                self.completePeerAddressResolution(peerId: peer.id, recipient: addresses.first(where: { $0.userId == peer.id }))
            }, error: { [weak self] _ in
                guard let self, self.component?.walletContext === component.walletContext else {
                    return
                }
                self.completePeerAddressResolution(peerId: peer.id, recipient: nil)
            }))
        }

        private func completePeerAddressResolution(peerId: EnginePeer.Id, recipient: WalletUserAddress?) {
            guard self.peerAddressState == .loading,
                  let component = self.component,
                  let peer = component.peer, peer.id == peerId else {
                return
            }
            let address = recipient?.address.trimmingCharacters(in: .whitespacesAndNewlines)
            if let recipient, let address, !address.isEmpty {
                self.peerAddressState = .resolved
                self.updateRecipient(address: address, publicKey: recipient.publicKey)
                component.walletContext.rememberWalletPeer(peer, address: address)
            } else {
                self.updateRecipient(address: "", publicKey: nil)
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

        private var commentEncrypted: Bool {
            return self.component?.peer != nil && self.comment != nil && !self.isCommentPublic
        }

        private var currentFeeRequest: WalletSendFeeRequest? {
            guard self.walletInfo?.canSign == true,
                  let balance = self.walletBalance,
                  self.amount > 0, self.amount <= balance,
                  !self.recipientAddress.isEmpty else {
                return nil
            }
            return WalletSendFeeRequest(
                address: self.recipientAddress,
                publicKey: self.recipientPublicKey,
                amount: self.amount,
                sendAll: self.shouldSendAll,
                comment: self.comment,
                commentEncrypted: self.commentEncrypted,
                balance: balance
            )
        }

        private func feesAreCovered(amount: Int64) -> Bool {
            guard let component = self.component else {
                return false
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            return WalletContext.isGaslessEligible(
                amount: amount,
                gaslessInfo: self.gaslessInfo.currentValue,
                minimumAmount: configuration.transferGaslessMinAmount
            )
        }

        private func preparedTransfer(for request: WalletSendFeeRequest) -> WalletContext.PreparedTransfer? {
            guard self.feeRequest == request,
                  let prepared = self.cachedPreparedTransfer,
                  TimeInterval(prepared.expiresAt) > Date().timeIntervalSince1970,
                  !request.commentEncrypted || self.commentSession?.isValid == true else {
                return nil
            }
            return prepared
        }

        private var feeDisplayState: WalletSendFeeDisplayState {
            guard self.amount > 0 else { return .hidden }
            if case .stale = self.gaslessInfo { return .unavailable }
            guard self.gaslessInfo.currentValue != nil else { return .loading }
            if !self.shouldSendAll && self.feesAreCovered(amount: self.amount) { return .hidden }
            if let prepared = self.submittingTransfer ?? self.currentFeeRequest.flatMap({ self.preparedTransfer(for: $0) }) {
                if self.feesAreCovered(amount: prepared.amount) || prepared.fee == 0 { return .hidden }
                return .value(prepared.fee)
            }
            if self.feePreparationFailed || (self.commentEncrypted && self.commentSession?.isValid != true && !self.isAuthorizingComment) {
                return .unavailable
            }
            if self.peerAddressState == .failed || self.peerAddressState == .errorPresented || self.peerAddressState == .cancelled {
                return .unavailable
            }
            if !self.walletIsLoading && self.currentFeeRequest == nil { return .unavailable }
            return .loading
        }

        private func updateFeePreparation() {
            guard self.isVisible, self.commentSessionAvailable, !self.isSubmittingTransfer, !self.isAuthorizingComment else { return }
            let request = self.currentFeeRequest
            if self.feeRequest != request {
                self.invalidateFeePreparation()
                self.feeRequest = request
            }
            guard let request, !self.isPreparingTransfer,
                  !self.isEstimatingFee, !self.feePreparationFailed else { return }
            if self.preparedTransfer(for: request) != nil { return }
            guard request.sendAll || !self.feesAreCovered(amount: request.amount) else { return }
            guard !request.commentEncrypted || self.commentSession?.isValid == true else { return }

            self.isEstimatingFee = true
            let revision = self.feeRevision
            Queue.mainQueue().after(0.4) { [weak self] in
                guard let self, self.feeRevision == revision, self.feeRequest == request else { return }
                self.prepareFee(request: request, revision: revision)
            }
        }

        private func prepareFee(request: WalletSendFeeRequest, revision: Int) {
            guard let walletContext = self.walletContext,
                  self.isVisible, self.commentSessionAvailable,
                  self.feeRevision == revision, self.currentFeeRequest == request else { return }
            guard !request.commentEncrypted || self.commentSession?.isValid == true else {
                self.invalidateCommentSession()
                self.componentState?.updated(transition: .immediate)
                return
            }
            self.discardCachedTransfer()
            self.isEstimatingFee = true
            self.feePreparationFailed = false
            let session = request.commentEncrypted ? self.commentSession : nil
            self.transferDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> mapToSignal { _ in
                return walletContext.prepareTransfer(
                    address: request.address,
                    amount: request.amount,
                    sendAll: request.sendAll,
                    comment: request.comment,
                    commentEncrypted: request.commentEncrypted,
                    recipientPublicKey: request.publicKey,
                    session: session
                )
            }
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self, self.walletContext === walletContext,
                      self.isVisible, self.feeRevision == revision, self.currentFeeRequest == request else {
                    let _ = walletContext.discardPreparedTransfer(prepared).startStandalone()
                    return
                }
                self.isEstimatingFee = false
                self.discardCachedTransfer()
                self.cachedPreparedTransfer = prepared
                if self.isPreparingTransfer {
                    self.completePreparedSend(prepared)
                } else {
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    let delay = max(0.0, TimeInterval(prepared.expiresAt) - Date().timeIntervalSince1970)
                    Queue.mainQueue().after(delay) { [weak self] in
                        guard let self, self.cachedPreparedTransfer?.id == prepared.id, !self.isSubmittingTransfer else { return }
                        self.invalidateFeePreparation()
                        self.updateFeePreparation()
                        self.componentState?.updated(transition: .immediate)
                    }
                }
            }, error: { [weak self] error in
                guard let self, self.walletContext === walletContext, self.feeRevision == revision else { return }
                let wasSending = self.isPreparingTransfer
                self.isEstimatingFee = false
                self.isPreparingTransfer = false
                self.feePreparationFailed = true
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                if wasSending { self.presentTransferError(error) }
            }))
        }

        fileprivate func invalidateCommentSession() {
            self.commentSessionGeneration &+= 1
            self.commentSessionDisposable.set(nil)
            self.commentSession?.invalidate()
            self.commentSession = nil
            self.isAuthorizingComment = false
            if self.commentEncrypted && !self.isSubmittingTransfer {
                self.invalidateFeePreparation()
            }
        }

        private func installCommentSession(_ session: PasscodeSession) {
            self.commentSession = session
            guard let expiresAt = session.expiresAt else { return }
            let delay = max(0.0, expiresAt - ProcessInfo.processInfo.systemUptime)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak session] in
                guard let self, let session, self.commentSession === session else { return }
                self.invalidateCommentSession()
                self.componentState?.updated(transition: .immediate)
            }
        }

        private func requestCommentSession(forSend: Bool) {
            guard !self.isAuthorizingComment, self.commentSessionAvailable,
                  let walletContext = self.walletContext else { return }
            if self.commentSession?.isValid == true {
                self.updateFeePreparation()
                return
            }
            self.invalidateCommentSession()
            let generation = self.commentSessionGeneration
            self.isAuthorizingComment = true
            self.isPreparingTransfer = forSend
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.commentSessionDisposable.set(walletContext.beginCommentEncryptionSession().start(next: { [weak self] session in
                guard let self, self.commentSessionGeneration == generation,
                      self.commentSessionAvailable, self.walletContext === walletContext else {
                    session.invalidate()
                    return
                }
                let shouldSend = forSend && self.isPreparingTransfer
                self.isAuthorizingComment = false
                self.isPreparingTransfer = false
                self.installCommentSession(session)
                if shouldSend, let component = self.component {
                    self.performSend(component: component)
                } else {
                    self.updateFeePreparation()
                }
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }, error: { [weak self] error in
                guard let self, self.commentSessionGeneration == generation else { return }
                self.isAuthorizingComment = false
                self.isPreparingTransfer = false
                self.feeRequest = self.currentFeeRequest
                self.feePreparationFailed = true
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError(error)
            }))
        }

        private func updateRecipient(address: String, publicKey: Data?) {
            guard self.recipientAddress != address || self.recipientPublicKey != publicKey else {
                return
            }
            self.recipientAddress = address
            self.recipientPublicKey = publicKey
            self.invalidateFeePreparation()
        }

        private func applyRecipient(_ value: String) {
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
            self.updateRecipient(address: address, publicKey: nil)
            if previousAmount != self.amount
                || previousSendAll != self.shouldSendAll
                || previousComment != self.comment {
                self.invalidateFeePreparation()
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
            self.abandonRestoration()
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
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isAuthorizingComment,
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
                            self.invalidateFeePreparation()
                            self.comment = comment
                            self.isCommentPublic = publicCommentState.value
                        }
                        if self.commentEncrypted {
                            self.requestCommentSession(forSend: false)
                        } else {
                            self.invalidateCommentSession()
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
            self.invalidateFeePreparation()
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
                  !self.isSubmittingTransfer,
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
            if walletInfo.canSign {
                self.abandonRestoration()
                self.performSend(component: component)
                return
            }
            if walletInfo.canExportPhrase {
                self.isResolvingSigningAccess = true
                let generation = self.restorationGeneration
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                        guard let self, self.restorationGeneration == generation else { return .fail(.authorizationCancelled) }
                        return self.restorationAuthorization()
                        |> mapToSignal { session in component.walletContext.recoveryPhrase(password: password, session: session) }
                    },
                    next: { [weak self] _ in
                        guard let self, self.restorationGeneration == generation, self.component?.walletContext === component.walletContext else {
                            return
                        }
                        self.abandonRestoration()
                        self.continueSendingAfterSigningAccess = true
                        self.resumeSendingAfterSigningAccessIfReady()
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    },
                    failed: { [weak self] error in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.finishResolvingSigningAccess(error: error)
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

        fileprivate func abandonRestoration() {
            self.signingAccessDisposable.set(nil)
            self.restorationGeneration &+= 1
            self.restorationSession?.invalidate()
            self.restorationSession = nil
            self.isResolvingSigningAccess = false
            self.continueSendingAfterSigningAccess = false
        }

        private func restorationAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if let session = self.restorationSession, session.isValid { return .single(session) }
            let generation = self.restorationGeneration
            return component.walletContext.beginWalletFlow(reason: "Restore wallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.restorationGeneration == generation else {
                    session.invalidate()
                    return .fail(.authorizationCancelled)
                }
                self.restorationSession?.invalidate()
                self.restorationSession = session
                return .single(session)
            }
        }

        private func finishResolvingSigningAccess(error: WalletContext.WalletError) {
            self.isResolvingSigningAccess = false
            self.continueSendingAfterSigningAccess = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if error == .authorizationCancelled { self.abandonRestoration(); return }
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            let generation = self.restorationGeneration
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Restore Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.abandonRestoration()
                    }),
                    TextAlertAction(type: .defaultAction, title: "Retry", action: { [weak self] in
                        guard let self, self.restorationGeneration == generation, let walletInfo = self.walletInfo else { return }
                        self.resolveSigningAccess(walletInfo: walletInfo)
                    })
                ],
                dismissOnOutsideTap: false
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
                  !self.isSubmittingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.isAuthorizingComment,
                  !self.walletIsLoading,
                  self.walletInfo?.canSign == true,
                  let balance = self.walletBalance,
                  self.amount <= balance,
                  !self.recipientAddress.isEmpty else {
                return
            }
            guard self.validateTransferAmount() else { return }
            if self.commentEncrypted && self.commentSession?.isValid != true {
                self.requestCommentSession(forSend: true)
                return
            }
            guard let request = self.currentFeeRequest else { return }
            if self.feeRequest != request {
                self.invalidateFeePreparation()
                self.feeRequest = request
            }
            self.isPreparingTransfer = true
            if let prepared = self.preparedTransfer(for: request) {
                self.completePreparedSend(prepared)
            } else if !self.isEstimatingFee {
                self.prepareFee(request: request, revision: self.feeRevision)
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func completePreparedSend(_ prepared: WalletContext.PreparedTransfer) {
            guard self.isVisible, let component = self.component,
                  let controller = self.environment?.controller() else { return }
            if let peer = component.peer {
                guard let controller = controller as? WalletSendScreen else { return }
                self.cachedPreparedTransfer = nil
                self.submittingTransfer = prepared
                self.isSubmittingTransfer = true
                let session = prepared.commentEncrypted ? self.commentSession : nil
                // The submission outlives the form and owns the borrowed session until completion.
                self.commentSession = nil
                self.commentSessionGeneration &+= 1
                self.commentSessionDisposable.set(nil)
                let submission = WalletPeerTransferSubmission(
                    context: component.context,
                    peer: peer,
                    displaySuccessToast: component.displaySuccessToast,
                    controller: controller,
                    closeForm: { [weak self, weak controller] in
                        guard let self, self.isVisible, let controller,
                              self.component?.walletContext === component.walletContext,
                              self.component?.peer?.id == peer.id else { return }
                        self.isVisible = false
                        component.completed?()
                        controller.dismiss()
                    },
                    presentErrorOnForm: { [weak self] error in
                        guard let self, self.isVisible,
                              self.component?.walletContext === component.walletContext else { return false }
                        self.isSubmittingTransfer = false
                        self.submittingTransfer = nil
                        self.invalidateFeePreparation()
                        self.feeRequest = self.currentFeeRequest
                        self.feePreparationFailed = true
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                        self.presentTransferError(error)
                        return true
                    }
                )
                submission.start(walletContext: component.walletContext, prepared: prepared, session: session)
                return
            }

            self.cachedPreparedTransfer = nil
            self.isPreparingTransfer = false
            let dismissSendScreen: () -> Void = { [weak controller] in
                guard let controller else { return }
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
                preparedTransfer: prepared,
                dismissSendScreen: dismissSendScreen
            ))
        }

        private func invalidateFeePreparation() {
            self.feeRevision &+= 1
            self.transferDisposable.set(nil)
            self.feeRequest = nil
            self.isEstimatingFee = false
            self.feePreparationFailed = false
            self.isPreparingTransfer = false
            self.discardCachedTransfer()
        }

        private func discardCachedTransfer() {
            guard let walletContext = self.walletContext,
                  let preparedTransfer = self.cachedPreparedTransfer else {
                return
            }
            self.cachedPreparedTransfer = nil
            self.discardTransferDisposables.add(
                walletContext.discardPreparedTransfer(preparedTransfer).start()
            )
        }

        private func presentTransferError(_ error: WalletContext.WalletError? = nil) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            walletPresentTransferError(error, on: controller, context: component.context)
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
            let peerChanged = self.component?.peer?.id != component.peer?.id
            self.component = component
            self.environment = environment
            self.componentState = state

            if peerChanged || (component.peer != nil && self.walletContext !== component.walletContext) {
                self.peerAddressDisposable.set(nil)
                self.peerAddressState = .notRequested
                self.updateRecipient(address: "", publicKey: nil)
                self.initialAddress = nil
            }

            var shouldFocusAmountField = false
            if self.initialAddress != component.initialAddress {
                self.initialAddress = component.initialAddress
                if !component.initialAddress.isEmpty {
                    self.applyRecipient(component.initialAddress)
                }
                shouldFocusAmountField = component.peer != nil || !component.initialAddress.isEmpty
            }

            if !self.didApplyInitialAmount {
                self.didApplyInitialAmount = true
                if let amount = component.initialAmountNanograms {
                    self.amount = amount
                    self.amountSource = .transferLink
                    self.invalidateFeePreparation()
                }
            }

            if self.walletContext !== component.walletContext {
                self.abandonRestoration()
                self.invalidateCommentSession()
                self.invalidateFeePreparation()
                self.walletContext = component.walletContext
                self.signingAccessDisposable.set(nil)
                self.walletInfo = nil
                self.walletBalance = nil
                self.gaslessInfo = .idle
                self.walletAddress = nil
                self.walletIsLoading = true
                self.isSubmittingTransfer = false
                self.submittingTransfer = nil
                self.isResolvingSigningAccess = false
                self.continueSendingAfterSigningAccess = false
                self.currentFiatCurrency = .usd
                self.currentRate = nil
                self.inputMode = .gram
                let accountId = component.context.account.id
                self.commentEnvironmentDisposable.set((combineLatest(
                    component.context.sharedContext.applicationBindings.applicationInForeground,
                    component.context.sharedContext.appLockContext.isPasscodeLocked,
                    component.context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
                ) |> deliverOnMainQueue).start(next: { [weak self] foreground, locked, current in
                    guard let self else { return }
                    self.commentSessionAvailable = foreground && !locked && current
                    if !self.commentSessionAvailable {
                        self.invalidateCommentSession()
                        if !self.isSubmittingTransfer { self.invalidateFeePreparation() }
                    } else {
                        self.updateFeePreparation()
                    }
                    if !self.isUpdating { self.componentState?.updated(transition: .immediate) }
                }))
                self.commentCredentialChangesDisposable.set(PasscodeCredentialStore.shared.changes.start(next: { [weak self] _ in
                    self?.invalidateCommentSession()
                    self?.componentState?.updated(transition: .immediate)
                }))
                let observedWalletContext = component.walletContext
                self.walletDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === observedWalletContext else {
                        return
                    }
                    let previousSendAll = self.shouldSendAll
                    if let previousInfo = self.walletInfo {
                        switch walletState.phase {
                        case let .wallet(info) where previousInfo.address == info.address && previousInfo.publicKey == info.publicKey:
                            break
                        default:
                            self.abandonRestoration()
                            self.invalidateCommentSession()
                            if !self.isSubmittingTransfer { self.invalidateFeePreparation() }
                        }
                    }
                    self.walletBalance = walletState.balance.currentValue
                    self.gaslessInfo = walletState.gaslessInfo
                    if previousSendAll != self.shouldSendAll && !self.isSubmittingTransfer {
                        self.invalidateFeePreparation()
                    }
                    if case let .wallet(info) = walletState.phase {
                        self.walletInfo = info
                        self.walletAddress = info.address
                    } else {
                        self.walletInfo = nil
                        self.walletAddress = nil
                    }
                    let isOwnPreparation = self.isEstimatingFee && walletState.activeOperation == .preparingTransfer
                    self.walletIsLoading = walletState.balance.currentValue == nil
                        || (walletState.activeOperation != nil && !isOwnPreparation)
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

            if self.isVisible {
                self.resolvePeerAddressIfNeeded()
            }
            self.updateFeePreparation()

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
            //TODO:localize
            let depositTitle = "Deposit funds"
            let showDeposit = isInsufficient || (!hasAmount && !hasPositiveBalance)
            let isDepositInline = hasAmount || hasPositiveBalance
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
                    minSize: CGSize(width: isDepositInline ? 0.0 : availableSize.width - 32.0, height: 40.0),
                    action: { [weak self] in
                        self?.openReceive()
                    },
                    isEnabled: showDeposit
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - 32.0 - (isDepositInline ? insufficientTextSize.width + 4.0 : 0.0)),
                    height: 40.0
                )
            )
            let insufficientOriginX = floorToScreenPixels((availableSize.width - insufficientTextSize.width - 4.0 - depositButtonSize.width) / 2.0)
            let depositButtonFrame = CGRect(
                x: isInsufficient ? insufficientOriginX + insufficientTextSize.width + 4.0 : 16.0,
                y: isInsufficient ? insufficientSlotFrame.midY - depositButtonSize.height / 2.0 : usableBottom - 68.0,
                width: depositButtonSize.width,
                height: depositButtonSize.height
            )
            if let insufficientTextView = self.insufficientText.view {
                let isNewlyAdded = insufficientTextView.superview == nil
                var insufficientVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if isNewlyAdded {
                    insufficientTextView.isUserInteractionEnabled = false
                    self.addSubview(insufficientTextView)
                    insufficientVisibilityTransition = .immediate
                }
                if isNewlyAdded || isInsufficient {
                    ComponentTransition.immediate.setFrame(
                        view: insufficientTextView,
                        frame: CGRect(
                            x: insufficientOriginX,
                            y: insufficientSlotFrame.minY + floorToScreenPixels((insufficientSlotFrame.height - insufficientTextSize.height) / 2.0),
                            width: insufficientTextSize.width,
                            height: insufficientTextSize.height
                        )
                    )
                }
                insufficientVisibilityTransition.setAlpha(view: insufficientTextView, alpha: isInsufficient ? 1.0 : 0.0)
            }
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
            let feeDisplayState = self.feeDisplayState
            let showFees = showBalance && feeDisplayState != .hidden
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
                        y: sendButtonY - (showFees ? 58.0 : 36.0) + floorToScreenPixels((24.0 - balanceTextSize.height) / 2.0),
                        width: balanceTextSize.width,
                        height: balanceTextSize.height
                    )
                )
                transition.setAlpha(view: balanceTextView, alpha: showBalance ? 1.0 : 0.0)
            }

            let feeValueComponent: AnyComponentWithIdentity<Empty>
            if feeDisplayState == .loading {
                feeValueComponent = AnyComponentWithIdentity(
                    id: "placeholder",
                    component: AnyComponent(WalletSendFeePlaceholderComponent(
                        color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.itemInputField.backgroundColor
                    ))
                )
            } else {
                let feeValue: String
                if case let .value(fee) = feeDisplayState {
                    //TODO:localize
                    feeValue = formatTonAmountText(fee, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: 5) + " Grams"
                } else {
                    feeValue = "—"
                }
                feeValueComponent = AnyComponentWithIdentity(
                    id: "value",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: feeValue,
                            font: Font.regular(13.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                )
            }
            let feeTextSize = self.feeText.update(
                transition: .immediate,
                component: AnyComponent(HStack([
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                //TODO:localize
                                string: "Network fee:",
                                font: Font.regular(13.0),
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                    ),
                    feeValueComponent
                ], spacing: 3.0)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            if let feeTextView = self.feeText.view {
                if feeTextView.superview == nil {
                    feeTextView.isUserInteractionEnabled = false
                    self.addSubview(feeTextView)
                }
                transition.setFrame(
                    view: feeTextView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - feeTextSize.width) / 2.0),
                        y: sendButtonY - 24.0 - floorToScreenPixels(feeTextSize.height / 2.0),
                        width: feeTextSize.width,
                        height: feeTextSize.height
                    )
                )
                transition.setAlpha(view: feeTextView, alpha: showFees ? 1.0 : 0.0)
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
                && !self.isSubmittingTransfer
                && !self.isResolvingSigningAccess
                && !self.isAuthorizingComment
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
                    displaysProgress: isResolvingPeerAddress || self.isResolvingSigningAccess || self.isPreparingTransfer,
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
    private var gaslessInfoDisposable: Disposable?
    private var refreshBalanceOnOpen: Bool
    fileprivate var peerTransferSubmission: WalletPeerTransferSubmission?

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
        initialAddress: String = "",
        initialAmountNanograms: Int64? = nil,
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
                initialAddress: initialAddress,
                initialAmountNanograms: initialAmountNanograms,
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
        initialAmountNanograms: Int64? = nil,
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
                initialAmountNanograms: initialAmountNanograms,
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

        if self.gaslessInfoDisposable == nil {
            self.gaslessInfoDisposable = self.walletContext.beginGaslessInfoUpdates()
        }
        if self.refreshBalanceOnOpen {
            self.refreshBalanceOnOpen = false
            self.balanceRefreshDisposable = self.walletContext.refreshBalance()
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true && self.parentController() == nil {
            (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.abandonRestoration()
            (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        }

        let peerTransferSubmission = self.peerTransferSubmission
        self.peerTransferSubmission = nil
        peerTransferSubmission?.formDidDisappear()

        self.balanceRefreshDisposable?.dispose()
        self.balanceRefreshDisposable = nil
        self.gaslessInfoDisposable?.dispose()
        self.gaslessInfoDisposable = nil
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewDidAppear()
        self.peerTransferSubmission?.formDidAppear()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        self.peerTransferSubmission?.formWillDisappear()
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.viewWillDisappear()

        super.viewWillDisappear(animated)
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.dismiss(completion: completion)
    }

    override public func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.dismiss(animated: flag, completion: completion)
    }

    override public func viewWillLeaveNavigation() {
        (self.node.hostView.componentView as? WalletSendScreenComponent.View)?.invalidateCommentSession()
        super.viewWillLeaveNavigation()
    }

    deinit {
        self.balanceRefreshDisposable?.dispose()
        self.gaslessInfoDisposable?.dispose()
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
