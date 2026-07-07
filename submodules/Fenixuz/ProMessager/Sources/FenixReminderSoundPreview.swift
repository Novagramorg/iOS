import Foundation
import AVFoundation
import FenixuzUnreadReminder

/// Plays a short preview of a bundled reminder tone when the user taps a row in the
/// sound picker. The AVAudioPlayer is held here so it is not deallocated mid-playback
/// (a locally-scoped player would stop the instant the closure returns).
final class FenixReminderSoundPreview {
    static let shared = FenixReminderSoundPreview()

    private var player: AVAudioPlayer?

    private init() {}

    /// Plays the tone for the given sound key. "default"/"none" (and any key without a
    /// bundled file) are silent no-ops — there is nothing local to preview.
    func play(key: String) {
        guard let fileName = FenixuzUnreadReminderSettings.fileName(for: key) else {
            return
        }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        // Bazel packs the .caf into the module's FRAMEWORK, not the app's main bundle,
        // so resolve them from there (Bundle.main.url returns nil → previously silent).
        guard let url = FenixuzUnreadReminderSettings.soundsBundle.url(forResource: name, withExtension: ext) else {
            return
        }

        // Use .playback so the preview is audible even with the ring switch muted —
        // the user explicitly asked to hear it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        self.player?.stop()
        self.player = try? AVAudioPlayer(contentsOf: url)
        self.player?.prepareToPlay()
        self.player?.play()
    }
}
