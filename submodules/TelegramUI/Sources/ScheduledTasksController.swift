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

// MARK: - Data Model

struct ScheduledTask: Codable, Equatable {
    let id: String
    let peerId: Int64
    let peerTitle: String
    let messageText: String
    let scheduledDate: Int32
    let createdDate: Int32
    var isSent: Bool
    
    init(peerId: Int64, peerTitle: String, messageText: String, scheduledDate: Int32) {
        self.id = UUID().uuidString
        self.peerId = peerId
        self.peerTitle = peerTitle
        self.messageText = messageText
        self.scheduledDate = scheduledDate
        self.createdDate = Int32(Date().timeIntervalSince1970)
        self.isSent = false
    }
}

final class ScheduledTaskStorage {
    private static let key = "scheduled_tasks_list"
    private static let suiteName = "pro_messager"
    
    static func loadTasks() -> [ScheduledTask] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([ScheduledTask].self, from: data)) ?? []
    }
    
    static func saveTasks(_ tasks: [ScheduledTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
        }
    }
    
    static func addTask(_ task: ScheduledTask) {
        var tasks = loadTasks()
        if !tasks.contains(where: { $0.peerId == task.peerId }) {
            tasks.append(task)
            saveTasks(tasks)
        }
    }
    
    static func removeTask(id: String) {
        var tasks = loadTasks()
        tasks.removeAll { $0.id == id }
        saveTasks(tasks)
    }
    
    static func markSent(id: String) {
        var tasks = loadTasks()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isSent = true
            saveTasks(tasks)
        }
    }
}

// MARK: - Entry

private enum ScheduledTasksSection: Int32 {
    case pending = 0
    case completed = 1
}

private enum ScheduledTasksEntry: ItemListNodeEntry {
    case pendingHeader(PresentationTheme, String)
    case pendingTask(Int, PresentationTheme, ScheduledTask)
    case emptyState(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .pendingHeader, .pendingTask, .emptyState:
            return ScheduledTasksSection.pending.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .pendingHeader:
            return -2
        case .emptyState:
            return -1
        case let .pendingTask(index, _, _):
            return Int32(index)
        }
    }
    
    static func ==(lhs: ScheduledTasksEntry, rhs: ScheduledTasksEntry) -> Bool {
        switch lhs {
        case let .pendingHeader(lhsTheme, lhsText):
            if case let .pendingHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .pendingTask(lhsIndex, lhsTheme, lhsTask):
            if case let .pendingTask(rhsIndex, rhsTheme, rhsTask) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTask == rhsTask {
                return true
            }
            return false
        case let .emptyState(lhsTheme, lhsText):
            if case let .emptyState(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: ScheduledTasksEntry, rhs: ScheduledTasksEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ScheduledTasksArguments
        switch self {
        case let .pendingHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .pendingTask(_, _, task):
            let dateStr = formatScheduledDate(task.scheduledDate)
            return ItemListDisclosureItem(presentationData: presentationData, title: task.peerTitle, label: dateStr, labelStyle: .text, sectionId: self.section, style: .blocks, action: {
                let currentPresentationData = arguments.context.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: currentPresentationData)
                var items: [ActionSheetItem] = []
                
                items.append(ActionSheetButtonItem(title: "Chatga o'tish", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    arguments.openTask(task)
                }))
                
                items.append(ActionSheetButtonItem(title: "O'chirish", color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    arguments.deleteTask(task.id)
                }))
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: currentPresentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                arguments.present(actionSheet)
            })
        case let .emptyState(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func formatScheduledDate(_ timestamp: Int32) -> String {
    let date = Date(timeIntervalSince1970: Double(timestamp))
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    return formatter.string(from: date)
}

// MARK: - Arguments

private final class ScheduledTasksArguments {
    let context: AccountContext
    let openTask: (ScheduledTask) -> Void
    let deleteTask: (String) -> Void
    let addTask: () -> Void
    let present: (ViewController) -> Void
    
    init(context: AccountContext, openTask: @escaping (ScheduledTask) -> Void, deleteTask: @escaping (String) -> Void, addTask: @escaping () -> Void, present: @escaping (ViewController) -> Void) {
        self.context = context
        self.openTask = openTask
        self.deleteTask = deleteTask
        self.addTask = addTask
        self.present = present
    }
}

// MARK: - State

private struct ScheduledTasksState: Equatable {
    var tasks: [ScheduledTask]
    
    init() {
        self.tasks = ScheduledTaskStorage.loadTasks()
    }
}

// MARK: - Entries Builder

private func scheduledTasksEntries(presentationData: PresentationData, state: ScheduledTasksState) -> [ScheduledTasksEntry] {
    var entries: [ScheduledTasksEntry] = []
    
    let pending = state.tasks.filter { !$0.isSent }.sorted { $0.scheduledDate < $1.scheduledDate }
    
    entries.append(.pendingHeader(presentationData.theme, "REJALASHTIRILGAN"))
    
    if pending.isEmpty {
        entries.append(.emptyState(presentationData.theme, "Rejalashtirilgan xabarlar yo'q.\n\"+\" tugmasini bosib yangi task qo'shing."))
    } else {
        for (index, task) in pending.enumerated() {
            entries.append(.pendingTask(index, presentationData.theme, task))
        }
    }
    
    return entries
}

// MARK: - Controller

public func scheduledTasksController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(ScheduledTasksState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ScheduledTasksState())
    let updateState: ((ScheduledTasksState) -> ScheduledTasksState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var navigateToChatImpl: ((PeerId) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ScheduledTasksArguments(
        context: context,
        openTask: { task in
            let peerId = PeerId(task.peerId)
            navigateToChatImpl?(peerId)
        },
        deleteTask: { taskId in
            ScheduledTaskStorage.removeTask(id: taskId)
            updateState { state in
                var state = state
                state.tasks = ScheduledTaskStorage.loadTasks()
                return state
            }
        },
        addTask: {},
        present: { c in
            presentControllerImpl?(c)
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, ScheduledTasksArguments)) in
            let rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                // Open chat-list style peer picker with search and folders
                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
                    context: context,
                    hasChatListSelector: true,
                    hasContactSelector: false,
                    title: "Kimga yuborish?"
                ))
                controller.peerSelected = { peer, _ in
                    // Save peer to task storage and update list, then navigate
                    let peerTitle = peer.displayTitle(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, displayOrder: context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder)
                    let task = ScheduledTask(peerId: peer.id.toInt64(), peerTitle: peerTitle, messageText: "", scheduledDate: Int32(Date().timeIntervalSince1970))
                    ScheduledTaskStorage.addTask(task)
                    updateState { state in
                        var state = state
                        state.tasks = ScheduledTaskStorage.loadTasks()
                        return state
                    }
                    navigateToChatImpl?(peer.id)
                }
                pushControllerImpl?(controller)
            })
            
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text("Vazifalar"),
                leftNavigationButton: ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {}),
                rightNavigationButton: rightButton,
                backNavigationButton: nil
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: scheduledTasksEntries(presentationData: presentationData, state: state),
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    
    // Refresh list from storage whenever controller appears (e.g., returning from chat)
    controller.didAppear = { _ in
        updateState { state in
            var state = state
            state.tasks = ScheduledTaskStorage.loadTasks()
            return state
        }
    }
    
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: PresentationContextType.window(PresentationSurfaceLevel.root))
    }
    navigateToChatImpl = { [weak controller] peerId in
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
    
    controller.updateTabBarSearchState(ViewController.TabBarSearchState(isActive: false), transition: .immediate)
    
    return controller
}
