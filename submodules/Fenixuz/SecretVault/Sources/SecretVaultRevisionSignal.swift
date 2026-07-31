import Foundation
import SwiftSignalKit

/// Emits once immediately, then again on every change to the vaulted set.
///
/// Surfaces that build their own peer feed from a reactive pipeline need something to re-trigger
/// that pipeline when a chat is hidden or unhidden — otherwise the row only disappears after some
/// unrelated update happens to fire. Combine this into the pipeline's inputs and the list rebuilds
/// straight away. The value itself is meaningless; only the emission matters.
public func fenixSecretVaultRevisionSignal() -> Signal<Int, NoError> {
    return Signal { subscriber in
        subscriber.putNext(0)

        var revision = 0
        let observer = NotificationCenter.default.addObserver(forName: .fenixSecretVaultChanged, object: nil, queue: .main) { _ in
            revision += 1
            subscriber.putNext(revision)
        }

        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
