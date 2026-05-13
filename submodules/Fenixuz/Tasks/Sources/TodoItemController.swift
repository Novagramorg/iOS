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
import QuickReplyNameAlertController
import AlertUI
import FenixuzLocalization

private enum TodoItemSection: Int32 {
    case tasks = 0
}

private enum TodoItemEntry: ItemListNodeEntry {
    case task(Int, PresentationTheme, TodoTask)
    case emptyState(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return TodoItemSection.tasks.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .emptyState:
            return -1
        case let .task(index, _, _):
            return Int32(index)
        }
    }
    
    static func ==(lhs: TodoItemEntry, rhs: TodoItemEntry) -> Bool {
        switch lhs {
        case let .task(lhsIndex, lhsTheme, lhsTask):
            if case let .task(rhsIndex, rhsTheme, rhsTask) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTask == rhsTask {
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
    
    static func <(lhs: TodoItemEntry, rhs: TodoItemEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TodoItemArguments
        switch self {
        case let .task(_, _, task):
            // We use standard list item with checkmark option
            return ItemListSwitchItem(presentationData: presentationData, title: task.title, value: task.isCompleted, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleTask(task)
            })
        case let .emptyState(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class TodoItemArguments {
    let toggleTask: (TodoTask) -> Void
    
    init(toggleTask: @escaping (TodoTask) -> Void) {
        self.toggleTask = toggleTask
    }
}

private struct TodoItemState: Equatable {
    var tasks: [TodoTask]
    
    init(folderId: String) {
        self.tasks = TodoStorage.loadTasks().filter { $0.folderId == folderId }
    }
}

private func todoItemEntries(presentationData: PresentationData, state: TodoItemState) -> [TodoItemEntry] {
    var entries: [TodoItemEntry] = []
    let l10n = FenixuzL10n(presentationData.strings)

    if state.tasks.isEmpty {
        entries.append(.emptyState(presentationData.theme, l10n.tasks_items_empty))
    } else {
        for (index, task) in state.tasks.enumerated() {
            entries.append(.task(index, presentationData.theme, task))
        }
    }
    
    return entries
}

public func todoItemController(context: AccountContext, folder: TodoFolder) -> ViewController {
    let statePromise = ValuePromise(TodoItemState(folderId: folder.id), ignoreRepeated: true)
    let stateValue = Atomic(value: TodoItemState(folderId: folder.id))
    let updateState: ((TodoItemState) -> TodoItemState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = TodoItemArguments(toggleTask: { task in
        TodoStorage.toggleTask(id: task.id)
        updateState { state in
            var state = state
            state.tasks = TodoStorage.loadTasks().filter { $0.folderId == folder.id }
            return state
        }
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, TodoItemArguments)) in
            let l10n = FenixuzL10n(presentationData.strings)
            let rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                let (controller, _) = quickReplyNameAlertController(context: context, text: l10n.tasks_newTask_title, subtext: l10n.tasks_newTask_prompt, value: nil, characterLimit: 200, apply: { title in
                    if let title = title, !title.isEmpty {
                        TodoStorage.addTask(folderId: folder.id, title: title)
                        updateState { state in
                            var state = state
                            state.tasks = TodoStorage.loadTasks().filter { $0.folderId == folder.id }
                            return state
                        }
                    }
                })
                presentControllerImpl?(controller)
            })
            
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(folder.title),
                leftNavigationButton: nil,
                rightNavigationButton: rightButton,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: todoItemEntries(presentationData: presentationData, state: state),
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: PresentationContextType.window(PresentationSurfaceLevel.root))
    }
    
    controller.didAppear = { (_: Bool) in
        updateState { state in
            var state = state
            state.tasks = TodoStorage.loadTasks().filter { $0.folderId == folder.id }
            return state
        }
    }
    
    return controller
}
