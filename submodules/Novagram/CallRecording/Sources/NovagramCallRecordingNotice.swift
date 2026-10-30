import Foundation

/// The "I'm recording this call" chat message (HOOKS.md, "Call recording"): which calls already sent it.
///
/// A recording is never secret: when one starts, the glue sends the notice to the call's chat, at most once per call.
/// A Stop and a new Record in the same call send nothing more, while the notice is being enqueued or was enqueued.
/// Only a notice that could not be enqueued (the recording was then stopped and thrown away) lets the next Record send
/// it again. A later failed delivery does not count as failed here.
/// Main-thread only; pure, so the rule is unit-tested.
public struct NovagramCallRecordingNoticeLedger {
    public enum Status: Equatable {
        case sending
        case enqueued
        case failed
    }

    private var statuses: [UUID: Status] = [:]

    public init() {
    }

    public func status(callId: UUID) -> Status? {
        return self.statuses[callId]
    }

    /// True when the notice must be sent now for this recording start, and marks it as on its way.
    public mutating func beginSending(callId: UUID) -> Bool {
        switch self.statuses[callId] {
        case .sending, .enqueued:
            return false
        case .failed, nil:
            self.statuses[callId] = .sending
            return true
        }
    }

    public mutating func markEnqueued(callId: UUID) {
        self.statuses[callId] = .enqueued
    }

    public mutating func markFailed(callId: UUID) {
        self.statuses[callId] = .failed
    }

    /// The call is over: nothing can be recorded in it any more.
    public mutating func forget(callId: UUID) {
        self.statuses.removeValue(forKey: callId)
    }
}
