import Foundation
import SwiftSignalKit
import TelegramVoip
import TelegramAudio
import DeviceProximity

public final class SharedCallAudioContext {
    private static weak var current: SharedCallAudioContext? 

    let audioDevice: OngoingCallContext.AudioDevice?
    let callKitIntegration: CallKitIntegration?
    
    private let defaultToSpeaker: Bool
    
    private var audioSessionDisposable: Disposable?
    private var audioSessionShouldBeActiveDisposable: Disposable?
    private var isAudioSessionActiveDisposable: Disposable?
    private var audioOutputStateDisposable: Disposable?
    
    private(set) var audioSessionControl: ManagedAudioSessionControl?
    
    private let isAudioSessionActivePromise = Promise<Bool>(false)
    private var isAudioSessionActive: Signal<Bool, NoError> {
        return self.isAudioSessionActivePromise.get()
    }
    
    private let audioOutputStatePromise = Promise<([AudioSessionOutput], AudioSessionOutput?)>(([], nil))
    private var audioOutputStateValue: ([AudioSessionOutput], AudioSessionOutput?) = ([], nil)
    public private(set) var currentAudioOutputValue: AudioSessionOutput = .builtin
    private var didSetCurrentAudioOutputValue: Bool = false
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
        return self.audioOutputStatePromise.get()
    }
    
    private let audioSessionShouldBeActive = Promise<Bool>(true)
    private var initialSetupTimer: Foundation.Timer?
    
    /// True between construction and the moment the speaker default has actually been applied.
    /// See `acceptReportedAudioOutput`.
    private var isInitialOutputPending: Bool = false
    
    private var proximityManagerIndex: Int?

    static func get(audioSession: ManagedAudioSession, callKitIntegration: CallKitIntegration?, defaultToSpeaker: Bool = false, reuseCurrent: Bool = false, enableMicrophone: Bool = true) -> SharedCallAudioContext {
        if let current = self.current, reuseCurrent {
            // The reused context was configured for the call that created it (a 1:1 audio call
            // defaults to the receiver), so without this the caller's defaultToSpeaker is dropped
            // and a group call silently inherits the earpiece.
            if defaultToSpeaker && !audioSession.getIsHeadsetPluggedIn() {
                current.switchToSpeakerIfBuiltin()
            }
            return current
        }
        let context = SharedCallAudioContext(audioSession: audioSession, callKitIntegration: callKitIntegration, defaultToSpeaker: defaultToSpeaker, enableMicrophone: enableMicrophone)
        self.current = context
        return context
    }
    
    private init(audioSession: ManagedAudioSession, callKitIntegration: CallKitIntegration?, defaultToSpeaker: Bool = false, enableMicrophone: Bool = true) {
        self.callKitIntegration = callKitIntegration
        
        // Align the shared WebRTC audio session configuration with the one ManagedAudioSession
        // installs for .voiceCall. When the two differ, the audio device module calls
        // setCategory:withOptions: as it starts, which resets overrideOutputAudioPort and drops the
        // call back to the receiver (and also loses mixWithOthers / allowBluetoothA2DP for the rest
        // of the call). CallKit calls got this via CallKitIntegration.reportIncomingCall; group
        // calls have no CallKit integration and were left with the stock configuration.
        // Streams pass enableMicrophone: false, which makes the device module skip the category
        // block entirely, so they need no alignment.
        if enableMicrophone {
            OngoingCallContext.setupSharedAudioSessionConfiguration()
        }
        
        self.audioDevice = OngoingCallContext.AudioDevice.create(enableSystemMute: false, enableMicrophone: enableMicrophone)
        
        var defaultToSpeaker = defaultToSpeaker
        if audioSession.getIsHeadsetPluggedIn() {
            defaultToSpeaker = false
        }
        
        self.defaultToSpeaker = defaultToSpeaker
        
        if defaultToSpeaker {
            self.didSetCurrentAudioOutputValue = true
            self.currentAudioOutputValue = .speaker
            self.isInitialOutputPending = true
        }
        
        var didReceiveAudioOutputs = false
        self.audioSessionDisposable = audioSession.push(audioSessionType: enableMicrophone ? .voiceCall : .play(mixWithOthers: true), manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                let previousControl = self.audioSessionControl
                self.audioSessionControl = control
                
                if previousControl == nil, let audioSessionControl = self.audioSessionControl {
                    if let callKitIntegration = self.callKitIntegration {
                        if self.didSetCurrentAudioOutputValue {
                            callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
                        }
                    } else {
                        audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
                        audioSessionControl.setup(synchronous: true)
                    }
                    
                    let audioSessionActive: Signal<Bool, NoError>
                    if let callKitIntegration = self.callKitIntegration {
                        audioSessionActive = callKitIntegration.audioSessionActive
                    } else {
                        audioSessionControl.activate({ _ in })
                        audioSessionActive = .single(true)
                    }
                    self.isAudioSessionActivePromise.set(audioSessionActive)
                    
                    self.initialSetupTimer?.invalidate()
                    let initialSetupTimer = Foundation.Timer(timeInterval: 0.5, repeats: false, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.isInitialOutputPending = false
                        
                        if self.defaultToSpeaker, let audioSessionControl = self.audioSessionControl {
                            self.currentAudioOutputValue = .speaker
                            self.didSetCurrentAudioOutputValue = true
                            
                            if let callKitIntegration = self.callKitIntegration {
                                if self.didSetCurrentAudioOutputValue {
                                    callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
                                }
                            } else {
                                audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
                                audioSessionControl.setup(synchronous: true)
                            }
                            
                            self.updateProximityMonitoring()
                        }
                    })
                    self.initialSetupTimer = initialSetupTimer
                    // Timer(timeInterval:repeats:block:) returns an *unscheduled* timer. Without
                    // adding it to a run loop it never fires, and this is the only code that
                    // re-applies the speaker default after the audio device module has started.
                    RunLoop.main.add(initialSetupTimer, forMode: .common)
                }
            }
        }, deactivate: { [weak self] _ in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let self {
                        self.isAudioSessionActivePromise.set(.single(false))
                        self.audioSessionControl = nil
                        self.isInitialOutputPending = false
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }, availableOutputsChanged: { [weak self] availableOutputs, currentOutput in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.audioOutputStateValue = (availableOutputs, currentOutput)
                if let currentOutput = currentOutput, self.acceptReportedAudioOutput(currentOutput) {
                    self.currentAudioOutputValue = currentOutput
                    self.didSetCurrentAudioOutputValue = true
                    self.updateProximityMonitoring()
                }
                
                var signal: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> = .single((availableOutputs, currentOutput))
                if !didReceiveAudioOutputs {
                    didReceiveAudioOutputs = true
                    if currentOutput == .speaker {
                        signal = .single((availableOutputs, .builtin))
                        |> then(
                            signal
                            |> delay(1.0, queue: Queue.mainQueue())
                        )
                    }
                }
                self.audioOutputStatePromise.set(signal)
            }
        })
        
        self.audioSessionShouldBeActive.set(.single(true))
        self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            if value {
                if let audioSessionControl = self.audioSessionControl {
                    let audioSessionActive: Signal<Bool, NoError>
                    if let callKitIntegration = self.callKitIntegration {
                        audioSessionActive = callKitIntegration.audioSessionActive
                    } else {
                        audioSessionControl.activate({ _ in })
                        audioSessionActive = .single(true)
                    }
                    self.isAudioSessionActivePromise.set(audioSessionActive)
                } else {
                    self.isAudioSessionActivePromise.set(.single(false))
                }
            } else {
                self.isAudioSessionActivePromise.set(.single(false))
            }
        })
        
        self.isAudioSessionActiveDisposable = (self.isAudioSessionActive
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            self.audioDevice?.setIsAudioSessionActive(value)
        })
        
        self.audioOutputStateDisposable = (self.audioOutputStatePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            self.audioOutputStateValue = value
            if let currentOutput = value.1, self.acceptReportedAudioOutput(currentOutput) {
                self.currentAudioOutputValue = currentOutput
                self.updateProximityMonitoring()
            }
        })
    }
    
    deinit {
        self.audioSessionDisposable?.dispose()
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.isAudioSessionActiveDisposable?.dispose()
        self.audioOutputStateDisposable?.dispose()
        self.initialSetupTimer?.invalidate()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
    }
    
    func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        self.initialSetupTimer?.invalidate()
        self.initialSetupTimer = nil
        self.isInitialOutputPending = false
        
        guard self.currentAudioOutputValue != output else {
            return
        }
        self.currentAudioOutputValue = output
        self.didSetCurrentAudioOutputValue = true
        
        self.audioOutputStatePromise.set(.single((self.audioOutputStateValue.0, output))
        |> then(
            .single(self.audioOutputStateValue)
            |> delay(1.0, queue: Queue.mainQueue())
        ))
        
        if let audioSessionControl = self.audioSessionControl {
            if let callKitIntegration = self.callKitIntegration {
                callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
            } else {
                audioSessionControl.setOutputMode(.custom(output))
            }
        }
    }
    
    public func switchToSpeakerIfBuiltin() {
        if case .builtin = self.currentAudioOutputValue {
            self.setCurrentAudioOutput(.speaker)
        }
    }
    
    /// The audio session reports the route as it was *before* the call configured it: the
    /// `availableOutputsChanged` hop that follows activation is queued ahead of the block that
    /// applies our output mode, and under the pre-call category `availableInputs` is nil, so the
    /// snapshot is always `.builtin`. While the speaker default is still pending that report says
    /// nothing about where audio will actually go, and accepting it would discard the default and
    /// switch on proximity monitoring. Any other route (headphones, bluetooth, a real speaker
    /// reading) is a genuine observation and ends the pending window.
    private func acceptReportedAudioOutput(_ output: AudioSessionOutput) -> Bool {
        if self.isInitialOutputPending {
            if case .builtin = output {
                return false
            }
            self.isInitialOutputPending = false
        }
        return true
    }
    
    private func updateProximityMonitoring() {
        var shouldMonitorProximity = false
        switch self.currentAudioOutputValue {
        case .builtin:
            shouldMonitorProximity = true
        default:
            break
        }
        
        if shouldMonitorProximity {
            if self.proximityManagerIndex == nil {
                self.proximityManagerIndex = DeviceProximityManager.shared().add { _ in
                }
            }
        } else {
            if let proximityManagerIndex = self.proximityManagerIndex {
                self.proximityManagerIndex = nil
                DeviceProximityManager.shared().remove(proximityManagerIndex)
            }
        }
    }
}
