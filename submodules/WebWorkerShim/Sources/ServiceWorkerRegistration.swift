import Foundation

enum ServiceWorkerState: String, Codable, Sendable {
    case installing
    case installed
    case activating
    case activated
    case redundant
}

/// Thread-safe service worker registration using actor isolation
actor ServiceWorkerRegistration {
    let id: UUID
    let scriptURL: URL
    let scope: String
    let origin: String
    var state: ServiceWorkerState = .installing
    var scriptContent: String?

    init(scriptURL: URL, scope: String, origin: String) {
        self.id = UUID()
        self.scriptURL = scriptURL
        self.scope = scope
        self.origin = origin
    }

    func matchesScope(path: String) -> Bool {
        // Direct match
        if path.hasPrefix(scope) {
            return true
        }
        // If scope ends with / and path doesn't, try adding / to path
        // e.g., scope="/app/" should match path="/app"
        if scope.hasSuffix("/") && !path.hasSuffix("/") {
            return (path + "/").hasPrefix(scope)
        }
        return false
    }

    func setState(_ newState: ServiceWorkerState) {
        state = newState
    }

    func setScriptContent(_ content: String?) {
        scriptContent = content
    }

    // Snapshot for persistence (captures current state synchronously within actor)
    func snapshot() -> RegistrationSnapshot {
        RegistrationSnapshot(
            id: id,
            scriptURL: scriptURL,
            scope: scope,
            origin: origin,
            state: state
        )
    }

    // Restore from snapshot
    init(from snapshot: RegistrationSnapshot) {
        self.id = snapshot.id
        self.scriptURL = snapshot.scriptURL
        self.scope = snapshot.scope
        self.origin = snapshot.origin
        self.state = snapshot.state
        self.scriptContent = nil
    }
}

/// Codable snapshot for persistence
struct RegistrationSnapshot: Codable, Sendable {
    let id: UUID
    let scriptURL: URL
    let scope: String
    let origin: String
    let state: ServiceWorkerState
}

/// Thread-safe set for tracking managed origins (accessed from URLProtocol.canInit)
private class ManagedOriginsStorage {
    private var origins: Set<String> = []
    private let queue = DispatchQueue(label: "com.workershim.managedOrigins", attributes: .concurrent)

    func contains(_ origin: String) -> Bool {
        queue.sync { origins.contains(origin) }
    }

    func insert(_ origin: String) {
        queue.async(flags: .barrier) { self.origins.insert(origin) }
    }

    func remove(_ origin: String) {
        queue.async(flags: .barrier) { self.origins.remove(origin) }
    }

    func removeAll() {
        queue.async(flags: .barrier) { self.origins.removeAll() }
    }
}

actor ServiceWorkerManager {
    static let shared = ServiceWorkerManager()

    // Thread-safe storage for managed origins (accessible outside actor)
    private static let _managedOriginsStorage = ManagedOriginsStorage()

    // Changed from [origin: registration] to [origin: [scope: registration]]
    // to support multiple scopes per origin
    private var registrations: [String: [String: ServiceWorkerRegistration]] = [:]
    private var contexts: [String: [String: ServiceWorkerContext]] = [:]  // [origin: [scope: context]]
    private var pendingRequests: [String: PWAURLProtocol] = [:]

    // Persistence layer (optional, nil during some tests)
    private var persistence: CachePersistence?

    private init() {}

    func setPersistence(_ persistence: CachePersistence?) {
        self.persistence = persistence
    }

    // MARK: - Persistence Integration

    func loadFromDisk() async {
        guard let persistence = persistence else { return }

        let loaded = persistence.loadAllRegistrations()
        for snapshot in loaded {
            if snapshot.state == .activated {
                let registration = ServiceWorkerRegistration(from: snapshot)
                if registrations[snapshot.origin] == nil {
                    registrations[snapshot.origin] = [:]
                }
                registrations[snapshot.origin]?[snapshot.scope] = registration
                // Add to managed origins so URLProtocol knows to intercept
                addManagedOrigin(snapshot.origin)
            }
        }
    }

    func register(scriptURL: URL, scope: String, origin: String) async -> ServiceWorkerRegistration {
        // Add to managed origins (thread-safe)
        addManagedOrigin(origin)

        // Initialize origin dict if needed
        if registrations[origin] == nil {
            registrations[origin] = [:]
        }

        // If registration already exists for this origin+scope, return it
        if let existing = registrations[origin]?[scope] {
            let existingScript = await existing.scriptURL
            if existingScript == scriptURL {
                return existing
            }
            // Different script - this is an update, let the existing flow continue
        }

        let registration = ServiceWorkerRegistration(scriptURL: scriptURL, scope: scope, origin: origin)
        registrations[origin]?[scope] = registration
        if let persistence = persistence {
            let snapshot = await registration.snapshot()
            persistence.saveRegistration(snapshot)
        }
        return registration
    }

    func getRegistration(for origin: String, path: String) async -> ServiceWorkerRegistration? {
        guard let scopeRegs = registrations[origin] else {
            print("[ServiceWorkerManager] No registration for origin '\(origin)'. Known origins: \(Array(registrations.keys))")
            return nil
        }

        // Find the most specific matching scope (longest scope that matches)
        var bestMatch: ServiceWorkerRegistration?
        var bestScopeLength = -1

        for (scope, reg) in scopeRegs {
            let matches = await reg.matchesScope(path: path)
            let state = await reg.state
            if matches && state == .activated && scope.count > bestScopeLength {
                bestMatch = reg
                bestScopeLength = scope.count
            }
        }

        if bestMatch == nil {
            print("[ServiceWorkerManager] No matching activated registration for path '\(path)' in origin '\(origin)'")
        }

        return bestMatch
    }

    func getRegistration(for origin: String) -> ServiceWorkerRegistration? {
        // Return first registration for this origin (for backward compatibility)
        return registrations[origin]?.values.first
    }

    func getRegistration(for origin: String, scope: String) -> ServiceWorkerRegistration? {
        return registrations[origin]?[scope]
    }

    func getState(for origin: String) async -> ServiceWorkerState? {
        // Return state of first registration (for backward compatibility)
        guard let reg = registrations[origin]?.values.first else { return nil }
        return await reg.state
    }

    func getState(for origin: String, scope: String) async -> ServiceWorkerState? {
        guard let reg = registrations[origin]?[scope] else { return nil }
        return await reg.state
    }

    func updateState(_ registration: ServiceWorkerRegistration, to state: ServiceWorkerState) async {
        let origin = await registration.origin
        let scope = await registration.scope
        print("[ServiceWorkerManager] Updating state for origin '\(origin)', scope '\(scope)' to '\(state)'")
        await registration.setState(state)
        if let persistence = persistence {
            let snapshot = await registration.snapshot()
            persistence.saveRegistration(snapshot)
        }
    }

    func unregister(origin: String) -> Bool {
        let removed = registrations.removeValue(forKey: origin) != nil
        contexts.removeValue(forKey: origin)
        removeManagedOrigin(origin)
        persistence?.deleteOrigin(origin)
        return removed
    }

    func unregister(origin: String, scope: String) -> Bool {
        let removed = registrations[origin]?.removeValue(forKey: scope) != nil
        contexts[origin]?.removeValue(forKey: scope)
        // Only delete from persistence and managed origins if no more scopes for this origin
        if registrations[origin]?.isEmpty == true {
            registrations.removeValue(forKey: origin)
            contexts.removeValue(forKey: origin)
            removeManagedOrigin(origin)
            persistence?.deleteOrigin(origin)
        }
        return removed
    }

    func clearAll() {
        registrations.removeAll()
        clearManagedOrigins()
        contexts.removeAll()
        pendingRequests.removeAll()
    }

    // MARK: - Managed Origins

    nonisolated func hasManagedOrigin(_ origin: String) -> Bool {
        // Thread-safe check - uses concurrent queue for reads
        return Self._managedOriginsStorage.contains(origin)
    }

    func addManagedOrigin(_ origin: String) {
        Self._managedOriginsStorage.insert(origin)
    }

    func removeManagedOrigin(_ origin: String) {
        Self._managedOriginsStorage.remove(origin)
    }

    func clearManagedOrigins() {
        Self._managedOriginsStorage.removeAll()
    }

    // MARK: - Context Management

    func setContext(_ context: ServiceWorkerContext, for origin: String, scope: String = "/") {
        if contexts[origin] == nil {
            contexts[origin] = [:]
        }
        contexts[origin]?[scope] = context
    }

    func getContext(for origin: String) -> ServiceWorkerContext? {
        // Return first context for this origin (for backward compatibility)
        return contexts[origin]?.values.first
    }

    func getContext(for origin: String, scope: String) -> ServiceWorkerContext? {
        return contexts[origin]?[scope]
    }

    func getContext(for origin: String, path: String) async -> ServiceWorkerContext? {
        guard let scopeContexts = contexts[origin] else { return nil }

        // Find the most specific matching scope (longest scope that matches)
        var bestMatch: ServiceWorkerContext?
        var bestScopeLength = -1

        for (scope, context) in scopeContexts {
            if path.hasPrefix(scope) && scope.count > bestScopeLength {
                bestMatch = context
                bestScopeLength = scope.count
            }
        }

        return bestMatch
    }

    func removeContext(for origin: String) {
        contexts.removeValue(forKey: origin)
    }

    func removeContext(for origin: String, scope: String) {
        contexts[origin]?.removeValue(forKey: scope)
        if contexts[origin]?.isEmpty == true {
            contexts.removeValue(forKey: origin)
        }
    }

    // MARK: - Pending Requests (for URLProtocol callbacks)

    nonisolated func registerPendingRequest(_ requestId: String, protocol urlProtocol: PWAURLProtocol) {
        Task {
            await self._registerPendingRequest(requestId, protocol: urlProtocol)
        }
    }

    func _registerPendingRequest(_ requestId: String, protocol urlProtocol: PWAURLProtocol) {
        pendingRequests[requestId] = urlProtocol
    }

    func getPendingRequest(_ requestId: String) -> PWAURLProtocol? {
        return pendingRequests.removeValue(forKey: requestId)
    }
}
