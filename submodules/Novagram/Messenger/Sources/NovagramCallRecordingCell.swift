import Foundation
import UIKit
import Display
import TelegramPresentationData
import AvatarNode

/// One row of the Call recordings list, laid out like a row of Telegram's call log: an avatar with the peer's
/// initials, the name over "Video call · 0:40 · 1.2 MB", and the time on the right. The fonts follow Telegram's
/// own text size (`listsFontSize`, like `CallListCallItem`), not the system's Dynamic Type directly.
/// Self-sizing (Auto Layout), so larger text grows the row instead of overlapping the lines.
final class NovagramCallRecordingCell: UITableViewCell {
    struct Content {
        let name: String
        let subtitle: String
        let time: String
    }

    static let reuseId = "recording"

    private static let avatarSize: CGFloat = 40.0
    private static let leadingInset: CGFloat = 16.0
    private static let trailingSeparatorInset: CGFloat = 16.0
    private static let avatarTextSpacing: CGFloat = 12.0
    private static let columnSpacing: CGFloat = 8.0
    private static let verticalInset: CGFloat = 10.0
    private static let lineSpacing: CGFloat = 2.0
    private static let minHeight: CGFloat = 60.0
    private static let initialsFontSize: CGFloat = 16.0
    // Telegram's call log sizes its lines from the list base size (17 pt by default).
    private static let referenceFontSize: CGFloat = 17.0
    private static let subtitleFontSize: CGFloat = 14.0
    private static let timeFontSize: CGFloat = 15.0
    /// From this Telegram base size the row is treated as an accessibility size (avatar top-aligned, time below).
    private static let largeBaseFontSize: CGFloat = 24.0

    /// Where the text starts, so the separator can line up with it.
    static let textInset: CGFloat = leadingInset + avatarSize + avatarTextSpacing

    private let avatarView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let initialsLabel = UILabel()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let detailLabel = UILabel()

    private var avatarCenterConstraint: NSLayoutConstraint?
    private var avatarTopConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupAvatar()
        self.setupLabels()
        self.setupConstraints()
        self.separatorInset = UIEdgeInsets(top: 0.0, left: NovagramCallRecordingCell.textInset, bottom: 0.0, right: NovagramCallRecordingCell.trailingSeparatorInset)
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.gradientLayer.frame = self.avatarView.bounds
        // While selecting, the content moves right to make room for the checkmark; the separator follows the text.
        let separatorLeft = self.contentView.frame.minX + NovagramCallRecordingCell.textInset
        if self.separatorInset.left != separatorLeft {
            self.separatorInset.left = separatorLeft
        }
    }

    func update(content: Content, theme: PresentationTheme, baseFontSize: CGFloat) {
        let list = theme.list
        let colors = AvatarNode.gradientColors
        let index = NovagramCallRecordingName.colorIndex(of: content.name, count: colors.count)
        if index < colors.count {
            self.gradientLayer.colors = colors[index].map(\.cgColor)
        }
        self.initialsLabel.text = NovagramCallRecordingName.initials(of: content.name)

        let reference = NovagramCallRecordingCell.referenceFontSize
        let titleFont = Font.medium(baseFontSize)
        let subtitleFont = Font.regular(floor(baseFontSize * NovagramCallRecordingCell.subtitleFontSize / reference))
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: floor(baseFontSize * NovagramCallRecordingCell.timeFontSize / reference), weight: .regular)
        self.titleLabel.font = titleFont
        self.subtitleLabel.font = subtitleFont
        self.timeLabel.font = timeFont
        self.detailLabel.font = timeFont

        // Accessibility text sizes: the right-hand column would squeeze the name to a few letters, so the time moves
        // to a third line, the name gets the full width, and the avatar sits at the top next to the name.
        let isLarge = self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory || baseFontSize >= NovagramCallRecordingCell.largeBaseFontSize
        self.titleLabel.text = content.name
        self.subtitleLabel.text = content.subtitle
        self.timeLabel.text = isLarge ? nil : content.time
        self.timeLabel.isHidden = isLarge
        self.detailLabel.text = content.time
        self.detailLabel.isHidden = !isLarge
        self.titleLabel.numberOfLines = isLarge ? 0 : 1
        self.avatarCenterConstraint?.isActive = !isLarge
        self.avatarTopConstraint?.isActive = isLarge

        self.titleLabel.textColor = list.itemPrimaryTextColor
        self.subtitleLabel.textColor = list.itemSecondaryTextColor
        self.timeLabel.textColor = list.itemSecondaryTextColor
        self.detailLabel.textColor = list.itemSecondaryTextColor
        self.tintColor = list.itemAccentColor

        self.backgroundColor = list.itemBlocksBackgroundColor
        let selected = UIView()
        selected.backgroundColor = list.itemHighlightedBackgroundColor
        self.selectedBackgroundView = selected
        // While selecting, a selected row shows only its checkmark, like Telegram's lists, not a grey fill.
        let multipleSelected = UIView()
        multipleSelected.backgroundColor = list.itemBlocksBackgroundColor
        self.multipleSelectionBackgroundView = multipleSelected
    }

    // MARK: - Setup

    private func setupAvatar() {
        self.avatarView.layer.cornerRadius = NovagramCallRecordingCell.avatarSize / 2.0
        self.avatarView.clipsToBounds = true
        self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        self.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        self.avatarView.layer.addSublayer(self.gradientLayer)

        self.initialsLabel.font = UIFont.systemFont(ofSize: NovagramCallRecordingCell.initialsFontSize, weight: .semibold)
        self.initialsLabel.textColor = .white
        self.initialsLabel.textAlignment = .center
        self.avatarView.addSubview(self.initialsLabel)

        self.avatarView.isAccessibilityElement = false
        self.contentView.addSubview(self.avatarView)
    }

    private func setupLabels() {
        self.subtitleLabel.numberOfLines = 0
        self.detailLabel.numberOfLines = 0
        self.timeLabel.textAlignment = .right
        for label in [self.titleLabel, self.subtitleLabel, self.timeLabel, self.detailLabel] {
            label.adjustsFontForContentSizeCategory = false
        }
        self.textStack.axis = .vertical
        self.textStack.alignment = .leading
        self.textStack.spacing = NovagramCallRecordingCell.lineSpacing
        self.textStack.addArrangedSubview(self.titleLabel)
        self.textStack.addArrangedSubview(self.subtitleLabel)
        self.textStack.addArrangedSubview(self.detailLabel)
        self.contentView.addSubview(self.textStack)
        self.contentView.addSubview(self.timeLabel)
    }

    private func setupConstraints() {
        let views = [self.avatarView, self.initialsLabel, self.textStack, self.timeLabel]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let content = self.contentView
        let inset = NovagramCallRecordingCell.verticalInset
        let minHeight = content.heightAnchor.constraint(greaterThanOrEqualToConstant: NovagramCallRecordingCell.minHeight)
        minHeight.priority = .required - 1

        // The time keeps its full width; the name is the one that gets cut.
        self.timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let avatarSize = NovagramCallRecordingCell.avatarSize
        let avatarCenter = self.avatarView.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        let avatarTop = self.avatarView.topAnchor.constraint(equalTo: self.textStack.topAnchor)
        self.avatarCenterConstraint = avatarCenter
        self.avatarTopConstraint = avatarTop

        NSLayoutConstraint.activate([
            minHeight,
            avatarCenter,
            self.avatarView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: NovagramCallRecordingCell.leadingInset),
            self.avatarView.widthAnchor.constraint(equalToConstant: avatarSize),
            self.avatarView.heightAnchor.constraint(equalToConstant: avatarSize),
            self.avatarView.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: inset),
            self.avatarView.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -inset),
            self.initialsLabel.centerXAnchor.constraint(equalTo: self.avatarView.centerXAnchor),
            self.initialsLabel.centerYAnchor.constraint(equalTo: self.avatarView.centerYAnchor),

            // The rows are at least 60 pt; taller text grows them, centred, with 10 pt above and below.
            self.textStack.leadingAnchor.constraint(equalTo: self.avatarView.trailingAnchor, constant: NovagramCallRecordingCell.avatarTextSpacing),
            self.textStack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            self.textStack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: inset),
            self.textStack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -inset),
            self.textStack.trailingAnchor.constraint(lessThanOrEqualTo: content.layoutMarginsGuide.trailingAnchor),
            self.titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.timeLabel.leadingAnchor, constant: -NovagramCallRecordingCell.columnSpacing),

            self.timeLabel.trailingAnchor.constraint(equalTo: content.layoutMarginsGuide.trailingAnchor),
            self.timeLabel.firstBaselineAnchor.constraint(equalTo: self.titleLabel.firstBaselineAnchor)
        ])
    }
}
