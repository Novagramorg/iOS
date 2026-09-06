import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import ResizableSheetComponent
import BundleIconComponent
import MultilineTextComponent
import ButtonComponent
import PlainButtonComponent
import GlassBarButtonComponent
import GlassControls
import TableComponent
import ContextUI
import TelegramStringFormatting
import TextFormat
import TextFieldComponent
import UndoUI
import TooltipUI
import AvatarComponent
import ShimmeringMask
import WalletContext
import WalletCollectibleHeaderComponent
import WalletSendScreen
import TextSelectionNode
import Pasteboard
import Speak
import TranslateUI
import TelegramUIPreferences
import TelegramNotices
import InvisibleInkDustNode
import WalletAuthorizationUI
import ActivityIndicator

private struct WalletTransactionPreviewSource: Equatable {
    let id: String
    let address: String
    let amount: Int64
    let requestedAmount: Int64
    let isSendAll: Bool
    let comment: String?
    let commentEncrypted: Bool
    let collectible: WalletContext.Collectible?
    let preparedTransfer: WalletContext.PreparedTransfer?

    init(preparedTransfer: WalletContext.PreparedTransfer) {
        self.id = preparedTransfer.id
        self.address = preparedTransfer.recipient
        self.amount = preparedTransfer.amount
        self.requestedAmount = preparedTransfer.requestedAmount
        self.isSendAll = preparedTransfer.isSendAll
        self.comment = preparedTransfer.comment
        self.commentEncrypted = preparedTransfer.commentEncrypted
        self.collectible = preparedTransfer.collectible
        self.preparedTransfer = preparedTransfer
    }

    init(address: String, amount: Int64, sendAll: Bool, comment: String?) {
        self.id = UUID().uuidString
        self.address = address
        self.amount = amount
        self.requestedAmount = amount
        self.isSendAll = sendAll
        self.comment = comment
        self.commentEncrypted = false
        self.collectible = nil
        self.preparedTransfer = nil
    }
}

private enum WalletTransactionContentMode {
    case transaction(WalletContext.Transaction)
    case preview(
        walletContext: WalletContext,
        source: WalletTransactionPreviewSource,
        dismissSendScreen: () -> Void
    )
}

private final class SelectableWalletTransactionCommentComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let text: NSAttributedString
    let controller: () -> ViewController?
    let performAction: (NSAttributedString, TextSelectionAction) -> Void

    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        text: NSAttributedString,
        controller: @escaping () -> ViewController?,
        performAction: @escaping (NSAttributedString, TextSelectionAction) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.text = text
        self.controller = controller
        self.performAction = performAction
    }

    static func ==(lhs: SelectableWalletTransactionCommentComponent, rhs: SelectableWalletTransactionCommentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private var textSelectionNode: TextSelectionNode?
        private weak var selectionTheme: PresentationTheme?
        private weak var selectionStrings: PresentationStrings?
        private var component: SelectableWalletTransactionCommentComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.clipsToBounds = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if self.bounds.contains(point) {
                return true
            }
            if let textSelectionNode {
                let localPoint = self.convert(point, to: textSelectionNode.view)
                return textSelectionNode.view.hitTest(localPoint, with: event) != nil
            }
            return false
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let textSelectionNode {
                let localPoint = self.convert(point, to: textSelectionNode.view)
                if let result = textSelectionNode.view.hitTest(localPoint, with: event) {
                    return result
                }
            }
            return super.hitTest(point, with: event)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if self.window == nil {
                self.removeTextSelectionNode()
            }
        }

        func cancelSelection() {
            self.textSelectionNode?.cancelSelection()
        }

        private func removeTextSelectionNode() {
            guard let textSelectionNode = self.textSelectionNode else {
                return
            }
            self.textSelectionNode = nil
            textSelectionNode.cancelSelection()
            textSelectionNode.highlightAreaNode.view.removeFromSuperview()
            textSelectionNode.view.removeFromSuperview()
        }

        private func ensureTextSelectionNode(textView: MultilineTextComponent.View) {
            guard let component = self.component else {
                return
            }

            if self.selectionTheme !== component.theme || self.selectionStrings !== component.strings {
                self.removeTextSelectionNode()
            }
            self.selectionTheme = component.theme
            self.selectionStrings = component.strings

            let textSelectionNode: TextSelectionNode
            if let current = self.textSelectionNode {
                textSelectionNode = current
            } else {
                let accentColor = component.theme.actionSheet.controlAccentColor
                textSelectionNode = TextSelectionNode(
                    theme: TextSelectionTheme(
                        selection: accentColor.withMultipliedAlpha(0.5),
                        knob: accentColor,
                        isDark: component.theme.overallDarkAppearance
                    ),
                    strings: component.strings,
                    textNodeOrView: .view(textView),
                    updateIsActive: { _ in
                    },
                    present: { [weak self] controller, arguments in
                        self?.component?.controller()?.presentInGlobalOverlay(controller, with: arguments)
                    },
                    rootView: { [weak self] in
                        return self?.component?.controller()?.displayNode.view
                    },
                    performAction: { [weak self] text, action in
                        self?.component?.performAction(text, action)
                    }
                )
                textSelectionNode.enableQuote = false
                textSelectionNode.enableSpeak = isSpeakSelectionEnabled()

                self.textSelectionNode = textSelectionNode
                self.insertSubview(textSelectionNode.highlightAreaNode.view, belowSubview: textView)
                self.addSubview(textSelectionNode.view)
            }

            textSelectionNode.enableCopy = true
            textSelectionNode.enableShare = true
        }

        func update(
            component: SelectableWalletTransactionCommentComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            if let previousComponent = self.component,
               previousComponent.text != component.text || previousComponent.theme !== component.theme {
                self.removeTextSelectionNode()
            }
            self.component = component

            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(component.text),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: availableSize
            )

            if let textView = self.text.view as? MultilineTextComponent.View {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = CGRect(origin: .zero, size: textSize)

                self.ensureTextSelectionNode(textView: textView)
                if let textSelectionNode = self.textSelectionNode {
                    let shouldUpdateLayout = textSelectionNode.frame.size != textSize
                    textSelectionNode.frame = CGRect(origin: .zero, size: textSize)
                    textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
                    if shouldUpdateLayout {
                        textSelectionNode.updateLayout()
                    }
                }
            }

            return textSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private protocol WalletTransactionContentController: AnyObject {
    func setCloseAction(id: String, action: @escaping (Bool) -> Void)
    func requestClose(animated: Bool)
    func dismissAllTooltips()
}

private func walletTransactionModeId(_ mode: WalletTransactionContentMode) -> String {
    switch mode {
    case let .transaction(transaction):
        return "transaction:\(transaction.presentationId)"
    case let .preview(_, source, _):
        return "preview:\(source.id)"
    }
}

private final class WalletTransactionFeePlaceholderComponent: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: WalletTransactionFeePlaceholderComponent, rhs: WalletTransactionFeePlaceholderComponent) -> Bool {
        return lhs.color.isEqual(rhs.color)
    }

    final class View: UIView {
        private let shimmerView = ShimmeringMaskView(peakAlpha: 0.3, duration: 1.6)
        private let shape = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.shimmerView.isUserInteractionEnabled = false
            self.addSubview(self.shimmerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletTransactionFeePlaceholderComponent,
            state: EmptyComponentState,
            transition: ComponentTransition
        ) -> CGSize {
            let size = CGSize(width: 128.0, height: 16.0)
            self.shape.parentState = state
            let shapeSize = self.shape.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: component.color,
                    cornerRadius: 8.0,
                    size: size
                )),
                environment: {},
                containerSize: size
            )
            if let shapeView = self.shape.view {
                if shapeView.superview !== self.shimmerView.contentView {
                    self.shimmerView.contentView.addSubview(shapeView)
                }
                transition.setFrame(view: shapeView, frame: CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: shapeSize))
            }
            transition.setFrame(view: self.shimmerView, frame: CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: size))
            self.shimmerView.update(
                size: size,
                containerWidth: size.width,
                offsetX: 0.0,
                gradientWidth: 60.0,
                transition: transition
            )
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, state: state, transition: transition)
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

private final class SendButtonContentComponent: Component {
    let text: String
    let color: UIColor

    init(text: String, color: UIColor) {
        self.text = text
        self.color = color
    }

    static func ==(lhs: SendButtonContentComponent, rhs: SendButtonContentComponent) -> Bool {
        return lhs.text == rhs.text && lhs.color == rhs.color
    }

    final class View: UIView {
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: SendButtonContentComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.text,
                        font: Font.regular(11.0),
                        textColor: component.color
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )

            let size = CGSize(width: titleSize.width + 12.0, height: 18.0)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(
                        x: floorToScreenPixels((size.width - titleSize.width) / 2.0),
                        y: floorToScreenPixels((size.height - titleSize.height) / 2.0),
                        width: titleSize.width,
                        height: titleSize.height
                    )
                )
            }

            self.backgroundLayer.backgroundColor = component.color.withAlphaComponent(0.1).cgColor
            self.backgroundLayer.cornerRadius = size.height / 2.0
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private enum CounterpartyContentId: Hashable {
    case peer(EnginePeer.Id)
    case address(String)
    case unknown
}

private final class CounterpartyRowComponent: CombinedComponent {
    typealias EnvironmentType = Empty

    let counterparty: AnyComponentWithIdentity<Empty>
    let sendButton: AnyComponent<Empty>
    let spacing: CGFloat
    let alignSendButtonToTop: Bool

    init(
        counterparty: AnyComponentWithIdentity<Empty>,
        sendButton: AnyComponent<Empty>,
        spacing: CGFloat,
        alignSendButtonToTop: Bool
    ) {
        self.counterparty = counterparty
        self.sendButton = sendButton
        self.spacing = spacing
        self.alignSendButtonToTop = alignSendButtonToTop
    }

    static func ==(lhs: CounterpartyRowComponent, rhs: CounterpartyRowComponent) -> Bool {
        return lhs.counterparty == rhs.counterparty
            && lhs.sendButton == rhs.sendButton
            && lhs.spacing == rhs.spacing
            && lhs.alignSendButtonToTop == rhs.alignSendButtonToTop
    }

    static var body: Body {
        let counterparties = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let sendButton = Child(environment: Empty.self)

        return { context in
            let sendButton = sendButton.update(
                component: context.component.sendButton,
                availableSize: context.availableSize,
                transition: context.transition
            )
            let counterparty = counterparties[context.component.counterparty.id].update(
                component: context.component.counterparty.component,
                availableSize: CGSize(
                    width: max(0.0, context.availableSize.width - sendButton.size.width - context.component.spacing),
                    height: context.availableSize.height
                ),
                transition: context.transition
            )

            let size = CGSize(
                width: counterparty.size.width + context.component.spacing + sendButton.size.width,
                height: max(counterparty.size.height, sendButton.size.height)
            )
            context.add(counterparty.position(CGPoint(
                x: counterparty.size.width / 2.0,
                y: size.height / 2.0
            )))
            context.add(sendButton.position(CGPoint(
                x: counterparty.size.width + context.component.spacing + sendButton.size.width / 2.0,
                y: context.component.alignSendButtonToTop ? sendButton.size.height / 2.0 : size.height / 2.0
            )))

            return size
        }
    }
}

private final class WalletTransactionContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletTransactionContentMode
    let walletContext: WalletContext?
    let openExplorer: (String) -> Void
    let animateOut: ActionSlot<Action<Void>>

    init(
        context: AccountContext,
        mode: WalletTransactionContentMode,
        walletContext: WalletContext?,
        openExplorer: @escaping (String) -> Void,
        animateOut: ActionSlot<Action<Void>>
    ) {
        self.context = context
        self.mode = mode
        self.walletContext = walletContext
        self.openExplorer = openExplorer
        self.animateOut = animateOut
    }

    static func ==(lhs: WalletTransactionContentComponent, rhs: WalletTransactionContentComponent) -> Bool {
        if lhs.context !== rhs.context || lhs.walletContext !== rhs.walletContext {
            return false
        }
        switch (lhs.mode, rhs.mode) {
        case let (.transaction(lhsTransaction), .transaction(rhsTransaction)):
            return lhsTransaction == rhsTransaction
        case let (.preview(lhsContext, lhsSource, _), .preview(rhsContext, rhsSource, _)):
            return lhsContext === rhsContext && lhsSource == rhsSource
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
            case submissionUnknown
            case confirmed

            var displaysProgress: Bool {
                switch self {
                case .authorizing, .submitting:
                    return true
                case .ready, .preparing, .submissionUnknown, .confirmed:
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
        private var commentText = ComponentView<Empty>()
        private let commentButton = ComponentView<Empty>()
        private var commentDustNode: InvisibleInkDustNode?
        private var commentActivityIndicator: ActivityIndicator?
        private var decryptedComment: String?
        private var commentDecryptionInProgress = false
        private var commentDecryptionRevision = 0
        private var commentWalletIdentity: String?
        private var isImportingCommentKey = false
        private weak var commentRecoveryController: ViewController?
        private let commentDecryptionDisposable = MetaDisposable()
        private let commentAuthorizationDisposable = MetaDisposable()
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
        private var previewSource: WalletTransactionPreviewSource?
        private var previewComment: String?
        private var preparedTransfer: WalletContext.PreparedTransfer?
        private var displayedFee: Int64?
        private var preparedTransferNeedsRefresh = false
        private var dismissSendScreen: (() -> Void)?
        private var didDismissSendScreen = false
        private var previewOperation: PreviewOperation = .ready
        private var preparingForSend = false
        private var previewTimestamp = Int32(Date().timeIntervalSince1970)
        private var latestWalletState: WalletContext.State?
        private var didShowSuccess = false

        private let inputExternalState = TextFieldComponent.ExternalState()
        private var commentRevision = 0
        private var isApplyingInput = false

        private let walletDisposable = MetaDisposable()
        private let transferDisposable = MetaDisposable()
        private let discardTransferDisposables = DisposableSet()
        private let hapticFeedback = HapticFeedback()
        private var currentSpeechHolder: SpeechSynthesizerHolder?
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
            self.discardCurrentPreparedTransfer()
            self.walletDisposable.dispose()
            self.transferDisposable.dispose()
            self.discardTransferDisposables.dispose()
            self.commentDecryptionDisposable.dispose()
            self.commentAuthorizationDisposable.dispose()
        }

        private var isPreview: Bool {
            return self.walletContext != nil
        }

        private var isFinishedPreview: Bool {
            guard self.isPreview else {
                return false
            }
            return self.previewOperation == .confirmed || self.previewOperation == .submissionUnknown
        }

        private func configureMode(_ mode: WalletTransactionContentMode, walletContext: WalletContext?) {
            self.resetCommentDecryption()
            self.commentWalletIdentity = nil
            self.discardCurrentPreparedTransfer()
            self.walletDisposable.set(nil)
            self.transferDisposable.set(nil)
            self.transaction = nil
            self.walletContext = nil
            self.previewSource = nil
            self.previewComment = nil
            self.preparedTransfer = nil
            self.displayedFee = nil
            self.preparedTransferNeedsRefresh = false
            self.dismissSendScreen = nil
            self.didDismissSendScreen = false
            self.previewOperation = .ready
            self.preparingForSend = false
            self.latestWalletState = nil
            self.didShowSuccess = false
            self.amountPending = false
            self.commentRevision += 1

            switch mode {
            case let .transaction(transaction):
                self.modeId = walletTransactionModeId(.transaction(transaction))
                self.transaction = transaction
            case let .preview(walletContext, source, dismissSendScreen):
                self.modeId = "preview:\(source.id)"
                self.walletContext = walletContext
                self.previewSource = source
                self.previewComment = walletTransactionComment(source.comment)
                self.preparedTransfer = source.preparedTransfer
                self.displayedFee = source.preparedTransfer?.fee
                self.dismissSendScreen = dismissSendScreen
                self.previewTimestamp = Int32(Date().timeIntervalSince1970)
                self.isApplyingInput = true
                self.inputExternalState.initialText = NSAttributedString(string: source.comment ?? "")
                self.isApplyingInput = false

                if source.preparedTransfer == nil {
                    let revision = self.commentRevision
                    Queue.mainQueue().justDispatch { [weak self] in
                        guard let self, self.commentRevision == revision else {
                            return
                        }
                        self.prepareCurrentComment(revision: revision, authorizeAfterPreparation: false)
                    }
                }
            }

            let observedContext = self.walletContext ?? walletContext
            if let observedContext {
                self.walletDisposable.set((observedContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self,
                          self.walletContext === observedContext
                            || (self.walletContext == nil && self.component?.walletContext === observedContext) else {
                        return
                    }
                    let walletIdentity: String?
                    if case let .wallet(info) = state.phase {
                        walletIdentity = info.address + ":" + info.publicKey
                    } else {
                        walletIdentity = nil
                    }
                    if self.commentWalletIdentity != walletIdentity {
                        self.resetCommentDecryption()
                        self.commentWalletIdentity = walletIdentity
                    }
                    self.latestWalletState = state
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
            guard let previewSource = self.previewSource else {
                preconditionFailure()
            }
            let preparedTransfer = self.preparedTransfer
            let recipient = preparedTransfer?.recipient ?? previewSource.address
            let amount = preparedTransfer?.amount ?? previewSource.amount
            let collectible = preparedTransfer?.collectible ?? previewSource.collectible
            return WalletContext.Transaction(
                id: "preview-\(previewSource.id)",
                logicalTime: previewSource.id,
                timestamp: self.previewTimestamp,
                direction: .outgoing,
                amount: amount,
                fee: self.displayedFee ?? 0,
                peer: .address(recipient, domain: nil),
                comment: self.previewComment,
                collectible: collectible.map(walletTransactionCollectible)
            )
        }

        private func dismissSendScreenIfNeeded() {
            guard !self.didDismissSendScreen else {
                return
            }
            self.didDismissSendScreen = true
            self.dismissSendScreen?()
        }

        private func close(animated: Bool = true) {
            self.resetCommentDecryption()
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            switch self.previewOperation {
            case .submitting, .submissionUnknown, .confirmed:
                self.dismissSendScreenIfNeeded()
            case .ready, .preparing:
                self.commentRevision += 1
                self.transferDisposable.set(nil)
                self.discardCurrentPreparedTransfer()
                self.previewOperation = .ready
                self.preparingForSend = false
            case .authorizing:
                self.discardCurrentPreparedTransfer()
                self.previewOperation = .ready
                self.preparingForSend = false
            }
            (controller as? WalletTransactionContentController)?.dismissAllTooltips()
            if animated {
                (controller as? ViewControllerComponentContainer)?.requestLayout(
                    forceUpdate: true,
                    transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                )
                component.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(completion: nil)
            }
        }

        private func toggleAmountPending() {
            guard !self.isPreview else {
                return
            }
            self.amountPending.toggle()
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func resetCommentDecryption() {
            self.commentDecryptionRevision += 1
            self.commentDecryptionDisposable.set(nil)
            self.commentAuthorizationDisposable.set(nil)
            self.commentDecryptionInProgress = false
            self.isImportingCommentKey = false
            self.commentRecoveryController = nil
            if self.decryptedComment != nil {
                (self.commentText.view as? SelectableWalletTransactionCommentComponent.View)?.cancelSelection()
                self.commentText.view?.removeFromSuperview()
                self.commentText = ComponentView<Empty>()
                self.decryptedComment = nil
                self.currentSpeechHolder = nil
            }
        }

        fileprivate func commentVisibilityUpdated(_ visible: Bool) {
            if visible, self.isImportingCommentKey {
                self.isImportingCommentKey = false
                self.commentRecoveryController = nil
                if let walletContext = self.component?.walletContext,
                   case let .wallet(info) = walletContext.stateValue.phase,
                   info.canSign,
                   info.address + ":" + info.publicKey == self.commentWalletIdentity {
                    self.startCommentDecryption(revision: self.commentDecryptionRevision)
                } else {
                    self.resetCommentDecryption()
                }
            } else if !visible, !self.isImportingCommentKey {
                self.resetCommentDecryption()
            }
            if !self.isUpdating {
                self.componentState?.updated(transition: .immediate)
            }
        }

        private func encryptedCommentPressed() {
            guard !self.commentDecryptionInProgress,
                  self.decryptedComment == nil,
                  let transaction = self.transaction,
                  transaction.commentEncrypted,
                  let component = self.component,
                  let walletContext = component.walletContext,
                  let controller = self.environment?.controller() else {
                return
            }
            guard case let .wallet(info) = walletContext.stateValue.phase else {
                self.presentCommentDecryptionError(.unavailable)
                return
            }
            self.commentDecryptionRevision += 1
            let revision = self.commentDecryptionRevision
            self.commentWalletIdentity = info.address + ":" + info.publicKey
            self.commentDecryptionInProgress = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if info.canSign {
                self.startCommentDecryption(revision: revision)
            } else if info.canExportPhrase {
                self.commentAuthorizationDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { password in
                        walletContext.recoveryPhrase(password: password)
                    },
                    next: { [weak self] _ in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.startCommentDecryption(revision: revision)
                    },
                    failed: { [weak self] error in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.finishCommentDecryption(error: error)
                    }
                ))
            } else {
                //TODO:localize
                controller.present(textAlertController(
                    context: component.context,
                    title: "Recovery Phrase Required",
                    text: "Enter your recovery phrase to restore access to this wallet and decrypt the comment.",
                    actions: [
                        TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                            guard let self, self.commentDecryptionRevision == revision else { return }
                            self.finishCommentDecryption(error: .authorizationCancelled)
                        }),
                        TextAlertAction(type: .defaultAction, title: "Proceed", action: { [weak self] in
                            Queue.mainQueue().after(0.25) { [weak self] in
                                self?.importCommentKey(revision: revision)
                            }
                        })
                    ],
                    dismissOnOutsideTap: false
                ), in: .window(.root))
            }
        }

        private func importCommentKey(revision: Int) {
            guard self.commentDecryptionRevision == revision else { return }
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  controller.navigationController != nil else {
                self.finishCommentDecryption(error: .authorizationCancelled)
                return
            }
            let importController = component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.commentRecoveryController?.dismiss(animated: true)
                }
            )
            self.commentRecoveryController = importController
            self.isImportingCommentKey = true
            controller.push(importController)
        }

        private func startCommentDecryption(revision: Int) {
            guard self.commentDecryptionRevision == revision,
                  let component = self.component,
                  let walletContext = component.walletContext,
                  let transaction = self.transaction else {
                return
            }
            let walletIdentity = self.commentWalletIdentity
            self.commentDecryptionDisposable.set((walletContext.state
            |> filter { state in
                guard case let .wallet(info) = state.phase else { return false }
                return info.canSign && state.activeOperation == nil
                    && info.address + ":" + info.publicKey == walletIdentity
            }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> mapToSignal { _ in
                walletContext.decryptTransactionComment(transaction)
            }
            |> deliverOnMainQueue).start(next: { [weak self] comment in
                guard let self, self.commentDecryptionRevision == revision,
                      self.component?.walletContext === walletContext,
                      case let .wallet(info) = walletContext.stateValue.phase,
                      info.address + ":" + info.publicKey == walletIdentity else {
                    return
                }
                self.commentDecryptionInProgress = false
                self.decryptedComment = comment
                self.componentState?.updated(transition: .spring(duration: 0.35))
            }, error: { [weak self] error in
                guard let self, self.commentDecryptionRevision == revision else { return }
                self.finishCommentDecryption(error: error)
            }))
        }

        private func finishCommentDecryption(error: WalletContext.WalletError) {
            self.resetCommentDecryption()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if error != .authorizationCancelled {
                self.presentCommentDecryptionError(error)
            }
        }

        private func presentCommentDecryptionError(_ error: WalletContext.WalletError) {
            guard let component = self.component, let controller = self.environment?.controller() else { return }
            let authorizationMessage = walletAuthorizationErrorMessage(error)
            //TODO:localize
            controller.present(textAlertController(
                context: component.context,
                title: authorizationMessage?.title ?? "Couldn't Decrypt Comment",
                text: authorizationMessage?.text ?? "The comment could not be decrypted.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func inputTextUpdated() {
            guard !self.isApplyingInput,
                  !self.isUpdating,
                  self.isPreview,
                  self.previewOperation == .ready || (self.previewOperation == .preparing && !self.preparingForSend) else {
                return
            }
            let comment = walletTransactionComment(self.inputExternalState.text.string)
            self.previewComment = comment
            if let preparedTransfer = self.preparedTransfer, preparedTransfer.comment == comment {
                self.commentRevision += 1
                self.transferDisposable.set(nil)
                self.displayedFee = preparedTransfer.fee
                self.previewOperation = .ready
                self.preparingForSend = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            self.commentRevision += 1
            let revision = self.commentRevision
            self.transferDisposable.set(nil)
            self.previewOperation = .ready
            self.preparingForSend = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            Queue.mainQueue().after(0.4) { [weak self] in
                guard let self, self.commentRevision == revision else {
                    return
                }
                self.prepareCurrentComment(revision: revision, authorizeAfterPreparation: false)
            }
        }

        private func prepareCurrentComment(revision: Int, authorizeAfterPreparation: Bool) {
            guard let walletContext = self.walletContext,
                  let previewSource = self.previewSource,
                  self.commentRevision == revision else {
                return
            }
            let comment = self.previewComment
            self.previewOperation = .preparing
            self.preparingForSend = authorizeAfterPreparation
            self.displayedFee = nil
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            let preparation: Signal<WalletContext.PreparedTransfer, WalletContext.WalletError>
            if let collectible = self.preparedTransfer?.collectible ?? previewSource.collectible {
                preparation = walletContext.prepareCollectibleTransfer(
                    address: self.preparedTransfer?.recipient ?? previewSource.address,
                    collectible: collectible,
                    comment: comment
                )
            } else {
                preparation = walletContext.prepareTransfer(
                    address: self.preparedTransfer?.recipient ?? previewSource.address,
                    amount: self.preparedTransfer?.requestedAmount ?? previewSource.requestedAmount,
                    sendAll: self.preparedTransfer?.isSendAll ?? previewSource.isSendAll,
                    comment: comment,
                    commentEncrypted: previewSource.commentEncrypted
                )
            }
            self.transferDisposable.set((preparation
            |> deliverOnMainQueue).start(next: { [weak self] updatedTransfer in
                guard let self else {
                    _ = walletContext.discardPreparedTransfer(updatedTransfer).start()
                    return
                }
                if revision != self.commentRevision {
                    self.discardTransferDisposables.add(
                        walletContext.discardPreparedTransfer(updatedTransfer).start()
                    )
                    return
                }
                if self.preparedTransfer?.id != updatedTransfer.id {
                    self.discardCurrentPreparedTransfer()
                }
                self.preparedTransfer = updatedTransfer
                self.displayedFee = updatedTransfer.fee
                self.preparedTransferNeedsRefresh = false
                let shouldAuthorize = self.preparingForSend
                self.preparingForSend = false
                if shouldAuthorize {
                    self.authorizeAndSubmit(updatedTransfer)
                } else {
                    self.previewOperation = .ready
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                if revision != self.commentRevision {
                    return
                }
                self.displayedFee = nil
                self.previewOperation = .ready
                self.preparingForSend = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError()
            }))
        }

        private func send() {
            guard self.isPreview, !self.preparingForSend else {
                return
            }
            if self.previewOperation == .preparing {
                self.preparingForSend = true
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            guard self.previewOperation == .ready else {
                return
            }
            let comment = self.previewComment
            if let preparedTransfer = self.preparedTransfer,
               !self.preparedTransferNeedsRefresh,
               preparedTransfer.comment == comment,
               TimeInterval(preparedTransfer.expiresAt) > Date().timeIntervalSince1970 {
                self.authorizeAndSubmit(preparedTransfer)
            } else {
                self.commentRevision += 1
                let revision = self.commentRevision
                self.transferDisposable.set(nil)
                self.prepareCurrentComment(revision: revision, authorizeAfterPreparation: true)
            }
        }

        private func authorizeAndSubmit(_ preparedTransfer: WalletContext.PreparedTransfer) {
            self.previewOperation = .authorizing
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.submit(preparedTransfer)
        }

        private func submit(_ preparedTransfer: WalletContext.PreparedTransfer) {
            guard let walletContext = self.walletContext else {
                return
            }
            self.previewOperation = .submitting
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.transferDisposable.set((walletContext.submitTransfer(preparedTransfer)
            |> deliverOnMainQueue).start(next: { [weak self] submittedTransfer in
                guard let self else {
                    return
                }
                self.preparedTransferNeedsRefresh = false
                self.dismissSendScreenIfNeeded()
                switch submittedTransfer.pendingTransfer.status {
                case .submissionUnknown:
                    self.previewOperation = .submissionUnknown
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self.presentSubmissionUnknown()
                case .broadcasting, .pending, .confirmed:
                    self.previewOperation = .confirmed
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    self.showSuccessIfNeeded(
                        address: submittedTransfer.pendingTransfer.recipient,
                        isCollectible: submittedTransfer.pendingTransfer.collectibleAddress != nil
                    )
                }
            }, error: { [weak self] error in
                guard let self else {
                    return
                }
                switch error {
                case .preparedTransferExpired, .preparedTransferNotFound:
                    self.preparedTransferNeedsRefresh = true
                default:
                    self.preparedTransferNeedsRefresh = false
                }
                self.previewOperation = .ready
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError()
            }))
        }

        private func discardCurrentPreparedTransfer() {
            guard let walletContext = self.walletContext,
                  let preparedTransfer = self.preparedTransfer else {
                return
            }
            self.preparedTransfer = nil
            self.preparedTransferNeedsRefresh = false
            self.discardTransferDisposables.add(
                walletContext.discardPreparedTransfer(preparedTransfer).start()
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
            let successPrefix = isCollectible ? "Collectible has been sent to" : "Grams have been sent to"
            let text = "\(successPrefix) **\(walletTransactionShortAddress(address))**."
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
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

        private func presentSubmissionUnknown() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let title = "Transfer Pending"
            //TODO:localize
            let text = "The transfer may have been sent. Don’t send it again while its status is being checked."
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

        private func presentTransferError() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let title = "Transfer Failed"
            //TODO:localize
            let text = "The transfer could not be prepared or sent. Check the address, balance and network connection, then try again."
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

        private func copyAddress(_ address: String) {
            UIPasteboard.general.string = address
            self.hapticFeedback.tap()

            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            (controller as? WalletTransactionContentController)?.dismissAllTooltips()
            
            //TODO:localize
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .copy(text: "TON address copied to clipboard"),
                    position: .bottom,
                    action: { _ in
                        return false
                    }
                ),
                in: .current
            )
        }

        private func openSend(peer transactionPeer: WalletContext.Transaction.Peer) {
            guard !self.isPreview,
                  let component = self.component,
                  let walletContext = component.walletContext,
                  let controller = self.environment?.controller() else {
                return
            }

            let sendScreen: WalletSendScreen
            switch transactionPeer {
            case let .user(peer, _, _):
                sendScreen = WalletSendScreen(
                    context: component.context,
                    peer: peer,
                    walletContext: walletContext
                )
            case .address:
                guard let counterpartyAddress = transactionPeer.address else {
                    return
                }
                let address = WalletContext.transferAddress(from: counterpartyAddress) ?? counterpartyAddress
                sendScreen = WalletSendScreen(
                    context: component.context,
                    walletContext: walletContext,
                    address: address
                )
            case .unsupported:
                return
            }
            sendScreen.navigationPresentation = .modal
            controller.push(sendScreen)

            Queue.mainQueue().after(0.6) { [weak self] in
                self?.close(animated: false)
            }
        }

        private func performCommentTextSelectionAction(text: NSAttributedString, action: TextSelectionAction) {
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }

            switch action {
            case .copy:
                storeAttributedTextInPasteboard(text)

                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                controller.present(
                    UndoOverlayController(
                        presentationData: presentationData,
                        content: .copy(text: presentationData.strings.Conversation_TextCopied),
                        position: .bottom,
                        action: { _ in return true }
                    ),
                    in: .current
                )
            case .share:
                let shareController = component.context.sharedContext.makeShareController(
                    context: component.context,
                    params: ShareControllerParams(
                        subject: .text(text.string),
                        externalShare: true,
                        immediateExternalShare: false
                    )
                )
                controller.present(shareController, in: .window(.root))
            case .lookup:
                let lookupController = UIReferenceLibraryViewController(term: text.string)
                if let window = controller.view.window {
                    lookupController.popoverPresentationController?.sourceView = window
                    lookupController.popoverPresentationController?.sourceRect = CGRect(
                        origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.height - 1.0),
                        size: CGSize(width: 1.0, height: 1.0)
                    )
                    window.rootViewController?.present(lookupController, animated: true)
                }
            case .speak:
                if let speechHolder = speakText(text: text.string) {
                    speechHolder.completion = { [weak self, weak speechHolder] in
                        guard let self else {
                            return
                        }
                        if self.currentSpeechHolder === speechHolder {
                            self.currentSpeechHolder = nil
                        }
                    }
                    self.currentSpeechHolder = speechHolder
                }
            case .translate:
                let _ = (component.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
                    guard let self, let component = self.component else {
                        return
                    }

                    let translationSettings: TranslationSettings
                    if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                        translationSettings = current
                    } else {
                        translationSettings = TranslationSettings.defaultSettings
                    }

                    let (_, language) = canTranslateText(
                        context: component.context,
                        text: text.string,
                        showTranslate: translationSettings.showTranslate,
                        showTranslateIfTopical: false,
                        ignoredLanguages: translationSettings.ignoredLanguages
                    )
                    let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(
                        accountManager: component.context.sharedContext.accountManager,
                        timestamp: Int32(Date().timeIntervalSince1970)
                    ).startStandalone()

                    Task { @MainActor [weak self] in
                        guard let self,
                              let component = self.component,
                              let controller = self.environment?.controller() else {
                            return
                        }
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let translationController = await component.context.sharedContext.makeTextProcessingScreen(
                            context: component.context,
                            theme: nil,
                            mode: .translate(fromLanguage: language, applyResult: nil),
                            inputText: .plain(text: text.string, entities: []),
                            copyResult: { [weak controller] result in
                                guard let controller else {
                                    return
                                }
                                switch result {
                                case let .plain(text, entities):
                                    storeMessageTextInPasteboard(text, entities: entities)
                                case .rich(_), .empty:
                                    return
                                }
                                controller.present(
                                    UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .copy(text: presentationData.strings.Conversation_TextCopied),
                                        elevatedLayout: true,
                                        animateInAsReplacement: false,
                                        action: { _ in return false }
                                    ),
                                    in: .window(.root)
                                )
                            },
                            translateChat: nil
                        )
                        controller.present(translationController, in: .window(.root))
                    }
                })
            case .quote:
                break
            }
        }

        private func openPeer(_ peer: EnginePeer) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            (controller as? WalletTransactionContentController)?.dismissAllTooltips()
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                chatController: nil,
                context: component.context,
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
                  let controller = self.environment?.controller(),
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
                action: { _, dismiss in
                    dismiss(.default)
                    
                    if let explorerUrl {
                        component.openExplorer(explorerUrl)
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
            let previousWalletContext = self.component?.walletContext
            self.component = component
            self.environment = environment
            self.componentState = state

            let incomingModeId = walletTransactionModeId(component.mode)
            if self.modeId != incomingModeId || previousWalletContext !== component.walletContext {
                self.configureMode(component.mode, walletContext: component.walletContext)
            } else if case let .transaction(transaction) = component.mode {
                if self.transaction?.comment != transaction.comment
                    || self.transaction?.commentEncrypted != transaction.commentEncrypted
                    || self.transaction?.direction != transaction.direction
                    || self.transaction?.peer.address != transaction.peer.address {
                    self.resetCommentDecryption()
                }
                self.transaction = transaction
            }
            (environment.controller() as? WalletTransactionContentController)?.setCloseAction(id: incomingModeId, action: { [weak self] animated in
                self?.close(animated: animated)
            })
            (environment.controller() as? WalletTransactionScreen)?.setCommentVisibilityAction(id: incomingModeId, action: { [weak self] visible in
                self?.commentVisibilityUpdated(visible)
            })

            let theme = environment.theme
            let transaction = self.currentTransaction()
            let showsMore = !self.isPreview || (self.isFinishedPreview && self.transaction != nil)
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
                controlsView.isUserInteractionEnabled = !self.isPreview
                transition.setFrame(
                    view: controlsView,
                    frame: CGRect(x: 16.0, y: 16.0, width: controlsSize.width, height: controlsSize.height)
                )
                transition.setAlpha(view: controlsView, alpha: self.isPreview ? 0.0 : 1.0)
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
                    component: AnyComponent(WalletTransactionAmountComponent(
                        theme: theme,
                        dateTimeFormat: environment.dateTimeFormat,
                        amount: transaction.amount,
                        direction: transaction.direction,
                        currency: transaction.currency,
                        pending: self.isPreview ? false : (transaction.status == .pending || self.amountPending)
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
                        usdText = "—"
                    }
                case .usdt:
                    if let fiatRate {
                        usdText = formatFiatValue(
                            abs(Double(transaction.amount)) / 1_000_000.0 * fiatRate.unitsPerUsd,
                            currencySymbol: fiatCurrency.symbol,
                            dateTimeFormat: environment.dateTimeFormat
                        )
                    } else {
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
                let displaysTransactionStatus = !self.isPreview
                    && (transaction.status == .pending || transaction.status == .failed || self.amountPending)
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
                let processingLabel = transaction.status == .failed ? "Failed" : "Processing..."
                let processingSize = self.processingText.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: processingLabel,
                            font: Font.regular(15.0),
                            textColor: transaction.status == .failed
                                ? theme.list.itemDestructiveColor
                                : theme.actionSheet.controlAccentColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width / 2.0, height: 24.0)
                )
                let usdToDotSpacing: CGFloat = 6.0
                let dotToProcessingSpacing: CGFloat = 4.0
                let processingWidth = usdToDotSpacing + dotSize.width + dotToProcessingSpacing + processingSize.width
                let combinedWidth = usdSize.width + (displaysTransactionStatus ? processingWidth : 0.0)
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
                    transition.setAlpha(view: dotView, alpha: displaysTransactionStatus ? 1.0 : 0.0)
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
                    transition.setAlpha(view: processingView, alpha: displaysTransactionStatus ? 1.0 : 0.0)
                }
                contentHeight += usdSize.height
            }

            let displaysCommentBubble = !self.isPreview || self.isFinishedPreview
            let displayedComment = transaction.commentEncrypted ? self.decryptedComment : walletTransactionComment(transaction.comment)
            let isCommentConcealed = transaction.commentEncrypted && transaction.comment?.isEmpty == false && self.decryptedComment == nil
            self.commentButton.view?.isHidden = !displaysCommentBubble || !isCommentConcealed
            if !displaysCommentBubble || !isCommentConcealed, let dustNode = self.commentDustNode {
                self.commentDustNode = nil
                transition.setAlpha(view: dustNode.view, alpha: 0.0, completion: { _ in
                    dustNode.view.removeFromSuperview()
                })
            }
            if !displaysCommentBubble || !isCommentConcealed || !self.commentDecryptionInProgress {
                self.commentActivityIndicator?.view.removeFromSuperview()
                self.commentActivityIndicator = nil
            }
            if displaysCommentBubble, isCommentConcealed || displayedComment != nil {
                contentHeight += 22.0
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let bubbleImage = self.commentBubbleImage(
                    presentationData: presentationData,
                    incoming: transaction.direction == .incoming,
                    fillColor: theme.list.itemInputField.backgroundColor
                )
                let commentSize: CGSize
                if isCommentConcealed {
                    commentSize = CGSize(width: 120.0, height: ceil(Font.regular(15.0).lineHeight))
                    self.commentText.view?.isHidden = true
                    (self.commentText.view as? SelectableWalletTransactionCommentComponent.View)?.cancelSelection()
                } else {
                    commentSize = self.commentText.update(
                        transition: transition,
                        component: AnyComponent(SelectableWalletTransactionCommentComponent(
                            theme: theme,
                            strings: environment.strings,
                            text: NSAttributedString(
                                string: displayedComment ?? "",
                                font: Font.regular(15.0),
                                textColor: theme.actionSheet.primaryTextColor
                            ),
                            controller: environment.controller,
                            performAction: { [weak self] text, action in
                                self?.performCommentTextSelectionAction(text: text, action: action)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - 122.0, height: .greatestFiniteMagnitude)
                    )
                }

                var commentTransition = transition
                if self.commentBackgroundView.image == nil {
                    self.commentBackgroundView.alpha = 0.0
                    commentTransition = .immediate
                }

                let bubbleSize = CGSize(width: commentSize.width + 34.0, height: max(commentSize.height + 14.0, bubbleImage.size.height))
                self.commentBackgroundView.image = bubbleImage
                let bubbleFrame = CGRect(
                    x: floorToScreenPixels(
                        (availableSize.width - bubbleSize.width) / 2.0
                        + (transaction.direction == .incoming ? -3.0 : 3.0)
                    ),
                    y: contentHeight,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )
                commentTransition.setFrame(view: self.commentBackgroundView, frame: bubbleFrame)
                transition.setAlpha(view: self.commentBackgroundView, alpha: 1.0)
                let commentFrame = CGRect(
                    x: floorToScreenPixels((availableSize.width - commentSize.width) / 2.0),
                    y: contentHeight + floorToScreenPixels((bubbleSize.height - commentSize.height) / 2.0),
                    width: commentSize.width,
                    height: commentSize.height
                )
                if isCommentConcealed {
                    let dustNode: InvisibleInkDustNode
                    if let current = self.commentDustNode {
                        dustNode = current
                    } else {
                        dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: component.context.sharedContext.energyUsageSettings.fullTranslucency)
                        dustNode.isUserInteractionEnabled = false
                        dustNode.isAccessibilityElement = false
                        self.commentDustNode = dustNode
                        self.addSubview(dustNode.view)
                    }
                    dustNode.frame = commentFrame.insetBy(dx: -3.0, dy: -3.0)
                    let rect = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: commentSize).insetBy(dx: 0.0, dy: 2.0)
                    dustNode.update(size: dustNode.frame.size, color: theme.actionSheet.primaryTextColor, textColor: theme.actionSheet.primaryTextColor, rects: [rect], wordRects: [rect])
                    transition.setAlpha(view: dustNode.view, alpha: self.commentDecryptionInProgress ? 0.25 : 1.0)
                    if self.commentDecryptionInProgress {
                        let indicator: ActivityIndicator
                        if let current = self.commentActivityIndicator {
                            indicator = current
                        } else {
                            indicator = ActivityIndicator(type: .custom(theme.actionSheet.primaryTextColor, 16.0, 1.5, false))
                            indicator.isUserInteractionEnabled = false
                            self.commentActivityIndicator = indicator
                            self.addSubview(indicator.view)
                        }
                        indicator.type = .custom(theme.actionSheet.primaryTextColor, 16.0, 1.5, false)
                        indicator.frame = CGRect(x: floorToScreenPixels(bubbleFrame.midX - 8.0), y: floorToScreenPixels(bubbleFrame.midY - 8.0), width: 16.0, height: 16.0)
                    }
                    let _ = self.commentButton.update(
                        transition: .immediate,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(Rectangle(color: .clear)),
                            minSize: bubbleSize,
                            action: { [weak self] in
                                self?.encryptedCommentPressed()
                            },
                            isEnabled: !self.commentDecryptionInProgress,
                            animateAlpha: false,
                            animateScale: false
                        )),
                        environment: {},
                        containerSize: bubbleSize
                    )
                    if let commentButtonView = self.commentButton.view {
                        if commentButtonView.superview == nil {
                            //TODO:localize
                            commentButtonView.accessibilityLabel = "Encrypted comment"
                            commentButtonView.accessibilityHint = "Double-tap to decrypt."
                            self.addSubview(commentButtonView)
                        }
                        commentButtonView.frame = bubbleFrame
                        self.bringSubviewToFront(commentButtonView)
                    }
                } else if let commentView = self.commentText.view {
                    if commentView.superview == nil {
                        commentTransition = .immediate
                        commentView.alpha = 0.0
                        self.addSubview(commentView)
                    }
                    commentView.isHidden = false
                    commentView.isUserInteractionEnabled = true
                    commentTransition.setFrame(view: commentView, frame: commentFrame)
                    transition.setAlpha(view: commentView, alpha: 1.0)
                }
                contentHeight += bubbleSize.height + 32.0
            } else {
                transition.setAlpha(view: self.commentBackgroundView, alpha: 0.0)
                if let commentView = self.commentText.view {
                    commentView.isUserInteractionEnabled = false
                    (commentView as? SelectableWalletTransactionCommentComponent.View)?.cancelSelection()
                    transition.setAlpha(view: commentView, alpha: 0.0)
                }
                contentHeight += transaction.collectible == nil ? 44.0 : 22.0
            }

            let valueFont = Font.regular(15.0)
            let valueColor = theme.list.itemPrimaryTextColor
            let secondaryValueColor = theme.list.itemSecondaryTextColor
            let counterpartyTitle: String
            if self.isPreview && !self.isFinishedPreview {
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
            let peerDisplayName = transaction.peer.displayName.flatMap { value -> String? in
                let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            let counterpartyName = peerDisplayName ?? transaction.peer.domain
            let addressComponent: AnyComponent<Empty>?
            if let counterparty = transaction.peer.address {
                let address = WalletContext.transferAddress(from: counterparty) ?? counterparty
                addressComponent = AnyComponent(Button(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(walletTransactionFormattedAddress(
                            address,
                            font: Font.monospace(15.0),
                            primaryTextColor: valueColor,
                            secondaryTextColor: theme.actionSheet.secondaryTextColor
                        )),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.12
                    )),
                    action: { [weak self] in
                        self?.copyAddress(address)
                    }
                ))
            } else {
                addressComponent = nil
            }
            let counterpartyContentId: CounterpartyContentId
            switch transaction.peer {
            case let .user(peer, _, _):
                counterpartyContentId = .peer(peer.id)
            case let .address(address, _):
                counterpartyContentId = .address(address)
            case .unsupported:
                counterpartyContentId = .unknown
            }
            let counterpartyContent: AnyComponent<Empty>
            if case let .user(peer, _, _) = transaction.peer {
                let peerItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(
                        id: "avatar",
                        component: AnyComponent(AvatarComponent(
                            context: component.context,
                            theme: theme,
                            peer: peer,
                            size: CGSize(width: 20.0, height: 20.0)
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: peer.debugDisplayTitle,
                                font: valueFont,
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 1
                        ))
                    )
                ]
                counterpartyContent = AnyComponent(Button(
                    content: AnyComponent(HStack(peerItems, spacing: 6.0)),
                    action: { [weak self] in
                        self?.openPeer(peer)
                    }
                ))
            } else if let counterpartyName {
                counterpartyContent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: counterpartyName, font: valueFont, textColor: valueColor)),
                    maximumNumberOfLines: 0
                ))
            } else if let addressComponent {
                counterpartyContent = addressComponent
            } else {
                //TODO:localize
                counterpartyContent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Unknown Address", font: valueFont, textColor: valueColor)),
                    maximumNumberOfLines: 0
                ))
            }
            let counterpartyContentComponent = AnyComponentWithIdentity(
                id: counterpartyContentId,
                component: counterpartyContent
            )
            let canSendToPeer: Bool
            switch transaction.peer {
            case .user:
                canSendToPeer = true
            case .address:
                canSendToPeer = transaction.peer.address != nil
            case .unsupported:
                canSendToPeer = false
            }
            let displaysSendButton: Bool
            if !self.isPreview, component.walletContext != nil, canSendToPeer {
                switch transaction.direction {
                case .incoming, .outgoing:
                    displaysSendButton = true
                case .unknown:
                    displaysSendButton = false
                }
            } else {
                displaysSendButton = false
            }
            let alignSendButtonToTop: Bool
            switch transaction.peer {
            case .address:
                alignSendButtonToTop = true
            case .user, .unsupported:
                alignSendButtonToTop = false
            }
            let counterpartyComponent: AnyComponent<Empty>
            if displaysSendButton {
                counterpartyComponent = AnyComponent(CounterpartyRowComponent(
                    counterparty: counterpartyContentComponent,
                    sendButton: AnyComponent(Button(
                        content: AnyComponent(SendButtonContentComponent(
                            //TODO:localize
                            text: "send",
                            color: theme.list.itemAccentColor
                        )),
                        action: { [weak self] in
                            self?.openSend(peer: transaction.peer)
                        }
                    )),
                    spacing: 6.0,
                    alignSendButtonToTop: alignSendButtonToTop
                ))
            } else {
                counterpartyComponent = counterpartyContentComponent.component
            }
            let displayedFee: Int64? = self.isPreview ? self.displayedFee : transaction.fee
            let feeComponent: AnyComponent<Empty>?
            if let displayedFee {
                if displayedFee > 0 {
                    var feeItems: [AnyComponentWithIdentity<Empty>] = [
                        AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(
                            name: "Ads/TonAbout",
                            tintColor: UIColor(rgb: 0x30a1f5),
                            maxSize: CGSize(width: 14.0, height: 14.0)
                        ))),
                        AnyComponentWithIdentity(id: "amount", component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: formatTonAmountText(displayedFee, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: 5),
                                font: valueFont,
                                textColor: valueColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    ]
                    if let fiatRate {
                        let usdFee = formatTonFiatValue(
                            displayedFee,
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
                    feeComponent = AnyComponent(HStack(feeItems, spacing: 3.0))
                } else {
                    feeComponent = nil
                }
            } else {
                feeComponent = AnyComponent(HStack([
                    AnyComponentWithIdentity(
                        id: "placeholder",
                        component: AnyComponent(WalletTransactionFeePlaceholderComponent(
                            color: theme.overallDarkAppearance ? theme.list.itemModalBlocksBackgroundColor : theme.list.itemInputField.backgroundColor
                        ))
                    )
                ], spacing: 0.0))
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
            let displaysSeparateAddress: Bool
            switch transaction.peer {
            case .user:
                displaysSeparateAddress = true
            case .address:
                displaysSeparateAddress = transaction.peer.domain != nil
            case .unsupported:
                displaysSeparateAddress = false
            }
            if displaysSeparateAddress, let addressComponent {
                //TODO:localize
                tableItems.append(TableComponent.Item(
                    id: "address",
                    title: "Address",
                    component: addressComponent
                ))
            }
            if transaction.direction == .outgoing, let feeComponent {
                tableItems.append(TableComponent.Item(
                    id: "fee",
                    title: feeTitle,
                    component: feeComponent
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

            let displaysInput = self.isPreview && !self.isFinishedPreview
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
            if self.isPreview && !self.isFinishedPreview {
                if transaction.collectible != nil {
                    //TODO:localize
                    actionTitle = "Send Collectible"
                } else {
                    //TODO:localize
                    let sendPrefix = "Send "
                    actionTitle = sendPrefix + formatTonAmountText(
                        transaction.amount,
                        dateTimeFormat: environment.dateTimeFormat,
                        maxDecimalPositions: 9,
                        formatString: environment.strings.Currency_Grams
                    )
                }
            } else {
                //TODO:localize
                actionTitle = "OK"
            }
            let canSign: Bool
            if let latestWalletState = self.latestWalletState, case let .wallet(walletInfo) = latestWalletState.phase {
                canSign = walletInfo.canSign
            } else {
                canSign = false
            }
            let actionIsEnabled: Bool
            if !self.isPreview || self.isFinishedPreview {
                actionIsEnabled = true
            } else {
                actionIsEnabled = canSign
                    && !self.preparingForSend
                    && (self.previewOperation == .ready || self.previewOperation == .preparing)
            }
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
                    displaysProgress: self.isPreview && (self.previewOperation.displaysProgress || self.preparingForSend),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if self.isPreview && !self.isFinishedPreview {
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
            self.scrollView.alwaysBounceHorizontal = true
            self.scrollView.bounces = true
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
                anchorId = previousComponent.transactions[previousIndex].presentationId
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
                      let anchorIndex = component.transactions.firstIndex(where: { $0.presentationId == anchorId }) {
                targetOffset = (CGFloat(anchorIndex) + anchorFraction) * itemStride
            }
            if let targetOffset {
                let maximumOffset = max(0.0, contentSize.width - scrollFrame.width)
                let resolvedOffset = self.isSwiping
                    ? targetOffset
                    : max(0.0, min(maximumOffset, targetOffset))
                self.ignoreContentOffsetChange = true
                self.scrollView.contentOffset = CGPoint(x: resolvedOffset, y: 0.0)
                self.ignoreContentOffsetChange = false
            }

            let currentIndex = self.currentIndex(component: component, itemStride: itemStride)
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
                
                let uniqueId = transaction.presentationId

                validIds.insert(uniqueId)
                let itemView: ComponentHostView<EnvironmentType>
                var itemTransition = transition
                if let current = self.itemViews[uniqueId] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<EnvironmentType>()
                    self.itemViews[uniqueId] = itemView
                    self.scrollView.addSubview(itemView)
                }

                let _ = itemView.update(
                    transition: itemTransition,
                    component: AnyComponent(WalletTransactionSheetComponent(
                        context: component.context,
                        transaction: transaction,
                        walletContext: component.walletContext,
                        hasDimView: false,
                        updatesPresentationContextLayout: index == currentIndex,
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
    let transaction: WalletContext.Transaction
    let walletContext: WalletContext?
    let hasDimView: Bool
    let updatesPresentationContextLayout: Bool
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        transaction: WalletContext.Transaction,
        walletContext: WalletContext?,
        hasDimView: Bool,
        updatesPresentationContextLayout: Bool,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.transaction = transaction
        self.walletContext = walletContext
        self.hasDimView = hasDimView
        self.updatesPresentationContextLayout = updatesPresentationContextLayout
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionSheetComponent, rhs: WalletTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context
            || lhs.walletContext !== rhs.walletContext
            || lhs.hasDimView != rhs.hasDimView
            || lhs.updatesPresentationContextLayout != rhs.updatesPresentationContextLayout {
            return false
        }
        return lhs.transaction == rhs.transaction
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
                        mode: .transaction(context.component.transaction),
                        walletContext: context.component.walletContext,
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
                        (controller() as? WalletTransactionContentController)?.dismissAllTooltips()
                    },
                    willDismiss: {
                        (controller() as? ViewControllerComponentContainer)?.requestLayout(
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
                        dismiss: { animated in
                            (controller() as? WalletTransactionContentController)?.requestClose(animated: animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if context.component.updatesPresentationContextLayout,
               let controller = controller(),
               !controller.automaticallyControlPresentationContextLayout {
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

private final class WalletTransactionPreviewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let source: WalletTransactionPreviewSource
    let dismissSendScreen: () -> Void
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        source: WalletTransactionPreviewSource,
        dismissSendScreen: @escaping () -> Void,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.source = source
        self.dismissSendScreen = dismissSendScreen
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionPreviewSheetComponent, rhs: WalletTransactionPreviewSheetComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.source == rhs.source
    }

    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = ResizableSheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let sheetComponent = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletTransactionContentComponent(
                        context: context.component.context,
                        mode: .preview(
                            walletContext: context.component.walletContext,
                            source: context.component.source,
                            dismissSendScreen: context.component.dismissSendScreen
                        ),
                        walletContext: context.component.walletContext,
                        openExplorer: context.component.openExplorer,
                        animateOut: animateOut
                    )),
                    leftItem: AnyComponent(GlassBarButtonComponent(
                        size: CGSize(width: 44.0, height: 44.0),
                        backgroundColor: nil,
                        isDark: environment.theme.overallDarkAppearance,
                        state: .glass,
                        component: AnyComponentWithIdentity(
                            id: "close",
                            component: AnyComponent(BundleIconComponent(
                                name: "Navigation/Close",
                                tintColor: environment.theme.chat.inputPanel.panelControlColor
                            ))
                        ),
                        action: { _ in
                            (controller() as? WalletTransactionContentController)?.requestClose(animated: true)
                        }
                    )),
                    hasTopEdgeEffect: false,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    clipsContent: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: environment.theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        inputHeight: environment.inputHeight,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            (controller() as? WalletTransactionContentController)?.requestClose(animated: animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let contentHeight = sheetExternalState.contentHeight + environment.inputHeight
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - contentHeight) / 2.0 + contentHeight
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

private func walletTransactionOpenExplorer(context: AccountContext) -> (String) -> Void {
    return { url in
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
}

public final class WalletTransactionScreen: ViewControllerComponentContainer, WalletTransactionContentController {
    private let accountContext: AccountContext
    private let navigationWalletContext: WalletContext?
    private let openExplorer: (String) -> Void
    private let stateDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    private var walletScreenUpdatesDisposable: Disposable?

    private var transactionsState: WalletContext.TransactionsState?
    private var transactions: [WalletContext.Transaction]
    private var currentTransactionPresentationId: String?
    private var currentCloseId: String
    private var closeActions: [String: (Bool) -> Void] = [:]
    private var commentVisibilityActions: [String: (Bool) -> Void] = [:]
    private var requestedOffset: Int?
    private var failedOffset: Int?

    public init(
        context: AccountContext,
        walletContext: WalletContext? = nil,
        transaction: WalletContext.Transaction
    ) {
        let initialState = walletContext?.stateValue.transactions
        var initialTransactions = initialState?.items.filter(\.isVisibleInWalletHistory) ?? []
        if !initialTransactions.contains(where: { $0.presentationId == transaction.presentationId }) {
            initialTransactions.insert(transaction, at: 0)
        }
        let initialIndex = initialTransactions.firstIndex(where: { $0.presentationId == transaction.presentationId }) ?? 0

        let openExplorer = walletTransactionOpenExplorer(context: context)

        self.accountContext = context
        self.navigationWalletContext = walletContext
        self.openExplorer = openExplorer
        self.transactionsState = initialState
        self.transactions = initialTransactions
        self.currentTransactionPresentationId = transaction.presentationId
        self.currentCloseId = walletTransactionModeId(.transaction(transaction))

        var indexUpdatedImpl: ((Int) -> Void)?
        var draggingBeganImpl: ((Int) -> Void)?
        let initialComponent: AnyComponent<ViewControllerComponentContainer.Environment>
        if let walletContext {
            initialComponent = AnyComponent(WalletTransactionPagerComponent(
                context: context,
                walletContext: walletContext,
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
                transaction: transaction,
                walletContext: context.walletContext,
                hasDimView: true,
                updatesPresentationContextLayout: true,
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

        if let walletContext {
            self.stateDisposable.set((walletContext.state
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
        self.walletScreenUpdatesDisposable?.dispose()
        self.stateDisposable.dispose()
        self.loadMoreDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.commentVisibilityActions[self.currentCloseId]?(true)

        if self.walletScreenUpdatesDisposable == nil, let navigationWalletContext = self.navigationWalletContext {
            self.walletScreenUpdatesDisposable = navigationWalletContext.beginWalletScreenUpdates()
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for action in self.commentVisibilityActions.values {
            action(false)
        }
        self.dismissAllTooltips()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.walletScreenUpdatesDisposable?.dispose()
        self.walletScreenUpdatesDisposable = nil
    }

    fileprivate func setCloseAction(id: String, action: @escaping (Bool) -> Void) {
        self.closeActions[id] = action
    }

    fileprivate func setCommentVisibilityAction(id: String, action: @escaping (Bool) -> Void) {
        self.commentVisibilityActions[id] = action
    }

    fileprivate func requestClose(animated: Bool) {
        self.dismissAllTooltips()
        if let closeAction = self.closeActions[self.currentCloseId] {
            closeAction(animated)
        } else {
            self.dismiss(completion: nil)
        }
    }

    public func dismissAnimated() {
        self.requestClose(animated: true)
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
        if let currentTransactionPresentationId = self.currentTransactionPresentationId,
           !transactions.contains(where: { $0.presentationId == currentTransactionPresentationId }),
           let currentTransaction = self.transactions.first(where: { $0.presentationId == currentTransactionPresentationId }) {
            let previousIndex = self.transactions.firstIndex(where: { $0.presentationId == currentTransactionPresentationId }) ?? 0
            transactions.insert(currentTransaction, at: min(previousIndex, transactions.count))
        }
        if transactions.isEmpty, let currentTransaction = self.transactions.first {
            transactions = [currentTransaction]
        }

        self.transactionsState = state
        self.transactions = transactions
        let currentIndex: Int
        if let currentTransactionPresentationId = self.currentTransactionPresentationId {
            currentIndex = transactions.firstIndex(where: { $0.presentationId == currentTransactionPresentationId }) ?? 0
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
            transition: .easeInOut(duration: 0.2)
        )
    }

    private func currentIndexUpdated(_ index: Int) {
        guard self.transactions.indices.contains(index) else {
            return
        }
        let transaction = self.transactions[index]
        if self.currentTransactionPresentationId != transaction.presentationId {
            self.commentVisibilityActions[self.currentCloseId]?(false)
        }
        self.currentTransactionPresentationId = transaction.presentationId
        self.currentCloseId = walletTransactionModeId(.transaction(transaction))
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func draggingBegan(_ index: Int) {
        self.dismissAllTooltips()
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

public final class WalletTransactionPreviewScreen: ViewControllerComponentContainer, WalletTransactionContentController {
    private let currentCloseId: String
    private var closeActions: [String: (Bool) -> Void] = [:]

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        preparedTransfer: WalletContext.PreparedTransfer,
        dismissSendScreen: @escaping () -> Void
    ) {
        let source = WalletTransactionPreviewSource(preparedTransfer: preparedTransfer)
        self.currentCloseId = walletTransactionModeId(.preview(
            walletContext: walletContext,
            source: source,
            dismissSendScreen: dismissSendScreen
        ))

        super.init(
            context: context,
            component: WalletTransactionPreviewSheetComponent(
                context: context,
                walletContext: walletContext,
                source: source,
                dismissSendScreen: dismissSendScreen,
                openExplorer: walletTransactionOpenExplorer(context: context)
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        address: String,
        amount: Int64,
        sendAll: Bool,
        comment: String?,
        dismissSendScreen: @escaping () -> Void
    ) {
        let source = WalletTransactionPreviewSource(address: address, amount: amount, sendAll: sendAll, comment: comment)
        self.currentCloseId = walletTransactionModeId(.preview(
            walletContext: walletContext,
            source: source,
            dismissSendScreen: dismissSendScreen
        ))

        super.init(
            context: context,
            component: WalletTransactionPreviewSheetComponent(
                context: context,
                walletContext: walletContext,
                source: source,
                dismissSendScreen: dismissSendScreen,
                openExplorer: walletTransactionOpenExplorer(context: context)
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

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }

    fileprivate func setCloseAction(id: String, action: @escaping (Bool) -> Void) {
        self.closeActions[id] = action
    }

    fileprivate func requestClose(animated: Bool) {
        self.dismissAllTooltips()
        if let closeAction = self.closeActions[self.currentCloseId] {
            closeAction(animated)
        } else {
            self.dismiss(completion: nil)
        }
    }

    public func dismissAnimated() {
        self.requestClose(animated: true)
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
}

private func walletTransactionComment(_ value: String?) -> String? {
    guard var value else {
        return nil
    }
    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

private func walletTransactionShortAddress(_ address: String) -> String {
    let address = WalletContext.transferAddress(from: address) ?? address
    guard address.count > 8 else {
        return address
    }
    return "\(address.prefix(4))…\(address.suffix(4))"
}

private func walletTransactionFormattedAddress(
    _ address: String,
    font: UIFont,
    primaryTextColor: UIColor,
    secondaryTextColor: UIColor
) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var index = address.startIndex
    var groupIndex = 0
    while index < address.endIndex {
        let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        if groupIndex != 0 {
            let separator = groupIndex.isMultiple(of: 4) ? "\n" : " "
            result.append(NSAttributedString(string: separator, font: font, textColor: primaryTextColor))
        }
        let rowIndex = groupIndex / 4
        let columnIndex = groupIndex % 4
        result.append(NSAttributedString(
            string: String(address[index ..< endIndex]),
            font: font,
            textColor: (rowIndex + columnIndex).isMultiple(of: 2) ? primaryTextColor : secondaryTextColor
        ))
        index = endIndex
        groupIndex += 1
    }
    return result
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

private func tonHashHex(fromBase64 hash: String) -> String? {
    guard let data = Data(base64Encoded: hash),
          data.count == 32 else {
        return nil
    }

    return data.map { String(format: "%02x", $0) }.joined()
}

private func walletTransactionExplorerUrl(id: String) -> String? {
    guard let encodedId = tonHashHex(fromBase64: id) else {
        return nil
    }
    return "https://tonviewer.com/transaction/\(encodedId)"
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
