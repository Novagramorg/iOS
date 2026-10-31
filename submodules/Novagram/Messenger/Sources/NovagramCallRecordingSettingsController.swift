import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import NovagramLocalization
import NovagramCalls
import NovagramCallRecordingCore

// The Call recording page, opened from its one row in the Developer section. Like the Camera page in the
// system Settings, every setting has its own block with an explanation under it. The texts come from the SDK
// (CallRecordingSettingsStrings), so the Mac explains each setting with the same words.

private final class NovagramCallRecordingSettingsArguments {
    let updateEnabled: (Bool) -> Void
    let updateAuto: (Bool) -> Void
    let openRecordings: () -> Void

    init(updateEnabled: @escaping (Bool) -> Void, updateAuto: @escaping (Bool) -> Void, openRecordings: @escaping () -> Void) {
        self.updateEnabled = updateEnabled
        self.updateAuto = updateAuto
        self.openRecordings = openRecordings
    }
}

private enum NovagramCallRecordingSettingsSection: Int32 {
    case record
    case auto
    case recordings
    case privacy
}

private enum NovagramCallRecordingSettingsEntry: ItemListNodeEntry {
    case recordHeader(String)
    case record(PresentationTheme, String, Bool)
    case recordFooter(PresentationTheme, String)
    case auto(PresentationTheme, String, Bool)
    case autoFooter(PresentationTheme, String)
    case recordingsHeader(String)
    case recordings(PresentationTheme, String, String)
    case recordingsFooter(PresentationTheme, String)
    case privacyHeader(String)
    case privacyText(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .recordHeader, .record, .recordFooter:
            return NovagramCallRecordingSettingsSection.record.rawValue
        case .auto, .autoFooter:
            return NovagramCallRecordingSettingsSection.auto.rawValue
        case .recordingsHeader, .recordings, .recordingsFooter:
            return NovagramCallRecordingSettingsSection.recordings.rawValue
        case .privacyHeader, .privacyText:
            return NovagramCallRecordingSettingsSection.privacy.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .recordHeader:
            return 0
        case .record:
            return 1
        case .recordFooter:
            return 2
        case .auto:
            return 3
        case .autoFooter:
            return 4
        case .recordingsHeader:
            return 5
        case .recordings:
            return 6
        case .recordingsFooter:
            return 7
        case .privacyHeader:
            return 8
        case .privacyText:
            return 9
        }
    }

    static func == (lhs: NovagramCallRecordingSettingsEntry, rhs: NovagramCallRecordingSettingsEntry) -> Bool {
        switch lhs {
        case let .recordHeader(lhsText):
            if case let .recordHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .record(lhsTheme, lhsTitle, lhsValue):
            if case let .record(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue { return true } else { return false }
        case let .recordFooter(lhsTheme, lhsText):
            if case let .recordFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .auto(lhsTheme, lhsTitle, lhsValue):
            if case let .auto(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue { return true } else { return false }
        case let .autoFooter(lhsTheme, lhsText):
            if case let .autoFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .recordingsHeader(lhsText):
            if case let .recordingsHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .recordings(lhsTheme, lhsTitle, lhsLabel):
            if case let .recordings(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .recordingsFooter(lhsTheme, lhsText):
            if case let .recordingsFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .privacyHeader(lhsText):
            if case let .privacyHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .privacyText(lhsTheme, lhsText):
            if case let .privacyText(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        }
    }

    static func < (lhs: NovagramCallRecordingSettingsEntry, rhs: NovagramCallRecordingSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramCallRecordingSettingsArguments
        switch self {
        case let .recordHeader(text), let .recordingsHeader(text), let .privacyHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .record(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .auto(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAuto(value)
            }, tag: NovagramSettingsItemTag(feature: .callRecordingAuto))
        case let .recordings(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openRecordings()
            }, tag: NovagramSettingsItemTag(feature: .callRecordings))
        case let .recordFooter(_, text), let .autoFooter(_, text), let .recordingsFooter(_, text), let .privacyText(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct NovagramCallRecordingSettingsState: Equatable {
    var isEnabled: Bool
    var isAutoEnabled: Bool
    var recordingCount: Int

    static func current() -> NovagramCallRecordingSettingsState {
        let settings = CallRecordingSettings()
        return NovagramCallRecordingSettingsState(isEnabled: settings.isEnabled, isAutoEnabled: settings.isAutoEnabled, recordingCount: NovagramCallRecordings.storage.list().count)
    }
}

private func novagramCallRecordingSettingsEntries(presentationData: PresentationData, strings: CallRecordingSettingsStrings, state: NovagramCallRecordingSettingsState) -> [NovagramCallRecordingSettingsEntry] {
    let theme = presentationData.theme
    var entries: [NovagramCallRecordingSettingsEntry] = []
    entries.append(.recordHeader(strings.recordingHeader))
    entries.append(.record(theme, strings.recordTitle, state.isEnabled))
    entries.append(.recordFooter(theme, strings.recordFooter))
    // Auto-record only takes effect while recording is on, so it shows only then.
    if state.isEnabled {
        entries.append(.auto(theme, strings.autoTitle, state.isAutoEnabled))
        entries.append(.autoFooter(theme, strings.autoFooter))
    }
    // Always shown: recordings made earlier stay reachable after the switch is turned off.
    entries.append(.recordingsHeader(strings.recordingsHeader))
    entries.append(.recordings(theme, strings.recordingsTitle, state.recordingCount > 0 ? "\(state.recordingCount)" : ""))
    entries.append(.recordingsFooter(theme, strings.recordingsFooter))
    entries.append(.privacyHeader(strings.privacyHeader))
    entries.append(.privacyText(theme, strings.privacyText))
    return entries
}

/// `highlightFeature` is `.callRecordingAuto` or `.callRecordings` when a per-row link opened the page: that row is
/// traced the same way as on the Novagram settings screen.
func novagramCallRecordingSettingsController(context: AccountContext, highlightFeature: NovagramSettingsFeature? = nil) -> ViewController {
    let statePromise = ValuePromise(NovagramCallRecordingSettingsState.current(), ignoreRepeated: true)
    let refreshState: () -> Void = {
        statePromise.set(NovagramCallRecordingSettingsState.current())
    }

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NovagramCallRecordingSettingsArguments(updateEnabled: { value in
        CallRecordingSettings().isEnabled = value
        refreshState()
    }, updateAuto: { value in
        CallRecordingSettings().isAutoEnabled = value
        refreshState()
    }, openRecordings: {
        pushControllerImpl?(novagramCallRecordingsController(context: context))
    })

    // A call can turn auto-record off or save a recording while this page stays open under the call UI.
    let changedObserver = NotificationCenter.default.addObserver(forName: CallRecordingSettings.changedNotification, object: nil, queue: .main) { _ in
        refreshState()
    }

    let latestStrings = Atomic<CallRecordingSettingsStrings?>(value: nil)
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> afterDisposed {
            NotificationCenter.default.removeObserver(changedObserver)
        }
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let strings = CallRecordingSettingsStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
            _ = latestStrings.swap(strings)
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramCallRecordingSettingsEntries(presentationData: presentationData, strings: strings, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    controller.didAppear = { [weak controller] firstTime in
        // Recordings are deleted on the list screen: recount them whenever the page shows again.
        refreshState()
        guard firstTime, let controller else {
            return
        }
        // Press and hold a row to copy or share its link, like on the Novagram settings screen.
        NovagramSettingsRowLinkMenu.attach(to: controller, context: context, title: { feature in
            guard let strings = latestStrings.with({ $0 }) else {
                return nil
            }
            switch feature {
            case .callRecordingAuto:
                return strings.autoTitle
            case .callRecordings:
                return strings.recordingsTitle
            default:
                return nil
            }
        })
        if let highlightFeature {
            let accentColor = context.sharedContext.currentPresentationData.with { $0 }.theme.list.itemAccentColor
            NovagramSettingsHighlight.run(controller: controller, feature: highlightFeature, accentColor: accentColor)
        }
    }
    return controller
}
