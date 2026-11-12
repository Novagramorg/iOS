import Foundation
import CoreAudio
import NovagramVoiceDSP

/// What the user sets for Modulation (tone in semitones), Echo (delay in tenths of a second, volume in tenths) and
/// Noise (volume in tenths), in the steps the Android app offers.
public struct NovagramVoiceParams: Equatable {
    public static let toneRange: ClosedRange<Int> = Int(NV_TONE_MIN) ... Int(NV_TONE_MAX)
    public static let stepRange: ClosedRange<Int> = Int(NV_STEP_MIN) ... Int(NV_STEP_MAX)

    public var tone: Int
    public var echoDelay: Int
    public var echoVolume: Int
    public var noiseVolume: Int

    public init(tone: Int, echoDelay: Int, echoVolume: Int, noiseVolume: Int) {
        self.tone = tone
        self.echoDelay = echoDelay
        self.echoVolume = echoVolume
        self.noiseVolume = noiseVolume
    }

    /// +5 semitones; an echo at 70% after 0.5 s; noise at 70%.
    public static var `default`: NovagramVoiceParams {
        let value = nv_params_default()
        return NovagramVoiceParams(tone: Int(value.tone), echoDelay: Int(value.echoDelay), echoVolume: Int(value.echoVolume), noiseVolume: Int(value.noiseVolume))
    }

    var dsp: NVParams {
        return nv_params_clamped(NVParams(tone: Int32(self.tone), echoDelay: Int32(self.echoDelay), echoVolume: Int32(self.echoVolume), noiseVolume: Int32(self.noiseVolume)))
    }
}

/// The preset ids, the same numbers as on Android. They are stored, so never renumber.
public enum NovagramVoicePreset {
    public static let off = Int(NV_PRESET_OFF)
    public static let child = Int(NV_PRESET_CHILD)
    public static let woman = Int(NV_PRESET_WOMAN)
    public static let man = Int(NV_PRESET_MAN)
    public static let helium = Int(NV_PRESET_HELIUM)
    public static let hexafluoride = Int(NV_PRESET_HEXAFLUORIDE)
    public static let monster = Int(NV_PRESET_MONSTER)
    public static let mouse = Int(NV_PRESET_MOUSE)
    public static let robot = Int(NV_PRESET_ROBOT)
    public static let alien = Int(NV_PRESET_ALIEN)
    public static let echo = Int(NV_PRESET_ECHO)
    public static let cave = Int(NV_PRESET_CAVE)
    public static let hoarseness = Int(NV_PRESET_HOARSENESS)
    public static let modulation = Int(NV_PRESET_MODULATION)
    public static let noise = Int(NV_PRESET_NOISE)

    /// The picker's "Record speed" row; it stands for `speeds`.
    public static let speedRow = -1

    /// The four tape speeds, thickest first.
    public static let speeds: [Int] = [16, 17, 18, 19]

    /// The picker's rows, in the Android app's order.
    public static let rows: [Int] = [off, speedRow, robot, alien, hoarseness, modulation, child, mouse, man, woman, monster, echo, noise, helium, hexafluoride, cave]

    public static func isSpeed(_ id: Int) -> Bool {
        return nv_preset_is_speed(Int32(id)) != 0
    }

    public static func hasSettings(_ id: Int) -> Bool {
        return nv_preset_has_settings(Int32(id)) != 0
    }

    static func isKnown(_ id: Int) -> Bool {
        return nv_preset_is_known(Int32(id)) != 0
    }
}

/// One choice of effect and its settings: one for voice messages, one for calls.
public final class NovagramVoiceChoice {
    private let prefix: String
    public let allowsSpeed: Bool

    init(prefix: String, allowsSpeed: Bool) {
        self.prefix = prefix
        self.allowsSpeed = allowsSpeed
    }

    /// The chosen preset; an id no preset has (or a speed where speeds aren't allowed) reads as off.
    public var presetId: Int {
        get {
            let id = NovagramVoiceChanger.defaults?.object(forKey: self.prefix + "preset") as? Int ?? NovagramVoicePreset.off
            if !NovagramVoicePreset.isKnown(id) || (!self.allowsSpeed && NovagramVoicePreset.isSpeed(id)) {
                return NovagramVoicePreset.off
            }
            return id
        }
        set {
            NovagramVoiceChanger.defaults?.set(newValue, forKey: self.prefix + "preset")
            NovagramVoiceChanger.didChange()
        }
    }

    public var params: NovagramVoiceParams {
        get {
            let defaults = NovagramVoiceChanger.defaults
            let fallback = NovagramVoiceParams.default
            func read(_ key: String, _ value: Int, _ range: ClosedRange<Int>) -> Int {
                let stored = defaults?.object(forKey: self.prefix + key) as? Int ?? value
                return min(max(stored, range.lowerBound), range.upperBound)
            }
            return NovagramVoiceParams(
                tone: read("tone", fallback.tone, NovagramVoiceParams.toneRange),
                echoDelay: read("echo_delay", fallback.echoDelay, NovagramVoiceParams.stepRange),
                echoVolume: read("echo_volume", fallback.echoVolume, NovagramVoiceParams.stepRange),
                noiseVolume: read("noise_volume", fallback.noiseVolume, NovagramVoiceParams.stepRange)
            )
        }
        set {
            let defaults = NovagramVoiceChanger.defaults
            defaults?.set(newValue.tone, forKey: self.prefix + "tone")
            defaults?.set(newValue.echoDelay, forKey: self.prefix + "echo_delay")
            defaults?.set(newValue.echoVolume, forKey: self.prefix + "echo_volume")
            defaults?.set(newValue.noiseVolume, forKey: self.prefix + "noise_volume")
            NovagramVoiceChanger.didChange()
        }
    }
}

/// The voice changer, ported from the Android app. Not approved yet, so one switch in the hidden Developer section
/// turns it on (`isEnabled`); while it is off nothing changes any voice, whatever effects are chosen.
public enum NovagramVoiceChanger {
    public static let changedNotification = Notification.Name("NovagramVoiceChangerChanged")

    static let defaults = UserDefaults(suiteName: "pro_messager")
    private static let enabledKey = "novagram_voice_changer"

    /// Voice messages, keys "novagram_voice_changer_preset", "..._tone", "..._echo_delay", "..._echo_volume",
    /// "..._noise_volume".
    public static let messages = NovagramVoiceChoice(prefix: "novagram_voice_changer_", allowsSpeed: true)

    /// Calls, the same keys with "call_" after the prefix. A live voice can't play faster or slower, so no speeds.
    public static let calls = NovagramVoiceChoice(prefix: "novagram_voice_changer_call_", allowsSpeed: false)

    /// The Developer switch.
    public static var isEnabled: Bool {
        get { return self.defaults?.object(forKey: self.enabledKey) as? Bool ?? false }
        set {
            self.defaults?.set(newValue, forKey: self.enabledKey)
            self.didChange()
        }
    }

    /// Hands the call choice to the call audio (C, read on the audio thread). Called at launch and on every change.
    public static func syncCallChoice() {
        let choice = self.calls
        let presetId = self.isEnabled ? choice.presetId : NovagramVoicePreset.off
        nv_call_set_choice(Int32(presetId), choice.params.dsp)
    }

    static func didChange() {
        self.syncCallChoice()
        NotificationCenter.default.post(name: self.changedNotification, object: nil)
    }

    /// The effect for one voice message, or nil while the voice changer is off or no effect is chosen.
    public static func makeRecorderEffect(sampleRate: Int) -> NovagramVoiceRecorderEffect? {
        guard self.isEnabled else {
            return nil
        }
        let choice = self.messages
        return NovagramVoiceRecorderEffect(presetId: choice.presetId, params: choice.params, sampleRate: sampleRate)
    }
}

/// One voice message's effect, in ManagedAudioRecorder (HOOKS.md, "Voice changer"). The recorder's own loop cuts
/// what comes out into Opus frames, so the waveform, the timer and the length all follow the changed voice (a tape
/// speed changes the length). Recorder queue only.
public final class NovagramVoiceRecorderEffect {
    private let effect: OpaquePointer
    private var isForwarding = false

    init?(presetId: Int, params: NovagramVoiceParams, sampleRate: Int) {
        guard let effect = nv_effect_create(Int32(presetId), params.dsp, Int32(sampleRate)) else {
            return nil
        }
        self.effect = effect
    }

    deinit {
        nv_effect_destroy(self.effect)
    }

    /// Runs one microphone buffer (16-bit mono) through the effect and hands the result to `sink` as a new buffer
    /// the sink frees. Returns false, doing nothing, for the buffer the sink itself gets, so the recorder can call
    /// its own processing as the sink.
    public func process(_ buffer: AudioBuffer, into sink: (AudioBuffer) -> Void) -> Bool {
        guard !self.isForwarding, let data = buffer.mData else {
            return false
        }
        var output: UnsafePointer<Int16>?
        let count = nv_effect_process(self.effect, data.assumingMemoryBound(to: Int16.self), Int32(buffer.mDataByteSize / 2), &output)
        self.forward(output, count: Int(count), into: sink)
        return true
    }

    /// The end of the recording: what the effect still holds (an echo fading out, the pitch shifter's last samples).
    public func drain(into sink: (AudioBuffer) -> Void) {
        var output: UnsafePointer<Int16>?
        let count = nv_effect_drain(self.effect, &output)
        self.forward(output, count: Int(count), into: sink)
    }

    private func forward(_ samples: UnsafePointer<Int16>?, count: Int, into sink: (AudioBuffer) -> Void) {
        guard let samples, count > 0, let copy = malloc(count * 2) else {
            return
        }
        memcpy(copy, samples, count * 2)
        self.isForwarding = true
        sink(AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(count * 2), mData: copy))
        self.isForwarding = false
    }
}
