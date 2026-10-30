import Foundation
import Combine
import SwiftSignalKit
import NovagramCallRecordingCore

/// The app's one call recording center (HOOKS.md, "Call recording"). The SDK (`submodules/Novagram/CallRecordingKit`)
/// has no singleton, and the call glue (TelegramCallsUI), the recordings list and the termination hook
/// (NovagramMessenger) must reach the same center, so it lives here.
///
/// `CallRecordingCenter` is main-actor API. Telegram's call code is not actor-annotated but calls these on the main
/// thread, so each method enters the main actor with `MainActor.assumeIsolated`, which traps off the main thread
/// (the old core asserted the same).
public enum NovagramCallRecordings {
    /// `Library/Application Support/CallRecordings`, the folder the app has always used.
    public static let storage = CallRecordingStorage.default

    @MainActor private static let center = CallRecordingCenter(storage: NovagramCallRecordings.storage)

    /// Starts recording a call. `onDetach` runs once on the main thread when the recording stops (Stop, `stopAll` or
    /// the writer failing on its own): remove the audio tap and the video subscriptions there.
    public static func start(callId: UUID, peerName: String, onDetach: @escaping () -> Void) throws -> CallRecordingSession {
        return try MainActor.assumeIsolated {
            return try self.center.start(callId: callId, peerName: peerName, onDetach: onDetach)
        }
    }

    /// Finishes the file and moves it into the folder. `completion` runs on the main thread.
    public static func stop(callId: UUID, completion: @escaping (Result<URL, CallRecordingError>) -> Void) {
        MainActor.assumeIsolated {
            self.center.stop(callId: callId, completion: { result in
                completion(result)
            })
        }
    }

    public static func isRecording(callId: UUID) -> Bool {
        return MainActor.assumeIsolated {
            return self.center.isRecording(callId: callId)
        }
    }

    /// Where the call screen's small picture is and whether the videos are swapped; ignored when not recording.
    public static func setLayout(callId: UUID, pipCorner: CallRecordingPipCorner, isSwapped: Bool) {
        MainActor.assumeIsolated {
            self.center.setLayout(callId: callId, pipCorner: pipCorner, isSwapped: isSwapped)
        }
    }

    /// The call's recording state now and on every change, on the main queue.
    public static func state(callId: UUID) -> Signal<CallRecordingState, NoError> {
        return Signal<CallRecordingState, NoError> { subscriber in
            var observation: AnyCancellable?
            MainActor.assumeIsolated {
                observation = self.center.$recordingStartDates.sink(receiveValue: { dates in
                    if let startDate = dates[callId] {
                        subscriber.putNext(.recording(startDate: startDate))
                    } else {
                        subscriber.putNext(.idle)
                    }
                })
            }
            return ActionDisposable {
                observation?.cancel()
            }
        }
        |> runOn(Queue.mainQueue())
        |> distinctUntilChanged
    }

    /// App termination: finishes every running recording. `completion` runs once, on a background queue, when all
    /// files are finished or after `timeout` seconds, so `applicationWillTerminate` may wait for it.
    public static func stopAll(timeout: Double, completion: @escaping @Sendable () -> Void) {
        MainActor.assumeIsolated {
            self.center.stopAll(timeout: timeout, completion: completion)
        }
    }

    /// A call changed a switch or saved a recording: an open Novagram Settings screen recounts. The call UI sits on
    /// its own window level, so closing it does not make the Settings screen appear again.
    public static func notifyChanged() {
        NotificationCenter.default.post(name: CallRecordingSettings.changedNotification, object: nil)
    }
}
