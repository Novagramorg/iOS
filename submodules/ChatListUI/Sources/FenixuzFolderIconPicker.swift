import Foundation
import UIKit
import Display
import TelegramPresentationData

// FENIX-HOOK #18 — Folder icon picker (LOCAL, grid). Stores nothing itself; reports the
// chosen emoji (or nil = remove) via onIconSelected. Storage is local UserDefaults, handled
// by the caller (ChatListFilterPresetController) — no server/premium dependency.

let fenixFolderIcons: [String] = [
    "💬", "👤", "👥", "📢", "🤖",
    "⭐️", "💼", "📚", "🎮", "❤️",
    "✈️", "🏠", "📌", "✅", "🎯",
    "🔔", "📷", "🎵", "🎁", "⚽️",
    "🍔", "💰", "🌙", "🔐", "🌿"
]

private final class FenixuzFolderIconCell: UICollectionViewCell {
    static let reuseId = "FenixuzFolderIconCell"

    private let selectionView = UIView()
    private let emojiLabel = UILabel()
    private let removeImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.selectionView.layer.cornerRadius = 16.0
        self.selectionView.layer.borderWidth = 2.5
        self.selectionView.isUserInteractionEnabled = false
        self.selectionView.isHidden = true
        self.contentView.addSubview(self.selectionView)

        self.emojiLabel.font = UIFont.systemFont(ofSize: 34.0)
        self.emojiLabel.textAlignment = .center
        self.contentView.addSubview(self.emojiLabel)

        self.removeImageView.contentMode = .center
        self.removeImageView.isHidden = true
        self.contentView.addSubview(self.removeImageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.selectionView.frame = self.contentView.bounds
        self.emojiLabel.frame = self.contentView.bounds
        self.removeImageView.frame = self.contentView.bounds
    }

    func configure(emoji: String?, isSelected: Bool, theme: PresentationTheme) {
        if let emoji = emoji {
            self.emojiLabel.text = emoji
            self.emojiLabel.isHidden = false
            self.removeImageView.isHidden = true
            self.selectionView.layer.borderColor = theme.list.itemAccentColor.cgColor
            self.selectionView.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.12)
        } else {
            self.emojiLabel.isHidden = true
            self.removeImageView.isHidden = false
            let config = UIImage.SymbolConfiguration(pointSize: 28.0)
            self.removeImageView.image = UIImage(systemName: "xmark.circle", withConfiguration: config)?.withTintColor(theme.list.itemSecondaryTextColor, renderingMode: .alwaysOriginal)
            self.selectionView.layer.borderColor = theme.list.itemSecondaryTextColor.cgColor
            self.selectionView.backgroundColor = theme.list.itemSecondaryTextColor.withAlphaComponent(0.12)
        }
        self.selectionView.isHidden = !isSelected
    }
}

public final class FenixuzFolderIconPickerController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let presentationData: PresentationData
    private let currentIcon: String?
    public var onIconSelected: ((String?) -> Void)?

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let separator = UIView()
    private var collectionView: UICollectionView!
    private let hapticFeedback = HapticFeedback()

    public init(presentationData: PresentationData, currentIcon: String?) {
        self.presentationData = presentationData
        self.currentIcon = currentIcon
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = self.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 12.0
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        let theme = self.presentationData.theme
        self.view.backgroundColor = theme.list.plainBackgroundColor

        let titleText: String
        switch self.presentationData.strings.primaryComponent.languageCode {
        case "uz": titleText = "Papka belgisi"
        case "ru": titleText = "Значок папки"
        default:   titleText = "Folder Icon"
        }
        self.titleLabel.text = titleText
        self.titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.titleLabel.textAlignment = .center
        self.view.addSubview(self.titleLabel)

        let config = UIImage.SymbolConfiguration(pointSize: 28.0)
        self.closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        self.closeButton.tintColor = theme.list.itemSecondaryTextColor
        self.closeButton.addTarget(self, action: #selector(self.closeTapped), for: .touchUpInside)
        self.view.addSubview(self.closeButton)

        self.separator.backgroundColor = theme.list.itemBlocksSeparatorColor
        self.view.addSubview(self.separator)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 64.0, height: 64.0)
        layout.minimumInteritemSpacing = 8.0
        layout.minimumLineSpacing = 8.0
        layout.sectionInset = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 16.0, right: 16.0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FenixuzFolderIconCell.self, forCellWithReuseIdentifier: FenixuzFolderIconCell.reuseId)
        self.view.addSubview(collectionView)
        self.collectionView = collectionView
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = self.view.bounds.width
        self.titleLabel.frame = CGRect(x: 50.0, y: 16.0, width: max(0.0, width - 100.0), height: 24.0)
        self.closeButton.frame = CGRect(x: width - 44.0 - 8.0, y: 13.0, width: 44.0, height: 30.0)
        self.separator.frame = CGRect(x: 0.0, y: 54.0, width: width, height: 1.0 / UIScreen.main.scale)
        self.collectionView.frame = CGRect(x: 0.0, y: 55.0, width: width, height: max(0.0, self.view.bounds.height - 55.0))
        self.collectionView.contentInset.bottom = self.view.safeAreaInsets.bottom + 16.0
    }

    @objc private func closeTapped() {
        self.dismiss(animated: true)
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fenixFolderIcons.count + 1
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FenixuzFolderIconCell.reuseId, for: indexPath) as! FenixuzFolderIconCell
        if indexPath.item == 0 {
            cell.configure(emoji: nil, isSelected: self.currentIcon == nil, theme: self.presentationData.theme)
        } else {
            let emoji = fenixFolderIcons[indexPath.item - 1]
            cell.configure(emoji: emoji, isSelected: self.currentIcon == emoji, theme: self.presentationData.theme)
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.hapticFeedback.tap()
        let selected: String? = indexPath.item == 0 ? nil : fenixFolderIcons[indexPath.item - 1]
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }, completion: { _ in
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = .identity
                })
            })
        }
        self.onIconSelected?(selected)
        self.dismiss(animated: true)
    }
}
