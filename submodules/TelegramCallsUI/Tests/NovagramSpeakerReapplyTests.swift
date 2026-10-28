import Foundation
import XCTest
import SwiftSignalKit
import TelegramAudio
import TelegramCore
@testable import TelegramCallsUI

// Novagram: regression tests for video calls that stayed on the earpiece. The fakes mirror the
// ones in SharedCallAudioContextTests.swift, which are private to that upstream file.

private final class FakeAudioSession: ManagedAudioSession {
    var isHeadsetPluggedIn: Bool = false
    var pushedParams: [ManagedAudioSessionClientParams] = []

    func getIsHeadsetPluggedIn() -> Bool {
        return self.isHeadsetPluggedIn
    }

    func getIsRecordingActive() -> Bool {
        return false
    }

    func headsetConnected() -> Signal<Bool, NoError> {
        return .single(self.isHeadsetPluggedIn)
    }

    func isActive() -> Signal<Bool, NoError> {
        return .single(false)
    }

    func isPlaybackActive() -> Signal<Bool, NoError> {
        return .single(false)
    }

    func isOtherAudioPlaying() -> Bool {
        return false
    }

    func didActivateWithZeroVolume() -> Signal<Void, NoError> {
        return .never()
    }

    func push(params: ManagedAudioSessionClientParams) -> Disposable {
        self.pushedParams.append(params)
        return EmptyDisposable
    }

    func dropAll() {
    }

    func applyVoiceChatOutputModeInCurrentAudioSession(outputMode: AudioSessionOutputMode) {
    }

    func callKitActivatedAudioSession() {
    }

    func callKitDeactivatedAudioSession() {
    }
}

private final class FakeControl {
    private(set) var appliedOutputModes: [AudioSessionOutputMode] = []
    private var pendingActivations: [(AudioSessionActivationState) -> Void] = []

    private(set) lazy var control: ManagedAudioSessionControl = ManagedAudioSessionControl(
        setup: { _ in },
        activate: { [unowned self] completion in
            self.pendingActivations.append(completion)
        },
        setOutputMode: { [unowned self] mode in
            self.appliedOutputModes.append(mode)
        },
        setupAndActivate: { [unowned self] _, completion in
            self.pendingActivations.append(completion)
        },
        setType: { _, completion in
            completion()
        }
    )

    func completeActivations(isHeadsetConnected: Bool) {
        let pending = self.pendingActivations
        self.pendingActivations = []
        for completion in pending {
            completion(AudioSessionActivationState(isHeadsetConnected: isHeadsetConnected))
        }
    }
}

/// A video call records the speaker as its output before the route has followed. The route
/// report that arrives while the default is pending is skipped, and a speaker override that does
/// not take effect produces no new report, so the session keeps reporting the earpiece while the
/// context believes in the speaker. The call screen asks for the speaker every second from then
/// on; those requests have to reach the session again.
final class NovagramSpeakerReapplyTests: XCTestCase {
    private static let loggerInstalled: Bool = {
        let path = NSTemporaryDirectory() + "NovagramSpeakerReapplyTests-logs"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        Logger.setSharedLogger(logger)
        return true
    }()

    private var session: FakeAudioSession!
    private var control: FakeControl!

    override func setUp() {
        super.setUp()
        XCTAssertTrue(NovagramSpeakerReapplyTests.loggerInstalled)
        self.session = FakeAudioSession()
        self.control = FakeControl()
    }

    override func tearDown() {
        self.control = nil
        self.session = nil
        super.tearDown()
    }

    private func spinMainQueue(for interval: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
    }

    /// Starts a video call on a phone without a headset: the session reports the earpiece while
    /// the speaker default is pending, then activation completes and the default is applied.
    private func startVideoCallWithoutHeadset() -> SharedCallAudioContext {
        self.session.isHeadsetPluggedIn = false
        let context = SharedCallAudioContext.get(audioSession: self.session, callKitIntegration: nil, defaultToSpeaker: true, reuseCurrent: false, enableMicrophone: true, legacyBehavior: false)
        XCTAssertEqual(self.session.pushedParams.count, 1)
        let params = self.session.pushedParams[0]

        params.manualActivate(self.control.control)
        self.spinMainQueue()

        params.availableOutputsChanged([.builtin, .speaker], .builtin)
        self.control.completeActivations(isHeadsetConnected: false)
        self.spinMainQueue()

        // Long enough for the half-second re-apply timer to fire.
        self.spinMainQueue(for: 0.8)
        return context
    }

    func testSpeakerRequestIsReappliedWhileTheSessionStillReportsTheEarpiece() {
        let context = self.startVideoCallWithoutHeadset()
        XCTAssertEqual(context.currentAudioOutputValue, .speaker)

        // No route change followed the override: the last report still names the earpiece.
        let appliedBefore = self.control.appliedOutputModes.count
        context.setCurrentAudioOutput(.speaker)
        self.spinMainQueue()

        XCTAssertEqual(self.control.appliedOutputModes.count, appliedBefore + 1, "the speaker request was dropped; applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(self.control.appliedOutputModes.last, .custom(.speaker))
    }

    func testSpeakerRequestIsNotReappliedOnceTheSessionReportsTheSpeaker() {
        let context = self.startVideoCallWithoutHeadset()

        self.session.pushedParams[0].availableOutputsChanged([.builtin, .speaker], .speaker)
        self.spinMainQueue()
        XCTAssertEqual(context.currentAudioOutputValue, .speaker)

        let appliedBefore = self.control.appliedOutputModes.count
        context.setCurrentAudioOutput(.speaker)
        self.spinMainQueue()

        XCTAssertEqual(self.control.appliedOutputModes.count, appliedBefore, "applied: \(self.control.appliedOutputModes)")
    }

    func testEarpieceChosenByTheUserIsAppliedDuringAVideoCall() {
        let context = self.startVideoCallWithoutHeadset()

        self.session.pushedParams[0].availableOutputsChanged([.builtin, .speaker], .speaker)
        self.spinMainQueue()

        context.setCurrentAudioOutput(.builtin)
        self.spinMainQueue()

        XCTAssertEqual(self.control.appliedOutputModes.last, .custom(.builtin), "applied: \(self.control.appliedOutputModes)")
        XCTAssertEqual(context.currentAudioOutputValue, .builtin)
    }
}
