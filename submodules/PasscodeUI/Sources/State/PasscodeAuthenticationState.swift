import Foundation
import PasscodeCore

/// An injected authentication result must satisfy the request before UI delivery.
func validatedPasscodeBiometricSession(_ session: PasscodeSession, scope: PasscodeSession.Scope,
                                      lifetime: PasscodeSession.Lifetime,
                                      credentials: PasscodeCredentialStore = .shared) throws -> PasscodeSession {
    do {
        guard session.lifetime == lifetime else { throw PasscodeError.authenticationRequired }
        try credentials.validate(session, scope: scope)
        return session
    } catch {
        session.invalidate()
        throw error
    }
}

/// Tracks whether a passcode screen may start or finish authentication. Share
/// extensions use a constant false foreground binding, so only the main app's
/// binding represents a real background transition. Dismissal ends either flow.
struct PasscodeEntryLifecycle {
    private let isMainApp: Bool
    private var isInBackground = false
    private var isDismissed = false
    private(set) var generation: UInt64 = 0

    init(isMainApp: Bool) {
        self.isMainApp = isMainApp
    }

    var canAuthenticate: Bool {
        return !self.isInBackground && !self.isDismissed
    }

    /// Returns true when ongoing work must be cancelled on entering background.
    mutating func updateApplicationInForeground(_ value: Bool) -> Bool {
        let isInBackground = self.isMainApp && !value
        guard self.isInBackground != isInBackground else { return false }
        self.isInBackground = isInBackground
        if isInBackground {
            self.generation &+= 1
            return true
        }
        return false
    }

    func acceptsResult(generation: UInt64) -> Bool {
        return self.canAuthenticate && self.generation == generation
    }

    mutating func dismiss() {
        guard !self.isDismissed else { return }
        self.isDismissed = true
        self.generation &+= 1
    }
}

/// Main-thread completion gate. A nil session represents the legacy PIN result.
/// Authentication stops before removal starts; the result belongs to this gate
/// until the presentation owner confirms that the controller has been removed.
final class PasscodeAuthenticationDismissal {
    typealias Outcome = Result<PasscodeSession?, PasscodeError>

    enum Phase {
        case active
        case closing
        case finished
    }

    private(set) var phase: Phase = .active
    private var pendingResult: Outcome?
    private var completed: ((Outcome) -> Void)?
    private var removalCompletions: [() -> Void] = []

    func finish(_ result: Outcome, stopAuthentication: () -> Void,
                removeController: (@escaping () -> Void) -> Void,
                completed: @escaping (Outcome) -> Void) {
        guard self.phase == .active else {
            if self.phase == .closing, case .failure(.cancelled) = result {
                if case let .success(session) = self.pendingResult { session?.invalidate() }
                self.pendingResult = result
            } else if case let .success(session) = result {
                // A duplicate delivery must not invalidate the very same grant
                // that is still awaiting removal, but other late grants expire.
                if case let .success(pending?) = self.pendingResult, pending === session { return }
                session?.invalidate()
            }
            return
        }
        self.phase = .closing
        self.pendingResult = result
        self.completed = completed
        stopAuthentication()
        removeController { [self] in self.didRemoveController() }
    }

    func afterRemoval(_ completion: @escaping () -> Void) {
        if self.phase == .finished {
            completion()
        } else {
            self.removalCompletions.append(completion)
        }
    }

    func didRemoveController() {
        guard self.phase == .closing, let result = self.pendingResult else { return }
        self.phase = .finished
        self.pendingResult = nil
        let completed = self.completed
        self.completed = nil
        let removalCompletions = self.removalCompletions
        self.removalCompletions.removeAll()
        completed?(result)
        for completion in removalCompletions { completion() }
    }
}

/// Presentation callbacks and the controller reference belong to MainActor.
/// Scheduling, starting and task cancellation may come from any thread; the
/// completion and cancellation flag are protected by the lock.
final class PendingPasscodeAuthentication<Controller: AnyObject>: @unchecked Sendable {
    typealias Outcome = Result<PasscodeSession, PasscodeError>
    typealias UIWork = @MainActor @Sendable () -> Void

    private let lock = NSLock()
    private var completion: ((Outcome) -> Void)?
    private var cancelled = false
    @MainActor private weak var controller: Controller?
    private let schedule: @Sendable (@escaping UIWork) -> Void
    private let create: @MainActor (@escaping (Outcome) -> Void) -> Controller?
    private let present: @MainActor (Controller) -> Void
    private let dismiss: @MainActor (Controller) -> Void

    init(schedule: @escaping @Sendable (@escaping UIWork) -> Void = { work in DispatchQueue.main.async(execute: work) },
         create: @escaping @MainActor (@escaping (Outcome) -> Void) -> Controller?,
         present: @escaping @MainActor (Controller) -> Void, dismiss: @escaping @MainActor (Controller) -> Void) {
        self.schedule = schedule
        self.create = create
        self.present = present
        self.dismiss = dismiss
    }

    func start(_ completion: @escaping (Outcome) -> Void) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            completion(.failure(.cancelled))
            return
        }
        self.completion = completion
        self.lock.unlock()
        self.schedule { [self] in
            guard self.canPresent() else {
                self.finish(.failure(.cancelled))
                return
            }
            let controller = self.create { [self] result in self.finish(result) }
            self.controller = controller
            guard let controller else { return }
            // Cancellation can arrive while the factory reads the credential.
            guard self.canPresent() else {
                self.dismiss(controller)
                return
            }
            self.present(controller)
        }
    }

    private func canPresent() -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return !self.cancelled && self.completion != nil
    }

    private func finish(_ result: Outcome) {
        self.lock.lock()
        let completion = self.completion
        self.completion = nil
        let cancelled = self.cancelled
        self.lock.unlock()
        guard let completion else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        if cancelled {
            if case let .success(session) = result { session.invalidate() }
            completion(.failure(.cancelled))
        } else {
            completion(result)
        }
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        self.lock.unlock()
        self.schedule { [self] in
            if let controller = self.controller {
                // The controller delivers cancellation after actual removal.
                self.dismiss(controller)
            } else {
                self.finish(.failure(.cancelled))
            }
        }
    }
}
