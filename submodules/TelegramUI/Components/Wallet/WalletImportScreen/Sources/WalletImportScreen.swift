import Foundation
import UIKit
import Display
import AccountContext
import Markdown
import ComponentFlow
import TelegramPresentationData
import PresentationDataUtils
import ViewControllerComponent
import MultilineTextComponent
import LottieComponent
import ButtonComponent
import SegmentControlComponent
import WalletContext
import SwiftSignalKit

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

            private let numberLabel = UILabel()
            let textField = WordTextField()

            var textChanged: ((Int, String) -> Void)?
            var editingChanged: ((Int, Bool) -> Void)?
            var returnPressed: ((Int) -> Void)?
            var pasteWords: ((Int, [String]) -> Bool)?
            var emptyBackspace: ((Int) -> Void)?

            init(index: Int, displayNumber: Int, wordCount: Int) {
                self.index = index

                super.init(frame: CGRect())

                self.layer.cornerRadius = 26.0
                self.layer.masksToBounds = true

                self.numberLabel.text = "\(displayNumber)."
                self.numberLabel.font = Font.with(size: 17.0, traits: .monospacedNumbers)
                self.numberLabel.textAlignment = .right

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

                self.addSubview(self.numberLabel)
                self.addSubview(self.textField)
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            func update(theme: PresentationTheme, isInvalid: Bool, size: CGSize) {
                self.backgroundColor = isInvalid
                    ? theme.list.itemDestructiveColor.withAlphaComponent(0.1)
                    : theme.list.itemInputField.backgroundColor

                self.numberLabel.textColor = theme.list.itemSecondaryTextColor
                self.textField.textColor = isInvalid ? theme.list.itemDestructiveColor : theme.list.itemPrimaryTextColor
                self.textField.tintColor = theme.list.itemAccentColor
                self.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance

                let numberInset: CGFloat = 10.0
                let numberWidth: CGFloat = 26.0
                let numberTextSpacing: CGFloat = 5.0
                self.numberLabel.frame = CGRect(
                    x: numberInset,
                    y: 0.0,
                    width: numberWidth,
                    height: size.height
                )
                self.textField.frame = CGRect(
                    x: numberInset + numberWidth + numberTextSpacing,
                    y: 0.0,
                    width: max(
                        0.0,
                        size.width - numberInset - numberWidth - numberTextSpacing - 9.0
                    ),
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
        private let button = ComponentView<Empty>()

        private let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        private var didRequestInitialFocus = false

        private weak var componentState: EmptyComponentState?
        private var environment: EnvironmentType?
        private var component: WalletImportScreenComponent?
        private let operationDisposable = MetaDisposable()
        private var isImporting = false
        private var didCompleteVerification = false
        private var words = Array(repeating: "", count: 12)
        private var wordValidationDisposables = DisposableDict<Int>()
        private let pastedMnemonicValidationDisposable = MetaDisposable()
        private var validWordIndices = Set<Int>()
        private var invalidWordIndices = Set<Int>()
        private var invalidPastedMnemonic: [String]?
        private var activeWordIndex: Int?

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

            self.setupWordInputFields(displayNumbers: Array(1 ... 12), preserving: [])
        }

        private func setupWordInputFields(displayNumbers: [Int], preserving existingWords: [String]) {
            guard !displayNumbers.isEmpty else {
                return
            }
            let count = displayNumbers.count
            for field in self.wordFields {
                field.removeFromSuperview()
            }
            self.wordFields.removeAll()
            self.wordValidationDisposables.dispose()
            self.wordValidationDisposables = DisposableDict()
            self.pastedMnemonicValidationDisposable.set(nil)
            self.words = Array(repeating: "", count: count)
            for index in 0 ..< min(existingWords.count, count) {
                self.words[index] = existingWords[index]
            }
            self.validWordIndices.removeAll()
            self.invalidWordIndices.removeAll()
            self.invalidPastedMnemonic = nil
            self.activeWordIndex = nil

            for index in 0 ..< count {
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
                field.returnPressed = { [weak self] index in
                    self?.advanceFocus(from: index)
                }
                field.pasteWords = { [weak self] index, words in
                    return self?.insertWords(words, from: index) ?? false
                }
                field.emptyBackspace = { [weak self] index in
                    self?.moveFocusBackward(from: index)
                }
                field.setText(self.words[index])
                self.wordFields.append(field)
            }
            if !self.isVerificationMode {
                for index in self.words.indices where !self.words[index].isEmpty {
                    self.validateWord(at: index)
                }
            }
        }

        private func setWordCount(_ count: Int) {
            guard (count == 12 || count == 24), count != self.words.count else {
                return
            }
            self.setupWordInputFields(displayNumbers: Array(1 ... count), preserving: self.words)
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
            DispatchQueue.main.async { [weak self] in
                self?.wordFields.first(where: { $0.textField.text?.isEmpty != false })?.textField.becomeFirstResponder()
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.titleTransformContainer.removeFromSuperview()
            self.operationDisposable.dispose()
            self.wordValidationDisposables.dispose()
            self.pastedMnemonicValidationDisposable.dispose()
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

        private var isPhraseValid: Bool {
            guard let component = self.component else {
                return false
            }
            switch component.mode {
            case .importWallet:
                if let invalidPastedMnemonic = self.invalidPastedMnemonic,
                   invalidPastedMnemonic == self.words {
                    return false
                }
                return self.words.indices.allSatisfy { index in
                    return !self.words[index].isEmpty && self.validWordIndices.contains(index)
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

        private func validatePastedMnemonic(_ words: [String]) {
            guard !self.isVerificationMode, let component = self.component else {
                return
            }
            self.invalidPastedMnemonic = nil
            self.pastedMnemonicValidationDisposable.set((component.walletContext.validateMnemonic(words: words)
            |> deliverOnMainQueue).start(next: { [weak self] isValid in
                guard let self, self.words == words else {
                    return
                }
                if isValid {
                    self.validWordIndices = Set(self.words.indices)
                    self.invalidWordIndices.removeAll()
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                } else {
                    self.invalidPastedMnemonic = words
                    for index in self.words.indices {
                        self.validateWord(at: index)
                    }
                    self.presentInvalidMnemonic()
                }
            }, error: { [weak self] _ in
                guard let self, self.words == words else {
                    return
                }
                for index in self.words.indices {
                    self.validateWord(at: index)
                }
            }))
        }

        private func validateWord(at index: Int) {
            guard !self.isVerificationMode,
                  let component = self.component,
                  self.words.indices.contains(index) else {
                return
            }
            let word = self.words[index]
            guard !word.isEmpty else {
                self.validWordIndices.remove(index)
                self.invalidWordIndices.remove(index)
                self.wordValidationDisposables.set(nil, forKey: index)
                return
            }

            self.validWordIndices.remove(index)
            self.invalidWordIndices.remove(index)
            self.componentState?.updated(transition: .immediate)
            self.wordValidationDisposables.set((component.walletContext.containsMnemonicWord(word)
            |> deliverOnMainQueue).start(next: { [weak self] isValid in
                guard let self, self.words.indices.contains(index), self.words[index] == word else {
                    return
                }
                if isValid {
                    self.validWordIndices.insert(index)
                    self.invalidWordIndices.remove(index)
                } else {
                    self.validWordIndices.remove(index)
                    self.invalidWordIndices.insert(index)
                }
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }, error: { [weak self] _ in
                guard let self, self.words.indices.contains(index), self.words[index] == word else {
                    return
                }
                self.validWordIndices.remove(index)
                self.invalidWordIndices.remove(index)
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }), forKey: index)
        }

        private func wordTextChanged(index: Int, text: String) {
            guard self.words.indices.contains(index) else {
                return
            }
            self.words[index] = self.normalizeWord(text)
            self.pastedMnemonicValidationDisposable.set(nil)
            self.invalidPastedMnemonic = nil
            self.wordValidationDisposables.set(nil, forKey: index)
            self.validWordIndices.remove(index)
            self.invalidWordIndices.remove(index)
            self.componentState?.updated(transition: .immediate)
        }

        private func wordEditingChanged(index: Int, isEditing: Bool) {
            guard self.words.indices.contains(index) else {
                return
            }

            if isEditing {
                self.activeWordIndex = index
                self.invalidWordIndices.remove(index)
            } else {
                if self.activeWordIndex == index {
                    self.activeWordIndex = nil
                }
                let normalizedWord = self.normalizeWord(self.wordFields[index].textField.text ?? "")
                self.words[index] = normalizedWord
                self.wordFields[index].setText(normalizedWord)
                self.validateWord(at: index)
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
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

            if index + 1 < self.wordFields.count {
                self.wordFields[index + 1].textField.becomeFirstResponder()
            } else {
                self.wordFields[index].textField.resignFirstResponder()
            }
        }

        private func moveFocusBackward(from index: Int) {
            guard index > 0 else {
                return
            }
            self.wordFields[index - 1].textField.becomeFirstResponder()
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
                        self.wordFields[nextIndex].textField.becomeFirstResponder()
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
            self.invalidPastedMnemonic = nil

            for offset in normalizedWords.indices {
                let targetIndex = startIndex + offset
                let word = normalizedWords[offset]
                self.words[targetIndex] = word
                self.wordFields[targetIndex].setText(word)
                self.wordValidationDisposables.set(nil, forKey: targetIndex)
                self.validWordIndices.remove(targetIndex)
                self.invalidWordIndices.remove(targetIndex)
            }

            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if normalizedWords.count > 1 {
                self.validatePastedMnemonic(normalizedWords)
            } else {
                self.validateWord(at: startIndex)
            }

            let nextIndex = startIndex + normalizedWords.count
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if nextIndex < self.wordFields.count {
                    self.wordFields[nextIndex].textField.becomeFirstResponder()
                } else {
                    self.wordFields.last?.textField.resignFirstResponder()
                }
            }
            return true
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
                title: "Invalid Recovery Phrase",
                text: "A TON recovery phrase must contain exactly 12 or 24 words. The pasted phrase contains \(count).",
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
                title: "Invalid Recovery Phrase",
                text: "Check the recovery phrase and try again.",
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
                  case let .verify(phraseWords) = component.mode,
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
                                self.wordFields[firstIndex].textField.becomeFirstResponder()
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
            self.performImport(words: self.words)
        }

        private func performImport(words: [String]) {
            guard let component = self.component else {
                return
            }
            self.isImporting = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.operationDisposable.set((component.walletContext.importWallet(words: words, version: .v5R1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                self?.dismiss()
            }, error: { [weak self] _ in
                self?.finishImportWithError()
            }))
        }

        private func finishImportWithError() {
            self.isImporting = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Couldn’t Import Wallet",
                text: "Check the recovery phrase and network connection, then try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment else {
                return
            }

            let titleCenterY = environment.statusBarHeight
                + (environment.navigationHeight - environment.statusBarHeight) * 0.5
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
                case .importWallet:
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
            let bodyContent: MultilineTextComponent.TextContent
            let buttonTitle: String
            let isVerificationMode: Bool
            switch component.mode {
            case .importWallet:
                isVerificationMode = false
                animationName = "WalletWordList"
                //TODO:localize
                titleText = "Import Wallet"
                //TODO:localize
                let bodyText = "Enter the 12- or 24-word recovery phrase from\nanother wallet you own."
                bodyContent = .plain(NSAttributedString(
                    string: bodyText,
                    font: Font.regular(16.0),
                    textColor: theme.list.itemPrimaryTextColor
                ))
                //TODO:localize
                buttonTitle = "Import"
            case .verify:
                isVerificationMode = true
                animationName = "WalletWordCheck"
                //TODO:localize
                titleText = "Test Time!"
                //TODO:localize
                let bodyText = "Let’s check that you wrote them down correctly. Please enter the words\n**%1$@**, **%2$@** and **%3$@**"
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

            let contentSideInset = 16.0 + max(
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
                    playOnce: self.playAnimation
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
                component: AnyComponent(MultilineTextComponent(
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
            contentHeight += bodySize.height + 38.0

            let fieldWidth = max(
                0.0,
                min(330.0, availableSize.width - contentSideInset * 2.0)
            )
            let fieldX = floorToScreenPixels((availableSize.width - fieldWidth) * 0.5)

            if isVerificationMode {
                self.wordCountControl.view?.removeFromSuperview()
            } else {
                //TODO:localize
                let twelveWordsTitle = "12 Words"
                //TODO:localize
                let twentyFourWordsTitle = "24 Words"
                self.wordCountControl.parentState = state

                let segmentedTheme = SegmentControlComponent.Theme(
                    backgroundColor: theme.list.itemInputField.backgroundColor,
                    legacyBackgroundColor: theme.list.itemInputField.backgroundColor,
                    foregroundColor: theme.overallDarkAppearance ? theme.actionSheet.opaqueItemBackgroundColor : theme.list.plainBackgroundColor,
                    textColor: theme.rootController.navigationBar.segmentedTextColor,
                    dividerColor: theme.rootController.navigationBar.segmentedDividerColor
                )

                let wordCountControlSize = self.wordCountControl.update(
                    transition: transition,
                    component: AnyComponent(SegmentControlComponent(
                        theme: segmentedTheme,
                        items: [
                            SegmentControlComponent.Item(id: AnyHashable(12), title: twelveWordsTitle),
                            SegmentControlComponent.Item(id: AnyHashable(24), title: twentyFourWordsTitle)
                        ],
                        selectedId: AnyHashable(self.words.count),
                        fillWidth: true,
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
                            x: fieldX,
                            y: contentHeight,
                            width: wordCountControlSize.width,
                            height: wordCountControlSize.height
                        )
                    )
                }
                contentHeight += wordCountControlSize.height + 24.0
                }

            let fieldHeight: CGFloat = 52.0
            let fieldSpacing: CGFloat = 14.0
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
                    isInvalid: self.invalidWordIndices.contains(index),
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
                    self?.wordFields.first?.textField.becomeFirstResponder()
                }
            }
            contentHeight += 24.0

            let isButtonEnabled = self.isPhraseValid
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
                        guard let self, self.isPhraseValid else {
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
        case .importWallet:
            verificationIndices = []
        case let .verify(words):
            precondition(words.count >= 3)
            verificationIndices = Array(words.indices.shuffled().prefix(3)).sorted()
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
}
