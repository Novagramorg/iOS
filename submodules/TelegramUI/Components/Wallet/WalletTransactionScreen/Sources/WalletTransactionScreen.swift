import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
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
import TooltipUI
import WalletContext
import WalletCollectibleHeaderComponent

private func walletTransactionModeId(_ mode: WalletTransactionScreenMode) -> String {
    switch mode {
    case let .transaction(transaction):
        return "transaction:\(transaction.id):\(transaction.logicalTime)"
    case let .preview(_, preparedTransfer, _):
        return "preview:\(preparedTransfer.id)"
    }
}

private func walletTransactionCollectible(
    _ collectible: WalletContext.Collectible
) -> WalletContext.Transaction.CollectibleTransfer {
    let kind: WalletContext.Transaction.CollectibleTransfer.Kind
    switch collectible.kind {
    case .gift:
        kind = .gift
    case .username:
        kind = .username
    case .anonymousNumber:
        kind = .anonymousNumber
    case .other:
        kind = .other
    }
    return WalletContext.Transaction.CollectibleTransfer(
        address: collectible.address,
        name: collectible.name,
        imageUrl: collectible.imageUrl,
        lottieUrl: collectible.lottieUrl,
        collectionName: collectible.collectionName,
        collectionUrl: collectible.collectionUrl,
        kind: kind
    )
}

private func walletTransactionAddressesEqual(_ lhs: String, _ rhs: String) -> Bool {
    guard let lhs = WalletContext.transferAddress(from: lhs),
          let rhs = WalletContext.transferAddress(from: rhs) else {
        return false
    }
    return lhs == rhs
}

private func walletTransactionHashesEqual(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs, let rhs else {
        return false
    }
    return lhs.lowercased() == rhs.lowercased()
}

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
        private let collectibleHeader = ComponentView<Empty>()
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
                comment: walletTransactionComment(self.inputExternalState.text.string) ?? preparedTransfer.comment,
                collectible: preparedTransfer.collectible.map(walletTransactionCollectible)
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
            controller.dismissAllTooltips()
            controller.requestLayout(
                forceUpdate: true,
                transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
            )
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
            let preparation: Signal<WalletContext.PreparedTransfer, WalletContext.WalletError>
            if let collectible = preparedTransfer.collectible {
                preparation = walletContext.prepareCollectibleTransfer(
                    address: preparedTransfer.recipient,
                    collectible: collectible,
                    comment: comment
                )
            } else {
                preparation = walletContext.prepareTransfer(
                    address: preparedTransfer.recipient,
                    amount: preparedTransfer.amount,
                    comment: comment
                )
            }
            self.transferDisposable.set((preparation
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
                if preparedTransfer.collectible != nil {
                    self.dismissSendScreenIfNeeded()
                }
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
            let transaction = state.transactions.items.first(where: { transaction in
                guard !self.baselineTransactionIds.contains("\(transaction.id):\(transaction.logicalTime)"),
                      transaction.status == .completed,
                      transaction.direction == .outgoing,
                      let counterparty = transaction.counterparty,
                      walletTransactionAddressesEqual(counterparty, pendingTransfer.recipient) else {
                    return false
                }
                if let normalizedHash = pendingTransfer.normalizedHash {
                    guard walletTransactionHashesEqual(transaction.externalMessageHash, normalizedHash) else {
                        return false
                    }
                } else {
                    guard walletTransactionComment(transaction.comment) == walletTransactionComment(pendingTransfer.comment),
                          transaction.timestamp >= pendingTransfer.createdAt - 60 else {
                        return false
                    }
                }
                if let collectibleAddress = pendingTransfer.collectibleAddress {
                    guard let transactionCollectibleAddress = transaction.collectible?.address else {
                        return false
                    }
                    return walletTransactionAddressesEqual(transactionCollectibleAddress, collectibleAddress)
                } else {
                    return transaction.collectible == nil && transaction.amount == pendingTransfer.amount
                }
            })
            guard let transaction else {
                self.submittedTransfer = nil
                self.preparedTransferNeedsRefresh = true
                self.previewOperation = .ready
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError()
                return
            }

            self.transaction = transaction
            self.previewOperation = .confirmed
            self.dismissSendScreenIfNeeded()
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
            self.showSuccessIfNeeded(
                address: pendingTransfer.recipient,
                isCollectible: pendingTransfer.collectibleAddress != nil
            )
        }

        private func showSuccessIfNeeded(address: String, isCollectible: Bool) {
            guard !self.didShowSuccess,
                  let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            self.didShowSuccess = true
            //TODO:localize
            let successPrefix = isCollectible ? "NFT has been sent to " : "Grams have been sent to "
            //TODO:localize
            let successSuffix = "."
            let text = successPrefix + walletTransactionShortAddress(address) + successSuffix
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .emoji(name: "TwoFactorSetupRememberSuccess", text: text),
                    position: .bottom,
                    action: { _ in
                        return false
                    }
                ),
                in: .current
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

            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .copy(text: "TON Address copied to clipboard"),
                    position: .bottom,
                    action: { _ in
                        return false
                    }
                ),
                in: .current
            )
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
            let explorerUrl = walletTransactionExplorerUrl(id: transaction.transactionHash ?? transaction.id)
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

            let incomingModeId = walletTransactionModeId(component.mode)
            if self.modeId != incomingModeId {
                self.configureMode(component.mode, fiatWalletContext: component.fiatWalletContext)
            } else if case let .transaction(transaction) = component.mode {
                self.transaction = transaction
            }
            (environment.controller() as? WalletTransactionScreen)?.setCloseAction(id: incomingModeId, action: { [weak self] in
                self?.close()
            })

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

            let fiatCurrency = self.latestWalletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = self.latestWalletState?.fiat.selectedRate
            var contentHeight: CGFloat = transaction.collectible == nil ? 71.0 : 44.0
            if let collectible = transaction.collectible {
                let headerSize = self.collectibleHeader.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleHeaderComponent(
                        context: component.context,
                        theme: theme,
                        item: WalletCollectibleHeaderComponent.Item(
                            name: collectible.name,
                            imageUrl: collectible.imageUrl,
                            lottieUrl: collectible.lottieUrl,
                            collectionName: collectible.collectionName,
                            collectionUrl: collectible.collectionUrl
                        ),
                        openCollection: component.openExplorer
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 1000.0)
                )
                if let headerView = self.collectibleHeader.view {
                    if headerView.superview == nil {
                        self.addSubview(headerView)
                    }
                    transition.setFrame(view: headerView, frame: CGRect(
                        x: 0.0,
                        y: contentHeight,
                        width: headerSize.width,
                        height: headerSize.height
                    ))
                    transition.setAlpha(view: headerView, alpha: 1.0)
                    (headerView as? WalletCollectibleHeaderComponent.View)?.setAnimationVisible(true)
                }
                contentHeight += headerSize.height

                if let amountView = self.amount.view {
                    amountView.isUserInteractionEnabled = false
                    transition.setAlpha(view: amountView, alpha: 0.0)
                }
                if let usdView = self.usdValue.view {
                    transition.setAlpha(view: usdView, alpha: 0.0)
                }
                if let dotView = self.processingDot.view {
                    transition.setAlpha(view: dotView, alpha: 0.0)
                }
                if let processingView = self.processingText.view {
                    transition.setAlpha(view: processingView, alpha: 0.0)
                }
            } else {
                if let headerView = self.collectibleHeader.view {
                    transition.setAlpha(view: headerView, alpha: 0.0)
                    (headerView as? WalletCollectibleHeaderComponent.View)?.setAnimationVisible(false)
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
                if let amountView = self.amount.view {
                    if amountView.superview == nil {
                        self.addSubview(amountView)
                    }
                    amountView.isUserInteractionEnabled = true
                    transition.setFrame(
                        view: amountView,
                        frame: CGRect(
                            x: floorToScreenPixels((availableSize.width - amountSize.width) / 2.0),
                            y: contentHeight,
                            width: amountSize.width,
                            height: amountSize.height
                        )
                    )
                    transition.setAlpha(view: amountView, alpha: 1.0)
                }
                contentHeight += amountSize.height + 7.0

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
                    transition.setAlpha(view: usdView, alpha: 1.0)
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
            }

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
                contentHeight += transaction.collectible == nil ? 44.0 : 22.0
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
            let counterpartyName = transaction.counterpartyName.flatMap { value -> String? in
                let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            let addressComponent: AnyComponent<Empty>?
            if let counterparty = transaction.counterparty {
                addressComponent = AnyComponent(Button(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: walletTransactionFormattedAddress(counterparty),
                            font: Font.monospace(15.0),
                            textColor: valueColor
                        )),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.12
                    )),
                    action: { [weak self] in
                        self?.copyAddress(counterparty)
                    }
                ))
            } else {
                addressComponent = nil
            }
            let counterpartyComponent: AnyComponent<Empty>
            if let counterpartyName {
                counterpartyComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: counterpartyName, font: valueFont, textColor: valueColor)),
                    maximumNumberOfLines: 0
                ))
            } else if let addressComponent {
                counterpartyComponent = addressComponent
            } else {
                //TODO:localize
                counterpartyComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Unknown Address", font: valueFont, textColor: valueColor)),
                    maximumNumberOfLines: 0
                ))
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
            if counterpartyName != nil, let addressComponent {
                //TODO:localize
                tableItems.append(TableComponent.Item(
                    id: "address",
                    title: "Address",
                    component: addressComponent
                ))
            }
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
            let tableWidth = availableSize.width - (20.0 + environment.safeInsets.left) * 2.0
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
                contentHeight += 12.0
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
                        fontSize: 17.0,
                        textColor: theme.actionSheet.inputTextColor,
                        accentColor: theme.actionSheet.controlAccentColor,
                        insets: UIEdgeInsets(top: 10.0, left: 16.0, bottom: 10.0, right: 16.0),
                        hideKeyboard: false,
                        customInputView: nil,
                        placeholder: NSAttributedString(
                            string: optionalMessage,
                            font: Font.regular(17.0),
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
                contentHeight += 24.0
            } else {
                contentHeight += 30.0
                if let backgroundView = self.inputBackground.view {
                    transition.setAlpha(view: backgroundView, alpha: 0.0)
                }
                if let fieldView = self.inputField.view {
                    transition.setAlpha(view: fieldView, alpha: 0.0)
                }
            }

            let actionTitle: String
            if self.isPreview && !self.isConfirmedPreview {
                if transaction.collectible != nil {
                    //TODO:localize
                    actionTitle = "Send Collectible"
                } else {
                    //TODO:localize
                    let sendPrefix = "Send "
                    //TODO:localize
                    let gramsSuffix = " Grams"
                    actionTitle = sendPrefix + formatTonAmountText(
                        transaction.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 9
                    ) + gramsSuffix
                }
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

private final class WalletTransactionPagerComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let transactions: [WalletContext.Transaction]
    let initialIndex: Int
    let itemSpacing: CGFloat
    let openExplorer: (String) -> Void
    let indexUpdated: (Int) -> Void
    let draggingBegan: (Int) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        transactions: [WalletContext.Transaction],
        initialIndex: Int,
        itemSpacing: CGFloat,
        openExplorer: @escaping (String) -> Void,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.transactions = transactions
        self.initialIndex = initialIndex
        self.itemSpacing = itemSpacing
        self.openExplorer = openExplorer
        self.indexUpdated = indexUpdated
        self.draggingBegan = draggingBegan
    }

    static func ==(lhs: WalletTransactionPagerComponent, rhs: WalletTransactionPagerComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.transactions == rhs.transactions
            && lhs.initialIndex == rhs.initialIndex
            && lhs.itemSpacing == rhs.itemSpacing
    }

    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let scrollView: UIScrollView
        private var itemViews: [String: ComponentHostView<EnvironmentType>] = [:]

        private var component: WalletTransactionPagerComponent?
        private var environment: Environment<EnvironmentType>?
        private var previousItemStride: CGFloat?
        private var previousIsDisplaying = false
        private var lastReportedIndex: Int?
        private var isUpdating = false
        private var ignoreContentOffsetChange = false
        private var isSwiping = false
        private var lastScrollTime: TimeInterval = 0.0

        override init(frame: CGRect) {
            self.dimView = UIView()
            self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)

            self.scrollView = UIScrollView(frame: frame)
            self.scrollView.clipsToBounds = true
            self.scrollView.isPagingEnabled = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.bounces = false
            self.scrollView.layer.cornerRadius = 10.0
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }

            super.init(frame: frame)

            self.addSubview(self.dimView)
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func itemStride(component: WalletTransactionPagerComponent, availableWidth: CGFloat) -> CGFloat {
            return availableWidth + component.itemSpacing * 2.0
        }

        private func currentIndex(component: WalletTransactionPagerComponent, itemStride: CGFloat) -> Int {
            guard !component.transactions.isEmpty, itemStride > 0.0 else {
                return 0
            }
            return max(0, min(component.transactions.count - 1, Int(round(self.scrollView.contentOffset.x / itemStride))))
        }

        private func reportCurrentIndex(force: Bool = false) {
            guard let component = self.component, !component.transactions.isEmpty else {
                return
            }
            let itemStride = self.previousItemStride
                ?? self.itemStride(component: component, availableWidth: self.bounds.width)
            let index = self.currentIndex(component: component, itemStride: itemStride)
            if force || self.lastReportedIndex != index {
                self.lastReportedIndex = index
                component.indexUpdated(index)
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let component = self.component, !component.transactions.isEmpty else {
                return
            }
            self.isSwiping = true
            self.lastScrollTime = CACurrentMediaTime()
            component.draggingBegan(self.currentIndex(
                component: component,
                itemStride: self.previousItemStride
                    ?? self.itemStride(component: component, availableWidth: self.bounds.width)
            ))
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.isSwiping = false
                self.reportCurrentIndex(force: true)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.isSwiping = false
            self.reportCurrentIndex(force: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component,
                  let environment = self.environment,
                  !self.ignoreContentOffsetChange,
                  !self.isUpdating else {
                return
            }
            if self.isSwiping {
                self.lastScrollTime = CACurrentMediaTime()
            }

            self.ignoreContentOffsetChange = true
            let _ = self.update(
                component: component,
                availableSize: self.bounds.size,
                environment: environment,
                transition: .immediate
            )
            self.ignoreContentOffsetChange = false
            self.reportCurrentIndex()
        }

        func update(
            component: WalletTransactionPagerComponent,
            availableSize: CGSize,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            transition.setFrame(view: self.dimView, frame: CGRect(origin: .zero, size: availableSize))

            let previousComponent = self.component
            let previousItemStride = self.previousItemStride
            var anchorId: String?
            var anchorFraction: CGFloat = 0.0
            if let previousComponent,
               let previousItemStride,
               previousItemStride > 0.0,
               !previousComponent.transactions.isEmpty {
                let previousIndex = self.currentIndex(component: previousComponent, itemStride: previousItemStride)
                anchorId = previousComponent.transactions[previousIndex].id
                anchorFraction = self.scrollView.contentOffset.x / previousItemStride - CGFloat(previousIndex)
            }

            self.component = component
            self.environment = environment

            let itemWidth = availableSize.width
            let itemStride = self.itemStride(component: component, availableWidth: itemWidth)
            self.previousItemStride = itemStride
            let totalWidth = itemWidth * CGFloat(component.transactions.count)
                + component.itemSpacing * 2.0 * CGFloat(component.transactions.count)
            let contentSize = CGSize(width: totalWidth, height: availableSize.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollFrame = CGRect(
                x: -component.itemSpacing / 2.0,
                y: 0.0,
                width: availableSize.width + component.itemSpacing * 2.0,
                height: availableSize.height
            )
            if self.scrollView.frame != scrollFrame {
                self.scrollView.frame = scrollFrame
            }

            let isFirstUpdate = previousComponent == nil || self.itemViews.isEmpty
            var targetOffset: CGFloat?
            if isFirstUpdate {
                let initialIndex = max(0, min(component.transactions.count - 1, component.initialIndex))
                targetOffset = CGFloat(initialIndex) * itemStride
            } else if let anchorId,
                      let anchorIndex = component.transactions.firstIndex(where: { $0.id == anchorId }) {
                targetOffset = (CGFloat(anchorIndex) + anchorFraction) * itemStride
            }
            if let targetOffset {
                let maximumOffset = max(0.0, contentSize.width - scrollFrame.width)
                self.ignoreContentOffsetChange = true
                self.scrollView.contentOffset = CGPoint(x: max(0.0, min(maximumOffset, targetOffset)), y: 0.0)
                self.ignoreContentOffsetChange = false
            }

            let viewportCenter = self.scrollView.contentOffset.x + availableSize.width * 0.5
            let isSwipingActive = self.isSwiping || CACurrentMediaTime() - self.lastScrollTime < 0.5
            var validIds = Set<String>()

            for (index, transaction) in component.transactions.enumerated() {
                let itemOriginX = component.itemSpacing * 0.5 + itemStride * CGFloat(index)
                let itemFrame = CGRect(x: itemOriginX, y: 0.0, width: itemWidth, height: availableSize.height)
                let position = (itemFrame.midX - viewportCenter) / (availableSize.width * 0.75)
                if (!isSwipingActive && abs(position) > 0.5) || (isSwipingActive && abs(position) > 1.5) {
                    continue
                }

                validIds.insert(transaction.id)
                let itemView: ComponentHostView<EnvironmentType>
                var itemTransition = transition
                if let current = self.itemViews[transaction.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<EnvironmentType>()
                    self.itemViews[transaction.id] = itemView
                    self.scrollView.addSubview(itemView)
                }

                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(WalletTransactionSheetComponent(
                        context: component.context,
                        mode: .transaction(transaction),
                        fiatWalletContext: component.walletContext,
                        hasDimView: false,
                        openExplorer: component.openExplorer
                    )),
                    environment: { environment[EnvironmentType.self] },
                    containerSize: availableSize
                )
                itemView.frame = itemFrame
            }

            var removeIds: [String] = []
            for (id, itemView) in self.itemViews where !validIds.contains(id) {
                removeIds.append(id)
                itemView.removeFromSuperview()
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }

            let viewEnvironment = environment[EnvironmentType.self].value
            if let _ = transition.userData(ViewControllerComponentContainer.AnimateInTransition.self) {
                self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            } else if self.previousIsDisplaying,
                      let _ = transition.userData(ViewControllerComponentContainer.AnimateOutTransition.self) {
                self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            self.previousIsDisplaying = viewEnvironment.isVisible

            if isFirstUpdate {
                self.reportCurrentIndex(force: true)
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
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private final class WalletTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletTransactionScreenMode
    let fiatWalletContext: WalletContext?
    let hasDimView: Bool
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        mode: WalletTransactionScreenMode,
        fiatWalletContext: WalletContext?,
        hasDimView: Bool,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.fiatWalletContext = fiatWalletContext
        self.hasDimView = hasDimView
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionSheetComponent, rhs: WalletTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context
            || lhs.fiatWalletContext !== rhs.fiatWalletContext
            || lhs.hasDimView != rhs.hasDimView {
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
                    hasDimView: context.component.hasDimView,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        (controller() as? WalletTransactionScreen)?.dismissAllTooltips()
                    },
                    willDismiss: {
                        (controller() as? WalletTransactionScreen)?.requestLayout(
                            forceUpdate: true,
                            transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                        )
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

private final class WalletTransactionRootComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let content: AnyComponent<EnvironmentType>

    init(content: AnyComponent<EnvironmentType>) {
        self.content = content
    }

    static func ==(lhs: WalletTransactionRootComponent, rhs: WalletTransactionRootComponent) -> Bool {
        return lhs.content == rhs.content
    }

    func makeView() -> ComponentHostView<EnvironmentType> {
        return ComponentHostView<EnvironmentType>()
    }

    func update(
        view: ComponentHostView<EnvironmentType>,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            transition: transition,
            component: self.content,
            environment: { environment[EnvironmentType.self] },
            forceUpdate: true,
            containerSize: availableSize
        )
    }
}

public final class WalletTransactionScreen: ViewControllerComponentContainer {
    private let accountContext: AccountContext
    private let navigationWalletContext: WalletContext?
    private let openExplorer: (String) -> Void
    private let stateDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()

    private var transactionsState: WalletContext.TransactionsState?
    private var transactions: [WalletContext.Transaction]
    private var currentTransactionId: String?
    private var currentCloseId: String
    private var closeActions: [String: () -> Void] = [:]
    private var requestedOffset: Int?
    private var failedOffset: Int?

    public init(
        context: AccountContext,
        walletContext: WalletContext? = nil,
        mode: WalletTransactionScreenMode
    ) {
        let navigationWalletContext: WalletContext?
        let fiatWalletContext: WalletContext?
        let initialTransaction: WalletContext.Transaction?
        switch mode {
        case let .transaction(transaction):
            navigationWalletContext = walletContext
            fiatWalletContext = walletContext ?? context.walletContext
            initialTransaction = transaction
        case let .preview(walletContext, _, _):
            navigationWalletContext = nil
            fiatWalletContext = walletContext
            initialTransaction = nil
        }

        let initialState = navigationWalletContext?.stateValue.transactions
        var initialTransactions = initialState?.items.filter(\.isVisibleInWalletHistory) ?? []
        if let initialTransaction,
           !initialTransactions.contains(where: { $0.id == initialTransaction.id }) {
            initialTransactions.insert(initialTransaction, at: 0)
        }
        let initialIndex: Int
        if let initialTransaction {
            initialIndex = initialTransactions.firstIndex(where: { $0.id == initialTransaction.id }) ?? 0
        } else {
            initialIndex = 0
        }

        let openExplorer: (String) -> Void = { url in
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

        self.accountContext = context
        self.navigationWalletContext = navigationWalletContext
        self.openExplorer = openExplorer
        self.transactionsState = initialState
        self.transactions = initialTransactions
        self.currentTransactionId = initialTransaction?.id
        self.currentCloseId = walletTransactionModeId(mode)

        var indexUpdatedImpl: ((Int) -> Void)?
        var draggingBeganImpl: ((Int) -> Void)?
        let initialComponent: AnyComponent<ViewControllerComponentContainer.Environment>
        if let navigationWalletContext, initialTransaction != nil {
            initialComponent = AnyComponent(WalletTransactionPagerComponent(
                context: context,
                walletContext: navigationWalletContext,
                transactions: initialTransactions,
                initialIndex: initialIndex,
                itemSpacing: 10.0,
                openExplorer: openExplorer,
                indexUpdated: { index in
                    indexUpdatedImpl?(index)
                },
                draggingBegan: { index in
                    draggingBeganImpl?(index)
                }
            ))
        } else {
            initialComponent = AnyComponent(WalletTransactionSheetComponent(
                context: context,
                mode: mode,
                fiatWalletContext: fiatWalletContext,
                hasDimView: true,
                openExplorer: openExplorer
            ))
        }
        super.init(
            context: context,
            component: WalletTransactionRootComponent(content: initialComponent),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        indexUpdatedImpl = { [weak self] index in
            self?.currentIndexUpdated(index)
        }
        draggingBeganImpl = { [weak self] index in
            self?.draggingBegan(index)
        }

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false

        if let navigationWalletContext {
            self.stateDisposable.set((navigationWalletContext.state
            |> map { $0.transactions }
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { [weak self] transactions in
                Queue.mainQueue().justDispatch { [weak self] in
                    self?.transactionsStateUpdated(transactions)
                }
            }))
            self.requestLoadMoreIfNeeded(index: initialIndex)
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.stateDisposable.dispose()
        self.loadMoreDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }

    fileprivate func setCloseAction(id: String, action: @escaping () -> Void) {
        self.closeActions[id] = action
    }

    fileprivate func requestClose() {
        self.dismissAllTooltips()
        if let closeAction = self.closeActions[self.currentCloseId] {
            closeAction()
        } else {
            self.dismiss(completion: nil)
        }
    }

    public func dismissAnimated() {
        self.requestClose()
    }

    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }

    private func transactionsStateUpdated(_ state: WalletContext.TransactionsState) {
        if let requestedOffset = self.requestedOffset,
           state.offset != requestedOffset || !state.canLoadMore {
            self.requestedOffset = nil
            self.failedOffset = nil
        }

        var transactions = state.items.filter(\.isVisibleInWalletHistory)
        if let currentTransactionId = self.currentTransactionId,
           !transactions.contains(where: { $0.id == currentTransactionId }),
           let currentTransaction = self.transactions.first(where: { $0.id == currentTransactionId }) {
            let previousIndex = self.transactions.firstIndex(where: { $0.id == currentTransactionId }) ?? 0
            transactions.insert(currentTransaction, at: min(previousIndex, transactions.count))
        }
        if transactions.isEmpty, let currentTransaction = self.transactions.first {
            transactions = [currentTransaction]
        }

        self.transactionsState = state
        self.transactions = transactions
        let currentIndex: Int
        if let currentTransactionId = self.currentTransactionId {
            currentIndex = transactions.firstIndex(where: { $0.id == currentTransactionId }) ?? 0
        } else {
            currentIndex = 0
        }
        if transactions.indices.contains(currentIndex) {
            self.currentCloseId = walletTransactionModeId(.transaction(transactions[currentIndex]))
        }
        self.updatePager(initialIndex: currentIndex)
        self.requestLoadMoreIfNeeded(index: currentIndex)
    }

    private func updatePager(initialIndex: Int) {
        guard let navigationWalletContext = self.navigationWalletContext else {
            return
        }
        self.updateComponent(
            component: AnyComponent(WalletTransactionRootComponent(
                content: AnyComponent(WalletTransactionPagerComponent(
                    context: self.accountContext,
                    walletContext: navigationWalletContext,
                    transactions: self.transactions,
                    initialIndex: initialIndex,
                    itemSpacing: 10.0,
                    openExplorer: self.openExplorer,
                    indexUpdated: { [weak self] index in
                        self?.currentIndexUpdated(index)
                    },
                    draggingBegan: { [weak self] index in
                        self?.draggingBegan(index)
                    }
                ))
            )),
            transition: .immediate
        )
    }

    private func currentIndexUpdated(_ index: Int) {
        guard self.transactions.indices.contains(index) else {
            return
        }
        let transaction = self.transactions[index]
        self.currentTransactionId = transaction.id
        self.currentCloseId = walletTransactionModeId(.transaction(transaction))
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func draggingBegan(_ index: Int) {
        if self.failedOffset == self.transactionsState?.offset {
            self.requestedOffset = nil
            self.failedOffset = nil
        }
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func requestLoadMoreIfNeeded(index: Int) {
        guard let navigationWalletContext = self.navigationWalletContext,
              let transactionsState = self.transactionsState,
              !self.transactions.isEmpty,
              index >= max(0, self.transactions.count - 2),
              transactionsState.canLoadMore,
              !transactionsState.isLoadingMore,
              transactionsState.error == nil || self.failedOffset == nil,
              navigationWalletContext.stateValue.activeOperation == nil else {
            return
        }
        let offset = transactionsState.offset
        guard self.requestedOffset != offset else {
            return
        }
        self.requestedOffset = offset
        self.loadMoreDisposable.set((navigationWalletContext.loadMoreTransactions()
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let self, self.requestedOffset == offset else {
                return
            }
            self.failedOffset = offset
        }))
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
