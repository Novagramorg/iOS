import Foundation
import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import LocalMediaResources
import MediaEditor

// Fenixuz: pick a regular video from the photo library and send it as a round video note
// (the circular "instant video" message). Mirrors how VideoMessageCameraScreen builds a
// round note — MediaEditorValues(.videoMessage) + LocalFileVideoMediaResource + the
// .instantRoundVideo flag — but feeds it a gallery video cropped to a centered square.
// PHPicker + UTType are iOS 14+, so the feature is gated to iOS 14 (isEnabled is false below that).
public final class FenixRoundVideoFromGallery {
    private static let defaultsSuite = "pro_messager"
    private static let enabledKey = "round_video_from_gallery"

    // NovagramPro toggle — default ON, but only on iOS 14+ where PHPicker exists.
    public static var isEnabled: Bool {
        if #available(iOS 14.0, *) {
            return UserDefaults(suiteName: defaultsSuite)?.object(forKey: enabledKey) as? Bool ?? true
        }
        return false
    }

    // PHPickerViewController holds its delegate weakly, so keep it alive for the picker's lifetime.
    // Type-erased to NSObject to avoid an @available annotation on a stored property.
    private static var activeDelegate: NSObject?

    public static func present(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, from parentController: ViewController) {
        guard #available(iOS 14.0, *) else {
            return
        }

        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        let delegate = PickerDelegate(context: context, peerId: peerId, threadId: threadId)
        picker.delegate = delegate
        activeDelegate = delegate

        guard let window = parentController.view.window else {
            activeDelegate = nil
            return
        }
        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        presenter?.present(picker, animated: true)
    }

    fileprivate static func clearDelegate() {
        activeDelegate = nil
    }

    fileprivate static func sendAsRoundVideo(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, videoPath: String) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        guard let track = asset.tracks(withMediaType: .video).first else {
            return
        }

        let transformedSize = track.naturalSize.applying(track.preferredTransform)
        let width = abs(transformedSize.width)
        let height = abs(transformedSize.height)
        guard width > 0.0, height > 0.0 else {
            return
        }

        // Centered square crop turns any rectangular video into a circle-ready square.
        let side = min(width, height)
        let cropRect = CGRect(x: (width - side) / 2.0, y: (height - side) / 2.0, width: side, height: side)

        let totalDuration = CMTimeGetSeconds(asset.duration)
        let maxDuration = 60.0
        let finalDuration = min(totalDuration, maxDuration)
        let trimRange: Range<Double>? = totalDuration > maxDuration ? 0.0 ..< maxDuration : nil

        let originalDimensions = PixelDimensions(width: Int32(width), height: Int32(height))

        let values = MediaEditorValues(
            peerId: context.account.peerId,
            originalDimensions: originalDimensions,
            cropOffset: .zero,
            cropRect: cropRect,
            cropScale: 1.0,
            cropRotation: 0.0,
            cropMirroring: false,
            cropOrientation: nil,
            gradientColors: nil,
            videoTrimRange: trimRange,
            videoBounce: false,
            videoIsMuted: false,
            videoIsFullHd: false,
            videoIsMirrored: false,
            videoVolume: nil,
            additionalVideoPath: nil,
            additionalVideoIsDual: false,
            additionalVideoMirroringChanges: [],
            additionalVideoPosition: nil,
            additionalVideoScale: nil,
            additionalVideoRotation: nil,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: nil,
            maskDrawing: nil,
            entities: [],
            toolValues: [:],
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: .videoMessage
        )

        var resourceAdjustments: VideoMediaResourceAdjustments?
        if let valuesData = try? JSONEncoder().encode(values) {
            let data = EngineMemoryBuffer(data: valuesData)
            let digest = EngineMemoryBuffer(data: data.md5Digest())
            resourceAdjustments = VideoMediaResourceAdjustments(data: data, digest: digest, isStory: false)
        }

        let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: videoPath, adjustments: resourceAdjustments)

        let media = TelegramMediaFile(
            fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)),
            partialReference: nil,
            resource: resource,
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [
                .FileName(fileName: "video.mp4"),
                .Video(duration: finalDuration, size: PixelDimensions(width: 384, height: 384), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)
            ],
            alternativeRepresentations: []
        )

        let message: EnqueueMessage = .message(
            text: "",
            attributes: [],
            inlineStickers: [:],
            mediaReference: .standalone(media: media),
            threadId: threadId,
            replyToMessageId: nil,
            replyToStoryId: nil,
            localGroupingKey: nil,
            correlationId: nil,
            bubbleUpEmojiOrStickersets: []
        )

        _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).startStandalone()
    }
}

@available(iOS 14.0, *)
private final class PickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let threadId: Int64?

    init(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?) {
        self.context = context
        self.peerId = peerId
        self.threadId = threadId
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else {
            FenixRoundVideoFromGallery.clearDelegate()
            return
        }

        let context = self.context
        let peerId = self.peerId
        let threadId = self.threadId
        let typeIdentifier = UTType.movie.identifier

        _ = result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
            guard let url else {
                Queue.mainQueue().async {
                    FenixRoundVideoFromGallery.clearDelegate()
                }
                return
            }
            // The provided URL is a temporary file removed after this closure returns, so copy it out first.
            let destination = NSTemporaryDirectory() + "fenix_round_\(Int64.random(in: 0 ... Int64.max)).mp4"
            try? FileManager.default.removeItem(atPath: destination)
            do {
                try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destination))
            } catch {
                Queue.mainQueue().async {
                    FenixRoundVideoFromGallery.clearDelegate()
                }
                return
            }
            Queue.mainQueue().async {
                FenixRoundVideoFromGallery.sendAsRoundVideo(context: context, peerId: peerId, threadId: threadId, videoPath: destination)
                FenixRoundVideoFromGallery.clearDelegate()
            }
        }
    }
}
