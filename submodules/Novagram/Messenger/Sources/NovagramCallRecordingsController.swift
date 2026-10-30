import Foundation
import UIKit
import QuickLook
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import NovagramLocalization
import NovagramCallRecording

/// Novagram Settings → Calls → Call recordings (HOOKS.md, "Call recording"): the files in the app's call recordings
/// folder, newest first. A tap opens Quick Look (plays audio and video, has the Share button); swipe to delete, with
/// a confirmation. A plain table in the grouped settings style, because the list needs swipe-to-delete, which the
/// ItemList rows without a peer do not have.
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
    private static let cellId = "recording"
    private static let rowHeight: CGFloat = 60.0

    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private var recordings: [NovagramCallRecordingStorage.Recording] = []
    private var previewURL: URL?

    private var tableView: UITableView?
    private var didSetInitialOffset = false
    private let emptyLabel = UILabel()

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
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()

        let tableView = UITableView(frame: CGRect(), style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = NovagramCallRecordingsController.rowHeight
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: NovagramCallRecordingsController.cellId)
        tableView.contentInsetAdjustmentBehavior = .never
        self.tableView = tableView
        self.displayNode.view.addSubview(tableView)

        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.emptyLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        self.emptyLabel.adjustsFontForContentSizeCategory = true
        self.displayNode.view.addSubview(self.emptyLabel)

        self.updateThemeAndStrings()
        self.reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A call may have saved a new recording while this screen was in the stack.
        self.reload()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let topInset = self.navigationLayout(layout: layout).navigationFrame.maxY
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        if let tableView = self.tableView {
            tableView.frame = bounds
            tableView.contentInset = UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
            tableView.scrollIndicatorInsets = tableView.contentInset
            if !self.didSetInitialOffset {
                self.didSetInitialOffset = true
                tableView.contentOffset = CGPoint(x: 0.0, y: -topInset)
            }
        }
        let sideInset = layout.safeInsets.left + 32.0
        let emptyWidth = max(0.0, layout.size.width - sideInset - layout.safeInsets.right - 32.0)
        let emptySize = self.emptyLabel.sizeThatFits(CGSize(width: emptyWidth, height: .greatestFiniteMagnitude))
        self.emptyLabel.frame = CGRect(x: sideInset, y: floor(topInset + (layout.size.height - topInset - emptySize.height) * 0.4), width: emptyWidth, height: ceil(emptySize.height))
    }

    private func updateThemeAndStrings() {
        let theme = self.presentationData.theme
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        let l10n = NovagramL10n(self.presentationData.strings)
        self.title = l10n.settings_callRecordings_title
        if self.isNodeLoaded {
            self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
            self.tableView?.backgroundColor = theme.list.blocksBackgroundColor
            self.tableView?.separatorColor = theme.list.itemBlocksSeparatorColor
            self.emptyLabel.textColor = theme.list.freeTextColor
            self.emptyLabel.text = l10n.callRecordings_empty
            self.tableView?.reloadData()
        }
    }

    private func reload() {
        self.recordings = NovagramCallRecordingStorage.list()
        self.emptyLabel.isHidden = !self.recordings.isEmpty
        self.tableView?.reloadData()
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.recordings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NovagramCallRecordingsController.cellId, for: indexPath)
        let recording = self.recordings[indexPath.row]
        let theme = self.presentationData.theme

        var content = UIListContentConfiguration.subtitleCell()
        content.text = recording.url.deletingPathExtension().lastPathComponent
        content.secondaryText = self.details(of: recording)
        content.textProperties.color = theme.list.itemPrimaryTextColor
        content.textProperties.numberOfLines = 1
        content.secondaryTextProperties.color = theme.list.itemSecondaryTextColor
        content.image = UIImage(systemName: recording.isVideo ? "video.fill" : "waveform")
        content.imageProperties.tintColor = theme.list.itemAccentColor
        content.imageProperties.reservedLayoutSize = CGSize(width: 28.0, height: 28.0)
        cell.contentConfiguration = content

        let background = UIView()
        background.backgroundColor = theme.list.itemHighlightedBackgroundColor
        cell.selectedBackgroundView = background
        cell.backgroundColor = theme.list.itemBlocksBackgroundColor
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < self.recordings.count else {
            return
        }
        self.previewURL = self.recordings[indexPath.row].url
        let preview = QLPreviewController()
        preview.dataSource = self
        self.view.window?.rootViewController?.present(preview, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: self.presentationData.strings.Common_Delete, handler: { [weak self] _, _, completion in
            guard let self, indexPath.row < self.recordings.count else {
                completion(false)
                return
            }
            self.confirmDelete(self.recordings[indexPath.row], completion: completion)
        })
        let configuration = UISwipeActionsConfiguration(actions: [delete])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func confirmDelete(_ recording: NovagramCallRecordingStorage.Recording, completion: @escaping (Bool) -> Void) {
        let strings = self.presentationData.strings
        let alert = textAlertController(context: self.context, title: nil, text: NovagramL10n(strings).callRecordings_deleteConfirm, actions: [
            TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {
                completion(false)
            }),
            TextAlertAction(type: .destructiveAction, title: strings.Common_Delete, action: { [weak self] in
                try? NovagramCallRecordingStorage.delete(recording.url)
                completion(true)
                self?.reload()
            })
        ], dismissOnOutsideTap: false)
        self.present(alert, in: .window(.root))
    }

    private func details(of recording: NovagramCallRecordingStorage.Recording) -> String {
        let date = DateFormatter.localizedString(from: recording.date, dateStyle: .medium, timeStyle: .short)
        let total = max(0, Int(recording.duration.rounded()))
        let duration = total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
        let size = ByteCountFormatter.string(fromByteCount: recording.size, countStyle: .file)
        return "\(date) · \(duration) · \(size)"
    }

    // MARK: - Quick Look

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return self.previewURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return (self.previewURL ?? NovagramCallRecordingStorage.directory) as NSURL
    }
}
