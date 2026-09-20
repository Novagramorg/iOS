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
import LottieComponent
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
import PasscodeCore
import WalletPagerComponent
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

private final class TransactionCommentComponent: Component {
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

    static func ==(lhs: TransactionCommentComponent, rhs: TransactionCommentComponent) -> Bool {
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
        private var component: TransactionCommentComponent?

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
                textSelectionNode.enableAutomaticScrolling = false
                textSelectionNode.cancelSelectionOnOutsideTap = true

                self.textSelectionNode = textSelectionNode
                self.insertSubview(textSelectionNode.highlightAreaNode.view, belowSubview: textView)
                self.addSubview(textSelectionNode.view)
            }

            textSelectionNode.enableCopy = true
            textSelectionNode.enableShare = true
        }

        func update(
            component: TransactionCommentComponent,
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
                    maximumNumberOfLines: 0,
                    insets: UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0)
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
    case name(String)
    case address(String)
    case unknown
}

private enum CounterpartyRowId: Hashable {
    case withSendButton
    case content(CounterpartyContentId)
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

private final class WalletTransactionKeyUpdateHeaderComponent: Component {
    let theme: PresentationTheme

    init(theme: PresentationTheme) {
        self.theme = theme
    }

    static func ==(lhs: WalletTransactionKeyUpdateHeaderComponent, rhs: WalletTransactionKeyUpdateHeaderComponent) -> Bool {
        return lhs.theme === rhs.theme
    }

    final class View: UIView {
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()
        private let title = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.backgroundView.image = generateGradientFilledCircleImage(
                diameter: 90.0,
                colors: [
                    UIColor(rgb: 0x9aa0ac).cgColor,
                    UIColor(rgb: 0xb8bdc7).cgColor
                ] as NSArray,
                direction: .vertical
            )
            self.iconView.image = generateTintedImage(
                image: UIImage(bundleImageName: "Wallet/TransactionKeyLarge"),
                color: .white
            )
            self.iconView.contentMode = .scaleAspectFit
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransactionKeyUpdateHeaderComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let iconBackgroundFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - 90.0) / 2.0),
                y: 76.0 - 90.0 / 2.0,
                width: 90.0,
                height: 90.0
            )
            transition.setFrame(view: self.backgroundView, frame: iconBackgroundFrame)
            transition.setFrame(view: self.iconView, frame: CGRect(
                x: iconBackgroundFrame.midX - 26.0,
                y: iconBackgroundFrame.midY - 26.0,
                width: 52.0,
                height: 52.0
            ))

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        //TODO:localize
                        string: "Key Update",
                        font: Font.semibold(22.0),
                        textColor: component.theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 100.0, height: .greatestFiniteMagnitude)
            )
            let titleFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                y: floorToScreenPixels(151.0 - titleSize.height / 2.0),
                width: titleSize.width,
                height: titleSize.height
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            return CGSize(width: availableSize.width, height: titleFrame.maxY)
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

private final class WalletTransactionContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletTransactionContentMode
    let walletContext: WalletContext?
    let fromChat: Bool
    let openExplorer: (String) -> Void
    let animateOut: ActionSlot<Action<Void>>

    init(
        context: AccountContext,
        mode: WalletTransactionContentMode,
        walletContext: WalletContext?,
        fromChat: Bool,
        openExplorer: @escaping (String) -> Void,
        animateOut: ActionSlot<Action<Void>>
    ) {
        self.context = context
        self.mode = mode
        self.walletContext = walletContext
        self.fromChat = fromChat
        self.openExplorer = openExplorer
        self.animateOut = animateOut
    }

    static func ==(lhs: WalletTransactionContentComponent, rhs: WalletTransactionContentComponent) -> Bool {
        if lhs.context !== rhs.context || lhs.walletContext !== rhs.walletContext || lhs.fromChat != rhs.fromChat {
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
        private let keyUpdateHeader = ComponentView<Empty>()
        private let collectibleHeader = ComponentView<Empty>()
        private let gramAnimation = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let usdValue = ComponentView<Empty>()
        private let processingDot = ComponentView<Empty>()
        private let processingText = ComponentView<Empty>()
        private let commentBackgroundView = UIImageView()
        private var commentText = ComponentView<Empty>()
        private let commentButton = ComponentView<Empty>()
        private var commentDustNode: InvisibleInkDustNode?
        private var decryptedComment: String?
        private var commentDecryptionInProgress = false
        private var commentDecryptionRevision = 0
        private var commentWalletIdentity: String?
        private var isImportingCommentKey = false
        private weak var commentRecoveryController: ViewController?
        private let commentDecryptionDisposable = MetaDisposable()
        private let commentAuthorizationDisposable = MetaDisposable()
        private var restorationSession: PasscodeSession?
        private var isRestoringCommentKey = false
        private var commentIsVisible = true
        private let table = ComponentView<Empty>()
        private let gramInfoButton = ComponentView<Empty>()
        private let inputBackground = ComponentView<Empty>()
        private let inputField = ComponentView<Empty>()
        private let commentEncryptionButton = ComponentView<Empty>()
        private var displayedCommentEncrypted: Bool?
        private let actionButton = ComponentView<Empty>()
        private var isClosing = false

        private var component: WalletTransactionContentComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var modeId: String?

        private var transaction: WalletContext.Transaction?
        private var walletContext: WalletContext?
        private var previewSource: WalletTransactionPreviewSource?
        private var previewComment: String?
        private var previewCommentEncrypted = false
        private var commentSession: PasscodeSession?
        private var commentSessionGeneration: UInt64 = 0
        private var isAuthorizingComment = false
        private var commentSessionAvailable = true
        private let commentSessionDisposable = MetaDisposable()
        private let commentEnvironmentDisposable = MetaDisposable()
        private let commentCredentialChangesDisposable = MetaDisposable()
        private var preparedTransfer: WalletContext.PreparedTransfer?
        private var submittedTransfer: WalletContext.PendingTransfer?
        private var displayedFee: Int64?
        private var preparedTransferNeedsRefresh = false
        private var dismissSendScreen: (() -> Void)?
        private var didDismissSendScreen = false
        private var previewOperation: PreviewOperation = .ready
        private var submissionStage: WalletContext.TransferSubmissionStage?
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
            self.restorationSession?.invalidate()
            self.commentSession?.invalidate()
            self.commentSessionDisposable.dispose()
            self.commentEnvironmentDisposable.dispose()
            self.commentCredentialChangesDisposable.dispose()
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

        private var canEditPreviewComment: Bool {
            return self.isPreview && !self.preparingForSend && (self.previewOperation == .ready
                || self.previewOperation == .preparing)
        }

        fileprivate var isCommentInputActive: Bool {
            return self.isPreview && !self.isFinishedPreview
                && (self.inputField.view as? TextFieldComponent.View)?.isActive == true
        }

        private var effectivePreviewCommentEncrypted: Bool {
            return self.previewCommentEncrypted && self.previewComment != nil && self.previewSource?.collectible == nil
        }

        private var commentPrivacyDescription: String {
            //TODO:localize
            return self.previewCommentEncrypted
                ? "Visible only to you and the recipient."
                : "The comment is visible to everyone."
        }

        private func configureMode(_ mode: WalletTransactionContentMode, walletContext: WalletContext?) {
            self.invalidateCommentSession()
            self.commentEnvironmentDisposable.set(nil)
            self.commentCredentialChangesDisposable.set(nil)
            self.resetCommentDecryption()
            self.commentWalletIdentity = nil
            self.discardCurrentPreparedTransfer()
            self.walletDisposable.set(nil)
            self.transferDisposable.set(nil)
            self.transaction = nil
            self.walletContext = nil
            self.previewSource = nil
            self.previewComment = nil
            self.previewCommentEncrypted = false
            self.displayedCommentEncrypted = nil
            self.preparedTransfer = nil
            self.submittedTransfer = nil
            self.displayedFee = nil
            self.preparedTransferNeedsRefresh = false
            self.dismissSendScreen = nil
            self.didDismissSendScreen = false
            self.previewOperation = .ready
            self.submissionStage = nil
            self.preparingForSend = false
            self.latestWalletState = nil
            self.didShowSuccess = false
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
                self.previewCommentEncrypted = source.collectible == nil && source.commentEncrypted
                self.preparedTransfer = source.preparedTransfer
                self.displayedFee = source.preparedTransfer?.fee
                self.dismissSendScreen = dismissSendScreen
                self.previewTimestamp = Int32(Date().timeIntervalSince1970)
                self.isApplyingInput = true
                self.inputExternalState.initialText = NSAttributedString(string: source.comment ?? "")
                self.isApplyingInput = false

                if let component = self.component {
                    let context = component.context
                    let accountId = context.account.id
                    self.commentEnvironmentDisposable.set((combineLatest(
                        context.sharedContext.applicationBindings.applicationInForeground,
                        context.sharedContext.appLockContext.isPasscodeLocked,
                        context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
                    ) |> deliverOnMainQueue).start(next: { [weak self] foreground, locked, current in
                        guard let self else { return }
                        self.commentSessionAvailable = foreground && !locked && current
                        if !self.commentSessionAvailable {
                            self.invalidateCommentSession()
                            if !self.isUpdating {
                                self.componentState?.updated(transition: .immediate)
                            }
                        }
                    }))
                    self.commentCredentialChangesDisposable.set(PasscodeCredentialStore.shared.changes.start(next: { [weak self] _ in
                        self?.invalidateCommentSession()
                        self?.componentState?.updated(transition: .immediate)
                    }))
                }
                if source.commentEncrypted, let prepared = source.preparedTransfer, source.collectible == nil {
                    let generation = self.commentSessionGeneration
                    self.isAuthorizingComment = true
                    self.commentSessionDisposable.set(walletContext.adoptCommentEncryptionSession(prepared).start(next: { [weak self] session in
                        guard let self, self.commentSessionGeneration == generation, self.commentSessionAvailable else {
                            session?.invalidate()
                            return
                        }
                        self.isAuthorizingComment = false
                        if let session { self.installCommentSession(session) }
                        else { self.invalidateCommentSession() }
                        self.previewCommentUpdated()
                    }, error: { [weak self] _ in
                        guard let self, self.commentSessionGeneration == generation else { return }
                        self.invalidateCommentSession()
                        self.componentState?.updated(transition: .immediate)
                    }))
                }
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
                        if self.commentWalletIdentity != nil, self.isPreview {
                            self.invalidateCommentSession()
                        }
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
            let gasless: Bool
            if let submittedTransfer = self.submittedTransfer {
                gasless = self.latestWalletState?.transactions.items.first(where: {
                    $0.presentationId == "pending:\(submittedTransfer.id)"
                })?.gasless ?? submittedTransfer.gasless
            } else {
                gasless = false
            }
            return WalletContext.Transaction(
                id: "preview-\(previewSource.id)",
                logicalTime: previewSource.id,
                timestamp: self.previewTimestamp,
                direction: .outgoing,
                amount: amount,
                fee: self.displayedFee ?? 0,
                gasless: gasless,
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

        private func close(animated: Bool = true, completion: (() -> Void)? = nil) {
            guard !self.isClosing, let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            self.isClosing = true
            (controller as? WalletTransactionScreen)?.cancelFirstGramsSuggestion()
            self.invalidateCommentSession()
            self.resetCommentDecryption()
            switch self.previewOperation {
            case .submitting:
                if self.submissionStage == .waitingForPreviousTransfer {
                    self.transferDisposable.set(nil)
                    self.discardCurrentPreparedTransfer()
                    self.previewOperation = .ready
                    self.submissionStage = nil
                } else {
                    self.dismissSendScreenIfNeeded()
                }
            case .submissionUnknown, .confirmed:
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
                    controller?.dismiss(completion: completion)
                })
            } else {
                controller.dismiss(completion: completion)
            }
        }

        private func openMyWallet() {
            guard !self.isClosing, let component = self.component,
                  component.fromChat, component.context.walletContext != nil,
                  let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                return
            }
            let context = component.context
            self.close(completion: { [weak navigationController] in
                guard let navigationController else {
                    return
                }
                navigationController.pushViewController(context.sharedContext.makeWalletScreen(context: context))
            })
        }

        private func presentFeesAlert(transaction: WalletContext.Transaction) {
            guard let component = self.component, let environment = self.environment,
                  let controller = environment.controller() else {
                return
            }
            //TODO:localize
            let title = "Network fees"
            //TODO:localize
            let walletConfiguration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let transfersText = "\(walletConfiguration.transferGaslessDailyLimit) transfers"
            let feeText: String
            if let fiatState = self.latestWalletState?.fiat, let fiatRate = fiatState.selectedRate {
                let fiatFee = formatTonFiatValue(
                    transaction.fee,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: fiatState.selectedCurrency.symbol,
                    maxDecimalPositions: 4,
                    dateTimeFormat: environment.dateTimeFormat
                )
                feeText = " (\(fiatFee))"
            } else {
                feeText = ""
            }
            //TODO:localize
            let text = "Every transfer costs a small network fee\(feeText).\n\nTelegram covers your first \(transfersText) each day."
            //TODO:localize
            let actionTitle = "Got it"
            let alertController = textAlertController(
                context: component.context,
                title: title,
                text: text,
                actions: [
                    TextAlertAction(
                        type: .defaultAction,
                        title: actionTitle,
                        action: {}
                    )
                ]
            )
            controller.present(alertController, in: .window(.root))
        }

        private func resetCommentDecryption() {
            self.commentDecryptionRevision += 1
            self.restorationSession?.invalidate()
            self.restorationSession = nil
            self.isRestoringCommentKey = false
            self.commentDecryptionDisposable.set(nil)
            self.commentAuthorizationDisposable.set(nil)
            self.commentDecryptionInProgress = false
            self.isImportingCommentKey = false
            self.commentRecoveryController = nil
            if self.decryptedComment != nil {
                (self.commentText.view as? TransactionCommentComponent.View)?.cancelSelection()
                self.commentText.view?.removeFromSuperview()
                self.commentText = ComponentView<Empty>()
                self.decryptedComment = nil
                self.currentSpeechHolder = nil
            }
        }

        fileprivate func commentVisibilityUpdated(_ visible: Bool, leavingTransaction: Bool) {
            self.commentIsVisible = visible
            if leavingTransaction {
                self.resetCommentDecryption()
            }
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
            } else if !visible, !self.isImportingCommentKey, !self.isRestoringCommentKey {
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
                self.restorationSession?.invalidate()
                self.restorationSession = nil
                self.isRestoringCommentKey = false
                self.startCommentDecryption(revision: revision)
            } else if info.canExportPhrase {
                self.isRestoringCommentKey = true
                self.commentAuthorizationDisposable.set(performWalletAuthorizedOperation(
                    context: component.context,
                    present: { [weak controller] alert in
                        controller?.present(alert, in: .window(.root))
                    },
                    operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                        guard let self, self.commentDecryptionRevision == revision else { return .fail(.authorizationCancelled) }
                        return self.restorationAuthorization(revision: revision)
                        |> mapToSignal { session in walletContext.recoveryPhrase(password: password, session: session) }
                    },
                    next: { [weak self] _ in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.restorationSession?.invalidate()
                        self.restorationSession = nil
                        self.isRestoringCommentKey = false
                        if self.commentIsVisible { self.startCommentDecryption(revision: revision) }
                        else { self.resetCommentDecryption() }
                    },
                    failed: { [weak self] error in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.finishCommentRestoration(error: error, revision: revision)
                    }
                ))
            } else {
                self.importCommentKey(revision: revision)
            }
        }

        private func restorationAuthorization(revision: Int) -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let walletContext = self.component?.walletContext else { return .fail(.authorizationCancelled) }
            if let session = self.restorationSession, session.isValid { return .single(session) }
            return walletContext.beginWalletFlow(reason: "Restore wallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.commentDecryptionRevision == revision else {
                    session.invalidate()
                    return .fail(.authorizationCancelled)
                }
                self.restorationSession?.invalidate()
                self.restorationSession = session
                return .single(session)
            }
        }

        private func finishCommentRestoration(error: WalletContext.WalletError, revision: Int) {
            if error == .authorizationCancelled {
                self.finishCommentDecryption(error: error)
                return
            }
            self.commentDecryptionInProgress = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard let component = self.component, let controller = self.environment?.controller() else {
                self.resetCommentDecryption()
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Restore Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.resetCommentDecryption()
                    }),
                    TextAlertAction(type: .defaultAction, title: "Retry", action: { [weak self] in
                        guard let self, self.commentDecryptionRevision == revision else { return }
                        self.encryptedCommentPressed()
                    })
                ],
                dismissOnOutsideTap: false
            ), in: .window(.root))
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
                  self.canEditPreviewComment else {
                return
            }
            self.previewComment = walletTransactionComment(self.inputExternalState.text.string)
            self.previewCommentUpdated()
        }

        fileprivate func invalidateCommentSession() {
            if self.previewOperation == .submitting && self.submissionStage == .waitingForPreviousTransfer {
                self.transferDisposable.set(nil)
                self.discardCurrentPreparedTransfer()
                self.previewOperation = .ready
                self.submissionStage = nil
            }
            self.commentSessionGeneration &+= 1
            self.commentSession?.invalidate()
            self.commentSession = nil
            self.isAuthorizingComment = false
            self.commentSessionDisposable.set(nil)
            if self.previewOperation != .submitting && !self.isFinishedPreview {
                self.preparingForSend = false
                if self.previewCommentEncrypted {
                    self.commentRevision += 1
                    self.transferDisposable.set(nil)
                    self.discardCurrentPreparedTransfer()
                    self.displayedFee = nil
                    self.previewOperation = .ready
                }
            }
        }

        private func installCommentSession(_ session: PasscodeSession) {
            if self.commentSession !== session { self.commentSession?.invalidate() }
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
            self.invalidateCommentSession()
            self.commentRevision += 1
            self.transferDisposable.set(nil)
            self.discardCurrentPreparedTransfer()
            self.displayedFee = nil
            self.previewOperation = .ready
            let generation = self.commentSessionGeneration
            self.isAuthorizingComment = true
            self.preparingForSend = forSend
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.commentSessionDisposable.set(walletContext.beginCommentEncryptionSession().start(next: { [weak self] session in
                guard let self, self.commentSessionGeneration == generation,
                      self.commentSessionAvailable, self.walletContext === walletContext else {
                    session.invalidate()
                    return
                }
                self.isAuthorizingComment = false
                self.installCommentSession(session)
                self.previewCommentEncrypted = true
                if forSend {
                    self.commentRevision += 1
                    self.transferDisposable.set(nil)
                    self.prepareCurrentComment(revision: self.commentRevision, authorizeAfterPreparation: true)
                } else {
                    self.previewCommentUpdated()
                    self.showCommentPrivacyTooltip()
                }
            }, error: { [weak self] error in
                guard let self, self.commentSessionGeneration == generation else { return }
                self.isAuthorizingComment = false
                self.preparingForSend = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError(error)
            }))
        }

        private func commentEncryptionPressed() {
            guard self.canEditPreviewComment,
                  self.previewSource?.collectible == nil else { return }
            if self.previewCommentEncrypted || self.isAuthorizingComment {
                self.invalidateCommentSession()
                self.previewCommentEncrypted = false
                self.previewCommentUpdated()
                self.showCommentPrivacyTooltip()
            } else {
                self.requestCommentSession(forSend: false)
            }
        }

        private func showCommentPrivacyTooltip() {
            guard self.canEditPreviewComment,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let buttonView = self.commentEncryptionButton.view else {
                return
            }
            (controller as? WalletTransactionContentController)?.dismissAllTooltips()

            let sourceFrame = buttonView.convert(buttonView.bounds, to: nil).offsetBy(dx: 0.0, dy: 3.0)
            controller.present(TooltipScreen(
                account: component.context.account,
                sharedContext: component.context.sharedContext,
                text: .plain(text: self.commentPrivacyDescription),
                location: .point(sourceFrame, .bottom),
                displayDuration: .default,
                shouldDismissOnTouch: { _, _ in
                    return .dismiss(consume: false)
                }
            ), in: .current)
        }

        private func previewCommentUpdated() {
            self.commentRevision += 1
            let revision = self.commentRevision
            self.transferDisposable.set(nil)
            self.previewOperation = .ready
            self.preparingForSend = false

            if self.isAuthorizingComment {
                self.displayedFee = nil
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            if self.previewCommentEncrypted && self.commentSession?.isValid != true {
                self.discardCurrentPreparedTransfer()
                self.displayedFee = nil
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }

            if let preparedTransfer = self.preparedTransfer,
               !self.preparedTransferNeedsRefresh,
               preparedTransfer.comment == self.previewComment,
               preparedTransfer.commentEncrypted == self.effectivePreviewCommentEncrypted,
               TimeInterval(preparedTransfer.expiresAt) > Date().timeIntervalSince1970 {
                self.displayedFee = preparedTransfer.fee
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }
            self.displayedFee = nil
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
                  self.commentRevision == revision, !self.isAuthorizingComment else {
                return
            }
            if self.previewCommentEncrypted && self.commentSession?.isValid != true {
                self.invalidateCommentSession()
                if authorizeAfterPreparation { self.requestCommentSession(forSend: true) }
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
                    commentEncrypted: self.previewCommentEncrypted,
                    session: self.previewCommentEncrypted ? self.commentSession : nil
                )
            }
            self.transferDisposable.set((walletContext.state
            |> filter { $0.activeOperation == nil }
            |> take(1)
            |> castError(WalletContext.WalletError.self)
            |> mapToSignal { _ in preparation }
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
            }, error: { [weak self] error in
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
                self.presentTransferError(error)
            }))
        }

        private func send() {
            guard self.isPreview, !self.preparingForSend,
                  self.previewOperation == .ready || self.previewOperation == .preparing else {
                return
            }
            if self.isAuthorizingComment { return }

            self.endEditing(true)

            if self.previewCommentEncrypted && self.commentSession?.isValid != true {
                self.requestCommentSession(forSend: true)
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
               preparedTransfer.commentEncrypted == self.effectivePreviewCommentEncrypted,
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
            self.submittedTransfer = nil
            self.previewOperation = .submitting
            self.submissionStage = .waitingForPreviousTransfer
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.transferDisposable.set((walletContext.submitTransfer(preparedTransfer, session: self.previewCommentEncrypted ? self.commentSession : nil, stageUpdated: { [weak self] stage in
                guard let self else { return }
                self.submissionStage = stage
                if stage == .submitted {
                    self.commentSession?.invalidate()
                    self.commentSession = nil
                }
            })
            |> deliverOnMainQueue).start(next: { [weak self] pendingTransfer in
                guard let self else {
                    return
                }
                self.submittedTransfer = pendingTransfer
                self.submissionStage = nil
                self.preparedTransferNeedsRefresh = false
                self.dismissSendScreenIfNeeded()
                switch pendingTransfer.status {
                case .submissionUnknown:
                    self.previewOperation = .submissionUnknown
                    self.invalidateCommentSession()
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self.presentSubmissionUnknown()
                case .broadcasting, .pending, .confirmed:
                    self.previewOperation = .confirmed
                    self.invalidateCommentSession()
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    self.showSuccessIfNeeded(
                        address: pendingTransfer.recipient,
                        isCollectible: pendingTransfer.collectibleAddress != nil
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
                self.submissionStage = nil
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentTransferError(error)
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

        private func presentTransferError(_ error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
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

            let refreshBalanceOnOpen = (controller as? WalletTransactionScreen)?.refreshBalanceOnSend ?? true
            let sendScreen: WalletSendScreen
            switch transactionPeer {
            case let .user(peer, _, _):
                sendScreen = WalletSendScreen(
                    context: component.context,
                    peer: peer,
                    walletContext: walletContext,
                    refreshBalanceOnOpen: refreshBalanceOnOpen
                )
            case .address:
                guard let counterpartyAddress = transactionPeer.address else {
                    return
                }
                let address = WalletContext.transferAddress(from: counterpartyAddress) ?? counterpartyAddress
                sendScreen = WalletSendScreen(
                    context: component.context,
                    walletContext: walletContext,
                    address: address,
                    refreshBalanceOnOpen: refreshBalanceOnOpen
                )
            case .unsupported:
                return
            }
            sendScreen.navigationPresentation = .modal
            if let controller = controller as? WalletTransactionScreen {
                if let view = controller.node.hostView.findTaggedView(tag: WalletPagerView.Tag()) as? WalletPagerView {
                    view.setDimHidden(true, animated: true)
                } else if let view = controller.node.hostView.findTaggedView(
                    tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
                ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
                    view.setDimHidden(true, animated: true)
                }
            }
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
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let explorerUrl = walletTransactionExplorerUrl(explorerUrl: configuration.explorerUrl, id: transaction.transactionHash ?? transaction.id)
            //TODO:localize
            let viewInExplorer = "View in Explorer"
            let whatIsGram = "What is Gram?"
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
            var items: [ContextMenuItem] = [.action(item)]
            if transaction.currency == .ton && transaction.collectible == nil {
                items.append(.action(ContextMenuActionItem(
                    text: whatIsGram,
                    icon: { theme in
                        return generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Context Menu/Help"),
                            color: theme.contextMenu.primaryColor
                        )
                    },
                    action: { [weak controller] _, dismiss in
                        dismiss(.default)
                        controller?.push(component.context.sharedContext.makeWalletInfoScreen(
                            context: component.context,
                            mode: .gram,
                            completion: nil
                        ))
                    }
                )))
            }
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                source: .reference(WalletTransactionContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
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
            (environment.controller() as? WalletTransactionPreviewScreen)?.invalidateCommentSession = { [weak self] in
                self?.invalidateCommentSession()
            }
            (environment.controller() as? WalletTransactionScreen)?.setCommentVisibilityAction(id: incomingModeId, action: { [weak self] visible, leavingTransaction in
                self?.commentVisibilityUpdated(visible, leavingTransaction: leavingTransaction)
            })

            let theme = environment.theme
            let transaction = self.currentTransaction()
            let walletState = self.latestWalletState ?? (self.walletContext ?? component.walletContext)?.stateValue
            let walletAddress: String?
            if case let .wallet(info) = walletState?.phase {
                walletAddress = info.address
            } else {
                walletAddress = nil
            }
            let isSelfTransfer = transaction.isSelfTransfer(walletAddress: walletAddress)
            let displaysIncomingSelfTransfer = isSelfTransfer && (!self.isPreview || self.isFinishedPreview)
            let displayedDirection: WalletContext.Transaction.Direction = displaysIncomingSelfTransfer ? .incoming : transaction.direction
            let displayedAmount = displaysIncomingSelfTransfer ? abs(transaction.amount) : transaction.amount
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
            let isKeyChange = transaction.kind == .keyChange
            let displaysGramHeader = transaction.currency == .ton && transaction.collectible == nil && !isKeyChange
            if !displaysGramHeader, let animationView = self.gramAnimation.view as? LottieComponent.View {
                transition.setAlpha(view: animationView, alpha: 0.0)
                animationView.externalShouldPlay = false
            }
            if !isKeyChange, let headerView = self.keyUpdateHeader.view {
                transition.setAlpha(view: headerView, alpha: 0.0)
            }
            if isKeyChange || transaction.collectible == nil, let headerView = self.collectibleHeader.view {
                transition.setAlpha(view: headerView, alpha: 0.0)
                (headerView as? WalletCollectibleHeaderComponent.View)?.setAnimationVisible(false)
            }
            if isKeyChange || transaction.collectible != nil {
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
            }

            var contentHeight: CGFloat = transaction.collectible == nil ? 71.0 : 44.0
            if isKeyChange {
                let headerSize = self.keyUpdateHeader.update(
                    transition: transition,
                    component: AnyComponent(WalletTransactionKeyUpdateHeaderComponent(theme: theme)),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
                )
                if let headerView = self.keyUpdateHeader.view {
                    if headerView.superview == nil {
                        self.addSubview(headerView)
                    }
                    transition.setFrame(view: headerView, frame: CGRect(origin: .zero, size: headerSize))
                    transition.setAlpha(view: headerView, alpha: 1.0)
                }
                contentHeight = headerSize.height
            } else if let collectible = transaction.collectible {
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
            } else {
                if displaysGramHeader {
                    let animationSize = CGSize(width: 118.0, height: 118.0)
                    let _ = self.gramAnimation.update(
                        transition: transition,
                        component: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(name: "TonDiamond"),
                            startingPosition: .begin,
                            size: animationSize,
                            loop: false,
                            lottieSettings: component.context.lottieRenderingSettings
                        )),
                        environment: {},
                        containerSize: animationSize
                    )
                    contentHeight = 10.0
                    if let animationView = self.gramAnimation.view as? LottieComponent.View {
                        animationView.externalShouldPlay = environment.isVisible
                        if animationView.superview == nil {
                            animationView.isUserInteractionEnabled = false
                            self.addSubview(animationView)
                            animationView.playOnce()
                        }
                        transition.setFrame(view: animationView, frame: CGRect(
                            x: floorToScreenPixels((availableSize.width - animationSize.width) / 2.0),
                            y: contentHeight,
                            width: animationSize.width,
                            height: animationSize.height
                        ))
                        transition.setAlpha(view: animationView, alpha: 1.0)
                    }
                    // TonDiamond includes transparent padding below the diamond.
                    contentHeight += animationSize.height - 16.0
                }
                let amountSize = self.amount.update(
                    transition: transition,
                    component: AnyComponent(WalletTransactionAmountComponent(
                        theme: theme,
                        dateTimeFormat: environment.dateTimeFormat,
                        amount: displayedAmount,
                        direction: displayedDirection,
                        currency: transaction.currency,
                        pending: !self.isPreview && transaction.status == .pending
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
                            abs(transaction.amount),
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
                    && (transaction.status == .pending || transaction.status == .failed)
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
            if displaysCommentBubble, isCommentConcealed || displayedComment != nil {
                contentHeight += 22.0
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let bubbleImage = self.commentBubbleImage(
                    presentationData: presentationData,
                    incoming: displayedDirection == .incoming,
                    fillColor: theme.list.itemInputField.backgroundColor
                )
                let commentSize: CGSize
                if isCommentConcealed {
                    commentSize = CGSize(width: 120.0, height: ceil(Font.regular(15.0).lineHeight))
                    self.commentText.view?.isHidden = true
                    (self.commentText.view as? TransactionCommentComponent.View)?.cancelSelection()
                } else {
                    commentSize = self.commentText.update(
                        transition: transition,
                        component: AnyComponent(TransactionCommentComponent(
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
                        + (displayedDirection == .incoming ? -3.0 : 3.0)
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
                    (commentView as? TransactionCommentComponent.View)?.cancelSelection()
                    transition.setAlpha(view: commentView, alpha: 0.0)
                }
                contentHeight += displaysGramHeader ? 32.0 : (!isKeyChange && transaction.collectible == nil ? 44.0 : 22.0)
            }

            let valueFont = Font.regular(15.0)
            let valueColor = theme.list.itemPrimaryTextColor
            let secondaryValueColor = theme.list.itemSecondaryTextColor
            let counterpartyTitle: String
            if self.isPreview && !self.isFinishedPreview {
                //TODO:localize
                counterpartyTitle = "Address"
            } else {
                switch displayedDirection {
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
            let counterpartyContent: AnyComponent<Empty>
            if case let .user(peer, _, _) = transaction.peer {
                counterpartyContentId = .peer(peer.id)
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
                counterpartyContentId = .name(transaction.peer.address ?? counterpartyName)
                counterpartyContent = AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: counterpartyName, font: valueFont, textColor: valueColor)),
                    maximumNumberOfLines: 0
                ))
            } else if let addressComponent, let address = transaction.peer.address {
                counterpartyContentId = .address(address)
                counterpartyContent = addressComponent
            } else {
                counterpartyContentId = .unknown
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
            if !self.isPreview, transaction.kind != .keyChange, component.walletContext != nil, canSendToPeer {
                switch displayedDirection {
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
                id: displaysSendButton ? CounterpartyRowId.withSendButton : .content(counterpartyContentId),
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
            if isSelfTransfer || (transaction.direction == .outgoing && !transaction.gasless), let feeComponent {
                tableItems.append(TableComponent.Item(
                    id: "fee",
                    title: feeTitle,
                    component: feeComponent
                ))
            }
            if !self.isPreview, !isSelfTransfer, transaction.gasless && transaction.direction == .outgoing {
                tableItems.append(TableComponent.Item(
                    id: "gaslessFee",
                    title: feeTitle,
                    component: AnyComponent(CounterpartyRowComponent(
                        counterparty: AnyComponentWithIdentity(
                            id: "gaslessFee",
                            component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(
                                    name: "Ads/TonAbout",
                                    tintColor: UIColor(rgb: 0x30a1f5),
                                    maxSize: CGSize(width: 14.0, height: 14.0)
                                ))),
                                AnyComponentWithIdentity(id: "text", component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        //TODO:localize
                                        string: "Free (paid by Telegram)",
                                        font: valueFont,
                                        textColor: valueColor
                                    )),
                                    maximumNumberOfLines: 0
                                )))
                            ], spacing: 3.0))
                        ),
                        sendButton: AnyComponent(Button(
                            content: AnyComponent(SendButtonContentComponent(
                                text: "?",
                                color: theme.list.itemAccentColor
                            )),
                            action: { [weak self] in
                                self?.presentFeesAlert(transaction: transaction)
                            }
                        )),
                        spacing: 6.0,
                        alignSendButtonToTop: false
                    ))
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

            let displaysGramInfo = displaysGramHeader && !self.isPreview
            if displaysGramInfo {
                contentHeight += 4.0
                //TODO:localize
                let gramInfoTitle = "What's Gram?"
                let gramInfoSize = self.gramInfoButton.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(Text(
                            text: gramInfoTitle,
                            font: Font.regular(14.0),
                            color: theme.actionSheet.controlAccentColor
                        )),
                        minSize: CGSize(width: 44.0, height: 44.0),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            self.environment?.controller()?.push(component.context.sharedContext.makeWalletInfoScreen(
                                context: component.context,
                                mode: .gram,
                                completion: nil
                            ))
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: tableWidth, height: 44.0)
                )
                if let gramInfoView = self.gramInfoButton.view {
                    if gramInfoView.superview == nil {
                        self.addSubview(gramInfoView)
                    }
                    gramInfoView.isUserInteractionEnabled = true
                    gramInfoView.isAccessibilityElement = true
                    gramInfoView.accessibilityLabel = gramInfoTitle
                    gramInfoView.accessibilityTraits = .button
                    transition.setFrame(view: gramInfoView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - gramInfoSize.width) / 2.0),
                        y: contentHeight,
                        width: gramInfoSize.width,
                        height: gramInfoSize.height
                    ))
                    transition.setAlpha(view: gramInfoView, alpha: 1.0)
                }
                contentHeight += gramInfoSize.height
            } else if let gramInfoView = self.gramInfoButton.view {
                gramInfoView.isUserInteractionEnabled = false
                transition.setAlpha(view: gramInfoView, alpha: 0.0)
            }

            let displaysInput = self.isPreview && !self.isFinishedPreview
            let displaysCommentEncryption = displaysInput && transaction.collectible == nil
            if displaysInput {
                contentHeight += 12.0
                let inputWidth = tableSize.width
                let commentEncryptionButtonSize = CGSize(width: 44.0, height: 40.0)
                let inputFieldWidth = displaysCommentEncryption
                    ? max(0.0, inputWidth - commentEncryptionButtonSize.width)
                    : inputWidth
                //TODO:localize
                let optionalMessage = "Optional message"
                self.inputField.parentState = state
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
                        // TextFieldComponent adds another 8 pt, giving a total leading inset of 16 pt.
                        insets: UIEdgeInsets(top: 10.0, left: 8.0, bottom: 10.0, right: 16.0),
                        hideKeyboard: false,
                        customInputView: nil,
                        placeholder: NSAttributedString(
                            string: optionalMessage,
                            font: Font.regular(17.0),
                            textColor: theme.actionSheet.inputPlaceholderColor
                        ),
                        resetText: nil,
                        isOneLineWhenUnfocused: false,
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
                    containerSize: CGSize(width: inputFieldWidth, height: .greatestFiniteMagnitude)
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
                        x: floorToScreenPixels((availableSize.width - inputWidth) / 2.0),
                        y: contentHeight + floorToScreenPixels((inputSize.height - fieldSize.height) / 2.0) + 1.0 - UIScreenPixel,
                        width: fieldSize.width,
                        height: fieldSize.height
                    ))
                    transition.setAlpha(view: fieldView, alpha: 1.0)
                    fieldView.isUserInteractionEnabled = self.canEditPreviewComment
                }
                if displaysCommentEncryption {
                    let commentEncrypted = self.previewCommentEncrypted
                    let buttonSize = self.commentEncryptionButton.update(
                        transition: transition,
                        component: AnyComponent(PlainButtonComponent(
                            content: AnyComponent(LottieComponent(
                                content: LottieComponent.AppBundleContent(
                                    name: "WalletCommentLock",
                                    frameRange: commentEncrypted ? (10.0 / 180.0 ..< 30.0 / 180.0) : (0.0 ..< 11.0 / 180.0)
                                ),
                                color: commentEncrypted ? theme.actionSheet.controlAccentColor : theme.actionSheet.inputPlaceholderColor,
                                startingPosition: .end,
                                size: CGSize(width: 24.0, height: 24.0),
                                lottieSettings: component.context.lottieRenderingSettings
                            )),
                            minSize: commentEncryptionButtonSize,
                            action: { [weak self] in
                                self?.commentEncryptionPressed()
                            },
                            isEnabled: self.canEditPreviewComment,
                            animateContents: false
                        )),
                        environment: {},
                        containerSize: commentEncryptionButtonSize
                    )
                    if let buttonView = self.commentEncryptionButton.view {
                        if buttonView.superview == nil {
                            self.addSubview(buttonView)
                        }
                        transition.setFrame(view: buttonView, frame: CGRect(
                            x: floorToScreenPixels((availableSize.width - tableSize.width) / 2.0) + tableSize.width - buttonSize.width,
                            y: contentHeight + floorToScreenPixels((inputSize.height - buttonSize.height) / 2.0),
                            width: buttonSize.width,
                            height: buttonSize.height
                        ))
                        transition.setAlpha(view: buttonView, alpha: 1.0)
                        buttonView.isUserInteractionEnabled = self.canEditPreviewComment
                        //TODO:localize
                        buttonView.accessibilityLabel = "Comment privacy"
                        buttonView.accessibilityValue = self.commentPrivacyDescription

                        if let displayedCommentEncrypted = self.displayedCommentEncrypted,
                           displayedCommentEncrypted != commentEncrypted,
                           let animationView = (buttonView as? PlainButtonComponent.View)?.contentView as? LottieComponent.View {
                            animationView.playOnce()
                        }
                        self.displayedCommentEncrypted = commentEncrypted
                    }
                }
                contentHeight += inputSize.height
                contentHeight += 24.0
            } else {
                contentHeight += displaysGramInfo ? 2.0 : 30.0
                if let backgroundView = self.inputBackground.view {
                    transition.setAlpha(view: backgroundView, alpha: 0.0)
                }
                if let fieldView = self.inputField.view {
                    transition.setAlpha(view: fieldView, alpha: 0.0)
                }
            }

            if !displaysCommentEncryption {
                if let buttonView = self.commentEncryptionButton.view {
                    transition.setAlpha(view: buttonView, alpha: 0.0)
                    buttonView.isUserInteractionEnabled = false
                }
                self.displayedCommentEncrypted = nil
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
            } else if !self.isPreview && component.fromChat {
                //TODO:localize
                actionTitle = "Open My Wallet"
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
                        } else if !self.isPreview && self.component?.fromChat == true {
                            self.openMyWallet()
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
    let fromChat: Bool
    let transactions: [WalletContext.Transaction]
    let initialIndex: Int
    let itemSpacing: CGFloat
    let openExplorer: (String) -> Void
    let indexUpdated: (Int) -> Void
    let draggingBegan: (Int) -> Void

    init(
        context: AccountContext,
        walletContext: WalletContext,
        fromChat: Bool,
        transactions: [WalletContext.Transaction],
        initialIndex: Int,
        itemSpacing: CGFloat,
        openExplorer: @escaping (String) -> Void,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) {
        self.context = context
        self.walletContext = walletContext
        self.fromChat = fromChat
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
            && lhs.fromChat == rhs.fromChat
            && lhs.transactions == rhs.transactions
            && lhs.initialIndex == rhs.initialIndex
            && lhs.itemSpacing == rhs.itemSpacing
    }

    typealias View = WalletPagerView

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
            itemIds: self.transactions.map(\.presentationId),
            initialIndex: self.initialIndex,
            itemSpacing: self.itemSpacing,
            availableSize: availableSize,
            environment: environment,
            transition: transition,
            makeContent: { index, isCurrent in
                return AnyComponent(WalletTransactionSheetComponent(
                    context: self.context,
                    transaction: self.transactions[index],
                    walletContext: self.walletContext,
                    fromChat: self.fromChat,
                    hasDimView: false,
                    updatesPresentationContextLayout: isCurrent,
                    openExplorer: self.openExplorer
                ))
            },
            indexUpdated: self.indexUpdated,
            draggingBegan: self.draggingBegan
        )
    }
}

private final class WalletTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let transaction: WalletContext.Transaction
    let walletContext: WalletContext?
    let fromChat: Bool
    let hasDimView: Bool
    let updatesPresentationContextLayout: Bool
    let openExplorer: (String) -> Void

    init(
        context: AccountContext,
        transaction: WalletContext.Transaction,
        walletContext: WalletContext?,
        fromChat: Bool,
        hasDimView: Bool,
        updatesPresentationContextLayout: Bool,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.transaction = transaction
        self.walletContext = walletContext
        self.fromChat = fromChat
        self.hasDimView = hasDimView
        self.updatesPresentationContextLayout = updatesPresentationContextLayout
        self.openExplorer = openExplorer
    }

    static func ==(lhs: WalletTransactionSheetComponent, rhs: WalletTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context
            || lhs.walletContext !== rhs.walletContext
            || lhs.fromChat != rhs.fromChat
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
                        fromChat: context.component.fromChat,
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
                        fromChat: false,
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

            if let sheetView = findTaggedComponentViewImpl(
                view: context.view,
                tag: ResizableSheetComponent<EnvironmentType>.View.Tag()
            ) as? ResizableSheetComponent<EnvironmentType>.View,
               let contentView = sheetView.contentViewValue as? WalletTransactionContentComponent.View,
               contentView.isCommentInputActive {
                sheetView.scrollToBottom(transition: context.transition)
            }

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
    private let fromChat: Bool
    private let openExplorer: (String) -> Void
    private let stateDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    private let firstGramsSuggestionDisposable = MetaDisposable()
    private var checkFirstGramsOnAppear: Bool
    #if DEBUG
    private var gaslessInfoDisposable: Disposable?
    #endif
    fileprivate var refreshBalanceOnSend: Bool {
        self.navigationWalletContext == nil
    }

    private var transactionsState: WalletContext.TransactionsState?
    private var transactions: [WalletContext.Transaction]
    private var currentTransactionPresentationId: String?
    private var currentCloseId: String
    private var closeActions: [String: (Bool) -> Void] = [:]
    private var commentVisibilityActions: [String: (Bool, Bool) -> Void] = [:]
    private var requestedOffset: Int?
    private var failedOffset: Int?

    public init(
        context: AccountContext,
        walletContext: WalletContext? = nil,
        transaction: WalletContext.Transaction,
        fromChat: Bool
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
        self.fromChat = fromChat
        self.openExplorer = openExplorer
        self.checkFirstGramsOnAppear = transaction.direction == .incoming && transaction.currency == .ton && transaction.collectible == nil
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
                fromChat: fromChat,
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
                fromChat: fromChat,
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
        self.stateDisposable.dispose()
        self.loadMoreDisposable.dispose()
        self.firstGramsSuggestionDisposable.dispose()
        #if DEBUG
        self.gaslessInfoDisposable?.dispose()
        #endif
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if DEBUG
        if self.gaslessInfoDisposable == nil {
            self.gaslessInfoDisposable = (self.navigationWalletContext ?? self.accountContext.walletContext)?.beginGaslessInfoUpdates()
        }
        #endif
        self.commentVisibilityActions[self.currentCloseId]?(true, false)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard self.checkFirstGramsOnAppear else {
            return
        }
        self.checkFirstGramsOnAppear = false
        self.firstGramsSuggestionDisposable.set((self.accountContext.engine.notices.getServerProvidedSuggestions()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] suggestions in
            guard let self, suggestions.contains(.firstGrams),
                  let navigationController = self.navigationController as? NavigationController,
                  navigationController.topViewController === self else {
                return
            }
            navigationController.pushViewController(self.accountContext.sharedContext.makeWalletInfoScreen(
                context: self.accountContext,
                mode: .firstGrams,
                completion: nil
            ))
            let _ = self.accountContext.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.firstGrams.id).startStandalone()
        }))
    }

    public override func viewWillDisappear(_ animated: Bool) {
        self.cancelFirstGramsSuggestion()
        super.viewWillDisappear(animated)
        for action in self.commentVisibilityActions.values {
            action(false, false)
        }
        self.dismissAllTooltips()
    }

    fileprivate func cancelFirstGramsSuggestion() {
        self.checkFirstGramsOnAppear = false
        self.firstGramsSuggestionDisposable.dispose()
    }

    fileprivate func setCloseAction(id: String, action: @escaping (Bool) -> Void) {
        self.closeActions[id] = action
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        #if DEBUG
        self.gaslessInfoDisposable?.dispose()
        self.gaslessInfoDisposable = nil
        #endif
        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            for action in self.commentVisibilityActions.values { action(false, true) }
        }
    }

    fileprivate func setCommentVisibilityAction(id: String, action: @escaping (Bool, Bool) -> Void) {
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
                    fromChat: self.fromChat,
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
            self.commentVisibilityActions[self.currentCloseId]?(false, true)
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
    fileprivate var invalidateCommentSession: (() -> Void)?

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
        if self.isBeingDismissed || self.isMovingFromParent || self.navigationController?.isBeingDismissed == true {
            self.invalidateCommentSession?()
        }
        self.dismissAllTooltips()
    }

    public override func dismiss(completion: (() -> Void)? = nil) {
        self.invalidateCommentSession?()
        super.dismiss(completion: completion)
    }

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.invalidateCommentSession?()
        super.dismiss(animated: flag, completion: completion)
    }

    public override func viewWillLeaveNavigation() {
        self.invalidateCommentSession?()
        super.viewWillLeaveNavigation()
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

private func walletTransactionExplorerUrl(explorerUrl: String, id: String) -> String? {
    guard let encodedId = tonHashHex(fromBase64: id) else {
        return nil
    }
    let baseUrl = explorerUrl.hasSuffix("/") ? explorerUrl : explorerUrl + "/"
    return "\(baseUrl)transaction/\(encodedId)"
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
