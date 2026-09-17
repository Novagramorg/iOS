import Foundation
import UIKit
import Display
import AccountContext
import WalletContext
import PasscodeCore
import SwiftSignalKit
import TelegramNotices
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import PresentationDataUtils
import TelegramStringFormatting
import AlertComponent
import AlertCheckComponent
import UndoUI
import WalletAuthorizationUI

private final class WalletSettingsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext

    init(context: AccountContext, walletContext: WalletContext) {
        self.context = context
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletSettingsScreenComponent, rhs: WalletSettingsScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.walletContext === rhs.walletContext
    }

    final class View: UIView {
        private enum WalletFlow { case create, enableBackup, disableBackup }
        private enum BackupAction {
            case enable, disable

            func isAvailable(for info: WalletContext.WalletInfo) -> Bool {
                switch self {
                case .enable:
                    return info.canEnableBackup
                case .disable:
                    return info.backupEnabled
                }
            }
        }
        private struct BackupAccessRequest {
            enum Phase { case restoring, importing, ready }

            let action: BackupAction
            let walletContext: WalletContext
            let address: String
            let publicKey: String
            var phase: Phase = .restoring
        }
        private var walletFlow: WalletFlow?
        private var flowSession: PasscodeSession?
        private var flowGeneration: UInt64 = 0
        private var backupAccessRequest: BackupAccessRequest?
        private var backupAccessGeneration: UInt64 = 0
        private var backupAccessSession: PasscodeSession?
        private let backupAccessDisposable = MetaDisposable()
        private var isVisible = false
        private let scrollView: UIScrollView
        private let recoverySection = ComponentView<Empty>()
        private let backupSection = ComponentView<Empty>()
        private let replacementSection = ComponentView<Empty>()
        private let previousWalletsSection = ComponentView<Empty>()
        #if DEBUG
        private let debugSection = ComponentView<Empty>()
        private let debugRemoveMnemonicDisposable = MetaDisposable()
        private var isRemovingMnemonic = false
        #endif

        private var component: WalletSettingsScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        private var isUpdating = false
        private let operationDisposable = MetaDisposable()
        private let backupOperationDisposable = MetaDisposable()
        private let walletStateDisposable = MetaDisposable()
        private var walletState: WalletContext.State?
        private let previousWalletsDisposable = MetaDisposable()
        private var previousWallets: [WalletContext.PreviousWallet] = []
        private var previousWalletsGeneration: UInt64 = 0
        private let previousWalletPhraseDisposable = MetaDisposable()
        private var previousWalletPhraseGeneration: UInt64 = 0
        private var isOpeningPreviousWalletPhrase = false
        private weak var backupWordsController: ViewController?
        private var preparedBackupDisable: WalletContext.PreparedBackupDisable? {
            didSet {
                if let previous = oldValue, previous.id != self.preparedBackupDisable?.id {
                    self.component?.walletContext.discardPreparedBackupDisable(previous)
                }
            }
        }
        private weak var disableBackupPreparationController: AlertScreen?
        private var disableBackupPreparationProgress: ValuePromise<Bool>?
        private var disableBackupPreparationContent: Promise<[AnyComponentWithIdentity<AlertComponentEnvironment>]>?
        private var disableBackupPreparationActions: Promise<[AlertScreen.Action]>?
        private var disableBackupCheckState: AlertCheckComponent.ExternalState?
        private let disableBackupChoiceDisposable = MetaDisposable()
        private var disableBackupPreparationGeneration: UInt64 = 0
        private var disableBackupUpdateSecretPhrase = false
        private var disableBackupRequiresTopUp = false
        private var disableBackupRotationPreview: WalletContext.PreparedBackupDisable?
        private var disableBackupPreparationError: WalletContext.WalletError?
        private var disableBackupWalletIdentity: (address: String, publicKey: String)?
        private var isPreparingBackupDisable = false
        private weak var disableBackupConfirmationController: AlertScreen?
        private var disableBackupProgress: ValuePromise<Bool>?
        private var isDisablingBackup = false
        private weak var replacementOptionsController: AlertScreen?
        private var replacementCreationProgress: ValuePromise<Bool>?
        private var isCreatingReplacementWallet = false

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.addSubview(self.scrollView)

        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.flowSession?.invalidate()
            self.backupAccessSession?.invalidate()
            if let prepared = self.preparedBackupDisable { self.component?.walletContext.discardPreparedBackupDisable(prepared) }
            self.operationDisposable.dispose()
            self.backupOperationDisposable.dispose()
            self.backupAccessDisposable.dispose()
            self.disableBackupChoiceDisposable.dispose()
            self.walletStateDisposable.dispose()
            self.previousWalletsDisposable.dispose()
            self.previousWalletPhraseDisposable.dispose()
            #if DEBUG
            self.debugRemoveMnemonicDisposable.dispose()
            #endif
        }

        private func endWalletFlow() {
            self.flowGeneration &+= 1
            self.flowSession?.invalidate()
            self.flowSession = nil
            self.walletFlow = nil
        }

        fileprivate func abandonWalletFlow() {
            self.abandonBackupAccess()
            self.cancelPreviousWalletPhrase()
            self.disableBackupPreparationGeneration &+= 1
            self.disableBackupChoiceDisposable.set(nil)
            self.disableBackupPreparationContent = nil
            self.disableBackupPreparationActions = nil
            self.disableBackupCheckState = nil
            self.disableBackupRequiresTopUp = false
            self.disableBackupRotationPreview = nil
            self.disableBackupPreparationError = nil
            self.disableBackupWalletIdentity = nil
            self.isPreparingBackupDisable = false
            self.operationDisposable.set(nil)
            self.backupOperationDisposable.set(nil)
            self.preparedBackupDisable = nil
            self.endWalletFlow()
        }

        private func walletFlowAuthorization(for flow: WalletFlow) -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if self.walletFlow != flow {
                self.endWalletFlow()
                self.walletFlow = flow
            }
            if let session = self.flowSession, session.isValid { return .single(session) }
            let generation = self.flowGeneration
            return component.walletContext.beginWalletFlow(reason: String(describing: flow))
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.flowGeneration == generation else { session.invalidate(); return .fail(.authorizationCancelled) }
                self.flowSession?.invalidate()
                self.flowSession = session
                return .single(session)
            }
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        fileprivate func visibilityUpdated(_ isVisible: Bool) {
            self.isVisible = isVisible
            if isVisible {
                if self.backupAccessRequest?.phase == .importing {
                    self.abandonBackupAccess()
                } else {
                    self.resumeBackupActionIfReady()
                }
            } else {
                self.cancelPreviousWalletPhrase()
            }
        }

        private func reloadPreviousWallets() {
            guard let component = self.component else {
                return
            }
            self.previousWalletsGeneration &+= 1
            let generation = self.previousWalletsGeneration
            let walletContext = component.walletContext
            self.previousWalletsDisposable.set((walletContext.previousWallets()
            |> deliverOnMainQueue).start(next: { [weak self] previousWallets in
                guard let self,
                      self.previousWalletsGeneration == generation,
                      self.component?.walletContext === walletContext else {
                    return
                }
                self.previousWallets = previousWallets
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.25))
                }
            }))
        }

        private func cancelPreviousWalletPhrase() {
            self.previousWalletPhraseGeneration &+= 1
            self.previousWalletPhraseDisposable.set(nil)
            self.isOpeningPreviousWalletPhrase = false
        }

        private func openPreviousWalletPhrase(id: String) {
            guard self.isVisible,
                  !self.isOpeningPreviousWalletPhrase,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  component.walletContext.stateValue.activeOperation == nil,
                  self.previousWallets.contains(where: { $0.id == id }) else {
                return
            }
            self.abandonWalletFlow()
            self.isOpeningPreviousWalletPhrase = true
            let generation = self.previousWalletPhraseGeneration
            let walletContext = component.walletContext
            self.previousWalletPhraseDisposable.set((walletContext.previousWalletRecoveryPhrase(id: id)
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] words in
                guard let self,
                      self.previousWalletPhraseGeneration == generation,
                      self.component?.walletContext === walletContext,
                      self.isVisible,
                      let controller else {
                    return
                }
                self.isOpeningPreviousWalletPhrase = false
                controller.push(component.context.sharedContext.makeWalletWordsScreen(
                    context: component.context,
                    words: words,
                    verify: false,
                    dismissOnBackgroundOrLock: true,
                    completion: nil
                ))
            }, error: { [weak self] error in
                guard let self,
                      self.previousWalletPhraseGeneration == generation,
                      self.component?.walletContext === walletContext,
                      self.isVisible else {
                    return
                }
                self.isOpeningPreviousWalletPhrase = false
                self.presentRecoveryPhraseError(error: error)
            }))
        }

        private func abandonBackupAccess() {
            self.backupAccessGeneration &+= 1
            self.backupAccessRequest = nil
            self.backupAccessDisposable.set(nil)
            self.backupAccessSession?.invalidate()
            self.backupAccessSession = nil
        }

        private func beginBackupAction(_ action: BackupAction) {
            guard self.backupAccessRequest == nil,
                  let component = self.component,
                  component.walletContext.stateValue.activeOperation == nil,
                  case let .wallet(info) = component.walletContext.stateValue.phase,
                  action.isAvailable(for: info) else {
                return
            }
            self.abandonWalletFlow()
            if info.canSign {
                self.performBackupAction(action)
                return
            }
            self.backupAccessRequest = BackupAccessRequest(
                action: action,
                walletContext: component.walletContext,
                address: info.address,
                publicKey: info.publicKey
            )
            self.resolveBackupAccess()
        }

        private func performBackupAction(_ action: BackupAction) {
            switch action {
            case .enable:
                self.enableBackup()
            case .disable:
                self.presentDisableBackupAlert()
            }
        }

        private func backupAccessAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let request = self.backupAccessRequest else { return .fail(.authorizationCancelled) }
            if let session = self.backupAccessSession, session.isValid { return .single(session) }
            let generation = self.backupAccessGeneration
            return request.walletContext.beginWalletFlow(reason: "Restore wallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.backupAccessGeneration == generation else {
                    session.invalidate()
                    return .fail(.authorizationCancelled)
                }
                self.backupAccessSession?.invalidate()
                self.backupAccessSession = session
                return .single(session)
            }
        }

        private func resolveBackupAccess() {
            guard let request = self.backupAccessRequest,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            guard component.walletContext === request.walletContext,
                  case let .wallet(info) = request.walletContext.stateValue.phase,
                  info.address == request.address, info.publicKey == request.publicKey,
                  request.action.isAvailable(for: info) else {
                self.abandonBackupAccess()
                return
            }
            if info.canSign {
                self.backupAccessRequest?.phase = .ready
                self.resumeBackupActionIfReady()
                return
            }
            let generation = self.backupAccessGeneration
            if info.canExportPhrase {
                self.backupAccessDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                        guard let self, self.backupAccessGeneration == generation else { return .fail(.authorizationCancelled) }
                        return self.backupAccessAuthorization()
                        |> mapToSignal { session in request.walletContext.recoveryPhrase(password: password, session: session) }
                    },
                    next: { [weak self] _ in
                        guard let self, self.backupAccessGeneration == generation else { return }
                        self.backupAccessDisposable.set(nil)
                        self.backupAccessSession?.invalidate()
                        self.backupAccessSession = nil
                        self.backupAccessRequest?.phase = .ready
                        self.resumeBackupActionIfReady()
                    },
                    failed: { [weak self] error in
                        guard let self, self.backupAccessGeneration == generation else { return }
                        self.presentBackupAccessError(error)
                    }
                ))
            } else {
                self.openRecoveryPhraseImport(backupAccessGeneration: generation)
            }
        }

        private func resumeBackupActionIfReady() {
            guard let request = self.backupAccessRequest else { return }
            guard self.component?.walletContext === request.walletContext,
                  case let .wallet(info) = request.walletContext.stateValue.phase,
                  info.address == request.address, info.publicKey == request.publicKey,
                  request.action.isAvailable(for: info) else {
                self.abandonBackupAccess()
                return
            }
            guard request.phase == .ready, self.isVisible,
                  info.canSign, request.walletContext.stateValue.activeOperation == nil,
                  self.walletState?.activeOperation == nil else {
                return
            }
            self.abandonBackupAccess()
            self.performBackupAction(request.action)
        }

        private func presentBackupAccessError(_ error: WalletContext.WalletError) {
            if error == .authorizationCancelled {
                self.abandonBackupAccess()
                return
            }
            guard let component = self.component, let controller = self.environment?.controller() else { return }
            let generation = self.backupAccessGeneration
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Restore Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                        guard let self, self.backupAccessGeneration == generation else { return }
                        self.abandonBackupAccess()
                    }),
                    TextAlertAction(type: .defaultAction, title: "Retry", action: { [weak self] in
                        guard let self, self.backupAccessGeneration == generation else { return }
                        self.resolveBackupAccess()
                    })
                ],
                dismissOnOutsideTap: false
            ), in: .window(.root))
        }

        private func openRecoveryPhrase() {
            self.abandonWalletFlow()
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletInfoScreen(
                context: component.context,
                mode: .recovery,
                completion: { [weak self] in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    self.operationDisposable.set(performWalletAuthorizedOperation(
                        context: component.context,
                        present: { [weak controller] alert in
                            controller?.present(alert, in: .window(.root))
                        },
                        operation: { password in
                            component.walletContext.recoveryPhrase(password: password)
                        },
                        next: { words in
                            controller.push(component.context.sharedContext.makeWalletWordsScreen(
                                context: component.context,
                                words: words,
                                verify: false,
                                dismissOnBackgroundOrLock: true,
                                completion: nil
                            ))
                        },
                        failed: { [weak self] error in
                            self?.presentRecoveryPhraseError(error: error)
                        }
                    ))
                }
            ))
        }

        private func presentRecoveryPhraseError(error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Show Secret Phrase",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport(backupAccessGeneration: UInt64? = nil) {
            if let backupAccessGeneration {
                guard self.backupAccessGeneration == backupAccessGeneration else { return }
                self.backupAccessRequest?.phase = .importing
            } else {
                self.abandonWalletFlow()
            }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport(backupAccessGeneration: backupAccessGeneration)
                }
            ))
        }

        private func completeRecoveryPhraseImport(backupAccessGeneration: UInt64? = nil) {
            guard let component = self.component,
                  let settingsController = self.environment?.controller(),
                  let navigationController = settingsController.navigationController as? NavigationController,
                  let settingsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === settingsController }) else {
                return
            }
            let viewControllers = Array(navigationController.viewControllers.prefix(through: settingsControllerIndex))
            if let backupAccessGeneration {
                if self.backupAccessGeneration == backupAccessGeneration {
                    self.backupAccessRequest?.phase = .ready
                }
                navigationController.setViewControllers(viewControllers, animated: true)
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            navigationController.setViewControllers(viewControllers, animated: true)
            Queue.mainQueue().after(0.4) { [weak settingsController] in
                settingsController?.present(UndoOverlayController(
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

        private func presentDisableBackupAlert(restarting: Bool = false) {
            if restarting, self.preparedBackupDisable == nil || self.backupWordsController == nil {
                return
            }
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  case let .wallet(info) = component.walletContext.stateValue.phase,
                  info.backupEnabled,
                  self.walletState?.activeOperation == nil,
                  self.disableBackupPreparationController == nil,
                  !self.isPreparingBackupDisable else {
                return
            }

            let updateSecretPhrase = restarting && self.preparedBackupDisable?.updateSecretPhrase == true
            if restarting {
                self.dismissBackupWordsFlow()
            }
            self.disableBackupWalletIdentity = (info.address, info.publicKey)
            self.disableBackupUpdateSecretPhrase = updateSecretPhrase
            self.disableBackupRequiresTopUp = updateSecretPhrase && self.disableBackupHasLowBalance
            self.disableBackupRotationPreview = nil
            self.disableBackupPreparationError = nil
            let checkState = AlertCheckComponent.ExternalState()
            self.disableBackupCheckState = checkState
            let content = Promise<[AnyComponentWithIdentity<AlertComponentEnvironment>]>()
            self.disableBackupPreparationContent = content
            let actions = Promise<[AlertScreen.Action]>()
            self.disableBackupPreparationActions = actions
            let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
            self.disableBackupPreparationProgress = progress
            self.updateDisableBackupPreparationContent()

            let alertController = AlertScreen(
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false),
                contentSignal: content.get(),
                actionsSignal: actions.get(),
                updatedPresentationData: (
                    component.context.sharedContext.currentPresentationData.with { $0 },
                    component.context.sharedContext.presentationData
                )
            )
            self.disableBackupPreparationController = alertController
            alertController.dismissed = { [weak self, weak alertController] _ in
                guard let self, self.disableBackupPreparationController === alertController else {
                    return
                }
                self.disableBackupPreparationController = nil
                self.disableBackupPreparationProgress = nil
                self.abandonWalletFlow()
            }
            self.disableBackupChoiceDisposable.set((checkState.valueSignal
            |> deliverOnMainQueue).start(next: { [weak self, weak checkState] _ in
                guard let self, let checkState,
                      self.disableBackupCheckState === checkState,
                      self.disableBackupUpdateSecretPhrase != checkState.value else {
                    return
                }
                self.updateDisableBackupPreparationState(updateSecretPhrase: checkState.value)
            }))
            controller.present(alertController, in: .window(.root))
            if updateSecretPhrase {
                self.prepareDisableBackup(openWordsWhenReady: false)
            }
        }

        private var disableBackupHasLowBalance: Bool {
            guard let balance = self.walletState?.balance.currentValue else {
                return false
            }
            return balance < 500_000
        }

        private func updateDisableBackupPreparationState(updateSecretPhrase: Bool) {
            guard self.disableBackupCheckState != nil else {
                return
            }
            let requiresTopUp = updateSecretPhrase && self.disableBackupHasLowBalance
            guard self.disableBackupUpdateSecretPhrase != updateSecretPhrase || self.disableBackupRequiresTopUp != requiresTopUp else {
                self.updateDisableBackupPreparationContent()
                return
            }
            self.disableBackupUpdateSecretPhrase = updateSecretPhrase
            self.disableBackupRequiresTopUp = requiresTopUp
            self.disableBackupPreparationGeneration &+= 1
            self.backupOperationDisposable.set(nil)
            if requiresTopUp {
                self.disableBackupRotationPreview = nil
            } else if let prepared = self.preparedBackupDisable, prepared.updateSecretPhrase {
                self.disableBackupRotationPreview = prepared
            }
            self.preparedBackupDisable = updateSecretPhrase ? self.disableBackupRotationPreview : nil
            self.isPreparingBackupDisable = false
            self.disableBackupPreparationProgress?.set(false)
            self.disableBackupPreparationError = nil
            self.updateDisableBackupPreparationContent()
            if updateSecretPhrase, !requiresTopUp, self.disableBackupRotationPreview == nil {
                self.prepareDisableBackup(openWordsWhenReady: false)
            }
        }

        private func disableBackupFeeText(_ fee: Int64) -> String {
            guard let component = self.component else {
                return ""
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            var text = formatTonAmountText(
                fee,
                dateTimeFormat: presentationData.dateTimeFormat,
                maxDecimalPositions: 5,
                formatString: presentationData.strings.Currency_Grams
            )
            if let fiat = self.walletState?.fiat,
               let rate = fiat.selectedRate,
               rate.unitsPerGram.isFinite, rate.unitsPerGram > 0.0 {
                let fiatText = formatTonFiatValue(
                    fee,
                    rate: rate.unitsPerGram,
                    currencySymbol: fiat.selectedCurrency.symbol,
                    dateTimeFormat: presentationData.dateTimeFormat
                )
                text += " (~\(fiatText))"
            }
            return text
        }

        private func updateDisableBackupPreparationContent() {
            guard let content = self.disableBackupPreparationContent,
                  let actions = self.disableBackupPreparationActions,
                  let progress = self.disableBackupPreparationProgress,
                  let checkState = self.disableBackupCheckState else {
                return
            }
            var items: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(AlertTitleComponent(title: "Disable Backup?"))
                ),
                AnyComponentWithIdentity(
                    id: "text",
                    component: AnyComponent(AlertTextComponent(content: .plain(
                        "The only way to recover your funds will be to manually enter your secret phrase."
                    )))
                ),
                AnyComponentWithIdentity(
                    id: "updateSecretPhrase",
                    component: AnyComponent(AlertCheckComponent(
                        title: "Update Secret Phrase",
                        alignment: .default,
                        initialValue: self.disableBackupUpdateSecretPhrase,
                        externalState: checkState
                    ))
                )
            ]
            if self.disableBackupRequiresTopUp {
                items.append(AnyComponentWithIdentity(
                    id: "topUpInfo",
                    component: AnyComponent(AlertTextComponent(
                        content: .plain("You need a non-zero balance to update your secret phrase."),
                        alignment: .center,
                        color: .primary,
                        style: .background(.small),
                        insets: UIEdgeInsets(top: 8.0, left: 8.0, bottom: 0.0, right: 8.0)
                    ))
                ))
            } else if self.disableBackupUpdateSecretPhrase, let prepared = self.preparedBackupDisable {
                var text = "You'll get a new phrase to write down. Address and balance stay the same."
                if let fee = prepared.networkFeeNanograms {
                    text += "\n\nNetwork fee: \(self.disableBackupFeeText(fee))."
                }
                items.append(AnyComponentWithIdentity(
                    id: "rotationInfo",
                    component: AnyComponent(AlertTextComponent(
                        content: .plain(text),
                        alignment: .center,
                        style: .background(.small),
                        insets: UIEdgeInsets(top: 8.0, left: 8.0, bottom: 0.0, right: 8.0)
                    ))
                ))
            }
            if !self.disableBackupRequiresTopUp, let error = self.disableBackupPreparationError {
                let message = self.disableBackupErrorMessage(error)
                items.append(AnyComponentWithIdentity(
                    id: "preparationError",
                    component: AnyComponent(AlertTextComponent(
                        content: .plain(message.text + "\n\nTap Disable to try again."),
                        color: .destructive,
                        style: .plain(.small),
                        insets: UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
                    ))
                ))
            }
            content.set(.single(items))
            actions.set(.single([
                AlertScreen.Action(title: "Cancel", action: { [weak self] in
                    self?.abandonWalletFlow()
                }),
                AlertScreen.Action(
                    id: "primary",
                    title: self.disableBackupRequiresTopUp ? "Top Up" : "Disable",
                    type: self.disableBackupRequiresTopUp ? .default : .destructive,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.disableBackupRequiresTopUp {
                            self.openDisableBackupTopUp()
                        } else {
                            self.beginDisableBackupPreparation()
                        }
                    },
                    autoDismiss: false,
                    isEnabled: progress.get() |> map { !$0 },
                    progress: progress.get()
                )
            ]))
        }

        private func openDisableBackupTopUp() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let alert = self.disableBackupPreparationController,
                  let identity = self.disableBackupWalletIdentity,
                  case let .wallet(info) = component.walletContext.stateValue.phase,
                  info.address == identity.address, info.publicKey == identity.publicKey else {
                return
            }
            self.disableBackupPreparationController = nil
            self.disableBackupPreparationProgress = nil
            self.abandonWalletFlow()
            alert.dismiss { [weak controller] in
                controller?.push(component.context.sharedContext.makeWalletReceiveScreen(
                    context: component.context,
                    address: info.address
                ))
            }
        }

        private func beginDisableBackupPreparation() {
            guard !self.isPreparingBackupDisable, !self.disableBackupRequiresTopUp else {
                return
            }
            if self.disableBackupPreparationError == nil,
               let prepared = self.preparedBackupDisable,
               prepared.updateSecretPhrase == self.disableBackupUpdateSecretPhrase {
                self.continueWithPreparedBackupDisable(prepared)
            } else {
                self.prepareDisableBackup(openWordsWhenReady: !self.disableBackupUpdateSecretPhrase)
            }
        }

        private func prepareDisableBackup(openWordsWhenReady: Bool) {
            guard !self.isPreparingBackupDisable,
                  !self.disableBackupRequiresTopUp,
                  self.disableBackupPreparationController != nil,
                  let component = self.component else {
                return
            }
            self.disableBackupPreparationGeneration &+= 1
            let generation = self.disableBackupPreparationGeneration
            let updateSecretPhrase = self.disableBackupUpdateSecretPhrase
            self.isPreparingBackupDisable = true
            self.disableBackupPreparationError = nil
            self.preparedBackupDisable = nil
            self.disableBackupPreparationProgress?.set(true)
            self.updateDisableBackupPreparationContent()
            self.backupOperationDisposable.set((self.walletFlowAuthorization(for: .disableBackup)
            |> mapToSignal { [weak self] session -> Signal<WalletContext.PreparedBackupDisable, WalletContext.WalletError> in
                guard let self, self.disableBackupPreparationGeneration == generation else {
                    return .fail(.authorizationCancelled)
                }
                return component.walletContext.prepareDisableBackup(updateSecretPhrase: updateSecretPhrase, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self, self.disableBackupPreparationGeneration == generation,
                      self.disableBackupPreparationController != nil,
                      self.disableBackupUpdateSecretPhrase == prepared.updateSecretPhrase else {
                    component.walletContext.discardPreparedBackupDisable(prepared)
                    return
                }
                self.isPreparingBackupDisable = false
                self.disableBackupPreparationProgress?.set(false)
                self.preparedBackupDisable = prepared
                self.updateDisableBackupPreparationContent()
                if openWordsWhenReady {
                    self.continueWithPreparedBackupDisable(prepared)
                }
            }, error: { [weak self] error in
                guard let self, self.disableBackupPreparationGeneration == generation,
                      self.disableBackupPreparationController != nil else {
                    return
                }
                self.isPreparingBackupDisable = false
                self.disableBackupPreparationProgress?.set(false)
                if error == .authorizationCancelled {
                    self.endWalletFlow()
                } else {
                    self.disableBackupPreparationError = error
                }
                self.updateDisableBackupPreparationContent()
            }))
        }

        private func continueWithPreparedBackupDisable(_ prepared: WalletContext.PreparedBackupDisable) {
            if let fee = prepared.networkFeeNanograms {
                guard let balance = self.walletState?.balance.currentValue else {
                    self.disableBackupPreparationError = .network
                    self.updateDisableBackupPreparationContent()
                    return
                }
                guard balance >= fee else {
                    self.disableBackupPreparationError = .insufficientBalance(required: fee)
                    self.updateDisableBackupPreparationContent()
                    return
                }
            }
            let generation = self.disableBackupPreparationGeneration
            let presentWords = { [weak self] in
                guard let self, self.disableBackupPreparationGeneration == generation,
                      self.preparedBackupDisable?.id == prepared.id else {
                    return
                }
                self.openBackupDisablePhrase(prepared: prepared)
            }
            self.disableBackupChoiceDisposable.set(nil)
            self.disableBackupPreparationContent = nil
            self.disableBackupPreparationActions = nil
            self.disableBackupCheckState = nil
            self.disableBackupRequiresTopUp = false
            self.disableBackupRotationPreview = nil
            self.disableBackupPreparationProgress = nil
            if let alert = self.disableBackupPreparationController {
                self.disableBackupPreparationController = nil
                alert.dismiss(completion: presentWords)
            } else {
                presentWords()
            }
        }

        private func openBackupDisablePhrase(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.preparedBackupDisable = prepared
            let wordsController = component.context.sharedContext.makeWalletWordsScreen(
                context: component.context,
                words: prepared.words,
                mode: .backupDisable(updateSecretPhrase: prepared.updateSecretPhrase),
                completion: { [weak self] in
                    self?.presentFinalDisableBackupAlert()
                }
            )
            self.backupWordsController = wordsController
            if let wordsController = wordsController as? ViewControllerComponentContainer {
                wordsController.wasDismissed = { [weak self, weak wordsController] in
                    Queue.mainQueue().justDispatch { [weak self, weak wordsController] in
                        guard let self,
                              self.backupWordsController === wordsController,
                              self.preparedBackupDisable?.id == prepared.id else {
                            return
                        }
                        if let wordsController,
                           let navigationController = wordsController.navigationController,
                           navigationController.viewControllers.contains(where: { $0 === wordsController }) {
                            return
                        }
                        self.backupWordsController = nil
                        self.isDisablingBackup = false
                        self.isPreparingBackupDisable = false
                        self.abandonWalletFlow()
                    }
                }
            }
            controller.push(wordsController)
        }

        private func presentFinalDisableBackupAlert(refresh: Bool = true) {
            guard let component = self.component,
                  let prepared = self.preparedBackupDisable,
                  let controller = self.backupWordsController?.navigationController?.topViewController as? ViewController
                    ?? self.environment?.controller() else {
                return
            }
            if refresh {
                guard !self.isDisablingBackup else { return }
                let generation = self.disableBackupPreparationGeneration
                self.isDisablingBackup = true
                self.backupOperationDisposable.set((self.walletFlowAuthorization(for: .disableBackup)
                |> mapToSignal { session in component.walletContext.refreshPreparedBackupDisable(prepared, session: session) }
                |> deliverOnMainQueue).start(next: { [weak self] updated in
                    guard let self, self.disableBackupPreparationGeneration == generation,
                          self.preparedBackupDisable?.id == prepared.id else { return }
                    self.isDisablingBackup = false
                    self.preparedBackupDisable = updated
                    self.presentFinalDisableBackupAlert(refresh: false)
                }, error: { [weak self] error in
                    guard let self, self.disableBackupPreparationGeneration == generation,
                          self.preparedBackupDisable?.id == prepared.id else { return }
                    self.isDisablingBackup = false
                    if error == .preparedBackupDisableExpired {
                        self.presentDisableBackupAlert(restarting: true)
                        return
                    }
                    self.presentFinalDisableBackupAlert(refresh: false)
                    self.presentDisableBackupError(error: error)
                }))
                return
            }
            var text = prepared.updateSecretPhrase
                ? "Your wallet will switch to the new secret phrase. After the change is confirmed, Telegram will delete the encrypted backup stored across its datacenters."
                : "Telegram will delete the encrypted backup stored across its datacenters. Your secret phrase will be the only way to recover this wallet."
            if let fee = prepared.networkFeeNanograms {
                text += "\n\nNetwork fee: \(self.disableBackupFeeText(fee))."
            }
            let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let actionsEnabled = progress.get() |> map { !$0 }
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false),
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(title: "Disable Backup?"))
                    ),
                    AnyComponentWithIdentity(
                        id: "text",
                        component: AnyComponent(AlertTextComponent(content: .plain(text)))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: "Cancel", action: { [weak self] in
                        self?.dismissBackupWordsFlow()
                    }, isEnabled: actionsEnabled),
                    AlertScreen.Action(
                        title: "Disable",
                        type: .destructive,
                        action: { [weak self] in
                            self?.submitDisableBackup(prepared: prepared)
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled,
                        progress: progress.get()
                    )
                ]
            )
            self.disableBackupConfirmationController = alertController
            self.disableBackupProgress = progress
            alertController.dismissed = { [weak self, weak alertController] _ in
                guard let self, self.disableBackupConfirmationController === alertController else {
                    return
                }
                self.disableBackupConfirmationController = nil
                self.disableBackupProgress = nil
                self.isDisablingBackup = false
            }
            controller.present(alertController, in: .window(.root))
        }

        private func submitDisableBackup(prepared: WalletContext.PreparedBackupDisable) {
            guard !self.isDisablingBackup,
                  self.preparedBackupDisable?.id == prepared.id,
                  let component = self.component else {
                return
            }
            let generation = self.disableBackupPreparationGeneration
            self.isDisablingBackup = true
            self.disableBackupProgress?.set(true)
            self.backupOperationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak self] alert in
                    self?.environment?.controller()?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization(for: .disableBackup)
                    |> mapToSignal { session in
                        component.walletContext.disableBackup(prepared, password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    guard let self, self.disableBackupPreparationGeneration == generation,
                          self.preparedBackupDisable?.id == prepared.id else { return }
                    let complete: () -> Void = { [weak self] in
                        guard let self, self.disableBackupPreparationGeneration == generation else { return }
                        self.dismissBackupWordsFlow()
                        self.presentBackupDisabledToast()
                    }
                    if let alertController = self.disableBackupConfirmationController {
                        alertController.dismiss(completion: complete)
                    } else {
                        complete()
                    }
                },
                failed: { [weak self] error in
                    guard let self, self.disableBackupPreparationGeneration == generation,
                          self.preparedBackupDisable?.id == prepared.id else { return }
                    self.isDisablingBackup = false
                    self.disableBackupProgress?.set(false)
                    if error == .preparedBackupDisableExpired {
                        let restart: () -> Void = { [weak self] in
                            guard let self, self.disableBackupPreparationGeneration == generation,
                                  self.preparedBackupDisable?.id == prepared.id else { return }
                            self.presentDisableBackupAlert(restarting: true)
                        }
                        if let alert = self.disableBackupConfirmationController {
                            alert.dismiss(completion: restart)
                        } else {
                            restart()
                        }
                        return
                    }
                    if case let .backupDisableNeedsConfirmation(updated) = error {
                        self.preparedBackupDisable = updated
                        let confirm: () -> Void = { [weak self] in
                            guard let self, self.disableBackupPreparationGeneration == generation,
                                  self.preparedBackupDisable?.id == updated.id else { return }
                            self.presentFinalDisableBackupAlert(refresh: false)
                        }
                        if let alert = self.disableBackupConfirmationController {
                            alert.dismiss(completion: confirm)
                        } else {
                            confirm()
                        }
                        return
                    }
                    if error == .authorizationCancelled { self.endWalletFlow() }
                    self.presentDisableBackupError(error: error)
                }
            ))
        }

        private func dismissBackupWordsFlow() {
            let wordsController = self.backupWordsController
            self.backupWordsController = nil
            self.isDisablingBackup = false
            self.abandonWalletFlow()
            guard let wordsController else {
                return
            }
            if let navigationController = wordsController.navigationController as? NavigationController,
               let index = navigationController.viewControllers.firstIndex(where: { $0 === wordsController }) {
                navigationController.setViewControllers(
                    Array(navigationController.viewControllers.prefix(upTo: index)),
                    animated: true
                )
            } else {
                wordsController.dismiss()
            }
        }

        private func disableBackupErrorMessage(_ error: WalletContext.WalletError?) -> (title: String, text: String) {
            switch error {
            case .proofInvalid?:
                return ("Couldn't Verify Wallet", "Telegram couldn't verify that you own this wallet. Please try again.")
            case .proofExpired?:
                return ("Verification Expired", "The wallet verification request expired. Tap Disable to try again.")
            case .rotationNotFound?:
                return (
                    "Secret Phrase Update Pending",
                    "Telegram couldn't confirm the secret phrase change on the blockchain yet. Wait a moment and tap Disable again."
                )
            case .keyRotationFailed?:
                return ("Couldn't Update Secret Phrase", "The secret phrase change could not be completed. Check your wallet state and try again.")
            case let .insufficientBalance(required)?:
                return (
                    "Not Enough Grams",
                    "You need \(self.disableBackupFeeText(required)) to update your secret phrase. Add funds and try again."
                )
            default:
                return error.flatMap(walletAuthorizationErrorMessage)
                    ?? ("Couldn't Disable Backup", "Couldn't confirm that backup was disabled. Check the network connection and try again.")
            }
        }

        private func presentDisableBackupError(error: WalletContext.WalletError? = nil) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component,
                  let controller = self.backupWordsController?.navigationController?.topViewController as? ViewController
                    ?? self.environment?.controller() else {
                return
            }
            let message = self.disableBackupErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message.title,
                text: message.text,
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func reconcileBackupDisableWalletState() {
            guard let identity = self.disableBackupWalletIdentity,
                  let walletState = self.walletState else {
                return
            }
            switch walletState.phase {
            case .restoring, .creating:
                return
            case let .wallet(info):
                if info.address == identity.address {
                    if info.publicKey == identity.publicKey {
                        if !info.backupEnabled, let alert = self.disableBackupPreparationController {
                            self.disableBackupPreparationController = nil
                            self.disableBackupPreparationProgress = nil
                            self.abandonWalletFlow()
                            alert.dismiss()
                            return
                        }
                        self.updateDisableBackupPreparationState(updateSecretPhrase: self.disableBackupUpdateSecretPhrase)
                        return
                    }
                    if let newPublicKey = self.preparedBackupDisable?.rotation?.newPublicKey,
                       info.publicKey == newPublicKey.map({ String(format: "%02x", $0) }).joined() {
                        return
                    }
                }
            case .empty, .failed:
                break
            }
            let preparationController = self.disableBackupPreparationController
            let confirmationController = self.disableBackupConfirmationController
            self.disableBackupPreparationController = nil
            self.disableBackupConfirmationController = nil
            self.disableBackupPreparationProgress = nil
            self.disableBackupProgress = nil
            self.dismissBackupWordsFlow()
            preparationController?.dismiss()
            confirmationController?.dismiss()
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Wallet Changed",
                text: "The wallet's secret phrase changed while you were updating backup settings. Restore access using the current secret phrase and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func presentBackupDisabledToast() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .actionSucceeded(
                    title: "Backup Disabled",
                    text: "Your secret phrase is now the only way to restore your wallet.",
                    cancel: nil,
                    destructive: false
                ),
                position: .bottom,
                action: { _ in false }
            ), in: .current)
        }

        private func enableBackup() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.backupOperationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization(for: .enableBackup) |> mapToSignal { session in
                        component.walletContext.enableBackup(password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    self?.endWalletFlow()
                    self?.presentBackupEnabledToast()
                },
                failed: { [weak self] error in
                    if error == .authorizationCancelled { self?.endWalletFlow() }
                    self?.presentBackupOperationError(error)
                }
            ))
        }

        private func presentBackupEnabledToast() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .actionSucceeded(
                    title: "Backup Enabled",
                    text: "Your keys are now stored encrypted across Telegram's datacenters.",
                    cancel: nil,
                    destructive: false
                ),
                position: .bottom,
                action: { _ in false }
            ), in: .current)
        }

        private func presentBackupOperationError(_ error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Update Backup",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func presentDeleteWalletAlert() {
            self.abandonWalletFlow()
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Delete Wallet?",
                text: "You'll lose access to your funds unless you've saved your secret phrase.",
                actions: [
                    TextAlertAction(type: .destructiveAction, title: "Delete Anyway", action: { [weak self] in
                        Queue.mainQueue().after(0.25) { [weak self] in
                            self?.presentWalletReplacementOptionsAlert()
                        }
                    }),
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {})
                ],
                actionLayout: .vertical
            ), in: .window(.root))
        }

        private func presentWalletReplacementOptionsAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let creationProgress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let actionsEnabled = creationProgress.get()
            |> map { !$0 }
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(
                    actionAlignment: .vertical,
                    dismissOnOutsideTap: true
                ),
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(
                            title: "How do you want to replace the old wallet?"
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(
                        title: "Create a New Wallet",
                        action: { [weak self] in
                            self?.createReplacementWallet()
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled,
                        progress: creationProgress.get()
                    ),
                    AlertScreen.Action(
                        title: "Import an Existing Wallet",
                        action: { [weak self] in
                            self?.openReplacementImport()
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled
                    )
                ]
            )
            self.replacementOptionsController = alertController
            self.replacementCreationProgress = creationProgress
            alertController.dismissed = { [weak self, weak alertController] outside in
                guard let self, self.replacementOptionsController === alertController else {
                    return
                }
                self.replacementOptionsController = nil
                self.replacementCreationProgress = nil
                self.isCreatingReplacementWallet = false
                if outside { self.abandonWalletFlow() }
                else { self.endWalletFlow() }
            }
            controller.present(alertController, in: .window(.root))
        }

        private func openReplacementImport() {
            guard !self.isCreatingReplacementWallet,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let alertController = self.replacementOptionsController else {
                return
            }
            alertController.dismiss { [weak self, weak controller] in
                controller?.push(component.context.sharedContext.makeWalletImportScreen(
                    context: component.context,
                    mode: .importWallet,
                    completion: { [weak self] in
                        self?.completeWalletReplacement(
                            toastTitle: "Wallet Imported",
                            toastText: "Your wallet was restored from your secret phrase."
                        )
                    }
                ))
            }
        }

        private func completeWalletReplacement(toastTitle: String, toastText: String) {
            guard let component = self.component else {
                return
            }
            let accountManager = component.context.sharedContext.accountManager
            let _ = (ApplicationSpecificNotice.resetWalletGramTooltip(accountManager: accountManager)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] in
                guard let self,
                      let component = self.component,
                      let settingsController = self.environment?.controller(),
                      let navigationController = settingsController.navigationController as? NavigationController,
                      let settingsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === settingsController }),
                      settingsControllerIndex > 0 else {
                    return
                }
                
                let remainingViewControllers = Array(navigationController.viewControllers.prefix(upTo: settingsControllerIndex))
                guard let walletController = remainingViewControllers.last as? ViewController else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                navigationController.setViewControllers(remainingViewControllers, animated: true)
                Queue.mainQueue().after(0.4) { [weak walletController] in
                    guard let walletController else {
                        return
                    }
                    //TODO:localize
                    walletController.present(UndoOverlayController(
                        presentationData: presentationData,
                        content: .actionSucceeded(
                            title: toastTitle,
                            text: toastText,
                            cancel: nil,
                            destructive: false
                        ),
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in
                            return false
                        }
                    ), in: .current)
                }
            })
        }

        private func createReplacementWallet() {
            guard !self.isCreatingReplacementWallet,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let alertController = self.replacementOptionsController,
                  let creationProgress = self.replacementCreationProgress else {
                return
            }
            self.isCreatingReplacementWallet = true
            creationProgress.set(true)
            let createdWallet = Atomic<WalletContext.WalletInfo?>(value: nil)
            self.operationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization(for: .create) |> mapToSignal { session in
                        let creation: Signal<WalletContext.WalletInfo, WalletContext.WalletError>
                        if let created = createdWallet.with({ $0 }) {
                            creation = .single(created)
                        } else {
                            creation = component.walletContext.createWallet(password: password, session: session)
                        }
                        return creation |> deliverOnMainQueue |> mapToSignal { created in
                            _ = createdWallet.swap(created)
                            return self.walletFlowAuthorization(for: .create) |> mapToSignal { session in
                                component.walletContext.completeWalletCreation(created, password: password, session: session)
                            }
                        }
                    }
                },
                next: { [weak self, weak alertController] _ in
                    self?.endWalletFlow()
                    let complete: () -> Void = { [weak self] in
                        self?.completeWalletReplacement(
                            toastTitle: "Wallet Created",
                            toastText: "Your new wallet is ready to use."
                        )
                    }
                    if let alertController {
                        alertController.dismiss(completion: complete)
                    } else {
                        complete()
                    }
                },
                failed: { [weak self] error in
                    guard let self else {
                        return
                    }
                    self.isCreatingReplacementWallet = false
                    self.replacementCreationProgress?.set(false)
                    if error == .authorizationCancelled { self.endWalletFlow() }
                    self.presentReplacementError(error)
                }
            ))
        }

        private func presentReplacementError(_ error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Replace Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func debugRemoveMnemonicFromKeychain() {
            guard !self.isRemovingMnemonic, let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.isRemovingMnemonic = true
            self.debugRemoveMnemonicDisposable.set((component.walletContext.debugRemoveMnemonicFromKeychain()
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] _ in
                guard let self else {
                    return
                }
                self.isRemovingMnemonic = false
                guard let controller else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                controller.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: "Mnemonic Deleted",
                        text: "The local mnemonic was deleted from Keychain.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }, error: { [weak self, weak controller] _ in
                guard let self else {
                    return
                }
                self.isRemovingMnemonic = false
                guard let controller else {
                    return
                }
                controller.present(textAlertController(
                    context: component.context,
                    title: "Couldn’t Delete Mnemonic",
                    text: "The mnemonic could not be deleted from Keychain. Please try again.",
                    actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
                ), in: .window(.root))
            }))
        }

        func update(
            component: WalletSettingsScreenComponent,
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
            let previousWalletContext = self.component?.walletContext
            self.component = component
            self.environment = environment
            self.state = state

            if previousWalletContext !== component.walletContext {
                self.abandonBackupAccess()
                self.cancelPreviousWalletPhrase()
                self.previousWalletsGeneration &+= 1
                self.previousWalletsDisposable.set(nil)
                self.previousWallets = []
                self.walletState = component.walletContext.stateValue
                if self.isVisible {
                    self.reloadPreviousWallets()
                }
                let observedWalletContext = component.walletContext
                self.walletStateDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.component?.walletContext === observedWalletContext else {
                        return
                    }
                    let previousPhase = self.walletState?.phase
                    self.walletState = walletState
                    if previousPhase != walletState.phase, self.isVisible {
                        self.reloadPreviousWallets()
                    }
                    self.reconcileBackupDisableWalletState()
                    self.resumeBackupActionIfReady()
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                }))
                self.reloadPreviousWallets()
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.blocksBackgroundColor

            //TODO:localize
            let recoveryHeader = "Secret Phrase"
            //TODO:localize
            //TODO:localize
            let backupHeader = "Encrypted Backup"
            //TODO:localize
            let enableBackupAction = "Enable Backup"
            //TODO:localize
            let disableBackupAction = "Disable Backup"
            //TODO:localize
            let deleteWalletAction = "Delete Wallet"

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let headerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let footerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let actionFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
            let sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let sectionSpacing: CGFloat = 24.0
            let sectionWidth = availableSize.width - sideInset * 2.0
            var contentHeight = environment.navigationHeight + 16.0
            let canDisableBackup: Bool
            let canEnableBackup: Bool
            let canRevealPhrase: Bool
            let canEnterRecoveryPhrase: Bool
            let backupEnabled: Bool
            if let phase = self.walletState?.phase, case let .wallet(info) = phase {
                canDisableBackup = info.backupEnabled
                canEnableBackup = info.canEnableBackup
                canRevealPhrase = info.canRevealPhrase
                canEnterRecoveryPhrase = !info.canSign && !info.canExportPhrase
                backupEnabled = info.backupEnabled
            } else {
                canDisableBackup = false
                canEnableBackup = false
                canRevealPhrase = false
                canEnterRecoveryPhrase = false
                backupEnabled = false
            }
            //TODO:localize
            let recoveryAction = canEnterRecoveryPhrase ? "Enter Secret Phrase" : "Show Secret Phrase"
            //TODO:localize
            let recoveryFooter = canEnterRecoveryPhrase
                ? "Enter your secret phrase to restore access to this wallet."
                : "You can transfer your wallet to another device by copying your 12- or 24-word secret phrase."
            //TODO:localize
            let backupFooter = backupEnabled
                ? "Your encrypted key backup is split into three parts and stored across three continents.\n\nIt can only be reassembled on your devices, so no one — not even Telegram — can access your key."
                : "Your encrypted key backup will be split into three parts and stored across three continents.\n\nIt can only be reassembled on your devices, so no one — not even Telegram — can access your key."

            self.recoverySection.parentState = self.state
            let recoverySectionSize = self.recoverySection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: recoveryHeader.uppercased(),
                            font: headerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: recoveryFooter,
                            font: footerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: "showRecoveryPhrase", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: recoveryAction,
                                    font: actionFont,
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                if canEnterRecoveryPhrase {
                                    self?.openRecoveryPhraseImport()
                                } else {
                                    self?.openRecoveryPhrase()
                                }
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if canRevealPhrase || canEnterRecoveryPhrase, let recoverySectionView = self.recoverySection.view {
                if recoverySectionView.superview == nil {
                    self.scrollView.addSubview(recoverySectionView)
                }
                transition.setFrame(
                    view: recoverySectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: recoverySectionSize
                    )
                )
                contentHeight += recoverySectionSize.height
                contentHeight += sectionSpacing
            } else {
                self.recoverySection.view?.removeFromSuperview()
            }

            var backupItems: [AnyComponentWithIdentity<Empty>] = []
            if canEnableBackup {
                backupItems.append(AnyComponentWithIdentity(id: "enableBackup", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: enableBackupAction,
                            font: actionFont,
                            textColor: theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    accessory: nil,
                    action: { [weak self] _ in
                        self?.beginBackupAction(.enable)
                    }
                ))))
            }
            if canDisableBackup {
                backupItems.append(AnyComponentWithIdentity(id: "disableBackup", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: disableBackupAction,
                            font: actionFont,
                            textColor: theme.list.itemDestructiveColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    accessory: nil,
                    action: { [weak self] _ in
                        self?.beginBackupAction(.disable)
                    }
                ))))
            }
            if !backupItems.isEmpty {
                self.backupSection.parentState = self.state
                let backupSectionSize = self.backupSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: backupHeader.uppercased(),
                                font: headerFont,
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: backupFooter,
                                font: footerFont,
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: backupItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: sectionWidth, height: 10000.0)
                )
                if let backupSectionView = self.backupSection.view {
                    if backupSectionView.superview == nil {
                        self.scrollView.addSubview(backupSectionView)
                    }
                    transition.setFrame(
                        view: backupSectionView,
                        frame: CGRect(
                            origin: CGPoint(x: sideInset, y: contentHeight),
                            size: backupSectionSize
                        )
                    )
                }
                contentHeight += backupSectionSize.height
                contentHeight += sectionSpacing
            } else {
                self.backupSection.view?.removeFromSuperview()
            }

            self.replacementSection.parentState = self.state
            let replacementSectionSize = self.replacementSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "deleteWallet", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: deleteWalletAction,
                                    font: actionFont,
                                    textColor: theme.list.itemDestructiveColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.presentDeleteWalletAlert()
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if let replacementSectionView = self.replacementSection.view {
                if replacementSectionView.superview == nil {
                    self.scrollView.addSubview(replacementSectionView)
                }
                transition.setFrame(
                    view: replacementSectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: replacementSectionSize
                    )
                )
            }
            contentHeight += replacementSectionSize.height

            if !self.previousWallets.isEmpty {
                let addressFont = Font.with(size: presentationData.listsFontSize.baseDisplaySize * 15.0 / 17.0, design: .monospace)
                let subtitleFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
                let calendar = Calendar.current
                let dateFormatter = DateFormatter()
                //TODO:localize
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = calendar.timeZone
                dateFormatter.dateFormat = "d MMM yyyy"

                let previousWalletItems: [AnyComponentWithIdentity<Empty>] = self.previousWallets.map { wallet in
                    let text = NSMutableAttributedString(string: "")
                    var addressIndex = wallet.address.startIndex
                    var groupIndex = 0
                    while addressIndex < wallet.address.endIndex {
                        let endIndex = wallet.address.index(addressIndex, offsetBy: 4, limitedBy: wallet.address.endIndex) ?? wallet.address.endIndex
                        if groupIndex != 0 {
                            text.append(NSAttributedString(
                                string: groupIndex.isMultiple(of: 6) ? "\n" : " ",
                                font: addressFont,
                                textColor: theme.list.itemPrimaryTextColor
                            ))
                        }
                        text.append(NSAttributedString(
                            string: String(wallet.address[addressIndex ..< endIndex]),
                            font: addressFont,
                            textColor: (groupIndex + groupIndex / 6).isMultiple(of: 2) ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor
                        ))
                        addressIndex = endIndex
                        groupIndex += 1
                    }

                    let balanceText: String
                    if let balance = wallet.balance {
                        balanceText = formatTonAmountText(
                            balance,
                            dateTimeFormat: environment.dateTimeFormat,
                            maxDecimalPositions: 9,
                            formatString: environment.strings.Currency_Grams
                        )
                    } else {
                        balanceText = environment.strings.Currency_Grams(100).replacingOccurrences(of: "100", with: "—")
                    }
                    let lastUsedDate = Date(timeIntervalSince1970: Double(wallet.lastUsedAt))
                    let lastUsedText: String
                    if calendar.isDateInToday(lastUsedDate) {
                        //TODO:localize
                        lastUsedText = "today"
                    } else if calendar.isDateInYesterday(lastUsedDate) {
                        //TODO:localize
                        lastUsedText = "yesterday"
                    } else {
                        lastUsedText = dateFormatter.string(from: lastUsedDate)
                    }
                    //TODO:localize
                    text.append(NSAttributedString(
                        string: "\n\(balanceText) — last used \(lastUsedText)",
                        font: subtitleFont,
                        textColor: theme.list.itemSecondaryTextColor
                    ))

                    return AnyComponentWithIdentity(id: wallet.id, component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(text),
                            maximumNumberOfLines: 0
                        )),
                        accessory: .arrow,
                        action: { [weak self] _ in
                            self?.openPreviousWalletPhrase(id: wallet.id)
                        }
                    )))
                }

                contentHeight += sectionSpacing
                self.previousWalletsSection.parentState = self.state

                var transition = transition
                if self.previousWalletsSection.view == nil {
                    transition = .immediate
                }
                let previousWalletsSectionSize = self.previousWalletsSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                //TODO:localize
                                string: "Previous Wallets".uppercased(),
                                font: headerFont,
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                //TODO:localize
                                string: "Wallets you used before on this device. Save their secret phrases — they'll be removed if you log out or reinstall the app.",
                                font: footerFont,
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: previousWalletItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: sectionWidth, height: 10000.0)
                )
                if let previousWalletsSectionView = self.previousWalletsSection.view {
                    if previousWalletsSectionView.superview == nil {
                        self.scrollView.addSubview(previousWalletsSectionView)
                    }
                    transition.setFrame(
                        view: previousWalletsSectionView,
                        frame: CGRect(
                            origin: CGPoint(x: sideInset, y: contentHeight),
                            size: previousWalletsSectionSize
                        )
                    )
                }
                contentHeight += previousWalletsSectionSize.height
            } else {
                self.previousWalletsSection.view?.removeFromSuperview()
            }

            #if DEBUG && false
            contentHeight += sectionSpacing
            self.debugSection.parentState = self.state
            let debugSectionSize = self.debugSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "deleteMnemonic", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: "Delete Mnemonic from Keychain",
                                    font: actionFont,
                                    textColor: theme.list.itemDestructiveColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.debugRemoveMnemonicFromKeychain()
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if let debugSectionView = self.debugSection.view {
                if debugSectionView.superview == nil {
                    self.scrollView.addSubview(debugSectionView)
                }
                transition.setFrame(
                    view: debugSectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: debugSectionSize
                    )
                )
            }
            contentHeight += debugSectionSize.height
            #endif
            contentHeight += 24.0 + environment.safeInsets.bottom

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(
                top: environment.navigationHeight,
                left: 0.0,
                bottom: environment.safeInsets.bottom,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
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

public final class WalletSettingsScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, walletContext: WalletContext) {
        //TODO:localize
        let title = "Keys & Backup"

        super.init(
            context: context,
            component: WalletSettingsScreenComponent(context: context, walletContext: walletContext),
            navigationBarAppearance: .default,
            theme: .default
        )

        self.title = title
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? WalletSettingsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (self.node.hostView.componentView as? WalletSettingsScreenComponent.View)?.visibilityUpdated(true)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        (self.node.hostView.componentView as? WalletSettingsScreenComponent.View)?.visibilityUpdated(false)
        super.viewWillDisappear(animated)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            (self.node.hostView.componentView as? WalletSettingsScreenComponent.View)?.abandonWalletFlow()
        }
    }
}
