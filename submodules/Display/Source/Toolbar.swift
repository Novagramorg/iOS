import Foundation
import UIKit

public struct ToolbarAction: Equatable {
    public enum Color: Equatable {
        case accent
        case custom(UIColor)
    }

    public let title: String
    public let isEnabled: Bool
    public let color: Color
    
    public init(title: String, isEnabled: Bool, color: Color = .accent) {
        self.title = title
        self.isEnabled = isEnabled
        self.color = color
    }
}

public struct Toolbar: Equatable {
    public let leftAction: ToolbarAction?
    public let rightAction: ToolbarAction?
    public let middleAction: ToolbarAction?
    // Fenixuz Secret Vault: optional 4th bulk action ("Hide to Vault"). Defaults to
    // nil so every existing Toolbar call site is unaffected.
    public let extraAction: ToolbarAction?
    
    public init(leftAction: ToolbarAction?, rightAction: ToolbarAction?, middleAction: ToolbarAction?, extraAction: ToolbarAction? = nil) {
        self.leftAction = leftAction
        self.rightAction = rightAction
        self.middleAction = middleAction
        self.extraAction = extraAction
    }
}
