import Foundation
import UIKit
import Display
import TelegramPresentationData
import FenixuzLocalization

// UserDefaults key to track first-launch state.
// Suite: "pro_messager", key: "fenixuz_tips_shown"
private let kSuiteName = "pro_messager"
private let kTipsShownKey = "fenixuz_tips_shown"

// MARK: - Public API

public final class FenixuzTipsScreen {

    /// Returns true if Tips screen has never been shown on this device.
    public static var shouldShowOnFirstLaunch: Bool {
        let defaults = UserDefaults(suiteName: kSuiteName)
        return !(defaults?.bool(forKey: kTipsShownKey) ?? false)
    }

    /// Mark tips as shown so auto-present never fires again.
    public static func markShown() {
        let defaults = UserDefaults(suiteName: kSuiteName)
        defaults?.set(true, forKey: kTipsShownKey)
    }

    /// Build and return the controller. Caller presents it modally.
    public static func makeController(presentationData: PresentationData) -> UIViewController {
        return FenixuzTipsViewController(presentationData: presentationData)
    }
}

// MARK: - Tip model

private struct Tip {
    let sfSymbol: String   // SF Symbol name
    let title: String
    let body: String
}

private func allTips(l10n: FenixuzL10n) -> [Tip] {
    return [
        Tip(sfSymbol: "eye.slash.fill",
            title: l10n.tips_ghost_title,
            body: l10n.tips_ghost_body),
        Tip(sfSymbol: "mic.fill",
            title: l10n.tips_stt_title,
            body: l10n.tips_stt_body),
        Tip(sfSymbol: "person.2.fill",
            title: l10n.tips_multiAccount_title,
            body: l10n.tips_multiAccount_body),
        Tip(sfSymbol: "clock.arrow.circlepath",
            title: l10n.tips_editedHistory_title,
            body: l10n.tips_editedHistory_body),
        Tip(sfSymbol: "lock.fill",
            title: l10n.tips_chatLock_title,
            body: l10n.tips_chatLock_body),
        Tip(sfSymbol: "text.append",
            title: l10n.tips_autoText_title,
            body: l10n.tips_autoText_body),
        Tip(sfSymbol: "character.bubble.fill",
            title: l10n.tips_translate_title,
            body: l10n.tips_translate_body),
        Tip(sfSymbol: "flame.fill",
            title: l10n.tips_fenixHub_title,
            body: l10n.tips_fenixHub_body),
    ]
}

// MARK: - View controller

private final class FenixuzTipsViewController: UIViewController {

    private let presentationData: PresentationData
    private var tableView: UITableView!
    private var tips: [Tip] = []
    private var closeButton: UIButton!

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        let theme = presentationData.theme
        let l10n = FenixuzL10n(presentationData.strings)
        tips = allTips(l10n: l10n)

        view.backgroundColor = theme.list.plainBackgroundColor

        // Navigation title
        title = l10n.tips_screenTitle
        if let nav = navigationController {
            nav.navigationBar.tintColor = theme.list.itemAccentColor
        }

        // Table
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = theme.list.itemBlocksSeparatorColor
        tableView.dataSource = self
        tableView.register(TipCell.self, forCellReuseIdentifier: TipCell.reuseId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        view.addSubview(tableView)

        // Bottom close button
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle(l10n.tips_closeButton, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        closeButton.backgroundColor = theme.list.itemAccentColor
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 14
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -8),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    @objc private func closeTapped() {
        FenixuzTipsScreen.markShown()
        dismiss(animated: true)
    }
}

extension FenixuzTipsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tips.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TipCell.reuseId, for: indexPath) as! TipCell
        let theme = presentationData.theme
        cell.configure(tip: tips[indexPath.row], theme: theme)
        return cell
    }
}

// MARK: - Tip cell

private final class TipCell: UITableViewCell {
    static let reuseId = "FenixuzTipCell"

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private var didSetupLayout = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
    }

    required init?(coder: NSCoder) { nil }

    func configure(tip: Tip, theme: PresentationTheme) {
        backgroundColor = theme.list.itemBlocksBackgroundColor

        // Icon container — accent-colored rounded square
        if !didSetupLayout {
            didSetupLayout = true

            iconContainer.translatesAutoresizingMaskIntoConstraints = false
            iconContainer.layer.cornerRadius = 10
            iconContainer.clipsToBounds = true
            contentView.addSubview(iconContainer)

            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFit
            iconView.tintColor = .white
            iconContainer.addSubview(iconView)

            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            titleLabel.numberOfLines = 1
            contentView.addSubview(titleLabel)

            bodyLabel.translatesAutoresizingMaskIntoConstraints = false
            bodyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            bodyLabel.numberOfLines = 0
            contentView.addSubview(bodyLabel)

            NSLayoutConstraint.activate([
                iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                iconContainer.widthAnchor.constraint(equalToConstant: 40),
                iconContainer.heightAnchor.constraint(equalToConstant: 40),

                iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 22),
                iconView.heightAnchor.constraint(equalToConstant: 22),

                titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

                bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
                bodyLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
                bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                bodyLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ])
        }

        iconContainer.backgroundColor = theme.list.itemAccentColor
        iconView.image = UIImage(systemName: tip.sfSymbol)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        titleLabel.textColor = theme.list.itemPrimaryTextColor
        titleLabel.text = tip.title
        bodyLabel.textColor = theme.list.itemSecondaryTextColor
        bodyLabel.text = tip.body
    }
}
