import Foundation

// MARK: - Data Models

public struct TodoFolder: Equatable {
    public let id: String
    public var title: String
    public var sortOrder: Int
    public let createdDate: Int32

    // Old convenience init — saqlanadi, eski callerlar buzilmaydi
    public init(title: String) {
        self.id = UUID().uuidString
        self.title = title
        self.sortOrder = 0
        self.createdDate = Int32(Date().timeIntervalSince1970)
    }

    // Full init — SQLite layer ishlatadi
    public init(id: String, title: String, sortOrder: Int, createdDate: Int32) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }
}

public struct TodoTask: Equatable {
    public let id: String
    public let folderId: String
    public var title: String
    public var description: String?
    public var dueAt: Int32?
    public var priority: Int               // 0=none, 1=low, 2=normal, 3=high, 4=urgent
    public var isCompleted: Bool
    public var completedAt: Int32?
    public var sortOrder: Int
    public let createdDate: Int32
    public var updatedAt: Int32

    // Old convenience init — saqlanadi, eski callerlar buzilmaydi
    public init(folderId: String, title: String) {
        let now = Int32(Date().timeIntervalSince1970)
        self.id = UUID().uuidString
        self.folderId = folderId
        self.title = title
        self.description = nil
        self.dueAt = nil
        self.priority = 0
        self.isCompleted = false
        self.completedAt = nil
        self.sortOrder = 0
        self.createdDate = now
        self.updatedAt = now
    }

    // Full init — SQLite layer ishlatadi
    public init(
        id: String, folderId: String, title: String,
        description: String?, dueAt: Int32?, priority: Int,
        isCompleted: Bool, completedAt: Int32?,
        sortOrder: Int, createdDate: Int32, updatedAt: Int32
    ) {
        self.id = id
        self.folderId = folderId
        self.title = title
        self.description = description
        self.dueAt = dueAt
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }
}

// MARK: - Storage Facade
//
// Thin wrapper above TodoDatabase (SQLite). Eski public API saqlanadi —
// mavjud controller'lar (TodoListController, TodoItemController, etc.)
// hech qanday o'zgartirishsiz ishlay beradi. Yangi feature'lar uchun
// TodoDatabase.shared'ni bevosita chaqirsa bo'ladi (due_at, priority,
// search, today/upcoming views uchun).

public final class TodoStorage {
    // MARK: - Folders

    public static func loadFolders() -> [TodoFolder] {
        return TodoDatabase.shared.loadFolders()
    }

    public static func addFolder(title: String) {
        TodoDatabase.shared.addFolder(title: title)
    }

    public static func renameFolder(id: String, title: String) {
        TodoDatabase.shared.updateFolderTitle(id: id, title: title)
    }

    public static func removeFolder(id: String) {
        TodoDatabase.shared.removeFolder(id: id)
    }

    // MARK: - Tasks

    public static func loadTasks() -> [TodoTask] {
        return TodoDatabase.shared.loadTasks()
    }

    public static func loadTasks(folderId: String) -> [TodoTask] {
        return TodoDatabase.shared.loadTasks(folderId: folderId)
    }

    public static func loadTasksDueToday() -> [TodoTask] {
        return TodoDatabase.shared.loadTasksDueToday()
    }

    public static func loadTasksUpcoming() -> [TodoTask] {
        return TodoDatabase.shared.loadTasksUpcoming()
    }

    public static func addTask(folderId: String, title: String) {
        _ = TodoDatabase.shared.addTask(folderId: folderId, title: title)
    }

    @discardableResult
    public static func addTask(folderId: String, title: String, description: String?, dueAt: Int32?, priority: Int) -> TodoTask {
        return TodoDatabase.shared.addTask(folderId: folderId, title: title, description: description, dueAt: dueAt, priority: priority)
    }

    public static func updateTask(id: String, title: String, description: String?, dueAt: Int32?, priority: Int) {
        TodoDatabase.shared.updateTask(id: id, title: title, description: description, dueAt: dueAt, priority: priority)
    }

    public static func toggleTask(id: String) {
        TodoDatabase.shared.toggleTask(id: id)
    }

    public static func removeTask(id: String) {
        TodoDatabase.shared.removeTask(id: id)
    }

    public static func reorderTasks(folderId: String, idsInOrder: [String]) {
        TodoDatabase.shared.reorderTasks(folderId: folderId, idsInOrder: idsInOrder)
    }

    public static func searchTasks(query: String) -> [TodoTask] {
        return TodoDatabase.shared.searchTasks(query: query)
    }

    public static func countActiveAndTotal(folderId: String) -> (done: Int, total: Int) {
        return TodoDatabase.shared.countActiveAndTotal(folderId: folderId)
    }
}
