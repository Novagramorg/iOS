import Foundation
import UIKit
import Display
import TelegramPresentationData
import LocalAuthentication

// MARK: - Public mode enum

/// Describes what the ChatPincodeViewController should do.
public enum ChatPincodeMode {
    /// First-time setup: let the user choose PIN vs text-password, enter it twice,
    /// then optionally enable biometrics. `onSuccess` receives (credential, type, biometricEnabled).
    case set(onSuccess: (String, ChatLockPasswordType, Bool) -> Void)

    /// Unlock an already-locked chat.
    /// `passwordType`     — which entry UI to show (dots vs text field).
    /// `biometricEnabled` — whether to attempt Face/Touch ID on appear.
    /// `onVerify`         — returns true when the entered credential is correct.
    /// `onSuccess`        — called after a successful unlock.
    /// `onForgot`         — optional; when non-nil a "Forgot pincode?" button is
    ///                      shown that invokes this (master-pincode recovery).
    case verify(
        passwordType: ChatLockPasswordType,
        biometricEnabled: Bool,
        onVerify: (String) -> Bool,
        onSuccess: () -> Void,
        onForgot: (() -> Void)? = nil
    )

    /// Remove the lock: verify the current credential, then call onSuccess.
    case remove(
        passwordType: ChatLockPasswordType,
        onVerify: (String) -> Bool,
        onSuccess: () -> Void
    )
}

// MARK: - ViewController

public final class ChatPincodeViewController: ViewController {

    private let mode: ChatPincodeMode
    private let presentationData: PresentationData
    // When true this is the master-pincode recovery screen ("Forgot pincode?"), which shows a
    // distinct title/subtitle so the user isn't faced with an identical-looking lock screen.
    private let isMasterRecovery: Bool

    // -- setup-flow state --
    private var chosenType: ChatLockPasswordType = .pin   // picked by the type-picker sheet
    private var setupPhase: SetupPhase = .pickType        // drives the setup step machine

    // -- entry state (shared by PIN and text modes) --
    private var enteredCode: String = ""
    private var firstCode: String = ""       // holds the first entry during confirmation step
    private var currentStep: ChatLockSetupStep = .enterNew
    // Wrong-entry counter (verify/master). After 4 we surface recovery — never a lockout.
    private var failedAttempts = 0

    // -- UI --
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!

    // PIN mode
    private var dotsView: UIStackView!
    private var dotViews: [UIView] = []
    private var numberPadView: UIView!

    // Text-password mode
    private var textField: UITextField!
    private var submitButton: UIButton!

    // Biometric button (shown during .verify when biometrics are available & enabled)
    private var biometricButton: UIButton!

    // "Forgot pincode?" button (shown only in .verify mode when an onForgot handler is supplied)
    private var forgotButton: UIButton!

    // Close button (always present)
    private var closeButton: UIButton!

    // Type-picker buttons (shown only during setupPhase == .pickType)
    private var typePickerContainer: UIView!

    // MARK: - Init

    public init(mode: ChatPincodeMode, presentationData: PresentationData, isMasterRecovery: Bool = false) {
        self.mode = mode
        self.presentationData = presentationData
        self.isMasterRecovery = isMasterRecovery

        // Derive initial step from mode so we skip the type picker for verify/remove.
        switch mode {
        case .set:
            self.setupPhase = .pickType
            self.currentStep = .enterNew
        case .verify:
            self.setupPhase = .enterCredential
            self.currentStep = isMasterRecovery ? .verifyMaster : .verify
        case .remove:
            self.setupPhase = .enterCredential
            self.currentStep = .remove
        }

        // For verify/remove, grab the password type from the mode payload.
        switch mode {
        case .verify(let passwordType, _, _, _, _):
            self.chosenType = passwordType
        case .remove(let passwordType, _, _):
            self.chosenType = passwordType
        case .set:
            self.chosenType = .pin   // overridden by the type picker
        }

        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        syncVisibility()
        updateLabels()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attemptBiometricIfNeeded()
        activateTextFieldIfNeeded()
    }

    // MARK: - Layout

    private func buildLayout() {
        let isDark = presentationData.theme.overallDarkAppearance
        view.backgroundColor = isDark ? UIColor(rgb: 0x1c1c1e) : UIColor(rgb: 0xf2f2f7)

        // Close button
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = isDark ? UIColor(white: 1, alpha: 0.4) : UIColor(white: 0, alpha: 0.3)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        // Title
        titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = isDark ? .white : .black
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Type-picker container (only used in set mode, phase .pickType)
        buildTypePickerContainer(isDark: isDark)
        view.addSubview(typePickerContainer)

        // PIN dots row
        buildDotsRow()
        view.addSubview(dotsView)

        // Number pad
        numberPadView = buildNumberPad(isDark: isDark)
        numberPadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(numberPadView)

        // Text field (for alphanumeric password mode)
        buildTextField(isDark: isDark)
        view.addSubview(textField)
        view.addSubview(submitButton)

        // Biometric button
        buildBiometricButton(isDark: isDark)
        view.addSubview(biometricButton)

        // "Forgot pincode?" button (verify + master-recovery only)
        buildForgotButton(isDark: isDark)
        view.addSubview(forgotButton)

        // Layout constraints
        let padHeight: CGFloat = 4 * 76 + 3 * 14

        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            // Title
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Subtitle
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Type picker (anchored below subtitle, same vertical space as dots+pad)
            typePickerContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            typePickerContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            typePickerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            typePickerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // Dots row
            dotsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dotsView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),

            // Number pad
            numberPadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numberPadView.topAnchor.constraint(equalTo: dotsView.bottomAnchor, constant: 44),
            numberPadView.widthAnchor.constraint(equalToConstant: 280),
            numberPadView.heightAnchor.constraint(equalToConstant: padHeight),

            // Text field
            textField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 48),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            textField.heightAnchor.constraint(equalToConstant: 50),

            // Submit button (below text field)
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            submitButton.widthAnchor.constraint(equalToConstant: 200),
            submitButton.heightAnchor.constraint(equalToConstant: 50),

            // Biometric button (below the number pad or submit button; we anchor to view bottom)
            biometricButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            biometricButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
            biometricButton.widthAnchor.constraint(equalToConstant: 60),
            biometricButton.heightAnchor.constraint(equalToConstant: 60),

            // "Forgot pincode?" — sits just above the biometric button. The biometric
            // button is hidden in most verify flows, so this usually floats near the bottom.
            forgotButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forgotButton.bottomAnchor.constraint(equalTo: biometricButton.topAnchor, constant: -20),
            forgotButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            forgotButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Sub-view builders

    private func buildTypePickerContainer(isDark: Bool) {
        typePickerContainer = UIView()
        typePickerContainer.translatesAutoresizingMaskIntoConstraints = false

        let pinBtn = makeTypePickerButton(
            title: FenixuzChatLockStrings.chooseTypePin,
            icon: "lock.fill",
            isDark: isDark,
            tag: 0
        )
        let textBtn = makeTypePickerButton(
            title: FenixuzChatLockStrings.chooseTypeText,
            icon: "textformat.abc",
            isDark: isDark,
            tag: 1
        )

        pinBtn.translatesAutoresizingMaskIntoConstraints = false
        textBtn.translatesAutoresizingMaskIntoConstraints = false
        typePickerContainer.addSubview(pinBtn)
        typePickerContainer.addSubview(textBtn)

        NSLayoutConstraint.activate([
            pinBtn.topAnchor.constraint(equalTo: typePickerContainer.topAnchor),
            pinBtn.leadingAnchor.constraint(equalTo: typePickerContainer.leadingAnchor),
            pinBtn.trailingAnchor.constraint(equalTo: typePickerContainer.trailingAnchor),
            pinBtn.heightAnchor.constraint(equalToConstant: 64),

            textBtn.topAnchor.constraint(equalTo: pinBtn.bottomAnchor, constant: 16),
            textBtn.leadingAnchor.constraint(equalTo: typePickerContainer.leadingAnchor),
            textBtn.trailingAnchor.constraint(equalTo: typePickerContainer.trailingAnchor),
            textBtn.heightAnchor.constraint(equalToConstant: 64),
            textBtn.bottomAnchor.constraint(equalTo: typePickerContainer.bottomAnchor)
        ])
    }

    private func makeTypePickerButton(title: String, icon: String, isDark: Bool, tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag

        let cardColor = isDark ? UIColor(white: 1, alpha: 0.08) : UIColor.white
        btn.backgroundColor = cardColor
        btn.layer.cornerRadius = 14
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = isDark ? 0 : 0.07
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6

        // Icon
        let imgView = UIImageView(image: UIImage(systemName: icon))
        imgView.tintColor = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        imgView.contentMode = .scaleAspectFit
        imgView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 17, weight: .medium)
        lbl.textColor = isDark ? .white : .black
        lbl.translatesAutoresizingMaskIntoConstraints = false

        // Chevron
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = isDark ? UIColor(white: 1, alpha: 0.3) : UIColor(white: 0, alpha: 0.25)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(imgView)
        btn.addSubview(lbl)
        btn.addSubview(chevron)

        NSLayoutConstraint.activate([
            imgView.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 20),
            imgView.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            imgView.widthAnchor.constraint(equalToConstant: 24),
            imgView.heightAnchor.constraint(equalToConstant: 24),

            lbl.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 14),
            lbl.centerYAnchor.constraint(equalTo: btn.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -18),
            chevron.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        btn.addTarget(self, action: #selector(typePickerTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func buildDotsRow() {
        dotsView = UIStackView()
        dotsView.axis = .horizontal
        dotsView.spacing = 16
        dotsView.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<4 {
            let dot = UIView()
            dot.layer.cornerRadius = 10
            dot.layer.borderWidth = 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 20).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 20).isActive = true
            dotViews.append(dot)
            dotsView.addArrangedSubview(dot)
        }
    }

    private func buildTextField(isDark: Bool) {
        textField = UITextField()
        textField.placeholder = FenixuzChatLockStrings.done
        textField.isSecureTextEntry = true
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 20, weight: .regular)
        textField.textColor = isDark ? .white : .black
        textField.textAlignment = .center
        textField.backgroundColor = isDark ? UIColor(white: 1, alpha: 0.08) : UIColor.white
        textField.layer.cornerRadius = 12
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false

        // Add some horizontal padding via a transparent left view.
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftView = padding
        textField.leftViewMode = .always

        submitButton = UIButton(type: .custom)
        submitButton.setTitle(FenixuzChatLockStrings.done, for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        submitButton.setTitleColor(.white, for: .normal)
        let accent = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        submitButton.backgroundColor = accent
        submitButton.layer.cornerRadius = 14
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildBiometricButton(isDark: Bool) {
        biometricButton = UIButton(type: .custom)
        // Icon will be updated in syncVisibility() based on detected biometric type.
        biometricButton.tintColor = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        biometricButton.backgroundColor = isDark ? UIColor(white: 1, alpha: 0.08) : UIColor(white: 0, alpha: 0.05)
        biometricButton.layer.cornerRadius = 30
        biometricButton.addTarget(self, action: #selector(biometricTapped), for: .touchUpInside)
        biometricButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildForgotButton(isDark: Bool) {
        forgotButton = UIButton(type: .system)
        forgotButton.setTitle(isMasterRecovery ? FenixuzChatLockStrings.resetButtonTitle : FenixuzChatLockStrings.forgotPincode, for: .normal)
        forgotButton.setTitleColor(UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb), for: .normal)
        forgotButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        forgotButton.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        forgotButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildNumberPad(isDark: Bool) -> UIView {
        let container = UIView()
        let buttonSize: CGFloat = 76
        let spacing: CGFloat = 14
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

        for (index, label) in digits.enumerated() {
            let row = index / 3
            let col = index % 3
            if label.isEmpty { continue }

            let button = UIButton(type: .custom)
            button.setTitle(label, for: .normal)
            button.titleLabel?.font = label == "⌫"
                ? .systemFont(ofSize: 24, weight: .medium)
                : .systemFont(ofSize: 28, weight: .regular)
            button.setTitleColor(isDark ? .white : .black, for: .normal)

            if label != "⌫" {
                button.backgroundColor = isDark ? UIColor(white: 1, alpha: 0.08) : UIColor(white: 1, alpha: 0.9)
                button.layer.cornerRadius = buttonSize / 2
                button.layer.shadowColor = UIColor.black.cgColor
                button.layer.shadowOpacity = isDark ? 0 : 0.08
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 4
            }

            button.frame = CGRect(
                x: CGFloat(col) * (buttonSize + spacing),
                y: CGFloat(row) * (buttonSize + spacing),
                width: buttonSize,
                height: buttonSize
            )
            button.tag = index
            button.addTarget(self, action: #selector(padTapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(padPressed(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(padReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

            container.addSubview(button)
        }

        let rows = 4
        let h = CGFloat(rows) * buttonSize + CGFloat(rows - 1) * spacing
        container.frame = CGRect(x: 0, y: 0, width: 3 * buttonSize + 2 * spacing, height: h)
        return container
    }

    // MARK: - Visibility sync

    /// Show/hide sub-views depending on which phase + type is active.
    private func syncVisibility() {
        let isPickingType = (setupPhase == .pickType)
        let isPINEntry    = !isPickingType && (chosenType == .pin)
        let isTextEntry   = !isPickingType && (chosenType == .text)

        typePickerContainer.isHidden = !isPickingType
        dotsView.isHidden            = !isPINEntry
        numberPadView.isHidden       = !isPINEntry
        textField.isHidden           = !isTextEntry
        submitButton.isHidden        = !isTextEntry

        // "Forgot pincode?": only in verify mode when a master-recovery handler is supplied.
        // Chat page: shown when master recovery exists. Master page: button is "Reset Chat Lock",
        // hidden until the user has struggled (4 wrong tries), per the surface-recovery UX.
        forgotButton.isHidden = isMasterRecovery ? (failedAttempts < 4) : (verifyOnForgot == nil)

        // Biometric button: only during verify/remove (never setup), when device supports it.
        let showBiometric = !isPickingType && biometricShouldShow()
        biometricButton.isHidden = !showBiometric

        if showBiometric {
            let iconName = (ChatLockBiometricHelper.availableType() == .faceID)
                ? "faceid" : "touchid"
            biometricButton.setImage(
                UIImage(systemName: iconName)?.withConfiguration(
                    UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
                ),
                for: .normal
            )
        }

        // Refresh dot colors whenever visibility changes.
        if isPINEntry { syncDots() }
    }

    /// True when the biometric button should be rendered on screen.
    private func biometricShouldShow() -> Bool {
        switch mode {
        case .verify(_, let enabled, _, _, _):
            return enabled && ChatLockBiometricHelper.availableType() != nil
        case .remove, .set:
            return false
        }
    }

    // MARK: - Label updates

    private func updateLabels() {
        let isDarkSub = presentationData.theme.overallDarkAppearance
        subtitleLabel.textColor = isDarkSub
            ? UIColor(white: 1, alpha: 0.5)
            : UIColor(white: 0, alpha: 0.45)

        if setupPhase == .pickType {
            titleLabel.text    = FenixuzChatLockStrings.chooseTypeTitle
            subtitleLabel.text = ""
            return
        }

        switch chosenType {
        case .pin:
            titleLabel.text    = FenixuzChatLockStrings.pinTitle(mode: currentStep)
            subtitleLabel.text = FenixuzChatLockStrings.pinSubtitle(mode: currentStep)
        case .text:
            titleLabel.text    = FenixuzChatLockStrings.textTitle(mode: currentStep)
            subtitleLabel.text = FenixuzChatLockStrings.textSubtitle(mode: currentStep)
        }
    }

    // MARK: - Biometric auto-attempt

    private func attemptBiometricIfNeeded() {
        // onVerify is not needed for the biometric path — bind to _ to silence the warning.
        guard case .verify(_, let enabled, _, let onSuccess, _) = mode,
              enabled,
              ChatLockBiometricHelper.availableType() != nil
        else { return }

        ChatLockBiometricHelper.evaluate(reason: FenixuzChatLockStrings.biometricReason) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.dismissSelf { onSuccess() }
            case .cancelled:
                // User dismissed — leave the PIN/text field ready for manual entry.
                break
            case .unavailable:
                // Biometrics failed (lockout, not enrolled). Fall through to manual entry.
                break
            }
        }
    }

    // MARK: - Text field focus

    private func activateTextFieldIfNeeded() {
        guard setupPhase == .enterCredential, chosenType == .text else { return }
        textField.becomeFirstResponder()
    }

    // MARK: - Type picker action

    @objc private func typePickerTapped(_ sender: UIButton) {
        chosenType = (sender.tag == 0) ? .pin : .text
        setupPhase = .enterCredential
        currentStep = .enterNew
        enteredCode = ""
        firstCode = ""
        syncVisibility()
        updateLabels()
        if chosenType == .text {
            textField.text = ""
            textField.becomeFirstResponder()
        }
    }

    // MARK: - Number pad actions

    @objc private func padPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) {
            sender.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
        }
    }

    @objc private func padReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }

    @objc private func padTapped(_ sender: UIButton) {
        guard let title = sender.titleLabel?.text else { return }

        if title == "⌫" {
            if !enteredCode.isEmpty {
                enteredCode.removeLast()
                syncDots()
            }
        } else {
            guard enteredCode.count < 4 else { return }
            enteredCode.append(title)
            syncDots()
            if enteredCode.count == 4 {
                processCredential(enteredCode)
            }
        }
    }

    // MARK: - Submit button (text mode)

    @objc private func submitTapped() {
        let code = (textField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        textField.resignFirstResponder()
        enteredCode = code
        processCredential(code)
    }

    // MARK: - Biometric button

    @objc private func biometricTapped() {
        attemptBiometricIfNeeded()
    }

    // MARK: - Forgot pincode

    /// The optional master-recovery handler — present only in `.verify` mode.
    private var verifyOnForgot: (() -> Void)? {
        if case let .verify(_, _, _, _, onForgot) = mode {
            return onForgot
        }
        return nil
    }

    @objc private func forgotTapped() {
        if isMasterRecovery {
            resetChatLockTapped()
        } else {
            verifyOnForgot?()
        }
    }

    // MARK: - Master reset (forgot the master too)

    /// Escape hatch when the user has ALSO forgotten the master pincode. Chat Lock is a local
    /// privacy gate (messages live on Telegram's servers), so a device-owner-proven reset loses
    /// no data. Requires the device Face/Touch ID or passcode so a snooper can't just tap it.
    private func resetChatLockTapped() {
        let alert = UIAlertController(
            title: FenixuzChatLockStrings.resetConfirmTitle,
            message: FenixuzChatLockStrings.resetConfirmMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: FenixuzChatLockStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: FenixuzChatLockStrings.resetConfirmAction, style: .destructive) { [weak self] _ in
            self?.authenticateThenReset()
        })
        present(alert, animated: true)
    }

    private func authenticateThenReset() {
        let proceed: () -> Void = { [weak self] in
            guard let self else { return }
            ChatPincodeManager.shared.disableChatLock()
            if case let .verify(_, _, _, onSuccess, _) = self.mode {
                self.dismissSelf { onSuccess() }
            } else {
                self.dismissSelf()
            }
        }
        let context = LAContext()
        var authError: NSError?
        // deviceOwnerAuthentication = biometrics with a device-passcode fallback.
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: FenixuzChatLockStrings.resetReason) { success, _ in
                DispatchQueue.main.async { if success { proceed() } }
            }
        } else {
            // No passcode/biometrics on the device — there is no security boundary to honor.
            proceed()
        }
    }

    /// After 4 wrong entries we never lock the owner out — we make the recovery obvious instead.
    private func revealRecovery() {
        guard isMasterRecovery || verifyOnForgot != nil else { return }
        subtitleLabel.text = FenixuzChatLockStrings.recoveryHint
        subtitleLabel.textColor = presentationData.theme.overallDarkAppearance
            ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.45)
        if isMasterRecovery {
            forgotButton.isHidden = false
        }
        guard !forgotButton.isHidden else { return }
        UIView.animate(withDuration: 0.15, animations: { self.forgotButton.transform = CGAffineTransform(scaleX: 1.12, y: 1.12) }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.forgotButton.transform = .identity }
        })
    }

    // MARK: - Core credential processing

    private func processCredential(_ code: String) {
        switch mode {

        case let .set(onSuccess):
            handleSetFlow(code: code, onSuccess: onSuccess)

        case let .verify(_, _, onVerify, onSuccess, _):
            if onVerify(code) {
                dismissSelf { onSuccess() }
            } else {
                failedAttempts += 1
                shakeAndReset(isPasswordMode: chosenType == .text)
                if failedAttempts >= 4 { revealRecovery() }
            }

        case let .remove(_, onVerify, onSuccess):
            if onVerify(code) {
                dismissSelf { onSuccess() }
            } else {
                shakeAndReset(isPasswordMode: chosenType == .text)
            }
        }
    }

    // MARK: - Setup flow state machine

    private func handleSetFlow(code: String, onSuccess: @escaping (String, ChatLockPasswordType, Bool) -> Void) {
        switch setupPhase {

        case .enterCredential:
            // First entry — ask for confirmation.
            firstCode = code
            enteredCode = ""
            setupPhase = .confirmCredential
            currentStep = .confirmNew
            updateLabels()
            if chosenType == .text {
                textField.text = ""
                textField.becomeFirstResponder()
            } else {
                syncDots()
            }

        case .confirmCredential:
            if code == firstCode {
                // Codes match — finish setup immediately. Enable biometrics by default when the
                // device supports them: Face ID is the default the user wants, PIN stays the
                // fallback, and Settings lets them turn it off. The previous in-place
                // UIAlertController "offer" could NOT present over this fullScreen pincode flow
                // (Display.ViewController.present routes to the already-busy rootViewController),
                // so it silently failed and hung the confirm step on real devices — removed.
                let hasBiometric = ChatLockBiometricHelper.availableType() != nil
                dismissSelf {
                    onSuccess(self.firstCode, self.chosenType, hasBiometric)
                }
            } else {
                // Mismatch — reset to first entry.
                let msg = (chosenType == .pin)
                    ? FenixuzChatLockStrings.mismatch
                    : FenixuzChatLockStrings.passwordMismatch
                shakeAndReset(isPasswordMode: chosenType == .text, message: msg)
                setupPhase = .enterCredential
                currentStep = .enterNew
            }

        default:
            break
        }
    }

    // MARK: - Biometric offer alert

    private func presentBiometricOffer(type: ChatLockBiometricType, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: FenixuzChatLockStrings.biometricPromptTitle,
            message: FenixuzChatLockStrings.biometricPromptSubtitle(type: type),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: FenixuzChatLockStrings.biometricEnable,
            style: .default
        ) { _ in completion(true) })
        alert.addAction(UIAlertAction(
            title: FenixuzChatLockStrings.biometricSkip,
            style: .cancel
        ) { _ in completion(false) })
        // `self` is a Display.ViewController whose present() routes to the window's
        // rootViewController — which is ALREADY presenting this pincode flow, so the alert
        // silently fails to appear and the confirm step hangs. This surfaces only on real
        // devices (the offer is reached only when biometrics exist; the simulator skips it).
        // Present on the enclosing UIKit navigation controller — the topmost presented
        // controller — instead, mirroring dismissSelf's reason for using navigationController.
        (self.navigationController ?? self).present(alert, animated: true)
    }

    // MARK: - Dot sync

    private func syncDots() {
        let accentColor = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        let isDark = presentationData.theme.overallDarkAppearance
        for (i, dot) in dotViews.enumerated() {
            let filled = i < enteredCode.count
            UIView.animate(withDuration: 0.15) {
                dot.backgroundColor = filled ? accentColor : .clear
                dot.layer.borderColor = filled
                    ? accentColor.cgColor
                    : (isDark
                        ? UIColor(white: 1, alpha: 0.3).cgColor
                        : UIColor(white: 0, alpha: 0.25).cgColor)
                dot.transform = filled ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
            }
        }
    }

    // MARK: - Shake & reset

    private func shakeAndReset(isPasswordMode: Bool, message: String? = nil) {
        let errorMsg = message ?? (isPasswordMode
            ? FenixuzChatLockStrings.wrongPassword
            : FenixuzChatLockStrings.wrongCode)
        subtitleLabel.text = errorMsg
        subtitleLabel.textColor = UIColor(rgb: 0xff3b30)

        let target: UIView = isPasswordMode ? textField : dotsView
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.4
        anim.values = [-10, 10, -8, 8, -5, 5, 0]
        target.layer.add(anim, forKey: "shake")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.enteredCode = ""
            if isPasswordMode {
                self.textField.text = ""
                self.textField.becomeFirstResponder()
            } else {
                self.syncDots()
            }
            self.updateLabels()
        }
    }

    // MARK: - Dismiss

    private func dismissSelf(completion: (() -> Void)? = nil) {
        // ChatPincodeViewController inherits Display.ViewController, whose
        // dismiss(animated:completion:) override silently drops the completion
        // (Display/Source/ViewController.swift:575). Our enclosing controller is a
        // plain UIKit UINavigationController, so dismiss THAT to get UIKit's real
        // completion — otherwise onSuccess (which stores / verifies the pincode)
        // never runs and the lock silently no-ops.
        let captured = completion
        if let navController = self.navigationController {
            navController.dismiss(animated: true) { captured?() }
        } else {
            self.presentingViewController?.dismiss(animated: true) { captured?() }
        }
    }

    // MARK: - Close

    @objc private func closeTapped() {
        dismissSelf()
    }

    // MARK: - Setup phase enum (private)

    private enum SetupPhase {
        case pickType
        case enterCredential
        case confirmCredential
        case offerBiometric
    }
}

// MARK: - UITextFieldDelegate

extension ChatPincodeViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitTapped()
        return false
    }
}
