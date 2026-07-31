import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import SemanticStatusNode

/// Renders `InstantPageBlock.document` — a generic file row inside a rich message.
///
/// Mirrors `InstantPageV2AudioContentNode` (which itself deliberately re-implements
/// `ChatMessageInteractiveFileNode`'s music branch rather than reusing it), minus everything
/// audio-specific: no playback, no album art, no playlist state. Two lines — filename and
/// "<size> · <extension>" — beside a status control that downloads on tap.
///
/// DEFERRED: tapping an already-downloaded file does nothing. Opening it needs a document-preview
/// presenter, and `presentDocumentPreviewController` is internal to the TelegramUI target — out of
/// reach from this module and from the rich-bubble component module. See the Stage 2 design doc.
final class InstantPageV2DocumentContentNode: ASDisplayNode {
    private let file: TelegramMediaFile

    private let statusNode: SemanticStatusNode
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let tapView: UIView

    private var titleAttributedString: NSAttributedString?
    private var descriptionAttributedString: NSAttributedString?

    /// Invoked when the row is tapped while the file is not yet local.
    var fetch: () -> Void = {}
    /// Invoked when the row is tapped while a fetch is in flight.
    var cancelFetch: () -> Void = {}

    private var resourceStatusDisposable: Disposable?
    private var fetchStatus: EngineMediaResourceStatus?

    private static let progressDiameter: CGFloat = 40.0
    // Ø40 control vertically centred in the 52pt row: y = (52 − 40) / 2 = 6.
    private static let progressOrigin = CGPoint(x: 12.0, y: 6.0)
    private static let controlAreaWidth: CGFloat = 12.0 + 40.0 + 8.0
    private static let normHeight: CGFloat = 52.0

    init(context: AccountContext, message: MessageReference?, file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData) {
        self.file = file

        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let backgroundNodeColor = messageTheme.mediaActiveControlColor
        let foregroundNodeColor: UIColor = (incoming && messageTheme.mediaActiveControlColor.rgb != 0xffffff) ? .white : .clear

        self.statusNode = SemanticStatusNode(
            backgroundNodeColor: backgroundNodeColor,
            foregroundNodeColor: foregroundNodeColor,
            image: nil,
            overlayForegroundNodeColor: presentationData.theme.chat.message.mediaOverlayControlColors.foregroundColor
        )

        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false

        self.tapView = UIView()

        super.init()

        self.titleAttributedString = InstantPageV2DocumentContentNode.titleString(file: file, incoming: incoming, presentationData: presentationData)
        self.descriptionAttributedString = InstantPageV2DocumentContentNode.descriptionString(file: file, incoming: incoming, presentationData: presentationData)

        self.addSubnode(self.statusNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)

        self.statusNode.transitionToState(.download, animated: false)

        if let messageId = message?.id {
            self.resourceStatusDisposable = (messageMediaFileStatus(context: context, messageId: messageId, file: file)
            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                self?.fetchStatus = status
                self?.updateFetchState()
            })
        }
    }

    deinit {
        self.resourceStatusDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()
        // Plain view + UITapGestureRecognizer, NOT an ASControl: ASControl's .touchUpInside is
        // cancelled by the chat ListView's gesture system (same reason as the audio node).
        self.view.addSubview(self.tapView)
        self.tapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapped)))
    }

    @objc private func tapped() {
        switch self.fetchStatus {
        case .Remote, .Paused:
            self.fetch()
        case .Fetching:
            self.cancelFetch()
        case .none, .Local:
            // DEFERRED: opening a downloaded file needs a document-preview presenter this module
            // cannot reach. Deliberately inert rather than guessing at media resolution.
            break
        }
    }

    private func updateFetchState() {
        let state: SemanticStatusNodeState
        switch self.fetchStatus {
        case .none:
            state = .download
        case .Local:
            // Downloaded: no affordance, since tapping cannot open it yet.
            state = .none
        case let .Fetching(_, progress):
            state = .progress(value: CGFloat(max(progress, 0.027)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        case .Remote, .Paused:
            state = .download
        }
        self.statusNode.transitionToState(state)
    }

    // Line 1: filename at 17pt (= baseDisplaySize at the default font setting; scales with it).
    private static func titleString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let titleFont = Font.regular(floor(presentationData.chatFontSize.baseDisplaySize))
        let title = file.fileName ?? "File"
        return NSAttributedString(string: title, font: titleFont, textColor: messageTheme.fileTitleColor)
    }

    // Line 2: "<size> · <EXT>", omitting either part when unavailable.
    private static func descriptionString(file: TelegramMediaFile, incoming: Bool, presentationData: PresentationData) -> NSAttributedString {
        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let descriptionFont = Font.with(size: floor(presentationData.chatFontSize.baseDisplaySize * 15.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])

        var text = ""
        if let size = file.size, size > 0 {
            text = dataSizeString(Int(size), formatting: DataSizeStringFormatting(presentationData: presentationData))
        }
        if let fileName = file.fileName, let dotIndex = fileName.lastIndex(of: "."), dotIndex < fileName.endIndex {
            let ext = String(fileName[fileName.index(after: dotIndex)...]).uppercased()
            if !ext.isEmpty {
                text += text.isEmpty ? ext : " · \(ext)"
            }
        }
        return NSAttributedString(string: text, font: descriptionFont, textColor: messageTheme.fileDescriptionColor)
    }

    func updateLayout(width: CGFloat) {
        let progressFrame = CGRect(origin: InstantPageV2DocumentContentNode.progressOrigin, size: CGSize(width: InstantPageV2DocumentContentNode.progressDiameter, height: InstantPageV2DocumentContentNode.progressDiameter))
        self.statusNode.frame = progressFrame

        let controlAreaWidth = InstantPageV2DocumentContentNode.controlAreaWidth
        let textWidth = max(1.0, width - controlAreaWidth - 8.0)
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: self.titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let (descLayout, descApply) = TextNode.asyncLayout(self.descriptionNode)(TextNodeLayoutArguments(attributedString: self.descriptionAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: textWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleApply()
        let _ = descApply()

        let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descLayout.size.height
        let normHeight = InstantPageV2DocumentContentNode.normHeight
        let titleFrame = CGRect(origin: CGPoint(x: controlAreaWidth, y: floor((normHeight - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
        self.titleNode.frame = titleFrame
        self.descriptionNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descLayout.size)

        self.tapView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: normHeight))
    }
}

/// Item view for `InstantPageBlock.document`. Mirrors `InstantPageV2MediaAudioView`'s shape: wraps a
/// content node, routes fetch through the fetch manager, and re-lays out on bounds change.
final class InstantPageV2DocumentView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2DocumentItem
    var itemFrame: CGRect { return self.item.frame }
    private let documentNode: InstantPageV2DocumentContentNode

    init(item: InstantPageV2DocumentItem, renderContext: InstantPageV2RenderContext, theme: InstantPageTheme) {
        self.item = item

        let presentationData = renderContext.context.sharedContext.currentPresentationData.with { $0 }
        let incoming = renderContext.message?.isIncoming == true
        let documentFile: TelegramMediaFile
        if case let .file(f) = item.media.media {
            documentFile = f
        } else {
            documentFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: EmptyMediaResource(), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/octet-stream", size: nil, attributes: [], alternativeRepresentations: [])
        }
        self.documentNode = InstantPageV2DocumentContentNode(context: renderContext.context, message: renderContext.message, file: documentFile, incoming: incoming, presentationData: presentationData)

        super.init(frame: item.frame)
        self.backgroundColor = .clear
        self.addSubview(self.documentNode.view)

        let fetchContext = renderContext.context
        let fetchMessage = renderContext.message
        let fetchMedia = item.media
        self.documentNode.fetch = {
            guard case let .file(file) = fetchMedia.media, let message = fetchMessage, let messageId = message.id else {
                return
            }
            // Through the fetch manager, not freeMediaFileInteractiveFetched: messageMediaFileStatus
            // keys progress off the fetch manager's `hasEntry`, so only this route surfaces
            // .Fetching and drives the progress ring.
            let _ = messageMediaFileInteractiveFetched(fetchManager: fetchContext.fetchManager, messageId: messageId, messageReference: message, file: file, userInitiated: true, priority: .userInitiated).startStandalone()
        }
        self.documentNode.cancelFetch = {
            guard case let .file(file) = fetchMedia.media, let messageId = fetchMessage?.id else {
                return
            }
            messageMediaFileCancelInteractiveFetch(context: fetchContext, messageId: messageId, file: file)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.documentNode.frame = self.bounds
        self.documentNode.updateLayout(width: self.bounds.width)
    }

    func update(item: InstantPageV2DocumentItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext) {
        self.item = item
        self.documentNode.updateLayout(width: self.bounds.width)
    }

    // Not a gallery item: explicit no-op witnesses, matching the audio view's pattern.
    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }

    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) {
    }
}
