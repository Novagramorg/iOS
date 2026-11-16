import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import OverlayStatusController
import NovagramLocalization

// "Ads tekshiruvi" (Developer section): pick an environment, run one read-only check, copy the result.
// The requests themselves live in NovagramSponsored (NovagramAdsCheckRunner), reached through
// `NovagramAdsCheck.provider`.

private final class NovagramAdsCheckArguments {
    let selectEnvironment: (Bool) -> Void
    let run: () -> Void
    let copy: () -> Void

    init(selectEnvironment: @escaping (Bool) -> Void, run: @escaping () -> Void, copy: @escaping () -> Void) {
        self.selectEnvironment = selectEnvironment
        self.run = run
        self.copy = copy
    }
}

private enum NovagramAdsCheckSection: Int32 {
    case environment
    case run
    case result
    case copy
}

private enum NovagramAdsCheckTone: Equatable {
    case hit
    case empty
    case failed
}

private enum NovagramAdsCheckEntry: ItemListNodeEntry {
    case environmentHeader(String)
    case environment(Bool, String, Bool)
    case run(String, Bool)
    case runFooter(String)
    case resultHeader(String)
    case slot(Int32, String, String, NovagramAdsCheckTone, String?)
    case resultFooter(String)
    case notReady(String)
    case copy(String)

    var section: ItemListSectionId {
        switch self {
        case .environmentHeader, .environment:
            return NovagramAdsCheckSection.environment.rawValue
        case .run, .runFooter:
            return NovagramAdsCheckSection.run.rawValue
        case .resultHeader, .slot, .resultFooter, .notReady:
            return NovagramAdsCheckSection.result.rawValue
        case .copy:
            return NovagramAdsCheckSection.copy.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .environmentHeader:
            return 0
        case let .environment(production, _, _):
            return production ? 1 : 2
        case .run:
            return 3
        case .runFooter:
            return 4
        case .resultHeader:
            return 10
        case let .slot(index, _, _, _, _):
            return 11 + index
        case .resultFooter:
            return 30
        case .notReady:
            return 31
        case .copy:
            return 40
        }
    }

    static func < (lhs: NovagramAdsCheckEntry, rhs: NovagramAdsCheckEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        // ItemListController always passes the arguments built in novagramAdsCheckController.
        // swiftlint:disable:next force_cast
        let arguments = arguments as! NovagramAdsCheckArguments
        switch self {
        case let .environmentHeader(text), let .resultHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .environment(production, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectEnvironment(production)
            })
        case let .run(title, running):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: running ? .disabled : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.run()
            })
        case let .runFooter(text), let .resultFooter(text), let .notReady(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .slot(_, title, label, tone, detail):
            let theme = presentationData.theme
            let labelColor: UIColor
            let detailColor: ItemListDisclosureItemDetailLabelColor
            switch tone {
            case .hit:
                labelColor = theme.list.itemDisclosureActions.constructive.fillColor
                detailColor = .constructive
            case .empty:
                labelColor = theme.list.itemSecondaryTextColor
                detailColor = .generic
            case .failed:
                labelColor = theme.list.itemDestructiveColor
                detailColor = .destructive
            }
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, labelStyle: .coloredText(labelColor), additionalDetailLabel: detail, additionalDetailLabelColor: detailColor, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .copy(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.copy()
            })
        }
    }
}

private struct NovagramAdsCheckState: Equatable {
    var production = true
    var running = false
    var report: NovagramAdsCheckReport?
    var notReady = false
}

private func novagramAdsCheckEntries(state: NovagramAdsCheckState, langCode: String) -> [NovagramAdsCheckEntry] {
    var entries: [NovagramAdsCheckEntry] = []
    entries.append(.environmentHeader(NovagramAdsCheckStrings.environmentHeader(langCode: langCode)))
    entries.append(.environment(true, "Production", state.production))
    entries.append(.environment(false, "Development", !state.production))

    let runTitle = state.running ? NovagramAdsCheckStrings.running(langCode: langCode) : NovagramAdsCheckStrings.run(langCode: langCode)
    entries.append(.run(runTitle, state.running))
    entries.append(.runFooter(NovagramAdsCheckStrings.runFooter(langCode: langCode)))

    if state.notReady {
        entries.append(.notReady(NovagramAdsCheckStrings.notReady(langCode: langCode)))
        return entries
    }
    guard let report = state.report else {
        return entries
    }
    entries.append(.resultHeader(NovagramAdsCheckStrings.reportHeader(report, langCode: langCode)))
    for (index, result) in report.slots.enumerated() {
        let title = NovagramAdsCheckStrings.slotName(result.slot, langCode: langCode)
        if let failure = result.failure, result.failures == result.requests {
            entries.append(.slot(Int32(index), title, NovagramAdsCheckStrings.failure(failure, langCode: langCode), .failed, nil))
        } else {
            let tone: NovagramAdsCheckTone = result.hits > 0 ? .hit : .empty
            entries.append(.slot(Int32(index), title, novagramAdsCheckCount(result), tone, novagramAdsCheckDetail(result, langCode: langCode)))
        }
    }
    let footer = NovagramAdsCheckStrings.responseLine(ms: report.elapsedMs, langCode: langCode) + " · " + NovagramAdsCheckStrings.serverState(responded: report.serverResponded, langCode: langCode)
    entries.append(.resultFooter(footer))
    entries.append(.copy(NovagramAdsCheckStrings.copy(langCode: langCode)))
    return entries
}

/// One check through the provider, as a signal: disposing it (leaving the screen) cancels the requests.
private func novagramAdsCheckSignal(production: Bool, lang: String) -> Signal<NovagramAdsCheckReport?, NoError> {
    return Signal { subscriber in
        guard let provider = NovagramAdsCheck.provider else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let task = Task {
            let report = await provider(production, lang)
            if Task.isCancelled {
                return
            }
            subscriber.putNext(report)
            subscriber.putCompletion()
        }
        return ActionDisposable {
            task.cancel()
        }
    }
}

public func novagramAdsCheckController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(NovagramAdsCheckState(), ignoreRepeated: true)
    let stateValue = Atomic(value: NovagramAdsCheckState())
    let updateState: ((NovagramAdsCheckState) -> NovagramAdsCheckState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let runDisposable = MetaDisposable()
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = NovagramAdsCheckArguments(selectEnvironment: { production in
        updateState { state in
            var state = state
            guard !state.running, state.production != production else {
                return state
            }
            state.production = production
            state.report = nil
            state.notReady = false
            return state
        }
    }, run: {
        var production = true
        var started = false
        updateState { state in
            var state = state
            if !state.running {
                state.running = true
                state.notReady = false
                started = true
            }
            production = state.production
            return state
        }
        guard started else {
            return
        }
        let lang = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
        runDisposable.set((novagramAdsCheckSignal(production: production, lang: lang)
        |> deliverOnMainQueue).startStrict(next: { report in
            if report != nil {
                HapticFeedback().success()
            }
            updateState { state in
                var state = state
                state.running = false
                state.report = report
                state.notReady = report == nil
                return state
            }
        }))
    }, copy: {
        guard let report = stateValue.with({ $0.report }) else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        UIPasteboard.general.string = novagramAdsCheckText(report, langCode: langCode)
        presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(NovagramAdsCheckStrings.copied(langCode: langCode), false)))
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(NovagramAdsCheckStrings.title(langCode: langCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramAdsCheckEntries(state: state, langCode: langCode), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        runDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
