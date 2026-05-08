import Foundation
import UIKit
import Display
import TelegramPresentationData

public enum ChatPincodeMode {
    case set(onSuccess: (String) -> Void)
    /// `onVerify` receives the entered code and returns true if it's correct, then `onSuccess` is called
    case verify(onVerify: (String) -> Bool, onSuccess: () -> Void)
    /// `onVerify` receives the entered code and returns true if correct; on success the pincode is removed
    case remove(onVerify: (String) -> Bool, onSuccess: () -> Void)
}

public final class ChatPincodeViewController: ViewController {
    private let mode: ChatPincodeMode
    private let presentationData: PresentationData

    private var enteredCode: String = ""
    private var firstCode: String = ""       // used in .set mode for second confirmation
    private var isConfirming: Bool = false

    // UI
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var dotsView: UIStackView!
    private var dotViews: [UIView] = []
    private var numberPadView: UIView!
    private var closeButton: UIButton!

    public init(mode: ChatPincodeMode, presentationData: PresentationData) {
        self.mode = mode
        self.presentationData = presentationData
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
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
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Dots row
        dotsView = UIStackView()
        dotsView.axis = .horizontal
        dotsView.spacing = 16
        dotsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dotsView)

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

        // Number pad
        numberPadView = buildNumberPad(isDark: isDark)
        numberPadView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(numberPadView)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            dotsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dotsView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),

            numberPadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numberPadView.topAnchor.constraint(equalTo: dotsView.bottomAnchor, constant: 44),
            numberPadView.widthAnchor.constraint(equalToConstant: 280),
            numberPadView.heightAnchor.constraint(equalToConstant: 4 * 76 + 3 * 14),
        ])

        updateUI()
    }

    private func updateUI() {
        let isDark = presentationData.theme.overallDarkAppearance
        let accentColor = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        let emptyDotColor = isDark ? UIColor(white: 1, alpha: 0.15) : UIColor(white: 0, alpha: 0.12)

        for (i, dot) in dotViews.enumerated() {
            let filled = i < enteredCode.count
            dot.backgroundColor = filled ? accentColor : .clear
            dot.layer.borderColor = filled ? accentColor.cgColor : (isDark ? UIColor(white: 1, alpha: 0.3).cgColor : UIColor(white: 0, alpha: 0.25).cgColor)
            let _ = emptyDotColor
        }

        switch mode {
        case .set:
            if isConfirming {
                titleLabel.text = "Tasdiqlang"
                subtitleLabel.text = "Kodni qayta kiriting"
            } else {
                titleLabel.text = "Pincode o'rnating"
                subtitleLabel.text = "4 raqamli kodni kiriting"
            }
        case .verify:
            titleLabel.text = "Pincode kiriting"
            subtitleLabel.text = "Chatni ochish uchun kod kerak"
        case .remove:
            titleLabel.text = "Pincode tasdiqlang"
            subtitleLabel.text = "O'chirish uchun amaldagi kodni kiriting"
        }

        let isDarkSub = presentationData.theme.overallDarkAppearance
        subtitleLabel.textColor = isDarkSub ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.45)
    }

    // MARK: - Number Pad

    private func buildNumberPad(isDark: Bool) -> UIView {
        let container = UIView()
        let buttonSize: CGFloat = 76
        let spacing: CGFloat = 14
        let digits = ["1","2","3","4","5","6","7","8","9","","0","⌫"]

        for (index, label) in digits.enumerated() {
            let row = index / 3
            let col = index % 3

            if label.isEmpty { continue }

            let button = UIButton(type: .custom)
            button.setTitle(label, for: .normal)
            button.titleLabel?.font = label == "⌫" ? .systemFont(ofSize: 24, weight: .medium) : .systemFont(ofSize: 28, weight: .regular)
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

            // Highlight on press
            button.addTarget(self, action: #selector(padPressed(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(padReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

            container.addSubview(button)
        }

        let totalRows = 4
        let h = CGFloat(totalRows) * buttonSize + CGFloat(totalRows - 1) * spacing
        container.frame = CGRect(x: 0, y: 0, width: 3 * buttonSize + 2 * spacing, height: h)
        return container
    }

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
                updateDots()
            }
        } else {
            guard enteredCode.count < 4 else { return }
            enteredCode.append(title)
            updateDots()
            if enteredCode.count == 4 {
                processCode()
            }
        }
    }

    private func updateDots() {
        let accentColor = UIColor(rgb: presentationData.theme.list.itemAccentColor.rgb)
        for (i, dot) in dotViews.enumerated() {
            let filled = i < enteredCode.count
            UIView.animate(withDuration: 0.15) {
                dot.backgroundColor = filled ? accentColor : .clear
                dot.layer.borderColor = filled ? accentColor.cgColor : (self.presentationData.theme.overallDarkAppearance ? UIColor(white: 1, alpha: 0.3).cgColor : UIColor(white: 0, alpha: 0.25).cgColor)
                dot.transform = filled ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
            }
        }
    }

    private func processCode() {
        switch mode {
        case let .set(onSuccess):
            if !isConfirming {
                firstCode = enteredCode
                enteredCode = ""
                isConfirming = true
                updateUI()
                updateDots()
            } else {
                if enteredCode == firstCode {
                    dismissSelf {
                        onSuccess(self.firstCode)
                    }
                } else {
                    shakeAndReset(message: "Kod mos kelmadi")
                }
            }

        case let .verify(onVerify, onSuccess):
            if onVerify(enteredCode) {
                dismissSelf {
                    onSuccess()
                }
            } else {
                shakeAndReset(message: "Noto'g'ri kod")
            }

        case let .remove(onVerify, onSuccess):
            if onVerify(enteredCode) {
                dismissSelf {
                    onSuccess()
                }
            } else {
                shakeAndReset(message: "Noto'g'ri kod")
            }
        }
    }

    private func shakeAndReset(message: String) {
        subtitleLabel.text = message
        subtitleLabel.textColor = UIColor(rgb: 0xff3b30)

        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.4
        anim.values = [-10, 10, -8, 8, -5, 5, 0]
        dotsView.layer.add(anim, forKey: "shake")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.enteredCode = ""
            self?.isConfirming = false
            self?.firstCode = ""
            self?.updateUI()
            self?.updateDots()
        }
    }

    private func dismissSelf(completion: (() -> Void)? = nil) {
        dismiss(animated: true, completion: completion)
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }

    @objc private func closeTapped() {
        dismissSelf()
    }
}
