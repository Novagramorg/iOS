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

private enum TodoListSection: Int32 {
    case folders = 0
}

private enum TodoListEntry: ItemListNodeEntry {
    case folder(Int, PresentationTheme, TodoFolder, Int) // Int count of tasks
    case emptyState(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return TodoListSection.folders.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .emptyState:
            return -1
        case let .folder(index, _, _, _):
            return Int32(index)
        }
    }
    
    static func ==(lhs: TodoListEntry, rhs: TodoListEntry) -> Bool {
        switch lhs {
        case let .folder(lhsIndex, lhsTheme, lhsFolder, lhsCount):
            if case let .folder(rhsIndex, rhsTheme, rhsFolder, rhsCount) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsFolder == rhsFolder, lhsCount == rhsCount {
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
    
    static func <(lhs: TodoListEntry, rhs: TodoListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TodoListArguments
        switch self {
        case let .folder(_, _, folder, count):
            return ItemListDisclosureItem(presentationData: presentationData, title: folder.title, label: "\(count)", labelStyle: .badge(presentationData.theme.list.itemAccentColor), sectionId: self.section, style: .blocks, action: {
                arguments.openFolder(folder)
            })
        case let .emptyState(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class TodoListArguments {
    let openFolder: (TodoFolder) -> Void
    
    init(openFolder: @escaping (TodoFolder) -> Void) {
        self.openFolder = openFolder
    }
}

private struct TodoListState: Equatable {
    var folders: [TodoFolder]
    var tasks: [TodoTask]
    
    init() {
        self.folders = TodoStorage.loadFolders()
        self.tasks = TodoStorage.loadTasks()
    }
}

private func todoListEntries(presentationData: PresentationData, state: TodoListState) -> [TodoListEntry] {
    var entries: [TodoListEntry] = []
    
    if state.folders.isEmpty {
        entries.append(.emptyState(presentationData.theme, "Sizda hozircha papkalar yo'q. Yangi qo'shing."))
    } else {
        for (index, folder) in state.folders.enumerated() {
            let count = state.tasks.filter { $0.folderId == folder.id }.count
            entries.append(.folder(index, presentationData.theme, folder, count))
        }
    }
    
    return entries
}

public func todoListController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(TodoListState(), ignoreRepeated: true)
    let stateValue = Atomic(value: TodoListState())
    let updateState: ((TodoListState) -> TodoListState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = TodoListArguments(openFolder: { folder in
        let controller = todoItemController(context: context, folder: folder)
        pushControllerImpl?(controller)
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, TodoListArguments)) in
            let rightButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                let (controller, _) = quickReplyNameAlertController(context: context, text: "Yangi papka", subtext: "Papka nomini kiriting", value: nil, characterLimit: 100, apply: { title in
                    if let title = title, !title.isEmpty {
                        TodoStorage.addFolder(title: title)
                        updateState { state in
                            var state = state
                            state.folders = TodoStorage.loadFolders()
                            return state
                        }
                    }
                })
                presentControllerImpl?(controller)
            })
            
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text("Task List"),
                leftNavigationButton: nil,
                rightNavigationButton: rightButton,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: todoListEntries(presentationData: presentationData, state: state),
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: PresentationContextType.window(PresentationSurfaceLevel.root))
    }
    
    controller.didAppear = { (_: Bool) in
        updateState { state in
            var state = state
            state.tasks = TodoStorage.loadTasks()
            state.folders = TodoStorage.loadFolders()
            return state
        }
    }
    
    return controller
}
