import Foundation
import SwiftSignalKit
import TelegramVoip

// The tap installed on OngoingCallContext.AudioDevice.setAudioTap: pcm, frames, channels, sampleRate, isPlayout.
// It runs on the real-time audio thread.
public typealias NovagramCallAudioTap = (UnsafePointer<Int16>, Int, Int, UInt32, Bool) -> Void

public struct NovagramCallRecordingSource {
    let peerName: String
    let setAudioTap: (NovagramCallAudioTap?) -> Void
    let incomingFrames: Signal<NovagramCallVideoFrame, NoError>?
    let outgoingFrames: Signal<NovagramCallVideoFrame, NoError>?
    let isMuted: Signal<Bool, NoError>
    let isVideo: Bool

    // `isVideo`: decided by the caller at start (our or the other side's video is active). A voice recording
    // ignores the video signals.
    public init(
        peerName: String,
        setAudioTap: @escaping (NovagramCallAudioTap?) -> Void,
        incomingVideo: Signal<OngoingGroupCallContext.VideoFrameData, NoError>?,
        outgoingVideo: Signal<OngoingGroupCallContext.VideoFrameData, NoError>?,
        isMuted: Signal<Bool, NoError>,
        isVideo: Bool
    ) {
        self.init(
            peerName: peerName,
            setAudioTap: setAudioTap,
            incomingFrames: incomingVideo.flatMap { signal in signal |> map { NovagramCallVideoFrame($0) } },
            outgoingFrames: outgoingVideo.flatMap { signal in signal |> map { NovagramCallVideoFrame($0) } },
            isMuted: isMuted,
            isVideo: isVideo
        )
    }

    // Tests feed synthetic frames through this one (VideoFrameData has no public initializer).
    init(
        peerName: String,
        setAudioTap: @escaping (NovagramCallAudioTap?) -> Void,
        incomingFrames: Signal<NovagramCallVideoFrame, NoError>?,
        outgoingFrames: Signal<NovagramCallVideoFrame, NoError>?,
        isMuted: Signal<Bool, NoError>,
        isVideo: Bool
    ) {
        self.peerName = peerName
        self.setAudioTap = setAudioTap
        self.incomingFrames = incomingFrames
        self.outgoingFrames = outgoingFrames
        self.isMuted = isMuted
        self.isVideo = isVideo
    }
}

public enum NovagramCallRecordingState: Equatable {
    case idle
    // CFAbsoluteTimeGetCurrent() at start, for the REC mm:ss timer.
    case recording(startTimestamp: Double)
}

public enum NovagramCallRecordingError: Error, Equatable {
    case writerFailed(String)
    case nothingRecorded
    // stop() for a call that is not being recorded.
    case cancelled
}

// One process-wide registry of call recordings, keyed by the call's internal UUID.
// Main-thread API. The audio tap runs on the audio thread and the writer on each recorder's own queue.
public final class NovagramCallRecordingCenter {
    public static let shared = NovagramCallRecordingCenter()

    private static var didRecover = false

    private var recorders: [UUID: NovagramCallRecorder] = [:]
    // A recording whose writer failed on its own; its error is what the next stop() for that call returns.
    private var failures: [UUID: NovagramCallRecordingError] = [:]
    private var startTimestamps: [UUID: Double] = [:]
    private let startTimestampsPromise = ValuePromise<[UUID: Double]>([:], ignoreRepeated: true)

    init() {
        NovagramCallRecordingCenter.recoverInterruptedRecordingsOnce()
    }

    // Moves recordings a killed app left unfinished into the folder, once per process and before any recording
    // of this process starts.
    static func recoverInterruptedRecordingsOnce() {
        guard !NovagramCallRecordingCenter.didRecover else {
            return
        }
        NovagramCallRecordingCenter.didRecover = true
        NovagramCallRecordingStorage.recoverInterrupted(in: NovagramCallRecordingStorage.directory)
    }

    // Returns false if this call is already being recorded or the writer could not start.
    public func start(callId: UUID, source: NovagramCallRecordingSource) -> Bool {
        assert(Thread.isMainThread)
        guard self.recorders[callId] == nil else {
            return false
        }
        let folder = NovagramCallRecordingStorage.directory
        let fileName = NovagramCallRecordingStorage.fileName(peerName: source.peerName, date: Date(), isVideo: source.isVideo, in: folder)
        let partialFolder = NovagramCallRecordingStorage.partialDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let recorder: NovagramCallRecorder
        do {
            try FileManager.default.createDirectory(at: partialFolder, withIntermediateDirectories: true)
            recorder = try NovagramCallRecorder(tempURL: partialFolder.appendingPathComponent(fileName), folder: folder, isVideo: source.isVideo)
        } catch {
            try? FileManager.default.removeItem(at: partialFolder)
            return false
        }
        recorder.onFailure = { [weak self, weak recorder] error in
            guard let self, let recorder else {
                return
            }
            self.recorderDidFail(callId: callId, recorder: recorder, error: error)
        }
        self.failures[callId] = nil
        self.recorders[callId] = recorder
        recorder.attach(source)
        self.startTimestamps[callId] = CFAbsoluteTimeGetCurrent()
        self.startTimestampsPromise.set(self.startTimestamps)
        return true
    }

    // Removes the tap and the video subscriptions, finishes the file and moves it into the folder.
    // `completion` runs on the main queue.
    public func stop(callId: UUID, completion: @escaping (Result<URL, NovagramCallRecordingError>) -> Void) {
        assert(Thread.isMainThread)
        guard let recorder = self.recorders.removeValue(forKey: callId) else {
            let error = self.failures.removeValue(forKey: callId) ?? .cancelled
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }
        self.removeTimestamp(callId: callId)
        recorder.detach()
        recorder.finish { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    public func state(callId: UUID) -> Signal<NovagramCallRecordingState, NoError> {
        return self.startTimestampsPromise.get()
        |> map { timestamps -> NovagramCallRecordingState in
            if let timestamp = timestamps[callId] {
                return .recording(startTimestamp: timestamp)
            }
            return .idle
        }
        |> distinctUntilChanged
    }

    public func isRecording(callId: UUID) -> Bool {
        assert(Thread.isMainThread)
        return self.recorders[callId] != nil
    }

    // App termination path: stops every recording and finishes the files. `completion` runs once, when all files
    // are finished or after `timeout` seconds, on a background queue (never main), so a caller in
    // applicationWillTerminate may block the main thread waiting for it. Nothing here needs the main thread.
    // A file not finished in time stays in `.partial` and is moved into the folder on the next launch.
    public func stopAll(timeout: Double, completion: @escaping () -> Void) {
        assert(Thread.isMainThread)
        let recorders = Array(self.recorders.values)
        self.recorders.removeAll()
        self.startTimestamps.removeAll()
        self.startTimestampsPromise.set(self.startTimestamps)
        let callback = NovagramCallOnceCallback(completion)
        let group = DispatchGroup()
        for recorder in recorders {
            group.enter()
            recorder.detach()
            recorder.finish { _ in
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
            callback.call()
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + max(timeout, 0)) {
            callback.call()
        }
    }

    private func recorderDidFail(callId: UUID, recorder: NovagramCallRecorder, error: NovagramCallRecordingError) {
        guard let current = self.recorders[callId], current === recorder else {
            return
        }
        self.recorders[callId] = nil
        self.failures[callId] = error
        self.removeTimestamp(callId: callId)
        recorder.detach()
    }

    private func removeTimestamp(callId: UUID) {
        self.startTimestamps[callId] = nil
        self.startTimestampsPromise.set(self.startTimestamps)
    }
}

// Calls the wrapped closure at most once, from whichever thread gets there first.
private final class NovagramCallOnceCallback {
    private let lock = NSLock()
    private var callback: (() -> Void)?

    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    func call() {
        self.lock.lock()
        let callback = self.callback
        self.callback = nil
        self.lock.unlock()
        callback?()
    }
}
