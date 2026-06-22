import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences

/// Client-side "Unread message reminder" (Xabar eslatmasi).
///
/// v1 behavior: the manager watches the account's total unread count. While the
/// toggle is ON and there are unread messages, it remembers the moment the unread
/// state began. When the app moves to the background it schedules a single local
/// notification to fire after the remaining time needed to reach the configured
/// threshold (e.g. 5 minutes). Reading the messages (count → 0) or returning to the
/// foreground cancels the pending reminder.
///
/// Everything is local: no extra server calls. Unread state comes from the public
/// `renderedTotalUnreadCount(accountManager:engine:)` engine signal, scheduling from
/// `UNUserNotificationCenter`.
public final class FenixuzUnreadReminderManager {
    // One reminder request id — scheduling again replaces the previous one.
    private static let notificationIdentifier = "fenixuz.unreadReminder"

    // Self-retained instances keyed by account peer id. Keeping the manager here
    // (instead of as a stored property on AuthorizedApplicationContext) lets the
    // start hook be a single additive line in the Telegram-owned file.
    private static var instances: [Int64: FenixuzUnreadReminderManager] = [:]

    /// Starts (or restarts) the reminder manager for the given account context.
    /// Safe to call repeatedly — the manager is keyed by account peer id, so a
    /// second call for the same account replaces the previous instance.
    public static func startIfNeeded(context: AccountContext) {
        let accountId = context.account.peerId.toInt64()
        instances[accountId] = FenixuzUnreadReminderManager(context: context)
    }

    private let context: AccountContext
    private let queue = Queue.mainQueue()

    private var unreadDisposable: Disposable?
    private var observers: [NSObjectProtocol] = []

    // Live unread count for the account (already filtered by the user's notification
    // settings, so muted chats are excluded when the user expects them to be).
    private var unreadCount: Int32 = 0
    // Wall-clock moment the unread state began (Date, nil when everything is read).
    private var unreadSince: Date?

    // Asked the system for notification permission once per process when enabled.
    private var didRequestAuthorization = false

    private init(context: AccountContext) {
        self.context = context
        self.start()
    }

    deinit {
        self.unreadDisposable?.dispose()
        let center = NotificationCenter.default
        for observer in self.observers {
            center.removeObserver(observer)
        }
    }

    private func start() {
        self.observeUnreadCount()
        self.observeAppLifecycle()
        // Pre-warm permission so the first real reminder isn't silently dropped.
        if FenixuzUnreadReminderSettings.isEnabled {
            self.requestAuthorizationIfNeeded()
        }
    }

    private func observeUnreadCount() {
        self.unreadDisposable = (renderedTotalUnreadCount(
            accountManager: self.context.sharedContext.accountManager,
            engine: self.context.engine
        )
        |> deliverOn(self.queue)).start(next: { [weak self] countAndType in
            self?.handleUnreadCount(countAndType.0)
        })
    }

    private func handleUnreadCount(_ count: Int32) {
        let previousCount = self.unreadCount
        self.unreadCount = count

        if count > 0 {
            // Start the clock the moment we go from "all read" to "has unread".
            if previousCount == 0 || self.unreadSince == nil {
                self.unreadSince = Date()
            }
        } else {
            // Everything read — drop the clock and any scheduled reminder.
            self.unreadSince = nil
            self.cancelScheduledReminder()
        }
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default

        let didEnterBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.queue.async {
                self?.scheduleReminderIfNeeded()
            }
        }
        self.observers.append(didEnterBackground)

        // Coming back to the app means the user is here — no reminder needed.
        let willEnterForeground = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.queue.async {
                self?.cancelScheduledReminder()
            }
        }
        self.observers.append(willEnterForeground)
    }

    // MARK: - Scheduling

    private func scheduleReminderIfNeeded() {
        guard FenixuzUnreadReminderSettings.isEnabled else {
            return
        }
        guard self.unreadCount > 0, let unreadSince = self.unreadSince else {
            return
        }

        let thresholdSeconds = TimeInterval(max(1, FenixuzUnreadReminderSettings.minutes) * 60)
        let elapsed = Date().timeIntervalSince(unreadSince)
        // Fire after the remaining time to reach the threshold; never below 1s
        // (UNTimeIntervalNotificationTrigger requires a positive interval).
        let remaining = max(1.0, thresholdSeconds - elapsed)

        self.requestAuthorizationIfNeeded()

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            self.queue.async {
                self.scheduleReminder(after: remaining)
            }
        }
    }

    private func scheduleReminder(after interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = FenixuzUnreadReminderStrings.notificationTitle()
        content.body = FenixuzUnreadReminderStrings.notificationBody(count: Int(self.unreadCount))
        content.sound = self.notificationSound()

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: FenixuzUnreadReminderManager.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        // Replace any previously scheduled reminder before adding the fresh one.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [FenixuzUnreadReminderManager.notificationIdentifier])
        center.add(request, withCompletionHandler: nil)
    }

    private func cancelScheduledReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [FenixuzUnreadReminderManager.notificationIdentifier])
    }

    private func notificationSound() -> UNNotificationSound? {
        switch FenixuzUnreadReminderSettings.sound {
        case "none":
            return nil
        case "default":
            return .default
        default:
            return .default
        }
    }

    private func requestAuthorizationIfNeeded() {
        guard !self.didRequestAuthorization else {
            return
        }
        self.didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            // Result handled lazily at schedule time via getNotificationSettings.
        }
    }
}
