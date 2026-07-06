import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import Postbox
import QuickReplyNameAlertController
import AlertUI
import FenixuzLocalization

// Tasks tab — Fenixuz to-do feature. Single-purpose: folder list backed by
// FenixuzTasks/TodoStorage (SQLite). Tapping a folder pushes the task editor
// (todoItemController). No scheduled-messages segment — the tab is for the
// to-do workflow only.

private enum TasksTabSection: Int32 {
    case main = 0
}

private enum TasksTabEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
    case folder(Int, PresentationTheme, TodoFolder, Int, Int) // index, theme, folder, doneCount, totalCount
    case empty(PresentationTheme, String)

    var section: ItemListSectionId { TasksTabSection.main.rawValue }

    var stableId: Int32 {
        switch self {
        case .header: return -100
        case .empty:  return -99
        case let .folder(index, _, _, _, _):
            return Int32(index + 1000)
        }
    }

    static func ==(lhs: TasksTabEntry, rhs: TasksTabEntry) -> Bool {
        switch lhs {
        case let .header(lhsTheme, lhsText):
            if case let .header(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .folder(lhsIndex, lhsTheme, lhsFolder, lhsDone, lhsTotal):
            if case let .folder(rhsIndex, rhsTheme, rhsFolder, rhsDone, rhsTotal) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsFolder == rhsFolder, lhsDone == rhsDone, lhsTotal == rhsTotal { return true }
            return false
        case let .empty(lhsTheme, lhsText):
            if case let .empty(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }

    static func <(lhs: TasksTabEntry, rhs: TasksTabEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TasksTabArguments
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .folder(_, _, folder, doneCount, totalCount):
            let label = totalCount > 0 ? "\(doneCount)/\(totalCount)" : "0"
            let badgeColor = doneCount == totalCount && totalCount > 0
                ? UIColor(rgb: 0x34c759)
                : presentationData.theme.list.itemAccentColor
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: folder.title,
                label: label,
                labelStyle: .badge(badgeColor),
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openFolder(folder)
                }
            )
        case let .empty(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class TasksTabArguments {
    let context: AccountContext
    let openFolder: (TodoFolder) -> Void
    let deleteFolder: (String) -> Void

    init(context: AccountContext, openFolder: @escaping (TodoFolder) -> Void, deleteFolder: @escaping (String) -> Void) {
        self.context = context
        self.openFolder = openFolder
        self.deleteFolder = deleteFolder
    }
}

private struct TasksTabState: Equatable {
    var folders: [TodoFolder]
    var tasks: [TodoTask]

    init() {
        self.folders = TodoStorage.loadFolders()
        self.tasks = TodoStorage.loadTasks()
    }
}

private func tasksTabEntries(presentationData: PresentationData, state: TasksTabState) -> [TasksTabEntry] {
    var entries: [TasksTabEntry] = []
    let l10n = FenixuzL10n(presentationData.strings)

    if state.folders.isEmpty {
        entries.append(.empty(presentationData.theme, l10n.tasks_folders_empty))
        return entries
    }

    let totalDone = state.tasks.filter { $0.isCompleted }.count
    let totalAll = state.tasks.count
    let header: String
    if totalAll == 0 {
        header = l10n.tasks_section_folders_headerWithCount(state.folders.count)
    } else {
        header = l10n.tasks_section_folders_headerWithProgress(folders: state.folders.count, done: totalDone, total: totalAll)
    }
    entries.append(.header(presentationData.theme, header))

    for (index, folder) in state.folders.enumerated() {
        let folderTasks = state.tasks.filter { $0.folderId == folder.id }
        let totalCount = folderTasks.count
        let doneCount = folderTasks.filter { $0.isCompleted }.count
        entries.append(.folder(index, presentationData.theme, folder, doneCount, totalCount))
    }
    return entries
}

public func tasksTabController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(TasksTabState(), ignoreRepeated: true)
    let stateValue = Atomic(value: TasksTabState())
    let updateState: ((TasksTabState) -> TasksTabState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = TasksTabArguments(
        context: context,
        openFolder: { folder in
            let currentPresentationData = context.sharedContext.currentPresentationData.with { $0 }
            let l10n = FenixuzL10n(currentPresentationData.strings)
            let actionSheet = ActionSheetController(presentationData: currentPresentationData)
            var items: [ActionSheetItem] = []

            items.append(ActionSheetButtonItem(title: l10n.tasks_action_open, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let controller = todoItemController(context: context, folder: folder)
                pushControllerImpl?(controller)
            }))

            items.append(ActionSheetButtonItem(title: currentPresentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                TodoStorage.removeFolder(id: folder.id)
                updateState { state in
                    var state = state
                    state.folders = TodoStorage.loadFolders()
                    state.tasks = TodoStorage.loadTasks()
                    return state
                }
            }))

            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: currentPresentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet)
        },
        deleteFolder: { folderId in
            TodoStorage.removeFolder(id: folderId)
            updateState { state in
                var state = state
                state.folders = TodoStorage.loadFolders()
                state.tasks = TodoStorage.loadTasks()
                return state
            }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, TasksTabArguments)) in
            let l10n = FenixuzL10n(presentationData.strings)

            let rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                let (controller, _) = quickReplyNameAlertController(
                    context: context,
                    text: l10n.tasks_newFolder_title,
                    subtext: l10n.tasks_newFolder_prompt,
                    value: nil,
                    characterLimit: 100,
                    apply: { title in
                        if let title = title, !title.isEmpty {
                            TodoStorage.addFolder(title: title)
                            updateState { state in
                                var state = state
                                state.folders = TodoStorage.loadFolders()
                                return state
                            }
                        }
                    }
                )
                presentControllerImpl?(controller)
            })

            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(l10n.tab_tasks),
                leftNavigationButton: ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {}),
                rightNavigationButton: rightButton,
                backNavigationButton: nil
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: tasksTabEntries(presentationData: presentationData, state: state),
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)

    let initialPresentationData = context.sharedContext.currentPresentationData.with { $0 }
    controller.tabBarItem.title = FenixuzL10n(initialPresentationData.strings).tab_tasks
    // Load the bundled PDF icon. The Contents.json already sets
    // `template-rendering-intent: template` so iOS treats the PDF as a
    // template; an extra `.withRenderingMode(.alwaysTemplate)` was found to
    // suppress the icon entirely in Telegram's custom TabBarController on
    // iOS 26. Upstream tabs (ChatList, Contacts) load the bundleImageName
    // directly without re-asserting rendering mode — match that pattern.
    let tasksIcon = UIImage(bundleImageName: "Chat List/Tabs/IconTasks")
    controller.tabBarItem.image = tasksIcon
    controller.tabBarItem.selectedImage = tasksIcon
    controller.navigationItem.hidesBackButton = true
    controller.navigationItem.leftBarButtonItem = nil

    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }

    return controller
}
