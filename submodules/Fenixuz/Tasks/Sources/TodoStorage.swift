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

// MARK: - Data Models

public struct TodoFolder: Codable, Equatable {
    public let id: String
    public var title: String
    public let createdDate: Int32
    
    public init(title: String) {
        self.id = UUID().uuidString
        self.title = title
        self.createdDate = Int32(Date().timeIntervalSince1970)
    }
}

public struct TodoTask: Codable, Equatable {
    public let id: String
    public let folderId: String
    public var title: String
    public var isCompleted: Bool
    public let createdDate: Int32
    
    public init(folderId: String, title: String) {
        self.id = UUID().uuidString
        self.folderId = folderId
        self.title = title
        self.isCompleted = false
        self.createdDate = Int32(Date().timeIntervalSince1970)
    }
}

public final class TodoStorage {
    private static let foldersKey = "todo_folders_list"
    private static let tasksKey = "todo_tasks_list"
    private static let suiteName = "pro_messager"
    
    public static func loadFolders() -> [TodoFolder] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: foldersKey) else { return [] }
        return (try? JSONDecoder().decode([TodoFolder].self, from: data)) ?? []
    }
    
    public static func saveFolders(_ folders: [TodoFolder]) {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults(suiteName: suiteName)?.set(data, forKey: foldersKey)
        }
    }
    
    public static func addFolder(title: String) {
        var folders = loadFolders()
        folders.append(TodoFolder(title: title))
        saveFolders(folders)
    }
    
    public static func removeFolder(id: String) {
        var folders = loadFolders()
        folders.removeAll { $0.id == id }
        saveFolders(folders)
        
        var tasks = loadTasks()
        tasks.removeAll { $0.folderId == id }
        saveTasks(tasks)
    }
    
    public static func loadTasks() -> [TodoTask] {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: tasksKey) else { return [] }
        return (try? JSONDecoder().decode([TodoTask].self, from: data)) ?? []
    }
    
    public static func saveTasks(_ tasks: [TodoTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults(suiteName: suiteName)?.set(data, forKey: tasksKey)
        }
    }
    
    public static func addTask(folderId: String, title: String) {
        var tasks = loadTasks()
        tasks.append(TodoTask(folderId: folderId, title: title))
        saveTasks(tasks)
    }
    
    public static func toggleTask(id: String) {
        var tasks = loadTasks()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isCompleted.toggle()
            saveTasks(tasks)
        }
    }
    
    public static func removeTask(id: String) {
        var tasks = loadTasks()
        tasks.removeAll { $0.id == id }
        saveTasks(tasks)
    }
}
