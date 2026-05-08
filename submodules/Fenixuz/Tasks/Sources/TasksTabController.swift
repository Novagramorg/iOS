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

// MARK: - Unified Entry

private enum TasksTabSection: Int32 {
    case main = 0
}

private enum TasksTabEntry: ItemListNodeEntry {
    // Scheduled entries
    case scheduledHeader(PresentationTheme, String)
    case scheduledTask(Int, PresentationTheme, ScheduledTask)
    case scheduledEmpty(PresentationTheme, String)
    // Todo entries
    case todoFolder(Int, PresentationTheme, TodoFolder, Int, Int) // index, theme, folder, doneCount, totalCount
    case todoEmpty(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return TasksTabSection.main.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .scheduledHeader:
            return -100
        case .scheduledEmpty:
            return -99
        case let .scheduledTask(index, _, _):
            return Int32(index)
        case .todoEmpty:
            return -98
        case let .todoFolder(index, _, _, _, _):
            return Int32(index + 1000)
        }
    }
    
    static func ==(lhs: TasksTabEntry, rhs: TasksTabEntry) -> Bool {
        switch lhs {
        case let .scheduledHeader(lhsTheme, lhsText):
            if case let .scheduledHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .scheduledTask(lhsIndex, lhsTheme, lhsTask):
            if case let .scheduledTask(rhsIndex, rhsTheme, rhsTask) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTask == rhsTask { return true }
            return false
        case let .scheduledEmpty(lhsTheme, lhsText):
            if case let .scheduledEmpty(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        case let .todoFolder(lhsIndex, lhsTheme, lhsFolder, lhsDone, lhsTotal):
            if case let .todoFolder(rhsIndex, rhsTheme, rhsFolder, rhsDone, rhsTotal) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsFolder == rhsFolder, lhsDone == rhsDone, lhsTotal == rhsTotal { return true }
            return false
        case let .todoEmpty(lhsTheme, lhsText):
            if case let .todoEmpty(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true }
            return false
        }
    }
    
    static func <(lhs: TasksTabEntry, rhs: TasksTabEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TasksTabArguments
        switch self {
        case let .scheduledHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .scheduledTask(_, _, task):
            let dateStr = formatTaskDate(task.scheduledDate)
            return ItemListDisclosureItem(presentationData: presentationData, title: task.peerTitle, label: dateStr, labelStyle: .text, sectionId: self.section, style: .blocks, action: {
                arguments.openScheduledTask(task)
            })
        case let .scheduledEmpty(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .todoFolder(_, _, folder, doneCount, totalCount):
            let label = totalCount > 0 ? "\(doneCount)/\(totalCount)" : "0"
            let badgeColor = doneCount == totalCount && totalCount > 0 ? UIColor(rgb: 0x34c759) : presentationData.theme.list.itemAccentColor
            return ItemListDisclosureItem(presentationData: presentationData, title: folder.title, label: label, labelStyle: .badge(badgeColor), sectionId: self.section, style: .blocks, action: {
                arguments.openTodoFolder(folder)
            })
        case let .todoEmpty(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func formatTaskDate(_ timestamp: Int32) -> String {
    let date = Date(timeIntervalSince1970: Double(timestamp))
    let now = Date()
    let calendar = Calendar.current

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    let timeString = timeFormatter.string(from: date)

    if calendar.isDateInToday(date) {
        return "Bugun, \(timeString)"
    }
    if calendar.isDateInTomorrow(date) {
        return "Ertaga, \(timeString)"
    }
    if calendar.isDateInYesterday(date) {
        return "Kecha, \(timeString)"
    }

    let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    let dayFormatter = DateFormatter()
    dayFormatter.locale = Locale(identifier: "uz_UZ")

    if daysBetween > 0 && daysBetween < 7 {
        dayFormatter.dateFormat = "EEEE, HH:mm"
        return dayFormatter.string(from: date).capitalized
    }

    if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
        dayFormatter.dateFormat = "d MMM, HH:mm"
    } else {
        dayFormatter.dateFormat = "d MMM yyyy"
    }
    return dayFormatter.string(from: date)
}

// MARK: - Arguments

private final class TasksTabArguments {
    let context: AccountContext
    let openScheduledTask: (ScheduledTask) -> Void
    let deleteScheduledTask: (String) -> Void
    let openTodoFolder: (TodoFolder) -> Void
    let deleteTodoFolder: (String) -> Void
    let present: (ViewController) -> Void
    
    init(context: AccountContext, openScheduledTask: @escaping (ScheduledTask) -> Void, deleteScheduledTask: @escaping (String) -> Void, openTodoFolder: @escaping (TodoFolder) -> Void, deleteTodoFolder: @escaping (String) -> Void, present: @escaping (ViewController) -> Void) {
        self.context = context
        self.openScheduledTask = openScheduledTask
        self.deleteScheduledTask = deleteScheduledTask
        self.openTodoFolder = openTodoFolder
        self.deleteTodoFolder = deleteTodoFolder
        self.present = present
    }
}

// MARK: - State

private struct TasksTabState: Equatable {
    var selectedSegment: Int
    var scheduledTasks: [ScheduledTask]
    var todoFolders: [TodoFolder]
    var todoTasks: [TodoTask]
    
    init() {
        self.selectedSegment = 0
        self.scheduledTasks = ScheduledTaskStorage.loadTasks()
        self.todoFolders = TodoStorage.loadFolders()
        self.todoTasks = TodoStorage.loadTasks()
    }
}

// MARK: - Entries Builder

private func tasksTabEntries(presentationData: PresentationData, state: TasksTabState) -> [TasksTabEntry] {
    var entries: [TasksTabEntry] = []
    
    if state.selectedSegment == 0 {
        let pending = state.scheduledTasks.filter { !$0.isSent }.sorted { $0.scheduledDate < $1.scheduledDate }
        let header = pending.isEmpty ? "REJALASHTIRILGAN" : "REJALASHTIRILGAN — \(pending.count) TA"
        entries.append(.scheduledHeader(presentationData.theme, header))
        if pending.isEmpty {
            entries.append(.scheduledEmpty(presentationData.theme, "📅\n\nRejalashtirilgan xabarlar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi rejani qo'shing."))
        } else {
            for (index, task) in pending.enumerated() {
                entries.append(.scheduledTask(index, presentationData.theme, task))
            }
        }
    } else {
        if state.todoFolders.isEmpty {
            entries.append(.todoEmpty(presentationData.theme, "🗂\n\nPapkalar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi papkangizni yarating."))
        } else {
            let totalDone = state.todoTasks.filter { $0.isCompleted }.count
            let totalAll = state.todoTasks.count
            let header: String
            if totalAll == 0 {
                header = "PAPKALAR — \(state.todoFolders.count) TA"
            } else {
                header = "PAPKALAR — \(state.todoFolders.count) TA · \(totalDone)/\(totalAll) BAJARILDI"
            }
            entries.append(.scheduledHeader(presentationData.theme, header))
            for (index, folder) in state.todoFolders.enumerated() {
                let folderTasks = state.todoTasks.filter { $0.folderId == folder.id }
                let totalCount = folderTasks.count
                let doneCount = folderTasks.filter { $0.isCompleted }.count
                entries.append(.todoFolder(index, presentationData.theme, folder, doneCount, totalCount))
            }
        }
    }

    return entries
}

// MARK: - Controller

public func tasksTabController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(TasksTabState(), ignoreRepeated: true)
    let stateValue = Atomic(value: TasksTabState())
    let updateState: ((TasksTabState) -> TasksTabState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var navigateToChatImpl: ((PeerId) -> Void)?
    
    let arguments = TasksTabArguments(
        context: context,
        openScheduledTask: { task in
            let currentPresentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: currentPresentationData)
            var items: [ActionSheetItem] = []
            
            items.append(ActionSheetButtonItem(title: "Chatga o'tish", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                navigateToChatImpl?(PeerId(task.peerId))
            }))
            
            items.append(ActionSheetButtonItem(title: "O'chirish", color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                ScheduledTaskStorage.removeTask(id: task.id)
                updateState { state in
                    var state = state
                    state.scheduledTasks = ScheduledTaskStorage.loadTasks()
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
        deleteScheduledTask: { taskId in
            ScheduledTaskStorage.removeTask(id: taskId)
            updateState { state in
                var state = state
                state.scheduledTasks = ScheduledTaskStorage.loadTasks()
                return state
            }
        },
        openTodoFolder: { folder in
            let currentPresentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: currentPresentationData)
            var items: [ActionSheetItem] = []
            
            items.append(ActionSheetButtonItem(title: "Ochish", color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let controller = todoItemController(context: context, folder: folder)
                pushControllerImpl?(controller)
            }))
            
            items.append(ActionSheetButtonItem(title: "O'chirish", color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                TodoStorage.removeFolder(id: folder.id)
                updateState { state in
                    var state = state
                    state.todoFolders = TodoStorage.loadFolders()
                    state.todoTasks = TodoStorage.loadTasks()
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
        deleteTodoFolder: { folderId in
            TodoStorage.removeFolder(id: folderId)
            updateState { state in
                var state = state
                state.todoFolders = TodoStorage.loadFolders()
                state.todoTasks = TodoStorage.loadTasks()
                return state
            }
        },
        present: { c in
            presentControllerImpl?(c)
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, TasksTabArguments)) in
            let rightButton: ItemListNavigationButton
            if state.selectedSegment == 0 {
                // Scheduled: "+" opens peer picker
                rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
                        context: context,
                        hasChatListSelector: true,
                        hasContactSelector: false,
                        title: "Kimga yuborish?"
                    ))
                    controller.peerSelected = { peer, _ in
                        let peerTitle = peer.displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder)
                        let task = ScheduledTask(peerId: peer.id.toInt64(), peerTitle: peerTitle, messageText: "", scheduledDate: Int32(Date().timeIntervalSince1970))
                        ScheduledTaskStorage.addTask(task)
                        updateState { state in
                            var state = state
                            state.scheduledTasks = ScheduledTaskStorage.loadTasks()
                            return state
                        }
                        navigateToChatImpl?(peer.id)
                    }
                    pushControllerImpl?(controller)
                })
            } else {
                // Task: "+" creates new folder
                rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                    let (controller, _) = quickReplyNameAlertController(context: context, text: "Yangi papka", subtext: "Papka nomini kiriting", value: nil, characterLimit: 100, apply: { title in
                        if let title = title, !title.isEmpty {
                            TodoStorage.addFolder(title: title)
                            updateState { state in
                                var state = state
                                state.todoFolders = TodoStorage.loadFolders()
                                return state
                            }
                        }
                    })
                    presentControllerImpl?(controller)
                })
            }
            
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .sectionControl(["Rejalashtirilgan", "Task"], state.selectedSegment),
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
    controller.tabBarItem.title = "Vazifalar"
    if #available(iOS 13.0, *) {
        let config = UIImage.SymbolConfiguration(weight: .medium)
        controller.tabBarItem.image = UIImage(systemName: "checklist", withConfiguration: config)
        controller.tabBarItem.selectedImage = UIImage(systemName: "checklist", withConfiguration: config)
    } else {
        controller.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconTasks")
        controller.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconTasks")
    }
    controller.navigationItem.hidesBackButton = true
    controller.navigationItem.leftBarButtonItem = nil
    
    // Handle segment change
    controller.titleControlValueChanged = { (index: Int) in
        updateState { state in
            var state = state
            state.selectedSegment = index
            return state
        }
    }
    
    // Refresh from storage when controller appears
    controller.didAppear = { (_: Bool) in
        updateState { state in
            var state = state
            state.scheduledTasks = ScheduledTaskStorage.loadTasks()
            state.todoFolders = TodoStorage.loadFolders()
            state.todoTasks = TodoStorage.loadTasks()
            return state
        }
    }
    
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: PresentationContextType.window(PresentationSurfaceLevel.root))
    }
    navigateToChatImpl = { [weak controller] (peerId: PeerId) in
        guard let controller = controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: context,
                chatLocation: .peer(peer),
                subject: .scheduledMessages,
                keepStack: .always
            ))
        })
    }
    
    return controller
}
