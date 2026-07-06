import Foundation
import Speech
import TelegramAudio
import SwiftSignalKit
import AVFoundation
import FenixuzVosk

public final class SpeechToTextManager {
    private enum Backend {
        case apple
        case vosk
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioSessionDisposable: Any?
    private var isStopping = false

    // Offline backend (Vosk), engaged only for languages Apple can't recognise (e.g. Uzbek).
    // The Apple state above is untouched; these are used only when `backend == .vosk`.
    private var backend: Backend = .apple
    private var voskRecognizer: VoskSpeechRecognizer?
    private var voskConverter: AVAudioConverter?
    private var voskOutputFormat: AVAudioFormat?
    private var voskModelDownloadTask: Task<Void, Never>?
    private let voskQueue = DispatchQueue(label: "fenixuz.vosk.recognizer")

    public var onTextUpdate: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((String) -> Void)?

    /// Optional handler injected by the caller to translate final transcriptions.
    /// Signature: (rawText, targetLangCode, completion(translatedText)) -> Void
    /// When nil, the raw transcription is emitted unchanged.
    /// On any failure the handler must call completion with the original rawText so the
    /// user never receives an empty insert.
    public var translateHandler: ((String, String, @escaping (String) -> Void) -> Void)?

    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    /// The language the user asked for. May be unsupported by Apple (e.g. Uzbek), in which case
    /// `speechRecognizer` is nil and startRecording() reports a clear, actionable message.
    private var requestedLocaleId: String = "en-US"

    public init() {
        let savedLocale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        self.requestedLocaleId = savedLocale
        // nil when Apple ships no recognizer for this language (e.g. Uzbek). We do NOT silently
        // substitute en-US — that recognises the spoken language as garbage/empty with no error.
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: savedLocale))
        // Route Uzbek (and any other Vosk-only language) to the offline backend, and start
        // fetching its model now so it's ready by the time the user records.
        self.backend = VoskLanguage.isVoskOnly(savedLocale) ? .vosk : .apple
        if self.backend == .vosk {
            self.ensureVoskModel(for: savedLocale)
        }
    }

    public func updateLocale(_ localeId: String) {
        if audioEngine.isRunning {
            stopRecording()
        }
        self.requestedLocaleId = localeId
        // nil for languages Apple does not support — no silent language swap; startRecording()
        // surfaces a clear message so the user knows to pick a supported language.
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        self.backend = VoskLanguage.isVoskOnly(localeId) ? .vosk : .apple
        if self.backend == .vosk {
            // Download-on-selection: fetch the model the moment the user picks the language.
            self.ensureVoskModel(for: localeId)
        } else {
            // Leaving a Vosk language — drop the loaded model to free memory.
            self.voskRecognizer = nil
        }
    }

    public func toggleRecording() {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isStopping = false

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        if self.backend == .vosk {
            // Vosk is offline and needs no Speech-recognition authorization — only the mic,
            // which the system prompts for when the audio engine starts (same as the Apple path).
            self.startRecordingEngine()
            return
        }

        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startRecordingEngine()
                case .denied:
                    self.onError?("Ovozni aniqlash ruxsati berilmagan. Sozlamalardan yoqing.")
                    self.onStop?()
                case .restricted:
                    self.onError?("Bu qurilmada ovozni aniqlash cheklangan.")
                    self.onStop?()
                case .notDetermined:
                    self.onError?("Ovozni aniqlash ruxsati kutilmoqda.")
                    self.onStop?()
                @unknown default:
                    self.onStop?()
                }
            }
        }
    }

    private func startRecordingEngine() {
        if self.backend == .vosk {
            self.startVoskRecording()
            return
        }
        guard let speechRecognizer = self.speechRecognizer else {
            // Apple has no speech recogniser for this language at all (e.g. Uzbek).
            let langName = SpeechToTextManager.languageName(for: self.requestedLocaleId)
            self.onError?("«\(langName)» tili ovozdan-matnga aylantirishni qo'llab-quvvatlamaydi. Sozlamalar → Novagram → Ovoz tili dan qo'llab-quvvatlanadigan til (masalan, Ruscha) tanlang.")
            self.onStop?()
            return
        }
        guard speechRecognizer.isAvailable else {
            self.onError?("Ovozdan-matnga xizmati hozir mavjud emas. Internet aloqasini tekshirib, qayta urinib ko'ring.")
            self.onStop?()
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            self.onError?("Ovozni aniqlash so'rovini yaratib bo'lmadi.")
            self.onStop?()
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }

        let setupAndStartEngine = { [weak self] in
            guard let self = self else { return }

            let inputNode = self.audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                self.onError?("Audio format noto'g'ri: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
                self.onStop?()
                return
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
                self.recognitionRequest?.append(buffer)
            }

            self.audioEngine.prepare()

            do {
                try self.audioEngine.start()
            } catch {
                self.onError?("Audio engine ishga tushmadi: \(error.localizedDescription)")
                self.onStop?()
                return
            }

            self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] (result, error) in
                guard let self = self else { return }

                if self.isStopping {
                    return
                }

                if let result = result {
                    let transcribed = result.bestTranscription.formattedString

                    if result.isFinal {
                        // Final result: optionally translate before emitting, then clean up.
                        self.emitFinalText(transcribed)
                    } else {
                        // Partial result: emit raw text immediately for live preview.
                        self.onTextUpdate?(transcribed)
                    }
                }

                if let error = error {
                    let nsError = error as NSError
                    // Ignore errors caused by intentional stop/cancel or unavailable service
                    // 7 = Speech recognition not available for this locale
                    // 1110 = No speech detected (normal when stopping)
                    // 216 = Operation cancelled
                    // 209 = Recognition cancelled
                    // 301 = Request was cancelled
                    let ignoredCodes: Set<Int> = [7, 1110, 216, 209, 301]
                    if !ignoredCodes.contains(nsError.code) {
                        self.onError?("Xato \(nsError.code): \(error.localizedDescription)")
                    }
                    self.cleanupRecording()
                }
            })
        }

        if let sharedManagedAudioSession = sharedManagedAudioSession {
            let disposable = sharedManagedAudioSession.push(
                audioSessionType: .record(speaker: false, video: false, withOthers: false),
                once: false,
                activate: { _ in
                    DispatchQueue.main.async {
                        setupAndStartEngine()
                    }
                },
                deactivate: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.stopRecording()
                    }
                    return .single(Void())
                }
            )
            self.audioSessionDisposable = disposable
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            setupAndStartEngine()
        }
    }

    public func stopRecording() {
        if self.backend == .vosk {
            self.stopVoskRecording()
            return
        }
        isStopping = true

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        if let disposable = self.audioSessionDisposable as? SwiftSignalKit.Disposable {
            disposable.dispose()
            self.audioSessionDisposable = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? audioSession.setActive(true)

        onStop?()
    }

    /// Reads the voice-translate flag and target lang from UserDefaults (same suite as the rest
    /// of the module), then either translates via the injected handler or emits raw text.
    /// Always calls cleanupRecording() once the text has been emitted.
    private func emitFinalText(_ rawText: String) {
        let ud = UserDefaults(suiteName: "pro_messager")
        let voiceTranslateOn = ud?.bool(forKey: "voice_translate_enabled") ?? false

        guard voiceTranslateOn, let handler = translateHandler, !rawText.isEmpty else {
            // Feature is off, no handler wired, or nothing was transcribed — emit as-is.
            onTextUpdate?(rawText)
            cleanupRecording()
            return
        }

        // Resolve target language: saved auto_translate_lang > "en"
        let savedLang = ud?.string(forKey: "auto_translate_lang") ?? ""
        let targetLang = savedLang.isEmpty ? "en" : savedLang

        handler(rawText, targetLang) { [weak self] translatedText in
            guard let self = self else { return }
            // handler guarantees a non-empty string on failure (falls back to rawText)
            self.onTextUpdate?(translatedText)
            self.cleanupRecording()
        }
    }

    /// Internal cleanup without triggering onStop (used when recognition ends naturally)
    private func cleanupRecording() {
        isStopping = true

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil

        if let disposable = self.audioSessionDisposable as? SwiftSignalKit.Disposable {
            disposable.dispose()
            self.audioSessionDisposable = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? audioSession.setActive(true)

        onStop?()
    }

    // MARK: - Vosk (offline) backend

    /// Kick off the model download for a Vosk language if it isn't already cached. Safe to
    /// call repeatedly — it no-ops while a download is in flight or the model is already present.
    private func ensureVoskModel(for localeId: String) {
        guard let modelName = VoskLanguage.modelName(for: localeId) else {
            return
        }
        if VoskModelManager.isModelReady(modelName) {
            return
        }
        if self.voskModelDownloadTask != nil {
            return
        }
        self.voskModelDownloadTask = Task { @MainActor [weak self] in
            _ = try? await VoskModelManager.ensureModel(modelName)
            self?.voskModelDownloadTask = nil
        }
    }

    private func startVoskRecording() {
        guard let modelName = VoskLanguage.modelName(for: self.requestedLocaleId) else {
            self.onError?("Ovoz tili modeli topilmadi.")
            self.onStop?()
            return
        }
        guard VoskModelManager.isModelReady(modelName) else {
            self.onError?("«O'zbekcha» modeli hali yuklanmoqda. Internetga ulanib, bir oz kutib qayta urinib ko'ring.")
            self.onStop?()
            self.ensureVoskModel(for: self.requestedLocaleId)
            return
        }
        let modelPath = VoskModelManager.modelPath(modelName)

        // Loading the model (vosk_model_new) reads ~49 MB and builds the decode graph, so do it
        // off the main thread, then start the audio engine back on main.
        self.voskQueue.async { [weak self] in
            guard let self = self else { return }
            let recognizer: VoskSpeechRecognizer
            do {
                recognizer = try VoskSpeechRecognizer(modelPath: modelPath)
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Ovoz aniqlovchini ishga tushirib bo'lmadi.")
                    self.onStop?()
                }
                return
            }
            DispatchQueue.main.async {
                guard !self.isStopping else { return }
                self.voskRecognizer = recognizer
                self.startVoskAudioSession()
            }
        }
    }

    private func startVoskAudioSession() {
        let setupAndStartEngine = { [weak self] in
            guard let self = self else { return }

            let inputNode = self.audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                self.onError?("Audio format noto'g'ri: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
                self.onStop?()
                return
            }

            // Vosk's Uzbek model is trained at 16 kHz mono — convert the mic input to match.
            guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true),
                  let converter = AVAudioConverter(from: recordingFormat, to: outFormat) else {
                self.onError?("Audio konversiyani sozlab bo'lmadi.")
                self.onStop?()
                return
            }
            self.voskOutputFormat = outFormat
            self.voskConverter = converter

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.feedVosk(inputBuffer: buffer)
            }

            self.audioEngine.prepare()

            do {
                try self.audioEngine.start()
            } catch {
                self.onError?("Audio engine ishga tushmadi: \(error.localizedDescription)")
                self.onStop?()
            }
        }

        if let sharedManagedAudioSession = sharedManagedAudioSession {
            let disposable = sharedManagedAudioSession.push(
                audioSessionType: .record(speaker: false, video: false, withOthers: false),
                once: false,
                activate: { _ in
                    DispatchQueue.main.async {
                        setupAndStartEngine()
                    }
                },
                deactivate: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.stopRecording()
                    }
                    return .single(Void())
                }
            )
            self.audioSessionDisposable = disposable
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            setupAndStartEngine()
        }
    }

    /// Convert one mic buffer to 16 kHz mono Int16 (cheap, on the audio thread), then feed the
    /// copied samples to Vosk on the serial queue (the heavy decode stays off the audio thread).
    private func feedVosk(inputBuffer buffer: AVAudioPCMBuffer) {
        guard let converter = self.voskConverter, let outFormat = self.voskOutputFormat else {
            return
        }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else {
            return
        }

        var consumed = false
        let status = converter.convert(to: outBuffer, error: nil) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, outBuffer.frameLength > 0, let channelData = outBuffer.int16ChannelData else {
            return
        }

        let count = Int(outBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: count))

        self.voskQueue.async { [weak self] in
            guard let self = self, let recognizer = self.voskRecognizer else { return }
            let isFinalUtterance = samples.withUnsafeBufferPointer { pointer -> Bool in
                guard let base = pointer.baseAddress else { return false }
                return recognizer.acceptWaveform(base, count: count)
            }
            let text = isFinalUtterance ? recognizer.finalText() : recognizer.partialText()
            guard !text.isEmpty else { return }
            DispatchQueue.main.async {
                guard !self.isStopping else { return }
                self.onTextUpdate?(text)
            }
        }
    }

    private func stopVoskRecording() {
        guard !isStopping else { return }
        isStopping = true

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Flush remaining audio and pull the final transcription on the serial queue, then reuse
        // the shared emit + cleanup path (translation, audio-session pop, onStop).
        self.voskQueue.async { [weak self] in
            guard let self = self else { return }
            let finalText = self.voskRecognizer?.finalText() ?? ""
            DispatchQueue.main.async {
                self.voskRecognizer = nil
                self.voskConverter = nil
                self.voskOutputFormat = nil
                if finalText.isEmpty {
                    self.cleanupRecording()
                } else {
                    self.emitFinalText(finalText)
                }
            }
        }
    }

    public static var currentLanguageName: String {
        let locale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        return SpeechToTextManager.languageName(for: locale)
    }

    public static func languageName(for localeId: String) -> String {
        for lang in supportedLanguages {
            if lang.id == localeId {
                return lang.name
            }
        }
        return localeId
    }

    public static let supportedLanguages: [(id: String, name: String)] = [
        ("uz-UZ", "O'zbekcha"),
        ("en-US", "🇬🇧 English"),
        ("ru-RU", "🇷🇺 Русский"),
        ("tr-TR", "🇹🇷 Türkçe"),
        ("de-DE", "🇩🇪 Deutsch"),
        ("fr-FR", "🇫🇷 Français"),
        ("es-ES", "🇪🇸 Español"),
        ("it-IT", "🇮🇹 Italiano"),
        ("pt-BR", "🇧🇷 Português"),
        ("ar-SA", "🇸🇦 العربية"),
        ("zh-CN", "🇨🇳 中文"),
        ("ja-JP", "🇯🇵 日本語"),
        ("ko-KR", "🇰🇷 한국어"),
        ("hi-IN", "🇮🇳 हिन्दी"),
        ("nl-NL", "🇳🇱 Nederlands"),
        ("pl-PL", "🇵🇱 Polski"),
        ("sv-SE", "🇸🇪 Svenska"),
        ("da-DK", "🇩🇰 Dansk"),
        ("fi-FI", "🇫🇮 Suomi"),
        ("nb-NO", "🇳🇴 Norsk"),
        ("uk-UA", "🇺🇦 Українська"),
        ("cs-CZ", "🇨🇿 Čeština"),
        ("el-GR", "🇬🇷 Ελληνικά"),
        ("ro-RO", "🇷🇴 Română"),
        ("hu-HU", "🇭🇺 Magyar"),
        ("sk-SK", "🇸🇰 Slovenčina"),
        ("hr-HR", "🇭🇷 Hrvatski"),
        ("ca-ES", "🇪🇸 Català"),
        ("vi-VN", "🇻🇳 Tiếng Việt"),
        ("ms-MY", "🇲🇾 Bahasa Melayu"),
        ("id-ID", "🇮🇩 Bahasa Indonesia"),
        ("th-TH", "🇹🇭 ไทย"),
        ("he-IL", "🇮🇱 עברית"),
        ("en-GB", "🇬🇧 English (UK)"),
        ("en-AU", "🇦🇺 English (AU)"),
        ("fr-CA", "🇨🇦 Français (CA)"),
        ("es-MX", "🇲🇽 Español (MX)"),
        ("zh-TW", "🇹🇼 中文 (繁體)"),
        ("pt-PT", "🇵🇹 Português (PT)")
    ]
}
