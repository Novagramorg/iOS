import Foundation
import UIKit
import SwiftUI
import Combine
import QuickLook
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ContextUI
import AppBundle
import AvatarNode
import MoreHeaderButton
import NovagramLocalization
import NovagramCalls
import NovagramCallRecordingCore
import NovagramCallRecordingUI

/// Novagram Settings → Calls → Call recordings (HOOKS.md, "Call recording"): the call recording SDK's SwiftUI list
/// (`CallRecordingsListView`), newest first and grouped by day like Telegram's call log, inside a Telegram
/// `ViewController`. A tap opens Quick Look (plays audio and video); swipe or long-press to share or delete.
/// Telegram's navigation bar keeps the title and back button, and its "more" button opens Telegram's context menu with
/// a filter (all / video / voice), Select and Clear All. They drive the SDK's view model; the SDK's own SwiftUI toolbar
/// is off (`showsToolbar`), because SwiftUI toolbars need a SwiftUI navigation container this screen does not have.
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
        NovagramCallRecordings.stopAll(timeout: self.timeout, completion: {
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: .now() + self.timeout + self.waitMargin)
    }
}

private final class NovagramCallRecordingsController: ViewController, QLPreviewControllerDataSource {
    // The list's text sizes at Telegram's default text size (17 pt); they scale with `listsFontSize`.
    private static let referenceFontSize: CGFloat = 17.0
    private static let subtitleFontSize: CGFloat = 14.0
    private static let timeFontSize: CGFloat = 15.0
    private static let freeTextFontSize: CGFloat = 13.0

    private let context: AccountContext
    private var presentationData: PresentationData
    private let model: CallRecordingsListViewModel

    private let moreButton: MoreHeaderButton
    private let moreItem: UIBarButtonItem
    private var doneItem: UIBarButtonItem?
    private var selectAllItem: UIBarButtonItem?
    private var hostingController: UIHostingController<CallRecordingsListView>?

    private var presentationDataDisposable: Disposable?
    private var modelObservation: AnyCancellable?
    private var previewURL: URL?

    init(context: AccountContext) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.model = CallRecordingsListViewModel(storage: NovagramCallRecordings.storage)
        let buttonColor = presentationData.theme.rootController.navigationBar.buttonColor
        self.moreButton = MoreHeaderButton(color: buttonColor)
        self.moreButton.isUserInteractionEnabled = true
        self.moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: buttonColor)))
        self.moreItem = UIBarButtonItem(customDisplayNode: self.moreButton) ?? UIBarButtonItem()

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))

        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        self.title = NovagramL10n(presentationData.strings).settings_callRecordings_title
        self.moreButton.addTarget(self, action: #selector(self.morePressed), forControlEvents: .touchUpInside)
        self.moreButton.accessibilityLabel = self.listStrings().options

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
        // objectWillChange fires before the model changes: read the new state on the next main-queue turn.
        self.modelObservation = self.model.objectWillChange.sink(receiveValue: { [weak self] _ in
            Queue.mainQueue().justDispatch {
                self?.updateNavigationItems(animated: true)
            }
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
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        let hostingController = UIHostingController(rootView: self.makeListView())
        hostingController.view.backgroundColor = .clear
        self.addChild(hostingController)
        self.displayNode.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController

        self.displayNodeDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A call may have saved a new recording while this screen was in the stack.
        if !self.model.isSelecting {
            let model = self.model
            Task {
                await model.reload()
            }
        }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        // The list starts under Telegram's navigation bar; the hosting view keeps the bottom safe area itself.
        let navigationBarHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let contentFrame = CGRect(x: 0.0, y: navigationBarHeight, width: layout.size.width, height: max(0.0, layout.size.height - navigationBarHeight))
        if let view = self.hostingController?.view {
            transition.updateFrame(view: view, frame: contentFrame)
        }
    }

    private func updateThemeAndStrings() {
        let theme = self.presentationData.theme
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        let buttonColor = theme.rootController.navigationBar.buttonColor
        self.moreButton.updateColor(color: buttonColor)
        self.moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: buttonColor)))
        self.title = NovagramL10n(self.presentationData.strings).settings_callRecordings_title
        self.moreButton.accessibilityLabel = self.listStrings().options
        self.doneItem = nil
        self.selectAllItem = nil
        self.updateNavigationItems(animated: false)
        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.hostingController?.rootView = self.makeListView()
    }

    // MARK: - The SDK list

    /// The same model every time, so the list keeps its state when the theme or the text size changes.
    private func makeListView() -> CallRecordingsListView {
        let presentationData = self.presentationData
        let list = presentationData.theme.list
        let baseFontSize = presentationData.listsFontSize.itemListBaseFontSize
        let reference = NovagramCallRecordingsController.referenceFontSize
        let theme = CallRecordingTheme(
            background: Color(list.blocksBackgroundColor),
            card: Color(list.itemBlocksBackgroundColor),
            primaryText: Color(list.itemPrimaryTextColor),
            secondaryText: Color(list.itemSecondaryTextColor),
            accent: Color(list.itemAccentColor),
            destructive: Color(list.itemDestructiveColor),
            separator: Color(list.itemBlocksSeparatorColor),
            avatarGradients: AvatarNode.gradientColors.map { colors in colors.map { Color($0) } },
            titleFontSize: baseFontSize,
            subtitleFontSize: floor(baseFontSize * NovagramCallRecordingsController.subtitleFontSize / reference),
            timeFontSize: floor(baseFontSize * NovagramCallRecordingsController.timeFontSize / reference),
            freeTextFontSize: floor(baseFontSize * NovagramCallRecordingsController.freeTextFontSize / reference),
            followsDynamicType: false,
            freeText: Color(list.freeTextColor)
        )
        var environment = CallRecordingUIEnvironment(
            languageCode: NovagramL10n.languageKey(for: presentationData.strings),
            theme: theme,
            isRecordingEnabled: CallRecordingSettings().isEnabled,
            onPlay: { [weak self] recording in
                self?.play(recording.url)
            },
            onShare: { [weak self] urls, rect in
                self?.share(urls, rect: rect)
            }
        )
        environment.showsToolbar = false
        environment.strings = self.listStrings()
        let strings = presentationData.strings
        environment.dayHeader = { day in
            return NovagramCallRecordingsController.dayTitle(day, strings: strings)
        }
        let sizeFormatting = DataSizeStringFormatting(presentationData: presentationData)
        environment.sizeString = { size in
            return dataSizeString(size, formatting: sizeFormatting)
        }
        let dateTimeFormat = presentationData.dateTimeFormat
        environment.timeString = { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            return stringForShortTimestamp(hours: Int32(parts.hour ?? 0), minutes: Int32(parts.minute ?? 0), dateTimeFormat: dateTimeFormat)
        }
        return CallRecordingsListView(model: self.model, environment: environment)
    }

    /// The SDK's texts in the app's language, with Telegram's own words where the old screen used them.
    private func listStrings() -> CallRecordingStrings {
        let strings = self.presentationData.strings
        var listStrings = CallRecordingStrings(languageCode: NovagramL10n.languageKey(for: strings))
        listStrings.title = NovagramL10n(strings).settings_callRecordings_title
        listStrings.share = strings.Conversation_ContextMenuShare
        listStrings.delete = strings.Common_Delete
        listStrings.cancel = strings.Common_Cancel
        listStrings.select = strings.Common_Select
        listStrings.done = strings.Common_Done
        listStrings.selectAll = strings.Contacts_SelectAll
        listStrings.deselectAll = strings.Contacts_DeselectAll
        listStrings.today = strings.Weekday_Today
        listStrings.yesterday = strings.Weekday_Yesterday
        let delete = strings.Common_Delete
        listStrings.deleteSelectedButton = { count in
            return count > 0 ? "\(delete) (\(count))" : delete
        }
        return listStrings
    }

    // MARK: - Navigation bar and menu

    /// More button normally, Done (and Select All on the left) while selecting, nothing when there are no recordings.
    private func updateNavigationItems(animated: Bool) {
        if self.model.recordings.isEmpty {
            self.navigationItem.setRightBarButton(nil, animated: animated)
            self.navigationItem.setLeftBarButton(nil, animated: animated)
            return
        }
        guard self.model.isSelecting else {
            if self.navigationItem.rightBarButtonItem !== self.moreItem {
                self.navigationItem.setRightBarButton(self.moreItem, animated: animated)
            }
            if self.navigationItem.leftBarButtonItem != nil {
                self.navigationItem.setLeftBarButton(nil, animated: animated)
            }
            return
        }
        let strings = self.presentationData.strings
        let doneItem = self.doneItem ?? UIBarButtonItem(title: strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        self.doneItem = doneItem
        if self.navigationItem.rightBarButtonItem !== doneItem {
            self.navigationItem.setRightBarButton(doneItem, animated: animated)
        }
        let title = self.model.allVisibleSelected ? strings.Contacts_DeselectAll : strings.Contacts_SelectAll
        if let selectAllItem = self.selectAllItem, selectAllItem.title == title, self.navigationItem.leftBarButtonItem === selectAllItem {
            return
        }
        let selectAllItem = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(self.selectAllPressed))
        self.selectAllItem = selectAllItem
        self.navigationItem.setLeftBarButton(selectAllItem, animated: false)
    }

    @objc private func morePressed() {
        let strings = self.presentationData.strings
        let listStrings = self.listStrings()
        var items: [ContextMenuItem] = []
        for filter in CallRecordingFilter.allCases {
            let isCurrent = self.model.filter == filter
            // The other filters get a clear check of the same size, so the three titles line up.
            items.append(.action(ContextMenuActionItem(text: filter.title(listStrings), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: isCurrent ? theme.contextMenu.primaryColor : .clear)
            }, action: { [weak self] _, f in
                f(.default)
                self?.model.filter = filter
            })))
        }
        if !self.model.visibleRecordings.isEmpty {
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: strings.Common_Select, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.setSelecting(true)
            })))
            items.append(.action(ContextMenuActionItem(text: listStrings.clearAll, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.model.requestClearAll()
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

    private func setSelecting(_ isSelecting: Bool) {
        guard self.model.isSelecting != isSelecting else {
            return
        }
        self.model.setSelecting(isSelecting)
        if isSelecting {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    @objc private func donePressed() {
        self.setSelecting(false)
    }

    @objc private func selectAllPressed() {
        self.model.toggleSelectAll()
    }

    // MARK: - Actions

    private func play(_ url: URL) {
        self.previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        self.view.window?.rootViewController?.present(preview, animated: true)
    }

    /// The system share sheet. On iPad it is a popover anchored at the row or button the SDK reports (window
    /// coordinates), or the bottom of the screen when it reports none.
    private func share(_ urls: [URL], rect: CGRect) {
        guard !urls.isEmpty, let window = self.view.window else {
            return
        }
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = window
            if rect.isEmpty {
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.maxY - 1.0, width: 1.0, height: 1.0)
                popover.permittedArrowDirections = []
            } else {
                popover.sourceRect = rect
            }
        }
        window.rootViewController?.present(controller, animated: true)
    }

    // MARK: - Formatting

    /// TODAY / YESTERDAY / "October 30" / "October 30, 2025", in the app's language, like the chat date headers.
    private static func dayTitle(_ day: Date, strings: PresentationStrings) -> String {
        let calendar = Calendar.current
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

    // MARK: - Quick Look

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return self.previewURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return (self.previewURL ?? NovagramCallRecordings.storage.directory) as NSURL
    }
}

/// Anchors the menu to the "more" button, like Telegram's own screens (PeerInfoStoryGridScreen).
private final class NovagramCallRecordingsMenuSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}
