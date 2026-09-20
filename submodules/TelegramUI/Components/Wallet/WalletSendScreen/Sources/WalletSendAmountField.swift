import Foundation
import UIKit
import CoreText
import Display
import ComponentFlow
import LottieComponent
import LottieSettings
import MultilineTextComponent
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import WalletContext

enum WalletSendInputMode: Equatable {
    case gram
    case fiat
}

func walletSendNormalizedDigits(_ text: String) -> String {
    return String(text.unicodeScalars.map { scalar -> Character in
        let character = Character(String(scalar))
        if CharacterSet.decimalDigits.contains(scalar), let digit = character.wholeNumberValue {
            return Character(String(digit))
        }
        return character
    })
}

func walletSendNanograms(
    text: String,
    mode: WalletSendInputMode,
    rate: Double?,
    decimalSeparator: String
) -> Int64? {
    guard !text.isEmpty else {
        return 0
    }

    guard !decimalSeparator.isEmpty else { return nil }
    let normalizedText = walletSendNormalizedDigits(text).replacingOccurrences(of: decimalSeparator, with: ".")
    let parts = normalizedText.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2,
          parts.allSatisfy({ $0.utf8.allSatisfy({ (48 ... 57).contains($0) }) }) else {
        return nil
    }
    switch mode {
    case .gram:
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
        guard let fractional = Int64(fractionalText) else { return nil }
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

func walletSendInputText(
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
            dateTimeFormat: PresentationDateTimeFormat(
                timeFormat: dateTimeFormat.timeFormat,
                dateFormat: dateTimeFormat.dateFormat,
                dateSeparator: "",
                dateSuffix: "",
                requiresFullYear: false,
                decimalSeparator: dateTimeFormat.decimalSeparator,
                groupingSeparator: ""
            ),
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

func walletSendGroupedAmountText(_ text: String, dateTimeFormat: PresentationDateTimeFormat) -> String {
    guard !dateTimeFormat.groupingSeparator.isEmpty else {
        return text
    }
    let integralEnd = text.range(of: dateTimeFormat.decimalSeparator)?.lowerBound ?? text.endIndex
    let integralPart = text[..<integralEnd]
    let integralLength = integralPart.count
    guard integralLength > 3 else {
        return text
    }

    var result = ""
    for (index, character) in integralPart.enumerated() {
        if index > 0 && (integralLength - index) % 3 == 0 {
            result.append(contentsOf: dateTimeFormat.groupingSeparator)
        }
        result.append(character)
    }
    result.append(contentsOf: text[integralEnd...])
    return result
}

private struct WalletSendAmountTextLayout {
    let attributedText: NSAttributedString
    let groupingSeparator: NSAttributedString
    let groupingSeparatorSize: CGSize
    let groupingPositions: [CGFloat]
}

private final class WalletSendAmountTextField: UITextField {
    private let groupingView = UIView()
    private var groupingLabels: [UILabel] = []
    private var textLayout: WalletSendAmountTextLayout?

    var selectionRange: NSRange? {
        guard let selection = self.selectedTextRange else { return nil }
        let start = self.offset(from: self.beginningOfDocument, to: selection.start)
        let end = self.offset(from: self.beginningOfDocument, to: selection.end)
        return NSRange(location: start, length: end - start)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.groupingView.isUserInteractionEnabled = false
        self.groupingView.accessibilityElementsHidden = true
        self.addSubview(self.groupingView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(layout: WalletSendAmountTextLayout, selection: NSRange?) {
        self.textLayout = layout
        if self.attributedText?.isEqual(to: layout.attributedText) != true {
            self.attributedText = layout.attributedText
        }
        if let selection {
            let textLength = layout.attributedText.length
            let start = min(textLength, max(0, selection.location))
            let end = start + min(textLength - start, max(0, selection.length))
            if self.selectionRange != NSRange(location: start, length: end - start),
               let startPosition = self.position(from: self.beginningOfDocument, offset: start),
               let endPosition = self.position(from: self.beginningOfDocument, offset: end) {
                self.selectedTextRange = self.textRange(from: startPosition, to: endPosition)
            }
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.groupingView.frame = self.bounds
        self.bringSubviewToFront(self.groupingView)
        guard let textLayout = self.textLayout else { return }
        while self.groupingLabels.count > textLayout.groupingPositions.count {
            self.groupingLabels.removeLast().removeFromSuperview()
        }
        while self.groupingLabels.count < textLayout.groupingPositions.count {
            let label = UILabel()
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            self.groupingView.addSubview(label)
            self.groupingLabels.append(label)
        }
        let startCaret = self.caretRect(for: self.beginningOfDocument)
        let textOriginX: CGFloat
        let centerY: CGFloat
        if !startCaret.isNull, !startCaret.isInfinite, startCaret.height > 0.0 {
            textOriginX = startCaret.minX
            centerY = startCaret.midY
        } else {
            // UIKit may not expose caret geometry before the field starts editing.
            let textRect = self.isEditing ? self.editingRect(forBounds: self.bounds) : self.textRect(forBounds: self.bounds)
            textOriginX = textRect.minX
            centerY = textRect.midY
        }
        for (index, position) in textLayout.groupingPositions.enumerated() {
            let label = self.groupingLabels[index]
            label.attributedText = textLayout.groupingSeparator
            label.frame = CGRect(
                x: textOriginX + position - textLayout.groupingSeparatorSize.width,
                y: centerY - textLayout.groupingSeparatorSize.height / 2.0,
                width: textLayout.groupingSeparatorSize.width,
                height: textLayout.groupingSeparatorSize.height
            )
        }
    }
}

final class WalletSendAmountField: UIView, UITextFieldDelegate {
    private let contentView = UIView()
    private let gramIcon = ComponentView<Empty>()
    private let fiatIcon = ComponentView<Empty>()
    private let textField = WalletSendAmountTextField(frame: .zero)
    private let suffix = ComponentView<Empty>()
    private let integralFont = Font.with(
        size: 48.0,
        design: .round,
        weight: .semibold,
        traits: []
    )
    private let fractionalFont = Font.with(size: 32.0, design: .round, weight: .semibold)

    private let gramIconLayoutSize = CGSize(width: 44.0, height: 44.0)
    private let gramAnimationSize = CGSize(width: 48.0, height: 48.0)
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

        self.addSubview(self.contentView)

        self.textField.font = self.integralFont
        self.textField.delegate = self
        self.textField.keyboardType = .decimalPad
        self.textField.autocorrectionType = .no
        self.textField.autocapitalizationType = .none
        self.textField.textAlignment = .left
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.contentView.addSubview(self.textField)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.activateInput))
        self.addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func activateInput() {
        self.textField.becomeFirstResponder()
    }

    private func amountTextLayout(_ text: String) -> WalletSendAmountTextLayout {
        let textColor = self.textField.textColor ?? UIColor.black
        let decimalSeparator = self.dateTimeFormat?.decimalSeparator ?? "."
        let groupingSeparator = self.dateTimeFormat?.groupingSeparator ?? ""
        let attributedText = NSMutableAttributedString(attributedString: tonAmountAttributedString(
            text,
            integralFont: self.integralFont,
            fractionalFont: self.fractionalFont,
            color: textColor,
            decimalSeparator: decimalSeparator
        ))
        let separatorText = NSAttributedString(string: groupingSeparator, font: self.integralFont, textColor: textColor)
        let separatorLine = CTLineCreateWithAttributedString(separatorText)
        let separatorSize = CGSize(
            width: ceil(CGFloat(CTLineGetTypographicBounds(separatorLine, nil, nil, nil))),
            height: ceil(self.integralFont.lineHeight)
        )
        let decimalRange = (text as NSString).range(of: decimalSeparator)
        let integralLength = decimalRange.location == NSNotFound ? attributedText.length : decimalRange.location
        var groupingOffsets: [Int] = []
        if !groupingSeparator.isEmpty, integralLength > 3 {
            groupingOffsets = Array(stride(from: integralLength - 3, through: 1, by: -3).reversed())
            for offset in groupingOffsets {
                // Reserve drawing space without introducing a selectable character.
                attributedText.addAttribute(.kern, value: separatorSize.width, range: NSRange(location: offset - 1, length: 1))
            }
        }
        var groupingPositions: [CGFloat] = []
        if !groupingOffsets.isEmpty {
            let line = CTLineCreateWithAttributedString(attributedText)
            for runValue in CTLineGetGlyphRuns(line) as NSArray {
                let run = runValue as! CTRun
                let glyphCount = CTRunGetGlyphCount(run)
                guard glyphCount > 0 else { continue }
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var indices = [CFIndex](repeating: 0, count: glyphCount)
                let range = CFRangeMake(0, glyphCount)
                CTRunGetPositions(run, range, &positions)
                CTRunGetStringIndices(run, range, &indices)
                for index in 0 ..< glyphCount where groupingOffsets.contains(indices[index]) {
                    // A caret can sit inside the kerned gap; use the next glyph's actual origin.
                    groupingPositions.append(positions[index].x)
                }
            }
        }
        return WalletSendAmountTextLayout(
            attributedText: attributedText,
            groupingSeparator: separatorText,
            groupingSeparatorSize: separatorSize,
            groupingPositions: groupingPositions
        )
    }

    private func applyText(_ text: String, selection: NSRange?) {
        self.isApplyingText = true
        self.textField.update(layout: self.amountTextLayout(text), selection: selection)
        self.isApplyingText = false
        self.setNeedsLayout()
    }

    @objc private func textChanged() {
        guard !self.isApplyingText, let dateTimeFormat = self.dateTimeFormat else {
            return
        }
        self.applyText(self.textField.text ?? "", selection: self.textField.selectionRange)
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
        let inputText = walletSendInputText(
            amount: amount,
            mode: self.mode,
            rate: self.rate,
            dateTimeFormat: dateTimeFormat
        )
        self.applyText(inputText, selection: NSRange(location: inputText.utf16.count, length: 0))
    }

    func update(
        mode: WalletSendInputMode,
        amount: Int64,
        rate: Double?,
        fiatCurrency: WalletContext.FiatCurrency,
        dateTimeFormat: PresentationDateTimeFormat,
        theme: PresentationTheme,
        lottieSettings: LottieRenderingSettings,
        isVisible: Bool,
        transition: ComponentTransition
    ) {
        let modeChanged = self.mode != mode
        let amountChanged = self.amount != amount
        let rateChanged = self.rate != rate
        let previousDecimalSeparator = self.dateTimeFormat?.decimalSeparator
        let decimalSeparatorChanged = self.dateTimeFormat?.decimalSeparator != dateTimeFormat.decimalSeparator
        let groupingSeparatorChanged = self.dateTimeFormat?.groupingSeparator != dateTimeFormat.groupingSeparator
        let textColorChanged = self.textField.textColor?.isEqual(theme.list.itemPrimaryTextColor) != true
        let previousSelection = self.textField.selectionRange
        self.mode = mode
        self.amount = amount
        self.rate = rate
        self.dateTimeFormat = dateTimeFormat

        if textColorChanged {
            self.textField.textColor = theme.list.itemPrimaryTextColor
        }
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

        let _ = self.gramIcon.update(
            transition: transition,
            component: AnyComponent(LottieComponent(
                content: LottieComponent.AppBundleContent(name: "TonDiamond"),
                startingPosition: .begin,
                size: self.gramAnimationSize,
                loop: true,
                lottieSettings: lottieSettings
            )),
            environment: {},
            containerSize: self.gramAnimationSize
        )
        if let gramIconView = self.gramIcon.view as? LottieComponent.View {
            gramIconView.externalShouldPlay = mode == .gram && isVisible
            if gramIconView.superview == nil {
                gramIconView.isUserInteractionEnabled = false
                self.contentView.addSubview(gramIconView)
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
                self.contentView.addSubview(fiatIconView)
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
            self.contentView.addSubview(suffixView)
        }

        if modeChanged || ((amountChanged || rateChanged) && !self.textField.isFirstResponder) {
            self.setAmount(amount)
            self.textField.reloadInputViews()
        } else if textColorChanged || decimalSeparatorChanged || groupingSeparatorChanged {
            var text = self.textField.text ?? ""
            var selection = previousSelection
            if decimalSeparatorChanged, let previousDecimalSeparator, !previousDecimalSeparator.isEmpty {
                let range = (text as NSString).range(of: previousDecimalSeparator)
                if range.location != NSNotFound {
                    text = (text as NSString).replacingCharacters(in: range, with: dateTimeFormat.decimalSeparator)
                    if let previousSelection = selection {
                        let replacementLength = dateTimeFormat.decimalSeparator.utf16.count
                        func updatedOffset(_ offset: Int) -> Int {
                            if offset <= range.location { return offset }
                            if offset < NSMaxRange(range) { return range.location + replacementLength }
                            return offset + replacementLength - range.length
                        }
                        let start = updatedOffset(previousSelection.location)
                        let end = updatedOffset(NSMaxRange(previousSelection))
                        selection = NSRange(location: start, length: end - start)
                    }
                }
            }
            self.applyText(text, selection: selection)
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconLayoutSize = CGSize(width: 40.0, height: 40.0)
        let iconSpacing: CGFloat = self.mode == .fiat ? 0.0 : 2.0
        let suffixSpacing: CGFloat = -1.0
        let displayText = (self.textField.text ?? "").isEmpty ? "0" : (self.textField.text ?? "")
        let displayTextBounds = self.amountTextLayout(displayText).attributedText.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.bounds.height),
            options: [],
            context: nil
        )
        let textWidth = max(31.0, ceil(displayTextBounds.width) + 5.0)
        let iconWidth = self.mode == .gram ? self.gramIconLayoutSize.width : self.fiatIconSize.width

        let iconLeadingInset = max(0.0, -floorToScreenPixels((iconLayoutSize.width - iconWidth) / 2.0))
        let totalWidth = iconLeadingInset + iconLayoutSize.width + iconSpacing + textWidth + suffixSpacing + self.suffixSize.width
        let scale = min(1.0, self.bounds.width / totalWidth)
        self.contentView.bounds = CGRect(origin: .zero, size: CGSize(width: totalWidth, height: self.bounds.height))
        self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)

        var x = iconLeadingInset
        let centerY = self.bounds.height / 2.0

        if let gramIconView = self.gramIcon.view {
            gramIconView.frame = CGRect(
                origin: CGPoint(
                    x: x + floorToScreenPixels((iconLayoutSize.width - self.gramAnimationSize.width) / 2.0) - 1.0,
                    y: floorToScreenPixels(centerY - self.gramAnimationSize.height / 2.0) - 1.0
                ),
                size: self.gramAnimationSize
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
        textField.setNeedsLayout()
        self.focusUpdated?(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.setNeedsLayout()
        self.focusUpdated?(false)
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        textField.setNeedsLayout()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let dateTimeFormat = self.dateTimeFormat else {
            return false
        }

        var replacement = walletSendNormalizedDigits(string)
        if replacement == "." || replacement == "," {
            replacement = dateTimeFormat.decimalSeparator
        }
        let previousText = (textField.text ?? "") as NSString
        guard range.location != NSNotFound, range.location >= 0, range.location <= previousText.length,
              range.length >= 0, range.length <= previousText.length - range.location else { return false }
        var updatedText = previousText.replacingCharacters(in: range, with: replacement)
        var selectionOffset = range.location + replacement.utf16.count
        let decimalSeparator = dateTimeFormat.decimalSeparator

        let allowedCharacters = CharacterSet(charactersIn: "0123456789" + decimalSeparator)
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
            selectionOffset += 1
        }
        if updatedText.count > 1 && updatedText.hasPrefix("0") && !updatedText.hasPrefix("0" + decimalSeparator) {
            updatedText.removeFirst()
            selectionOffset = max(0, selectionOffset - 1)
        }
        let shouldAppendDecimalSeparator = !replacement.isEmpty && updatedText == "0"
        if shouldAppendDecimalSeparator {
            updatedText += decimalSeparator
            selectionOffset = updatedText.utf16.count
        }
        guard walletSendNanograms(
            text: updatedText,
            mode: self.mode,
            rate: self.rate,
            decimalSeparator: decimalSeparator
        ) != nil else {
            return false
        }

        self.applyText(updatedText, selection: NSRange(location: selectionOffset, length: 0))
        self.textChanged()
        return false
    }
}
