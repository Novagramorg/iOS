import Foundation
import LocalAuthentication

// Thin async wrapper around LAContext for ChatLock's biometric unlock step.
// We call evaluatePolicy directly (not via the shared LocalAuth module) because
// ChatLock only needs a simple prompt — no Secure Enclave key involved.

enum ChatLockBiometricResult {
    case success
    /// User cancelled Face ID / Touch ID sheet.
    case cancelled
    /// Hardware unavailable, not enrolled, or locked out — show PIN/text field instead.
    case unavailable
}

final class ChatLockBiometricHelper {

    /// LocalAuthentication cancels an evaluation the moment its LAContext is released, so the
    /// context has to outlive the call that started it. Holding the live one here also lets us
    /// cancel it before a different prompt starts — two concurrent evaluations knock each other
    /// out, and the second one comes back as a plain failure with no passcode fallback.
    private static var activeContext: LAContext?

    /// Cancels a prompt that is still on screen. Call before starting a different one.
    static func cancelPending() {
        activeContext?.invalidate()
        activeContext = nil
    }

    // Returns the biometric type available on this device, or nil if none.
    static func availableType() -> ChatLockBiometricType? {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch ctx.biometryType {
        case .faceID:   return .faceID
        case .touchID:  return .touchID
        default:        return nil
        }
    }

    // Triggers a biometric prompt and calls completion on the main thread.
    // Never throws — all error paths map to .cancelled or .unavailable.
    static func evaluate(reason: String, completion: @escaping (ChatLockBiometricResult) -> Void) {
        cancelPending()

        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Not available (no hardware, not enrolled, locked out after too many failures).
            DispatchQueue.main.async { completion(.unavailable) }
            return
        }
        activeContext = ctx

        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                if activeContext === ctx {
                    activeContext = nil
                }
                if success {
                    completion(.success)
                    return
                }
                // Map LAError codes to our simplified result set.
                let code = (evalError as? LAError)?.code
                switch code {
                case .userCancel, .systemCancel, .appCancel, .userFallback:
                    completion(.cancelled)
                default:
                    // biometryLockout, biometryNotEnrolled, biometryNotAvailable, etc.
                    completion(.unavailable)
                }
            }
        }
    }
}
