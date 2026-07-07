import Foundation
import SwiftSignalKit

// MARK: - Notification name (Feature #6)

public extension NSNotification.Name {
    // Posted when the user flips the "Show ads" toggle in NovagramPro settings.
    // ChatHistoryListNode subscribes via FenixShowAdsGate so the ads gate re-reads live.
    static let fenixShowAdsChanged = NSNotification.Name("FenixShowAdsChanged")
}

// MARK: - Reactive read helper (Feature #6)

/// Lets ChatHistoryListNode gate the sponsored-message stream on the "Show ads" toggle
/// without referencing UserDefaults key literals, and re-evaluate live when the toggle flips.
public enum FenixShowAdsGate {
    private static let udSuite = "pro_messager"
    private static let udKey = "fenix_show_ads"

    /// Current toggle value. Default true = sponsored messages shown.
    public static var isEnabled: Bool {
        return UserDefaults(suiteName: udSuite)?.object(forKey: udKey) as? Bool ?? true
    }

    /// Emits the current toggle value immediately, then re-emits whenever the toggle posts
    /// `.fenixShowAdsChanged`. Delivered on the main queue (NotificationCenter observer queue).
    public static var enabledSignal: Signal<Bool, NoError> {
        return Signal { subscriber in
            subscriber.putNext(isEnabled)
            let observer = NotificationCenter.default.addObserver(forName: .fenixShowAdsChanged, object: nil, queue: .main) { _ in
                subscriber.putNext(isEnabled)
            }
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    /// Wraps an ad-message source signal so it emits `empty` while the toggle is off and mirrors
    /// `source` while on, switching live on toggle changes. Generic to avoid coupling to the
    /// ad-message tuple type in TelegramUI.
    public static func gate<T>(empty: T, source: Signal<T, NoError>) -> Signal<T, NoError> {
        return enabledSignal
        |> distinctUntilChanged
        |> mapToSignal { show -> Signal<T, NoError> in
            return show ? source : .single(empty)
        }
    }
}
