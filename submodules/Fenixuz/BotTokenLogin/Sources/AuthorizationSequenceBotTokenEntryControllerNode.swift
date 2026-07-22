import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AuthorizationUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode

private let titleText = "Bot token bilan kirish"
private let noticeText = "Bot rejimi cheklangan: chat ro'yxati va tarix ko'rinmaydi"
private let placeholderText = "123456789:ABCdef..."
private let proceedText = "Kirish"
private let pasteText = "Joylash"

// A bot token looks like "<digits>:<35 chars>", e.g. 123456789:AAE... . Lenient check so we
// auto-fill / recognise a pasted token without being strict about Telegram's exact length.
private func isLikelyBotToken(_ raw: String) -> Bool {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let colon = value.firstIndex(of: ":") else {
        return false
    }
    let idPart = value[value.startIndex ..< colon]
    let secretPart = value[value.index(after: colon)...]
    guard idPart.count >= 5, idPart.allSatisfy({ $0.isNumber }) else {
        return false
    }
    guard secretPart.count >= 20, secretPart.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else {
        return false
    }
    return true
}

final class AuthorizationSequenceBotTokenEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme

    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let titleActivateAreaNode: AccessibilityAreaNode
    private let noticeNode: ASTextNode
    private let noticeActivateAreaNode: AccessibilityAreaNode
    private let proceedNode: SolidRoundedButtonNode

    private let inputBackgroundNode: ASDisplayNode
    private let tokenField: TextFieldNode
    private let pasteButton: HighlightableButtonNode

    private let hapticFeedback = HapticFeedback()
    private var didCheckClipboard = false

    private var layoutArguments: (ContainerViewLayout, CGFloat)?

    var currentToken: String {
        return self.tokenField.textField.text ?? ""
    }

    var proceed: ((String) -> Void)?

    var inProgress: Bool = false {
        didSet {
            self.inputBackgroundNode.alpha = self.inProgress ? 0.6 : 1.0
            self.tokenField.alpha = self.inProgress ? 0.6 : 1.0

            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }

    private var timer: SwiftSignalKit.Timer?

    private let appearanceTimestamp = CACurrentMediaTime()

    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme

        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroPassword"), width: 256, height: 256, playbackMode: .still(.start), mode: .direct(cachePathPrefix: nil))

        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: titleText, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)

        self.titleActivateAreaNode = AccessibilityAreaNode()
        self.titleActivateAreaNode.accessibilityTraits = .staticText

        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.lineSpacing = 0.1
        self.noticeNode.attributedText = NSAttributedString(string: noticeText, font: Font.regular(15.0), textColor: self.theme.list.itemSecondaryTextColor, paragraphAlignment: .center)

        self.noticeActivateAreaNode = AccessibilityAreaNode()
        self.noticeActivateAreaNode.accessibilityTraits = .staticText

        // Filled, rounded input container — a polished native dark-theme field instead of a bare underline.
        self.inputBackgroundNode = ASDisplayNode()
        self.inputBackgroundNode.backgroundColor = self.theme.list.itemBlocksBackgroundColor
        self.inputBackgroundNode.cornerRadius = 12.0
        self.inputBackgroundNode.borderWidth = UIScreenPixel
        self.inputBackgroundNode.borderColor = self.theme.list.itemBlocksSeparatorColor.cgColor

        // Monospaced token font — it is a technical credential, so it should read like one.
        let tokenFont = UIFont.monospacedSystemFont(ofSize: 17.0, weight: .regular)
        self.tokenField = TextFieldNode()
        self.tokenField.textField.font = tokenFont
        self.tokenField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.tokenField.textField.textAlignment = .natural
        self.tokenField.textField.isSecureTextEntry = false
        self.tokenField.textField.autocapitalizationType = .none
        self.tokenField.textField.autocorrectionType = .no
        self.tokenField.textField.spellCheckingType = .no
        self.tokenField.textField.keyboardType = .asciiCapable
        self.tokenField.textField.returnKeyType = .done
        self.tokenField.textField.clearButtonMode = .whileEditing
        self.tokenField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.tokenField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.tokenField.textField.tintColor = self.theme.list.itemAccentColor
        self.tokenField.textField.attributedPlaceholder = NSAttributedString(string: placeholderText, font: tokenFont, textColor: self.theme.list.itemPlaceholderTextColor)

        // One-tap paste chip, trailing inside the field. Accent-tinted pill; hidden once the field has text.
        self.pasteButton = HighlightableButtonNode()
        self.pasteButton.setTitle(pasteText, with: Font.semibold(15.0), with: self.theme.list.itemAccentColor, for: .normal)
        self.pasteButton.backgroundColor = self.theme.list.itemAccentColor.withAlphaComponent(0.12)
        self.pasteButton.cornerRadius = 9.0
        self.pasteButton.accessibilityLabel = pasteText

        self.proceedNode = SolidRoundedButtonNode(title: proceedText, theme: SolidRoundedButtonTheme(backgroundColor: self.theme.list.itemCheckColors.fillColor, foregroundColor: self.theme.list.itemCheckColors.foregroundColor), glass: false, height: 50.0, cornerRadius: 50.0 * 0.5)
        self.proceedNode.progressType = .embedded
        self.proceedNode.isEnabled = false

        super.init()

        self.setViewBlock({
            return UITracingLayerView()
        })

        self.backgroundColor = self.theme.list.plainBackgroundColor

        self.tokenField.textField.delegate = self
        self.tokenField.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)

        self.addSubnode(self.inputBackgroundNode)
        self.addSubnode(self.tokenField)
        self.addSubnode(self.pasteButton)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleActivateAreaNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.noticeActivateAreaNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.proceedNode)

        self.pasteButton.addTarget(self, action: #selector(self.pastePressed), forControlEvents: .touchUpInside)

        // Tap anywhere on the field container to focus it.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.inputContainerTapped))
        self.inputBackgroundNode.view.addGestureRecognizer(tapGesture)

        self.proceedNode.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.proceed?(strongSelf.currentToken)
            }
        }

        self.timer = SwiftSignalKit.Timer(timeout: 7.5, repeat: true, completion: { [weak self] in
            self?.animationNode.playOnce()
        }, queue: Queue.mainQueue())
        self.timer?.start()
    }

    deinit {
        self.timer?.invalidate()
    }

    func updateData() {
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.layoutArguments?.0.inputHeight ?? 0.0
        let newInputHeight = layout.inputHeight ?? 0.0

        self.layoutArguments = (layout, navigationBarHeight)

        var layout = layout
        if CACurrentMediaTime() - self.appearanceTimestamp < 2.0, newInputHeight < previousInputHeight {
            layout = layout.withUpdatedInputHeight(previousInputHeight)
        }

        let inset: CGFloat = 24.0
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        let fieldWidth = maximumWidth - inset * 2.0
        let fieldHeight: CGFloat = 54.0

        var insets = layout.insets(options: [])
        insets.top = layout.statusBarHeight ?? 20.0
        if let inputHeight = layout.inputHeight, !inputHeight.isZero {
            insets.bottom = max(inputHeight, insets.bottom)
        }

        let titleInset: CGFloat = layout.size.width > 320.0 ? 18.0 : 0.0
        let additionalBottomInset: CGFloat = layout.size.width > 320.0 ? 110.0 : 20.0

        let animationSize = CGSize(width: 100.0, height: 100.0)
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))

        let noticeSize = self.noticeNode.measure(CGSize(width: maximumWidth - 40.0, height: CGFloat.greatestFiniteMagnitude))
        let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - inset * 2.0, transition: transition)
        let proceedSize = CGSize(width: maximumWidth - inset * 2.0, height: proceedHeight)

        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: titleInset, maxValue: titleInset), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 14.0, maxValue: 14.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.inputBackgroundNode, size: CGSize(width: fieldWidth, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 36.0, maxValue: 60.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))

        if layout.size.width > 320.0 {
            items.insert(AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)), at: 0)
            self.proceedNode.isHidden = false
            self.animationNode.isHidden = false
            self.animationNode.visibility = true
        } else {
            insets.top = navigationBarHeight
            self.proceedNode.isHidden = true
            self.animationNode.isHidden = true
        }

        transition.updateFrame(node: self.proceedNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize))

        self.animationNode.updateLayout(size: animationSize)

        _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - additionalBottomInset)), items: items, transition: transition, failIfDoesNotFit: false)

        // Position the token field and the paste chip inside the container's resolved frame.
        let containerFrame = self.inputBackgroundNode.frame
        let leftPadding: CGFloat = 16.0
        let pasteSize = self.pasteButton.measure(CGSize(width: 160.0, height: fieldHeight))
        let pasteWidth = pasteSize.width + 24.0
        let pasteHeight: CGFloat = 34.0
        let pasteTrailing: CGFloat = 8.0

        transition.updateFrame(node: self.pasteButton, frame: CGRect(x: containerFrame.maxX - pasteWidth - pasteTrailing, y: containerFrame.midY - pasteHeight / 2.0, width: pasteWidth, height: pasteHeight))

        let fieldTrailingLimit = containerFrame.maxX - pasteWidth - pasteTrailing - 8.0
        transition.updateFrame(node: self.tokenField, frame: CGRect(x: containerFrame.minX + leftPadding, y: containerFrame.minY, width: fieldTrailingLimit - (containerFrame.minX + leftPadding), height: containerFrame.height))

        self.updatePasteButtonVisibility()

        self.titleActivateAreaNode.accessibilityLabel = self.titleNode.attributedText?.string ?? ""
        self.noticeActivateAreaNode.accessibilityLabel = self.noticeNode.attributedText?.string ?? ""

        self.titleActivateAreaNode.frame = self.titleNode.frame
        self.noticeActivateAreaNode.frame = self.noticeNode.frame
    }

    func activateInput() {
        self.tokenField.textField.becomeFirstResponder()
        self.checkClipboardAutofill()
    }

    // If the clipboard already holds a bot-token-shaped string and the field is empty, fill it once so
    // the user can just tap "Kirish" — the fast path. They can still clear/edit it.
    private func checkClipboardAutofill() {
        guard !self.didCheckClipboard else {
            return
        }
        self.didCheckClipboard = true
        guard (self.tokenField.textField.text ?? "").isEmpty, UIPasteboard.general.hasStrings else {
            return
        }
        if let clipboard = UIPasteboard.general.string, isLikelyBotToken(clipboard) {
            self.tokenField.textField.text = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
            self.hapticFeedback.success()
            self.textDidChange()
        }
    }

    @objc private func pastePressed() {
        guard let clipboard = UIPasteboard.general.string, !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.hapticFeedback.error()
            return
        }
        self.tokenField.textField.text = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hapticFeedback.impact(.light)
        self.textDidChange()
    }

    @objc private func inputContainerTapped() {
        self.tokenField.textField.becomeFirstResponder()
    }

    private func updatePasteButtonVisibility() {
        let isEmpty = (self.tokenField.textField.text ?? "").isEmpty
        // hasStrings is a cheap check that does NOT read the clipboard content, so it never triggers the
        // iOS "pasted from…" banner — unlike reading `.string`, which we only do on the explicit paste tap.
        self.pasteButton.isHidden = !(isEmpty && UIPasteboard.general.hasStrings)
    }

    func animateError() {
        self.hapticFeedback.error()
        self.inputBackgroundNode.layer.addShakeAnimation()
        self.tokenField.layer.addShakeAnimation()
    }

    @objc func textDidChange() {
        self.proceedNode.isEnabled = !(self.tokenField.textField.text ?? "").isEmpty
        self.updatePasteButtonVisibility()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.proceed?(self.currentToken)
        return false
    }
}
