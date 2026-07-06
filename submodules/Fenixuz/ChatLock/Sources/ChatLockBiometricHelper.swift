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
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Not available (no hardware, not enrolled, locked out after too many failures).
            DispatchQueue.main.async { completion(.unavailable) }
            return
        }

        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
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
