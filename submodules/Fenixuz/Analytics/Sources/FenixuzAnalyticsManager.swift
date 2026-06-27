import Foundation
import Security
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

// Orchestrates the two analytics counters against the shared Firebase RTDB:
//   • "Number of Novagram users" — distinct devices, counted ONCE per physical device.
//   • "Active accounts"          — cumulative account registrations, +1 per new account,
//                                  never decremented on logout.
//
// Dedup state (device-id, "device counted" flag, the set of already-counted account ids)
// lives in the KEYCHAIN on purpose: Keychain survives app deletion + reinstall on the same
// device, so a reinstall does NOT re-count the device or its accounts. (UserDefaults would
// be wiped on reinstall and inflate the numbers.)
public final class FenixuzAnalyticsManager {
    public static let shared = FenixuzAnalyticsManager()

    private let stateQueue = DispatchQueue(label: "uz.fenixuz.app.Analytics.state")
    private let keychainService = "uz.fenixuz.app.Analytics"

    private let deviceIdKey = "deviceId"
    private let deviceCountedKey = "deviceCounted"
    private let countedAccountsKey = "countedAccounts"

    private var accountsDisposable: Disposable?
    private var started = false

    private init() {}

    deinit {
        self.accountsDisposable?.dispose()
    }

    // Called once from AppDelegate after the shared account context is ready.
    public func start(sharedContext: SharedAccountContext) {
        self.stateQueue.async { [weak self] in
            self?.trackDeviceLaunchIfNeeded()
        }
        if !self.started {
            self.started = true
            self.observeAccounts(sharedContext: sharedContext)
        }
    }

    // MARK: - Device counting (runs on stateQueue)

    private func trackDeviceLaunchIfNeeded() {
        guard FenixuzAnalyticsConfig.isConfigured else {
            return
        }
        if self.readKeychain(key: self.deviceCountedKey) == "1" {
            return
        }
        let deviceId = self.deviceId()
        FenixuzFirebaseClient.shared.markPresent(path: FenixuzAnalyticsConfig.devicesPath + "/" + deviceId, completion: { _ in })
        FenixuzFirebaseClient.shared.increment(path: FenixuzAnalyticsConfig.deviceCountPath, by: 1, completion: { [weak self] success in
            guard let self = self, success else {
                return
            }
            self.stateQueue.async {
                self.writeKeychain("1", key: self.deviceCountedKey)
            }
        })
    }

    // MARK: - Account counting

    private func observeAccounts(sharedContext: SharedAccountContext) {
        self.accountsDisposable = (sharedContext.activeAccountContexts
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self = self else {
                return
            }
            // Pull the stable per-account ids on the main queue, then mutate dedup state
            // on the serial state queue.
            let keys = value.1.map { $0.1.account.peerId.toInt64() }
            self.stateQueue.async {
                guard FenixuzAnalyticsConfig.isConfigured else {
                    return
                }
                for key in keys {
                    self.trackAccountIfNeeded(key)
                }
            }
        })
    }

    // Runs on stateQueue.
    private func trackAccountIfNeeded(_ accountKey: Int64) {
        var counted = self.readCountedAccounts()
        if counted.contains(accountKey) {
            return
        }
        // Mark optimistically so a second emission for the same account (while the request
        // is in flight) does not double-increment.
        counted.insert(accountKey)
        self.writeCountedAccounts(counted)
        FenixuzFirebaseClient.shared.increment(path: FenixuzAnalyticsConfig.accountCountPath, by: 1, completion: { [weak self] success in
            guard let self = self, !success else {
                return
            }
            // Roll back on failure so a later emission / next launch retries.
            self.stateQueue.async {
                var set = self.readCountedAccounts()
                set.remove(accountKey)
                self.writeCountedAccounts(set)
            }
        })
    }

    private func readCountedAccounts() -> Set<Int64> {
        guard let raw = self.readKeychain(key: self.countedAccountsKey), !raw.isEmpty else {
            return []
        }
        return Set(raw.split(separator: ",").compactMap { Int64($0) })
    }

    private func writeCountedAccounts(_ set: Set<Int64>) {
        let raw = set.map { String($0) }.joined(separator: ",")
        self.writeKeychain(raw, key: self.countedAccountsKey)
    }

    // MARK: - Reading the counts for the UI

    public func counts() -> Signal<(devices: Int?, accounts: Int?), NoError> {
        let devices = FenixuzFirebaseClient.shared.readInt(path: FenixuzAnalyticsConfig.deviceCountPath)
        let accounts = FenixuzFirebaseClient.shared.readInt(path: FenixuzAnalyticsConfig.accountCountPath)
        return combineLatest(devices, accounts)
        |> map { devices, accounts -> (devices: Int?, accounts: Int?) in
            return (devices, accounts)
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
