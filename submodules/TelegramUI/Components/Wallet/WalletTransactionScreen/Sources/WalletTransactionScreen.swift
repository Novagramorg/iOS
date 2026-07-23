import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import GlassControls
import TableComponent
import ContextUI
import TelegramStringFormatting
import TextFormat
import TextFieldComponent
import UndoUI
import WalletContext

private final class WalletTransactionContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletTransactionScreenMode
    let fiatWalletContext: WalletContext?
    let openExplorer: (String) -> Void
    let animateOut: ActionSlot<Action<Void>>

    init(
        context: AccountContext,
        mode: WalletTransactionScreenMode,
        fiatWalletContext: WalletContext?,
        openExplorer: @escaping (String) -> Void,
        animateOut: ActionSlot<Action<Void>>
    ) {
        self.context = context
        self.mode = mode
        self.fiatWalletContext = fiatWalletContext
        self.openExplorer = openExplorer
        self.animateOut = animateOut
    }

    static func ==(lhs: WalletTransactionContentComponent, rhs: WalletTransactionContentComponent) -> Bool {
        if lhs.context !== rhs.context || lhs.fiatWalletContext !== rhs.fiatWalletContext {
            return false
        }
        switch (lhs.mode, rhs.mode) {
        case let (.transaction(lhsTransaction), .transaction(rhsTransaction)):
            return lhsTransaction == rhsTransaction
        case let (.preview(lhsContext, lhsTransfer, _), .preview(rhsContext, rhsTransfer, _)):
            return lhsContext === rhsContext && lhsTransfer == rhsTransfer
        default:
            return false
        }
    }

    final class View: UIView {
        private enum PreviewOperation: Equatable {
            case ready
            case preparing
            case authorizing
            case submitting
            case pending
            case confirmed

            var displaysProgress: Bool {
                switch self {
                case .authorizing, .submitting, .pending:
                    return true
                case .ready, .preparing, .confirmed:
                    return false
                }
            }
        }

        private let controlButtons = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let usdValue = ComponentView<Empty>()
        private let processingDot = ComponentView<Empty>()
        private let processingText = ComponentView<Empty>()
        private let commentBackgroundView = UIImageView()
        private let commentText = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let inputBackground = ComponentView<Empty>()
        private let inputField = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()

        private var component: WalletTransactionContentComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var modeId: String?

        private var transaction: WalletContext.Transaction?
        private var walletContext: WalletContext?
        private var preparedTransfer: WalletContext.PreparedTransfer?
        private var preparedTransferNeedsRefresh = false
        private var dismissSendScreen: (() -> Void)?
        private var didDismissSendScreen = false
        private var previewOperation: PreviewOperation = .ready
        private var preparingForSend = false
        private var previewTimestamp = Int32(Date().timeIntervalSince1970)
        private var submittedTransfer: WalletContext.SubmittedTransfer?
        private var baselineTransactionIds = Set<String>()
        private var latestWalletState: WalletContext.State?
        private var didShowSuccess = false

        private let inputExternalState = TextFieldComponent.ExternalState()
        private var commentRevision = 0
        private var isApplyingInput = false

        private let walletDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private let hapticFeedback = HapticFeedback()
        private var amountPending = false
        private var isUpdating = false

        private var cachedCommentBubbleImage: (
            theme: PresentationTheme,
            corners: PresentationChatBubbleCorners,
            incoming: Bool,
            fillColor: UIColor,
            image: UIImage
        )?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.commentBackgroundView.contentMode = .scaleToFill
            self.addSubview(self.commentBackgroundView)
            self.inputExternalState.updated = { [weak self] in
                self?.inputTextUpdated()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.walletDisposable.dispose()
            self.transferDisposable.dispose()
        }

        private var isPreview: Bool {
            return self.walletContext != nil
        }

        private var isConfirmedPreview: Bool {
            return self.isPreview && self.previewOperation == .confirmed
        }

        private func configureMode(_ mode: WalletTransactionScreenMode, fiatWalletContext: WalletContext?) {
            self.walletDisposable.set(nil)
            self.transferDisposable.set(nil)
            self.transaction = nil
            self.walletContext = nil
            self.preparedTransfer = nil
            self.preparedTransferNeedsRefresh = false
            self.dismissSendScreen = nil
            self.didDismissSendScreen = false
            self.previewOperation = .ready
            self.preparingForSend = false
            self.submittedTransfer = nil
            self.baselineTransactionIds.removeAll()
            self.latestWalletState = nil
            self.didShowSuccess = false
            self.amountPending = false
            self.commentRevision += 1

            switch mode {
            case let .transaction(transaction):
                self.modeId = "transaction:\(transaction.id):\(transaction.logicalTime)"
                self.transaction = transaction
            case let .preview(walletContext, preparedTransfer, dismissSendScreen):
                self.modeId = "preview:\(preparedTransfer.id)"
                self.walletContext = walletContext
                self.preparedTransfer = preparedTransfer
                self.dismissSendScreen = dismissSendScreen
                self.previewTimestamp = Int32(Date().timeIntervalSince1970)
                self.isApplyingInput = true
                self.inputExternalState.initialText = NSAttributedString(string: preparedTransfer.comment ?? "")
                self.isApplyingInput = false

            }

            let observedContext = self.walletContext ?? fiatWalletContext
            if let observedContext {
                self.walletDisposable.set((observedContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self,
                          self.walletContext === observedContext
                            || (self.walletContext == nil && self.component?.fiatWalletContext === observedContext) else {
                        return
                    }
                    self.latestWalletState = state
                    self.checkForConfirmation()
                    if !self.isUpdating {
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    }
                }))
            }
        }

        private func currentTransaction() -> WalletContext.Transaction {
            if let transaction = self.transaction {
                return transaction
            }
            guard let preparedTransfer = self.preparedTransfer else {
                preconditionFailure("Preview must have a prepared transfer")
            }
            return WalletContext.Transaction(
                id: "preview-\(preparedTransfer.id)",
                logicalTime: preparedTransfer.id,
                timestamp: self.previewTimestamp,
                direction: .outgoing,
                amount: preparedTransfer.amount,
                fee: preparedTransfer.fee,
                counterparty: preparedTransfer.recipient,
                comment: walletTransactionComment(self.inputExternalState.text.string) ?? preparedTransfer.comment
            )
        }

        private func dismissSendScreenIfNeeded() {
            guard !self.didDismissSendScreen else {
                return
            }
            self.didDismissSendScreen = true
            self.dismissSendScreen?()
        }

        private func close() {
            guard let component = self.component,
                  let controller = self.environment?.controller() as? WalletTransactionScreen else {
                return
            }
            switch self.previewOperation {
            case .submitting, .pending, .confirmed:
                self.dismissSendScreenIfNeeded()
            case .preparing:
                self.commentRevision += 1
                self.transferDisposable.set(nil)
                self.previewOperation = .ready
                self.preparingForSend = false
            case .authorizing:
                self.previewOperation = .ready
                self.preparingForSend = false
            case .ready:
                break
            }
            component.animateOut.invoke(Action { [weak controller] _ in
                controller?.dismiss(completion: nil)
            })
        }

        private func toggleAmountPending() {
            guard !self.isPreview else {
                return
            }
            self.amountPending.toggle()
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func inputTextUpdated() {
            guard !self.isApplyingInput,
                  self.isPreview,
                  self.previewOperation == .ready || (self.previewOperation == .preparing && !self.preparingForSend) else {
                return
            }
            let comment = walletTransactionComment(self.inputExternalState.text.string)
            if self.preparedTransfer?.comment == comment {
                self.commentRevision += 1
                self.transferDisposable.set(nil)
                self.previewOperation = .ready
                self.preparingForSend = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            self.commentRevision += 1
            let revision = self.commentRevision
            self.previewOperation = .preparing
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            Queue.mainQueue().after(0.35) { [weak self] in
                guard let self, self.commentRevision == revision else {
                    return
                }
                self.prepareCurrentComment(revision: revision, authorizeAfterPreparation: false)
            }
        }

        private func prepareCurrentComment(revision: Int? = nil, authorizeAfterPreparation: Bool) {
            guard let walletContext = self.walletContext,
                  let preparedTransfer = self.preparedTransfer else {
                return
            }
            if let revision, revision != self.commentRevision {
                return
            }
            let comment = walletTransactionComment(self.inputExternalState.text.string)
            self.previewOperation = .preparing
            self.preparingForSend = authorizeAfterPreparation
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.transferDisposable.set((walletContext.prepareTransfer(
                address: preparedTransfer.recipient,
                amount: preparedTransfer.amount,
                comment: comment
            )
            |> deliverOnMainQueue).start(next: { [weak self] updatedTransfer in
                guard let self else {
                    return
                }
                if let revision, revision != self.commentRevision {
                    return
                }
                self.preparedTransfer = updatedTransfer
                self.preparedTransferNeedsRefresh = false
                self.preparingForSend = false
                if authorizeAfterPreparation {
                    self.authorizeAndSubmit(updatedTransfer)
                } else {
                    self.previewOperation = .ready
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                if let revision, revision != self.commentRevision {
                    return
                }
                self.previewOperation = .ready
                self.preparingForSend = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError()
            }))
        }

        private func send() {
            guard self.isPreview, self.previewOperation == .ready, let preparedTransfer = self.preparedTransfer else {
                return
            }
            let comment = walletTransactionComment(self.inputExternalState.text.string)
            let isExpired = TimeInterval(preparedTransfer.expiresAt) <= Date().timeIntervalSince1970
            if self.preparedTransferNeedsRefresh || preparedTransfer.comment != comment || isExpired {
                self.prepareCurrentComment(authorizeAfterPreparation: true)
            } else {
                self.authorizeAndSubmit(preparedTransfer)
            }
        }

        private func authorizeAndSubmit(_ preparedTransfer: WalletContext.PreparedTransfer) {
            guard let component = self.component else {
                return
            }
            self.previewOperation = .authorizing
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            component.context.sharedContext.authorizeWalletAccess(context: component.context, completion: { [weak self] authorized in
                guard let self, self.previewOperation == .authorizing else {
                    return
                }
                guard authorized else {
                    self.previewOperation = .ready
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    return
                }
                self.submit(preparedTransfer)
            })
        }

        private func submit(_ preparedTransfer: WalletContext.PreparedTransfer) {
            guard let walletContext = self.walletContext else {
                return
            }
            self.baselineTransactionIds = Set((self.latestWalletState?.transactions.items ?? []).map {
                "\($0.id):\($0.logicalTime)"
            })
            self.previewOperation = .submitting
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.transferDisposable.set((walletContext.submitTransfer(preparedTransfer)
            |> deliverOnMainQueue).start(next: { [weak self] submittedTransfer in
                guard let self else {
                    return
                }
                self.submittedTransfer = submittedTransfer
                self.preparedTransferNeedsRefresh = false
                self.previewOperation = .pending
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.checkForConfirmation()
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.preparedTransferNeedsRefresh = true
                self.previewOperation = .ready
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError()
            }))
        }

        private func checkForConfirmation() {
            guard self.previewOperation == .pending,
                  let submittedTransfer = self.submittedTransfer,
                  let state = self.latestWalletState else {
                return
            }
            guard !state.pendingTransfers.contains(where: { $0.id == submittedTransfer.pendingTransfer.id }) else {
                return
            }
            let pendingTransfer = submittedTransfer.pendingTransfer
            guard let transaction = state.transactions.items.first(where: { transaction in
                guard !self.baselineTransactionIds.contains("\(transaction.id):\(transaction.logicalTime)"),
                      transaction.direction == .outgoing,
                      transaction.amount == pendingTransfer.amount,
                      transaction.counterparty == pendingTransfer.recipient,
                      walletTransactionComment(transaction.comment) == walletTransactionComment(pendingTransfer.comment),
                      transaction.timestamp >= pendingTransfer.createdAt - 60 else {
                    return false
                }
                return true
            }) else {
                return
            }

            self.transaction = transaction
            self.previewOperation = .confirmed
            self.dismissSendScreenIfNeeded()
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
            self.showSuccessIfNeeded(address: pendingTransfer.recipient)
        }

        private func showSuccessIfNeeded(address: String) {
            guard !self.didShowSuccess,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            self.didShowSuccess = true
            //TODO:localize
            let successPrefix = "Grams have been sent to "
            //TODO:localize
            let successSuffix = "."
            let text = successPrefix + walletTransactionShortAddress(address) + successSuffix
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .emoji(name: "TwoFactorSetupRememberSuccess", text: text),
                    position: .top,
                    action: { _ in
                        return false
                    }
                ),
                in: .window(.root)
            )
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

        private func copyAddress(_ address: String) {
            UIPasteboard.general.string = address
            self.hapticFeedback.tap()
        }

        private func commentBubbleImage(
            presentationData: PresentationData,
            incoming: Bool,
            fillColor: UIColor
        ) -> UIImage {
            let corners = presentationData.chatBubbleCorners
            if let cached = self.cachedCommentBubbleImage,
               cached.theme === presentationData.theme,
               cached.corners == corners,
               cached.incoming == incoming,
               cached.fillColor == fillColor {
                return cached.image
            }
            let image = messageBubbleImage(
                maxCornerRadius: corners.mainRadius,
                minCornerRadius: corners.auxiliaryRadius,
                incoming: incoming,
                fillColor: fillColor,
                strokeColor: .clear,
                neighbors: .none,
                shadow: nil,
                wallpaper: presentationData.chatWallpaper,
                knockout: false
            )
            self.cachedCommentBubbleImage = (presentationData.theme, corners, incoming, fillColor, image)
            return image
        }

        private func openExplorer(sourceView: UIView) {
            guard let component = self.component,
                  let controller = self.environment?.controller() as? WalletTransactionScreen,
                  let transaction = self.transaction else {
                return
            }
            let explorerUrl = walletTransactionExplorerUrl(id: transaction.id)
            //TODO:localize
            let viewInExplorer = "View In Explorer"
            let item = ContextMenuActionItem(
                text: viewInExplorer,
                icon: { theme in
                    return generateTintedImage(
                        image: UIImage(bundleImageName: "Chat/Context Menu/Search"),
                        color: theme.contextMenu.primaryColor
                    )
                },
                action: { [weak self] contextController, dismiss in
                    let open = {
                        guard let self, let explorerUrl else {
                            return
                        }
                        self.close()
                        component.openExplorer(explorerUrl)
                    }
                    if let contextController {
                        contextController.dismiss(result: .default, completion: open)
                    } else {
                        dismiss(.default)
                        open()
                    }
                }
            )
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                source: .reference(WalletTransactionContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list([.action(item)]))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        func update(
            component: WalletTransactionContentComponent,
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

            let incomingModeId: String
            switch component.mode {
            case let .transaction(transaction):
                incomingModeId = "transaction:\(transaction.id):\(transaction.logicalTime)"
            case let .preview(_, preparedTransfer, _):
                incomingModeId = "preview:\(preparedTransfer.id)"
            }
            if self.modeId != incomingModeId {
                self.configureMode(component.mode, fiatWalletContext: component.fiatWalletContext)
            }
            (environment.controller() as? WalletTransactionScreen)?.closeAction = { [weak self] in
                self?.close()
            }

            let theme = environment.theme
            let transaction = self.currentTransaction()
            let showsMore = !self.isPreview || self.isConfirmedPreview
            let controlsSize = self.controlButtons.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [GlassControlGroupComponent.Item(
                            id: AnyHashable("close"),
                            content: .icon("Navigation/Close"),
                            action: { [weak self] in
                                self?.close()
                            }
                        )],
                        background: .panel
                    ),
                    centralItem: nil,
                    rightItem: showsMore ? GlassControlPanelComponent.Item(
                        items: [GlassControlGroupComponent.Item(
                            id: AnyHashable("more"),
                            content: .animation("anim_morewide"),
                            action: { [weak self] in
                                guard let self,
                                      let controlsView = self.controlButtons.view as? GlassControlPanelComponent.View,
                                      let sourceView = controlsView.rightItemView?.itemView(id: AnyHashable("more")) else {
                                    return
                                }
                                self.openExplorer(sourceView: sourceView)
                            }
                        )],
                        background: .panel
                    ) : nil,
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 44.0)
            )
            if let controlsView = self.controlButtons.view {
                if controlsView.superview == nil {
                    self.addSubview(controlsView)
                }
                transition.setFrame(
                    view: controlsView,
                    frame: CGRect(x: 16.0, y: 16.0, width: controlsSize.width, height: controlsSize.height)
                )
            }

            let amountSize = self.amount.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(WalletTransactionAmountComponent(
                        theme: theme,
                        dateTimeFormat: environment.dateTimeFormat,
                        amount: transaction.amount,
                        direction: transaction.direction,
                        currency: transaction.currency,
                        pending: self.isPreview ? false : self.amountPending
                    )),
                    automaticHighlight: false,
                    action: { [weak self] in
                        self?.toggleAmountPending()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            var contentHeight: CGFloat = 71.0
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    self.addSubview(amountView)
                }
                transition.setFrame(
                    view: amountView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - amountSize.width) / 2.0),
                        y: contentHeight,
                        width: amountSize.width,
                        height: amountSize.height
                    )
                )
            }
            contentHeight += amountSize.height + 7.0

            let fiatCurrency = self.latestWalletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = self.latestWalletState?.fiat.selectedRate
            let usdText: String
            switch transaction.currency {
            case .ton:
                if let fiatRate {
                    usdText = formatTonFiatValue(
                        transaction.amount,
                        rate: fiatRate.unitsPerGram,
                        currencySymbol: fiatCurrency.symbol,
                        dateTimeFormat: environment.dateTimeFormat
                    )
                } else {
                    //TODO:localize
                    usdText = "—"
                }
            case .usdt:
                if let fiatRate {
                    usdText = formatFiatValue(
                        Double(transaction.amount) / 1_000_000.0 * fiatRate.unitsPerUsd,
                        currencySymbol: fiatCurrency.symbol,
                        dateTimeFormat: environment.dateTimeFormat
                    )
                } else {
                    //TODO:localize
                    usdText = "—"
                }
            }
            let usdSize = self.usdValue.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: usdText,
                        font: Font.regular(15.0),
                        textColor: theme.actionSheet.secondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 64.0, height: 24.0)
            )
            let displaysTestProcessing = !self.isPreview && self.amountPending
            let dotSize = self.processingDot.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: "•",
                        font: Font.regular(15.0),
                        textColor: theme.actionSheet.secondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 24.0)
            )
            //TODO:localize
            let processingLabel = "Processing..."
            let processingSize = self.processingText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: processingLabel,
                        font: Font.regular(15.0),
                        textColor: theme.actionSheet.controlAccentColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width / 2.0, height: 24.0)
            )
            let usdToDotSpacing: CGFloat = 6.0
            let dotToProcessingSpacing: CGFloat = 4.0
            let processingWidth = usdToDotSpacing + dotSize.width + dotToProcessingSpacing + processingSize.width
            let combinedWidth = usdSize.width + (displaysTestProcessing ? processingWidth : 0.0)
            let combinedX = floorToScreenPixels((availableSize.width - combinedWidth) / 2.0)
            if let usdView = self.usdValue.view {
                if usdView.superview == nil {
                    self.addSubview(usdView)
                }
                transition.setFrame(view: usdView, frame: CGRect(x: combinedX, y: contentHeight, width: usdSize.width, height: usdSize.height))
            }
            if let dotView = self.processingDot.view {
                if dotView.superview == nil {
                    self.addSubview(dotView)
                }
                transition.setFrame(view: dotView, frame: CGRect(x: combinedX + usdSize.width + usdToDotSpacing, y: contentHeight, width: dotSize.width, height: dotSize.height))
                transition.setAlpha(view: dotView, alpha: displaysTestProcessing ? 1.0 : 0.0)
            }
            if let processingView = self.processingText.view {
                if processingView.superview == nil {
                    self.addSubview(processingView)
                }
                transition.setFrame(view: processingView, frame: CGRect(
                    x: combinedX + usdSize.width + usdToDotSpacing + dotSize.width + dotToProcessingSpacing,
                    y: contentHeight,
                    width: processingSize.width,
                    height: processingSize.height
                ))
                transition.setAlpha(view: processingView, alpha: displaysTestProcessing ? 1.0 : 0.0)
            }
            contentHeight += usdSize.height

            let displaysCommentBubble = !self.isPreview || self.isConfirmedPreview
            if displaysCommentBubble, let comment = walletTransactionComment(transaction.comment) {
                contentHeight += 22.0
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let bubbleImage = self.commentBubbleImage(
                    presentationData: presentationData,
                    incoming: transaction.direction == .incoming,
                    fillColor: theme.list.itemInputField.backgroundColor
                )
                let commentSize = self.commentText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: comment,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.primaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 122.0, height: 1000.0)
                )
                let bubbleSize = CGSize(width: commentSize.width + 34.0, height: max(commentSize.height + 14.0, bubbleImage.size.height))
                self.commentBackgroundView.image = bubbleImage
                transition.setFrame(view: self.commentBackgroundView, frame: CGRect(
                    x: floorToScreenPixels(
                        (availableSize.width - bubbleSize.width) / 2.0
                        + (transaction.direction == .incoming ? -3.0 : 3.0)
                    ),
                    y: contentHeight,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                ))
                transition.setAlpha(view: self.commentBackgroundView, alpha: 1.0)
                if let commentView = self.commentText.view {
                    if commentView.superview == nil {
                        self.addSubview(commentView)
                    }
                    transition.setFrame(view: commentView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - commentSize.width) / 2.0),
                        y: contentHeight + floorToScreenPixels((bubbleSize.height - commentSize.height) / 2.0),
                        width: commentSize.width,
                        height: commentSize.height
                    ))
                    transition.setAlpha(view: commentView, alpha: 1.0)
                }
                contentHeight += bubbleSize.height + 32.0
            } else {
                transition.setAlpha(view: self.commentBackgroundView, alpha: 0.0)
                if let commentView = self.commentText.view {
                    transition.setAlpha(view: commentView, alpha: 0.0)
                }
                contentHeight += 44.0
            }

            let valueFont = Font.regular(15.0)
            let valueColor = theme.list.itemPrimaryTextColor
            let secondaryValueColor = theme.list.itemSecondaryTextColor
            let counterpartyTitle: String
            if self.isPreview && !self.isConfirmedPreview {
                //TODO:localize
                counterpartyTitle = "Address"
            } else {
                switch transaction.direction {
                case .incoming:
                    //TODO:localize
                    counterpartyTitle = "Sender"
                case .outgoing:
                    //TODO:localize
                    counterpartyTitle = "Recipient"
                case .unknown:
                    //TODO:localize
                    counterpartyTitle = "Address"
                }
            }
            let counterpartyText: String
            let counterpartyFont: UIFont
            if let counterparty = transaction.counterparty {
                counterpartyText = walletTransactionFormattedAddress(counterparty)
                counterpartyFont = Font.monospace(15.0)
            } else {
                //TODO:localize
                counterpartyText = "Unknown Address"
                counterpartyFont = valueFont
            }
            let counterpartyTextComponent: AnyComponent<Empty> = AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: counterpartyText, font: counterpartyFont, textColor: valueColor)),
                maximumNumberOfLines: 0,
                lineSpacing: 0.12
            ))
            let counterpartyComponent: AnyComponent<Empty>
            if let counterparty = transaction.counterparty {
                counterpartyComponent = AnyComponent(Button(
                    content: counterpartyTextComponent,
                    action: { [weak self] in
                        self?.copyAddress(counterparty)
                    }
                ))
            } else {
                counterpartyComponent = counterpartyTextComponent
            }
            var feeItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(
                    name: "Ads/TonAbout",
                    tintColor: UIColor(rgb: 0x30a1f5),
                    maxSize: CGSize(width: 14.0, height: 14.0)
                ))),
                AnyComponentWithIdentity(id: "amount", component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: formatTonAmountText(transaction.fee, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: 5),
                        font: valueFont,
                        textColor: valueColor
                    )),
                    maximumNumberOfLines: 1
                )))
            ]
            if let fiatRate {
                let usdFee = formatTonFiatValue(
                    transaction.fee,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: fiatCurrency.symbol,
                    maxDecimalPositions: 4,
                    dateTimeFormat: environment.dateTimeFormat
                )
                feeItems.append(AnyComponentWithIdentity(id: "usd", component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "~ \(usdFee)", font: valueFont, textColor: secondaryValueColor)),
                    maximumNumberOfLines: 1
                ))))
            }
            //TODO:localize
            let feeTitle = "Fee"
            //TODO:localize
            let dateTitle = "Date"
            var tableItems: [TableComponent.Item] = [TableComponent.Item(
                id: "counterparty",
                title: counterpartyTitle,
                component: counterpartyComponent
            )]
            if transaction.direction == .outgoing {
                tableItems.append(TableComponent.Item(
                    id: "fee",
                    title: feeTitle,
                    component: AnyComponent(HStack(feeItems, spacing: 3.0))
                ))
            }
            tableItems.append(TableComponent.Item(
                id: "date",
                title: dateTitle,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: walletTransactionDateText(
                            timestamp: transaction.timestamp,
                            strings: environment.strings,
                            dateTimeFormat: environment.dateTimeFormat
                        ),
                        font: valueFont,
                        textColor: valueColor
                    )),
                    maximumNumberOfLines: 1
                ))
            ))
            let tableWidth = availableSize.width - (32.0 + environment.safeInsets.left) * 2.0
            let tableSize = self.table.update(
                transition: transition,
                component: AnyComponent(TableComponent(theme: theme, items: tableItems)),
                environment: {},
                containerSize: CGSize(width: tableWidth, height: .greatestFiniteMagnitude)
            )
            if let tableView = self.table.view {
                if tableView.superview == nil {
                    self.addSubview(tableView)
                }
                transition.setFrame(view: tableView, frame: CGRect(
                    x: floorToScreenPixels((availableSize.width - tableSize.width) / 2.0),
                    y: contentHeight,
                    width: tableSize.width,
                    height: tableSize.height
                ))
            }
            contentHeight += tableSize.height

            let displaysInput = self.isPreview && !self.isConfirmedPreview
            if displaysInput {
                contentHeight += 16.0
                let inputWidth = max(0.0, tableSize.width - 24.0)
                //TODO:localize
                let optionalMessage = "Optional message"
                let fieldSize = self.inputField.update(
                    transition: transition,
                    component: AnyComponent(TextFieldComponent(
                        context: component.context,
                        theme: theme,
                        strings: environment.strings,
                        externalState: self.inputExternalState,
                        fontSize: 15.0,
                        textColor: theme.actionSheet.inputTextColor,
                        accentColor: theme.actionSheet.controlAccentColor,
                        insets: UIEdgeInsets(top: 10.0, left: 16.0, bottom: 10.0, right: 16.0),
                        hideKeyboard: false,
                        customInputView: nil,
                        placeholder: NSAttributedString(
                            string: optionalMessage,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.inputPlaceholderColor
                        ),
                        resetText: nil,
                        isOneLineWhenUnfocused: true,
                        characterLimit: nil,
                        emptyLineHandling: .notAllowed,
                        formatMenuAvailability: .none,
                        returnKeyType: .done,
                        keyboardType: .default,
                        autocapitalizationType: .sentences,
                        autocorrectionType: .default,
                        lockedFormatAction: {
                        },
                        present: { [weak self] controller in
                            self?.environment?.controller()?.present(controller, in: .window(.root))
                        },
                        paste: { _ in
                        },
                        returnKeyAction: { [weak self] in
                            self?.endEditing(true)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: inputWidth, height: 61.0)
                )
                let inputSize = CGSize(width: inputWidth, height: max(40.0, fieldSize.height))
                let inputBackgroundSize = self.inputBackground.update(
                    transition: transition,
                    component: AnyComponent(RoundedRectangle(
                        color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.itemInputField.backgroundColor,
                        cornerRadius: 20.0
                    )),
                    environment: {},
                    containerSize: inputSize
                )
                if let backgroundView = self.inputBackground.view {
                    if backgroundView.superview == nil {
                        self.addSubview(backgroundView)
                    }
                    transition.setFrame(view: backgroundView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - tableSize.width) / 2.0),
                        y: contentHeight,
                        width: tableSize.width,
                        height: inputBackgroundSize.height
                    ))
                    transition.setAlpha(view: backgroundView, alpha: 1.0)
                }
                if let fieldView = self.inputField.view {
                    if fieldView.superview == nil {
                        self.addSubview(fieldView)
                    }
                    transition.setFrame(view: fieldView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - fieldSize.width) / 2.0),
                        y: contentHeight + floorToScreenPixels((inputSize.height - fieldSize.height) / 2.0) + 1.0 - UIScreenPixel,
                        width: fieldSize.width,
                        height: fieldSize.height
                    ))
                    transition.setAlpha(view: fieldView, alpha: 1.0)
                    fieldView.isUserInteractionEnabled = self.previewOperation == .ready
                        || (self.previewOperation == .preparing && !self.preparingForSend)
                }
                contentHeight += inputSize.height
            } else {
                if let backgroundView = self.inputBackground.view {
                    transition.setAlpha(view: backgroundView, alpha: 0.0)
                }
                if let fieldView = self.inputField.view {
                    transition.setAlpha(view: fieldView, alpha: 0.0)
                }
            }

            contentHeight += 30.0
            let actionTitle: String
            if self.isPreview && !self.isConfirmedPreview {
                //TODO:localize
                let sendPrefix = "Send "
                //TODO:localize
                let gramsSuffix = " Grams"
                actionTitle = sendPrefix + formatTonAmountText(
                    transaction.amount,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: 9
                ) + gramsSuffix
            } else {
                //TODO:localize
                actionTitle = "OK"
            }
            let actionIsEnabled = !self.isPreview || self.previewOperation == .ready || self.previewOperation == .confirmed
            let actionSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(id: actionTitle, component: AnyComponent(Text(
                        text: actionTitle,
                        font: Font.semibold(17.0),
                        color: theme.list.itemCheckColors.foregroundColor
                    ))),
                    isEnabled: actionIsEnabled,
                    displaysProgress: self.isPreview && self.previewOperation.displaysProgress,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.isPreview && !self.isConfirmedPreview {
                            self.send()
                        } else {
                            self.close()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 60.0, height: 52.0)
            )
            if let actionView = self.actionButton.view {
                if actionView.superview == nil {
                    self.addSubview(actionView)
                }
                transition.setFrame(view: actionView, frame: CGRect(
                    x: floorToScreenPixels((availableSize.width - actionSize.width) / 2.0),
                    y: contentHeight,
                    width: actionSize.width,
                    height: actionSize.height
                ))
            }
            contentHeight += actionSize.height + 30.0
            if displaysInput {
                contentHeight += environment.inputHeight
            }

            return CGSize(width: availableSize.width, height: contentHeight)
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

private final class WalletTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletTransactionScreenMode
    let fiatWalletContext: WalletContext?
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        mode: WalletTransactionScreenMode,
        fiatWalletContext: WalletContext?,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.fiatWalletContext = fiatWalletContext
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionSheetComponent, rhs: WalletTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context || lhs.fiatWalletContext !== rhs.fiatWalletContext {
            return false
        }
        switch (lhs.mode, rhs.mode) {
        case let (.transaction(lhsTransaction), .transaction(rhsTransaction)):
            return lhsTransaction == rhsTransaction
        case let (.preview(lhsContext, lhsTransfer, _), .preview(rhsContext, rhsTransfer, _)):
            return lhsContext === rhsContext && lhsTransfer == rhsTransfer
        default:
            return false
        }
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let sheetComponent = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletTransactionContentComponent(
                        context: context.component.context,
                        mode: context.component.mode,
                        fiatWalletContext: context.component.fiatWalletContext,
                        openExplorer: context.component.openExplorer,
                        animateOut: animateOut
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { _ in
                            (controller() as? WalletTransactionScreen)?.requestClose()
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                controller.presentationContext.containerLayoutUpdated(
                    ContainerViewLayout(
                        size: context.availableSize,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                        safeInsets: UIEdgeInsets(
                            top: 0.0,
                            left: max(sideInset, environment.safeInsets.left),
                            bottom: 0.0,
                            right: max(sideInset, environment.safeInsets.right)
                        ),
                        additionalInsets: .zero,
                        statusBarHeight: environment.statusBarHeight,
                        inputHeight: nil,
                        inputHeightIsInteractivellyChanging: false,
                        inVoiceOver: false
                    ),
                    transition: context.transition.containedViewLayoutTransition
                )
            }
            return context.availableSize
        }
    }
}

public final class WalletTransactionScreen: ViewControllerComponentContainer {
    fileprivate var closeAction: (() -> Void)?

    public init(context: AccountContext, mode: WalletTransactionScreenMode) {
        let fiatWalletContext: WalletContext?
        switch mode {
        case .transaction:
            fiatWalletContext = context.walletContext
        case let .preview(walletContext, _, _):
            fiatWalletContext = walletContext
        }
        super.init(
            context: context,
            component: WalletTransactionSheetComponent(
                context: context,
                mode: mode,
                fiatWalletContext: fiatWalletContext,
                openExplorer: { url in
                    context.sharedContext.openExternalUrl(
                        context: context,
                        urlContext: .generic,
                        url: url,
                        forceExternal: true,
                        presentationData: context.sharedContext.currentPresentationData.with { $0 },
                        navigationController: nil,
                        dismissInput: {
                        }
                    )
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    fileprivate func requestClose() {
        if let closeAction = self.closeAction {
            closeAction()
        } else {
            self.dismiss(completion: nil)
        }
    }

    public func dismissAnimated() {
        self.requestClose()
    }
}

private func walletTransactionComment(_ value: String?) -> String? {
    guard var value else {
        return nil
    }
    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

private func walletTransactionShortAddress(_ address: String) -> String {
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

private func walletTransactionFormattedAddress(_ address: String) -> String {
    var groups: [String] = []
    var index = address.startIndex
    while index < address.endIndex {
        let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        groups.append(String(address[index ..< endIndex]))
        index = endIndex
    }
    var lines: [String] = []
    for lineStart in stride(from: 0, to: groups.count, by: 4) {
        let lineEnd = min(lineStart + 4, groups.count)
        lines.append(groups[lineStart ..< lineEnd].joined(separator: " "))
    }
    return lines.joined(separator: "\n")
}

private func walletTransactionDateText(
    timestamp: Int32,
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat
) -> String {
    let dateComponents = getDateTimeComponents(timestamp: timestamp)
    let date = stringForMediumCompactDate(
        timestamp: timestamp,
        strings: strings,
        dateTimeFormat: dateTimeFormat,
        withTime: false
    )
    let time = stringForShortTimestamp(
        hours: dateComponents.hour,
        minutes: dateComponents.minutes,
        dateTimeFormat: dateTimeFormat
    )
    return strings.Time_MediumDate(date, time).string
}

private func walletTransactionExplorerUrl(id: String) -> String? {
    let hash: String
    if id.count == 64 && id.unicodeScalars.allSatisfy({ scalar in
        switch scalar.value {
        case 48 ... 57, 65 ... 70, 97 ... 102:
            return true
        default:
            return false
        }
    }) {
        hash = id.lowercased()
    } else {
        var base64 = id.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64), data.count == 32 else {
            return nil
        }
        hash = data.map { String(format: "%02x", $0) }.joined()
    }
    return "https://tonviewer.com/transaction/\(hash)"
}

private final class WalletTransactionContextReferenceContentSource: ContextReferenceContentSource {
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
