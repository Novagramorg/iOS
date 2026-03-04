import Foundation
import Speech
import AVFoundation

public final class SpeechToTextManager {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    public var onTextUpdate: ((String) -> Void)?
    public var onStop: (() -> Void)?
    public var onError: ((String) -> Void)?
    
    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    public init() {
        let savedLocale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "uz-UZ"
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: savedLocale))
    }
    
    public func updateLocale(_ localeId: String) {
        if audioEngine.isRunning {
            stopRecording()
        }
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
    }
    
    public func toggleRecording() {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.onError?("Audio session xatolik: \(error.localizedDescription)")
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
            recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            self.onError?("Audio engine ishga tushmadi: \(error.localizedDescription)")
            self.onStop?()
            return
        }
        
        self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let result = result {
                self.onTextUpdate?(result.bestTranscription.formattedString)
                
                if result.isFinal {
                    self.stopRecording()
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Ignore "cancelled" errors (code 216 or 209)
                if nsError.code != 216 && nsError.code != 209 {
                    print("Speech recognition error: \(error)")
                }
                self.stopRecording()
            }
        })
    }
    
    public func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Restore audio session for normal playback
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? audioSession.setActive(true)
        
        onStop?()
    }
    
    public static var currentLanguageName: String {
        let locale = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "uz-UZ"
        return SpeechToTextManager.languageName(for: locale)
    }
    
    public static func languageName(for localeId: String) -> String {
        switch localeId {
        case "uz-UZ": return "🇺🇿 O'zbek"
        case "ru-RU": return "🇷🇺 Rus"
        case "en-US": return "🇬🇧 Ingliz"
        case "tr-TR": return "🇹🇷 Turk"
        case "de-DE": return "🇩🇪 Nemis"
        case "fr-FR": return "🇫🇷 Fransuz"
        case "es-ES": return "🇪🇸 Ispan"
        case "ar-SA": return "🇸🇦 Arab"
        case "zh-CN": return "🇨🇳 Xitoy"
        case "ja-JP": return "🇯🇵 Yapon"
        case "ko-KR": return "🇰🇷 Koreys"
        case "hi-IN": return "🇮🇳 Hind"
        case "pt-BR": return "🇧🇷 Portugaliya"
        case "it-IT": return "🇮🇹 Italyan"
        default: return localeId
        }
    }
    
    public static let supportedLanguages: [(id: String, name: String)] = [
        ("uz-UZ", "🇺🇿 O'zbek"),
        ("ru-RU", "🇷🇺 Rus"),
        ("en-US", "🇬🇧 Ingliz"),
        ("tr-TR", "🇹🇷 Turk"),
        ("de-DE", "🇩🇪 Nemis"),
        ("fr-FR", "🇫🇷 Fransuz"),
        ("es-ES", "🇪🇸 Ispan"),
        ("ar-SA", "🇸🇦 Arab"),
        ("zh-CN", "🇨🇳 Xitoy"),
        ("ja-JP", "🇯🇵 Yapon"),
        ("ko-KR", "🇰🇷 Koreys"),
        ("hi-IN", "🇮🇳 Hind"),
        ("pt-BR", "🇧🇷 Portugaliya"),
        ("it-IT", "🇮🇹 Italyan")
    ]
}
