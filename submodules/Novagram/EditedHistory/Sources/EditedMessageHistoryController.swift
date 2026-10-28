import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import ContextUI
import Markdown
import Postbox
import PhotoResources

// MARK: - EditedMessageHistoryController
public final class EditedMessageHistoryController: ViewController {
    private let context: AccountContext
    private let message: Message
    private var presentationData: PresentationData
    private var presentationDataDisposable: MetaDisposable?

    private let listNode: EditedMessageHistoryListNode

    public init(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        self.listNode = EditedMessageHistoryListNode(context: context, message: message, presentationData: self.presentationData)

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = self.presentationData.strings.Conversation_Edit

        self.presentationDataDisposable = MetaDisposable()
        self.presentationDataDisposable?.set((context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings

                strongSelf.presentationData = presentationData

                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }))
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        self.title = self.presentationData.strings.Conversation_Edit
        self.listNode.updatePresentationData(self.presentationData)
    }

    override public func loadDisplayNode() {
        self.displayNode = self.listNode
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.listNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

// MARK: - EditedMessageHistoryListNode
private final class EditedMessageHistoryListNode: ASDisplayNode {
    private let context: AccountContext
    private let message: Message
    private var presentationData: PresentationData

    private let scrollNode: ASScrollNode
    private var historyEntries: [EditedMessageHistoryEntry] = []
    private var entryNodes: [EditedMessageHistoryEntryNode] = []

    init(context: AccountContext, message: Message, presentationData: PresentationData) {
        self.context = context
        self.message = message
        self.presentationData = presentationData

        self.scrollNode = ASScrollNode()
        self.scrollNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor

        super.init()

        self.addSubnode(self.scrollNode)

        if let historyAttribute = message.attributes.first(where: { $0 is EditedMessageHistoryAttribute }) as? EditedMessageHistoryAttribute {
            // Sort history by timestamp descending (newest edits first)
            self.historyEntries = historyAttribute.history.sorted(by: { $0.timestamp > $1.timestamp })
        }

        for entry in self.historyEntries {
            let node = EditedMessageHistoryEntryNode(context: context, message: message, entry: entry, presentationData: presentationData)
            self.entryNodes.append(node)
            self.scrollNode.addSubnode(node)
        }
    }

    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.scrollNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        // Can re-initialize nodes here, but skipping for simplicity
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight

        self.scrollNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.view.contentInset = insets
        self.scrollNode.view.scrollIndicatorInsets = insets

        var currentY: CGFloat = 0.0
        for node in self.entryNodes {
            let size = node.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
            node.frame = CGRect(origin: CGPoint(x: 0.0, y: currentY), size: size)
            currentY += size.height
        }

        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
    }
}

// MARK: - EditedMessageHistoryEntryNode
private final class EditedMessageHistoryEntryNode: ASDisplayNode {
    private let entry: EditedMessageHistoryEntry
    private let presentationData: PresentationData

    private let backgroundNode: ASDisplayNode
    private let dateTextNode: ASTextNode
    private let textNode: ASTextNode
    private let separatorNode: ASDisplayNode

    // Media preview for the previous version of the message (photo/video thumbnail,
    // or a text row for documents and other media kinds).
    private var mediaImageNode: TransformImageNode?
    private var playIconNode: ASImageNode?
    private var fileTextNode: ASTextNode?
    private var mediaDimensions: CGSize?

    init(context: AccountContext, message: Message, entry: EditedMessageHistoryEntry, presentationData: PresentationData) {
        self.entry = entry
        self.presentationData = presentationData

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor

        self.dateTextNode = ASTextNode()
        self.dateTextNode.isUserInteractionEnabled = false

        let dateString = stringForTimestamp(timestamp: entry.timestamp, strings: presentationData.strings)
        self.dateTextNode.attributedText = NSAttributedString(string: dateString, font: Font.regular(14.0), textColor: presentationData.theme.list.itemSecondaryTextColor)

        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.attributedText = NSAttributedString(string: entry.text, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.dateTextNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.separatorNode)

        self.setupMediaPreview(context: context, message: message)
    }

    private func setupMediaPreview(context: AccountContext, message: Message) {
        guard !self.entry.media.isEmpty else {
            return
        }
        let userLocation: MediaResourceUserLocation = .peer(message.id.peerId)
        if let image = self.entry.media.first(where: { $0 is TelegramMediaImage }) as? TelegramMediaImage {
            let imageNode = TransformImageNode()
            imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, userLocation: userLocation, photoReference: .standalone(media: image)))
            self.mediaImageNode = imageNode
            self.mediaDimensions = largestImageRepresentation(image.representations)?.dimensions.cgSize ?? CGSize(width: 320.0, height: 240.0)
            self.addSubnode(imageNode)
        } else if let file = self.entry.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
            if file.isVideo {
                let imageNode = TransformImageNode()
                imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox, userLocation: userLocation, videoReference: .standalone(media: file)))
                self.mediaImageNode = imageNode
                self.mediaDimensions = file.dimensions?.cgSize ?? CGSize(width: 320.0, height: 240.0)
                self.addSubnode(imageNode)

                let playIconNode = ASImageNode()
                playIconNode.isUserInteractionEnabled = false
                playIconNode.image = generatePlayIcon()
                self.playIconNode = playIconNode
                self.addSubnode(playIconNode)
            } else {
                var fileTitle = file.fileName ?? EditedHistoryStrings.file
                if let size = file.size {
                    fileTitle += " · \(fileSizeString(size))"
                }
                self.addFileTextNode(text: fileTitle)
            }
        } else {
            self.addFileTextNode(text: EditedHistoryStrings.media)
        }
    }

    private func addFileTextNode(text: String) {
        let fileTextNode = ASTextNode()
        fileTextNode.isUserInteractionEnabled = false
        fileTextNode.attributedText = NSAttributedString(string: text, font: Font.medium(15.0), textColor: self.presentationData.theme.list.itemAccentColor)
        self.fileTextNode = fileTextNode
        self.addSubnode(fileTextNode)
    }

    private func mediaPreviewSize(forWidth width: CGFloat) -> CGSize? {
        guard self.mediaImageNode != nil, let dimensions = self.mediaDimensions else {
            return nil
        }
        let safeDimensions = (dimensions.width < 1.0 || dimensions.height < 1.0) ? CGSize(width: 320.0, height: 240.0) : dimensions
        var fitted = safeDimensions.aspectFitted(CGSize(width: min(width, 280.0), height: 280.0))
        fitted.width = max(fitted.width, 60.0)
        fitted.height = max(fitted.height, 60.0)
        return fitted
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let insets = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 12.0, right: 16.0)
        let textWidth = constrainedSize.width - insets.left - insets.right

        let dateSize = self.dateTextNode.measure(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.measure(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))

        var totalHeight = insets.top + dateSize.height
        if !self.entry.text.isEmpty {
            totalHeight += 6.0 + textSize.height
        }
        if let mediaSize = self.mediaPreviewSize(forWidth: textWidth) {
            totalHeight += 8.0 + mediaSize.height
        }
        if let fileTextNode = self.fileTextNode {
            let fileSize = fileTextNode.measure(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
            totalHeight += 8.0 + fileSize.height
        }
        totalHeight += insets.bottom
        return CGSize(width: constrainedSize.width, height: totalHeight)
    }

    override func layout() {
        super.layout()

        let insets = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 12.0, right: 16.0)
        let bounds = self.bounds
        self.backgroundNode.frame = bounds

        let contentWidth = bounds.size.width - insets.left - insets.right

        let dateSize = self.dateTextNode.calculatedSize
        self.dateTextNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: dateSize)
        var currentY = insets.top + dateSize.height

        if !self.entry.text.isEmpty {
            let textSize = self.textNode.calculatedSize
            self.textNode.frame = CGRect(origin: CGPoint(x: insets.left, y: currentY + 6.0), size: textSize)
            currentY += 6.0 + textSize.height
        } else {
            self.textNode.frame = CGRect(origin: CGPoint(x: insets.left, y: currentY), size: CGSize())
        }

        if let mediaImageNode = self.mediaImageNode, let mediaSize = self.mediaPreviewSize(forWidth: contentWidth) {
            let mediaFrame = CGRect(origin: CGPoint(x: insets.left, y: currentY + 8.0), size: mediaSize)
            mediaImageNode.frame = mediaFrame
            let applyLayout = mediaImageNode.asyncLayout()
            applyLayout(TransformImageArguments(corners: ImageCorners(radius: 10.0), imageSize: mediaSize, boundingSize: mediaSize, intrinsicInsets: UIEdgeInsets()))()
            if let playIconNode = self.playIconNode, let iconSize = playIconNode.image?.size {
                playIconNode.frame = CGRect(origin: CGPoint(x: mediaFrame.midX - iconSize.width / 2.0, y: mediaFrame.midY - iconSize.height / 2.0), size: iconSize)
            }
            currentY += 8.0 + mediaSize.height
        }

        if let fileTextNode = self.fileTextNode {
            let fileSize = fileTextNode.calculatedSize
            fileTextNode.frame = CGRect(origin: CGPoint(x: insets.left, y: currentY + 8.0), size: fileSize)
            currentY += 8.0 + fileSize.height
        }

        let separatorHeight = UIScreenPixel
        self.separatorNode.frame = CGRect(x: 16.0, y: bounds.size.height - separatorHeight, width: bounds.size.width - 16.0, height: separatorHeight)
    }
}

private func stringForTimestamp(timestamp: Int32, strings: PresentationStrings) -> String {
    let date = Date(timeIntervalSince1970: Double(timestamp))
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

private func generatePlayIcon() -> UIImage? {
    let size = CGSize(width: 44.0, height: 44.0)
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 18.0, y: 13.0))
        context.addLine(to: CGPoint(x: 33.0, y: 22.0))
        context.addLine(to: CGPoint(x: 18.0, y: 31.0))
        context.closePath()
        context.fillPath()
    })
}

private func fileSizeString(_ size: Int64) -> String {
    let value = Double(size)
    let kb = 1024.0
    let mb = kb * 1024.0
    let gb = mb * 1024.0
    if value >= gb {
        return String(format: "%.1f GB", value / gb)
    } else if value >= mb {
        return String(format: "%.1f MB", value / mb)
    } else if value >= kb {
        return String(format: "%.1f KB", value / kb)
    } else {
        return "\(size) B"
    }
}
