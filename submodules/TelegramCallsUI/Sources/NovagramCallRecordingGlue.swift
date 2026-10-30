import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramVoip
import AccountContext
import CallScreen
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
/// - Video: both sides' video is followed for the whole recording, also in a voice call (the file is .mp4 if video was
///   ever on, .m4a otherwise). Our side is the camera, or our shared screen while we share it. The picture-in-picture
///   corner and the big/small swap follow the call screen; while we share our screen, the screen is big.
/// - Never secret: once a recording really started, "🔴 I'm recording this call (Novagram)" goes to the 1:1 chat with
///   the call's peer, in the app's language, at most once per call (`NovagramCallRecordingNoticeLedger`). If it cannot
///   be enqueued, the recording is stopped, its file deleted and "Couldn't notify the other person…" shown; the next
///   Record in that call then tries the notice again. A later failed delivery does not stop the recording (Mac parity).
final class NovagramCallRecordingGlue {
    private static let savedToastTimeout: Double = 8.0
    // How often the call screen's picture-in-picture corner and swap are read while recording. Dragging the small
    // window does not update the screen, so it is read rather than pushed.
    private static let layoutPollInterval: Double = 0.25
    // Which calls already sent the "I'm recording this call" message. Static, so a new call screen for the same call
    // does not send it again. Main thread only.
    private static var noticeLedger = NovagramCallRecordingNoticeLedger()

    private weak var call: PresentationCallImpl?
    private let callId: UUID
    private let peerId: EnginePeer.Id
    private let isOutgoing: Bool
    private let context: AccountContext
    private let presentationData: PresentationData
    private weak var control: NovagramCallRecordControl?
    private weak var callScreen: PrivateCallScreen?

    private var stateDisposable: Disposable?
    private var recordingStateDisposable: Disposable?
    private var layoutTimer: SwiftSignalKit.Timer?
    private var sentLayout: NovagramCallVideoLayout?

    private var callState: PresentationCallState?
    private var peerName = ""
    private var recordingStart: Double?
    // Set by the first start or stop in this call, so auto-record never starts a second time.
    private var didStartOnce = false
    private var isStopping = false
    // Set when the notice failed: the stop that follows deletes the file instead of offering it.
    private var discardRecording = false
    private var isAsking = false
    private var isCallOver = false

    init(call: PresentationCall, callScreen: PrivateCallScreen, presentationData: PresentationData) {
        let control = callScreen.novagramRecord
        self.callScreen = callScreen
        self.call = call as? PresentationCallImpl
        self.callId = call.internalId
        self.peerId = call.peerId
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
        self.layoutTimer?.invalidate()

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
                NovagramCallRecordingGlue.noticeLedger.forget(callId: self.callId)
                if self.recordingStart != nil || NovagramCallRecordingCenter.shared.isRecording(callId: self.callId) {
                    self.stop()
                }
            }
        default:
            self.autoStartIfNeeded(state)
        }
        self.updateLayout()
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

    private static func isScreencastActive(_ state: PresentationCallState) -> Bool {
        switch state.videoState {
        case let .active(isScreencast, _), let .paused(isScreencast, _):
            return isScreencast
        case .notAvailable, .inactive:
            return false
        }
    }

    // MARK: - Video layout

    /// What the call screen shows, for the recording: the corner of its small window and whether it swapped the big
    /// and small videos. While we share our screen, the screen (our side) is big. Sent only when it changes.
    private func updateLayout() {
        guard self.recordingStart != nil else {
            return
        }
        let screen = self.callScreen?.novagramVideoLayout ?? (isPipTop: false, isPipLeft: false, isSwapped: false)
        let pipCorner: NovagramCallPipCorner
        switch (screen.isPipTop, screen.isPipLeft) {
        case (true, true):
            pipCorner = .topLeft
        case (true, false):
            pipCorner = .topRight
        case (false, true):
            pipCorner = .bottomLeft
        case (false, false):
            pipCorner = .bottomRight
        }
        let isScreencast = self.callState.map(NovagramCallRecordingGlue.isScreencastActive) ?? false
        let layout = NovagramCallVideoLayout(pipCorner: pipCorner, isSwapped: isScreencast || screen.isSwapped)
        guard layout != self.sentLayout else {
            return
        }
        self.sentLayout = layout
        NovagramCallRecordingCenter.shared.setLayout(callId: self.callId, pipCorner: layout.pipCorner, isSwapped: layout.isSwapped)
    }

    private func updateLayoutTimer() {
        if self.recordingStart != nil {
            guard self.layoutTimer == nil else {
                return
            }
            self.sentLayout = nil
            self.updateLayout()
            let timer = SwiftSignalKit.Timer(timeout: NovagramCallRecordingGlue.layoutPollInterval, repeat: true, completion: { [weak self] in
                self?.updateLayout()
            }, queue: Queue.mainQueue())
            self.layoutTimer = timer
            timer.start()
        } else {
            self.layoutTimer?.invalidate()
            self.layoutTimer = nil
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
        self.updateLayoutTimer()
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
                    NovagramCallRecordingSettings.isUserAutoEnabled = false
                    NovagramCallRecordingSettings.notifyChanged()
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
        let source = NovagramCallRecordingSource(
            peerName: self.peerName.isEmpty ? "Call" : self.peerName,
            setAudioTap: { tap in
                audioDevice.setAudioTap(tap)
            },
            incomingVideo: NovagramCallRecordingGlue.liveVideo(call: impl, isIncoming: true),
            outgoingVideo: NovagramCallRecordingGlue.liveOutgoingVideo(call: impl),
            isMuted: impl.isMuted
        )
        self.didStartOnce = true
        if !NovagramCallRecordingCenter.shared.start(callId: self.callId, source: source) {
            NovagramCallRecordingGlue.showResult(.failure(.writerFailed("start")), context: self.context, presentationData: self.presentationData)
            return
        }
        self.sendNoticeIfNeeded()
    }

    // MARK: - Notice

    /// "🔴 I'm recording this call (Novagram)" to the chat with the call's peer, once per call, through TelegramCore's
    /// normal outgoing path (the same as a typed message). Only a failure to enqueue stops the recording.
    private func sendNoticeIfNeeded() {
        guard NovagramCallRecordingGlue.noticeLedger.beginSending(callId: self.callId) else {
            return
        }
        let text = NovagramL10n(self.presentationData.strings).callRecording_noticeMessage
        // Not tied to this object's lifetime: once asked for, the message is enqueued even if the screen goes.
        let _ = (self.context.engine.messages.enqueueOutgoingMessage(to: self.peerId, replyTo: nil, content: .text(text, []))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] messageIds in
            guard let self else {
                return
            }
            guard (messageIds.first ?? nil) != nil else {
                Logger.shared.log("NovagramCallRecording", "notice could not be enqueued")
                self.noticeFailed()
                return
            }
            NovagramCallRecordingGlue.noticeLedger.markEnqueued(callId: self.callId)
        })
    }

    /// The other person could not be told: the call must not be recorded. A recording that runs is stopped and its
    /// file deleted.
    private func noticeFailed() {
        NovagramCallRecordingGlue.noticeLedger.markFailed(callId: self.callId)
        if self.recordingStart != nil || NovagramCallRecordingCenter.shared.isRecording(callId: self.callId) {
            self.discardRecording = true
            self.stop()
        } else {
            NovagramCallRecordingGlue.showNoticeFailed(context: self.context, presentationData: self.presentationData)
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
            var discard = false
            if let self {
                discard = self.discardRecording
                self.discardRecording = false
                self.isStopping = false
                self.updateControl()
            }
            if discard {
                NovagramCallRecordingGlue.discard(result, context: context, presentationData: presentationData)
            } else {
                NovagramCallRecordingGlue.showResult(result, context: context, presentationData: presentationData)
            }
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

    private enum OutgoingVideoKind {
        case none
        case camera
        case screencast
    }

    /// Our side: the camera, or our shared screen while we share it (`requestScreencast` turns the camera off and
    /// sends the screencast capturer instead). Follows the switch both ways; while there is neither it sends nothing.
    private static func liveOutgoingVideo(call: PresentationCallImpl) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        return call.state
        |> map { [weak call] state -> OutgoingVideoKind in
            guard let call else {
                return .none
            }
            switch state.videoState {
            case let .active(isScreencast, _), let .paused(isScreencast, _):
                if isScreencast {
                    return call.novagramScreencastVideo != nil ? .screencast : .none
                }
                return call.video(isIncoming: false) != nil ? .camera : .none
            case .notAvailable, .inactive:
                return .none
            }
        }
        |> distinctUntilChanged
        |> mapToSignal { [weak call] kind -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> in
            guard let call else {
                return .complete()
            }
            let video: Signal<OngoingGroupCallContext.VideoFrameData, NoError>?
            switch kind {
            case .none:
                video = nil
            case .camera:
                video = call.video(isIncoming: false)
            case .screencast:
                video = call.novagramScreencastVideo
            }
            return video ?? .complete()
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
        // An open Settings screen recounts the recordings.
        NovagramCallRecordingSettings.notifyChanged()
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
        case let .failure(error):
            Logger.shared.log("NovagramCallRecording", "recording failed: \(error)")
            // No audio ever reached the tap (the call's audio unit did not start), so say that instead of a bare "failed".
            let text = error == .nothingRecorded ? l10n.callRecording_nothingRecorded : l10n.callRecording_failed
            controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in
                return false
            })
        }
        NovagramCallRecordingGlue.presentOverCall(controller, context: context)
    }

    /// After a failed notice: the file is deleted (the other person was not told), and the failure is shown.
    private static func discard(_ result: Result<URL, NovagramCallRecordingError>, context: AccountContext, presentationData: PresentationData) {
        if case let .success(url) = result {
            do {
                try NovagramCallRecordingStorage.delete(url)
            } catch {
                Logger.shared.log("NovagramCallRecording", "could not delete the unnotified recording: \(error)")
            }
        }
        NovagramCallRecordingSettings.notifyChanged()
        NovagramCallRecordingGlue.showNoticeFailed(context: context, presentationData: presentationData)
    }

    private static func showNoticeFailed(context: AccountContext, presentationData: PresentationData) {
        let text = NovagramL10n(presentationData.strings).callRecording_noticeFailed
        let controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in
            return false
        })
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
