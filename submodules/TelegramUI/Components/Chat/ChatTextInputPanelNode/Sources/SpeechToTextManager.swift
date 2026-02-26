import Foundation
import Speech
import AVFoundation

public final class SpeechToTextManager {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "uz-UZ"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    public var onTextUpdate: ((String) -> Void)?
    public var onStop: (() -> Void)?
    
    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    public init() {
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
            print("audioSession properties weren't set because of an error.")
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.startRecordingEngine()
                } else {
                    print("Speech authorization failed: \(authStatus)")
                    self.stopRecording()
                }
            }
        }
    }
    
    private func startRecordingEngine() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
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
            print("audioEngine couldn't start because of an error: \(error)")
        }
        
        self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            if let result = result {
                self.onTextUpdate?(result.bestTranscription.formattedString)
            }
            if let error = error {
                print("Speech recognition error: \(error)")
                self.stopRecording()
            } else if result?.isFinal == true {
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
        onStop?()
    }
}
