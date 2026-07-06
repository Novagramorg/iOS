import Foundation
import CVosk

public enum VoskError: Error {
    case modelLoadFailed
    case recognizerCreateFailed
}

/// Thin Swift wrapper around the Vosk C recognizer.
///
/// Vosk is NOT thread-safe per recognizer, so the owner must serialize every call —
/// `SpeechToTextManager` feeds it from one dedicated serial queue.
public final class VoskSpeechRecognizer {
    private var model: OpaquePointer?
    private var recognizer: OpaquePointer?

    public init(modelPath: String, sampleRate: Float = 16000) throws {
        vosk_set_log_level(-1) // silence Kaldi info/debug logging
        guard let model = vosk_model_new(modelPath) else {
            throw VoskError.modelLoadFailed
        }
        guard let recognizer = vosk_recognizer_new(model, sampleRate) else {
            vosk_model_free(model)
            throw VoskError.recognizerCreateFailed
        }
        self.model = model
        self.recognizer = recognizer
    }

    /// Feed one chunk of 16 kHz mono PCM. `count` is the SAMPLE count (frameLength), not
    /// bytes — the `_s` variant takes shorts. Returns true at end-of-utterance (silence).
    @discardableResult
    public func acceptWaveform(_ samples: UnsafePointer<Int16>, count: Int) -> Bool {
        guard let recognizer = self.recognizer else { return false }
        return vosk_recognizer_accept_waveform_s(recognizer, samples, Int32(count)) == 1
    }

    /// In-progress transcription for live preview (the `"partial"` JSON field).
    public func partialText() -> String {
        guard let recognizer = self.recognizer else { return "" }
        return Self.decode(field: "partial", json: vosk_recognizer_partial_result(recognizer))
    }

    /// Final transcription, flushing any remaining buffered audio (the `"text"` JSON field).
    public func finalText() -> String {
        guard let recognizer = self.recognizer else { return "" }
        return Self.decode(field: "text", json: vosk_recognizer_final_result(recognizer))
    }

    /// Vosk returns a JSON string like `{"partial":"..."}` / `{"text":"..."}`; pull one field.
    private static func decode(field: String, json: UnsafePointer<CChar>?) -> String {
        guard let json = json else { return "" }
        let raw = String(cString: json)
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object[field] as? String else {
            return ""
        }
        return text
    }

    deinit {
        if let recognizer = self.recognizer {
            vosk_recognizer_free(recognizer)
        }
        if let model = self.model {
            vosk_model_free(model)
        }
    }
}
