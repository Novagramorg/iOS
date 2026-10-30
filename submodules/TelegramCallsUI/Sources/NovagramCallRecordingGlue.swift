import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramVoip
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import UndoUI
import NovagramCalls
import NovagramCallRecording
import NovagramLocalization

/// Novagram (HOOKS.md, "Call recording"): connects one 1:1 call to the recording core and to the call screen's
/// Record control. Ours, although it sits in TelegramCallsUI: it needs `PresentationCallImpl`'s internal audio device
/// and video signals. `CallControllerNodeV2` creates one per call screen and keeps it for its lifetime.
///
/// - The control shows while the "Call recording" switch is on (or a recording runs), from the start of an outgoing
///   call and from the answer of an incoming one, until the call ends. Without the shared audio device (killswitch
///   `ios_killswitch_disable_call_device`) there is no audio tap, so it never shows.
/// - The first recording ever asks for consent; Cancel does not record (and turns auto-record off when it was an auto
///   start).
/// - Auto-record starts once per call: when an outgoing call starts ringing, or when an incoming call is answered.
///   A manual Stop is not undone.
/// - The recording stops when the call ends or the screen goes away; the file is always finished. The result shows as
///   a toast with a Share action.
final class NovagramCallRecordingGlue {
    private static let savedToastTimeout: Double = 8.0

    private weak var call: PresentationCallImpl?
    private let callId: UUID
    private let isOutgoing: Bool
    private let context: AccountContext
    private let presentationData: PresentationData
    private weak var control: NovagramCallRecordControl?

    private var stateDisposable: Disposable?
    private var recordingStateDisposable: Disposable?

    private var callState: PresentationCallState?
    private var peerName = ""
    private var recordingStart: Double?
    private var recordingIsVideo = false
    // Set by the first start or stop in this call, so auto-record never starts a second time.
    private var didStartOnce = false
    private var didShowAudioOnly = false
    private var isStopping = false
    private var isAsking = false
    private var isCallOver = false

    init(call: PresentationCall, control: NovagramCallRecordControl, presentationData: PresentationData) {
        self.call = call as? PresentationCallImpl
        self.callId = call.internalId
        self.isOutgoing = call.isOutgoing
        self.context = call.context
        self.presentationData = presentationData
        self.control = control

        guard self.call?.sharedAudioContext?.audioDevice != nil else {
            control.setState(isAvailable: false, recordingStart: nil)
            return
        }

        control.toggle = { [weak self] in
            self?.toggle(isAuto: false)
        }

        let strings = presentationData.strings
        let nameDisplayOrder = presentationData.nameDisplayOrder
        let peerName = call.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId))
        |> map { peer -> String in
            return peer?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
        }
        // The name is needed before an auto start, so the call state waits for it (a local read).
        self.stateDisposable = (combineLatest(call.state, peerName)
        |> deliverOnMainQueue).startStrict(next: { [weak self] state, peerName in
            guard let self else {
                return
            }
            self.peerName = peerName
            self.callStateUpdated(state)
        })
        self.recordingStateDisposable = (NovagramCallRecordingCenter.shared.state(callId: self.callId)
        |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            self?.recordingStateUpdated(state)
        })
    }

    deinit {
        self.stateDisposable?.dispose()
        self.recordingStateDisposable?.dispose()

        // The screen went away while recording: finish the file anyway.
        let callId = self.callId
        let context = self.context
        let presentationData = self.presentationData
        let stop = {
            guard NovagramCallRecordingCenter.shared.isRecording(callId: callId) else {
                return
            }
            NovagramCallRecordingCenter.shared.stop(callId: callId, completion: { result in
                NovagramCallRecordingGlue.showResult(result, context: context, presentationData: presentationData)
            })
        }
        if Thread.isMainThread {
            stop()
        } else {
            Queue.mainQueue().async(stop)
        }
    }

    // MARK: - Call state

    private func callStateUpdated(_ state: PresentationCallState) {
        self.callState = state
        switch state.state {
        case .terminating, .terminated:
            if !self.isCallOver {
                self.isCallOver = true
                if self.recordingStart != nil || NovagramCallRecordingCenter.shared.isRecording(callId: self.callId) {
                    self.stop()
                }
            }
        default:
            self.autoStartIfNeeded(state)
            self.noteVideoTurnedOnIfNeeded(state)
        }
        self.updateControl()
    }

    // Outgoing: from the start of the call. Incoming: only once answered.
    private func isStateAllowed(_ state: PresentationCallState) -> Bool {
        switch state.state {
        case .waiting, .requesting:
            return self.isOutgoing
        case .ringing:
            return false
        case .connecting, .active, .reconnecting:
            return true
        case .terminating, .terminated:
            return false
        }
    }

    private func autoStartIfNeeded(_ state: PresentationCallState) {
        guard NovagramCallRecordingSettings.isEnabled, NovagramCallRecordingSettings.isAutoEnabled, !self.didStartOnce, self.recordingStart == nil, !self.isCallOver else {
            return
        }
        let shouldStart: Bool
        switch state.state {
        case let .requesting(isRinging):
            // Outgoing: as soon as it rings, so the ringback is in the recording.
            shouldStart = isRinging && self.isOutgoing
        case .connecting, .active, .reconnecting:
            // Incoming once answered; an outgoing call that never reported ringing.
            shouldStart = true
        default:
            shouldStart = false
        }
        if shouldStart {
            self.didStartOnce = true
            self.toggle(isAuto: true)
        }
    }

    private func noteVideoTurnedOnIfNeeded(_ state: PresentationCallState) {
        guard self.recordingStart != nil, !self.recordingIsVideo, !self.didShowAudioOnly, NovagramCallRecordingGlue.isVideoActive(state) else {
            return
        }
        self.didShowAudioOnly = true
        let text = NovagramL10n(self.presentationData.strings).callRecording_audioOnly
        NovagramCallRecordingGlue.presentOverCall(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in
            return false
        }), context: self.context)
    }

    private static func isVideoActive(_ state: PresentationCallState) -> Bool {
        switch state.videoState {
        case .active, .paused:
            return true
        case .notAvailable, .inactive:
            break
        }
        switch state.remoteVideoState {
        case .active, .paused:
            return true
        case .inactive:
            return false
        }
    }

    // MARK: - Recording state

    private func recordingStateUpdated(_ state: NovagramCallRecordingState) {
        let wasRecording = self.recordingStart != nil
        switch state {
        case .idle:
            self.recordingStart = nil
        case let .recording(startTimestamp):
            self.recordingStart = startTimestamp
        }
        if wasRecording && self.recordingStart == nil && !self.isStopping {
            // The writer stopped on its own (a failure): stop() hands out its error and the failure toast.
            self.stop()
        }
        self.updateControl()
    }

    private func updateControl() {
        let isAllowed = self.callState.map(self.isStateAllowed) ?? false
        let isAvailable = !self.isCallOver && isAllowed && (NovagramCallRecordingSettings.isEnabled || self.recordingStart != nil)
        self.control?.setState(isAvailable: isAvailable, recordingStart: self.recordingStart)
    }

    // MARK: - Start and stop

    private func toggle(isAuto: Bool) {
        if self.recordingStart != nil || NovagramCallRecordingCenter.shared.isRecording(callId: self.callId) {
            self.stop()
            return
        }
        guard !self.isAsking, !self.isStopping, !self.isCallOver else {
            return
        }
        if NovagramCallRecordingSettings.wasWarned {
            self.start()
            return
        }

        self.isAsking = true
        let l10n = NovagramL10n(self.presentationData.strings)
        let alert = textAlertController(context: self.context, title: l10n.callRecording_warningTitle, text: l10n.callRecording_warningText, actions: [
            TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: { [weak self] in
                self?.isAsking = false
                if isAuto {
                    NovagramCallRecordingSettings.isAutoEnabled = false
                }
            }),
            TextAlertAction(type: .defaultAction, title: l10n.callRecording_continue, action: { [weak self] in
                guard let self else {
                    return
                }
                self.isAsking = false
                NovagramCallRecordingSettings.wasWarned = true
                self.start()
            })
        ], dismissOnOutsideTap: false)
        NovagramCallRecordingGlue.presentOverCall(alert, context: self.context)
    }

    private func start() {
        guard !self.isCallOver, let impl = self.call, let audioDevice = impl.sharedAudioContext?.audioDevice else {
            return
        }
        let isVideo = impl.isVideo || (self.callState.map(NovagramCallRecordingGlue.isVideoActive) ?? false)
        let source = NovagramCallRecordingSource(
            peerName: self.peerName.isEmpty ? "Call" : self.peerName,
            setAudioTap: { tap in
                audioDevice.setAudioTap(tap)
            },
            incomingVideo: NovagramCallRecordingGlue.liveVideo(call: impl, isIncoming: true),
            outgoingVideo: NovagramCallRecordingGlue.liveVideo(call: impl, isIncoming: false),
            isMuted: impl.isMuted,
            isVideo: isVideo
        )
        self.didStartOnce = true
        if NovagramCallRecordingCenter.shared.start(callId: self.callId, source: source) {
            self.recordingIsVideo = isVideo
            self.didShowAudioOnly = false
        } else {
            NovagramCallRecordingGlue.showResult(.failure(.writerFailed("start")), context: self.context, presentationData: self.presentationData)
        }
    }

    private func stop() {
        guard !self.isStopping else {
            return
        }
        self.isStopping = true
        self.didStartOnce = true
        let context = self.context
        let presentationData = self.presentationData
        NovagramCallRecordingCenter.shared.stop(callId: self.callId, completion: { [weak self] result in
            if let self {
                self.isStopping = false
                self.updateControl()
            }
            NovagramCallRecordingGlue.showResult(result, context: context, presentationData: presentationData)
        })
    }

    /// The call's current video of one side. Follows the side's video turning off and on again (a new camera
    /// capturer, the remote video arriving after the call connected); while there is none it sends nothing.
    private static func liveVideo(call: PresentationCallImpl, isIncoming: Bool) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        return call.state
        |> map { [weak call] state -> Bool in
            guard let call else {
                return false
            }
            let isActive: Bool
            if isIncoming {
                switch state.remoteVideoState {
                case .active, .paused:
                    isActive = true
                case .inactive:
                    isActive = false
                }
            } else {
                switch state.videoState {
                case .active, .paused:
                    isActive = true
                case .notAvailable, .inactive:
                    isActive = false
                }
            }
            return isActive && call.video(isIncoming: isIncoming) != nil
        }
        |> distinctUntilChanged
        |> mapToSignal { [weak call] isAvailable -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> in
            guard isAvailable, let call, let video = call.video(isIncoming: isIncoming) else {
                return .complete()
            }
            return video
        }
    }

    // MARK: - Result

    /// The call screen sits on the window's `.calls` level, and the call controller's own `present` goes to `.root`,
    /// under it. Alerts and toasts go on `.calls` so they show over the call screen, and stay after it closes.
    private static func presentOverCall(_ controller: ViewController, context: AccountContext) {
        context.sharedContext.mainWindow?.present(controller, on: .calls, blockInteraction: false, completion: {})
    }

    /// "Call recording saved" with Share, or "Call recording failed".
    private static func showResult(_ result: Result<URL, NovagramCallRecordingError>, context: AccountContext, presentationData: PresentationData) {
        let l10n = NovagramL10n(presentationData.strings)
        let controller: ViewController
        switch result {
        case let .success(url):
            controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: l10n.callRecording_saved, timeout: NovagramCallRecordingGlue.savedToastTimeout, customUndoText: l10n.callRecording_share), elevatedLayout: false, action: { action in
                if case .undo = action {
                    NovagramCallRecordingGlue.share(url: url, context: context)
                }
                return false
            })
        case .failure(.cancelled):
            // stop() for a call that was not being recorded: nothing to report.
            return
        case .failure:
            controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: l10n.callRecording_failed, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in
                return false
            })
        }
        NovagramCallRecordingGlue.presentOverCall(controller, context: context)
    }

    /// The system share sheet (Save to Files, Save Video, AirDrop, …), on the main window: the call screen may be gone.
    static func share(url: URL, context: AccountContext) {
        guard let window = context.sharedContext.mainWindow else {
            return
        }
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            let sourceView = window.hostView.containerView
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.maxY - 1.0, width: 1.0, height: 1.0)
            popover.permittedArrowDirections = []
        }
        window.presentNative(activityController)
    }
}
