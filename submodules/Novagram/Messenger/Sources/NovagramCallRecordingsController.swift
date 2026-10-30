import Foundation
import UIKit
import QuickLook
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import TextFormat
import NovagramLocalization
import NovagramCallRecording

/// Novagram Settings → Calls → Call recordings (HOOKS.md, "Call recording"): the files in the app's call recordings
/// folder, newest first, grouped by day like Telegram's call log. A tap opens Quick Look (plays audio and video);
/// swipe or long-press to share or delete (delete asks first). A plain table in the grouped settings style, because
/// the list needs swipe actions, which the ItemList rows without a peer do not have.
public func novagramCallRecordingsController(context: AccountContext) -> ViewController {
    return NovagramCallRecordingsController(context: context)
}

/// App termination (`applicationWillTerminate`): finishes every running call recording, waiting up to 3 s, the same
/// idea as the Mac's `stopForQuit`. A file not finished in time is recovered on the next launch.
public enum NovagramCallRecordingTermination {
    private static let timeout: Double = 3.0
    private static let waitMargin: Double = 0.2

    public static func stopAll() {
        let semaphore = DispatchSemaphore(value: 0)
        NovagramCallRecordingCenter.shared.stopAll(timeout: self.timeout, completion: {
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: .now() + self.timeout + self.waitMargin)
    }
}

private final class NovagramCallRecordingsController: ViewController, UITableViewDataSource, UITableViewDelegate, QLPreviewControllerDataSource {
    private typealias Recording = NovagramCallRecordingStorage.Recording

    /// The recordings of one calendar day, newest first.
    private struct DaySection {
        let day: Date
        var recordings: [Recording]
    }

    private static let headerId = "day"
    private static let estimatedRowHeight: CGFloat = 60.0
    private static let headerFontSize: CGFloat = 13.0
    private static let summaryTopInset: CGFloat = 16.0
    private static let summaryBottomInset: CGFloat = 0.0
    private static let summaryTextInset: CGFloat = 16.0
    private static let emptyIconSize: CGFloat = 44.0
    private static let emptyMaxWidth: CGFloat = 300.0
    private static let emptyIconSpacing: CGFloat = 12.0
    private static let emptyTextSpacing: CGFloat = 6.0
    private static let emptySideMargin: CGFloat = 32.0
    private static let emptyVerticalPosition: CGFloat = 0.4
    private static let secondsPerHour = 3600
    private static let secondsPerMinute = 60

    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var contentSizeObserver: NSObjectProtocol?

    private var sections: [DaySection] = []
    private var previewURL: URL?

    private var tableView: UITableView?
    private var didSetInitialOffset = false
    private var lastLayout: ContainerViewLayout?
    private let summaryContainer = UIView()
    private let summaryLabel = UILabel()
    private let emptyView = UIView()
    private let emptyIcon = UIImageView()
    private let emptyTitle = UILabel()
    private let emptyText = UILabel()

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = NovagramL10n(self.presentationData.strings).settings_callRecordings_title

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self, presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings else {
                return
            }
            self.presentationData = presentationData
            self.updateThemeAndStrings()
        })
        // Larger text changes the summary and empty-state heights, which are laid out by hand.
        // The labels pick up the new font after this notification, so measure on the next main-queue turn.
        self.contentSizeObserver = NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            Queue.mainQueue().justDispatch {
                self?.tableView?.reloadData()
                self?.layoutAuxiliaryViews()
            }
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
        if let contentSizeObserver = self.contentSizeObserver {
            NotificationCenter.default.removeObserver(contentSizeObserver)
        }
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()

        let tableView = UITableView(frame: CGRect(), style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = NovagramCallRecordingsController.estimatedRowHeight
        tableView.register(NovagramCallRecordingCell.self, forCellReuseIdentifier: NovagramCallRecordingCell.reuseId)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: NovagramCallRecordingsController.headerId)
        tableView.contentInsetAdjustmentBehavior = .never
        self.tableView = tableView
        self.displayNode.view.addSubview(tableView)

        self.summaryLabel.numberOfLines = 0
        self.summaryLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: UIFont.systemFont(ofSize: NovagramCallRecordingsController.headerFontSize))
        self.summaryLabel.adjustsFontForContentSizeCategory = true
        self.summaryContainer.addSubview(self.summaryLabel)

        self.setupEmptyState()
        self.displayNode.view.addSubview(self.emptyView)

        self.updateThemeAndStrings()
        self.reload()
    }

    private func setupEmptyState() {
        let iconConfiguration = UIImage.SymbolConfiguration(pointSize: NovagramCallRecordingsController.emptyIconSize, weight: .regular)
        self.emptyIcon.image = UIImage(systemName: "record.circle", withConfiguration: iconConfiguration)
        self.emptyIcon.isAccessibilityElement = false
        self.emptyTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        self.emptyText.font = UIFont.preferredFont(forTextStyle: .subheadline)
        for label in [self.emptyTitle, self.emptyText] {
            label.numberOfLines = 0
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
        }
        self.emptyView.isUserInteractionEnabled = false
        self.emptyView.addSubview(self.emptyIcon)
        self.emptyView.addSubview(self.emptyTitle)
        self.emptyView.addSubview(self.emptyText)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A call may have saved a new recording while this screen was in the stack.
        self.reload()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.lastLayout = layout
        let topInset = self.navigationLayout(layout: layout).navigationFrame.maxY
        if let tableView = self.tableView {
            tableView.frame = CGRect(origin: CGPoint(), size: layout.size)
            tableView.contentInset = UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
            tableView.scrollIndicatorInsets = tableView.contentInset
            if !self.didSetInitialOffset {
                self.didSetInitialOffset = true
                tableView.contentOffset = CGPoint(x: 0.0, y: -topInset)
            }
        }
        self.layoutAuxiliaryViews()
    }

    private func layoutAuxiliaryViews() {
        guard let layout = self.lastLayout else {
            return
        }
        self.layoutSummary()
        self.layoutEmptyState(layout: layout, topInset: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    /// "4 recordings · 24.6 MB · stored only on this iPhone", in the footer-text style, lined up with the section headers.
    private func layoutSummary() {
        guard let tableView = self.tableView, !self.sections.isEmpty else {
            self.tableView?.tableHeaderView = nil
            return
        }
        tableView.layoutIfNeeded()
        let textInset = NovagramCallRecordingsController.summaryTextInset
        let left = tableView.layoutMargins.left + textInset
        let width = max(0.0, tableView.bounds.width - left - tableView.layoutMargins.right - textInset)
        let height = ceil(self.summaryLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        let top = NovagramCallRecordingsController.summaryTopInset
        self.summaryLabel.frame = CGRect(x: left, y: top, width: width, height: height)
        self.summaryContainer.frame = CGRect(x: 0.0, y: 0.0, width: tableView.bounds.width, height: top + height + NovagramCallRecordingsController.summaryBottomInset)
        tableView.tableHeaderView = self.summaryContainer
    }

    private func layoutEmptyState(layout: ContainerViewLayout, topInset: CGFloat) {
        let sideMargin = NovagramCallRecordingsController.emptySideMargin
        let contentWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right
        let width = max(0.0, min(NovagramCallRecordingsController.emptyMaxWidth, contentWidth - sideMargin * 2.0))
        let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
        let iconSize = self.emptyIcon.image?.size ?? CGSize()
        let titleHeight = ceil(self.emptyTitle.sizeThatFits(fitting).height)
        let textHeight = ceil(self.emptyText.sizeThatFits(fitting).height)
        let iconSpacing = NovagramCallRecordingsController.emptyIconSpacing
        let textSpacing = NovagramCallRecordingsController.emptyTextSpacing
        let total = iconSize.height + iconSpacing + titleHeight + textSpacing + textHeight
        let available = layout.size.height - topInset - layout.intrinsicInsets.bottom
        let x = layout.safeInsets.left + floor((contentWidth - width) / 2.0)
        var y = topInset + max(0.0, floor((available - total) * NovagramCallRecordingsController.emptyVerticalPosition))

        self.emptyView.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.emptyIcon.frame = CGRect(x: x + floor((width - iconSize.width) / 2.0), y: y, width: iconSize.width, height: iconSize.height)
        y += iconSize.height + iconSpacing
        self.emptyTitle.frame = CGRect(x: x, y: y, width: width, height: titleHeight)
        y += titleHeight + textSpacing
        self.emptyText.frame = CGRect(x: x, y: y, width: width, height: textHeight)
    }

    private func updateThemeAndStrings() {
        let theme = self.presentationData.theme
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        let l10n = NovagramL10n(self.presentationData.strings)
        self.title = l10n.settings_callRecordings_title
        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView?.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView?.separatorColor = theme.list.itemBlocksSeparatorColor
        self.summaryLabel.textColor = theme.list.freeTextColor
        self.emptyIcon.tintColor = theme.list.itemSecondaryTextColor
        self.emptyTitle.textColor = theme.list.itemPrimaryTextColor
        self.emptyText.textColor = theme.list.itemSecondaryTextColor
        self.emptyTitle.text = l10n.callRecordings_emptyTitle
        self.emptyText.text = l10n.callRecordings_emptyText
        self.updateSummary()
        self.tableView?.reloadData()
        self.layoutAuxiliaryViews()
    }

    private func reload() {
        self.sections = NovagramCallRecordingsController.group(NovagramCallRecordingStorage.list())
        self.updateSummary()
        self.tableView?.reloadData()
        self.layoutAuxiliaryViews()
    }

    private func updateSummary() {
        let recordings = self.sections.flatMap { $0.recordings }
        let totalSize = recordings.reduce(Int64(0)) { $0 + $1.size }
        self.summaryLabel.text = NovagramL10n(self.presentationData.strings).callRecordings_summary(count: recordings.count, size: self.sizeString(totalSize))
        self.emptyView.isHidden = !recordings.isEmpty
    }

    private static func group(_ recordings: [Recording]) -> [DaySection] {
        let calendar = Calendar.current
        var result: [DaySection] = []
        for recording in recordings {
            let day = calendar.startOfDay(for: recording.date)
            if let last = result.last, last.day == day {
                result[result.count - 1].recordings.append(recording)
            } else {
                result.append(DaySection(day: day, recordings: [recording]))
            }
        }
        return result
    }

    private func recording(at indexPath: IndexPath) -> Recording? {
        guard indexPath.section < self.sections.count, indexPath.row < self.sections[indexPath.section].recordings.count else {
            return nil
        }
        return self.sections[indexPath.section].recordings[indexPath.row]
    }

    private func indexPath(of url: URL) -> IndexPath? {
        for (sectionIndex, section) in self.sections.enumerated() {
            if let row = section.recordings.firstIndex(where: { $0.url == url }) {
                return IndexPath(row: row, section: sectionIndex)
            }
        }
        return nil
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section < self.sections.count ? self.sections[section].recordings.count : 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < self.sections.count else {
            return nil
        }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: NovagramCallRecordingsController.headerId)
        var content = UIListContentConfiguration.groupedHeader()
        content.text = self.dayTitle(self.sections[section].day)
        content.textProperties.color = self.presentationData.theme.list.sectionHeaderTextColor
        content.textProperties.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: UIFont.systemFont(ofSize: NovagramCallRecordingsController.headerFontSize))
        content.textProperties.transform = .uppercase
        view?.contentConfiguration = content
        return view
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NovagramCallRecordingCell.reuseId, for: indexPath)
        guard let cell = cell as? NovagramCallRecordingCell, let recording = self.recording(at: indexPath) else {
            return cell
        }
        let l10n = NovagramL10n(self.presentationData.strings)
        let name = NovagramCallRecordingName.peerName(fromFileName: recording.url.deletingPathExtension().lastPathComponent)
        let kind = recording.isVideo ? l10n.callRecordings_videoCall : l10n.callRecordings_voiceCall
        let size = self.sizeString(recording.size)
        cell.update(content: NovagramCallRecordingCell.Content(
            name: name,
            subtitle: "\(kind) · \(NovagramCallRecordingsController.durationString(recording.duration))",
            time: self.timeString(recording.date),
            size: size,
            isVideo: recording.isVideo
        ), theme: self.presentationData.theme)
        cell.accessibilityLabel = [name, kind, self.spokenDuration(recording.duration), self.spokenDate(recording.date), size].joined(separator: ", ")
        cell.accessibilityCustomActions = self.accessibilityActions(url: recording.url)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let recording = self.recording(at: indexPath) else {
            return
        }
        self.play(recording.url)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let recording = self.recording(at: indexPath) else {
            return nil
        }
        let url = recording.url
        let strings = self.presentationData.strings
        let delete = UIContextualAction(style: .destructive, title: strings.Common_Delete, handler: { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            self.confirmDelete(url, completion: completion)
        })
        delete.image = UIImage(systemName: "trash")
        let share = UIContextualAction(style: .normal, title: strings.Conversation_ContextMenuShare, handler: { [weak self] _, _, completion in
            completion(true)
            self?.share(url)
        })
        share.image = UIImage(systemName: "square.and.arrow.up")
        share.backgroundColor = self.presentationData.theme.list.itemAccentColor
        let configuration = UISwipeActionsConfiguration(actions: [delete, share])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let recording = self.recording(at: indexPath) else {
            return nil
        }
        let url = recording.url
        let strings = self.presentationData.strings
        let l10n = NovagramL10n(strings)
        return UIContextMenuConfiguration(identifier: url as NSURL, previewProvider: nil, actionProvider: { [weak self] _ in
            let play = UIAction(title: l10n.callRecordings_play, image: UIImage(systemName: "play.fill"), handler: { _ in
                self?.play(url)
            })
            let share = UIAction(title: strings.Conversation_ContextMenuShare, image: UIImage(systemName: "square.and.arrow.up"), handler: { _ in
                self?.share(url)
            })
            let delete = UIAction(title: strings.Common_Delete, image: UIImage(systemName: "trash"), attributes: .destructive, handler: { _ in
                self?.confirmDelete(url, completion: { _ in })
            })
            return UIMenu(children: [play, share, delete])
        })
    }

    func tableView(_ tableView: UITableView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func accessibilityActions(url: URL) -> [UIAccessibilityCustomAction] {
        let strings = self.presentationData.strings
        return [
            UIAccessibilityCustomAction(name: strings.Conversation_ContextMenuShare, actionHandler: { [weak self] _ in
                self?.share(url)
                return true
            }),
            UIAccessibilityCustomAction(name: strings.Common_Delete, actionHandler: { [weak self] _ in
                self?.confirmDelete(url, completion: { _ in })
                return true
            })
        ]
    }

    // MARK: - Actions

    private func play(_ url: URL) {
        self.previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        self.view.window?.rootViewController?.present(preview, animated: true)
    }

    /// The system share sheet. On iPad it is a popover, anchored on the recording's row.
    private func share(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            var anchor: UIView = self.view
            if let tableView = self.tableView, let indexPath = self.indexPath(of: url), let cell = tableView.cellForRow(at: indexPath) {
                anchor = cell
            }
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        self.view.window?.rootViewController?.present(controller, animated: true)
    }

    private func confirmDelete(_ url: URL, completion: @escaping (Bool) -> Void) {
        let strings = self.presentationData.strings
        let alert = textAlertController(context: self.context, title: nil, text: NovagramL10n(strings).callRecordings_deleteConfirm, actions: [
            TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {
                completion(false)
            }),
            TextAlertAction(type: .destructiveAction, title: strings.Common_Delete, action: { [weak self] in
                guard let self, (try? NovagramCallRecordingStorage.delete(url)) != nil else {
                    completion(false)
                    self?.reload()
                    return
                }
                self.removeRow(of: url)
                completion(true)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            })
        ], dismissOnOutsideTap: false)
        self.present(alert, in: .window(.root))
    }

    /// Animates the deleted recording out: its row, or its whole day when it was the day's last one.
    private func removeRow(of url: URL) {
        guard let tableView = self.tableView, let indexPath = self.indexPath(of: url) else {
            self.reload()
            return
        }
        self.sections[indexPath.section].recordings.remove(at: indexPath.row)
        if self.sections[indexPath.section].recordings.isEmpty {
            self.sections.remove(at: indexPath.section)
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
        } else {
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        self.updateSummary()
        self.layoutAuxiliaryViews()
    }

    // MARK: - Formatting

    /// TODAY / YESTERDAY / "October 30" / "October 30, 2025", in the app's language, like the chat date headers.
    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        let strings = self.presentationData.strings
        if calendar.isDateInToday(day) {
            return strings.Weekday_Today
        }
        if calendar.isDateInYesterday(day) {
            return strings.Weekday_Yesterday
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let month = stringForMonth(strings: strings, month: Int32((parts.month ?? 1) - 1))
        let dayOfMonth = "\(parts.day ?? 1)"
        let year = parts.year ?? 0
        if year == calendar.component(.year, from: Date()) {
            return strings.Date_ChatDateHeader(month, dayOfMonth).string
        }
        return strings.Date_ChatDateHeaderYear(month, dayOfMonth, "\(year)").string
    }

    private func timeString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return stringForShortTimestamp(hours: Int32(parts.hour ?? 0), minutes: Int32(parts.minute ?? 0), dateTimeFormat: self.presentationData.dateTimeFormat)
    }

    private func sizeString(_ size: Int64) -> String {
        return dataSizeString(size, formatting: DataSizeStringFormatting(presentationData: self.presentationData))
    }

    /// m:ss, or h:mm:ss from one hour.
    private static func durationString(_ duration: Double) -> String {
        let total = max(0, Int(duration.rounded()))
        let hours = total / secondsPerHour
        let minutes = (total % secondsPerHour) / secondsPerMinute
        let seconds = total % secondsPerMinute
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "40 seconds" in the app's language, for VoiceOver.
    private func spokenDuration(_ duration: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: NovagramL10n.languageKey(for: self.presentationData.strings))
        formatter.calendar = calendar
        return formatter.string(from: max(0.0, duration.rounded())) ?? NovagramCallRecordingsController.durationString(duration)
    }

    /// "today at 15:00", for VoiceOver.
    private func spokenDate(_ date: Date) -> String {
        return humanReadableStringForTimestamp(strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, timestamp: Int32(date.timeIntervalSince1970)).string
    }

    // MARK: - Quick Look

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return self.previewURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return (self.previewURL ?? NovagramCallRecordingStorage.directory) as NSURL
    }
}
