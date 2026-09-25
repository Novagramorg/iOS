import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import TextFieldComponent
import TextFormat
import PhotoResources

/// Modal editor: media preview on top, the post text below in Telegram's own rich text field
/// (formatting menu, custom emoji), Send in the navigation bar.
final class FenixuzForwardEditScreen: ViewController {
    private let context: AccountContext
    private let source: FenixuzForwardEditSource
    private let threadId: Int64?
    private let send: ([EnqueueMessage]) -> Void
    private let presentationData: PresentationData
    private let strings: FenixuzForwardEditStrings

    private var editNode: FenixuzForwardEditScreenNode?
    private var sendButtonItem: UIBarButtonItem?
    private var didActivateInput = false
    private var didSend = false

    init(context: AccountContext, source: FenixuzForwardEditSource, threadId: Int64?, send: @escaping ([EnqueueMessage]) -> Void) {
        self.context = context
        self.source = source
        self.threadId = threadId
        self.send = send
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = FenixuzForwardEditStrings(self.presentationData.strings)

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.navigationPresentation = .modal
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = self.strings.screenTitle

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        let sendButtonItem = UIBarButtonItem(title: self.presentationData.strings.ShareMenu_Send, style: .done, target: self, action: #selector(self.sendPressed))
        self.navigationItem.rightBarButtonItem = sendButtonItem
        self.sendButtonItem = sendButtonItem
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let editNode = FenixuzForwardEditScreenNode(context: self.context, source: self.source, presentationData: self.presentationData, strings: self.strings, present: { [weak self] controller in
            self?.present(controller, in: .window(.root))
        })
        editNode.canSendUpdated = { [weak self] canSend in
            self?.sendButtonItem?.isEnabled = canSend
        }
        self.editNode = editNode
        self.displayNode = editNode
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.editNode?.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // The usual job is trimming the other channel's links at the end of the post, so open
        // with the keyboard up and the cursor there.
        if !self.didActivateInput {
            self.didActivateInput = true
            self.editNode?.activateInput()
        }
    }

    @objc private func cancelPressed() {
        self.editNode?.deactivateInput()
        self.dismiss()
    }

    @objc private func sendPressed() {
        guard !self.didSend, let editNode = self.editNode, let content = editNode.finalContent() else {
            return
        }
        self.didSend = true

        let messages = FenixuzForwardEditCopy.makeMessages(
            source: self.source,
            text: content.text,
            entities: content.entities,
            inlineStickers: content.inlineStickers,
            threadId: self.threadId,
            allowCustomEmoji: self.context.isPremium
        )
        editNode.deactivateInput()
        self.send(messages)
        self.dismiss()
    }
}

private final class FenixuzForwardEditScreenNode: ASDisplayNode {
    struct FinalContent {
        let text: String
        let entities: [MessageTextEntity]
        let inlineStickers: [MediaId: Media]
    }

    private let context: AccountContext
    private let source: FenixuzForwardEditSource
    private let presentationData: PresentationData
    private let strings: FenixuzForwardEditStrings
    private let present: (ViewController) -> Void
    private let characterLimit: Int
    private let initialText: NSAttributedString

    private let scrollView = UIScrollView()
    private let mediaScrollView = UIScrollView()
    private var thumbnailViews: [FenixuzForwardEditThumbnailView] = []
    private let cardView = UIView()
    private let textField = ComponentView<Empty>()
    private let textFieldExternalState = TextFieldComponent.ExternalState()
    private let textFieldParentState = EmptyComponentState()
    private let counterLabel = UILabel()
    private let footerLabel = UILabel()

    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    private var isUpdatingLayout = false
    private var canSend = true
    var canSendUpdated: ((Bool) -> Void)?

    private let thumbnailSize: CGFloat = 72.0
    private let thumbnailSpacing: CGFloat = 8.0
    private let cardMinHeight: CGFloat = 120.0

    init(context: AccountContext, source: FenixuzForwardEditSource, presentationData: PresentationData, strings: FenixuzForwardEditStrings, present: @escaping (ViewController) -> Void) {
        self.context = context
        self.source = source
        self.presentationData = presentationData
        self.strings = strings
        self.present = present
        self.characterLimit = source.hasMedia ? Int(context.userLimits.maxCaptionLength) : FenixuzForwardEditCopy.maxTextLength
        self.initialText = FenixuzForwardEditCopy.initialInputText(source: source, allowCustomEmoji: context.isPremium)

        super.init()

        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor

        // Consumed by the text field on its first update.
        self.textFieldExternalState.initialText = self.initialText
        self.textFieldParentState._updated = { [weak self] _, _ in
            self?.textFieldDidUpdate()
        }
    }

    override func didLoad() {
        super.didLoad()

        let theme = self.presentationData.theme

        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.view.addSubview(self.scrollView)

        if !self.source.previewItems.isEmpty {
            self.mediaScrollView.showsHorizontalScrollIndicator = false
            self.mediaScrollView.contentInsetAdjustmentBehavior = .never
            self.mediaScrollView.alwaysBounceHorizontal = false
            self.scrollView.addSubview(self.mediaScrollView)

            for item in self.source.previewItems {
                let thumbnailView = FenixuzForwardEditThumbnailView(context: self.context, item: item, theme: theme)
                self.thumbnailViews.append(thumbnailView)
                self.mediaScrollView.addSubview(thumbnailView)
            }
        }

        self.cardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cardView.layer.cornerRadius = 12.0
        self.cardView.clipsToBounds = true
        self.cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cardTapped)))
        self.scrollView.addSubview(self.cardView)

        self.counterLabel.font = Font.regular(13.0)
        self.counterLabel.textAlignment = .right
        self.scrollView.addSubview(self.counterLabel)

        self.footerLabel.font = Font.regular(13.0)
        self.footerLabel.textColor = theme.list.freeTextColor
        self.footerLabel.numberOfLines = 0
        self.scrollView.addSubview(self.footerLabel)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.validLayout?.layout.inputHeight
        self.validLayout = (layout, navigationHeight)
        self.updateLayout()

        if previousInputHeight != layout.inputHeight {
            self.scrollCaretIntoView()
        }
    }

    func activateInput() {
        (self.textField.view as? TextFieldComponent.View)?.activateInput()
    }

    func deactivateInput() {
        (self.textField.view as? TextFieldComponent.View)?.deactivateInput()
    }

    func finalContent() -> FinalContent? {
        guard let textFieldView = self.textField.view as? TextFieldComponent.View else {
            return nil
        }
        let text = trimChatInputText(textFieldView.getAttributedText(applyAutocorrection: true))
        guard self.isSendable(length: text.string.count) else {
            return nil
        }

        // Same entity pass as the chat composer: formatting from the field plus detected links,
        // mentions and hashtags.
        var entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text, maxAnimatedEmojisInText: 0))
        if !self.context.isPremium {
            entities = FenixuzForwardEditCopy.removingCustomEmoji(entities)
        }

        var inlineStickers: [MediaId: Media] = [:]
        text.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: text.length), options: [], using: { value, _, _ in
            if let value = value as? ChatTextInputTextCustomEmojiAttribute, let file = value.file {
                inlineStickers[file.fileId] = file
            }
        })

        return FinalContent(text: text.string, entities: entities, inlineStickers: inlineStickers)
    }

    @objc private func cardTapped() {
        self.activateInput()
    }

    private func textFieldDidUpdate() {
        // The field can report a change while it is being laid out; finish that pass first.
        if self.isUpdatingLayout {
            DispatchQueue.main.async { [weak self] in
                self?.updateLayout()
                self?.scrollCaretIntoView()
            }
            return
        }
        self.updateLayout()
        self.scrollCaretIntoView()
    }

    private func currentTextLength() -> Int {
        let text: NSAttributedString
        if let textFieldView = self.textField.view as? TextFieldComponent.View {
            text = textFieldView.getAttributedText(applyAutocorrection: false)
        } else {
            text = self.initialText
        }
        return trimChatInputText(text).string.count
    }

    private func isSendable(length: Int) -> Bool {
        if length > self.characterLimit {
            return false
        }
        // A photo or video may go without a caption, a text post may not be empty.
        return self.source.hasMedia || length > 0
    }

    private func updateLayout() {
        guard let (layout, navigationHeight) = self.validLayout, self.isNodeLoaded else {
            return
        }
        self.isUpdatingLayout = true
        defer {
            self.isUpdatingLayout = false
        }

        let theme = self.presentationData.theme
        let size = layout.size

        self.scrollView.frame = CGRect(origin: CGPoint(), size: size)
        var insets = layout.insets(options: [.input])
        insets.top += navigationHeight
        insets.bottom += 16.0
        if self.scrollView.contentInset != insets {
            self.scrollView.contentInset = insets
            self.scrollView.scrollIndicatorInsets = insets
        }

        let sideInset: CGFloat = 16.0 + max(layout.safeInsets.left, layout.safeInsets.right)
        let contentWidth = size.width - sideInset * 2.0
        var y: CGFloat = 16.0

        if !self.thumbnailViews.isEmpty {
            self.mediaScrollView.frame = CGRect(x: 0.0, y: y, width: size.width, height: self.thumbnailSize)
            var x = sideInset
            for thumbnailView in self.thumbnailViews {
                thumbnailView.frame = CGRect(x: x, y: 0.0, width: self.thumbnailSize, height: self.thumbnailSize)
                thumbnailView.updateLayout(size: CGSize(width: self.thumbnailSize, height: self.thumbnailSize))
                x += self.thumbnailSize + self.thumbnailSpacing
            }
            self.mediaScrollView.contentSize = CGSize(width: x - self.thumbnailSpacing + sideInset, height: self.thumbnailSize)
            y += self.thumbnailSize + 12.0
        }

        let placeholder = self.source.hasMedia ? self.strings.captionPlaceholder : self.strings.textPlaceholder
        self.textField.parentState = self.textFieldParentState
        let textFieldSize = self.textField.update(
            transition: .immediate,
            component: AnyComponent(TextFieldComponent(
                context: self.context,
                theme: theme,
                strings: self.presentationData.strings,
                externalState: self.textFieldExternalState,
                fontSize: 17.0,
                textColor: theme.list.itemPrimaryTextColor,
                accentColor: theme.list.itemAccentColor,
                insets: UIEdgeInsets(top: 9.0, left: 8.0, bottom: 10.0, right: 8.0),
                hideKeyboard: false,
                customInputView: nil,
                placeholder: NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.list.itemPlaceholderTextColor),
                resetText: nil,
                isOneLineWhenUnfocused: false,
                formatMenuAvailability: .available(TextFieldComponent.FormatMenuAvailability.Action.all),
                lockedFormatAction: {},
                present: { [weak self] controller in
                    self?.present(controller)
                },
                paste: { _ in },
                // A hardware keyboard's Return is caught as a key command and does nothing
                // unless there is an action (iPad, Mac). The on-screen Return is not affected.
                returnKeyAction: { [weak self] in
                    (self?.textField.view as? TextFieldComponent.View)?.insertText(NSAttributedString(string: "\n"))
                }
            )),
            environment: {},
            containerSize: CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        )

        let cardFrame = CGRect(x: sideInset, y: y, width: contentWidth, height: max(self.cardMinHeight, textFieldSize.height))
        self.cardView.frame = cardFrame
        if let textFieldView = self.textField.view {
            if textFieldView.superview == nil {
                self.cardView.addSubview(textFieldView)
                if let textFieldView = textFieldView as? TextFieldComponent.View {
                    textFieldView.inputTextView.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
                }
            }
            textFieldView.frame = CGRect(origin: CGPoint(), size: textFieldSize)
        }
        y = cardFrame.maxY + 6.0

        let length = self.currentTextLength()
        let isTooLong = length > self.characterLimit
        self.counterLabel.text = "\(length) / \(self.characterLimit)"
        self.counterLabel.textColor = isTooLong ? theme.list.itemDestructiveColor : theme.list.freeTextColor
        self.counterLabel.frame = CGRect(x: sideInset, y: y, width: contentWidth - 4.0, height: 18.0)
        y += 18.0 + 8.0

        var footerLines: [String] = []
        if isTooLong {
            footerLines.append(self.strings.tooLong(limit: self.characterLimit))
        }
        footerLines.append(self.strings.footerNote)
        if self.source.hasButtons {
            footerLines.append(self.strings.buttonsNotCopied)
        }
        self.footerLabel.text = footerLines.joined(separator: "\n")
        let footerWidth = contentWidth - 8.0
        let footerSize = self.footerLabel.sizeThatFits(CGSize(width: footerWidth, height: .greatestFiniteMagnitude))
        self.footerLabel.frame = CGRect(x: sideInset + 4.0, y: y, width: footerWidth, height: ceil(footerSize.height))
        y += ceil(footerSize.height) + 16.0

        self.scrollView.contentSize = CGSize(width: size.width, height: y)

        let canSend = self.isSendable(length: length)
        if canSend != self.canSend {
            self.canSend = canSend
            self.canSendUpdated?(canSend)
        }
    }

    /// The text field is as tall as its text and the page scrolls around it, so typing near the
    /// bottom must move the page to keep the cursor above the keyboard.
    private func scrollCaretIntoView() {
        guard let textView = (self.textField.view as? TextFieldComponent.View)?.inputTextView, textView.isFirstResponder, let selectedRange = textView.selectedTextRange else {
            return
        }
        let caretRect = textView.caretRect(for: selectedRange.end)
        if caretRect.isNull || caretRect.isInfinite {
            return
        }
        let caretFrame = textView.convert(caretRect, to: self.scrollView).insetBy(dx: 0.0, dy: -12.0)

        let insets = self.scrollView.contentInset
        let visibleTop = self.scrollView.contentOffset.y + insets.top
        let visibleBottom = self.scrollView.contentOffset.y + self.scrollView.bounds.height - insets.bottom
        var offset = self.scrollView.contentOffset.y
        if caretFrame.maxY > visibleBottom {
            offset += caretFrame.maxY - visibleBottom
        } else if caretFrame.minY < visibleTop {
            offset -= visibleTop - caretFrame.minY
        } else {
            return
        }
        let minOffset = -insets.top
        let maxOffset = max(minOffset, self.scrollView.contentSize.height + insets.bottom - self.scrollView.bounds.height)
        offset = min(max(offset, minOffset), maxOffset)
        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: offset), animated: false)
    }
}

private final class FenixuzForwardEditThumbnailView: UIView {
    private let imageNode = TransformImageNode()
    private let iconView = UIImageView()
    private var imageDimensions: CGSize?
    private var isVideo = false

    init(context: AccountContext, item: FenixuzForwardEditSource.PreviewItem, theme: PresentationTheme) {
        super.init(frame: CGRect())

        self.clipsToBounds = true
        self.layer.cornerRadius = 10.0
        self.backgroundColor = theme.list.mediaPlaceholderColor
        self.iconView.contentMode = .center

        switch item {
        case let .photo(message, image):
            self.imageNode.setSignal(mediaGridMessagePhoto(account: context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message), media: image)))
            self.imageDimensions = largestImageRepresentation(image.representations)?.dimensions.cgSize
            self.addSubview(self.imageNode.view)
        case let .video(message, file):
            self.imageNode.setSignal(mediaGridMessageVideo(postbox: context.account.postbox, userLocation: .peer(message.id.peerId), videoReference: .message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true))
            self.imageDimensions = file.dimensions?.cgSize
            self.addSubview(self.imageNode.view)
            if !file.isAnimated {
                self.isVideo = true
                self.iconView.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold))
                self.iconView.tintColor = .white
                self.iconView.layer.shadowColor = UIColor.black.cgColor
                self.iconView.layer.shadowOpacity = 0.5
                self.iconView.layer.shadowRadius = 2.0
                self.iconView.layer.shadowOffset = CGSize()
            }
        case let .file(file):
            let symbolName: String
            if file.isMusic {
                symbolName = "music.note"
            } else if file.isVoice {
                symbolName = "waveform"
            } else {
                symbolName = "doc.fill"
            }
            self.iconView.image = UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 26.0, weight: .regular))
            self.iconView.tintColor = theme.list.itemAccentColor
            // The media placeholder color is nearly invisible on the list background.
            self.backgroundColor = theme.list.itemBlocksBackgroundColor
        }
        self.addSubview(self.iconView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLayout(size: CGSize) {
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        if let imageDimensions = self.imageDimensions {
            let makeLayout = self.imageNode.asyncLayout()
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageDimensions.aspectFilled(size), boundingSize: size, intrinsicInsets: UIEdgeInsets()))
            apply()
        }
        if self.isVideo {
            self.iconView.frame = CGRect(x: 6.0, y: size.height - 22.0, width: 16.0, height: 16.0)
        } else {
            self.iconView.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
}
