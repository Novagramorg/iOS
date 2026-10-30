import XCTest
import AVFoundation
import CoreVideo
import Metal
@preconcurrency import SwiftSignalKit
@testable import NovagramCallRecording

// Stands in for OngoingCallContext.AudioDevice: keeps the tap the center installs.
private final class TapHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var tap: NovagramCallAudioTap?
    private(set) var setCount = 0

    func set(_ tap: NovagramCallAudioTap?) {
        self.lock.lock()
        self.tap = tap
        self.setCount += 1
        self.lock.unlock()
    }

    var current: NovagramCallAudioTap? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.tap
    }
}

final class NovagramCallRecordingEndToEndTests: XCTestCase {
    private static let seconds = 3.0
    private static let chunkSeconds = 0.01

    private func makeNV12Frame() -> NovagramCallVideoFrame {
        let width = 640
        let height = 360
        let y = Data(repeating: 150, count: width * height)
        let uv = Data(repeating: 100, count: width * height / 2)
        return NovagramCallVideoFrame(buffer: .nv12(width: width, height: height, y: y, strideY: width, uv: uv, strideUV: width), rotationQuarterTurns: 1, mirrorHorizontally: false, mirrorVertically: false)
    }

    private func makeNativeFrame() -> NovagramCallVideoFrame? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
        guard CVPixelBufferCreate(kCFAllocatorDefault, 360, 640, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 0x80, CVPixelBufferGetBytesPerRow(buffer) * 640)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return NovagramCallVideoFrame(buffer: .pixelBuffer(buffer), rotationQuarterTurns: 0, mirrorHorizontally: true, mirrorVertically: false)
    }

    // Feeds 10 ms chunks in real time from a background thread, like the audio device: 48 kHz playout and 16 kHz
    // microphone, plus a video frame on every third chunk.
    private func feed(_ holder: TapHolder, incoming: ValuePipe<NovagramCallVideoFrame>?, outgoing: ValuePipe<NovagramCallVideoFrame>?) async {
        let nv12 = self.makeNV12Frame()
        let native = self.makeNativeFrame()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let thread = Thread {
                let chunkCount = Int(NovagramCallRecordingEndToEndTests.seconds / NovagramCallRecordingEndToEndTests.chunkSeconds)
                var playout = [Int16](repeating: 0, count: 480)
                var mic = [Int16](repeating: 0, count: 160)
                let start = Date()
                for chunk in 0 ..< chunkCount {
                    let deadline = start.addingTimeInterval(Double(chunk) * NovagramCallRecordingEndToEndTests.chunkSeconds)
                    let wait = deadline.timeIntervalSinceNow
                    if wait > 0 {
                        usleep(UInt32(wait * 1_000_000))
                    }
                    for index in 0 ..< playout.count {
                        let time = Double(chunk * 480 + index) / 48000
                        playout[index] = Int16(8000 * sin(2 * Double.pi * 440 * time))
                    }
                    for index in 0 ..< mic.count {
                        let time = Double(chunk * 160 + index) / 16000
                        mic[index] = Int16(6000 * sin(2 * Double.pi * 300 * time))
                    }
                    if let tap = holder.current {
                        playout.withUnsafeBufferPointer { tap($0.baseAddress!, 480, 1, 48000, true) }
                        mic.withUnsafeBufferPointer { tap($0.baseAddress!, 160, 1, 16000, false) }
                    }
                    if chunk % 3 == 0 {
                        incoming?.putNext(nv12)
                        if let native {
                            outgoing?.putNext(native)
                        }
                    }
                }
                continuation.resume()
            }
            thread.qualityOfService = .userInteractive
            thread.start()
        }
    }

    @MainActor
    private func record(isVideo: Bool) async throws -> URL {
        let center = NovagramCallRecordingCenter.shared
        let holder = TapHolder()
        let incoming = ValuePipe<NovagramCallVideoFrame>()
        let outgoing = ValuePipe<NovagramCallVideoFrame>()
        let source = NovagramCallRecordingSource(
            peerName: "Test: Peer",
            setAudioTap: { holder.set($0) },
            incomingFrames: incoming.signal(),
            outgoingFrames: outgoing.signal(),
            isMuted: .single(false),
            isVideo: isVideo
        )
        let callId = UUID()
        var states: [NovagramCallRecordingState] = []
        let stateDisposable = center.state(callId: callId).start(next: { state in
            states.append(state)
        })
        defer {
            stateDisposable.dispose()
        }

        XCTAssertTrue(center.start(callId: callId, source: source))
        XCTAssertTrue(center.isRecording(callId: callId))
        XCTAssertFalse(center.start(callId: callId, source: source), "a second start for the same call is refused")
        XCTAssertNotNil(holder.current)

        await self.feed(holder, incoming: isVideo ? incoming : nil, outgoing: isVideo ? outgoing : nil)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, NovagramCallRecordingError>, Never>) in
            center.stop(callId: callId) { result in
                continuation.resume(returning: result)
            }
        }
        XCTAssertNil(holder.current, "stop removes the tap")
        XCTAssertFalse(center.isRecording(callId: callId))
        XCTAssertEqual(states.first, .idle)
        XCTAssertTrue(states.contains { if case .recording = $0 { return true } else { return false } })
        XCTAssertEqual(states.last, .idle)
        let url = try result.get()
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, NovagramCallRecordingStorage.directory.standardizedFileURL)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Test- Peer "))
        XCTAssertEqual(url.pathExtension, isVideo ? "mp4" : "m4a")
        return url
    }

    private func checkAudioTrack(_ asset: AVURLAsset) async throws {
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, NovagramCallRecordingEndToEndTests.seconds, accuracy: 0.3)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 1)
        let track = try XCTUnwrap(tracks.first)
        let formats = try await track.load(.formatDescriptions)
        let format = try XCTUnwrap(formats.first)
        let description = try XCTUnwrap(CMAudioFormatDescriptionGetStreamBasicDescription(format)).pointee
        XCTAssertEqual(description.mFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(description.mSampleRate, 48000)
        XCTAssertEqual(description.mChannelsPerFrame, 2)
        let trackDuration = try await track.load(.timeRange).duration.seconds
        XCTAssertEqual(trackDuration, NovagramCallRecordingEndToEndTests.seconds, accuracy: 0.3)
    }

    // RGB of one pixel, y counted from the top.
    private func pixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8)? {
        var pixels = [UInt8](repeating: 0, count: 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                return false
            }
            // Shift the image so the wanted pixel lands on the 1x1 bitmap.
            context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
            return true
        }
        return drawn ? (pixels[0], pixels[1], pixels[2]) : nil
    }

    @MainActor
    func testVoiceRecordingWritesAacFile() async throws {
        let url = try await self.record(isVideo: false)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let asset = AVURLAsset(url: url)
        try await self.checkAudioTrack(asset)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(videoTracks.count, 0)

        let listed = NovagramCallRecordingStorage.list().first { $0.url.standardizedFileURL == url.standardizedFileURL }
        XCTAssertNotNil(listed)
        XCTAssertEqual(listed?.isVideo, false)
        XCTAssertEqual(listed?.duration ?? 0, NovagramCallRecordingEndToEndTests.seconds, accuracy: 0.3)
        XCTAssertGreaterThan(listed?.size ?? 0, 0)
    }

    @MainActor
    func testVideoRecordingWritesH264AndAacFile() async throws {
        let url = try await self.record(isVideo: true)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let asset = AVURLAsset(url: url)
        try await self.checkAudioTrack(asset)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 720, height: 1280))
        let formats = try await track.load(.formatDescriptions)
        let format = try XCTUnwrap(formats.first)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(format), kCMVideoCodecType_H264)
        let videoDuration = try await track.load(.timeRange).duration.seconds
        XCTAssertEqual(videoDuration, NovagramCallRecordingEndToEndTests.seconds, accuracy: 0.3)
        let frameRate = try await track.load(.nominalFrameRate)
        XCTAssertGreaterThan(frameRate, 20)
        XCTAssertLessThanOrEqual(frameRate, 31)

        let listed = NovagramCallRecordingStorage.list().first { $0.url.standardizedFileURL == url.standardizedFileURL }
        XCTAssertEqual(listed?.isVideo, true)

        // The composed picture is not black: the other side (grey-green NV12) fills the frame and our own video
        // (grey) sits in the top-right corner.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        // Core Image renders nothing without a Metal device, and the Bazel test runner's simulator has none.
        guard #available(iOS 16.0, *), MTLCreateSystemDefaultDevice() != nil else {
            return
        }
        let image = try await generator.image(at: CMTime(seconds: 1.5, preferredTimescale: 600)).image
        XCTAssertEqual(image.width, 720)
        XCTAssertEqual(image.height, 1280)
        let center = try XCTUnwrap(self.pixel(image, x: 360, y: 640))
        XCTAssertGreaterThan(Int(center.0) + Int(center.1) + Int(center.2), 120, "centre \(center)")
        let pip = try XCTUnwrap(self.pixel(image, x: 720 - 24 - 100, y: 24 + 100))
        XCTAssertGreaterThan(Int(pip.0) + Int(pip.1) + Int(pip.2), 120, "picture-in-picture \(pip)")
        let corner = try XCTUnwrap(self.pixel(image, x: 4, y: 4))
        XCTAssertLessThan(Int(corner.0) + Int(corner.1) + Int(corner.2), 60, "letterbox \(corner)")
    }

    @MainActor
    func testStopWithoutRecordingIsCancelled() async {
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, NovagramCallRecordingError>, Never>) in
            NovagramCallRecordingCenter.shared.stop(callId: UUID()) { result in
                continuation.resume(returning: result)
            }
        }
        switch result {
        case .success:
            XCTFail("nothing was recording")
        case let .failure(error):
            XCTAssertEqual(error, .cancelled)
        }
    }

    @MainActor
    func testStopBeforeAnyAudioReportsNothingRecorded() async {
        let holder = TapHolder()
        let source = NovagramCallRecordingSource(peerName: "Empty", setAudioTap: { holder.set($0) }, incomingFrames: nil, outgoingFrames: nil, isMuted: .single(false), isVideo: false)
        let callId = UUID()
        XCTAssertTrue(NovagramCallRecordingCenter.shared.start(callId: callId, source: source))
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, NovagramCallRecordingError>, Never>) in
            NovagramCallRecordingCenter.shared.stop(callId: callId) { result in
                continuation.resume(returning: result)
            }
        }
        XCTAssertEqual(holder.setCount, 2)
        switch result {
        case .success:
            XCTFail("no audio was delivered")
        case let .failure(error):
            XCTAssertEqual(error, .nothingRecorded)
        }
    }
}
