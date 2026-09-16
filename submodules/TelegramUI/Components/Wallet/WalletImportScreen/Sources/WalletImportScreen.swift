import PasscodeCore
import Foundation
import LottieSettings
import UIKit
import Display
import AccountContext
import Markdown
import ComponentFlow
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import LottieComponent
import ButtonComponent
import SegmentControlComponent
import WalletContext
import SwiftSignalKit
import WalletAuthorizationUI

private final class WalletImportScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let mode: WalletImportScreenMode
    let verificationIndices: [Int]
    let completion: (() -> Void)?

    init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletImportScreenMode,
        verificationIndices: [Int],
        completion: (() -> Void)?
    ) {
        self.context = context
        self.walletContext = walletContext
        self.mode = mode
        self.verificationIndices = verificationIndices
        self.completion = completion
    }

    static func ==(lhs: WalletImportScreenComponent, rhs: WalletImportScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.walletContext === rhs.walletContext
            && lhs.mode == rhs.mode
            && lhs.verificationIndices == rhs.verificationIndices
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private final class WordTextField: UITextField {
            var emptyBackspace: (() -> Void)?
            var pastedText: ((String) -> Bool)?
            var shouldBecomeFirstResponder: (() -> Bool)?

            override func becomeFirstResponder() -> Bool {
                guard self.shouldBecomeFirstResponder?() ?? true else {
                    return false
                }
                let shouldSelectAll = !self.isFirstResponder && self.text?.isEmpty == false
                let result = super.becomeFirstResponder()
                if result && shouldSelectAll {
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.isFirstResponder else {
                            return
                        }
                        self.selectAll(nil)
                    }
                }
                return result
            }

            override func deleteBackward() {
                if self.text?.isEmpty != false {
                    self.emptyBackspace?()
                }
                super.deleteBackward()
            }

            override func paste(_ sender: Any?) {
                if let text = UIPasteboard.general.string, self.pastedText?(text) == true {
                    return
                }
                super.paste(sender)
            }
        }

        private final class WordFieldView: UIView, UITextFieldDelegate {
            let index: Int
            private var displayNumber: Int

            private let backgroundLayer = SimpleShapeLayer()
            private let numberText = ComponentView<Empty>()
            private let pasteButton = ComponentView<Empty>()
            let textField = WordTextField()

            var textChanged: ((Int, String) -> Void)?
            var editingChanged: ((Int, Bool) -> Void)?
            var shouldBeginEditing: ((Int) -> Bool)?
            var returnPressed: ((Int) -> Void)?
            var pasteWords: ((Int, [String]) -> Bool)?
            var emptyBackspace: ((Int) -> Void)?
            var pastePressed: (() -> Void)?

            init(index: Int, displayNumber: Int, wordCount: Int) {
                self.index = index
                self.displayNumber = displayNumber

                super.init(frame: CGRect())

                self.backgroundLayer.lineWidth = 1.0
                self.backgroundLayer.fillColor = UIColor.clear.cgColor
                self.backgroundLayer.strokeColor = UIColor.clear.cgColor
                self.layer.addSublayer(self.backgroundLayer)

                self.textField.delegate = self
                self.textField.font = Font.regular(17.0)
                self.textField.borderStyle = .none
                self.textField.backgroundColor = .clear
                self.textField.keyboardType = .asciiCapable
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .none
                self.textField.spellCheckingType = .no
                self.textField.clearButtonMode = .whileEditing
                self.textField.returnKeyType = index == wordCount - 1 ? .done : .next
                self.textField.enablesReturnKeyAutomatically = false
                if #available(iOS 11.0, *) {
                    self.textField.smartDashesType = .no
                    self.textField.smartQuotesType = .no
                    self.textField.smartInsertDeleteType = .no
                }
                self.textField.addTarget(self, action: #selector(self.textFieldTextChanged), for: .editingChanged)
                self.textField.shouldBecomeFirstResponder = { [weak self] in
                    guard let self else {
                        return true
                    }
                    return self.shouldBeginEditing?(self.index) ?? true
                }
                self.textField.emptyBackspace = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.emptyBackspace?(self.index)
                }
                self.textField.pastedText = { [weak self] text in
                    guard let self else {
                        return false
                    }
                    let words = text
                        .split(whereSeparator: { $0.isWhitespace })
                        .map { String($0) }
                    guard !words.isEmpty else {
                        return false
                    }
                    return self.pasteWords?(self.index, words) ?? false
                }

                self.addSubview(self.textField)
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            func updateConfiguration(displayNumber: Int, wordCount: Int) {
                self.displayNumber = displayNumber
                self.textField.returnKeyType = self.index == wordCount - 1 ? .done : .next
            }

            func update(
                theme: PresentationTheme,
                isInvalid: Bool,
                displaysPasteButton: Bool,
                size: CGSize
            ) {
                let transition = ComponentTransition.easeInOut(duration: 0.2)

                let backgroundFrame = CGRect(origin: .zero, size: size)
                transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
                transition.setShapeLayerPath(
                    layer: self.backgroundLayer,
                    path: UIBezierPath(roundedRect: backgroundFrame, cornerRadius: 26.0).cgPath
                )
                transition.setShapeLayerFillColor(
                    layer: self.backgroundLayer,
                    color: isInvalid
                        ? theme.list.itemInputField.backgroundColor.mixedWith(theme.list.itemDestructiveColor, alpha: 0.03)
                        : theme.list.itemInputField.backgroundColor
                )
                transition.setShapeLayerStrokeColor(
                    layer: self.backgroundLayer,
                    color: isInvalid ? theme.list.itemDestructiveColor : .clear
                )

                let numberColor = self.textField.isFirstResponder || self.textField.text?.isEmpty == false
                    ? theme.list.itemPrimaryTextColor
                    : theme.list.itemSecondaryTextColor
                self.textField.textColor = theme.list.itemPrimaryTextColor
                self.textField.tintColor = theme.list.itemAccentColor
                self.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance

                let numberInset: CGFloat = 10.0
                let numberWidth: CGFloat = 26.0
                let numberTextSpacing: CGFloat = 5.0
                let numberTextSize = self.numberText.update(
                    transition: transition,
                    component: AnyComponent(Text(
                        text: "\(self.displayNumber).",
                        font: Font.with(size: 17.0, traits: .monospacedNumbers),
                        color: .white,
                        tintColor: numberColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: numberWidth, height: size.height)
                )
                if let numberTextView = self.numberText.view {
                    if numberTextView.superview == nil {
                        self.insertSubview(numberTextView, belowSubview: self.textField)
                    }
                    numberTextView.frame = CGRect(
                        x: numberInset + numberWidth - numberTextSize.width,
                        y: floor((size.height - numberTextSize.height) / 2.0) + 1.0,
                        width: numberTextSize.width,
                        height: numberTextSize.height
                    )
                }
                let textFieldMinX = numberInset + numberWidth + numberTextSpacing
                var textFieldMaxX = size.width - 9.0
                if displaysPasteButton {
                    let pasteButtonHeight: CGFloat = 28.0
                    let pasteButtonSize = self.pasteButton.update(
                        transition: transition,
                        component: AnyComponent(ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .legacy,
                                color: theme.overallDarkAppearance
                                    ? theme.actionSheet.opaqueItemBackgroundColor
                                    : theme.list.plainBackgroundColor,
                                foreground: theme.list.itemAccentColor,
                                pressedColor: theme.list.itemInputField.backgroundColor,
                                cornerRadius: pasteButtonHeight / 2.0
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable("paste"),
                                component: AnyComponent(Text(
                                    text: "Paste",
                                    font: Font.semibold(15.0),
                                    color: theme.list.itemAccentColor
                                ))
                            ),
                            restrictContentAnimations: true,
                            contentInsets: UIEdgeInsets(
                                top: 0.0,
                                left: 16.0,
                                bottom: 0.0,
                                right: 16.0
                            ),
                            fitToContentWidth: true,
                            isEnabled: true,
                            displaysProgress: false,
                            action: { [weak self] in
                                self?.pastePressed?()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(
                            width: max(1.0, size.width - 16.0),
                            height: pasteButtonHeight
                        )
                    )
                    if let pasteButtonView = self.pasteButton.view {
                        var transition = transition
                        if pasteButtonView.superview == nil {
                            transition = .immediate
                            self.addSubview(pasteButtonView)
                        }
                        let pasteButtonFrame = CGRect(
                            x: size.width - 12.0 - pasteButtonSize.width,
                            y: floor((size.height - pasteButtonSize.height) / 2.0),
                            width: pasteButtonSize.width,
                            height: pasteButtonSize.height
                        )
                        transition.setFrame(view: pasteButtonView, frame: pasteButtonFrame)
                        textFieldMaxX = pasteButtonFrame.minX - 4.0
                    }
                } else {
                    self.pasteButton.view?.removeFromSuperview()
                }
                self.textField.frame = CGRect(
                    x: textFieldMinX,
                    y: 0.0,
                    width: max(0.0, textFieldMaxX - textFieldMinX),
                    height: size.height
                )
            }

            func setText(_ text: String) {
                self.textField.text = text
            }

            @objc private func textFieldTextChanged() {
                let currentText = self.textField.text ?? ""
                let normalizedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if currentText != normalizedText {
                    self.textField.text = normalizedText
                }
                self.textChanged?(self.index, normalizedText)
            }

            func textFieldDidBeginEditing(_ textField: UITextField) {
                self.editingChanged?(self.index, true)
            }

            func textFieldDidEndEditing(_ textField: UITextField) {
                self.editingChanged?(self.index, false)
            }

            func textFieldShouldReturn(_ textField: UITextField) -> Bool {
                self.returnPressed?(self.index)
                return false
            }

            func textFieldShouldClear(_ textField: UITextField) -> Bool {
                self.textChanged?(self.index, "")
                return true
            }

            func textField(
                _ textField: UITextField,
                shouldChangeCharactersIn range: NSRange,
                replacementString string: String
            ) -> Bool {
                if string == " " {
                    self.returnPressed?(self.index)
                    return false
                }
                guard string.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else {
                    return true
                }

                let words = string
                    .split(whereSeparator: { $0.isWhitespace })
                    .map { String($0) }
                if !words.isEmpty {
                    return !(self.pasteWords?(self.index, words) ?? false)
                }
                return false
            }
        }

        private let scrollView = ScrollView()
        private let animation = ComponentView<Empty>()
        private let navigationTitle = ComponentView<Empty>()
        private let titleTransformContainer = UIView()
        private let body = ComponentView<Empty>()
        private let wordCountControl = ComponentView<Empty>()
        private var wordFields: [WordFieldView] = []
        private var wordSuggestionView: ComponentHostView<Empty>?
        private let button = ComponentView<Empty>()

        private let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        private var didRequestInitialFocus = false

        private weak var componentState: EmptyComponentState?
        private var environment: EnvironmentType?
        private var component: WalletImportScreenComponent?
        private let operationDisposable = MetaDisposable()
        private var flowSession: PasscodeSession?
        private var flowGeneration: UInt64 = 0
        private let discardDisposable = MetaDisposable()
        private var isImporting = false
        private var activePreparedRecoveryPhraseImport: WalletContext.PreparedRecoveryPhraseImport?
        private var preparedImportWords: [String]?
        private var didCompleteVerification = false
        private var words = Array(repeating: "", count: 12)
        private var isImportPhraseValid = false
        private var invalidWordIndices = Set<Int>()
        private var activeWordIndex: Int?
        private var wordSuggestions: [String] = []
        private var hasInvalidWordSuggestion = false
        private var invalidWordSuggestionPulseId = 0
        private var wordSuggestionFrame: CGRect?
        private var hasPasteboardText = UIPasteboard.general.hasStrings
        private var scrollToBottomAfterPaste = false

        override init(frame: CGRect) {
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.keyboardDismissMode = .interactive
            self.scrollView.alwaysBounceVertical = true
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }

            self.titleTransformContainer.isUserInteractionEnabled = false

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIPasteboard.changedNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.pasteboardDidChange(_:)),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )

            self.setupWordInputFields(displayNumbers: Array(1 ... 12), preserving: [])
        }

        private func setupWordInputFields(
            displayNumbers: [Int],
            preserving existingWords: [String],
            preservingFocus: Bool = false
        ) {
            guard !displayNumbers.isEmpty else {
                return
            }
            let count = displayNumbers.count
            let preservedActiveWordIndex = preservingFocus
                ? self.wordFields.firstIndex(where: { $0.textField.isFirstResponder })
                : nil
            self.words = Array(repeating: "", count: count)
            for index in 0 ..< min(existingWords.count, count) {
                self.words[index] = existingWords[index]
            }
            self.updateImportPhraseValidity()
            self.invalidWordIndices.removeAll()
            if let preservedActiveWordIndex, preservedActiveWordIndex < count {
                self.activeWordIndex = preservedActiveWordIndex
            } else {
                self.activeWordIndex = nil
            }
            self.wordSuggestions = []
            self.hasInvalidWordSuggestion = false
            self.wordSuggestionFrame = nil

            if self.wordFields.count > count {
                for field in self.wordFields[count...] {
                    field.removeFromSuperview()
                }
                self.wordFields.removeSubrange(count...)
            }

            while self.wordFields.count < count {
                let index = self.wordFields.count
                let field = WordFieldView(
                    index: index,
                    displayNumber: displayNumbers[index],
                    wordCount: count
                )
                field.textChanged = { [weak self] index, text in
                    self?.wordTextChanged(index: index, text: text)
                }
                field.editingChanged = { [weak self] index, isEditing in
                    self?.wordEditingChanged(index: index, isEditing: isEditing)
                }
                field.shouldBeginEditing = { [weak self] index in
                    return self?.shouldBeginEditingWord(at: index) ?? true
                }
                field.returnPressed = { [weak self] index in
                    self?.handleReturn(from: index)
                }
                field.pasteWords = { [weak self] index, words in
                    return self?.insertWords(words, from: index) ?? false
                }
                field.emptyBackspace = { [weak self] index in
                    self?.moveFocusBackward(from: index)
                }
                field.pastePressed = { [weak self] in
                    self?.pasteRecoveryPhrase()
                }
                self.wordFields.append(field)
            }

            for index in self.wordFields.indices {
                let field = self.wordFields[index]
                field.updateConfiguration(
                    displayNumber: displayNumbers[index],
                    wordCount: count
                )
                if field.textField.text != self.words[index] {
                    field.setText(self.words[index])
                }
            }
            if !self.isVerificationMode {
                for index in self.words.indices where !self.words[index].isEmpty {
                    self.validateWord(at: index)
                }
            }
            if self.activeWordIndex != nil {
                self.updateWordSuggestions()
            }
        }

        private func setWordCount(_ count: Int) {
            guard (count == 12 || count == 24), count != self.words.count else {
                return
            }
            self.setupWordInputFields(
                displayNumbers: Array(1 ... count),
                preserving: self.words,
                preservingFocus: true
            )
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.flowSession?.invalidate()
            if let prepared = self.activePreparedRecoveryPhraseImport,
               let walletContext = self.component?.walletContext {
                let _ = walletContext.discardRecoveryPhraseImport(prepared).start()
            }
            NotificationCenter.default.removeObserver(self)
            self.titleTransformContainer.removeFromSuperview()
            self.operationDisposable.dispose()
            self.discardDisposable.dispose()
        }

        fileprivate func endWalletFlow() {
            self.flowGeneration &+= 1
            self.operationDisposable.set(nil)
            self.flowSession?.invalidate()
            self.flowSession = nil
            if let prepared = self.activePreparedRecoveryPhraseImport {
                self.discardPreparedRecoveryPhraseImport(prepared)
            }
        }

        private func walletFlowAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if let session = self.flowSession, session.isValid {
                return .single(session)
            }
            let generation = self.flowGeneration
            return component.walletContext.beginWalletFlow(reason: "importWallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.flowGeneration == generation else { session.invalidate(); return .fail(.authorizationCancelled) }
                self.flowSession?.invalidate()
                self.flowSession = session
                return .single(session)
            }
        }

        @objc private func pasteboardDidChange(_ notification: Notification) {
            let hasPasteboardText = UIPasteboard.general.hasStrings
            guard self.hasPasteboardText != hasPasteboardText else {
                return
            }
            self.hasPasteboardText = hasPasteboardText
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView else {
                return
            }
            self.updateScrolling(transition: .immediate)
        }

        private var isActionEnabled: Bool {
            guard let component = self.component else {
                return false
            }
            switch component.mode {
            case .importWallet, .enterRecoveryPhrase:
                return self.words.allSatisfy { word in
                    return !word.isEmpty && component.walletContext.isMnemonicWord(word)
                }
            case .verify:
                return self.words.allSatisfy { !$0.isEmpty }
            }
        }

        private var isVerificationMode: Bool {
            guard let component = self.component else {
                return false
            }
            if case .verify = component.mode {
                return true
            } else {
                return false
            }
        }

        private func updateImportPhraseValidity() {
            guard let component = self.component else {
                self.isImportPhraseValid = false
                return
            }
            self.isImportPhraseValid = component.walletContext.isMnemonicValid(words: self.words)
        }

        private func updateWordSuggestions() {
            guard !self.isVerificationMode,
                  let component = self.component,
                  let activeWordIndex,
                  self.words.indices.contains(activeWordIndex),
                  self.words[activeWordIndex].count >= 2 else {
                self.wordSuggestions = []
                self.hasInvalidWordSuggestion = false
                return
            }
            let word = self.words[activeWordIndex]
            let suggestions = component.walletContext.mnemonicWordSuggestions(
                for: word,
                limit: 3
            )
            if suggestions.isEmpty && !component.walletContext.isMnemonicWord(word) {
                self.wordSuggestions = ["Invalid word"]
                self.hasInvalidWordSuggestion = true
                self.invalidWordIndices.insert(activeWordIndex)
            } else if suggestions.count == 1, suggestions[0] == word {
                self.wordSuggestions = []
                self.hasInvalidWordSuggestion = false
            } else {
                self.wordSuggestions = suggestions
                self.hasInvalidWordSuggestion = false
            }
        }

        private func isInvalidWord(at index: Int) -> Bool {
            guard !self.isVerificationMode,
                  let component = self.component,
                  self.words.indices.contains(index) else {
                return false
            }
            let word = self.words[index]
            return !word.isEmpty && !component.walletContext.isMnemonicWord(word)
        }

        private func rejectInvalidWord(at index: Int) {
            guard self.wordFields.indices.contains(index) else {
                return
            }
            self.invalidWordIndices.insert(index)
            self.updateWordSuggestions()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.wordFields[index].layer.addShakeAnimation()
            HapticFeedback().error()
        }

        private func shouldBeginEditingWord(at index: Int) -> Bool {
            guard let activeWordIndex = self.activeWordIndex,
                  activeWordIndex != index,
                  self.isInvalidWord(at: activeWordIndex) else {
                return true
            }
            self.rejectInvalidWord(at: activeWordIndex)
            return false
        }

        private func selectSuggestedWord(_ word: String, at index: Int) {
            guard self.activeWordIndex == index,
                  self.words.indices.contains(index),
                  self.wordFields.indices.contains(index) else {
                return
            }
            let word = self.normalizeWord(word)
            self.words[index] = word
            self.wordFields[index].setText(word)
            self.invalidWordIndices.remove(index)
            self.wordSuggestions = []
            self.hasInvalidWordSuggestion = false
            self.updateImportPhraseValidity()
            self.componentState?.updated(transition: .immediate)
            self.advanceFocus(from: index)
        }

        private func validateWord(at index: Int) {
            guard !self.isVerificationMode,
                  let component = self.component,
                  self.words.indices.contains(index) else {
                return
            }
            let word = self.words[index]
            if word.isEmpty || component.walletContext.isMnemonicWord(word) {
                self.invalidWordIndices.remove(index)
            } else {
                self.invalidWordIndices.insert(index)
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func wordTextChanged(index: Int, text: String) {
            guard self.words.indices.contains(index) else {
                return
            }
            let previousWord = self.words[index]
            let word = self.normalizeWord(text)
            self.words[index] = word
            self.updateImportPhraseValidity()
            self.invalidWordIndices.remove(index)
            self.updateWordSuggestions()
            if word.count > previousWord.count && self.hasInvalidWordSuggestion {
                self.invalidWordSuggestionPulseId += 1
                HapticFeedback().impact()
            }
            self.componentState?.updated(transition: .immediate)
        }

        private func wordEditingChanged(index: Int, isEditing: Bool) {
            guard self.words.indices.contains(index) else {
                return
            }

            if isEditing {
                self.activeWordIndex = index
                self.invalidWordIndices.remove(index)
                self.updateWordSuggestions()
            } else {
                if self.activeWordIndex == index {
                    self.activeWordIndex = nil
                }
                let normalizedWord = self.normalizeWord(self.wordFields[index].textField.text ?? "")
                self.words[index] = normalizedWord
                self.wordFields[index].setText(normalizedWord)
                self.updateImportPhraseValidity()
                self.updateWordSuggestions()
                self.validateWord(at: index)
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
        }

        private func handleReturn(from index: Int) {
            if self.activeWordIndex == index,
               !self.hasInvalidWordSuggestion,
               let firstSuggestion = self.wordSuggestions.first {
                self.selectSuggestedWord(firstSuggestion, at: index)
                return
            }
            if self.isInvalidWord(at: index) {
                self.rejectInvalidWord(at: index)
                return
            }
            self.advanceFocus(from: index)
        }

        private func advanceFocus(from index: Int) {
            guard self.wordFields.indices.contains(index) else {
                return
            }
            let currentWord = self.normalizeWord(self.wordFields[index].textField.text ?? "")
            guard !currentWord.isEmpty else {
                self.wordFields[index].layer.addShakeAnimation()
                HapticFeedback().error()
                return
            }
            guard !self.isInvalidWord(at: index) else {
                self.rejectInvalidWord(at: index)
                return
            }

            if index + 1 < self.wordFields.count {
                let _ = self.wordFields[index + 1].textField.becomeFirstResponder()
            } else {
                self.wordFields[index].textField.resignFirstResponder()
            }
        }

        private func moveFocusBackward(from index: Int) {
            guard index > 0 else {
                return
            }
            let _ = self.wordFields[index - 1].textField.becomeFirstResponder()
        }

        private func insertWords(_ sourceWords: [String], from index: Int) -> Bool {
            let normalizedWords = sourceWords
                .map(self.normalizeWord)
                .filter { !$0.isEmpty }
            guard !normalizedWords.isEmpty else {
                return false
            }

            if self.isVerificationMode {
                guard self.words.indices.contains(index) else {
                    return false
                }
                let insertedWords = Array(normalizedWords.prefix(self.words.count - index))
                guard !insertedWords.isEmpty else {
                    return false
                }
                for offset in insertedWords.indices {
                    let targetIndex = index + offset
                    self.words[targetIndex] = insertedWords[offset]
                    self.wordFields[targetIndex].setText(insertedWords[offset])
                    self.invalidWordIndices.remove(targetIndex)
                }
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))

                let nextIndex = index + insertedWords.count
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    if nextIndex < self.wordFields.count {
                        let _ = self.wordFields[nextIndex].textField.becomeFirstResponder()
                    } else {
                        self.wordFields.last?.textField.resignFirstResponder()
                    }
                }
                return true
            }

            if normalizedWords.count > 1 {
                guard normalizedWords.count == 12 || normalizedWords.count == 24 else {
                    self.presentInvalidPhraseLength(count: normalizedWords.count)
                    return true
                }
                if normalizedWords.count != self.words.count {
                    self.setupWordInputFields(
                        displayNumbers: Array(1 ... normalizedWords.count),
                        preserving: []
                    )
                }
            }
            let startIndex = normalizedWords.count > 1 ? 0 : index
            guard self.words.indices.contains(startIndex), normalizedWords.count <= self.words.count - startIndex else {
                return false
            }
            for offset in normalizedWords.indices {
                let targetIndex = startIndex + offset
                let word = normalizedWords[offset]
                self.words[targetIndex] = word
                self.wordFields[targetIndex].setText(word)
                self.invalidWordIndices.remove(targetIndex)
            }

            self.wordSuggestions = []
            self.hasInvalidWordSuggestion = false
            self.updateImportPhraseValidity()
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if normalizedWords.count > 1 {
                if self.isImportPhraseValid {
                    self.invalidWordIndices.removeAll()
                } else {
                    for index in self.words.indices {
                        self.validateWord(at: index)
                    }
                }
            } else {
                self.validateWord(at: startIndex)
            }

            let nextIndex = startIndex + normalizedWords.count
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if nextIndex < self.wordFields.count {
                    let _ = self.wordFields[nextIndex].textField.becomeFirstResponder()
                } else {
                    self.wordFields.last?.textField.resignFirstResponder()
                }
            }
            return true
        }

        private func pasteRecoveryPhrase() {
            guard !self.isVerificationMode, let component = self.component else {
                return
            }
            guard let text = UIPasteboard.general.string else {
                self.hasPasteboardText = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                return
            }

            let words = text
                .split(whereSeparator: { $0.isWhitespace })
                .map { self.normalizeWord(String($0)) }
                .filter { !$0.isEmpty }
            guard words.count == 12 || words.count == 24 else {
                self.presentInvalidPhraseLength(count: words.count)
                return
            }
            guard component.walletContext.isMnemonicValid(words: words) else {
                self.presentInvalidMnemonic()
                return
            }

            for field in self.wordFields where field.textField.isFirstResponder {
                field.textField.resignFirstResponder()
            }
            self.setupWordInputFields(
                displayNumbers: Array(1 ... words.count),
                preserving: words
            )
            self.scrollToBottomAfterPaste = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func presentInvalidPhraseLength(count: Int) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            HapticFeedback().error()
            if let activeWordIndex, self.wordFields.indices.contains(activeWordIndex) {
                self.wordFields[activeWordIndex].layer.addShakeAnimation()
            }
            //TODO:localize
            controller.present(textAlertController(
                context: component.context,
                title: "Invalid Secret Phrase",
                text: "A secret phrase must contain exactly 12 or 24 words. The pasted phrase contains \(count).",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func presentInvalidMnemonic() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            HapticFeedback().error()
            //TODO:localize
            controller.present(textAlertController(
                context: component.context,
                title: "Invalid Secret Phrase",
                text: "Check the word order.\n\nOnly a secret phrase created in Telegram can be imported here.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func normalizeWord(_ word: String) -> String {
            return word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        private func dismiss() {
            self.environment?.controller()?.dismiss()
        }

        private func continueVerification() {
            guard let component = self.component,
                  case let .verify(phraseWords, _) = component.mode,
                  component.verificationIndices.count == self.words.count,
                  !self.didCompleteVerification else {
                return
            }

            var mismatchedIndices: [Int] = []
            for fieldIndex in self.words.indices {
                let phraseIndex = component.verificationIndices[fieldIndex]
                guard phraseWords.indices.contains(phraseIndex) else {
                    mismatchedIndices.append(fieldIndex)
                    continue
                }
                if self.normalizeWord(self.words[fieldIndex]) != self.normalizeWord(phraseWords[phraseIndex]) {
                    mismatchedIndices.append(fieldIndex)
                }
            }

            if mismatchedIndices.isEmpty {
                self.didCompleteVerification = true
                component.completion?()
                return
            }

            HapticFeedback().error()
            guard let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            let alertTitle = "Incorrect words!"
            //TODO:localize
            let alertText = "The secret words you have entered do not match the ones in the list."
            //TODO:localize
            let tryAgainTitle = "Try Again"
            //TODO:localize
            let viewWordsTitle = "View Words"
            controller.present(textAlertController(
                context: component.context,
                title: alertTitle,
                text: alertText,
                actions: [
                    TextAlertAction(type: .genericAction, title: viewWordsTitle, action: { [weak self] in
                        self?.dismiss()
                    }),
                    TextAlertAction(type: .defaultAction, title: tryAgainTitle, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        for index in mismatchedIndices where self.words.indices.contains(index) {
                            self.words[index] = ""
                            self.wordFields[index].setText("")
                        }
                        self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                        if let firstIndex = mismatchedIndices.first {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                guard let self, self.wordFields.indices.contains(firstIndex) else {
                                    return
                                }
                                let _ = self.wordFields[firstIndex].textField.becomeFirstResponder()
                            }
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func importWallet() {
            guard !self.isImporting else {
                return
            }
            guard self.isImportPhraseValid else {
                self.presentInvalidMnemonic()
                return
            }
            self.performImport(words: self.words)
        }

        private func performImport(words: [String]) {
            guard let component = self.component else {
                return
            }
            if component.mode == .enterRecoveryPhrase {
                if let prepared = self.activePreparedRecoveryPhraseImport, self.preparedImportWords == words {
                    switch prepared.disposition {
                    case .currentWallet: self.completeRecoveryPhraseImport(prepared, password: nil)
                    case .replacement: self.authorizeRecoveryPhraseReplacement(prepared)
                    }
                    return
                }
                self.prepareRecoveryPhraseImport(words: words)
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard let controller = self.environment?.controller() else {
                return
            }
            self.operationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization() |> mapToSignal { session in
                        component.walletContext.importWallet(words: words, password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    self?.endWalletFlow()
                    if let completion = component.completion {
                        completion()
                    } else {
                        self?.dismiss()
                    }
                },
                failed: { [weak self] error in
                    self?.finishImportWithError(error: error)
                }
            ))
        }

        private func prepareRecoveryPhraseImport(words: [String]) {
            guard let component = self.component else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            let cleanup: Signal<Void, WalletContext.WalletError>
            if let previous = self.activePreparedRecoveryPhraseImport {
                cleanup = component.walletContext.discardRecoveryPhraseImport(previous)
                self.activePreparedRecoveryPhraseImport = nil
                self.preparedImportWords = nil
            } else {
                cleanup = .single(())
            }
            self.operationDisposable.set((cleanup
            |> mapToSignal { [weak self] _ -> Signal<PasscodeSession, WalletContext.WalletError> in
                self?.walletFlowAuthorization() ?? .fail(.authorizationCancelled)
            }
            |> mapToSignal { session in
                component.walletContext.prepareRecoveryPhraseImport(words: words, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self else {
                    return
                }
                self.activePreparedRecoveryPhraseImport = prepared
                self.preparedImportWords = words
                switch prepared.disposition {
                case .currentWallet:
                    self.completeRecoveryPhraseImport(prepared, password: nil)
                case .replacement:
                    self.isImporting = false
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self.presentReplacementConfirmation(prepared)
                }
            }, error: { [weak self] error in
                self?.finishImportWithError(error: error)
            }))
        }

        private func presentReplacementConfirmation(_ prepared: WalletContext.PreparedRecoveryPhraseImport) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Replace Wallet",
                text: "This secret phrase belongs to a different wallet. Replacing the current wallet will remove access to it on this device. Make sure you’ve saved its secret phrase before continuing.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                        self?.endWalletFlow()
                    }),
                    TextAlertAction(type: .destructiveAction, title: "Replace", action: { [weak self] in
                        self?.authorizeRecoveryPhraseReplacement(prepared)
                    })
                ],
                dismissOnOutsideTap: false
            ), in: .window(.root))
        }

        private func authorizeRecoveryPhraseReplacement(_ prepared: WalletContext.PreparedRecoveryPhraseImport) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.operationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<WalletContext.WalletInfo, WalletContext.WalletError> in
                    guard let self else { return .fail(.authorizationCancelled) }
                    return self.walletFlowAuthorization() |> mapToSignal { session in
                        component.walletContext.completeRecoveryPhraseImport(prepared, password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    self?.finishRecoveryPhraseImport()
                },
                failed: { [weak self] error in
                    if error == .authorizationCancelled {
                        self?.discardPreparedRecoveryPhraseImport(prepared)
                    }
                    self?.finishImportWithError(error: error)
                }
            ))
        }

        private func completeRecoveryPhraseImport(
            _ prepared: WalletContext.PreparedRecoveryPhraseImport,
            password: String?
        ) {
            guard let component = self.component else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.operationDisposable.set((self.walletFlowAuthorization()
            |> mapToSignal { session in
                component.walletContext.completeRecoveryPhraseImport(prepared, password: password, session: session)
            }
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                self?.finishRecoveryPhraseImport()
            }, error: { [weak self] error in
                self?.finishImportWithError(error: error)
            }))
        }

        private func discardPreparedRecoveryPhraseImport(_ prepared: WalletContext.PreparedRecoveryPhraseImport) {
            guard let component = self.component else {
                return
            }
            self.activePreparedRecoveryPhraseImport = nil
            self.preparedImportWords = nil
            self.discardDisposable.set(component.walletContext.discardRecoveryPhraseImport(prepared).start())
        }

        private func finishRecoveryPhraseImport() {
            guard let component = self.component else {
                return
            }
            self.activePreparedRecoveryPhraseImport = nil
            self.preparedImportWords = nil
            self.endWalletFlow()
            self.isImporting = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if let completion = component.completion {
                completion()
            } else {
                self.dismiss()
            }
        }

        private func finishImportWithError(error: WalletContext.WalletError) {
            self.isImporting = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard error != .authorizationCancelled else {
                self.endWalletFlow()
                return
            }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Import Wallet",
                text: message?.text ?? "Check the secret phrase and network connection, then try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment else {
                return
            }

            let titleCenterY = environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) * 0.5 + 3.0
            let titleTransformDistance: CGFloat = 20.0
            let titleY = max(
                titleCenterY,
                self.titleTransformContainer.center.y - self.scrollView.contentOffset.y
            )
            transition.setSublayerTransform(
                view: self.titleTransformContainer,
                transform: CATransform3DMakeTranslation(
                    0.0,
                    titleY - self.titleTransformContainer.center.y,
                    0.0
                )
            )

            let titleYDistance = titleY - titleCenterY
            let titleTransformFraction = 1.0 - max(
                0.0,
                min(1.0, titleYDistance / titleTransformDistance)
            )
            let titleMinScale: CGFloat = 17.0 / 28.0
            let titleScale = 1.0 * (1.0 - titleTransformFraction)
                + titleMinScale * titleTransformFraction
            if let navigationTitleView = self.navigationTitle.view {
                transition.setScale(view: navigationTitleView, scale: titleScale)
            }

            if let controller = environment.controller(),
               let navigationBar = controller.navigationBar,
               let edgeEffectView = navigationBar.edgeEffectView {
                let alphaDistance = max(
                    1.0,
                    self.titleTransformContainer.center.y - titleCenterY
                )
                let alpha = max(
                    0.0,
                    min(1.0, self.scrollView.contentOffset.y / alphaDistance)
                )
                transition.setAlpha(view: edgeEffectView, alpha: alpha)
            }
        }

        private func removeWordSuggestionView() {
            guard let wordSuggestionView = self.wordSuggestionView else {
                self.wordSuggestionFrame = nil
                return
            }
            self.wordSuggestionView = nil
            self.wordSuggestionFrame = nil
            wordSuggestionView.isUserInteractionEnabled = false
            wordSuggestionView.alpha = 0.0
            wordSuggestionView.layer.animateAlpha(
                from: 1.0,
                to: 0.0,
                duration: 0.25,
                removeOnCompletion: false,
                completion: { [weak wordSuggestionView] _ in
                    wordSuggestionView?.removeFromSuperview()
                }
            )
        }

        private func ensureActiveFieldVisible(
            availableSize: CGSize,
            navigationHeight: CGFloat,
            inputHeight: CGFloat
        ) {
            guard inputHeight > 0.0,
                  let activeWordIndex,
                  self.wordFields.indices.contains(activeWordIndex) else {
                return
            }

            var targetFrame = self.wordFields[activeWordIndex].frame
            if activeWordIndex >= max(0, self.wordFields.count - 3), let buttonView = self.button.view {
                targetFrame = targetFrame.union(buttonView.frame)
            }
            if let wordSuggestionFrame = self.wordSuggestionFrame {
                targetFrame = targetFrame.union(wordSuggestionFrame)
            }
            targetFrame = targetFrame.insetBy(dx: 0.0, dy: -12.0)

            let visibleTop = self.scrollView.contentOffset.y + navigationHeight
            let visibleBottom = self.scrollView.contentOffset.y
                + availableSize.height - inputHeight - 12.0
            var targetOffsetY = self.scrollView.contentOffset.y
            if targetFrame.maxY > visibleBottom {
                targetOffsetY += targetFrame.maxY - visibleBottom
            } else if targetFrame.minY < visibleTop {
                targetOffsetY -= visibleTop - targetFrame.minY
            }

            let maximumOffsetY = max(
                0.0,
                self.scrollView.contentSize.height
                    + self.scrollView.contentInset.bottom
                    - self.scrollView.bounds.height
            )
            targetOffsetY = max(0.0, min(maximumOffsetY, targetOffsetY))
            if abs(targetOffsetY - self.scrollView.contentOffset.y) > UIScreenPixel {
                self.scrollView.setContentOffset(
                    CGPoint(x: 0.0, y: targetOffsetY),
                    animated: true
                )
            }
        }

        func update(
            component: WalletImportScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            let previousMode = self.component?.mode
            self.environment = environment
            self.component = component
            self.componentState = state

            if previousMode != component.mode {
                self.didPlayAnimation = false
                self.didRequestInitialFocus = false
                self.didCompleteVerification = false
                switch component.mode {
                case .importWallet, .enterRecoveryPhrase:
                    self.setupWordInputFields(displayNumbers: Array(1 ... 12), preserving: [])
                case .verify:
                    self.setupWordInputFields(
                        displayNumbers: component.verificationIndices.map { $0 + 1 },
                        preserving: []
                    )
                }
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.plainBackgroundColor

            let animationName: String
            let titleText: String
            let bodyContent: BalancedTextComponent.TextContent
            let buttonTitle: String
            let isVerificationMode: Bool
            switch component.mode {
            case .importWallet:
                isVerificationMode = false
                animationName = "WalletWordList"
                //TODO:localize
                titleText = "Import Wallet"
                //TODO:localize
                let bodyText = "Enter the 12- or 24-word recovery phrase from another wallet you own."
                bodyContent = .plain(NSAttributedString(
                    string: bodyText,
                    font: Font.regular(16.0),
                    textColor: theme.list.itemPrimaryTextColor
                ))
                //TODO:localize
                buttonTitle = "Import"
            case .enterRecoveryPhrase:
                isVerificationMode = false
                animationName = "WalletWordList"
                //TODO:localize
                titleText = "Enter Recovery Phrase"
                //TODO:localize
                let bodyText = "Enter the 12- or 24-word recovery phrase for this wallet."
                bodyContent = .plain(NSAttributedString(
                    string: bodyText,
                    font: Font.regular(16.0),
                    textColor: theme.list.itemPrimaryTextColor
                ))
                //TODO:localize
                buttonTitle = "Done"
            case .verify:
                isVerificationMode = true
                animationName = "WalletWordCheck"
                //TODO:localize
                titleText = "Test Time"
                //TODO:localize
                let bodyText = "Make sure you wrote your recovery phrase down correctly.\nEnter words **%1$@**, **%2$@** and **%3$@**."
                let displayedIndices = component.verificationIndices.map { String($0 + 1) }
                let formattedBodyText: String
                if displayedIndices.count == 3 {
                    formattedBodyText = String(
                        format: bodyText,
                        displayedIndices[0],
                        displayedIndices[1],
                        displayedIndices[2]
                    )
                } else {
                    formattedBodyText = bodyText
                }
                bodyContent = .markdown(
                    text: formattedBodyText,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(
                            font: Font.regular(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        bold: MarkdownAttributeSet(
                            font: Font.semibold(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        link: MarkdownAttributeSet(
                            font: Font.regular(16.0),
                            textColor: theme.list.itemPrimaryTextColor
                        ),
                        linkAttribute: { _ in nil }
                    )
                )
                //TODO:localize
                buttonTitle = "Continue"
            }

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )

            let contentSideInset = 48.0 + max(
                environment.safeInsets.left,
                environment.safeInsets.right
            )
            let contentWidth = max(
                0.0,
                min(430.0, availableSize.width - contentSideInset * 2.0)
            )
            var contentHeight = environment.navigationHeight - 28.0

            self.animation.parentState = state
            let animationSize = CGSize(width: 108.0, height: 108.0)
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: animationName),
                    startingPosition: .begin,
                    size: animationSize,
                    loop: false,
                    playOnce: self.playAnimation,
                    lottieSettings: component.context.lottieRenderingSettings
                )),
                environment: {},
                containerSize: animationSize
            )
            if let animationView = self.animation.view {
                if animationView.superview == nil {
                    self.scrollView.addSubview(animationView)
                }
                transition.setFrame(
                    view: animationView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - animationSize.width) * 0.5),
                        y: contentHeight,
                        width: animationSize.width,
                        height: animationSize.height
                    )
                )
            }
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playAnimation.invoke(Void())
            }
            contentHeight += animationSize.height + 8.0

            self.navigationTitle.parentState = state
            let titleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: Font.bold(28.0),
                        textColor: theme.rootController.navigationBar.primaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 100.0)
            )
            let titleFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5),
                y: contentHeight,
                width: titleSize.width,
                height: titleSize.height
            )
            let overlaySuperview: UIView
            if let controller = environment.controller(),
               let navigationBar = controller.navigationBar,
               let navigationBarSuperview = navigationBar.view.superview {
                overlaySuperview = navigationBarSuperview
            } else {
                overlaySuperview = self
            }
            if self.titleTransformContainer.superview !== overlaySuperview {
                self.titleTransformContainer.removeFromSuperview()
                if let controller = environment.controller(),
                   let navigationBar = controller.navigationBar,
                   overlaySuperview === navigationBar.view.superview {
                    overlaySuperview.insertSubview(
                        self.titleTransformContainer,
                        aboveSubview: navigationBar.view
                    )
                } else {
                    overlaySuperview.addSubview(self.titleTransformContainer)
                }
            }
            if let titleView = self.navigationTitle.view {
                if titleView.superview !== self.titleTransformContainer {
                    titleView.removeFromSuperview()
                    self.titleTransformContainer.addSubview(titleView)
                }
                transition.setPosition(
                    view: self.titleTransformContainer,
                    position: titleFrame.center
                )
                transition.setBounds(
                    view: self.titleTransformContainer,
                    bounds: CGRect(origin: CGPoint(), size: titleFrame.size)
                )
                transition.setPosition(
                    view: titleView,
                    position: CGPoint(
                        x: titleFrame.width * 0.5,
                        y: titleFrame.height * 0.5
                    )
                )
                transition.setBounds(
                    view: titleView,
                    bounds: CGRect(origin: CGPoint(), size: titleFrame.size)
                )
            }
            contentHeight += titleSize.height + 5.0

            self.body.parentState = state
            let bodySize = self.body.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: bodyContent,
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: contentWidth, height: 1000.0)
            )
            if let bodyView = self.body.view {
                if bodyView.superview == nil {
                    self.scrollView.addSubview(bodyView)
                }
                transition.setFrame(
                    view: bodyView,
                    frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - bodySize.width) * 0.5),
                        y: contentHeight,
                        width: bodySize.width,
                        height: bodySize.height
                    )
                )
            }
            contentHeight += bodySize.height + 14.0

            let fieldWidth = max(
                0.0,
                min(330.0, availableSize.width - contentSideInset * 2.0)
            )
            let fieldX = floorToScreenPixels((availableSize.width - fieldWidth) * 0.5)

            if isVerificationMode {
                self.wordCountControl.view?.removeFromSuperview()
            } else {
                self.wordCountControl.parentState = state

                let segmentedTheme = SegmentControlComponent.Theme(
                    backgroundColor: theme.list.itemInputField.backgroundColor,
                    legacyBackgroundColor: theme.list.itemInputField.backgroundColor,
                    foregroundColor: theme.overallDarkAppearance ? theme.actionSheet.opaqueItemBackgroundColor : theme.list.plainBackgroundColor,
                    textColor: theme.rootController.navigationBar.segmentedTextColor,
                    dividerColor: theme.rootController.navigationBar.segmentedDividerColor
                )

                //TODO:localize
                let wordCountControlSize = self.wordCountControl.update(
                    transition: transition,
                    component: AnyComponent(SegmentControlComponent(
                        theme: segmentedTheme,
                        items: [
                            SegmentControlComponent.Item(id: AnyHashable(12), title: "12 words"),
                            SegmentControlComponent.Item(id: AnyHashable(24), title: "24 words")
                        ],
                        selectedId: AnyHashable(self.words.count),
                        fillWidth: false,
                        action: { [weak self] id in
                            guard let count = id.base as? Int else {
                                return
                            }
                            self?.setWordCount(count)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: fieldWidth, height: 36.0)
                )
                if let wordCountControlView = self.wordCountControl.view {
                    if wordCountControlView.superview == nil {
                        self.scrollView.addSubview(wordCountControlView)
                    }
                    transition.setFrame(
                        view: wordCountControlView,
                        frame: CGRect(
                            x: floor((availableSize.width - wordCountControlSize.width) / 2.0),
                            y: contentHeight,
                            width: wordCountControlSize.width,
                            height: wordCountControlSize.height
                        )
                    )
                }
                contentHeight += wordCountControlSize.height + 32.0
            }

            let fieldHeight: CGFloat = 52.0
            let fieldSpacing: CGFloat = 14.0
            let displaysPasteButton = !isVerificationMode
                && self.hasPasteboardText
                && self.words.allSatisfy { $0.isEmpty }
            for index in self.wordFields.indices {
                var transition = transition
                let field = self.wordFields[index]
                if field.superview == nil {
                    transition = .immediate
                    self.scrollView.addSubview(field)
                }
                let fieldFrame = CGRect(
                    x: fieldX,
                    y: contentHeight,
                    width: fieldWidth,
                    height: fieldHeight
                )
                transition.setFrame(view: field, frame: fieldFrame)
                field.update(
                    theme: theme,
                    isInvalid: false,
                    displaysPasteButton: index == 0 && displaysPasteButton,
                    size: fieldFrame.size
                )
                contentHeight += fieldHeight
                if index != self.wordFields.count - 1 {
                    contentHeight += fieldSpacing
                }
            }
            if !self.didRequestInitialFocus {
                self.didRequestInitialFocus = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    let _ = self?.wordFields.first?.textField.becomeFirstResponder()
                }
            }
            contentHeight += 24.0

            let isButtonEnabled = self.isActionEnabled
            self.button.parentState = state
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(Text(
                            text: buttonTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: isButtonEnabled,
                    displaysProgress: !isVerificationMode && self.isImporting,
                    action: { [weak self] in
                        guard let self, self.isActionEnabled else {
                            return
                        }
                        if self.isVerificationMode {
                            self.continueVerification()
                        } else {
                            self.importWallet()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fieldWidth, height: 52.0)
            )
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.scrollView.addSubview(buttonView)
                }
                transition.setFrame(
                    view: buttonView,
                    frame: CGRect(
                        x: fieldX,
                        y: contentHeight,
                        width: buttonSize.width,
                        height: buttonSize.height
                    )
                )
            }
            contentHeight += buttonSize.height + environment.safeInsets.bottom + 24.0

            if !isVerificationMode,
               !self.wordSuggestions.isEmpty,
               let activeWordIndex = self.activeWordIndex,
               self.wordFields.indices.contains(activeWordIndex) {
                let wordSuggestionView: ComponentHostView<Empty>
                let animateIn: Bool
                if let current = self.wordSuggestionView {
                    wordSuggestionView = current
                    animateIn = false
                } else {
                    wordSuggestionView = ComponentHostView<Empty>()
                    self.wordSuggestionView = wordSuggestionView
                    self.scrollView.addSubview(wordSuggestionView)
                    animateIn = true
                }
                let suggestionTransition: ComponentTransition = animateIn
                    ? .immediate
                    : .easeInOut(duration: 0.2)

                let suggestionIndex = activeWordIndex
                let suggestionSize = wordSuggestionView.update(
                    transition: suggestionTransition,
                    component: AnyComponent(WalletWordSuggestionsComponent(
                        fieldIndex: activeWordIndex,
                        query: self.words[activeWordIndex],
                        words: self.wordSuggestions,
                        isInteractive: !self.hasInvalidWordSuggestion,
                        pulseId: self.hasInvalidWordSuggestion ? self.invalidWordSuggestionPulseId : 0,
                        action: { [weak self] word in
                            self?.selectSuggestedWord(word, at: suggestionIndex)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(
                        width: fieldWidth,
                        height: WalletWordSuggestionsComponent.height
                    )
                )
                let fieldFrame = self.wordFields[activeWordIndex].frame
                let suggestionX = floor(min(
                    fieldFrame.maxX - suggestionSize.width,
                    max(fieldFrame.minX, fieldFrame.midX - suggestionSize.width / 2.0)
                ))
                let suggestionFrame = CGRect(
                    x: suggestionX,
                    y: fieldFrame.maxY - WalletWordSuggestionsComponent.notchHeight,
                    width: suggestionSize.width,
                    height: suggestionSize.height
                )
                suggestionTransition.setFrame(view: wordSuggestionView, frame: suggestionFrame)
                self.wordSuggestionFrame = suggestionFrame
                self.scrollView.bringSubviewToFront(wordSuggestionView)
                if let componentView = wordSuggestionView.componentView as? WalletWordSuggestionsComponent.View {
                    componentView.adjustBackground(
                        relativePositionX: fieldFrame.midX - suggestionFrame.minX,
                        transition: suggestionTransition
                    )
                }
                if animateIn {
                    wordSuggestionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                }
            } else {
                self.removeWordSuggestionView()
            }

            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }

            let bottomContentInset = max(
                environment.safeInsets.bottom + 16.0,
                environment.inputHeight + 16.0
            )
            let contentInset = UIEdgeInsets(
                top: 0.0,
                left: 0.0,
                bottom: bottomContentInset,
                right: 0.0
            )
            if self.scrollView.contentInset != contentInset {
                self.scrollView.contentInset = contentInset
            }
            let scrollIndicatorInsets = UIEdgeInsets(
                top: environment.navigationHeight,
                left: 0.0,
                bottom: bottomContentInset,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollIndicatorInsets
            }

            if self.scrollToBottomAfterPaste && environment.inputHeight == 0.0 {
                self.scrollToBottomAfterPaste = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    let maximumOffsetY = max(
                        0.0,
                        self.scrollView.contentSize.height
                            + self.scrollView.contentInset.bottom
                            - self.scrollView.bounds.height
                    )
                    self.scrollView.setContentOffset(
                        CGPoint(x: 0.0, y: maximumOffsetY),
                        animated: true
                    )
                }
            }

            self.updateScrolling(transition: transition)
            self.ensureActiveFieldVisible(
                availableSize: availableSize,
                navigationHeight: environment.navigationHeight,
                inputHeight: environment.inputHeight
            )

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

public final class WalletImportScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        mode: WalletImportScreenMode,
        completion: (() -> Void)?
    ) {
        let verificationIndices: [Int]
        switch mode {
        case .importWallet, .enterRecoveryPhrase:
            verificationIndices = []
        case let .verify(words, keyRotation):
            precondition(words.count >= 3)
            if keyRotation {
                precondition(words.count == 24)
                let anchorIndex = Int.random(in: 0 ..< 12)
                let signingIndices = Array((12 ..< 24).shuffled().prefix(2))
                verificationIndices = ([anchorIndex] + signingIndices).sorted()
            } else {
                verificationIndices = Array(words.indices.shuffled().prefix(3)).sorted()
            }
        }

        super.init(
            context: context,
            component: WalletImportScreenComponent(
                context: context,
                walletContext: walletContext,
                mode: mode,
                verificationIndices: verificationIndices,
                completion: completion
            ),
            navigationBarAppearance: .default,
            statusBarStyle: .default,
            theme: .default
        )

        //TODO:localize
        let backTitle = "Back"
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(
            title: backTitle,
            style: .plain,
            target: nil,
            action: nil
        )

        self.scrollToTop = { [weak self] in
            guard let self,
                  let componentView = self.node.hostView.componentView as? WalletImportScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            (self.node.hostView.componentView as? WalletImportScreenComponent.View)?.endWalletFlow()
        }
    }
}
