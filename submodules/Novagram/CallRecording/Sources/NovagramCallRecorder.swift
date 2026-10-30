import Foundation
import AVFoundation
import CoreMedia
import CoreImage
import SwiftSignalKit

// Records one call into an AVAssetWriter: one AAC track (both sides mixed), plus an H.264 track for video calls.
// Timeline: the session starts at the first audio chunk (time zero); audio times come from the sample count,
// video times from the host clock relative to the same start. All writer state lives on `queue`; the audio tap
// only writes into the two rings, and the main thread only attaches, detaches and starts finishing.
final class NovagramCallRecorder {
    static let sampleRate = NovagramCallAudioMixer.outputSampleRate
    static let tickInterval: Double = 1.0 / 30.0
    static let audioBitRate = 128_000
    static let videoBitRate = 2_500_000
    static let videoFramesPerSecond = 30
    static let keyFrameInterval = 60
    static let fragmentInterval: Double = 2.0
    // A playout chunk this much later than the timeline expects means chunks were lost or playout stalled; the
    // hole is filled with the microphone alone so audio stays in sync with the host clock.
    static let gapThreshold: Double = 0.12
    // Without playout chunks for this long, the timeline keeps moving with the microphone alone, `staleLag` behind.
    static let staleThreshold: Double = 0.3
    static let staleLag: Double = 0.15
    // Microphone chunks alone start the session after this long without any playout chunk.
    static let micOnlyStartDelay: Double = 0.4
    static let commitFrames = NovagramCallRecorder.sampleRate / 10
    static let maxSilenceFillFrames = NovagramCallRecorder.sampleRate
    static let maxPendingAudioFrames = NovagramCallRecorder.sampleRate * 3
    // A video side without a new frame for this long counts as having no video (camera turned off).
    static let videoSideTimeout: Double = 4.0
    static let finishRetryCount = 50
    static let finishRetryMicroseconds: UInt32 = 10_000

    let tempURL: URL
    let folder: URL
    let isVideo: Bool
    // Main thread: told once when the writer fails on its own.
    var onFailure: ((NovagramCallRecordingError) -> Void)?

    let queue = DispatchQueue(label: "uz.novagram.call-recorder", qos: .userInitiated)
    private let micRing = NovagramCallAudioRing()
    private let playoutRing = NovagramCallAudioRing()

    private let writer: AVAssetWriter
    private let audioInput: AVAssetWriterInput
    private let videoInput: AVAssetWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let audioFormat: CMAudioFormatDescription

    // Main thread.
    private var setAudioTap: ((NovagramCallAudioTap?) -> Void)?
    private let disposables = DisposableSet()

    // Recorder queue.
    private let mixer = NovagramCallAudioMixer()
    private var timer: DispatchSourceTimer?
    private var isMuted = false
    private var startSeconds: Double?
    private var firstMicSeconds: Double?
    private var lastPlayoutSeconds: Double?
    private var framesWritten: Int64 = 0
    private var mixBuffer: [Int16] = []
    private var pendingAudio: [(buffer: CMSampleBuffer, frames: Int)] = []
    private var pendingAudioFrames = 0
    private var compositor: NovagramCallVideoCompositor?
    private var remote = VideoSide()
    private var local = VideoSide()
    private var lastVideoTime: CMTime = .invalid
    private var failure: NovagramCallRecordingError?
    private var isFinishing = false

    private struct VideoSide {
        let converter = NovagramCallVideoFrameConverter()
        var frame: NovagramCallVideoFrame?
        var frameSeconds: Double = 0
        var isDirty = false
        var image: CIImage?
    }

    init(tempURL: URL, folder: URL, isVideo: Bool) throws {
        self.tempURL = tempURL
        self.folder = folder
        self.isVideo = isVideo

        guard let audioFormat = NovagramCallRecorder.makeAudioFormat() else {
            throw NovagramCallRecordingError.writerFailed("audio format")
        }
        self.audioFormat = audioFormat
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: tempURL, fileType: isVideo ? .mp4 : .m4a)
        } catch {
            throw NovagramCallRecordingError.writerFailed(error.localizedDescription)
        }
        // Movie fragments keep the file playable up to the last fragment if the app is killed.
        writer.movieFragmentInterval = CMTime(seconds: NovagramCallRecorder.fragmentInterval, preferredTimescale: 600)

        if isVideo {
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: NovagramCallRecorder.videoSettings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else {
                throw NovagramCallRecordingError.writerFailed("video input")
            }
            writer.add(input)
            self.videoInput = input
            self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: NovagramCallVideoCompositor.width,
                kCVPixelBufferHeightKey as String: NovagramCallVideoCompositor.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ])
        } else {
            self.videoInput = nil
            self.adaptor = nil
        }

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: NovagramCallRecorder.sampleRate,
            AVNumberOfChannelsKey: NovagramCallAudioMixer.outputChannels,
            AVEncoderBitRateKey: NovagramCallRecorder.audioBitRate
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings, sourceFormatHint: audioFormat)
        audioInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(audioInput) else {
            throw NovagramCallRecordingError.writerFailed("audio input")
        }
        writer.add(audioInput)
        self.audioInput = audioInput

        guard writer.startWriting() else {
            throw NovagramCallRecordingError.writerFailed(NovagramCallRecorder.describe(writer.error, stage: "startWriting"))
        }
        self.writer = writer
    }

    deinit {
        self.timer?.cancel()
        self.disposables.dispose()
    }

    private static var videoSettings: [String: Any] {
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NovagramCallVideoCompositor.width,
            AVVideoHeightKey: NovagramCallVideoCompositor.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: NovagramCallRecorder.videoBitRate,
                AVVideoExpectedSourceFrameRateKey: NovagramCallRecorder.videoFramesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: NovagramCallRecorder.keyFrameInterval,
                // No B-frames: frames arrive with real-time timestamps and are cut into movie fragments; with
                // reordering, finishWriting failed about one time in four (-11800, underlying -16341).
                AVVideoAllowFrameReorderingKey: false,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]
    }

    private static func makeAudioFormat() -> CMAudioFormatDescription? {
        let channels = UInt32(NovagramCallAudioMixer.outputChannels)
        let bytesPerFrame = UInt32(MemoryLayout<Int16>.size) * channels
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(NovagramCallRecorder.sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr else {
            return nil
        }
        return format
    }

    // The closure the call's audio device runs on its real-time thread: copy into a ring and return.
    func makeAudioTap() -> NovagramCallAudioTap {
        let micRing = self.micRing
        let playoutRing = self.playoutRing
        return { samples, frames, channels, sampleRate, isPlayout in
            let hostTime = NovagramCallHostClock.now()
            if isPlayout {
                playoutRing.write(samples, frames: frames, channels: channels, sampleRate: sampleRate, hostTime: hostTime)
            } else {
                micRing.write(samples, frames: frames, channels: channels, sampleRate: sampleRate, hostTime: hostTime)
            }
        }
    }

    // MARK: - Main thread

    func attach(_ source: NovagramCallRecordingSource) {
        self.setAudioTap = source.setAudioTap
        source.setAudioTap(self.makeAudioTap())
        self.disposables.add(source.isMuted.start(next: { [weak self] isMuted in
            self?.queue.async {
                self?.isMuted = isMuted
            }
        }))
        if self.isVideo {
            if let incoming = source.incomingFrames {
                self.disposables.add(incoming.start(next: { [weak self] frame in
                    self?.receive(frame, isRemote: true)
                }))
            }
            if let outgoing = source.outgoingFrames {
                self.disposables.add(outgoing.start(next: { [weak self] frame in
                    self?.receive(frame, isRemote: false)
                }))
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: self.queue)
        timer.schedule(deadline: .now() + NovagramCallRecorder.tickInterval, repeating: NovagramCallRecorder.tickInterval, leeway: .milliseconds(5))
        timer.setEventHandler(handler: { [weak self] in
            self?.tick()
        })
        self.queue.async {
            self.timer = timer
            timer.resume()
        }
    }

    // Removes the tap and the video subscriptions. Safe to call more than once.
    func detach() {
        if let setAudioTap = self.setAudioTap {
            self.setAudioTap = nil
            setAudioTap(nil)
        }
        self.disposables.dispose()
    }

    // MARK: - Recorder queue

    private func receive(_ frame: NovagramCallVideoFrame, isRemote: Bool) {
        let seconds = NovagramCallHostClock.seconds(NovagramCallHostClock.now())
        self.queue.async {
            if isRemote {
                self.remote.frame = frame
                self.remote.frameSeconds = seconds
                self.remote.isDirty = true
            } else {
                self.local.frame = frame
                self.local.frameSeconds = seconds
                self.local.isDirty = true
            }
        }
    }

    private func tick() {
        guard !self.isFinishing, self.failure == nil else {
            return
        }
        self.drainAudio(final: false)
        if self.isVideo, self.startSeconds != nil {
            self.writeVideoFrame()
        }
        self.checkWriter()
    }

    private func startSession(at seconds: Double) {
        guard self.writer.status == .writing else {
            return
        }
        self.startSeconds = seconds
        self.writer.startSession(atSourceTime: .zero)
        // Microphone audio captured before the start would play late; drop it.
        if let firstMic = self.firstMicSeconds, firstMic < seconds {
            self.mixer.discardMic(frames: Int((seconds - firstMic) * Double(NovagramCallRecorder.sampleRate)))
        }
    }

    private var producedFrames: Int64 {
        return self.framesWritten + Int64(self.mixBuffer.count / NovagramCallAudioMixer.outputChannels)
    }

    private func drainAudio(final: Bool) {
        let isMuted = self.isMuted
        self.micRing.consume { chunk in
            if self.firstMicSeconds == nil {
                self.firstMicSeconds = NovagramCallHostClock.seconds(chunk.hostTime)
            }
            self.mixer.pushMic(chunk.samples, frames: chunk.frames, channels: chunk.channels, sampleRate: chunk.sampleRate, isMuted: isMuted)
        }
        self.playoutRing.consume { chunk in
            let chunkSeconds = NovagramCallHostClock.seconds(chunk.hostTime)
            if self.startSeconds == nil {
                self.startSession(at: chunkSeconds)
            }
            guard let start = self.startSeconds else {
                return
            }
            let expected = start + Double(self.producedFrames) / Double(NovagramCallRecorder.sampleRate)
            let gap = chunkSeconds - expected
            if gap > NovagramCallRecorder.gapThreshold {
                self.fillWithMicrophone(frames: Int(gap * Double(NovagramCallRecorder.sampleRate)))
            }
            self.mixer.mixPlayout(chunk.samples, frames: chunk.frames, channels: chunk.channels, sampleRate: chunk.sampleRate, output: &self.mixBuffer)
            self.lastPlayoutSeconds = chunkSeconds
            if self.mixBuffer.count >= NovagramCallRecorder.commitFrames * NovagramCallAudioMixer.outputChannels {
                self.commitMix()
            }
        }
        if !final {
            let now = NovagramCallHostClock.seconds(NovagramCallHostClock.now())
            if self.startSeconds == nil, let firstMic = self.firstMicSeconds, now - firstMic > NovagramCallRecorder.micOnlyStartDelay {
                self.startSession(at: firstMic)
            }
            if let start = self.startSeconds, now - (self.lastPlayoutSeconds ?? start) > NovagramCallRecorder.staleThreshold {
                let target = Int64((now - NovagramCallRecorder.staleLag - start) * Double(NovagramCallRecorder.sampleRate))
                let missing = target - self.producedFrames
                if missing > 0 {
                    self.fillWithMicrophone(frames: Int(missing))
                }
            }
        }
        self.commitMix()
    }

    // Moves the timeline forward with the microphone alone, one second at a time so memory stays bounded.
    private func fillWithMicrophone(frames: Int) {
        var remaining = frames
        while remaining > 0 {
            let count = min(remaining, NovagramCallRecorder.maxSilenceFillFrames)
            self.mixer.mixSilence(frames: count, output: &self.mixBuffer)
            self.commitMix()
            remaining -= count
        }
    }

    private func commitMix() {
        let frames = self.mixBuffer.count / NovagramCallAudioMixer.outputChannels
        guard frames > 0, self.startSeconds != nil else {
            return
        }
        let buffer = self.makeAudioSampleBuffer(self.mixBuffer, frames: frames, position: self.framesWritten)
        self.framesWritten += Int64(frames)
        self.mixBuffer.removeAll(keepingCapacity: true)
        guard let buffer else {
            return
        }
        self.pendingAudio.append((buffer, frames))
        self.pendingAudioFrames += frames
        while self.pendingAudioFrames > NovagramCallRecorder.maxPendingAudioFrames, !self.pendingAudio.isEmpty {
            self.pendingAudioFrames -= self.pendingAudio.removeFirst().frames
        }
        self.flushPendingAudio()
    }

    private func flushPendingAudio() {
        while !self.pendingAudio.isEmpty, self.writer.status == .writing, self.audioInput.isReadyForMoreMediaData {
            let item = self.pendingAudio.removeFirst()
            self.pendingAudioFrames -= item.frames
            if !self.audioInput.append(item.buffer) {
                break
            }
        }
    }

    private func makeAudioSampleBuffer(_ samples: [Int16], frames: Int, position: Int64) -> CMSampleBuffer? {
        let byteCount = samples.count * MemoryLayout<Int16>.size
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: byteCount, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &blockBuffer) == kCMBlockBufferNoErr, let blockBuffer else {
            return nil
        }
        let copied = samples.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress else {
                return kCMBlockBufferBadPointerParameterErr
            }
            return CMBlockBufferReplaceDataBytes(with: base, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)
        }
        guard copied == kCMBlockBufferNoErr else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        let time = CMTime(value: position, timescale: CMTimeScale(NovagramCallRecorder.sampleRate))
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, formatDescription: self.audioFormat, sampleCount: frames, presentationTimeStamp: time, packetDescriptions: nil, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        return sampleBuffer
    }

    private func currentImage(_ side: inout VideoSide, now: Double) -> CIImage? {
        guard side.frame != nil, now - side.frameSeconds < NovagramCallRecorder.videoSideTimeout else {
            side.frame = nil
            side.image = nil
            side.isDirty = false
            return nil
        }
        if side.isDirty, let frame = side.frame {
            side.isDirty = false
            // A frame that cannot be converted keeps the previous picture.
            if let image = side.converter.image(for: frame) {
                side.image = image
            }
        }
        return side.image
    }

    private func writeVideoFrame() {
        guard let videoInput = self.videoInput, let adaptor = self.adaptor, let start = self.startSeconds, self.writer.status == .writing, videoInput.isReadyForMoreMediaData else {
            return
        }
        let now = NovagramCallHostClock.seconds(NovagramCallHostClock.now())
        // The first picture is at zero so the video track has no empty edit at its start.
        let time = self.lastVideoTime.isValid ? CMTime(seconds: max(0, now - start), preferredTimescale: 90000) : .zero
        if self.lastVideoTime.isValid, time <= self.lastVideoTime {
            return
        }
        let remoteImage = self.currentImage(&self.remote, now: now)
        let localImage = self.currentImage(&self.local, now: now)
        guard let pool = adaptor.pixelBufferPool else {
            return
        }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess, let pixelBuffer else {
            return
        }
        let compositor: NovagramCallVideoCompositor
        if let current = self.compositor {
            compositor = current
        } else {
            compositor = NovagramCallVideoCompositor()
            self.compositor = compositor
        }
        compositor.render(remote: remoteImage, local: localImage, into: pixelBuffer)
        if adaptor.append(pixelBuffer, withPresentationTime: time) {
            self.lastVideoTime = time
        }
    }

    private func checkWriter() {
        guard self.writer.status == .failed else {
            return
        }
        self.fail(.writerFailed(NovagramCallRecorder.describe(self.writer.error, stage: "recording")))
    }

    // The writer failed on its own: stop, keep what the movie fragments saved, and tell the center.
    private func fail(_ error: NovagramCallRecordingError) {
        guard self.failure == nil, !self.isFinishing else {
            return
        }
        self.failure = error
        self.timer?.cancel()
        self.timer = nil
        self.salvage()
        DispatchQueue.main.async {
            self.onFailure?(error)
        }
    }

    private func salvage() {
        let size = (try? self.tempURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > 0 {
            _ = try? NovagramCallRecordingStorage.moveIntoPlace(self.tempURL, folder: self.folder, duration: nil)
        } else {
            try? FileManager.default.removeItem(at: self.tempURL.deletingLastPathComponent())
        }
    }

    // Finishes the file and moves it into the folder. `completion` runs on the recorder queue, exactly once.
    func finish(completion: @escaping (Result<URL, NovagramCallRecordingError>) -> Void) {
        self.queue.async {
            guard !self.isFinishing else {
                completion(.failure(.cancelled))
                return
            }
            if let failure = self.failure {
                self.isFinishing = true
                completion(.failure(failure))
                return
            }
            self.isFinishing = true
            self.timer?.cancel()
            self.timer = nil
            self.drainAudio(final: true)
            guard self.startSeconds != nil, self.framesWritten > 0, self.writer.status == .writing else {
                if self.writer.status == .writing {
                    self.writer.cancelWriting()
                }
                try? FileManager.default.removeItem(at: self.tempURL.deletingLastPathComponent())
                completion(.failure(self.writer.status == .failed ? .writerFailed(NovagramCallRecorder.describe(self.writer.error, stage: "stopping")) : .nothingRecorded))
                return
            }
            var retries = 0
            while !self.pendingAudio.isEmpty, retries < NovagramCallRecorder.finishRetryCount, self.writer.status == .writing {
                self.flushPendingAudio()
                if !self.pendingAudio.isEmpty {
                    usleep(NovagramCallRecorder.finishRetryMicroseconds)
                }
                retries += 1
            }
            self.audioInput.markAsFinished()
            self.videoInput?.markAsFinished()
            let audioDuration = Double(self.framesWritten) / Double(NovagramCallRecorder.sampleRate)
            let videoDuration = self.lastVideoTime.isValid ? self.lastVideoTime.seconds + NovagramCallRecorder.tickInterval : 0
            let duration = max(audioDuration, videoDuration)
            self.writer.finishWriting {
                self.queue.async {
                    self.completeFinishing(duration: duration, completion: completion)
                }
            }
        }
    }

    // "<stage>: <domain> <code> <description> (underlying <domain> <code>)", so a failure report says what broke.
    static func describe(_ error: Error?, stage: String) -> String {
        guard let error = error as NSError? else {
            return "\(stage): unknown error"
        }
        var text = "\(stage): \(error.domain) \(error.code) \(error.localizedDescription)"
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += " (underlying \(underlying.domain) \(underlying.code))"
        }
        return text
    }

    private func completeFinishing(duration: Double, completion: (Result<URL, NovagramCallRecordingError>) -> Void) {
        guard self.writer.status == .completed else {
            self.salvage()
            completion(.failure(.writerFailed(NovagramCallRecorder.describe(self.writer.error, stage: "finishing"))))
            return
        }
        do {
            let url = try NovagramCallRecordingStorage.moveIntoPlace(self.tempURL, folder: self.folder, duration: duration)
            completion(.success(url))
        } catch {
            completion(.failure(.writerFailed(error.localizedDescription)))
        }
    }
}
