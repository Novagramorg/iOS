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
    let walletAddress: String
    let walletPublicKey: String
    let address: String
    let comment: WalletContext.TransferFeeComment
}

private struct WalletSendTransferRequest {
    let feeRequest: WalletSendFeeRequest
    let publicKey: Data?
    let amount: Int64
    let sendAll: Bool
    let comment: String?
    let commentEncrypted: Bool
}

private func walletSendShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
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
    private let submissionDisposable = MetaDisposable()
    private var submissionStage: WalletContext.TransferSubmissionStage = .waitingForPreviousTransfer
    private var preparedTransfer: WalletContext.PreparedTransfer?
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
        self.preparedTransfer = prepared
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

        self.submissionDisposable.set(walletContext.submitTransfer(prepared, recipientPeerId: self.peer.id, pendingMessageCreated: { [weak self] in
            self?.pendingMessageCreated()
        }, session: session, stageUpdated: { [weak self] stage in
            guard let self else { return }
            self.submissionStage = stage
            if stage == .submitted {
                self.commentSession?.invalidate()
                self.commentSession = nil
            }
        }).start(next: { [self] pending in
            self.finish(.success(pending))
        }, error: { [self] error in
            self.finish(.failure(error))
        }))
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
        if self.submissionStage == .waitingForPreviousTransfer {
            self.invalidate()
        }
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
        self.submissionDisposable.set(nil)
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
        if self.submissionStage == .waitingForPreviousTransfer {
            self.submissionDisposable.dispose()
            self.commentSession?.invalidate()
            self.commentSession = nil
            if let preparedTransfer, let walletContext = self.walletContext {
                let _ = walletContext.discardPreparedTransfer(preparedTransfer).startStandalone()
            }
        }
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
        private let recipient = ComponentView<Empty>()
        private var recipientInfoAlert: AlertScreen?
        private let amountField = WalletSendAmountField()
        private let keyboard = ComponentView<Empty>()
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
        private var isAttachmentTabBarVisible: Bool?
        private var hasActivatedAmountInput = false

        private var walletContext: WalletContext?
        private let walletDisposable = MetaDisposable()
        private let peerAddressDisposable = MetaDisposable()
        private var peerAddressState: PeerAddressState = .notRequested
        private var isVisible = false
        private let feeDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private let signingAccessDisposable = MetaDisposable()
        private var restorationSession: PasscodeSession?
        private var restorationGeneration = 0
        private var cachedFeeEstimate: WalletContext.TransferFeeEstimate?
        private var pendingSend: WalletSendTransferRequest?
        private var sendRevision = 0
        private var isPreparingActualTransfer = false
        private var submittingTransfer: WalletContext.PreparedTransfer?
        private var feeRequest: WalletSendFeeRequest?
        private var feeRevision = 0
        private var isEstimatingFee = false
        private var feePreparationFailed = false
        private var commentSession: PasscodeSession?
        private var commentSessionGeneration = 0
        private var commentSessionAvailable = true
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
        private var lastRateDisplaysGramIcon = false
        private var recipientAddress = ""
        private var recipientPublicKey: Data?
        private var initialAddress: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.amountField)
            self.amountField.amountUpdated = { [weak self] amount in
                guard let self, !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                    return
                }
                self.amountSource = .manual
                self.amount = amount
                if self.inputMode == .gram, !self.validateTransferAmount() {
                    return
                }
                if !self.isUpdating {
                    self.componentState?.updated(transition: .immediate)
                }
            }
            self.amountField.focusUpdated = { [weak self] focused in
                guard let self else {
                    return
                }
                if focused {
                    self.hasActivatedAmountInput = true
                    if let controller = self.environment?.controller() as? WalletSendScreen {
                        controller.requestAttachmentMenuExpansion()
                        controller.cancelPanGesture()
                    }
                }
                if !focused {
                    (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
                }
                if !self.isUpdating {
                    self.componentState?.updated(transition: .spring(duration: 0.4))
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
            if let insufficientTextView = self.insufficientText.view,
               insufficientTextView.alpha > 0.0, insufficientTextView.frame.contains(point) {
                return self
            }
            return super.hitTest(point, with: event)
        }

        deinit {
            self.restorationSession?.invalidate()
            self.commentSession?.invalidate()
            self.commentEnvironmentDisposable.dispose()
            self.commentCredentialChangesDisposable.dispose()
            self.invalidateFeePreparation()
            self.feeDisposable.dispose()
            self.walletDisposable.dispose()
            self.peerAddressDisposable.dispose()
            self.transferDisposable.dispose()
            self.signingAccessDisposable.dispose()
        }

        func isPanGestureEnabled() -> Bool {
            return !self.amountField.isInputActive
        }

        func viewDidAppear() {
            self.isVisible = true
            self.resolvePeerAddressIfNeeded()
            self.feePreparationFailed = false
            self.updateFeePreparation()
            self.componentState?.updated(transition: .immediate)
        }

        func viewWillDisappear() {
            self.isVisible = false
            (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
            if let controller = self.environment?.controller() as? WalletSendScreen, controller.parentController() != nil {
                self.amountField.endEditing(true)
            }
            if !self.isSubmittingTransfer {
                self.cancelPendingSend()
                if self.isEstimatingFee {
                    self.invalidateFeePreparation()
                }
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
        }

        private var shouldSendAll: Bool {
            guard self.amountSource == .manual, self.amount > 0, let walletBalance = self.walletBalance else {
                return false
            }
            return self.amount == walletBalance
        }

        private var commentEncrypted: Bool {
            return self.component?.peer != nil
                && self.comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && !self.isCommentPublic
        }

        private var currentFeeRequest: WalletSendFeeRequest? {
            guard let walletInfo = self.walletInfo, !self.recipientAddress.isEmpty else { return nil }
            let comment: WalletContext.TransferFeeComment
            if self.commentEncrypted {
                comment = .encrypted
            } else if let text = self.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                comment = .plainText(byteCount: text.utf8.count)
            } else {
                comment = .none
            }
            return WalletSendFeeRequest(
                walletAddress: walletInfo.address,
                walletPublicKey: walletInfo.publicKey,
                address: self.recipientAddress,
                comment: comment
            )
        }

        private var isSelfTransfer: Bool {
            return WalletContext.isSelfTransfer(recipient: self.recipientAddress, walletAddress: self.walletInfo?.address)
        }

        private func feesAreCovered(amount: Int64) -> Bool {
            guard !self.isSelfTransfer, let component = self.component else {
                return false
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            return WalletContext.isGaslessEligible(
                amount: amount,
                gaslessInfo: self.gaslessInfo.currentValue,
                minimumAmount: configuration.transferGaslessMinAmount
            )
        }

        private var feeDisplayState: WalletSendFeeDisplayState {
            if !self.isSelfTransfer {
                if case .stale = self.gaslessInfo { return .unavailable }
                guard let gaslessInfo = self.gaslessInfo.currentValue else { return .loading }
                if self.amount == 0 && gaslessInfo.available && gaslessInfo.left > 0 { return .hidden }
            }
            if !self.shouldSendAll && self.feesAreCovered(amount: self.amount) { return .hidden }
            if let prepared = self.submittingTransfer {
                if self.feesAreCovered(amount: prepared.amount) || prepared.fee == 0 { return .hidden }
                return .value(prepared.fee)
            }
            if self.feeRequest == self.currentFeeRequest, let estimate = self.cachedFeeEstimate {
                let effectiveAmount = self.shouldSendAll ? max(0, self.amount - estimate.fee) : self.amount
                if self.feesAreCovered(amount: effectiveAmount) || estimate.fee == 0 { return .hidden }
                return .value(estimate.fee)
            }
            if self.feePreparationFailed { return .unavailable }
            if self.peerAddressState == .failed || self.peerAddressState == .errorPresented || self.peerAddressState == .cancelled {
                return .unavailable
            }
            if !self.walletIsLoading && self.currentFeeRequest == nil { return .unavailable }
            return .loading
        }

        private func updateFeePreparation() {
            guard self.isVisible, self.commentSessionAvailable, !self.isSubmittingTransfer else { return }
            let request = self.currentFeeRequest
            if self.feeRequest != request {
                if let pendingSend = self.pendingSend, pendingSend.feeRequest != request {
                    self.cancelPendingSend()
                }
                self.invalidateFeePreparation()
                self.feeRequest = request
            }
            guard let request else { return }
            if self.cachedFeeEstimate != nil {
                self.continuePendingSend()
                return
            }
            guard !self.isEstimatingFee, !self.feePreparationFailed else { return }
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
            self.isEstimatingFee = true
            self.feePreparationFailed = false
            self.feeDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> mapToSignal { _ in
                return walletContext.estimateTransferFee(address: request.address, comment: request.comment)
            }
            |> deliverOnMainQueue).start(next: { [weak self] estimate in
                guard let self, self.walletContext === walletContext,
                      self.isVisible, self.feeRevision == revision, self.currentFeeRequest == request else { return }
                self.isEstimatingFee = false
                self.cachedFeeEstimate = estimate
                self.continuePendingSend()
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }, error: { [weak self] error in
                guard let self, self.walletContext === walletContext, self.feeRevision == revision else { return }
                let wasSending = self.pendingSend != nil
                self.isEstimatingFee = false
                self.feePreparationFailed = true
                if wasSending { self.cancelPendingSend() }
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                if wasSending { self.presentTransferError(error) }
            }))
        }

        fileprivate func invalidateCommentSession() {
            if !self.isSubmittingTransfer {
                self.cancelPendingSend()
            }
        }

        private func installCommentSession(_ session: PasscodeSession) {
            self.commentSession = session
            guard let expiresAt = session.expiresAt else { return }
            let generation = self.commentSessionGeneration
            let delay = max(0.0, expiresAt - ProcessInfo.processInfo.systemUptime)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak session] in
                guard let self, let session, self.commentSessionGeneration == generation,
                      self.commentSession === session else { return }
                self.invalidateCommentSession()
                self.componentState?.updated(transition: .immediate)
            }
        }

        private func updateRecipient(address: String, publicKey: Data?) {
            guard self.recipientAddress != address || self.recipientPublicKey != publicKey else {
                return
            }
            let previousRequest = self.currentFeeRequest
            self.cancelPendingSend()
            self.recipientAddress = address
            self.recipientPublicKey = publicKey
            if previousRequest != self.currentFeeRequest {
                self.invalidateFeePreparation()
            }
        }

        private func applyRecipient(_ value: String) {
            let previousRequest = self.currentFeeRequest
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
            if previousRequest != self.currentFeeRequest {
                self.invalidateFeePreparation()
            }
            if !self.isUpdating {
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }
        }

        private func toggleInputMode() {
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let rate = self.currentRate, rate.isFinite, rate > 0.0 else {
                return
            }
            switch self.inputMode {
            case .gram:
                self.inputMode = .fiat
            case .fiat:
                self.inputMode = .gram
                self.amount = (self.amount / 1_000_000) * 1_000_000
                guard self.validateTransferAmount() else {
                    return
                }
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func dismiss() {
            self.abandonRestoration()
            self.cancelPendingSend()
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

        private func showRecipientInfoAlert() {
            guard self.recipientInfoAlert == nil, self.isVisible,
                  !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
                  let component = self.component,
                  !self.recipientAddress.isEmpty,
                  let controller = self.environment?.controller() else {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let title: String
            let recipientName: String?
            if let peer = component.peer {
                let fullName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                let shortName = peer.compactDisplayTitle.isEmpty ? fullName : peer.compactDisplayTitle
                //TODO:localize
                title = "\(shortName)’s wallet"
                if let username = peer.addressName, !username.isEmpty {
                    recipientName = "@\(username)"
                } else {
                    recipientName = fullName
                }
            } else {
                //TODO:localize
                title = "Unlinked wallet"
                recipientName = nil
            }
            let peerId = component.peer?.id
            let recipientAddress = self.recipientAddress
            let restoreInputFocus = self.amountField.isInputActive
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: true, allowInputInset: true),
                content: [
                    AnyComponentWithIdentity(
                        id: "recipientInfo",
                        component: AnyComponent(WalletSendRecipientAlertContentComponent(
                            title: title,
                            recipientName: recipientName,
                            address: recipientAddress
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: presentationData.strings.Common_OK, type: .default)
                ]
            )
            self.recipientInfoAlert = alertController
            alertController.dismissed = { [weak self, weak controller, weak alertController] _ in
                DispatchQueue.main.async { [weak self, weak controller, weak alertController] in
                    guard let self, self.recipientInfoAlert === alertController else {
                        return
                    }
                    self.recipientInfoAlert = nil
                    guard restoreInputFocus, self.isVisible, self.window != nil,
                          let controller, self.environment?.controller() === controller, !controller.isBeingDismissed,
                          self.component?.peer?.id == peerId, self.recipientAddress == recipientAddress,
                          !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                        return
                    }
                    self.amountField.activateInput()
                }
            }
            controller.present(alertController, in: .window(.root))
        }

        private func showCommentAlert() {
            guard !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer,
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
                        maxHeight: (controller.view.window?.bounds.height ?? UIScreen.main.bounds.height) * 0.31,
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
                        guard let self, !self.isPreparingTransfer, !self.isSubmittingTransfer else {
                            return
                        }
                        let value = inputState.value.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        let comment = value.isEmpty ? nil : value
                        let previousRequest = self.currentFeeRequest
                        self.comment = comment
                        self.isCommentPublic = publicCommentState.value
                        if previousRequest != self.currentFeeRequest {
                            self.invalidateFeePreparation()
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
                  self.isVisible, self.commentSessionAvailable,
                  self.amount > 0,
                  !self.isPreparingTransfer,
                  !self.isSubmittingTransfer,
                  !self.isResolvingSigningAccess,
                  !self.walletIsLoading,
                  self.walletInfo != nil,
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
            guard let feeRequest = self.currentFeeRequest else { return }
            self.sendRevision &+= 1
            self.pendingSend = WalletSendTransferRequest(
                feeRequest: feeRequest,
                publicKey: self.recipientPublicKey,
                amount: self.amount,
                sendAll: self.shouldSendAll,
                comment: self.comment,
                commentEncrypted: self.commentEncrypted
            )
            self.isPreparingTransfer = true
            self.amountField.isUserInteractionEnabled = false
            self.amountField.endEditing(true)
            self.componentState?.updated(transition: .immediate)
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
                self.cancelPendingSend()
                self.componentState?.updated(transition: .immediate)
                self.openRecoveryPhraseImport()
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
            self.cancelPendingSend()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if error == .authorizationCancelled { return }
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
                        guard let self, self.restorationGeneration == generation else { return }
                        self.send()
                    })
                ],
                dismissOnOutsideTap: false
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
                        text: "Your wallet was restored from your secret phrase.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
        }

        private func performSend(component: WalletSendScreenComponent) {
            guard self.isVisible, self.commentSessionAvailable,
                  self.walletContext === component.walletContext,
                  let request = self.pendingSend,
                  self.walletInfo != nil else { return }
            guard self.currentFeeRequest == request.feeRequest else {
                self.cancelPendingSend()
                self.componentState?.updated(transition: .immediate)
                return
            }
            self.feePreparationFailed = false
            self.updateFeePreparation()
            self.componentState?.updated(transition: .immediate)
        }

        private func continuePendingSend() {
            guard self.isVisible, self.commentSessionAvailable,
                  !self.isSubmittingTransfer, !self.isResolvingSigningAccess,
                  !self.isPreparingActualTransfer,
                  let walletContext = self.walletContext,
                  let request = self.pendingSend,
                  self.currentFeeRequest == request.feeRequest,
                  self.feeRequest == request.feeRequest, self.cachedFeeEstimate != nil else { return }
            self.isPreparingActualTransfer = true
            let revision = self.sendRevision
            self.transferDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] state -> Signal<PasscodeSession?, WalletContext.WalletError> in
                guard let self, self.sendRevision == revision, self.pendingSend != nil,
                      self.isVisible, self.walletContext === walletContext else { return .fail(.authorizationCancelled) }
                guard case let .wallet(info) = state.phase else { return .fail(.unavailable) }
                if !info.canSign {
                    self.isPreparingActualTransfer = false
                    self.resolveSigningAccess(walletInfo: info)
                    return .complete()
                }
                guard request.commentEncrypted else { return .single(nil) }
                return walletContext.beginCommentEncryptionSession()
                |> mapToSignal { [weak self] session -> Signal<PasscodeSession?, WalletContext.WalletError> in
                    guard let self, self.sendRevision == revision, self.pendingSend != nil,
                          self.isVisible, self.commentSessionAvailable, self.walletContext === walletContext else {
                        session.invalidate()
                        return .fail(.authorizationCancelled)
                    }
                    self.installCommentSession(session)
                    return .single(session)
                }
            }
            |> mapToSignal { [weak self] session -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
                return walletContext.state
                |> filter { $0.activeOperation == nil }
                |> take(1)
                |> castError(WalletContext.WalletError.self)
                |> deliverOnMainQueue
                |> mapToSignal { [weak self] state -> Signal<WalletContext.PreparedTransfer, WalletContext.WalletError> in
                    guard let self, self.sendRevision == revision, self.pendingSend != nil,
                          self.isVisible, self.commentSessionAvailable, self.walletContext === walletContext,
                          self.currentFeeRequest == request.feeRequest else { return .fail(.authorizationCancelled) }
                    guard let balance = state.balance.currentValue, request.amount <= balance else {
                        return .fail(.insufficientBalance(required: request.amount))
                    }
                    if request.sendAll && balance != request.amount { return .fail(.previewFailed) }
                    return walletContext.prepareTransfer(
                        address: request.feeRequest.address,
                        amount: request.amount,
                        sendAll: request.sendAll,
                        comment: request.comment,
                        commentEncrypted: request.commentEncrypted,
                        recipientPublicKey: request.publicKey,
                        session: session
                    )
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self, self.sendRevision == revision, self.pendingSend != nil,
                      self.isVisible, self.walletContext === walletContext else {
                    let _ = walletContext.discardPreparedTransfer(prepared).startStandalone()
                    return
                }
                self.isPreparingActualTransfer = false
                self.completePreparedSend(prepared)
            }, error: { [weak self] error in
                guard let self, self.sendRevision == revision, self.walletContext === walletContext else { return }
                self.cancelPendingSend()
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError(error)
            }))
        }

        private func completePreparedSend(_ prepared: WalletContext.PreparedTransfer) {
            guard self.isVisible, let component = self.component,
                  let controller = self.environment?.controller() else {
                if let walletContext = self.walletContext {
                    let _ = walletContext.discardPreparedTransfer(prepared).startStandalone()
                }
                self.cancelPendingSend()
                self.componentState?.updated(transition: .immediate)
                return
            }
            if let peer = component.peer {
                guard let controller = controller as? WalletSendScreen else {
                    let _ = component.walletContext.discardPreparedTransfer(prepared).startStandalone()
                    self.cancelPendingSend()
                    self.componentState?.updated(transition: .immediate)
                    return
                }
                self.submittingTransfer = prepared
                self.isSubmittingTransfer = true
                self.pendingSend = nil
                let session = prepared.commentEncrypted ? self.commentSession : nil
                self.commentSession = nil
                self.commentSessionGeneration &+= 1
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
                        self.cancelPendingSend()
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                        self.presentTransferError(error)
                        return true
                    }
                )
                submission.start(walletContext: component.walletContext, prepared: prepared, session: session)
                return
            }

            self.pendingSend = nil
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
            self.feeDisposable.set(nil)
            self.feeRequest = nil
            self.isEstimatingFee = false
            self.feePreparationFailed = false
            self.cachedFeeEstimate = nil
        }

        private func cancelPendingSend() {
            guard !self.isSubmittingTransfer else { return }
            self.sendRevision &+= 1
            self.pendingSend = nil
            self.isPreparingTransfer = false
            self.isPreparingActualTransfer = false
            self.transferDisposable.set(nil)
            self.commentSessionGeneration &+= 1
            self.commentSession?.invalidate()
            self.commentSession = nil
            self.abandonRestoration()
            self.amountField.isUserInteractionEnabled = true
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
            let attachmentController = environment.controller() as? WalletSendScreen
            let isInAttachmentMenu = attachmentController?.parentController() != nil

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
                shouldFocusAmountField = !isInAttachmentMenu && (component.peer != nil || !component.initialAddress.isEmpty)
            }

            if !self.didApplyInitialAmount {
                self.didApplyInitialAmount = true
                if let amount = component.initialAmountNanograms {
                    self.amount = amount
                    self.amountSource = .transferLink
                }
            }

            if self.walletContext !== component.walletContext {
                self.isSubmittingTransfer = false
                self.submittingTransfer = nil
                self.invalidateCommentSession()
                self.invalidateFeePreparation()
                self.walletContext = component.walletContext
                self.signingAccessDisposable.set(nil)
                self.walletInfo = nil
                self.walletBalance = nil
                self.gaslessInfo = .idle
                self.walletAddress = nil
                self.walletIsLoading = true
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
                    if case let .wallet(info) = walletState.phase {
                        self.walletInfo = info
                        self.walletAddress = info.address
                    } else {
                        self.walletInfo = nil
                        self.walletAddress = nil
                    }
                    let isOwnPreparation = (self.isEstimatingFee || self.isPreparingActualTransfer)
                        && walletState.activeOperation == .preparingTransfer
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
            let isAmountInputEnabled = !self.isPreparingTransfer && !self.isResolvingSigningAccess && !self.isSubmittingTransfer
            self.amountField.isUserInteractionEnabled = isAmountInputEnabled

            let theme = environment.theme
            self.backgroundColor = theme.list.modalPlainBackgroundColor

            //TODO:localize
            let titleText = NSAttributedString(
                string: "Send Money to ",
                font: Font.semibold(17.0),
                textColor: theme.list.itemPrimaryTextColor
            )

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

            var recipientFrame: CGRect?
            if component.peer != nil || !self.recipientAddress.isEmpty {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let recipientSize = self.recipient.update(
                    transition: transition,
                    component: AnyComponent(WalletSendRecipientComponent(
                        context: component.context,
                        theme: theme,
                        strings: environment.strings,
                        nameDisplayOrder: presentationData.nameDisplayOrder,
                        peer: component.peer,
                        address: self.recipientAddress,
                        isLoading: self.recipientAddress.isEmpty && (self.peerAddressState == .notRequested || self.peerAddressState == .loading),
                        openInfo: { [weak self] in
                            self?.showRecipientInfoAlert()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: controlButtonsWidth, height: .greatestFiniteMagnitude)
                )
                let frame = CGRect(
                    x: environment.safeInsets.left + 16.0,
                    y: headerOriginY + headerButtonSize.height + 14.0,
                    width: recipientSize.width,
                    height: recipientSize.height
                )
                recipientFrame = frame
                if let recipientView = self.recipient.view {
                    if recipientView.superview == nil {
                        self.addSubview(recipientView)
                    }
                    recipientView.isUserInteractionEnabled = true
                    transition.setFrame(view: recipientView, frame: frame)
                    transition.setAlpha(view: recipientView, alpha: 1.0)
                }
            } else if let recipientView = self.recipient.view {
                recipientView.isUserInteractionEnabled = false
                transition.setAlpha(view: recipientView, alpha: 0.0)
            }

            let isKeyboardVisible = !isInAttachmentMenu || self.hasActivatedAmountInput
            let keyboardSize = self.keyboard.update(
                transition: transition,
                component: AnyComponent(WalletSendKeyboardComponent(
                    theme: theme,
                    safeInsets: environment.safeInsets,
                    decimalSeparator: environment.dateTimeFormat.decimalSeparator,
                    deleteTitle: environment.strings.Common_Delete,
                    isEnabled: isAmountInputEnabled && environment.isVisible && isKeyboardVisible,
                    action: { [weak self] action in
                        HapticFeedback().tap()
                        guard let self, self.isVisible,
                              !self.isPreparingTransfer, !self.isResolvingSigningAccess, !self.isSubmittingTransfer else {
                            return
                        }
                        switch action {
                        case let .insertText(text):
                            self.amountField.insertText(text)
                        case .deleteBackward:
                            self.amountField.deleteBackward()
                        }
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            let keyboardFrame = CGRect(
                x: 0.0,
                y: isKeyboardVisible ? availableSize.height - environment.additionalInsets.bottom - keyboardSize.height : availableSize.height,
                width: keyboardSize.width,
                height: keyboardSize.height
            )
            if let keyboardView = self.keyboard.view {
                if keyboardView.superview == nil {
                    self.addSubview(keyboardView)
                    keyboardView.frame = keyboardFrame
                    keyboardView.alpha = isKeyboardVisible ? 1.0 : 0.0
                }
                keyboardView.isUserInteractionEnabled = isAmountInputEnabled && isKeyboardVisible
                keyboardView.accessibilityElementsHidden = !isKeyboardVisible
                transition.setFrame(view: keyboardView, frame: keyboardFrame)
                transition.setAlpha(view: keyboardView, alpha: isKeyboardVisible ? 1.0 : 0.0)
            }
            let usableBottom = isKeyboardVisible ? keyboardFrame.minY : availableSize.height - environment.additionalInsets.bottom - environment.safeInsets.bottom
            let hasAmount = self.amount > 0
            let isInsufficient = hasAmount
                && !self.walletIsLoading
                && self.walletBalance.map { self.amount > $0 } == true
            let hasPositiveBalance = self.walletBalance.map { $0 > 0 } == true
            let hasZeroBalance = self.walletBalance == 0
            let sendButtonY = usableBottom - 68.0
            let showSendButton = hasAmount || component.peer != nil || !component.initialAddress.isEmpty
            let showBalance = (hasAmount || hasPositiveBalance) && !hasZeroBalance
            let feeDisplayState = self.feeDisplayState
            let showFees = feeDisplayState != .hidden
            let balanceSlotY = sendButtonY - (showFees ? 58.0 : 36.0)
            
            var centralContentLayouts: [(view: UIView, frame: CGRect, transition: ComponentTransition)] = []
            let amountWidth = max(1.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 32.0)
            let amountFrame = CGRect(
                x: environment.safeInsets.left + 16.0,
                y: 0.0,
                width: amountWidth,
                height: 74.0
            )
            var centralContentFrame = amountFrame
            transition.setBounds(view: self.amountField, bounds: CGRect(origin: .zero, size: amountFrame.size))
            centralContentLayouts.append((self.amountField, amountFrame, transition))
            self.amountField.update(
                mode: self.inputMode,
                amount: self.amount,
                rate: self.currentRate,
                fiatCurrency: self.currentFiatCurrency,
                dateTimeFormat: environment.dateTimeFormat,
                theme: theme,
                lottieSettings: component.context.lottieRenderingSettings,
                isVisible: environment.isVisible,
                transition: transition
            )

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
            let emptyHintFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - emptyHintSize.width) / 2.0),
                y: amountFrame.maxY + 5.0,
                width: emptyHintSize.width,
                height: emptyHintSize.height
            )
            let showEmptyHint = !shouldFocusAmountField && !self.hasActivatedAmountInput && !self.amountField.isInputActive && !self.amountField.hasInputText
            if showEmptyHint {
                centralContentFrame = centralContentFrame.union(emptyHintFrame)
            }
            if let emptyHintView = self.emptyHint.view {
                if emptyHintView.superview == nil {
                    self.addSubview(emptyHintView)
                }
                emptyHintView.accessibilityElementsHidden = !showEmptyHint
                transition.setBounds(view: emptyHintView, bounds: CGRect(origin: .zero, size: emptyHintFrame.size))
                centralContentLayouts.append((emptyHintView, emptyHintFrame, transition))
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
                    rateText = formatTonAmountText(
                        self.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 3
                    )
                }
            }
            let showRate = hasAmount && !rateText.isEmpty
            if showRate {
                self.lastRateText = rateText
                self.lastRateDisplaysGramIcon = self.inputMode == .fiat
            }
            var rateItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.with(size: 13.0, design: .round, weight: .semibold),
                        color: theme.list.itemSecondaryTextColor,
                        items: [
                            AnimatedTextComponent.Item(id: "rate", content: .text(self.lastRateText))
                        ],
                        noDelay: true,
                        blur: true
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
            if self.lastRateDisplaysGramIcon {
                rateItems.insert(AnyComponentWithIdentity(
                    id: "gramIcon",
                    component: AnyComponent(BundleIconComponent(
                        name: "Wallet/SendGram",
                        tintColor: UIColor(rgb: 0x30A1F5),
                        maxSize: CGSize(width: 16.0, height: 16.0)
                    ))
                ), at: 0)
            }
            
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
                y: amountFrame.maxY - 1.0,
                width: rateButtonSize.width,
                height: rateButtonSize.height
            )
            if self.currentRate != nil {
                centralContentFrame = centralContentFrame.union(rateButtonFrame)
            }
            if let rateButtonView = self.rateButton.view {
                var rateVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if rateButtonView.superview == nil {
                    self.addSubview(rateButtonView)
                    rateVisibilityTransition = .immediate
                }
                rateButtonView.bounds = CGRect(origin: .zero, size: rateButtonFrame.size)
                centralContentLayouts.append((rateButtonView, rateButtonFrame, transition))
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
                        font: Font.regular(14.0),
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
            let showDeposit = hasZeroBalance || isInsufficient || (!hasAmount && !hasPositiveBalance)
            let isDepositInline = !hasZeroBalance && (hasAmount || hasPositiveBalance)
            let depositItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: depositTitle,
                            font: Font.regular(14.0),
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
            let insufficientOriginX = floorToScreenPixels((availableSize.width - insufficientTextSize.width - (isDepositInline ? 4.0 + depositButtonSize.width : 0.0)) / 2.0)
            let depositButtonFrame = CGRect(
                x: isDepositInline ? insufficientOriginX + insufficientTextSize.width + 4.0 : floorToScreenPixels((availableSize.width - depositButtonSize.width) / 2.0),
                y: (isDepositInline ? insufficientSlotFrame.midY : balanceSlotY + 12.0) - depositButtonSize.height / 2.0,
                width: depositButtonSize.width,
                height: depositButtonSize.height
            )
            let insufficientTextFrame = CGRect(
                x: insufficientOriginX,
                y: insufficientSlotFrame.minY + floorToScreenPixels((insufficientSlotFrame.height - insufficientTextSize.height) / 2.0),
                width: insufficientTextSize.width,
                height: insufficientTextSize.height
            )
            if isInsufficient {
                centralContentFrame = centralContentFrame.union(insufficientTextFrame)
            }
            if showDeposit && isDepositInline {
                centralContentFrame = centralContentFrame.union(depositButtonFrame)
            }
            
            var insufficientPositionTransition: ComponentTransition = transition
            if let insufficientTextView = self.insufficientText.view {
                let isNewlyAdded = insufficientTextView.superview == nil
                var insufficientVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if isNewlyAdded {
                    self.addSubview(insufficientTextView)
                    insufficientVisibilityTransition = .immediate
                    insufficientPositionTransition = .immediate
                }
                insufficientPositionTransition.setBounds(view: insufficientTextView, bounds: CGRect(origin: .zero, size: insufficientTextFrame.size))
                centralContentLayouts.append((insufficientTextView, insufficientTextFrame, insufficientPositionTransition))
                insufficientVisibilityTransition.setAlpha(view: insufficientTextView, alpha: isInsufficient ? 1.0 : 0.0)
            }
            if let depositButtonView = self.depositButton.view {
                var depositPositionTransition = transition
                var depositVisibilityTransition: ComponentTransition = .easeInOut(duration: 0.2)
                if depositButtonView.superview == nil {
                    self.addSubview(depositButtonView)
                    depositPositionTransition = .immediate
                    depositVisibilityTransition = .immediate
                }
                depositPositionTransition.setBounds(view: depositButtonView, bounds: CGRect(origin: .zero, size: depositButtonFrame.size))
                if isDepositInline {
                    centralContentLayouts.append((depositButtonView, depositButtonFrame, depositPositionTransition))
                } else {
                    depositPositionTransition.setPosition(view: depositButtonView, position: depositButtonFrame.center)
                }
                depositVisibilityTransition.setAlpha(view: depositButtonView, alpha: showDeposit ? 1.0 : 0.0)
            }

            if component.peer != nil, let comment = self.comment, !comment.isEmpty {
                let isInitialCommentLayout = self.commentText.view?.superview == nil
                var commentTransition = transition
                if isInitialCommentLayout {
                    commentTransition = .immediate
                }
                let commentPositionTransition: ComponentTransition = isInitialCommentLayout ? .immediate : transition

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
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 120.0, height: 1000.0)
                )
                let bubbleSize = CGSize(width: commentSize.width + 34.0, height: max(34.0, commentSize.height + 14.0))
                let commentOriginY: CGFloat
                if isInsufficient {
                    commentOriginY = (isDepositInline ? depositButtonFrame.maxY : insufficientTextFrame.maxY) + 8.0
                } else {
                    commentOriginY = rateButtonFrame.maxY + 15.0
                }
                let bubbleFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - bubbleSize.width) / 2.0 + 3.0),
                    y: commentOriginY,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )
                centralContentFrame = centralContentFrame.union(bubbleFrame)
                ComponentTransition.immediate.setBounds(
                    view: self.commentBackgroundView,
                    bounds: CGRect(origin: .zero, size: bubbleFrame.size)
                )
                centralContentLayouts.append((self.commentBackgroundView, bubbleFrame, commentPositionTransition))
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
                    let positionedCommentTextFrame = commentTextFrame.offsetBy(dx: 2.0 - UIScreenPixel, dy: 0.0)
                    centralContentLayouts.append((commentTextView, positionedCommentTextFrame, commentPositionTransition))
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
                    maxDecimalPositions: 2,
                    formatString: environment.strings.Currency_Grams
                )
            } else {
                //TODO:localize
                let unavailableBalance = "—"
                formattedBalance = unavailableBalance
            }
            //TODO:localize
            let balancePrefix = "Balance: "
            let balanceText = balancePrefix + formattedBalance

            let balanceTextSize = self.balanceText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: balanceText,
                        font: Font.regular(14.0),
                        textColor: theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 24.0)
            )
            let balanceTextFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - balanceTextSize.width) / 2.0),
                y: balanceSlotY + floorToScreenPixels((24.0 - balanceTextSize.height) / 2.0),
                width: balanceTextSize.width,
                height: balanceTextSize.height
            )
            if let balanceTextView = self.balanceText.view {
                if balanceTextView.superview == nil {
                    self.addSubview(balanceTextView)
                }
                transition.setFrame(view: balanceTextView, frame: balanceTextFrame)
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
                    feeValue = formatTonAmountText(
                        fee,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 5,
                        formatString: environment.strings.Currency_Grams
                    )
                } else {
                    feeValue = "—"
                }
                feeValueComponent = AnyComponentWithIdentity(
                    id: "value",
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: feeValue,
                            font: Font.regular(14.0),
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
                                font: Font.regular(14.0),
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
            let feeTextFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - feeTextSize.width) / 2.0),
                y: sendButtonY - 24.0 - floorToScreenPixels(feeTextSize.height / 2.0),
                width: feeTextSize.width,
                height: feeTextSize.height
            )
            if let feeTextView = self.feeText.view {
                if feeTextView.superview == nil {
                    feeTextView.isUserInteractionEnabled = false
                    self.addSubview(feeTextView)
                }
                transition.setFrame(view: feeTextView, frame: feeTextFrame)
                transition.setAlpha(view: feeTextView, alpha: showFees ? 1.0 : 0.0)
            }

            let centralContentTop = recipientFrame?.maxY ?? (headerOriginY + headerButtonSize.height)
            var centralContentBottom = showSendButton ? sendButtonY : usableBottom
            if showBalance {
                centralContentBottom = min(centralContentBottom, balanceTextFrame.minY)
            }
            if showDeposit && !isDepositInline {
                centralContentBottom = min(centralContentBottom, depositButtonFrame.minY)
            }
            if showFees {
                centralContentBottom = min(centralContentBottom, feeTextFrame.minY)
            }
            let centralContentOriginY = floorToScreenPixels(centralContentTop + max(
                12.0,
                (centralContentBottom - centralContentTop - centralContentFrame.height) / 2.0
            ))
            let centralContentOffsetY = centralContentOriginY - centralContentFrame.minY
            for layout in centralContentLayouts {
                layout.transition.setPosition(view: layout.view, position: layout.frame.center.offsetBy(dx: 0.0, dy: centralContentOffsetY))
            }
            if shouldFocusAmountField {
                self.amountField.activateInput()
            }

            var sendIdentifier: String
            let amountTitle: String
            if self.inputMode == .fiat, self.currentRate != nil {
                if self.amount > 0 {
                    let amountText = walletSendInputText(
                        amount: self.amount,
                        mode: .fiat,
                        rate: self.currentRate,
                        dateTimeFormat: environment.dateTimeFormat
                    )
                    amountTitle = walletSendGroupedAmountText(amountText, dateTimeFormat: environment.dateTimeFormat)
                        + " " + self.currentFiatCurrency.code
                } else {
                    amountTitle = self.currentFiatCurrency.code
                }
                sendIdentifier = "fiat"
            } else {
                if self.amount > 0 {
                    let amountText = walletSendInputText(
                        amount: self.amount,
                        mode: .gram,
                        rate: nil,
                        dateTimeFormat: environment.dateTimeFormat
                    )
                    let groupedAmountText = walletSendGroupedAmountText(amountText, dateTimeFormat: environment.dateTimeFormat)
                    let pluralizationValue: Int32 = self.amount == 1_000_000_000 ? 1 : 100
                    amountTitle = environment.strings.Currency_Grams(pluralizationValue).replacingOccurrences(
                        of: "\(pluralizationValue)",
                        with: groupedAmountText
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
            let canSend = hasAmount
                && hasRecipient
                && !self.isPreparingTransfer
                && !self.isSubmittingTransfer
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
                    displaysProgress: self.isResolvingSigningAccess || self.isPreparingTransfer,
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
                transition.setAlpha(view: sendButtonView, alpha: showSendButton ? 1.0 : 0.0)
                sendButtonView.isUserInteractionEnabled = hasAmount
            }

            if isInAttachmentMenu {
                let isTabBarVisible = !isKeyboardVisible
                if self.isAttachmentTabBarVisible != isTabBarVisible {
                    self.isAttachmentTabBarVisible = isTabBarVisible
                    DispatchQueue.main.async { [weak self, weak attachmentController] in
                        guard let self, self.isAttachmentTabBarVisible == isTabBarVisible else { return }
                        attachmentController?.updateTabBarVisibility(isTabBarVisible, transition.containedViewLayoutTransition)
                    }
                }
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
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
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
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
    }

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
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
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
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
