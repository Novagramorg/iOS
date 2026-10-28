import Foundation
import LocalAuthentication

public enum SecretVaultBiometric {
    /// The biometric hardware available on this device.
    public enum Kind {
        case faceID
        case touchID
    }

    /// Device-owner authentication — Face ID / Touch ID with an automatic fallback to
    /// the device passcode. Used as the "Forgot vault PIN?" recovery path: proving
    /// device ownership is enough to reopen the vault, since the hidden chats are not
    /// separately encrypted (only gated by the PIN).
    public static func authenticateDeviceOwner(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    /// The enrolled biometric type, or nil when no biometrics are available/enrolled
    /// (e.g. a bare simulator, or a device with Face ID disabled). Drives whether the
    /// "Unlock with Face ID / Touch ID" toggle is shown and how it is labelled.
    public static func availableType() -> Kind? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        default:       return nil
        }
    }

    /// Biometrics-only prompt (no passcode fallback). Used once to confirm the user can
    /// authenticate when they turn the vault biometric toggle ON. The PIN/text entry
    /// stays the fallback at vault-open time, so a biometric failure here never strands
    /// the user out of the vault.
    public static func authenticateBiometricsOnly(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
