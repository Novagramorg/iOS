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
import RichTextEditorCore
import RichTextEditorUIKit
import PhotosUI

@available(iOS 17.0, *)
public class RichTextAttachmentScreen: ViewControllerComponentContainer, AttachmentContainable {
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

    public init(context: AccountContext) {
        let overNavigationContainer = SparseContainerView()

        super.init(context: context, component: RichTextAttachmentScreenComponent(
            context: context,
            overNavigationContainer: overNavigationContainer
        ), navigationBarAppearance: .transparent, theme: .default)

        self._hasGlassStyle = true

        // Glass style: the Cancel/Done buttons are rendered by the View into
        // overNavigationContainer, so the nav item only needs an empty placeholder.
        self.navigationItem.setLeftBarButton(UIBarButtonItem(customView: UIView()), animated: false)

        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(overNavigationContainer, at: 0)
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func donePressed() {
        // TODO: produce a rich-text message from the editor and send it once the
        // RichTextEditor demo is moved in. For now Done is a placeholder that dismisses.
        self.dismiss()
    }
}

@available(iOS 17.0, *)
final class RichTextAttachmentScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    // Held for the next step: the RichTextEditor demo will read context and add
    // its editor view into the View's content container.
    let context: AccountContext
    let overNavigationContainer: UIView

    init(context: AccountContext, overNavigationContainer: UIView) {
        self.context = context
        self.overNavigationContainer = overNavigationContainer
    }

    static func ==(lhs: RichTextAttachmentScreenComponent, rhs: RichTextAttachmentScreenComponent) -> Bool {
        return true
    }

    final class View: UIView, PHPickerViewControllerDelegate {
        private let title = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
        private let contentContainer = UIView()
        
        private let editor = RichTextEditorView()

        private var component: RichTextAttachmentScreenComponent?
        private var environment: EnvironmentType?
        
        private var bar: UIView?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.contentContainer)
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

        /// An inline custom-emoji run (one U+FFFC carrying an EmojiRef) — resolved to a view by the provider.
        private func emojiRun(_ id: String, _ instance: String) -> TextRun {
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: EmojiRef(id: id, instanceID: instance, altText: ":\(id):")))
        }
        
        /// A horizontally-scrollable button bar so every command stays reachable on a phone-width screen.
        /// Buttons (and menu-buttons) don't become first responder, so the editor keeps its selection.
        private func makeToolbar() -> UIView {
            func button(_ title: String, _ action: @escaping () -> Void) -> UIButton {
                var cfg = UIButton.Configuration.gray()
                cfg.title = title
                cfg.baseForegroundColor = .label
                return UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
            }
            func menuButton(_ title: String, _ menu: UIMenu) -> UIButton {
                var cfg = UIButton.Configuration.gray()
                cfg.title = title
                cfg.baseForegroundColor = .label
                let b = UIButton(configuration: cfg)
                b.menu = menu
                b.showsMenuAsPrimaryAction = true
                return b
            }

            let buttons: [UIButton] = [
                button("B") { [weak self] in self?.editor.toggleBold() },
                button("I") { [weak self] in self?.editor.toggleItalic() },
                button("S") { [weak self] in self?.editor.toggleStrikethrough() },
                button("<>") { [weak self] in self?.editor.toggleInlineCode() },
                button("Spoiler") { [weak self] in self?.editor.toggleSpoiler() },
                menuButton("Style", styleMenu()),
                menuButton("List", listMenu()),
                button("Indent") { [weak self] in self?.editor.indent() },
                button("Outdent") { [weak self] in self?.editor.outdent() },
                menuButton("Align", alignMenu()),
                menuButton("Table", tableMenu()),
                button("Image") { [weak self] in self?.presentImagePicker() },
                button("Link") { [weak self] in self?.presentLinkPrompt() },
                menuButton("Emoji", emojiMenu()),
                button("Undo") { [weak self] in self?.editor.undo() },
                button("Redo") { [weak self] in self?.editor.redo() },
            ]

            let stack = UIStackView(arrangedSubviews: buttons)
            stack.axis = .horizontal
            stack.spacing = 8
            stack.alignment = .center
            stack.isLayoutMarginsRelativeArrangement = true
            stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
            stack.translatesAutoresizingMaskIntoConstraints = false

            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            scroll.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            ])
            return scroll
        }

        private func styleMenu() -> UIMenu {
            let names: [(String, ParagraphStyleName)] = [("Title", .title), ("Heading 1", .heading1),
                ("Heading 2", .heading2), ("Heading 3", .heading3), ("Body", .body), ("Quote", .quote)]
            return UIMenu(title: "Style", children: names.map { n in
                UIAction(title: n.0) { [weak self] _ in self?.editor.setParagraphStyle(n.1) }
            })
        }
        private func listMenu() -> UIMenu {
            UIMenu(title: "List", children: [
                UIAction(title: "None") { [weak self] _ in self?.editor.setList(nil) },
                UIAction(title: "Bullet") { [weak self] _ in self?.editor.setList(.bullet) },
                UIAction(title: "Numbered") { [weak self] _ in self?.editor.setList(.ordered) },
            ])
        }
        private func alignMenu() -> UIMenu {
            let items: [(String, TextAlignment)] = [("Left", .left), ("Center", .center), ("Right", .right), ("Justify", .justified)]
            return UIMenu(title: "Align", children: items.map { i in
                UIAction(title: i.0) { [weak self] _ in self?.editor.setAlignment(i.1) }
            })
        }
        private func emojiMenu() -> UIMenu {
            UIMenu(title: "Emoji", children: [
                UIAction(title: "Insert ★ (static)") { [weak self] _ in self?.editor.insertEmoji(id: "star", altText: ":star:") },
                UIAction(title: "Insert ◐ (animated)") { [weak self] _ in self?.editor.insertEmoji(id: "spinner", altText: ":spinner:") },
            ])
        }

        private func tableMenu() -> UIMenu {
            UIMenu(title: "Table", children: [
                UIAction(title: "Insert Table 2×2") { [weak self] _ in self?.editor.insertTable(rows: 2, cols: 2) },
                UIAction(title: "Insert Wide Table 7×3") { [weak self] _ in self?.editor.insertTable(rows: 3, cols: 7) },
                UIAction(title: "Insert Row Above") { [weak self] _ in self?.editor.insertTableRowAbove() },
                UIAction(title: "Insert Row Below") { [weak self] _ in self?.editor.insertTableRowBelow() },
                UIAction(title: "Delete Row") { [weak self] _ in self?.editor.deleteTableRow() },
                UIAction(title: "Insert Column Left") { [weak self] _ in self?.editor.insertTableColumnLeft() },
                UIAction(title: "Insert Column Right") { [weak self] _ in self?.editor.insertTableColumnRight() },
                UIAction(title: "Delete Column") { [weak self] _ in self?.editor.deleteTableColumn() },
                UIAction(title: "Align Column Left") { [weak self] _ in self?.editor.setTableColumnAlignment(.left) },
                UIAction(title: "Align Column Center") { [weak self] _ in self?.editor.setTableColumnAlignment(.center) },
                UIAction(title: "Align Column Right") { [weak self] _ in self?.editor.setTableColumnAlignment(.right) },
            ])
        }

        // MARK: Phase 5b — image picker + link prompt

        private func presentImagePicker() {
            guard let component = self.component else {
                return
            }
            
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            
            component.context.sharedContext.mainWindow?.presentNative(picker)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self?.editor.becomeFirstResponder()
                    self?.editor.insertImage(image, naturalSize: image.size)
                }
            }
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

        func update(component: RichTextAttachmentScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            if self.component == nil {
                let table = TableBlock(id: BlockID("t"),
                    columns: [ColumnSpec(width: 140), ColumnSpec(width: 110), ColumnSpec(width: 110)],
                    rows: [
                        Row(id: BlockID("r0"), isHeader: true, cells: [textCell("h0", ["Name"]), textCell("h1", ["Mass (suns)"]), textCell("h2", ["Distance"])]),
                        Row(id: BlockID("r1"), cells: [
                            Cell(id: BlockID("c0"), blocks: [.paragraph(ParagraphBlock(id: BlockID("c0p"),
                                runs: [TextRun(text: "Sagittarius A* "), emojiRun("spinner", "cell-spin")]))]),
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
                    ])
                editor.document = Document(
                    metadata: DocumentMetadata(title: "Into the Dark", createdAt: Date(timeIntervalSince1970: 0),
                                               modifiedAt: Date(timeIntervalSince1970: 0)),
                    blocks: [
                        .paragraph(ParagraphBlock(id: BlockID("title"), style: .title, runs: [TextRun(text: "Into the Dark")])),
                        .paragraph(ParagraphBlock(id: BlockID("intro"), runs: [
                            TextRun(text: "Black holes "), emojiRun("spinner", "intro-spin"),
                            TextRun(text: " are the strangest objects we know "), emojiRun("star", "intro-star"),
                            TextRun(text: ". Places where gravity pulls so hard that not even light escapes."),
                        ])),
                        .paragraph(ParagraphBlock(id: BlockID("spoilerDemo"), runs: [
                            TextRun(text: "Tap to reveal: "),
                            TextRun(text: "this is a hidden spoiler", attributes: CharacterAttributes(spoiler: true)),
                        ])),
                        .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Three things to know")])),
                        .paragraph(ParagraphBlock(id: BlockID("l0"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "Form when massive stars collapse")])),
                        .paragraph(ParagraphBlock(id: BlockID("l1"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "The point of no return is the event horizon")])),
                        .paragraph(ParagraphBlock(id: BlockID("l2"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "Time slows as you approach one")])),
                        .paragraph(ParagraphBlock(id: BlockID("q"), style: .quote, runs: [TextRun(text: "Black holes are where the universe stops making sense. They bend time, swallow light, and remind us how little we really understand.")])),
                        .paragraph(ParagraphBlock(id: BlockID("famous"), style: .heading1, runs: [TextRun(text: "Famous black holes")])),
                        .table(table),
                        .paragraph(ParagraphBlock(id: BlockID("wide"), style: .heading1, runs: [TextRun(text: "Wide table (horizontal scroll)")])),
                        .table(wideTable),
                        .paragraph(ParagraphBlock(id: BlockID("end"), runs: [TextRun(text: "")])),
                    ])

                editor.registerEmojiViewProvider { id, size in
                    switch id {
                    case "spinner":
                        let v = UIView(frame: CGRect(origin: .zero, size: size))
                        v.backgroundColor = .clear
                        let dot = CALayer()
                        dot.frame = CGRect(x: size.width * 0.15, y: size.height * 0.15,
                                           width: size.width * 0.7, height: size.height * 0.7)
                        dot.cornerRadius = dot.frame.width / 2
                        dot.backgroundColor = UIColor.systemPurple.cgColor
                        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                        spin.fromValue = 0; spin.toValue = 2 * Double.pi
                        spin.duration = 1.0; spin.repeatCount = .infinity; spin.isRemovedOnCompletion = false
                        dot.add(spin, forKey: "spin")
                        v.layer.addSublayer(dot)
                        return v
                    default: // a static colored square ("star")
                        let v = UIView(frame: CGRect(origin: .zero, size: size))
                        v.backgroundColor = .systemYellow
                        v.layer.cornerRadius = 3
                        return v
                    }
                }

                let bar = makeToolbar()
                self.bar = bar
                bar.translatesAutoresizingMaskIntoConstraints = true
                editor.translatesAutoresizingMaskIntoConstraints = false
                self.addSubview(bar)
                self.addSubview(editor)
            }
            self.component = component

            let barButtonSize = CGSize(width: 44.0, height: 44.0)

            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                            return
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    component.overNavigationContainer.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }

            //TODO:localize
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: nil,
                    backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .tintedGlass,
                    isEnabled: true,
                    component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                        Text(text: "Done", font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? RichTextAttachmentScreen else {
                            return
                        }
                        controller.donePressed()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: barButtonSize.height)
            )
            let doneButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - doneButtonSize.width, y: 16.0), size: doneButtonSize)
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    component.overNavigationContainer.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
            }

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
            var titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if titleFrame.maxX > doneButtonFrame.minX - 16.0 {
                titleFrame.origin.x = cancelButtonFrame.maxX + floorToScreenPixels((doneButtonFrame.minX - cancelButtonFrame.maxX) - titleSize.width) / 2.0
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    component.overNavigationContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }

            // Content region (editor seam) — empty in this step.
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.navigationHeight), size: CGSize(width: availableSize.width, height: max(0.0, availableSize.height - environment.navigationHeight)))
            transition.setFrame(view: self.contentContainer, frame: contentFrame)
            
            self.backgroundColor = .white
            
            if let bar = self.bar {
                bar.frame = CGRect(origin: CGPoint(x: environment.safeInsets.left, y: environment.navigationHeight), size: CGSize(width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right, height: 50.0))
            }
            self.editor.frame = CGRect(origin: CGPoint(x: environment.safeInsets.left, y: environment.navigationHeight + 50.0), size: CGSize(width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right, height: availableSize.height - 50.0 - environment.navigationHeight - environment.safeInsets.bottom))

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
