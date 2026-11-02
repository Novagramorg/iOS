import Foundation
import CoreVideo
import ImageIO
import TelegramVoip
import NovagramCallRecordingCore

extension CallRecordingVideoFrame {
    /// A call video frame for the recording SDK (HOOKS.md, "Call recording"), with the call screen's rotation and
    /// mirroring (`AdaptedCallVideoSource` in `CallControllerNodeV2`) for a portrait screen held in portrait.
    /// Stays in the app because it reads Telegram's types; it is the old core's `NovagramCallVideoFrame.init(_:)`.
    public init(telegram data: OngoingGroupCallContext.VideoFrameData) {
        let buffer: CallRecordingVideoFrame.Buffer
        switch data.buffer {
        case let .native(native), let .argb(native), let .bgra(native):
            buffer = .pixelBuffer(native.pixelBuffer)
        case let .nv12(nv12):
            buffer = .nv12(y: nv12.y, strideY: nv12.strideY, uv: nv12.uv, strideUV: nv12.strideUV, width: nv12.width, height: nv12.height)
        case let .i420(i420):
            buffer = .i420(y: i420.y, strideY: i420.strideY, u: i420.u, strideU: i420.strideU, v: i420.v, strideV: i420.strideV, width: i420.width, height: i420.height)
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
        self.init(buffer: buffer, rotationQuarterTurns: CallRecordingVideoFrame.quarterTurns(orientation), mirrorHorizontally: mirrorHorizontally, mirrorVertically: mirrorVertically)
    }

    /// Our shared screen as the broadcast extension hands it to the app (`IpcGroupCallBufferAppContext.frames`), turned
    /// the way the call sends it (`OngoingCallVideoCapturer.injectSampleBuffer`: left = 90, down = 180, right = 270).
    /// The screencast capturer's own `video()` never fires: tgcalls' custom capturer feeds only the call, not its
    /// output sinks.
    public init(screencast pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let quarterTurns: Int
        switch orientation {
        case .left:
            quarterTurns = 1
        case .down:
            quarterTurns = 2
        case .right:
            quarterTurns = 3
        default:
            quarterTurns = 0
        }
        self.init(buffer: .pixelBuffer(pixelBuffer), rotationQuarterTurns: quarterTurns)
    }

    private static func quarterTurns(_ orientation: OngoingCallVideoOrientation) -> Int {
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
