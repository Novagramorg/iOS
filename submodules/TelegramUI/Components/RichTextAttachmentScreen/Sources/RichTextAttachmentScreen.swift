import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import AttachmentUI
import ViewControllerComponent
import TelegramPresentationData
import GlassBarButtonComponent
import BundleIconComponent
import MultilineTextComponent
import EdgeEffect
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextEditorMediaView
import InstantPageUI
import ContextUI
import Postbox
import TelegramCore
import CheckNode
import GlassControls
import ChatRichTextEditorComposer
import TextFormat

/// `RichTextChecklistMarkerView` host wrapper backing a checklist item's checkbox with a `CheckNode`
/// (an `ASDisplayNode`, so we host its `.view` — this is a `UIView`, not a node). The editor frames this
/// view in the marker gutter and calls `setChecked(_:animated:)` when the item toggles. A private copy
/// lives in each editor host (cross-module; duplication is expected).
private final class HostChecklistCheckboxView: UIView, RichTextChecklistMarkerView {
    private let checkNode: CheckNode
    init(theme: CheckNodeTheme, checked: Bool) {
        self.checkNode = CheckNode(theme: theme, content: .check(isRectangle: true))
        super.init(frame: .zero)
        self.checkNode.isUserInteractionEnabled = false
        self.addSubview(self.checkNode.view)
        self.checkNode.setSelected(checked, animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.checkNode.frame = self.bounds
    }
    func setChecked(_ checked: Bool, animated: Bool) {
        self.checkNode.setSelected(checked, animated: animated)
    }
}

public class RichTextAttachmentScreen: ViewControllerComponentContainer, AttachmentContainable {
    public enum RichTextAttachment {
        case image(ImageMediaReference)
        case file(FileMediaReference)
        case location(TelegramMediaMap)
    }
    
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = { return nil }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false

    public var mediaPickerContext: AttachmentMediaPickerContext?

    public var isPanGestureEnabled: (() -> Bool)? {
        return { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                return true
            }
            return componentView.isPanGestureEnabled()
        }
    }

    private let sendMessage: (Document, [String: Media], [Int64: TelegramMediaFile]) -> Void
    private let syncContent: ((Document, [String: Media], [Int64: TelegramMediaFile]) -> Void)?

    public init(context: AccountContext, initialContents: Document? = nil, initialMedia: [String: Media] = [:], initialEmojiFiles: [Int64: TelegramMediaFile] = [:], sendMessage: @escaping (Document, [String: Media], [Int64: TelegramMediaFile]) -> Void, syncContent: ((Document, [String: Media], [Int64: TelegramMediaFile]) -> Void)? = nil, presentAttachmentMenu: ((@escaping (RichTextAttachmentScreen.RichTextAttachment) -> Void) -> Void)?) {
        self.sendMessage = sendMessage
        self.syncContent = syncContent

        let overNavigationContainer = SparseContainerView()

        super.init(context: context, component: RichTextAttachmentScreenComponent(
            context: context,
            initialContents: initialContents,
            initialMedia: initialMedia,
            initialEmojiFiles: initialEmojiFiles,
            overNavigationContainer: overNavigationContainer,
            presentAttachmentMenu: presentAttachmentMenu
        ), navigationBarAppearance: .transparent, theme: .default)

        self._hasGlassStyle = true

        // Glass style: the Cancel/Done buttons are rendered by the View into
        // overNavigationContainer, so the nav item only needs an empty placeholder.
        self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: UIView()), animated: false)

        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(overNavigationContainer, at: 0)
        }
        
        self.attemptNavigation = { [weak self] _ in
            guard let self, let syncContent = self.syncContent, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
                return true
            }
            syncContent(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
            return true
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func donePressed() {
        if let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View {
            self.sendMessage(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
        }
        self.dismiss()
    }
    
    fileprivate func close() {
        guard let syncContent = self.syncContent, let componentView = self.node.hostView.componentView as? RichTextAttachmentScreenComponent.View else {
            self.dismiss()
            return
        }
        syncContent(componentView.currentDocument, componentView.currentMedia, componentView.currentEmojiFiles)
        self.dismiss()
    }
}

final class RichTextAttachmentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    // Held for the next step: the RichTextEditor demo will read context and add
    // its editor view into the View's content container.
    let context: AccountContext
    let initialContents: Document?
    let initialMedia: [String: Media]
    let initialEmojiFiles: [Int64: TelegramMediaFile]
    let overNavigationContainer: UIView
    let presentAttachmentMenu: ((@escaping (RichTextAttachmentScreen.RichTextAttachment) -> Void) -> Void)?

    init(context: AccountContext, initialContents: Document?, initialMedia: [String: Media], initialEmojiFiles: [Int64: TelegramMediaFile], overNavigationContainer: UIView, presentAttachmentMenu: ((@escaping (RichTextAttachmentScreen.RichTextAttachment) -> Void) -> Void)?) {
        self.context = context
        self.initialContents = initialContents
        self.initialMedia = initialMedia
        self.initialEmojiFiles = initialEmojiFiles
        self.overNavigationContainer = overNavigationContainer
        self.presentAttachmentMenu = presentAttachmentMenu
    }

    static func ==(lhs: RichTextAttachmentScreenComponent, rhs: RichTextAttachmentScreenComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let leftNavActionsBar = ComponentView<Empty>()
        private let rightNavActionsBar = ComponentView<Empty>()
        
        private let editor = RichTextEditorView()
        // Frosted fade at the screen top (mirrors ComposePollScreen) — scrolling content dissolves into the
        // nav region. Overlaid above the editor; the nav buttons live in the separate over-nav container.
        private let topEdgeEffectView = EdgeEffectView()

        /// The current editor document, read by the controller's `donePressed`.
        var currentDocument: Document {
            return self.editor.document
        }

        /// Picked media keyed by the opaque `mediaID` handed to the editor. Read by `donePressed`.
        private var attachedMedia: [String: Media] = [:]

        /// The picked media map, keyed by the editor's `mediaID`. Read by the controller's `donePressed`.
        var currentMedia: [String: Media] {
            return self.attachedMedia
        }

        /// The custom-emoji file store (seeded + user-inserted), keyed by fileId. Read by the controller's
        /// `donePressed` so each emoji run's `TelegramMediaFile` is re-attached when converting back.
        var currentEmojiFiles: [Int64: TelegramMediaFile] {
            return self.emojiKeyboard?.currentEmojiFiles ?? [:]
        }

        private var component: RichTextAttachmentScreenComponent?
        private var environment: EnvironmentType?
        
        private let actionBar = ComponentView<Empty>()
        private let aiButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()

        private var emojiKeyboard: RichTextEmojiKeyboardController?
        private var componentState: EmptyComponentState?
        private var isUpdating = false
        private var lastTabBarVisible: Bool?
        /// The `PresentationTheme` last mapped into the editor. `PresentationTheme` is a shared `final
        /// class`, so reference inequality is the cheap change-signal — guarding the editor `theme` setter
        /// (which does an unconditional reload+redraw) against firing on every keystroke (`onChange` →
        /// `componentState.updated` → `update`).
        private var appliedTheme: PresentationTheme?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func isPanGestureEnabled() -> Bool {
            return !viewTreeContainsFirstResponder(view: self.editor)
        }
        
        private func textCell(_ id: String, _ lines: [String]) -> Cell {
            Cell(id: BlockID(id), blocks: lines.enumerated().map { i, t in
                .paragraph(ParagraphBlock(id: BlockID("\(id)p\(i)"), runs: [TextRun(text: t)]))
            })
        }

        // MARK: Phase 5b — image picker + link prompt

        private func presentImagePicker() {
            guard let component = self.component else {
                return
            }
            component.presentAttachmentMenu?({ [weak self] attachment in
                guard let self else {
                    return
                }
                let media: Media
                let kind: MediaKind
                let naturalSize: CGSize
                switch attachment {
                case let .image(imageReference):
                    let image = imageReference.media
                    media = image
                    kind = .image
                    naturalSize = image.representations.last?.dimensions.cgSize ?? CGSize(width: 1, height: 1)
                case let .file(fileReference):
                    let file = fileReference.media
                    if file.isVideo {
                        media = file
                        kind = .video
                        naturalSize = file.dimensions?.cgSize ?? CGSize(width: 1, height: 1)
                    } else if file.isMusic || file.isVoice {
                        // Audio (music from the Audio picker; voice only via edit round-trips). The block is a
                        // fixed-height row, so naturalSize is ignored by MediaBlockBox — pass a 1x1 placeholder.
                        media = file
                        kind = .audio
                        naturalSize = CGSize(width: 1.0, height: 1.0)
                    } else {
                        return   // unsupported document type
                    }
                case let .location(map):
                    // A map is id-less, so mint a deterministic key from its coordinates; the venue title (if any)
                    // seeds the caption (a raw dropped pin has no venue -> empty caption). Self-contained insert,
                    // since the shared `media.id` path below can't key an id-less medium.
                    let mediaID = "map:\(map.latitude):\(map.longitude)"
                    self.attachedMedia[mediaID] = map
                    let caption: [TextRun] = map.venue?.title.isEmpty == false ? [TextRun(text: map.venue!.title)] : []
                    self.editor.insertMedia(mediaID: mediaID, naturalSize: CGSize(width: 600.0, height: 300.0), kind: .location, caption: caption)
                    return
                }
                guard let mediaId = media.id else { return }
                let mediaID = "\(mediaId.namespace):\(mediaId.id)"
                self.attachedMedia[mediaID] = media
                self.editor.insertMedia(mediaID: mediaID, naturalSize: naturalSize, kind: kind)
            })
        }

        private func presentLinkPrompt() {
            guard let component = self.component else {
                return
            }
            
            let existing = editor.currentLink()
            let alert = UIAlertController(title: "Link", message: "Set a URL for the selected text", preferredStyle: .alert)
            alert.addTextField { tf in
                tf.placeholder = "https://example.com"
                tf.text = existing
                tf.keyboardType = .URL
                tf.autocapitalizationType = .none
                tf.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "Set", style: .default) { [weak self, weak alert] _ in
                guard let url = alert?.textFields?.first?.text, !url.isEmpty else { return }
                self?.editor.becomeFirstResponder()
                self?.editor.setLink(url)
            })
            if existing != nil {
                alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                    self?.editor.becomeFirstResponder()
                    self?.editor.removeLink()
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            component.context.sharedContext.mainWindow?.presentNative(alert)
        }

        private func presentActionMenu(from sourceView: UIView, items: [ContextMenuItem]) {
            guard let component = self.component else { return }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let controller = makeContextController(
                presentationData: presentationData,
                source: .reference(RichTextActionContextReferenceSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            self.environment?.controller()?.presentInGlobalOverlay(controller)
        }

        /// Maps the app theme to the editor's render colors. Every value is `PresentationTheme`-derived —
        /// no OS-semantic `UIColor` survives on this path. accent/table derivations mirror the chat
        /// composer (`ChatTextInputPanelNode.makeRichTextThemeColors`); text uses `list.item*` because the
        /// screen's surface is `list.plainBackgroundColor`.
        private static func mapEditorTheme(_ theme: PresentationTheme) -> RichTextEditorTheme {
            let codeFill = theme.list.itemAccentColor.withMultipliedAlpha(0.1)
            return RichTextEditorTheme(
                primaryText: theme.list.itemPrimaryTextColor,
                secondaryText: theme.list.itemSecondaryTextColor,
                placeholder: theme.list.itemPlaceholderTextColor,
                accent: theme.list.itemAccentColor,
                tableBorder: theme.list.itemAccentColor.withMultipliedAlpha(0.25),
                tableHeaderBackground: codeFill,
                codeBackground: codeFill,
                listMarker: theme.list.itemPrimaryTextColor,
                inlineCodeBackground: codeFill,
                markedTextUnderline: theme.list.itemPrimaryTextColor,
                spoilerDust: theme.list.itemSecondaryTextColor,
                containerPlaceholder: theme.list.itemPlaceholderTextColor.mixedWith(theme.list.itemAccentColor, alpha: 0.15).withMultipliedBrightnessBy(theme.overallDarkAppearance ? 1.1 : 0.9),
                // Same source as secondaryText/placeholder above — no visual change until a distinct value is set.
                quoteAuthorText: theme.list.itemAccentColor,
                quoteAuthorPlaceholder: theme.list.itemPlaceholderTextColor.mixedWith(theme.list.itemAccentColor, alpha: 0.15).withMultipliedBrightnessBy(theme.overallDarkAppearance ? 1.1 : 0.9)
            )
        }

        func update(component: RichTextAttachmentScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.componentState = state
            self.environment = environment

            self.isUpdating = true
            defer { self.isUpdating = false }

            if self.component == nil {
                /*let table = TableBlock(id: BlockID("t"),
                    columns: [ColumnSpec(width: 140), ColumnSpec(width: 110), ColumnSpec(width: 110)],
                    rows: [
                        Row(id: BlockID("r0"), isHeader: true, cells: [textCell("h0", ["Name"]), textCell("h1", ["Mass (suns)"]), textCell("h2", ["Distance"])]),
                        Row(id: BlockID("r1"), cells: [
                            Cell(id: BlockID("c0"), blocks: [.paragraph(ParagraphBlock(id: BlockID("c0p"),
                                runs: [TextRun(text: "Sagittarius A*")]))]),
                            textCell("c1", ["4.3 M"]), textCell("c2", ["26,000 ly"])]),
                        Row(id: BlockID("r2"), cells: [textCell("d0", ["M87*"]), textCell("d1", ["6.5 B"]), textCell("d2", ["53M ly"])]),
                    ])
                let wideTable = TableBlock(id: BlockID("wt"),
                    columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100),
                              ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
                    rows: [
                        Row(id: BlockID("wr0"), isHeader: true, cells: [
                            textCell("w00", ["Col 1"]), textCell("w01", ["Col 2"]), textCell("w02", ["Col 3"]),
                            textCell("w03", ["Col 4"]), textCell("w04", ["Col 5"]), textCell("w05", ["Col 6"]),
                            textCell("w06", ["Col 7"]),
                        ]),
                        Row(id: BlockID("wr1"), cells: [
                            textCell("w10", ["A"]), textCell("w11", ["B"]), textCell("w12", ["C"]),
                            textCell("w13", ["D"]), textCell("w14", ["E"]), textCell("w15", ["F"]),
                            textCell("w16", ["G"]),
                        ]),
                    ])*/
                // The screen paints `list.plainBackgroundColor` (below); clear the editor's opaque default
                // `.systemBackground` so that themed surface shows through.
                editor.canvasBackgroundColor = .clear
                // Theme the editor's mapper BEFORE seeding the document: the document setter builds each
                // block's attributed string with the mapper's current theme (baking in the foreground
                // color), and the `editor.theme` setter only re-maps existing boxes when `bounds.width > 0`
                // — which is false here (the editor frame is set later this pass). So seeding pre-existing
                // text before theming left it the `.default` black foreground. (The guarded re-apply below
                // is a no-op on this first pass since `appliedTheme` is now set, and handles later theme
                // changes when the frame — and a working reload width — exists.)
                editor.theme = Self.mapEditorTheme(environment.theme)
                self.appliedTheme = environment.theme
                // Quote geometry for the full-page article editor. Defaults == the editor's built-in look;
                // tune here to diverge from the chat composer.
                editor.quoteStyle = QuoteStyle(leadingInset: 9.0, topInset: 4.0, bottomInset: 4.0)
                editor.pullQuoteStyle = PullQuoteStyle()
                // Quote collapse/expand affordance icons (same assets as the chat composer / legacy input).
                if let collapse = UIImage(bundleImageName: "Media Gallery/Minimize")?.precomposed().withRenderingMode(.alwaysTemplate),
                   let expand = UIImage(bundleImageName: "Media Gallery/Fullscreen")?.precomposed().withRenderingMode(.alwaysTemplate) {
                    editor.quoteCollapseIcons = RichTextEditorQuoteCollapseIcons(collapse: collapse, expand: expand)
                }
                // A selection-handle ("knob") drag must NOT be hijacked by the interactive keyboard-/modal-
                // dismiss gestures. These Display flags can only be set host-side (the editor package can't
                // import Display) and are applied to the hit-testable handle views, so the effect is scoped to
                // knob interaction — not the whole editor surface.
                editor.configureSelectionHandleView = { handle in
                    handle.disablesInteractiveTransitionGestureRecognizer = true   // navigation back-swipe (triggered by a horizontal knob drag)
                    handle.disablesInteractiveModalDismiss = true
                    handle.disablesInteractiveKeyboardGestureRecognizer = true
                }
                editor.disablesInteractiveTransitionGestureRecognizer = true   // navigation back-swipe (triggered by a horizontal knob drag)
                editor.disablesInteractiveModalDismiss = true
                editor.disablesInteractiveKeyboardGestureRecognizer = true
                // Seed the editor with the caller-supplied initial content (e.g. the chat composer's
                // current document when expanding); an empty document when none is provided.
                editor.document = component.initialContents ?? Document()
                // Seed the picked-media store alongside the document (before the media-view provider runs)
                // so any media referenced by the initial document resolves on first layout.
                self.attachedMedia = component.initialMedia

                let emojiKeyboard = RichTextEmojiKeyboardController(context: component.context, editor: editor, requestLayout: { [weak self] in
                    guard let self, !self.isUpdating else { return }
                    self.componentState?.updated(transition: .spring(duration: 0.4))
                })
                self.emojiKeyboard = emojiKeyboard
                // Seed the keyboard's file store with the files of any custom emoji the initial document
                // references (the `Document` carries only fileIds) — before the editor's first layout, so a
                // custom emoji carried in from the chat composer renders, and its file survives back out.
                emojiKeyboard.seedEmojiFiles(component.initialEmojiFiles)

                editor.registerEmojiViewProvider { [weak self] id, size in
                    return self?.emojiKeyboard?.customEmojiView(forId: id, size: size)
                }

                editor.registerMediaViewProvider { [weak self] mediaID, _ in
                    guard let self, let component = self.component,
                          let media = self.attachedMedia[mediaID] else { return nil }
                    // Theme an audio row to the editor's accent/text scheme (same `list.item*` sources as
                    // `mapEditorTheme` / the table); ignored for image/map media.
                    let theme = component.context.sharedContext.currentPresentationData.with { $0 }.theme
                    let audioColors = InstantPageAudioColorOverride(
                        control: theme.list.itemAccentColor,
                        controlForeground: theme.list.itemCheckColors.foregroundColor,
                        title: theme.list.itemPrimaryTextColor,
                        description: theme.list.itemSecondaryTextColor
                    )
                    return MediaItemNodeView(context: component.context, media: EngineMedia(media), audioColorOverride: audioColors)
                }

                // Host the checklist checkbox with a `CheckNode` themed from the standard app checkbox palette
                // (`list.itemCheckColors`), mirroring `instantPageChecklistMarkerTheme`. Reads `appliedTheme`
                // (the live `PresentationTheme`) lazily; nil before the first theme apply (harmless — the editor
                // falls back to its glyph marker until a checkbox is provided).
                editor.registerChecklistMarkerViewProvider { [weak self] checked, _ in
                    guard let self, let theme = self.appliedTheme else { return nil }
                    let c = theme.list.itemCheckColors
                    let nodeTheme = CheckNodeTheme(backgroundColor: c.fillColor, strokeColor: c.foregroundColor, borderColor: c.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false)
                    return HostChecklistCheckboxView(theme: nodeTheme, checked: checked)
                }

                editor.onBecameFirstResponder = { [weak self] in
                    guard let self else {
                        return
                    }
                    if let controller = self.environment?.controller() as? RichTextAttachmentScreen {
                        controller.requestAttachmentMenuExpansion()
                    }
                }

                // The editor no longer drives its own layout/keyboard insets; it just tells us when anything
                // changes so we re-run this update (which calls editor.update(size:insets:)). The isUpdating
                // guard only defends the SYNCHRONOUS loop (update → editor.update → onChange → update);
                // editor.update/performLayout don't fire onChange synchronously, so it can't loop. Async
                // onChange (user edits/caret moves) skips the guard and correctly schedules a re-layout.
                editor.onChange = { [weak self] in
                    guard let self, !self.isUpdating else { return }
                    self.componentState?.updated(transition: .immediate)
                }

                self.addSubview(editor)
                self.topEdgeEffectView.isUserInteractionEnabled = false
                self.addSubview(self.topEdgeEffectView)
            }
            self.component = component

            if self.appliedTheme !== environment.theme {
                self.appliedTheme = environment.theme
                self.editor.theme = Self.mapEditorTheme(environment.theme)
            }

            let barButtonSize = CGSize(width: 44.0, height: 44.0)
            
            let editorState = self.editor.currentState()
            
            let leftNavActionsBarSize = self.leftNavActionsBar.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Navigation/Close"), action: { [weak self] in
                            guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                                return
                            }
                            controller.close()
                        })
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: barButtonSize.height)
            )
            let leftNavActionsBarFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: leftNavActionsBarSize)
            if let leftNavActionsBarView = self.leftNavActionsBar.view {
                if leftNavActionsBarView.superview == nil {
                    component.overNavigationContainer.addSubview(leftNavActionsBarView)
                }
                transition.setFrame(view: leftNavActionsBarView, frame: leftNavActionsBarFrame)
            }
            
            let rightNavActionsBarSize = self.rightNavActionsBar.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Media Editor/Undo"), action: editorState.canUndo ? { [weak self] in
                            self?.editor.undo()
                        } : nil),
                        GlassControlGroupComponent.Item(id: 1, content: .icon("Media Editor/Redo"), action: editorState.canRedo ? { [weak self] in
                            self?.editor.redo()
                        } : nil)
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: barButtonSize.height)
            )
            let rightNavActionsBarFrame = CGRect(origin: CGPoint(x: availableSize.width - (environment.safeInsets.left + 16.0) - rightNavActionsBarSize.width, y: 16.0), size: rightNavActionsBarSize)
            if let rightNavActionsBarView = self.rightNavActionsBar.view {
                if rightNavActionsBarView.superview == nil {
                    component.overNavigationContainer.addSubview(rightNavActionsBarView)
                }
                transition.setFrame(view: rightNavActionsBarView, frame: rightNavActionsBarFrame)
            }

            if component.initialContents == nil {
                //TODO:localize
                let titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "Text",
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            ))
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 40.0)
                )
                // The title is centered, but must clear both the left button cluster (Close + undo + redo) and the
                // Done button. When the natural center would overlap either side, re-center it in the gap between
                // the cluster's trailing edge and Done (needed on narrow screens where the centered title would
                // otherwise sit under the redo pill).
                let leftClusterMaxX = leftNavActionsBarFrame.maxX
                var titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
                if titleFrame.minX < leftClusterMaxX + 16.0 || titleFrame.maxX > rightNavActionsBarFrame.minX - 16.0 {
                    titleFrame.origin.x = leftClusterMaxX + floorToScreenPixels((rightNavActionsBarFrame.minX - leftClusterMaxX) - titleSize.width) / 2.0
                }
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        component.overNavigationContainer.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: titleFrame)
                }
            }
            
            self.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor

            let emojiPanelHeight = self.emojiKeyboard?.updatePanel(container: self, availableSize: availableSize, environment: environment, transition: transition) ?? 0.0
            let editorTop = environment.navigationHeight
            let editorFrame = CGRect(x: environment.safeInsets.left, y: 0.0,
                                     width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right,
                                     height: availableSize.height)
            self.editor.frame = editorFrame
            
            var barActions: [RichTextActionBarComponent.Action] = []
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("paragraphStyle"), icon: "RichText/ToolParagraphStyle",
                action: editorState.isInTable ? nil : { [weak self] sourceView in
                    guard let self else { return }
                    let current = self.editor.currentState().paragraphStyle
                    let entries: [(String, ParagraphStyleName)] = [
                        ("Heading 1", .heading1), ("Heading 2", .heading2),
                        ("Heading 3", .heading3), ("Body", .body)]
                    let items: [ContextMenuItem] = entries.map { (title, style) in
                        .action(ContextMenuActionItem(text: title, icon: { theme in
                            style == current
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            self?.editor.setParagraphStyle(style)
                        }))
                    }
                    self.presentActionMenu(from: sourceView, items: items)
                },
                isSelected: false
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("list"), icon: "RichText/ToolList",
                action: editorState.isInTable ? nil : { [weak self] sourceView in
                    guard let self else { return }
                    let current = self.editor.currentState().listMarker
                    let entries: [(String, ListMarker?)] = [("None", nil), ("Bulleted", .bullet), ("Numbered", .ordered), ("Checklist", .checklist)]
                    let items: [ContextMenuItem] = entries.map { (title, marker) in
                        .action(ContextMenuActionItem(text: title, icon: { theme in
                            marker == current
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            self?.editor.setList(marker)
                        }))
                    }
                    self.presentActionMenu(from: sourceView, items: items)
                },
                isSelected: editorState.listMarker != nil
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("quote"), icon: "RichText/ToolQuote",
                action: editorState.isInTable ? nil : { [weak self] sourceView in
                    guard let self else { return }
                    // Re-read live state at tap time rather than the build-time snapshot.
                    let state = self.editor.currentState()
                    let isQuote = state.blockQuoteDepth > 0   // inside a Block.blockQuote container (Task 16b)
                    let isCode = state.isCodeBlock
                    let isPullQuote = state.isPullQuote
                    let items: [ContextMenuItem] = [
                        .action(ContextMenuActionItem(text: "None", icon: { theme in
                            (!isQuote && !isCode && !isPullQuote)
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else { return }
                            // Return to a plain body paragraph. Un-code / un-pullquote / un-blockquote as
                            // needed. `unwrapBlockQuoteLevel()` peels one `Block.blockQuote` container;
                            // `setParagraphStyle(.body)` resets a heading paragraph.
                            let live = self.editor.currentState()
                            if live.isCodeBlock {
                                self.editor.makeCodeBlock()
                            } else if live.isPullQuote {
                                self.editor.makePullQuote()
                            } else if live.blockQuoteDepth > 0 {
                                self.editor.unwrapBlockQuoteLevel()
                            } else {
                                self.editor.setParagraphStyle(.body)
                            }
                        })),
                        .action(ContextMenuActionItem(text: "Quote", icon: { theme in
                            isQuote
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else { return }
                            // Exit a code block first (its text becomes body paragraphs), then wrap in a
                            // Block.blockQuote container (wrapInBlockQuote nests; unwrap is via None above).
                            if self.editor.currentState().isCodeBlock {
                                self.editor.makeCodeBlock()
                            }
                            self.editor.wrapInBlockQuote()
                        })),
                        .action(ContextMenuActionItem(text: "Pull Quote", icon: { theme in
                            isPullQuote
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else { return }
                            // makePullQuote() toggles; only turn it ON so re-selecting Pull Quote is idempotent.
                            if !self.editor.currentState().isPullQuote {
                                self.editor.makePullQuote()
                            }
                        })),
                        .action(ContextMenuActionItem(text: "Code Block", icon: { theme in
                            isCode
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else { return }
                            // makeCodeBlock() toggles; only turn it ON so re-selecting Code Block is idempotent.
                            if !self.editor.currentState().isCodeBlock {
                                self.editor.makeCodeBlock()
                            }
                        })),
                    ]
                    self.presentActionMenu(from: sourceView, items: items)
                },
                isSelected: editorState.blockQuoteDepth > 0 || editorState.isCodeBlock || editorState.isPullQuote
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("writingDirection"), icon: "RichText/ToolParagraphStyle",
                action: editorState.isInTable ? nil : { [weak self] sourceView in
                    guard let self else { return }
                    let current = self.editor.layoutDirectionOverride
                    let entries: [(String, DocumentLayoutDirection)] = [
                        ("Automatic", .auto), ("Left-to-Right", .leftToRight), ("Right-to-Left", .rightToLeft)]
                    let items: [ContextMenuItem] = entries.map { (title, dir) in
                        .action(ContextMenuActionItem(text: title, icon: { theme in
                            dir == current
                                ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                : UIImage()
                        }, action: { [weak self] _, f in
                            f(.default)
                            self?.editor.layoutDirectionOverride = dir
                        }))
                    }
                    self.presentActionMenu(from: sourceView, items: items)
                },
                isSelected: self.editor.layoutDirectionOverride != .auto
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("table"), icon: "RichText/ToolTable",
                action: { [weak self] sourceView in
                    guard let self else { return }
                    var items: [ContextMenuItem] = []
                    if self.editor.currentState().isInTable {
                        items.append(.action(ContextMenuActionItem(text: "Insert Row Above", icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.insertTableRowAbove()
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Insert Row Below", icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.insertTableRowBelow()
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Delete Row", textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.deleteTableRow()
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Insert Column Left", icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.insertTableColumnLeft()
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Insert Column Right", icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.insertTableColumnRight()
                        })))
                        items.append(.action(ContextMenuActionItem(text: "Delete Column", textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.deleteTableColumn()
                        })))
                        for (title, alignment) in [("Align Left", TextAlignment.left), ("Align Center", .center), ("Align Right", .right)] {
                            items.append(.action(ContextMenuActionItem(text: title, icon: { _ in nil }, action: { [weak self] _, f in
                                f(.default); self?.editor.setTableColumnAlignment(alignment)
                            })))
                        }
                        items.append(.action(ContextMenuActionItem(text: "Delete Table", textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.deleteTable()
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: "Insert Table", icon: { _ in nil }, action: { [weak self] _, f in
                            f(.default); self?.editor.insertTable(rows: 2, cols: 2)
                        })))
                    }
                    self.presentActionMenu(from: sourceView, items: items)
                },
                isSelected: false
            ))
            if component.presentAttachmentMenu != nil {
                barActions.append(RichTextActionBarComponent.Action(
                    id: AnyHashable("attach"), icon: "RichText/ToolAttach",
                    action: editorState.isInTable ? nil : { [weak self] _ in self?.presentImagePicker() },
                    isSelected: false
                ))
            }
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("link"), icon: "RichText/ToolLink",
                action: editorState.hasSelection ? { [weak self] _ in self?.presentLinkPrompt() } : nil,
                isSelected: editorState.link != nil
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("bold"), icon: "RichText/ToolBold",
                action: { [weak self] _ in self?.editor.toggleBold() },
                isSelected: editorState.bold
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("italic"), icon: "RichText/ToolItalic",
                action: { [weak self] _ in self?.editor.toggleItalic() },
                isSelected: editorState.italic
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("underline"), icon: "RichText/ToolUnderline",
                action: { [weak self] _ in self?.editor.toggleUnderline() },
                isSelected: editorState.underline
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("strike"), icon: "RichText/ToolStrike",
                action: { [weak self] _ in self?.editor.toggleStrikethrough() },
                isSelected: editorState.strikethrough
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("emoji"), icon: "RichText/ToolEmoji",
                action: { [weak self] _ in self?.emojiKeyboard?.toggle() },
                isSelected: self.emojiKeyboard?.isEmojiMode ?? false
            ))
            barActions.append(RichTextActionBarComponent.Action(
                id: AnyHashable("code"), icon: "RichText/ToolCode",
                action: { [weak self] _ in self?.editor.toggleInlineCode() },
                isSelected: editorState.code
            ))
            
            let tabBarBottomInset = max(environment.inputHeight, emojiPanelHeight, environment.additionalInsets.bottom)
            
            var sideInset: CGFloat = 12.0
            if tabBarBottomInset <= 28.0 {
                sideInset = 20.0
            }
            
            let actionBarSpacing: CGFloat = 6.0
            
            let aiButtonSize = self.aiButton.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .panel,
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Chat/Input/Text/InputAIIcon"), action: { [weak self] in
                            Task { @MainActor in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                
                                let currentContent = chatInputContent(fromDocument: self.currentDocument, media: self.currentMedia, emojiFiles: self.currentEmojiFiles)
                                let currentPage = instantPage(from: currentContent)
                                
                                let textProcessingScreen = await component.context.sharedContext.makeTextProcessingScreen(
                                    context: component.context,
                                    theme: environment.theme,
                                    mode: .edit(
                                        saveRestoreStateId: nil,
                                        completion: { [weak self] result in
                                            guard let self else {
                                                return
                                            }
                                            let content: ChatInputContent
                                            switch result {
                                            case let .rich(instantPage):
                                                content = chatInputContent(fromInstantPage: instantPage)
                                            case let .plain(text, entities):
                                                content = chatInputContent(from: chatInputStateStringWithAppliedEntities(text, entities: entities))
                                            case .empty:
                                                return
                                            }
                                            let (document, media, emojiFiles) = documentMediaAndEmoji(fromChatInputContent: content)
                                            self.emojiKeyboard?.seedEmojiFiles(emojiFiles)
                                            self.attachedMedia.merge(media) { _, new in new }
                                            self.editor.document = document
                                        },
                                        send: nil,
                                        sendContextActions: nil
                                    ),
                                    inputText: ComposedRichMessage.rich(instantPage: currentPage),
                                    copyResult: nil,
                                    translateChat: nil
                                )
                                environment.controller()?.push(textProcessingScreen)
                            }
                        })
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            
            let sendButtonSize = self.sendButton.update(
                transition: transition,
                component: AnyComponent(GlassControlGroupComponent(
                    theme: environment.theme,
                    preferClearGlass: false,
                    background: .activeTint(inset: false),
                    items: [
                        GlassControlGroupComponent.Item(id: 0, content: .icon("Chat/Input/Text/SendIcon"), action: { [weak self] in
                            guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                                return
                            }
                            controller.donePressed()
                        })
                    ], minWidth: 44.0)
                ),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            
            let actionBarSize = self.actionBar.update(
                transition: transition,
                component: AnyComponent(RichTextActionBarComponent(
                    theme: environment.theme,
                    actions: barActions
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - (sideInset + environment.safeInsets.left) * 2.0 - actionBarSpacing * 2.0 - aiButtonSize.width - sendButtonSize.width, height: 44.0)
            )
            
            var bottomInset = max(environment.inputHeight, emojiPanelHeight, environment.safeInsets.bottom)
            
            let aiButtonFrame = CGRect(origin: CGPoint(x: sideInset + environment.safeInsets.left, y: availableSize.height - bottomInset - 6.0 - aiButtonSize.height), size: aiButtonSize)
            if let aiButtonView = self.aiButton.view {
                if aiButtonView.superview == nil {
                    self.addSubview(aiButtonView)
                }
                transition.setFrame(view: aiButtonView, frame: aiButtonFrame)
            }
            
            let sendButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - (sideInset + environment.safeInsets.left) - sendButtonSize.width, y: availableSize.height - bottomInset - 6.0 - sendButtonSize.height), size: sendButtonSize)
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.addSubview(sendButtonView)
                }
                transition.setFrame(view: sendButtonView, frame: sendButtonFrame)
            }
            
            let actionBarFrame = CGRect(origin: CGPoint(x: sideInset + environment.safeInsets.left + aiButtonSize.width + actionBarSpacing, y: availableSize.height - bottomInset - 6.0 - actionBarSize.height), size: actionBarSize)
            if let actionBarView = self.actionBar.view {
                if actionBarView.superview == nil {
                    self.addSubview(actionBarView)
                }
                transition.setFrame(view: actionBarView, frame: actionBarFrame)
            }
            bottomInset += 6.0 + actionBarSize.height + 6.0
            
            // The editor no longer tracks the keyboard; supply the bottom obstruction as a scroll inset.
            // Only one of (system keyboard / emoji panel) is up at a time (the emoji panel uses an
            // EmptyInputView, so inputHeight ≈ 0 while it shows); the home-indicator safe area is the floor.
            _ = self.editor.update(size: editorFrame.size,
                                   insets: UIEdgeInsets(top: editorTop, left: 0.0, bottom: bottomInset, right: 0.0),
                                   contentMargins: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0))

            // Top edge effect (mirrors ComposePollScreen): a blurred gradient at the screen top that content
            // fades under. Content color = the screen background (themed list.plainBackgroundColor).
            let edgeEffectHeight: CGFloat = 88.0
            let topEdgeEffectFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(content: environment.theme.actionSheet.opaqueItemBackgroundColor, blur: true, alpha: 1.0, rect: topEdgeEffectFrame, edge: .top, edgeSize: topEdgeEffectFrame.height, transition: transition)

            // While the emoji panel is up, hide the AttachmentController's bottom menu/tab bar so the
            // container collapses that panel and re-lays out this screen at full height — otherwise the
            // emoji panel renders behind the attachment menu (mirrors ComposePollScreen).
            let isTabBarVisible = !(self.emojiKeyboard?.isEmojiMode ?? false)
            if self.lastTabBarVisible != isTabBarVisible {
                self.lastTabBarVisible = isTabBarVisible
                if let controller = environment.controller() as? RichTextAttachmentScreen {
                    let tabBarTransition = transition.containedViewLayoutTransition
                    DispatchQueue.main.async { [weak controller] in
                        controller?.updateTabBarVisibility(isTabBarVisible, tabBarTransition)
                    }
                }
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

@available(iOS 13.0, *)
private final class RichTextActionContextReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    init(sourceView: UIView) { self.sourceView = sourceView }
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0), actionsPosition: .top)
    }
}
