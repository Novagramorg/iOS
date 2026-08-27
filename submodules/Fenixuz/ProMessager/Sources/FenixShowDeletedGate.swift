import Foundation
import SwiftSignalKit

// MARK: - Notification name (show deleted messages)

public extension NSNotification.Name {
    // Posted when the user flips the "Show deleted messages" toggle in NovagramPro settings.
    // ChatHistoryListNode subscribes via FenixShowDeletedGate so the history transform re-runs live.
    static let fenixShowDeletedChanged = NSNotification.Name("FenixShowDeletedChanged")
}

// MARK: - Reactive reload helper (show deleted messages)

/// Lets ChatHistoryListNode re-run its history transform when the "Show deleted messages"
/// toggle flips, without reopening the chat. The transform itself reads the UserDefaults key;
/// this only pokes the pipeline so that read happens again.
public enum FenixShowDeletedGate {
    /// Emits `()` immediately, then re-emits whenever the toggle posts `.fenixShowDeletedChanged`.
    /// Delivered on the main queue (NotificationCenter observer queue).
    public static var reloadSignal: Signal<Void, NoError> {
        return Signal { subscriber in
            subscriber.putNext(())
            let observer = NotificationCenter.default.addObserver(forName: .fenixShowDeletedChanged, object: nil, queue: .main) { _ in
                subscriber.putNext(())
            }
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

// MARK: - App Group mirror (so the notification extension can see the toggle)

/// The "Deleted messages" flag has to be readable from the NotificationService extension: Telegram
/// pushes a silent `MESSAGE_DELETED` and the extension is what actually removes the message from
/// the (shared) Postbox, long before the app's own state manager ever sees the delete.
///
/// `UserDefaults(suiteName: "pro_messager")` is a plain suite, so it resolves to a *per-process*
/// container — the extension reading it always gets `false`. Mirror the value into the App Group
/// suite, which both processes really do share.
public enum FenixSharedDefaults {
    /// Key is deliberately the same as in the `pro_messager` suite so the two stay easy to trace.
    public static let showDeletedMessagesKey = "show_deleted_messages"

    /// Main-app side only. The extension derives its own name by stripping its bundle-id suffix.
    public static var appGroupName: String? {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return nil
        }
        return "group.\(bundleId)"
    }

    /// Copies the current `show_deleted_messages` value into the App Group suite. Safe to call
    /// repeatedly; also acts as the backfill for users who had the toggle on before this shipped.
    public static func syncShowDeletedMessages() {
        guard let appGroupName = self.appGroupName, let shared = UserDefaults(suiteName: appGroupName) else {
            return
        }
        let value = UserDefaults(suiteName: "pro_messager")?.bool(forKey: self.showDeletedMessagesKey) ?? false
        shared.set(value, forKey: self.showDeletedMessagesKey)
    }
}
