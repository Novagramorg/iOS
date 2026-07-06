import Foundation
import Security
import SwiftSignalKit
import TelegramCore
import AccountContext

// Orchestrates the two analytics counters against the Novagram Statistics API:
//   • "Number of Novagram users" — distinct devices, counted ONCE per physical device
//     (downloads, via POST /v1/install).
//   • "Active accounts"          — one per device while it holds at least one account
//     (active, via POST /v1/account/create when it gains its first account and
//     POST /v1/account/delete when it loses its last).
//
// The server dedups by `device_id`, so the calls are idempotent and the client never owns a
// counter. Local state (the stable device id + two "already sent" flags) lives in the
// KEYCHAIN on purpose: Keychain survives app deletion + reinstall on the same device, so a
// reinstall does NOT re-count the device. (UserDefaults would be wiped on reinstall and
// inflate downloads.)
public final class FenixuzAnalyticsManager {
    public static let shared = FenixuzAnalyticsManager()

    private let stateQueue = DispatchQueue(label: "uz.fenixuz.app.Analytics.state")
    private let keychainService = "uz.fenixuz.app.Analytics"

    private let deviceIdKey = "deviceId"
    private let installRegisteredKey = "installRegistered"
    private let deviceActiveKey = "deviceActive"

    private var accountsDisposable: Disposable?
    private var started = false

    private init() {}

    deinit {
        self.accountsDisposable?.dispose()
    }

    // Called once from AppDelegate after the shared account context is ready.
    public func start(sharedContext: SharedAccountContext) {
        self.stateQueue.async { [weak self] in
            self?.registerInstallIfNeeded()
        }
        if !self.started {
            self.started = true
            self.observeAccounts(sharedContext: sharedContext)
        }
    }

    // MARK: - Install (downloads, once per device)

    private func registerInstallIfNeeded() {
        guard FenixuzAnalyticsConfig.isConfigured else {
            return
        }
        if self.readKeychain(key: self.installRegisteredKey) == "1" {
            return
        }
        let deviceId = self.deviceId()
        FenixuzStatisticsClient.shared.registerInstall(deviceId: deviceId, completion: { [weak self] response in
            guard let self = self, response != nil else {
                return
            }
            self.stateQueue.async {
                self.writeKeychain("1", key: self.installRegisteredKey)
            }
        })
    }

    // MARK: - Active (one per device while it holds at least one account)

    private func observeAccounts(sharedContext: SharedAccountContext) {
        self.accountsDisposable = (sharedContext.activeAccountContexts
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self = self else {
                return
            }
            let hasAccounts = !value.1.isEmpty
            self.stateQueue.async {
                self.syncActiveState(hasAccounts: hasAccounts)
            }
        })
    }

    // Runs on stateQueue. Drives the device's active presence: +1 the moment it gains its
    // first account, -1 the moment it loses its last. The local flag is updated optimistically
    // and rolled back on network failure so the next emission / launch retries.
    private func syncActiveState(hasAccounts: Bool) {
        guard FenixuzAnalyticsConfig.isConfigured else {
            return
        }
        let isActive = self.readKeychain(key: self.deviceActiveKey) == "1"
        if hasAccounts == isActive {
            return
        }
        let deviceId = self.deviceId()
        if hasAccounts {
            self.writeKeychain("1", key: self.deviceActiveKey)
            FenixuzStatisticsClient.shared.registerAccountCreate(deviceId: deviceId, completion: { [weak self] response in
                guard let self = self, response == nil else {
                    return
                }
                self.stateQueue.async {
                    self.writeKeychain("0", key: self.deviceActiveKey)
                }
            })
        } else {
            self.writeKeychain("0", key: self.deviceActiveKey)
            FenixuzStatisticsClient.shared.registerAccountDelete(deviceId: deviceId, completion: { [weak self] response in
                guard let self = self, response == nil else {
                    return
                }
                self.stateQueue.async {
                    self.writeKeychain("1", key: self.deviceActiveKey)
                }
            })
        }
    }

    // MARK: - Reading the counts for the UI

    public func counts() -> Signal<(devices: Int?, accounts: Int?), NoError> {
        return Signal { subscriber in
            FenixuzStatisticsClient.shared.fetchStats(completion: { result in
                if let result = result {
                    subscriber.putNext((result.downloads, result.active))
                } else {
                    subscriber.putNext((nil, nil))
                }
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
    }

    // MARK: - Device id (Keychain — survives reinstall on the same device)

    private func deviceId() -> String {
        if let existing = self.readKeychain(key: self.deviceIdKey) {
            return existing
        }
        let generated = UUID().uuidString
        self.writeKeychain(generated, key: self.deviceIdKey)
        return generated
    }

    // MARK: - Keychain plumbing

    private func baseQuery(key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: key
        ]
    }

    private func readKeychain(key: String) -> String? {
        var query = self.baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func writeKeychain(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }
        let updateQuery = self.baseQuery(key: key)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary) == errSecSuccess {
            return
        }
        var addQuery = self.baseQuery(key: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }
}
