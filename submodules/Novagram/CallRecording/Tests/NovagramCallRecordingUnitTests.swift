import XCTest
import CoreImage
import CoreVideo
import Metal
@testable import NovagramCallRecording

final class NovagramCallRecordingStorageTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        super.setUp()
        self.folder = FileManager.default.temporaryDirectory.appendingPathComponent("call-recording-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.folder)
        super.tearDown()
    }

    private func date() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 30
        components.hour = 14
        components.minute = 5
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    func testFileNameSanitizesSlashesAndColons() {
        let name = NovagramCallRecordingStorage.fileName(peerName: " A/B: C ", date: self.date(), isVideo: true, in: self.folder)
        XCTAssertEqual(name, "A-B- C 2026-10-30 14.05.mp4")
        let voice = NovagramCallRecordingStorage.fileName(peerName: "Ali", date: self.date(), isVideo: false, in: self.folder)
        XCTAssertEqual(voice, "Ali 2026-10-30 14.05.m4a")
        let empty = NovagramCallRecordingStorage.fileName(peerName: "   ", date: self.date(), isVideo: false, in: self.folder)
        XCTAssertEqual(empty, "Novagram call 2026-10-30 14.05.m4a")
    }

    func testFileNameAppendsNumberWhenTaken() throws {
        let first = NovagramCallRecordingStorage.fileName(peerName: "Ali", date: self.date(), isVideo: true, in: self.folder)
        XCTAssertEqual(first, "Ali 2026-10-30 14.05.mp4")
        try Data([1]).write(to: self.folder.appendingPathComponent(first))
        let second = NovagramCallRecordingStorage.fileName(peerName: "Ali", date: self.date(), isVideo: true, in: self.folder)
        XCTAssertEqual(second, "Ali 2026-10-30 14.05 2.mp4")
        try Data([1]).write(to: self.folder.appendingPathComponent(second))
        let third = NovagramCallRecordingStorage.fileName(peerName: "Ali", date: self.date(), isVideo: true, in: self.folder)
        XCTAssertEqual(third, "Ali 2026-10-30 14.05 3.mp4")
        // The voice name is separate from the video one.
        XCTAssertEqual(NovagramCallRecordingStorage.fileName(peerName: "Ali", date: self.date(), isVideo: false, in: self.folder), "Ali 2026-10-30 14.05.m4a")
    }

    func testListIsNewestFirstAndSkipsOtherFiles() throws {
        let older = self.folder.appendingPathComponent("old.m4a")
        let newer = self.folder.appendingPathComponent("new.mp4")
        try Data([1, 2, 3]).write(to: older)
        try Data([1, 2, 3, 4]).write(to: newer)
        try Data([1]).write(to: self.folder.appendingPathComponent("notes.txt"))
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 1000)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 2000)], ofItemAtPath: newer.path)
        NovagramCallRecordingStorage.storeDuration(12.5, of: newer)

        let list = NovagramCallRecordingStorage.list(in: self.folder)
        XCTAssertEqual(list.map { $0.url.lastPathComponent }, ["new.mp4", "old.m4a"])
        XCTAssertEqual(list.first?.isVideo, true)
        XCTAssertEqual(list.first?.duration, 12.5)
        XCTAssertEqual(list.first?.size, 4)
        XCTAssertEqual(list.last?.isVideo, false)
    }

    func testInterruptedRecordingIsMovedIntoFolder() throws {
        let partial = self.folder.appendingPathComponent(".partial/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try Data([1, 2]).write(to: partial.appendingPathComponent("Ali 2026-10-30 14.05.mp4"))
        NovagramCallRecordingStorage.recoverInterrupted(in: self.folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.folder.appendingPathComponent("Ali 2026-10-30 14.05.mp4").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
    }
}

final class NovagramCallAudioMixerTests: XCTestCase {
    private func mixPlayout(_ mixer: NovagramCallAudioMixer, _ samples: [Int16], channels: Int = 1, sampleRate: UInt32) -> [Int16] {
        var output: [Int16] = []
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return
            }
            mixer.mixPlayout(base, frames: samples.count / channels, channels: channels, sampleRate: sampleRate, output: &output)
        }
        return output
    }

    private func pushMic(_ mixer: NovagramCallAudioMixer, _ samples: [Int16], channels: Int = 1, sampleRate: UInt32, isMuted: Bool = false) {
        samples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return
            }
            mixer.pushMic(base, frames: samples.count / channels, channels: channels, sampleRate: sampleRate, isMuted: isMuted)
        }
    }

    private func left(_ stereo: [Int16]) -> [Int16] {
        return stride(from: 0, to: stereo.count, by: 2).map { stereo[$0] }
    }

    func testMixesBothSidesAt48k() {
        let mixer = NovagramCallAudioMixer()
        self.pushMic(mixer, [Int16](repeating: 1000, count: 480), sampleRate: 48000)
        let output = self.mixPlayout(mixer, [Int16](repeating: 2000, count: 480), sampleRate: 48000)
        XCTAssertEqual(output.count, 960)
        XCTAssertTrue(output.allSatisfy { $0 == 3000 })
    }

    func testPassesThroughExactSamplesAt48k() {
        let mixer = NovagramCallAudioMixer()
        let mic: [Int16] = (0 ..< 480).map { Int16($0) }
        let playout: [Int16] = (0 ..< 480).map { Int16($0 * 2) }
        self.pushMic(mixer, mic, sampleRate: 48000)
        let output = self.mixPlayout(mixer, playout, sampleRate: 48000)
        XCTAssertEqual(self.left(output), (0 ..< 480).map { Int16($0 * 3) })
        // Both channels carry the same mono mix.
        XCTAssertEqual(stride(from: 1, to: output.count, by: 2).map { output[$0] }, self.left(output))
    }

    func testResamplesPlayoutFrom16k() {
        let mixer = NovagramCallAudioMixer()
        // A 16 kHz ramp of 30 per sample becomes a 48 kHz ramp of 10 per sample.
        let ramp: [Int16] = (0 ..< 160).map { Int16($0 * 30) }
        let output = self.left(self.mixPlayout(mixer, ramp, sampleRate: 16000))
        XCTAssertEqual(output.count, 3 * 160 - 2)
        XCTAssertEqual(output, (0 ..< output.count).map { Int16($0 * 10) })
        // The next chunk continues the ramp without a seam.
        let next: [Int16] = (160 ..< 320).map { Int16($0 * 30) }
        let continued = self.left(self.mixPlayout(mixer, next, sampleRate: 16000))
        XCTAssertEqual(continued.count, 480)
        XCTAssertEqual(continued, (output.count ..< output.count + 480).map { Int16($0 * 10) })
    }

    func testResamplesMicFrom16k() {
        let mixer = NovagramCallAudioMixer()
        self.pushMic(mixer, (0 ..< 160).map { Int16($0 * 30) }, sampleRate: 16000)
        XCTAssertEqual(mixer.bufferedMicFrames, 478)
        let output = self.left(self.mixPlayout(mixer, [Int16](repeating: 100, count: 478), sampleRate: 48000))
        XCTAssertEqual(output, (0 ..< 478).map { Int16($0 * 10 + 100) })
    }

    func testMutedMicContributesSilence() {
        let mixer = NovagramCallAudioMixer()
        self.pushMic(mixer, [Int16](repeating: 1000, count: 480), sampleRate: 48000, isMuted: true)
        XCTAssertEqual(mixer.bufferedMicFrames, 480)
        let output = self.mixPlayout(mixer, [Int16](repeating: 2000, count: 480), sampleRate: 48000)
        XCTAssertTrue(output.allSatisfy { $0 == 2000 })
    }

    func testMicUnderrunGivesZeros() {
        let mixer = NovagramCallAudioMixer()
        let silentMic = self.mixPlayout(mixer, [Int16](repeating: 2000, count: 480), sampleRate: 48000)
        XCTAssertTrue(silentMic.allSatisfy { $0 == 2000 })
        self.pushMic(mixer, [Int16](repeating: 1000, count: 100), sampleRate: 48000)
        let output = self.left(self.mixPlayout(mixer, [Int16](repeating: 0, count: 480), sampleRate: 48000))
        XCTAssertEqual(Array(output[0 ..< 100]), [Int16](repeating: 1000, count: 100))
        XCTAssertEqual(Array(output[100...]), [Int16](repeating: 0, count: 380))
        let silence = self.left({ () -> [Int16] in
            var result: [Int16] = []
            mixer.mixSilence(frames: 10, output: &result)
            return result
        }())
        XCTAssertEqual(silence, [Int16](repeating: 0, count: 10))
    }

    func testSumIsClipped() {
        let mixer = NovagramCallAudioMixer()
        self.pushMic(mixer, [30000, -30000], sampleRate: 48000)
        let output = self.left(self.mixPlayout(mixer, [30000, -30000], sampleRate: 48000))
        XCTAssertEqual(output, [Int16.max, Int16.min])
    }

    func testStereoInputIsDownmixed() {
        let mixer = NovagramCallAudioMixer()
        let output = self.left(self.mixPlayout(mixer, [1000, 3000, -1000, -3000], channels: 2, sampleRate: 48000))
        XCTAssertEqual(output, [2000, -2000])
    }

    func testRingSplitsLargeChunksAndKeepsOrder() {
        let ring = NovagramCallAudioRing(slotCount: 4, slotCapacity: 8)
        let samples: [Int16] = (0 ..< 20).map { Int16($0) }
        samples.withUnsafeBufferPointer { buffer in
            ring.write(buffer.baseAddress!, frames: 10, channels: 2, sampleRate: 48000, hostTime: 7)
        }
        var collected: [Int16] = []
        ring.consume { chunk in
            XCTAssertEqual(chunk.channels, 2)
            XCTAssertEqual(chunk.hostTime, 7)
            collected.append(contentsOf: UnsafeBufferPointer(start: chunk.samples, count: chunk.frames * chunk.channels))
        }
        XCTAssertEqual(collected, samples)
        // A full ring drops what does not fit instead of waiting.
        let many: [Int16] = [Int16](repeating: 1, count: 80)
        many.withUnsafeBufferPointer { buffer in
            ring.write(buffer.baseAddress!, frames: 80, channels: 1, sampleRate: 48000, hostTime: 0)
        }
        var frames = 0
        ring.consume { chunk in
            frames += chunk.frames
        }
        XCTAssertEqual(frames, 32)
        XCTAssertEqual(ring.droppedChunks, 1)
    }
}

final class NovagramCallVideoTests: XCTestCase {
    // Maps the centre of a pixel through the orientation transform; (x, y) are counted from the top, as on screen.
    private func orientedPixel(_ x: Int, _ y: Int, width: Int, height: Int, turns: Int, mirrorH: Bool, mirrorV: Bool) -> (Int, Int, CGSize) {
        let extent = CGRect(x: 0, y: 0, width: width, height: height)
        let transform = NovagramCallVideoFrameConverter.orientation(extent: extent, quarterTurns: turns, mirrorHorizontally: mirrorH, mirrorVertically: mirrorV)
        let size = extent.applying(transform)
        // Core Image's y axis points up.
        let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(height - 1 - y) + 0.5).applying(transform)
        return (Int(point.x.rounded(.down)), Int(size.height) - 1 - Int(point.y.rounded(.down)), CGSize(width: size.width, height: size.height))
    }

    // The call screen draws the frame mirrored, then rotates the layer clockwise by the frame's orientation.
    func testOrientationMatchesCallScreen() {
        let cases: [(turns: Int, mirrorH: Bool, mirrorV: Bool, size: CGSize, topLeftGoesTo: (Int, Int))] = [
            (0, false, false, CGSize(width: 4, height: 2), (0, 0)),
            (1, false, false, CGSize(width: 2, height: 4), (1, 0)),
            (2, false, false, CGSize(width: 4, height: 2), (3, 1)),
            (3, false, false, CGSize(width: 2, height: 4), (0, 3)),
            (0, true, false, CGSize(width: 4, height: 2), (3, 0)),
            (0, false, true, CGSize(width: 4, height: 2), (0, 1)),
            (1, true, false, CGSize(width: 2, height: 4), (1, 3)),
            (3, true, false, CGSize(width: 2, height: 4), (0, 0))
        ]
        for item in cases {
            let label = "turns \(item.turns) mirror \(item.mirrorH)/\(item.mirrorV)"
            let result = self.orientedPixel(0, 0, width: 4, height: 2, turns: item.turns, mirrorH: item.mirrorH, mirrorV: item.mirrorV)
            XCTAssertEqual(result.2, item.size, label)
            XCTAssertEqual(result.0, item.topLeftGoesTo.0, label)
            XCTAssertEqual(result.1, item.topLeftGoesTo.1, label)
            // The CIImage path uses the same transform and lands at the origin.
            let image = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 10, y: 20, width: 4, height: 2))
            let oriented = NovagramCallVideoFrameConverter.orient(image, quarterTurns: item.turns, mirrorHorizontally: item.mirrorH, mirrorVertically: item.mirrorV)
            XCTAssertEqual(oriented.extent, CGRect(origin: .zero, size: item.size), label)
        }
    }

    func testRotatedRemoteFillsPortraitFrame() {
        let canvas = NovagramCallVideoCompositor.canvas
        // A 640x360 frame turned a quarter is 360x640, the canvas's own aspect.
        let portrait = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 360, height: 640))
        XCTAssertEqual(NovagramCallVideoCompositor.place(portrait, in: canvas, fill: false).extent, canvas)
        // An upright landscape frame is letterboxed: full width, centred vertically.
        let landscape = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 360))
        let placed = NovagramCallVideoCompositor.place(landscape, in: canvas, fill: false).extent
        // Core Image rounds a fractional extent outwards, so allow one point.
        XCTAssertEqual(placed.width, 720, accuracy: 1)
        XCTAssertEqual(placed.height, 405, accuracy: 1)
        XCTAssertEqual(placed.midY, canvas.midY, accuracy: 1)
        let composed = NovagramCallVideoCompositor.compose(remote: landscape, local: portrait, background: CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: canvas))
        XCTAssertEqual(composed.extent, canvas)
    }

    func testI420IsInterleavedIntoNV12() throws {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &buffer)
        let pixelBuffer = try XCTUnwrap(buffer)
        let y = Data((0 ..< 16).map { UInt8($0) })
        let u = Data([10, 11, 12, 13])
        let v = Data([20, 21, 22, 23])
        XCTAssertTrue(NovagramCallVideoFrameConverter.copyI420(width: 4, height: 4, y: y, strideY: 4, u: u, strideU: 2, v: v, strideV: 2, into: pixelBuffer))
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        let yBase = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)).assumingMemoryBound(to: UInt8.self)
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        XCTAssertEqual(yBase[yStride + 1], 5)
        let uvBase = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)).assumingMemoryBound(to: UInt8.self)
        let uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: uvBase, count: 4)), [10, 20, 11, 21])
        XCTAssertEqual(Array(UnsafeBufferPointer(start: uvBase + uvStride, count: 4)), [12, 22, 13, 23])
    }

    func testPictureInPictureSitsTopRight() {
        let rect = NovagramCallVideoCompositor.pipRect(for: CGSize(width: 480, height: 640))
        XCTAssertEqual(rect.maxX, CGFloat(NovagramCallVideoCompositor.width) - NovagramCallVideoCompositor.pipMargin)
        XCTAssertEqual(rect.maxY, CGFloat(NovagramCallVideoCompositor.height) - NovagramCallVideoCompositor.pipMargin)
        XCTAssertEqual(rect.width, (720 * 0.28).rounded())
        XCTAssertEqual(rect.height, (rect.width * 640 / 480).rounded())
    }

    func testPictureInPictureFollowsTheFourCorners() {
        let size = CGSize(width: 480, height: 640)
        let width = CGFloat(NovagramCallVideoCompositor.width)
        let height = CGFloat(NovagramCallVideoCompositor.height)
        let margin = NovagramCallVideoCompositor.pipMargin
        // Core Image is y up: the top of the picture is the high y.
        let topLeft = NovagramCallVideoCompositor.pipRect(for: size, corner: .topLeft)
        XCTAssertEqual(topLeft.minX, margin)
        XCTAssertEqual(topLeft.maxY, height - margin)
        let topRight = NovagramCallVideoCompositor.pipRect(for: size, corner: .topRight)
        XCTAssertEqual(topRight.maxX, width - margin)
        XCTAssertEqual(topRight.maxY, height - margin)
        XCTAssertEqual(topRight, NovagramCallVideoCompositor.pipRect(for: size), "top-right stays the default")
        let bottomLeft = NovagramCallVideoCompositor.pipRect(for: size, corner: .bottomLeft)
        XCTAssertEqual(bottomLeft.minX, margin)
        XCTAssertEqual(bottomLeft.minY, margin)
        let bottomRight = NovagramCallVideoCompositor.pipRect(for: size, corner: .bottomRight)
        XCTAssertEqual(bottomRight.maxX, width - margin)
        XCTAssertEqual(bottomRight.minY, margin)
        for rect in [topLeft, bottomLeft, bottomRight] {
            XCTAssertEqual(rect.size, topRight.size, "only the position changes")
        }
    }

    func testSwapPutsOurVideoBig() {
        let normal = NovagramCallVideoCompositor.arrange(remote: "remote", local: "local", isSwapped: false)
        XCTAssertEqual(normal.main, "remote")
        XCTAssertEqual(normal.pip, "local")
        let swapped = NovagramCallVideoCompositor.arrange(remote: "remote", local: "local", isSwapped: true)
        XCTAssertEqual(swapped.main, "local")
        XCTAssertEqual(swapped.pip, "remote")
        // A lone side always fills the frame, swapped or not.
        for isSwapped in [false, true] {
            let remoteOnly = NovagramCallVideoCompositor.arrange(remote: "remote", local: nil, isSwapped: isSwapped)
            XCTAssertEqual(remoteOnly.main, "remote")
            XCTAssertNil(remoteOnly.pip)
            let localOnly = NovagramCallVideoCompositor.arrange(remote: nil, local: "local", isSwapped: isSwapped)
            XCTAssertEqual(localOnly.main, "local")
            XCTAssertNil(localOnly.pip)
        }
    }

    // Swapped with the pip bottom-left: our picture fills the frame and the other side's sits in that corner.
    func testComposeUsesLayout() {
        let canvas = NovagramCallVideoCompositor.canvas
        let background = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: canvas)
        let remote = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        let local = CIImage(color: CIColor(red: 0, green: 1, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 720, height: 1280))
        let layout = NovagramCallVideoLayout(pipCorner: .bottomLeft, isSwapped: true)
        let composed = NovagramCallVideoCompositor.compose(remote: remote, local: local, layout: layout, background: background)
        XCTAssertEqual(composed.extent, canvas)
        let pip = NovagramCallVideoCompositor.pipRect(for: remote.extent.size, corner: .bottomLeft)
        XCTAssertEqual(pip.minX, NovagramCallVideoCompositor.pipMargin)
        XCTAssertEqual(pip.minY, NovagramCallVideoCompositor.pipMargin)
        XCTAssertLessThan(pip.height, pip.width, "the pip keeps the landscape remote's aspect")
    }
}
