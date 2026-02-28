import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI

// MARK: - Available Text Styles

public enum ProMessagerTextStyle: String, CaseIterable {
    case none          = "none"
    case bold          = "bold"
    case italic        = "italic"
    case monospace     = "monospace"
    case strikethrough = "strikethrough"
    case underline     = "underline"
    case spoiler       = "spoiler"
    
    public var displayName: String {
        switch self {
        case .none:          return "Uslubsiz (Oddiy)"
        case .bold:          return "Qalin (Bold)"
        case .italic:        return "Kiyshiq (Italic)"
        case .monospace:     return "Monospace (Kod)"
        case .strikethrough: return "Chizilgan (Strikethrough)"
        case .underline:     return "Tagiga chizilgan (Underline)"
        case .spoiler:       return "Spoiler"
        }
    }
    
    public static var current: ProMessagerTextStyle {
        let rawValue = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        return ProMessagerTextStyle(rawValue: rawValue) ?? .none
    }
}

// MARK: - Section & Entry

private enum TextStyleSection: Int32 {
    case styles
}

private enum TextStyleEntry: ItemListNodeEntry {
    case styleItem(Int32, PresentationTheme, String, Bool, ProMessagerTextStyle)
    
    var section: ItemListSectionId {
        return TextStyleSection.styles.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case let .styleItem(index, _, _, _, _):
            return index
        }
    }
    
    static func ==(lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.styleItem(li, lt, ln, ls, lStyle), .styleItem(ri, rt, rn, rs, rStyle)):
            return li == ri && lt === rt && ln == rn && ls == rs && lStyle == rStyle
        }
    }
    
    static func <(lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TextStyleArguments
        switch self {
        case let .styleItem(_, theme, name, isSelected, style):
            let label = isSelected ? "✓ Tanlangan" : ""
            let labelStyle: ItemListDisclosureLabelStyle = isSelected
                ? .badge(theme.list.itemAccentColor)
                : .text
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: name,
                label: label,
                labelStyle: labelStyle,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.selectStyle(style)
                }
            )
        }
    }
}

// MARK: - State

private struct TextStyleControllerState: Equatable {
    var selectedStyle: ProMessagerTextStyle
    
    init() {
        self.selectedStyle = ProMessagerTextStyle.current
    }
}

// MARK: - Arguments

private final class TextStyleArguments {
    let selectStyle: (ProMessagerTextStyle) -> Void
    
    init(selectStyle: @escaping (ProMessagerTextStyle) -> Void) {
        self.selectStyle = selectStyle
    }
}

// MARK: - Entries builder

private func textStyleEntries(
    presentationData: PresentationData,
    state: TextStyleControllerState
) -> [TextStyleEntry] {
    var entries: [TextStyleEntry] = []
    for (index, style) in ProMessagerTextStyle.allCases.enumerated() {
        let isSelected = state.selectedStyle == style
        entries.append(.styleItem(
            Int32(index),
            presentationData.theme,
            style.displayName,
            isSelected,
            style
        ))
    }
    return entries
}

// MARK: - Controller factory

public func proMessagerTextStyleController(context: AccountContext, onStyleSelected: @escaping (String) -> Void = { _ in }) -> ViewController {
    let statePromise = ValuePromise(TextStyleControllerState(), ignoreRepeated: true)
    let stateValue  = Atomic(value: TextStyleControllerState())
    
    let updateState: ((TextStyleControllerState) -> TextStyleControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = TextStyleArguments(selectStyle: { style in
        UserDefaults(suiteName: "pro_messager")?.set(style.rawValue, forKey: "text_style")
        onStyleSelected(style.rawValue)
        updateState { state in
            var state = state
            state.selectedStyle = style
            return state
        }
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Xabar uslubi"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: textStyleEntries(presentationData: presentationData, state: state),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }
    
    return ItemListController(context: context, state: signal)
}
