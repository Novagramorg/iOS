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
import ContextUI
import AppBundle
import MoreHeaderButton
import NovagramLocalization
import NovagramCalls
import NovagramCallRecording

/// Novagram Settings → Calls → Call recordings (HOOKS.md, "Call recording"): the files in the app's call recordings
/// folder, newest first, grouped by day like Telegram's call log. A tap opens Quick Look (plays audio and video);
/// swipe or long-press to share or delete (delete asks first). The "more" button on the right of the navigation bar
/// opens Telegram's context menu with a filter (all / video / voice), Select (multi-select with a Share / Delete
/// toolbar) and Clear All. A plain table in the grouped settings style, because the list needs swipe actions and
/// multi-select, which the ItemList rows without a peer do not have.
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

    private enum Filter {
        case all
        case video
        case voice

        func includes(_ recording: Recording) -> Bool {
            switch self {
            case .all:
                return true
            case .video:
                return recording.isVideo
            case .voice:
                return !recording.isVideo
            }
        }
    }

    /// The menu's filter. Kept for the app session only: a relaunch starts with All again.
    private static var sessionFilter: Filter = .all

    private static let headerId = "day"
    private static let estimatedRowHeight: CGFloat = 60.0
    // Telegram's list sizes, relative to the 17 pt list base size, so they follow Telegram's text size.
    private static let referenceFontSize: CGFloat = 17.0
    private static let freeTextFontSize: CGFloat = 13.0
    private static let summaryTopInset: CGFloat = 16.0
    private static let summaryBottomInset: CGFloat = 12.0
    private static let filterEmptyTopInset: CGFloat = 32.0
    private static let footerTopInset: CGFloat = 8.0
    private static let footerBottomInset: CGFloat = 16.0
    private static let freeTextInset: CGFloat = 16.0
    private static let toolbarHeight: CGFloat = 44.0
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

    private var allRecordings: [Recording] = []
    private var sections: [DaySection] = []
    private var previewURL: URL?
    private var isSelecting = false

    private var tableView: UITableView?
    private var didSetInitialOffset = false
    private var lastLayout: ContainerViewLayout?
    private let summaryContainer = UIView()
    private let summaryLabel = UILabel()
    private let footerContainer = UIView()
    private let footerLabel = UILabel()
    private let emptyView = UIView()
    private let emptyIcon = UIImageView()
    private let emptyTitle = UILabel()
    private let emptyText = UILabel()
    private var toolbarNode: ToolbarNode?

    private let moreButton: MoreHeaderButton
    private let moreItem: UIBarButtonItem
    private var doneItem: UIBarButtonItem?
    private var selectAllItem: UIBarButtonItem?

    private var filter: Filter {
        get {
            return NovagramCallRecordingsController.sessionFilter
        }
        set {
            NovagramCallRecordingsController.sessionFilter = newValue
        }
    }

    private var baseFontSize: CGFloat {
        return self.presentationData.listsFontSize.itemListBaseFontSize
    }

    init(context: AccountContext) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        let buttonColor = presentationData.theme.rootController.navigationBar.buttonColor
        self.moreButton = MoreHeaderButton(color: buttonColor)
        self.moreButton.isUserInteractionEnabled = true
        self.moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: buttonColor)))
        self.moreItem = UIBarButtonItem(customDisplayNode: self.moreButton) ?? UIBarButtonItem()

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = NovagramL10n(self.presentationData.strings).settings_callRecordings_title
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.moreButton.accessibilityLabel = NovagramL10n(self.presentationData.strings).callRecordings_menuAccessibility

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            let previous = self.presentationData
            guard presentationData.theme !== previous.theme || presentationData.strings !== previous.strings || presentationData.listsFontSize != previous.listsFontSize else {
                return
            }
            self.presentationData = presentationData
            self.updateThemeAndStrings()
        })
        // Larger text changes the row layout (accessibility sizes) and the empty-state heights, which are laid out by
        // hand. The labels pick up the new size after this notification, so measure on the next main-queue turn.
        self.contentSizeObserver = NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            Queue.mainQueue().justDispatch {
                self?.reconfigureVisibleRows()
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
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(NovagramCallRecordingCell.self, forCellReuseIdentifier: NovagramCallRecordingCell.reuseId)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: NovagramCallRecordingsController.headerId)
        tableView.contentInsetAdjustmentBehavior = .never
        self.tableView = tableView
        self.displayNode.view.addSubview(tableView)

        for label in [self.summaryLabel, self.footerLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = false
        }
        self.summaryContainer.addSubview(self.summaryLabel)
        self.footerContainer.addSubview(self.footerLabel)

        self.setupEmptyState()
        self.displayNode.view.addSubview(self.emptyView)

        self.updateThemeAndStrings()
        self.reload()
    }

    private func setupEmptyState() {
        let iconConfiguration = UIImage.SymbolConfiguration(pointSize: NovagramCallRecordingsController.emptyIconSize, weight: .regular)
        self.emptyIcon.image = UIImage(systemName: "waveform.circle", withConfiguration: iconConfiguration)
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
        if !self.isSelecting {
            self.reload()
        }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.lastLayout = layout
        let topInset = self.navigationLayout(layout: layout).navigationFrame.maxY
        if let tableView = self.tableView {
            tableView.frame = CGRect(origin: CGPoint(), size: layout.size)
            let bottomInset = self.isSelecting ? self.toolbarFrame(layout: layout).height : layout.intrinsicInsets.bottom
            tableView.contentInset = UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomInset, right: 0.0)
            tableView.scrollIndicatorInsets = tableView.contentInset
            if !self.didSetInitialOffset {
                self.didSetInitialOffset = true
                tableView.contentOffset = CGPoint(x: 0.0, y: -topInset)
            }
        }
        self.layoutToolbar(layout: layout, transition: transition)
        self.layoutAuxiliaryViews()
    }

    private func layoutAuxiliaryViews() {
        guard let layout = self.lastLayout else {
            return
        }
        self.layoutHeaderAndFooter()
        self.layoutEmptyState(layout: layout, topInset: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    /// "5 recordings · 817 KB" above the list (or "No video call recordings" when the filter hides everything) and the
    /// storage note below it, in the free-text style, lined up with the section headers.
    private func layoutHeaderAndFooter() {
        guard let tableView = self.tableView, !self.allRecordings.isEmpty else {
            self.tableView?.tableHeaderView = nil
            self.tableView?.tableFooterView = nil
            return
        }
        tableView.layoutIfNeeded()
        let isFilterEmpty = self.sections.isEmpty
        self.summaryLabel.textAlignment = isFilterEmpty ? .center : .natural
        let summaryTop = isFilterEmpty ? NovagramCallRecordingsController.filterEmptyTopInset : NovagramCallRecordingsController.summaryTopInset
        self.layoutFreeText(self.summaryLabel, in: self.summaryContainer, top: summaryTop, bottom: NovagramCallRecordingsController.summaryBottomInset)
        tableView.tableHeaderView = self.summaryContainer
        if isFilterEmpty {
            tableView.tableFooterView = nil
        } else {
            self.layoutFreeText(self.footerLabel, in: self.footerContainer, top: NovagramCallRecordingsController.footerTopInset, bottom: NovagramCallRecordingsController.footerBottomInset)
            tableView.tableFooterView = self.footerContainer
        }
    }

    private func layoutFreeText(_ label: UILabel, in container: UIView, top: CGFloat, bottom: CGFloat) {
        guard let tableView = self.tableView else {
            return
        }
        let textInset = NovagramCallRecordingsController.freeTextInset
        let left = tableView.layoutMargins.left + textInset
        let width = max(0.0, tableView.bounds.width - left - tableView.layoutMargins.right - textInset)
        let height = ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        label.frame = CGRect(x: left, y: top, width: width, height: height)
        container.frame = CGRect(x: 0.0, y: 0.0, width: tableView.bounds.width, height: top + height + bottom)
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
        let buttonColor = theme.rootController.navigationBar.buttonColor
        self.moreButton.updateColor(color: buttonColor)
        self.moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: buttonColor)))
        let l10n = NovagramL10n(self.presentationData.strings)
        self.title = l10n.settings_callRecordings_title
        self.moreButton.accessibilityLabel = l10n.callRecordings_menuAccessibility
        self.doneItem = nil
        self.selectAllItem = nil
        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView?.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView?.separatorColor = theme.list.itemBlocksSeparatorColor
        let freeTextFont = Font.regular(floor(self.baseFontSize * NovagramCallRecordingsController.freeTextFontSize / NovagramCallRecordingsController.referenceFontSize))
        self.summaryLabel.font = freeTextFont
        self.footerLabel.font = freeTextFont
        self.summaryLabel.textColor = theme.list.freeTextColor
        self.footerLabel.textColor = theme.list.freeTextColor
        self.footerLabel.text = l10n.callRecordings_storageFooter
        self.emptyIcon.tintColor = theme.list.itemSecondaryTextColor
        self.emptyTitle.textColor = theme.list.itemPrimaryTextColor
        self.emptyText.textColor = theme.list.freeTextColor
        self.emptyTitle.text = l10n.callRecordings_emptyTitle
        self.toolbarNode?.updateTheme(ToolbarTheme(rootControllerTheme: theme))
        self.updateSummary()
        self.updateNavigationItems(animated: false)
        self.reconfigureVisibleRows()
    }

    /// Reloads the rows in place (fonts, colours, accessibility layout) and keeps the selection while selecting.
    private func reconfigureVisibleRows() {
        guard let tableView = self.tableView else {
            return
        }
        let selected = tableView.indexPathsForSelectedRows ?? []
        tableView.reloadData()
        if self.isSelecting {
            for indexPath in selected {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
        self.layoutAuxiliaryViews()
        self.updateToolbar()
    }

    private func reload() {
        self.allRecordings = NovagramCallRecordingStorage.list()
        self.sections = NovagramCallRecordingsController.group(self.allRecordings.filter(self.filter.includes))
        self.updateSummary()
        self.updateNavigationItems(animated: false)
        self.tableView?.reloadData()
        self.layoutAuxiliaryViews()
    }

    private func updateSummary() {
        let l10n = NovagramL10n(self.presentationData.strings)
        let recordings = self.sections.flatMap { $0.recordings }
        if recordings.isEmpty {
            self.summaryLabel.text = l10n.callRecordings_filterEmpty(isVideo: self.filter == .video)
        } else {
            let totalSize = recordings.reduce(Int64(0)) { $0 + $1.size }
            self.summaryLabel.text = l10n.callRecordings_summary(count: recordings.count, size: self.sizeString(totalSize))
        }
        self.emptyText.text = NovagramCallRecordingSettings.isEnabled ? l10n.callRecordings_emptyTextEnabled : l10n.callRecordings_emptyText
        self.emptyView.isHidden = !self.allRecordings.isEmpty
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

    /// Regroups the recordings under the current filter and animates the difference: whole days fade in or out, and
    /// rows inside days that stay. The list is always newest first, so nothing moves.
    private func applyRecordings() {
        let updated = NovagramCallRecordingsController.group(self.allRecordings.filter(self.filter.includes))
        guard let tableView = self.tableView, tableView.window != nil else {
            self.sections = updated
            self.tableView?.reloadData()
            self.didChangeRecordings()
            return
        }
        let previous = self.sections
        let previousDays = previous.map(\.day)
        let updatedDays = Set(updated.map(\.day))
        var deletedSections = IndexSet()
        var insertedSections = IndexSet()
        var deletedRows: [IndexPath] = []
        var insertedRows: [IndexPath] = []
        for (index, section) in previous.enumerated() where !updatedDays.contains(section.day) {
            deletedSections.insert(index)
        }
        for (index, section) in updated.enumerated() {
            guard let previousIndex = previousDays.firstIndex(of: section.day) else {
                insertedSections.insert(index)
                continue
            }
            let previousURLs = previous[previousIndex].recordings.map(\.url)
            let updatedURLs = Set(section.recordings.map(\.url))
            for (row, url) in previousURLs.enumerated() where !updatedURLs.contains(url) {
                deletedRows.append(IndexPath(row: row, section: previousIndex))
            }
            let previousSet = Set(previousURLs)
            for (row, recording) in section.recordings.enumerated() where !previousSet.contains(recording.url) {
                insertedRows.append(IndexPath(row: row, section: index))
            }
        }
        self.sections = updated
        tableView.performBatchUpdates({
            tableView.deleteSections(deletedSections, with: .fade)
            tableView.insertSections(insertedSections, with: .fade)
            tableView.deleteRows(at: deletedRows, with: .fade)
            tableView.insertRows(at: insertedRows, with: .fade)
        }, completion: nil)
        self.didChangeRecordings()
    }

    private func didChangeRecordings() {
        self.updateSummary()
        if self.isSelecting && self.sections.isEmpty {
            self.setSelecting(false)
        } else {
            self.updateNavigationItems(animated: true)
            self.updateToolbar()
        }
        self.layoutAuxiliaryViews()
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

    private var selectedRecordings: [Recording] {
        let indexPaths = (self.tableView?.indexPathsForSelectedRows ?? []).sorted()
        return indexPaths.compactMap { self.recording(at: $0) }
    }

    private var visibleRecordings: [Recording] {
        return self.sections.flatMap { $0.recordings }
    }

    // MARK: - Navigation bar, menu and selection

    /// More button normally, Done (and Select All on the left) while selecting, nothing when there are no recordings.
    private func updateNavigationItems(animated: Bool) {
        if self.allRecordings.isEmpty {
            self.navigationItem.setRightBarButton(nil, animated: animated)
            self.navigationItem.setLeftBarButton(nil, animated: animated)
            return
        }
        guard self.isSelecting else {
            if self.navigationItem.rightBarButtonItem !== self.moreItem {
                self.navigationItem.setRightBarButton(self.moreItem, animated: animated)
            }
            self.navigationItem.setLeftBarButton(nil, animated: animated)
            return
        }
        let strings = self.presentationData.strings
        let doneItem = self.doneItem ?? UIBarButtonItem(title: strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        self.doneItem = doneItem
        if self.navigationItem.rightBarButtonItem !== doneItem {
            self.navigationItem.setRightBarButton(doneItem, animated: animated)
        }
        let selectedCount = self.tableView?.indexPathsForSelectedRows?.count ?? 0
        let allSelected = selectedCount > 0 && selectedCount == self.visibleRecordings.count
        let title = allSelected ? strings.Contacts_DeselectAll : strings.Contacts_SelectAll
        if let selectAllItem = self.selectAllItem, selectAllItem.title == title, self.navigationItem.leftBarButtonItem === selectAllItem {
            return
        }
        let selectAllItem = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(self.selectAllPressed))
        self.selectAllItem = selectAllItem
        self.navigationItem.setLeftBarButton(selectAllItem, animated: false)
    }

    @objc private func morePressed() {
        let strings = self.presentationData.strings
        let l10n = NovagramL10n(strings)
        var items: [ContextMenuItem] = []
        let filters: [(Filter, String)] = [(.all, l10n.callRecordings_filterAll), (.video, l10n.callRecordings_filterVideo), (.voice, l10n.callRecordings_filterVoice)]
        for (filter, title) in filters {
            let isCurrent = self.filter == filter
            // The other filters get a clear check of the same size, so the three titles line up.
            items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: isCurrent ? theme.contextMenu.primaryColor : .clear)
            }, action: { [weak self] _, f in
                f(.default)
                self?.setFilter(filter)
            })))
        }
        if !self.sections.isEmpty {
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strings.Common_Select, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.setSelecting(true)
            })))
            items.append(.action(ContextMenuActionItem(text: l10n.callRecordings_clearAll, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.confirmClearAll()
            })))
        }
        let contextController = makeContextController(
            presentationData: self.presentationData,
            source: .reference(NovagramCallRecordingsMenuSource(sourceView: self.moreButton.referenceNode.view)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        self.presentInGlobalOverlay(contextController)
    }

    private func setFilter(_ filter: Filter) {
        guard self.filter != filter else {
            return
        }
        self.filter = filter
        self.applyRecordings()
    }

    private func setSelecting(_ selecting: Bool) {
        guard self.isSelecting != selecting, let tableView = self.tableView else {
            return
        }
        self.isSelecting = selecting
        tableView.setEditing(selecting, animated: true)
        if selecting {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        self.updateNavigationItems(animated: true)
        if let layout = self.lastLayout {
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .easeInOut))
        }
    }

    @objc private func donePressed() {
        self.setSelecting(false)
    }

    @objc private func selectAllPressed() {
        guard let tableView = self.tableView else {
            return
        }
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        if selectedCount > 0 && selectedCount == self.visibleRecordings.count {
            for indexPath in tableView.indexPathsForSelectedRows ?? [] {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        } else {
            for (section, day) in self.sections.enumerated() {
                for row in day.recordings.indices {
                    tableView.selectRow(at: IndexPath(row: row, section: section), animated: false, scrollPosition: .none)
                }
            }
        }
        self.selectionDidChange()
    }

    private func selectionDidChange() {
        self.updateNavigationItems(animated: false)
        self.updateToolbar()
    }

    // MARK: - Selection toolbar

    private func toolbarFrame(layout: ContainerViewLayout) -> CGRect {
        let bottomInset = max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom)
        let height = NovagramCallRecordingsController.toolbarHeight + bottomInset
        return CGRect(x: 0.0, y: layout.size.height - height, width: layout.size.width, height: height)
    }

    private func layoutToolbar(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var frame = self.toolbarFrame(layout: layout)
        if self.isSelecting {
            if self.toolbarNode == nil {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(rootControllerTheme: self.presentationData.theme), displaySeparator: true, left: { [weak self] in
                    self?.shareSelected()
                }, right: { [weak self] in
                    self?.confirmDeleteSelected()
                })
                // Slide in from below the screen.
                toolbarNode.frame = frame.offsetBy(dx: 0.0, dy: frame.height)
                self.toolbarNode = toolbarNode
                self.displayNode.addSubnode(toolbarNode)
            }
        } else {
            frame = frame.offsetBy(dx: 0.0, dy: frame.height)
        }
        guard let toolbarNode = self.toolbarNode else {
            return
        }
        let isSelecting = self.isSelecting
        transition.updateFrame(node: toolbarNode, frame: frame, completion: { [weak self, weak toolbarNode] _ in
            guard !isSelecting, let self, let toolbarNode, self.toolbarNode === toolbarNode, !self.isSelecting else {
                return
            }
            toolbarNode.removeFromSupernode()
            self.toolbarNode = nil
        })
        self.updateToolbar(layout: layout)
    }

    private func updateToolbar(layout: ContainerViewLayout? = nil) {
        guard let toolbarNode = self.toolbarNode, let layout = layout ?? self.lastLayout else {
            return
        }
        let strings = self.presentationData.strings
        let count = self.tableView?.indexPathsForSelectedRows?.count ?? 0
        let deleteTitle = count > 0 ? "\(strings.Common_Delete) (\(count))" : strings.Common_Delete
        let toolbar = Toolbar(
            leftAction: ToolbarAction(title: strings.Conversation_ContextMenuShare, isEnabled: count > 0),
            rightAction: ToolbarAction(title: deleteTitle, isEnabled: count > 0),
            middleAction: nil
        )
        let bottomInset = max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom)
        toolbarNode.updateLayout(size: self.toolbarFrame(layout: layout).size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalSideInsets: UIEdgeInsets(), bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
    }

    private func shareSelected() {
        let urls = self.selectedRecordings.map(\.url)
        guard !urls.isEmpty else {
            return
        }
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            let anchor: UIView = self.toolbarNode?.view ?? self.view
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
        }
        self.view.window?.rootViewController?.present(controller, animated: true)
    }

    private func confirmDeleteSelected() {
        let urls = self.selectedRecordings.map(\.url)
        guard !urls.isEmpty else {
            return
        }
        let text = NovagramL10n(self.presentationData.strings).callRecordings_deleteSelectedConfirm(count: urls.count)
        self.confirmDeletion(urls, text: text)
    }

    /// Clear All deletes what the list shows: everything, or only the filtered recordings when a filter is on.
    private func confirmClearAll() {
        let recordings = self.visibleRecordings
        guard !recordings.isEmpty else {
            return
        }
        let l10n = NovagramL10n(self.presentationData.strings)
        let size = self.sizeString(recordings.reduce(Int64(0)) { $0 + $1.size })
        let text: String
        switch self.filter {
        case .all:
            text = l10n.callRecordings_clearAllConfirm(count: recordings.count, size: size)
        case .video, .voice:
            text = l10n.callRecordings_clearFilteredConfirm(count: recordings.count, size: size, isVideo: self.filter == .video)
        }
        self.confirmDeletion(recordings.map(\.url), text: text)
    }

    private func confirmDeletion(_ urls: [URL], text: String) {
        let strings = self.presentationData.strings
        let alert = textAlertController(context: self.context, title: nil, text: text, actions: [
            TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: strings.Common_Delete, action: { [weak self] in
                self?.delete(urls)
            })
        ], dismissOnOutsideTap: false)
        self.present(alert, in: .window(.root))
    }

    /// Deletes the files and animates their rows out. A file that could not be deleted stays in the list.
    private func delete(_ urls: [URL]) {
        var deleted = Set<URL>()
        for url in urls where (try? NovagramCallRecordingStorage.delete(url)) != nil {
            deleted.insert(url)
        }
        guard !deleted.isEmpty else {
            self.reload()
            return
        }
        self.allRecordings.removeAll { deleted.contains($0.url) }
        self.applyRecordings()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        content.textProperties.font = Font.regular(floor(self.baseFontSize * NovagramCallRecordingsController.freeTextFontSize / NovagramCallRecordingsController.referenceFontSize))
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
        let duration = NovagramCallRecordingsController.durationString(recording.duration)
        cell.update(content: NovagramCallRecordingCell.Content(
            name: name,
            subtitle: "\(kind) · \(duration) · \(size)",
            time: self.timeString(recording.date)
        ), theme: self.presentationData.theme, baseFontSize: self.baseFontSize)
        cell.accessibilityLabel = [name, kind, self.spokenDuration(recording.duration), self.spokenDate(recording.date), size].joined(separator: ", ")
        cell.accessibilityCustomActions = self.accessibilityActions(url: recording.url)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            self.selectionDidChange()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        guard let recording = self.recording(at: indexPath) else {
            return
        }
        self.play(recording.url)
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            self.selectionDidChange()
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !tableView.isEditing, let recording = self.recording(at: indexPath) else {
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
        guard !tableView.isEditing, let recording = self.recording(at: indexPath) else {
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
                self.allRecordings.removeAll { $0.url == url }
                self.applyRecordings()
                completion(true)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            })
        ], dismissOnOutsideTap: false)
        self.present(alert, in: .window(.root))
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

/// Anchors the toolbar menu to the "more" button, like Telegram's own screens (PeerInfoStoryGridScreen).
private final class NovagramCallRecordingsMenuSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}
