import Foundation
import UIKit
import TelegramPresentationData
import AvatarNode

/// One row of the Call recordings list, laid out like a row of Telegram's call log: an avatar with the peer's
/// initials and a call-kind badge, the name over "Video call · 0:40", and the time over the file size on the right.
/// Self-sizing (Auto Layout), so larger text grows the row instead of overlapping the lines.
final class NovagramCallRecordingCell: UITableViewCell {
    struct Content {
        let name: String
        let subtitle: String
        let time: String
        let size: String
        let isVideo: Bool
    }

    static let reuseId = "recording"

    private static let avatarSize: CGFloat = 40.0
    private static let badgeSize: CGFloat = 18.0
    private static let badgeRing: CGFloat = 1.5
    private static let badgeGlyphSize: CGFloat = 8.0
    private static let leadingInset: CGFloat = 16.0
    private static let avatarTextSpacing: CGFloat = 12.0
    private static let columnSpacing: CGFloat = 8.0
    private static let verticalInset: CGFloat = 10.0
    private static let lineSpacing: CGFloat = 2.0
    private static let minHeight: CGFloat = 60.0
    private static let initialsFontSize: CGFloat = 16.0

    /// Where the text starts, so the separator can line up with it.
    static let textInset: CGFloat = leadingInset + avatarSize + avatarTextSpacing

    private let avatarView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let initialsLabel = UILabel()
    private let badgeView = UIView()
    private let badgeIcon = UIImageView()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let sizeLabel = UILabel()
    private let detailLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupAvatar()
        self.setupLabels()
        self.setupConstraints()
        self.separatorInset = UIEdgeInsets(top: 0.0, left: NovagramCallRecordingCell.textInset, bottom: 0.0, right: 0.0)
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.gradientLayer.frame = self.avatarView.bounds
    }

    func update(content: Content, theme: PresentationTheme) {
        let list = theme.list
        let colors = AvatarNode.gradientColors
        let index = NovagramCallRecordingName.colorIndex(of: content.name, count: colors.count)
        if index < colors.count {
            self.gradientLayer.colors = colors[index].map(\.cgColor)
        }
        self.initialsLabel.text = NovagramCallRecordingName.initials(of: content.name)

        self.badgeView.backgroundColor = list.itemAccentColor
        self.badgeView.layer.borderColor = list.itemBlocksBackgroundColor.cgColor
        let glyph = UIImage.SymbolConfiguration(pointSize: NovagramCallRecordingCell.badgeGlyphSize, weight: .bold)
        self.badgeIcon.image = UIImage(systemName: content.isVideo ? "video.fill" : "waveform", withConfiguration: glyph)

        // Accessibility text sizes: the right-hand column would squeeze the name to a few letters, so the time and
        // size move to a third line under the subtitle and the name gets the full width.
        let isLarge = self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        self.titleLabel.text = content.name
        self.subtitleLabel.text = content.subtitle
        self.timeLabel.text = isLarge ? nil : content.time
        self.sizeLabel.text = isLarge ? nil : content.size
        self.detailLabel.text = "\(content.time) · \(content.size)"
        self.detailLabel.isHidden = !isLarge
        self.detailLabel.textColor = list.itemSecondaryTextColor
        self.titleLabel.textColor = list.itemPrimaryTextColor
        self.subtitleLabel.textColor = list.itemSecondaryTextColor
        self.timeLabel.textColor = list.itemSecondaryTextColor
        self.sizeLabel.textColor = list.itemSecondaryTextColor
        self.titleLabel.numberOfLines = isLarge ? 0 : 1

        self.backgroundColor = list.itemBlocksBackgroundColor
        let selected = UIView()
        selected.backgroundColor = list.itemHighlightedBackgroundColor
        self.selectedBackgroundView = selected
    }

    // MARK: - Setup

    private func setupAvatar() {
        let avatarSize = NovagramCallRecordingCell.avatarSize
        let badgeSize = NovagramCallRecordingCell.badgeSize
        self.avatarView.layer.cornerRadius = avatarSize / 2.0
        self.avatarView.clipsToBounds = true
        self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.avatarView.layer.addSublayer(self.gradientLayer)

        self.initialsLabel.font = UIFont.systemFont(ofSize: NovagramCallRecordingCell.initialsFontSize, weight: .semibold)
        self.initialsLabel.textColor = .white
        self.initialsLabel.textAlignment = .center
        self.avatarView.addSubview(self.initialsLabel)

        self.badgeView.layer.cornerRadius = badgeSize / 2.0
        self.badgeView.layer.borderWidth = NovagramCallRecordingCell.badgeRing
        self.badgeIcon.tintColor = .white
        self.badgeIcon.contentMode = .center
        self.badgeView.addSubview(self.badgeIcon)

        for view in [self.avatarView, self.badgeView] {
            view.isAccessibilityElement = false
            self.contentView.addSubview(view)
        }
    }

    private func setupLabels() {
        self.titleLabel.font = NovagramCallRecordingCell.scaledFont(.body, size: 17.0, weight: .semibold)
        self.subtitleLabel.font = NovagramCallRecordingCell.scaledFont(.subheadline, size: 15.0, weight: .regular, monospacedDigits: true)
        self.timeLabel.font = NovagramCallRecordingCell.scaledFont(.subheadline, size: 15.0, weight: .regular, monospacedDigits: true)
        self.sizeLabel.font = NovagramCallRecordingCell.scaledFont(.caption1, size: 12.0, weight: .regular, monospacedDigits: true)
        self.detailLabel.font = NovagramCallRecordingCell.scaledFont(.subheadline, size: 15.0, weight: .regular, monospacedDigits: true)
        self.subtitleLabel.numberOfLines = 0
        self.detailLabel.numberOfLines = 0
        self.timeLabel.textAlignment = .right
        self.sizeLabel.textAlignment = .right
        for label in [self.titleLabel, self.subtitleLabel, self.timeLabel, self.sizeLabel, self.detailLabel] {
            label.adjustsFontForContentSizeCategory = true
        }
        self.textStack.axis = .vertical
        self.textStack.alignment = .leading
        self.textStack.spacing = NovagramCallRecordingCell.lineSpacing
        self.textStack.addArrangedSubview(self.titleLabel)
        self.textStack.addArrangedSubview(self.subtitleLabel)
        self.textStack.addArrangedSubview(self.detailLabel)
        self.contentView.addSubview(self.textStack)
        self.contentView.addSubview(self.timeLabel)
        self.contentView.addSubview(self.sizeLabel)
    }

    private static func scaledFont(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight, monospacedDigits: Bool = false) -> UIFont {
        let base = monospacedDigits ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    private func setupConstraints() {
        let views = [self.avatarView, self.initialsLabel, self.badgeView, self.badgeIcon, self.textStack, self.timeLabel, self.sizeLabel]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let content = self.contentView
        let inset = NovagramCallRecordingCell.verticalInset
        let minHeight = content.heightAnchor.constraint(greaterThanOrEqualToConstant: NovagramCallRecordingCell.minHeight)
        minHeight.priority = .required - 1

        // The trailing column keeps its full width; the name is the one that gets cut.
        for label in [self.timeLabel, self.sizeLabel] {
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
        }
        self.titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate(self.avatarConstraints() + [
            minHeight,
            // The rows are at least 60 pt; taller text grows them, centred, with 10 pt above and below.
            self.textStack.leadingAnchor.constraint(equalTo: self.avatarView.trailingAnchor, constant: NovagramCallRecordingCell.avatarTextSpacing),
            self.textStack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            self.textStack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: inset),
            self.textStack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -inset),
            self.textStack.trailingAnchor.constraint(lessThanOrEqualTo: content.layoutMarginsGuide.trailingAnchor),
            self.titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.timeLabel.leadingAnchor, constant: -NovagramCallRecordingCell.columnSpacing),
            self.subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.sizeLabel.leadingAnchor, constant: -NovagramCallRecordingCell.columnSpacing),

            self.timeLabel.trailingAnchor.constraint(equalTo: content.layoutMarginsGuide.trailingAnchor),
            self.timeLabel.firstBaselineAnchor.constraint(equalTo: self.titleLabel.firstBaselineAnchor),
            self.sizeLabel.trailingAnchor.constraint(equalTo: self.timeLabel.trailingAnchor),
            self.sizeLabel.firstBaselineAnchor.constraint(equalTo: self.subtitleLabel.firstBaselineAnchor),
            self.sizeLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -inset)
        ])
    }

    private func avatarConstraints() -> [NSLayoutConstraint] {
        let content = self.contentView
        let avatarSize = NovagramCallRecordingCell.avatarSize
        let badgeSize = NovagramCallRecordingCell.badgeSize
        // The badge's centre sits on the avatar's circle at the bottom-right (45 degrees).
        let badgeOffset = avatarSize / 2.0 * (1.0 + 1.0 / 2.0.squareRoot()) - badgeSize / 2.0
        return [
            self.avatarView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: NovagramCallRecordingCell.leadingInset),
            self.avatarView.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            self.avatarView.widthAnchor.constraint(equalToConstant: avatarSize),
            self.avatarView.heightAnchor.constraint(equalToConstant: avatarSize),
            self.avatarView.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: NovagramCallRecordingCell.verticalInset),
            self.initialsLabel.centerXAnchor.constraint(equalTo: self.avatarView.centerXAnchor),
            self.initialsLabel.centerYAnchor.constraint(equalTo: self.avatarView.centerYAnchor),
            self.badgeView.widthAnchor.constraint(equalToConstant: badgeSize),
            self.badgeView.heightAnchor.constraint(equalToConstant: badgeSize),
            self.badgeView.leadingAnchor.constraint(equalTo: self.avatarView.leadingAnchor, constant: badgeOffset),
            self.badgeView.topAnchor.constraint(equalTo: self.avatarView.topAnchor, constant: badgeOffset),
            self.badgeIcon.centerXAnchor.constraint(equalTo: self.badgeView.centerXAnchor),
            self.badgeIcon.centerYAnchor.constraint(equalTo: self.badgeView.centerYAnchor)
        ]
    }
}
