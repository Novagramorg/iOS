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
