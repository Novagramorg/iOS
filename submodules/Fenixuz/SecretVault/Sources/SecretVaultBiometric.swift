import Foundation
import LocalAuthentication

public enum SecretVaultBiometric {
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
}
