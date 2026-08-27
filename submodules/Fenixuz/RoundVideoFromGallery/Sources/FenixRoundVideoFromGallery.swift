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
import FenixuzLocalization

// Fenixuz: pick a regular video from the photo library and send it as a round video note
// (the circular "instant video" message). Mirrors how VideoMessageCameraScreen builds a
// round note — MediaEditorValues(.videoMessage) + LocalFileVideoMediaResource + the
// .instantRoundVideo flag — but feeds it a gallery video cropped to a centered square.
// PHPicker + UTType are iOS 14+, so the feature is gated to iOS 14 (isEnabled is false below that).
public final class FenixRoundVideoFromGallery {
    private static let defaultsSuite = "pro_messager"
    private static let enabledKey = "round_video_from_gallery"

    // NovagramPro toggle — opt-in, so a fresh install does not add the extra
    // "Photos" entry to the video-message menu until the user asks for it.
    public static var isEnabled: Bool {
        if #available(iOS 14.0, *) {
            return UserDefaults(suiteName: defaultsSuite)?.object(forKey: enabledKey) as? Bool ?? false
        }
        return false
    }

    // PHPickerViewController holds its delegate weakly, so keep it alive for the picker's lifetime.
    // Type-erased to NSObject to avoid an @available annotation on a stored property.
    private static var activeDelegate: NSObject?

    public static func present(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, replySubject: EngineMessageReplySubject?, from parentController: ViewController) {
        guard #available(iOS 14.0, *) else {
            return
        }

        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        let delegate = PickerDelegate(context: context, peerId: peerId, threadId: threadId, replySubject: replySubject, parentController: parentController)
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

    fileprivate static func sendAsRoundVideo(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, replySubject: EngineMessageReplySubject?, videoPath: String) {
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
            replyToMessageId: replySubject,
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
    private let replySubject: EngineMessageReplySubject?
    private weak var parentController: ViewController?

    init(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64?, replySubject: EngineMessageReplySubject?, parentController: ViewController?) {
        self.context = context
        self.peerId = peerId
        self.threadId = threadId
        self.replySubject = replySubject
        self.parentController = parentController
    }

    // Exporting the pick out of Photos can take several seconds — an iCloud-hosted video is
    // downloaded in full first, then copied out of the provider's temp file. The picker sheet is
    // already gone by then, so without this the user is left staring at the chat with nothing
    // happening until the round note suddenly appears.
    //
    // A plain spinner overlay was tried first and rejected: it showed no progress, and tapping
    // anywhere outside it silently cancelled the send. A UIAlertController is modal (a stray tap
    // cannot dismiss it), and the item provider hands us a real `Progress`, so show the actual
    // percentage with an explicit Cancel instead.
    private static func topPresenter(for parentController: ViewController?) -> UIViewController? {
        guard let window = parentController?.view.window else {
            return nil
        }
        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        return presenter
    }

    private static func presentProgressAlert(on parentController: ViewController?, title: String, text: String, cancelTitle: String, onCancel: @escaping () -> Void) -> (alert: UIAlertController, progressView: UIProgressView)? {
        guard let presenter = topPresenter(for: parentController) else {
            return nil
        }
        // The trailing blank lines reserve the strip the progress bar is pinned into; without them
        // the bar would overlap the message label.
        let alert = UIAlertController(title: title, message: text + "\n\n", preferredStyle: .alert)

        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0.0
        alert.view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 24.0),
            progressView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -24.0),
            progressView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -56.0)
        ])

        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in
            onCancel()
        }))
        presenter.present(alert, animated: true)
        return (alert, progressView)
    }

    private static func presentAlert(on parentController: ViewController?, title: String, text: String, ok: String) {
        guard let presenter = topPresenter(for: parentController) else {
            return
        }
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ok, style: .default, handler: nil))
        presenter.present(alert, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            picker.dismiss(animated: true)
            FenixRoundVideoFromGallery.clearDelegate()
            return
        }

        let context = self.context
        let peerId = self.peerId
        let threadId = self.threadId
        let replySubject = self.replySubject
        let parentController = self.parentController
        let typeIdentifier = UTType.movie.identifier

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let l10n = FenixuzL10n(presentationData.strings)

        // Everything runs from the dismissal completion: presenting on a controller that is still
        // animating away silently does nothing, so the progress alert would never appear.
        picker.dismiss(animated: true, completion: {
            // Cancelling is a user action, not a failure — it must not raise the error alert.
            let wasCancelled = Atomic<Bool>(value: false)
            var loadProgress: Progress?

            let presented = PickerDelegate.presentProgressAlert(
                on: parentController,
                title: l10n.roundVideo_preparing,
                text: l10n.roundVideo_preparingText,
                cancelTitle: l10n.roundVideo_cancel,
                onCancel: {
                    let _ = wasCancelled.swap(true)
                    loadProgress?.cancel()
                }
            )
            // Held until `finish` runs; releasing it earlier would stop the percentage updating.
            var progressObservation: NSKeyValueObservation?
            let didFinish = Atomic<Bool>(value: false)

            // Called from whichever queue the item provider replies on, so hop to main first.
            let finish: (String?) -> Void = { videoPath in
                Queue.mainQueue().async {
                    // loadFileRepresentation can report both a cancellation and a failure; only
                    // the first one should drive the UI.
                    if didFinish.swap(true) {
                        return
                    }
                    progressObservation?.invalidate()
                    progressObservation = nil

                    let continueAfterDismiss: () -> Void = {
                        if let videoPath {
                            FenixRoundVideoFromGallery.sendAsRoundVideo(context: context, peerId: peerId, threadId: threadId, replySubject: replySubject, videoPath: videoPath)
                        } else if !wasCancelled.with({ $0 }) {
                            PickerDelegate.presentAlert(on: parentController, title: l10n.roundVideo_failedTitle, text: l10n.roundVideo_failedText, ok: l10n.roundVideo_ok)
                        }
                        FenixRoundVideoFromGallery.clearDelegate()
                    }

                    if let alert = presented?.alert {
                        // The failure alert has to wait for this one to be gone, or it never shows.
                        alert.dismiss(animated: true, completion: continueAfterDismiss)
                    } else {
                        continueAfterDismiss()
                    }
                }
            }

            let itemProgress = result.itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url else {
                    finish(nil)
                    return
                }
                // The provided URL is a temporary file removed once this closure returns, so copy it out first.
                let destination = NSTemporaryDirectory() + "fenix_round_\(Int64.random(in: 0 ... Int64.max)).mp4"
                try? FileManager.default.removeItem(atPath: destination)
                do {
                    try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: destination))
                } catch {
                    finish(nil)
                    return
                }
                finish(destination)
            }
            loadProgress = itemProgress

            if let progressView = presented?.progressView {
                progressObservation = itemProgress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
                    let value = Float(progress.fractionCompleted)
                    Queue.mainQueue().async {
                        progressView.setProgress(value, animated: true)
                    }
                }
            }
        })
    }
}
