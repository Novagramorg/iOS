import Foundation
import Speech
import TelegramAudio
import SwiftSignalKit
import AVFoundation

public final class SpeechToTextManager {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioSessionDisposable: Any?
    private var isStopping = false
    
    public var onTextUpdate: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((String) -> Void)?
    
    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    public init() {
        let savedLocale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: savedLocale))
        if recognizer?.isAvailable == true {
            self.speechRecognizer = recognizer
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }
    
    public func updateLocale(_ localeId: String) {
        if audioEngine.isRunning {
            stopRecording()
        }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        if recognizer?.isAvailable == true {
            self.speechRecognizer = recognizer
        } else {
            self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
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
        guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else {
            self.onError?("Tanlangan til uchun ovozni aniqlash mavjud emas.")
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
                    self.onTextUpdate?(result.bestTranscription.formattedString)
                    
                    if result.isFinal {
                        self.cleanupRecording()
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
        ("pt-PT", "🇵🇹 Português (PT)"),
    ]
}
