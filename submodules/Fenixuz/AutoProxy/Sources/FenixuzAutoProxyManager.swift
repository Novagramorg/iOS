import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

// Drives the "Enable NovagramProxy" opt-in. When the user turns the toggle ON (default is OFF),
// the app auto-finds a working SOCKS5 proxy from the bundled pool and routes THIS user's Telegram
// connection through it — so a user in any blocked country can reach Telegram without configuring
// a proxy by hand. The proxy details are never surfaced by the toggle.
//
// It writes only the shared proxy settings via the public `updateProxySettingsInteractively` API;
// the running account observes that change and applies the proxy automatically. No dependency on a
// live account/network, so it works before login too (the login server itself may be blocked), and
// stays merge-stable (no `SharedAccountContext` internals touched).
//
// Safety:
//   • A proxy the user configured themselves is never overridden or removed.
//   • A proxy we set earlier that has since died is re-checked and rotated to a live one.
//   • Turning the toggle OFF removes only our proxy, never the user's own.
public final class FenixuzAutoProxyManager {
    public static let shared = FenixuzAutoProxyManager()

    private let coordinationQueue = DispatchQueue(label: "uz.fenixuz.app.AutoProxy.coordination")
    private let readDisposable = MetaDisposable()

    // Persisted opt-in toggle, default OFF. Kept in the shared "pro_messager" defaults suite so it
    // lives alongside the other NovagramPro settings.
    private let defaultsSuite = "pro_messager"
    private let enabledKey = "novagram_proxy_enabled"

    // Health-probe tuning. ~90% of the pool is alive at any moment, so one batch almost always
    // yields a live proxy; the extra batches are a safety margin.
    private let probeTimeout: TimeInterval = 6.0
    private let batchSize = 6
    private let maxCandidates = 18

    private init() {}

    deinit {
        self.readDisposable.dispose()
    }

    // MARK: - Public toggle state

    public var isEnabled: Bool {
        return UserDefaults(suiteName: self.defaultsSuite)?.bool(forKey: self.enabledKey) ?? false
    }

    private func persist(enabled: Bool) {
        UserDefaults(suiteName: self.defaultsSuite)?.set(enabled, forKey: self.enabledKey)
    }

    // MARK: - Entry points

    // Called once from AppDelegate at launch. If the toggle is ON, make sure a healthy proxy is
    // active (rotating to a fresh one if the previously-chosen proxy has died).
    public func start(sharedContext: SharedAccountContext) {
        self.coordinationQueue.async { [weak self] in
            guard let self = self, self.isEnabled else {
                return
            }
            self.ensureActiveProxy(sharedContext: sharedContext)
        }
    }

    // Called from the NovagramPro toggle row. Persists the choice and applies it immediately.
    public func setEnabled(_ enabled: Bool, sharedContext: SharedAccountContext) {
        self.coordinationQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.persist(enabled: enabled)
            if enabled {
                self.ensureActiveProxy(sharedContext: sharedContext)
            } else {
                self.disableOurProxy(sharedContext: sharedContext)
            }
        }
    }

    // MARK: - Enable path

    // Runs on coordinationQueue.
    private func ensureActiveProxy(sharedContext: SharedAccountContext) {
        let accountManager = sharedContext.accountManager
        self.readDisposable.set((accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> take(1)).start(next: { [weak self] sharedData in
            let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
            self?.coordinationQueue.async {
                self?.handleForEnable(currentSettings: settings, accountManager: accountManager)
            }
        }))
    }

    // Runs on coordinationQueue.
    private func handleForEnable(currentSettings: ProxySettings, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let pool = FenixuzProxyPool.loadShuffled()
        if pool.isEmpty {
            return
        }
        let poolHosts = Set(pool.map { $0.host })

        if let active = currentSettings.effectiveActiveServer {
            guard case .socks5 = active.connection, poolHosts.contains(active.host) else {
                // The user has their own proxy active — respect it, do nothing.
                return
            }
            // One of ours: keep it if it still works, otherwise rotate to a fresh live one.
            let checkSession = FenixuzProxyProbeSession(candidates: [active], batchSize: 1, probeTimeout: self.probeTimeout, queue: self.coordinationQueue)
            checkSession.start { [weak self] aliveServer in
                guard let self = self, aliveServer == nil else {
                    return
                }
                self.selectAndEnable(pool: pool, excludingHost: active.host, accountManager: accountManager)
            }
        } else {
            self.selectAndEnable(pool: pool, excludingHost: nil, accountManager: accountManager)
        }
    }

    // Runs on coordinationQueue.
    private func selectAndEnable(pool: [ProxyServerSettings], excludingHost: String?, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        var candidates = pool
        if let excludingHost = excludingHost {
            candidates = candidates.filter { $0.host != excludingHost }
        }
        candidates = Array(candidates.prefix(self.maxCandidates))
        if candidates.isEmpty {
            return
        }
        let session = FenixuzProxyProbeSession(candidates: candidates, batchSize: self.batchSize, probeTimeout: self.probeTimeout, queue: self.coordinationQueue)
        session.start { [weak self] server in
            guard let self = self, let server = server else {
                return
            }
            self.enable(server: server, accountManager: accountManager)
        }
    }

    // Runs on coordinationQueue. Writes the chosen proxy to shared data and enables it. Re-checks
    // the toggle in case the user turned it OFF while probing was still in flight.
    private func enable(server: ProxyServerSettings, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        guard self.isEnabled else {
            return
        }
        _ = updateProxySettingsInteractively(accountManager: accountManager, { settings in
            var settings = settings
            if let index = settings.servers.firstIndex(of: server) {
                settings.servers[index] = server
            } else {
                settings.servers.insert(server, at: 0)
            }
            settings.activeServer = server
            settings.enabled = true
            return settings
        }).start()
    }

    // MARK: - Disable path

    // Runs on coordinationQueue. Turns the proxy off and clears our servers ONLY when the active
    // proxy is one of ours; never touches a proxy the user configured themselves.
    private func disableOurProxy(sharedContext: SharedAccountContext) {
        let accountManager = sharedContext.accountManager
        self.readDisposable.set((accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> take(1)).start(next: { [weak self] sharedData in
            let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) ?? ProxySettings.defaultSettings
            self?.coordinationQueue.async {
                let poolHosts = Set(FenixuzProxyPool.loadShuffled().map { $0.host })
                guard let active = settings.effectiveActiveServer, poolHosts.contains(active.host) else {
                    // No active proxy, or it is the user's own — leave everything alone.
                    return
                }
                _ = updateProxySettingsInteractively(accountManager: accountManager, { settings in
                    var settings = settings
                    settings.servers.removeAll(where: { poolHosts.contains($0.host) })
                    if let activeHost = settings.activeServer?.host, poolHosts.contains(activeHost) {
                        settings.activeServer = nil
                    }
                    settings.enabled = false
                    return settings
                }).start()
            }
        }))
    }
}
