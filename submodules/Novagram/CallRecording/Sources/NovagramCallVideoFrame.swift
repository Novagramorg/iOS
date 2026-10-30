import Foundation
import CoreVideo
import CoreImage
import Accelerate
import TelegramVoip

// One call video frame, reduced to what the recorder needs: the picture and how the call screen shows it.
struct NovagramCallVideoFrame {
    enum Buffer {
        case pixelBuffer(CVPixelBuffer)
        case nv12(width: Int, height: Int, y: Data, strideY: Int, uv: Data, strideUV: Int)
        case i420(width: Int, height: Int, y: Data, strideY: Int, u: Data, strideU: Int, v: Data, strideV: Int)
    }

    let buffer: Buffer
    // Clockwise quarter turns, applied after the mirroring, as the call screen applies them.
    let rotationQuarterTurns: Int
    let mirrorHorizontally: Bool
    let mirrorVertically: Bool

    init(buffer: Buffer, rotationQuarterTurns: Int, mirrorHorizontally: Bool, mirrorVertically: Bool) {
        self.buffer = buffer
        self.rotationQuarterTurns = ((rotationQuarterTurns % 4) + 4) % 4
        self.mirrorHorizontally = mirrorHorizontally
        self.mirrorVertically = mirrorVertically
    }

    // Same rotation and mirroring as AdaptedCallVideoSource in CallControllerNodeV2 (TelegramCallsUI) for a
    // portrait screen held in portrait, so the recording shows what the call screen shows.
    init(_ data: OngoingGroupCallContext.VideoFrameData) {
        let buffer: Buffer
        switch data.buffer {
        case let .native(native), let .argb(native), let .bgra(native):
            buffer = .pixelBuffer(native.pixelBuffer)
        case let .nv12(nv12):
            buffer = .nv12(width: nv12.width, height: nv12.height, y: nv12.y, strideY: nv12.strideY, uv: nv12.uv, strideUV: nv12.strideUV)
        case let .i420(i420):
            buffer = .i420(width: i420.width, height: i420.height, y: i420.y, strideY: i420.strideY, u: i420.u, strideU: i420.strideU, v: i420.v, strideV: i420.strideV)
        }
        let orientation = data.deviceRelativeOrientation ?? data.orientation
        var mirrorHorizontally = data.mirrorHorizontally
        var mirrorVertically = data.mirrorVertically
        if let deviceRelativeOrientation = data.deviceRelativeOrientation, deviceRelativeOrientation != data.orientation {
            let shouldMirror = data.mirrorHorizontally || data.mirrorVertically
            switch deviceRelativeOrientation {
            case .rotation0, .rotation180:
                mirrorHorizontally = shouldMirror
                mirrorVertically = false
            case .rotation90, .rotation270:
                mirrorHorizontally = false
                mirrorVertically = shouldMirror
            }
        }
        self.init(buffer: buffer, rotationQuarterTurns: NovagramCallVideoFrame.quarterTurns(orientation), mirrorHorizontally: mirrorHorizontally, mirrorVertically: mirrorVertically)
    }

    static func quarterTurns(_ orientation: OngoingCallVideoOrientation) -> Int {
        switch orientation {
        case .rotation0:
            return 0
        case .rotation90:
            return 1
        case .rotation180:
            return 2
        case .rotation270:
            return 3
        }
    }
}

// Turns frames into upright CIImages. NV12 and I420 planes are copied into full-range 4:2:0 pixel buffers (the
// format the call screen converts them to). Used on the recorder queue only; one converter per video side.
final class NovagramCallVideoFrameConverter {
    private var pool: CVPixelBufferPool?
    private var poolWidth = 0
    private var poolHeight = 0

    func image(for frame: NovagramCallVideoFrame) -> CIImage? {
        let pixelBuffer: CVPixelBuffer
        switch frame.buffer {
        case let .pixelBuffer(buffer):
            pixelBuffer = buffer
        case let .nv12(width, height, y, strideY, uv, strideUV):
            guard let buffer = self.makeBuffer(width: width, height: height), NovagramCallVideoFrameConverter.copyNV12(width: width, height: height, y: y, strideY: strideY, uv: uv, strideUV: strideUV, into: buffer) else {
                return nil
            }
            pixelBuffer = buffer
        case let .i420(width, height, y, strideY, u, strideU, v, strideV):
            guard let buffer = self.makeBuffer(width: width, height: height), NovagramCallVideoFrameConverter.copyI420(width: width, height: height, y: y, strideY: strideY, u: u, strideU: strideU, v: v, strideV: strideV, into: buffer) else {
                return nil
            }
            pixelBuffer = buffer
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard !image.extent.isEmpty else {
            return nil
        }
        return NovagramCallVideoFrameConverter.orient(image, quarterTurns: frame.rotationQuarterTurns, mirrorHorizontally: frame.mirrorHorizontally, mirrorVertically: frame.mirrorVertically)
    }

    static func orient(_ image: CIImage, quarterTurns: Int, mirrorHorizontally: Bool, mirrorVertically: Bool) -> CIImage {
        return image.transformed(by: NovagramCallVideoFrameConverter.orientation(extent: image.extent, quarterTurns: quarterTurns, mirrorHorizontally: mirrorHorizontally, mirrorVertically: mirrorVertically))
    }

    // Mirror first (the call screen mirrors the texture), then rotate clockwise as seen on screen, then move the
    // result back to the origin. Core Image's y axis points up, so a clockwise turn on screen is a negative angle.
    static func orientation(extent: CGRect, quarterTurns: Int, mirrorHorizontally: Bool, mirrorVertically: Bool) -> CGAffineTransform {
        let mirror = CGAffineTransform(
            a: mirrorHorizontally ? -1 : 1, b: 0,
            c: 0, d: mirrorVertically ? -1 : 1,
            tx: mirrorHorizontally ? extent.maxX + extent.minX : 0,
            ty: mirrorVertically ? extent.maxY + extent.minY : 0
        )
        let rotation: CGAffineTransform
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1:
            rotation = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0)
        case 2:
            rotation = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
        case 3:
            rotation = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0)
        default:
            rotation = .identity
        }
        let turned = mirror.concatenating(rotation)
        let moved = extent.applying(turned)
        return turned.concatenating(CGAffineTransform(translationX: -moved.minX, y: -moved.minY))
    }

    private func makeBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        guard width > 0, height > 0 else {
            return nil
        }
        if self.pool == nil || self.poolWidth != width || self.poolHeight != height {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
            var pool: CVPixelBufferPool?
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess else {
                return nil
            }
            self.pool = pool
            self.poolWidth = width
            self.poolHeight = height
        }
        guard let pool = self.pool else {
            return nil
        }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess, let buffer else {
            return nil
        }
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, .shouldPropagate)
        return buffer
    }

    private static func copyPlane(_ source: Data, sourceStride: Int, rowBytes: Int, rows: Int, buffer: CVPixelBuffer, plane: Int) -> Bool {
        guard let destination = CVPixelBufferGetBaseAddressOfPlane(buffer, plane), sourceStride >= rowBytes, source.count >= sourceStride * (rows - 1) + rowBytes else {
            return false
        }
        let destinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
        guard destinationStride >= rowBytes else {
            return false
        }
        source.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else {
                return
            }
            for row in 0 ..< rows {
                memcpy(destination + row * destinationStride, base + row * sourceStride, rowBytes)
            }
        }
        return true
    }

    static func copyNV12(width: Int, height: Int, y: Data, strideY: Int, uv: Data, strideUV: Int, into buffer: CVPixelBuffer) -> Bool {
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
            return false
        }
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        let chromaWidth = (width + 1) / 2
        let chromaHeight = (height + 1) / 2
        return copyPlane(y, sourceStride: strideY, rowBytes: width, rows: height, buffer: buffer, plane: 0) && copyPlane(uv, sourceStride: strideUV, rowBytes: chromaWidth * 2, rows: chromaHeight, buffer: buffer, plane: 1)
    }

    static func copyI420(width: Int, height: Int, y: Data, strideY: Int, u: Data, strideU: Int, v: Data, strideV: Int, into buffer: CVPixelBuffer) -> Bool {
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
            return false
        }
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        guard copyPlane(y, sourceStride: strideY, rowBytes: width, rows: height, buffer: buffer, plane: 0), let destinationUV = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
            return false
        }
        let chromaWidth = (width + 1) / 2
        let chromaHeight = (height + 1) / 2
        guard strideU >= chromaWidth, strideV >= chromaWidth, u.count >= strideU * (chromaHeight - 1) + chromaWidth, v.count >= strideV * (chromaHeight - 1) + chromaWidth else {
            return false
        }
        let destinationStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        // Interleaves U and V into the CbCr plane with vImage (a per-pixel Swift loop is far too slow at -Onone).
        let status: vImage_Error = u.withUnsafeBytes { rawU -> vImage_Error in
            v.withUnsafeBytes { rawV -> vImage_Error in
                guard let baseU = rawU.baseAddress, let baseV = rawV.baseAddress else {
                    return vImage_Error(kvImageNullPointerArgument)
                }
                var planeU = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: baseU), height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: strideU)
                var planeV = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: baseV), height: vImagePixelCount(chromaHeight), width: vImagePixelCount(chromaWidth), rowBytes: strideV)
                return withUnsafePointer(to: &planeU) { pointerU in
                    withUnsafePointer(to: &planeV) { pointerV in
                        var sources: [UnsafePointer<vImage_Buffer>?] = [pointerU, pointerV]
                        var destinations: [UnsafeMutableRawPointer?] = [destinationUV, destinationUV + 1]
                        return vImageConvert_PlanarToChunky8(&sources, &destinations, 2, 2, vImagePixelCount(chromaWidth), vImagePixelCount(chromaHeight), destinationStride, vImage_Flags(kvImageNoFlags))
                    }
                }
            }
        }
        return status == kvImageNoError
    }
}
