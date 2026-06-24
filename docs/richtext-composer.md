# Rich-text chat composer & `ChatInputContent`

The app-side rich-text **input** story: the WYSIWYG editor, the `ChatInputContent` value model that
replaced `NSAttributedString` as the composer currency, and the round-trips through send / edit / drafts /
cross-device sync.

**Authority boundaries** — this file is the app-integration reference. For:
- **editor internals** (TextKit seam, layout, boxes) → `submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md`.
- **message rendering** (InstantPage V2, rich bubbles) → [`docs/instantpage-richtext.md`](instantpage-richtext.md).

The editor is gated behind the `debugRichText` flag; the **native** engine is the rich path, the **legacy**
`UITextView` node is the production fallback (a lossy filter — see below).

---

## 1. The editor

A from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`), developed as an
in-tree **SwiftPM package** and wired into the app: `ChatTextInputPanelNode` depends on `:RichTextEditorUIKit`,
so it builds under Bazel at the repo's iOS-13 floor. Core (`:RichTextEditorCore`) is pure-Foundation.

- **TextKit is quarantined behind `protocol BlockLayoutEngine`:** `BlockLayout` (TextKit 2, `@available(iOS 16)`)
  on iOS 16+, `BlockLayoutTK1` (TextKit 1) on iOS 13–15, chosen by `makeBlockLayout(...)` /
  `BlockLayoutBackend.forceTextKit1`. Higher-OS APIs kept at their genuine floor: TK2 + `UIEditMenuInteraction`
  at 16, loupe (`UITextLoupeSession`) + inline predictions at 17, Translate at 17.4, `isEditable` at 18. **TK1
  trade-offs (iOS 13–15, deliberate):** no spoiler text-hiding, loupe, or inline predictions.
- **The system edit menu** falls back `UIEditMenuInteraction` (16+) → `UIMenuController` (13–15). iOS 13–15 keeps
  the editor's built-in menu (`UIMenuController` can't carry closure-backed items).
- **Bundled resource (spoiler texture) is build-system-split** behind `#if SWIFT_PACKAGE`: SwiftPM uses
  `.module`; Bazel uses the app's `AppBundle` (`UIImage(bundleImageName: "Components/TextSpeckle")`,
  `//submodules/AppBundle` dep).
- **Parent-driven API:** `RichTextEditorView.update(size:insets:) -> CGFloat` (parent supplies scroll insets,
  returns measured height), payload-free `onChange`, `currentState() -> EditorState`, `deleteTable()`,
  `makeCodeBlock()`, `registerMediaViewProvider`. The host `RichTextAttachmentScreen` (separate module) drives
  layout from `onChange` and owns a bottom action bar (`RichTextActionBarComponent`).

> **Invariant — a view does not own its `frame`.** Editor/component `update(...)` reads `self.bounds` and lays
> out subviews; it never writes `self.frame` (the parent chose it). See the "View frame ownership" note in the
> root `CLAUDE.md`.

---

## 2. `ChatInputContent` — the composer currency

`ChatInputContent` (`submodules/TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift`) is a
purpose-built, TelegramCore-native **value model** that replaced `NSAttributedString` as the chat composer's
currency. It is a block/run tree mirroring the editor `Document` 1:1:

- **Blocks:** `.paragraph` (body / heading1-3 / quote, + optional `list` membership), `.code`,
  `.collapsedQuote(ChatInputContent)`, `.media(ChatInputMedia)`, `.table(ChatInputTable)`.
- **Inline runs:** bold / italic / mono / strike / underline / spoiler + entity mention / url / date /
  `customEmoji(fileId:file:enableAnimation:)`.
- **Selection** is a recursive tree-path (`ChatInputPathStep{blockIndex,slot}` / `ChatInputPosition{path,offset}`
  / `ChatInputSelection{start,end}`) — chosen for nested quotes + collapsible blocks — with a content-aware
  flat↔structural bridge (`position(forFlatOffset:)` / `flatOffset(for:)` / `nsRange(in:)` / `init(nsRange:in:)`).

Conversions:
- **Display-neutral TextFormat utility** (`Sources/ChatInputContentConversion.swift`): `chatInputContent(from:)`
  / `attributedString(from:)`, round-trip-identity tested in `//submodules/TextFormat:TextFormatTests`.
- **Direct editor bridge** (`ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`):
  `Document ↔ ChatInputContent`, used by the native node — it **bypasses the `NSAttributedString` hop** where
  structural blocks (media/table/heading/list) would be flattened.

### Load-bearing invariants

- **`ChatTextInputState.==` is value-based** (`submodules/AccountContext/Sources/ChatController.swift`):
  fast-path on `selectionRange` + `inputText.isEqual(to:)`, else compare `chatInputContent(from:)` value models.
  This is strictly coarser-or-equal to the old reference equality (can only remove churn). **Scoped to the state
  type (Design A)** — *not* a global value-based `ChatTextInputTextCustomEmojiAttribute.isEqual`, which lives in
  ~90 files incl. message rendering.
- **`.media` / `.table` are off the flat axis** (`blockIsFlatParticipating`) across `plainText` /
  `blockFlatLength` / `flatOffset` / `position(forFlatOffset:)`, so the invariant `plainText ==
  attributedString(from:).string` holds. Violating it drifts the native caret past non-text blocks.
  `.collapsedQuote` legitimately *is* one flat placeholder char.
- **Custom emoji occupies its alt-string's UTF-16 length in the composer flat space** (the editor's
  `composerSelectedRange` / `composerParagraphs`), matching the content and the legacy seam — else the caret
  drifts past custom emoji.
- **Codable (drafts) goes through `AdaptedPostbox{En,De}coder`, which supports NO `singleValueContainer` and NO
  bare `Int`.** So enum discriminators are explicit `Int32` rawValues (never `encode(SomeEnum.case)`), and all
  numbers are explicit `Int32`/`Int64`. Test the model Codable via `AdaptedPostboxEncoder` (a JSON round-trip
  masks this). The polymorphic `Media` persists via a concrete-type discriminator + `TelegramMediaImage/File(decoder:)`,
  **not** `decodeRootObjectWithHash` (that needs the app-startup `declareEncodable` registry, empty in tests).

`isEntityExpressible(options:)` is the routing switch: text / quote / collapsed-quote / code / mention / date /
custom-emoji-in-body are entity-expressible (normal text+entities path); heading / list / table / media are
not (→ structured `.instantPage` path). The `EntityExpressibleOptions` bag narrows this: with
`.quotesRequireRichContent`, a `.quote` paragraph and a `.collapsedQuote` are treated as NOT entity-expressible,
so quote-bearing content routes onto the rich path even though entities could represent it (opted into by the
send-options preview and the attachment-menu rich-editor send — see §5).

---

## 3. Composer ↔ editor wiring

- **Node selection** (`ChatTextInputPanelNode`): `richTextInputNode` is the native node
  (`RichTextEditorChatInputNode`, `usesNativeRichTextEngine == true`) under `debugRichText`, else the legacy
  `UITextView` node (`ChatRichTextInputNodeImpl`).
- **GET** (`inputTextState`): returns `ChatTextInputState(content: richTextInputNode.currentInputContent().content, …)`
  **directly** — no `NSAttributedString` round-trip, so native structural blocks survive. For the legacy node the
  content is always flat, so it's identical to the old path.
- **SET** (`setInputContent`): the chat layer routes content-set sites through the node. The native node lands
  structural blocks straight into the editor `Document` (registering media/emoji so a later GET resolves them);
  the **legacy node is a render-only lossy filter** — `attributedString(from:)` drops media/table and renders
  heading/list as plain text.
- **Legacy node owns its decoration:** `applyRenderingConfig(...)` + `setInputContent` + `currentInputContent`,
  per-keystroke `decorateAfterTextChange`, spoiler-reveal (`updateSpoilersRevealed`, 1.5 s hide + dust
  cross-fade), paste/plain-fragment (`decorateReplacementFragment`). The panel no longer calls
  `refreshTextInputAttributes` / `prepareForSpoilerReveal` etc. Theme-change re-color routes through
  `decorateAfterTextChange` (correct per-attribute colors + overlay rebuild — a naive full-range
  `foregroundColor` rewrite reveals custom-emoji / unrevealed-spoiler base glyphs).
- **Expand / collapse is routed through `ChatInterfaceState`, not the node** (`ChatControllerNode.openExpandedInput`):
  OUT converts the live `inputTextState.content` → `(Document, media, emojiFiles)` to seed
  `RichTextAttachmentScreen`; IN converts the editor's `(document, media, emojiFiles)` → `ChatTextInputState`
  applied via `updateChatPresentationInterfaceState` + `withUpdatedEffectiveInputState` (the `openAICompose`
  precedent — one value seen by undo/drafts/send/observers). Thin converters:
  `ChatRichTextEditorComposer/Sources/ComposerExpandedEditorBridge.swift`. Custom-emoji **files** (`[Int64:
  TelegramMediaFile]`) and media are threaded both ways (a fileId-only emoji ref renders blank).

> **Invariant — the cycle constraint.** `InstantPageUI` transitively deps `ChatTextInputPanelNode`, so the
> panel/node **cannot** dep `InstantPageUI` / `RichTextEditorMediaView`. `TelegramUI` (above the cycle) builds
> the inline-media view (`RichTextEditorMediaView.MediaItemNodeView`) and **injects a `mediaItemViewFactory`
> closure** into the panel at its construction sites; media crosses the protocol as `EngineMedia` (keeping the
> node Postbox-free).

> **Invariant — the `Display.Window1.hitTest` "EditMenu" match** is load-bearing for the iOS-16 edit menu:
> without it the menu's taps fall through to content app-wide.

---

## 4. Feature round-trips

All inline / structural features round-trip losslessly through the native composer; the markers live in shared
`TextFormat` codecs so live-edit, send, copy, and paste agree.

- **Formatting menu (iOS 16+):** the composer's **Format** submenu (Bold/Italic/Monospace/Link/Strikethrough/
  Underline/Quote/Spoiler/Date/Code, secret-chat gated) is spliced into the editor's edit menu via
  `RichTextEditorView.contextMenuItemsProvider`. Actions route to the native engine; **Link** through the host
  `openLinkEditing`; **Code** creates a first-class code block; **Date** is a deferred no-op (the editor lacks
  only a timestamp-creation UI).
- **Custom emoji / mention / date:** carried by `ComposerDocumentBridge` (live) + the direct bridge. Custom
  emoji = one `U+FFFC` with the alt-string on `EmojiRef.altText` (emitted **as the run text** under the entity on
  send — a bare `U+FFFC` otherwise reaches the wire). Mentions / dates encode into the shared `link` field via
  `tg://user?id=` / `tg://timestamp?t=` markers (`TextFormat/MentionDateMarkers.swift`:
  `mentionMarkdownURL` / `dateMarkdownURL` / `classifyChatLink` / `chatInputLinkAttribute`). **Accepted
  limitation:** a `textUrl` whose string equals a `tg://` marker (via markdown/paste/edit) is reinterpreted as a
  mention/date on round-trip — low-probability, documented in `MentionDateMarkers.swift`.
- **Code blocks:** first-class multi-line `Block.code` (Core `CodeBlock` + `CodeBlockBox`), reusing the
  newline-agnostic position model. Markers in `TextFormat/CodeBlockMarkers.swift`; entity-expressible (`.Pre`).
  Enter inserts an interior newline (exits on an empty trailing line), backspace in an empty block un-codes it.
  Multi-line quotes also emit **one contiguous blockquote** on send. **Deferred:** language picker (creation
  sets `language = nil`; incoming language round-trips), code in table cells, inline formatting inside code.
- **Inline media:** an attached image/video renders inline in the native composer and survives expand↔collapse
  + drafts, carried by `ChatInputContent.media`. The concrete view is the shared
  `RichTextEditorMediaView.MediaItemNodeView` (also used by the article editor), resolved via the injected
  factory (§3).

---

## 5. Send / edit / pending display of rich messages

Rich content that the entity set can't express (heading/list/table/media, and structured combinations) is sent
as a **`RichTextMessageAttribute`** carrying an `InstantPage`, rendered by the V2 path (see
`instantpage-richtext.md`). The `ChatInputContent ↔ InstantPage` pair lives in
`TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift`.

- **Send** (`ChatControllerNode.sendCurrentMessage`): reads the structural `composeInputState.content`. When
  `editMessage == nil && !content.isEntityExpressible() && !content.isEmpty`, enqueues **one**
  `.message(text: "", attributes: [RichTextMessageAttribute(instantPage: instantPage(from: content), …)], …)`.
  Entity-expressible content keeps the existing `breakChatInputText` text+entities loop **byte-identical**. The
  custom-emoji premium-lock harvest + early-return stays **before** the branch.
- **Edit** (`ChatControllerLoadDisplayNode`): LOAD seeds `ChatTextInputState(content: chatInputContent(fromInstantPage:
  richTextAttribute.instantPage))` (structural, media preserved — *not* a markdown flatten); DONE routes by
  `isEntityExpressible()` — non-entity → rebuild `RichTextMessageAttribute` + pass `richText:` (so the backend
  uploads media), else demote to plain text+entities. Native path only (the legacy composer flattens structure
  on the first keystroke).
- **Attachment-menu rich editor** (`ChatControllerOpenAttachmentMenu`'s `.richText` send →
  `composeRichMessage(from:media:forSendPreview:)` in `RichTextEditorMessageConversion`): passes
  `forSendPreview: true`, so a **blockquote forces the rich (InstantPage) path here** even though a quote is
  entity-expressible (`documentNeedsRichLayout` honors the same flag at the editor-`Document` level). The composer
  Send / Edit gates above pass **default** options, so a quote sent from the composer is still plain text + a
  blockquote entity — a deliberate, localized divergence (this rich-editor send has no long-press preview; the
  composer's preview opts into the same quote-as-rich rule, below).
- **Pending edits display optimistically:** `ChatUpdatingMessageMedia` carries an optional `richText`; the
  bubble prefers `itemAttributes.updatingMedia.map(\.richText) ?? item.message.richText` (display `:360`,
  anchor `:1449`, "Show more" gate `:567` in `ChatMessageRichDataBubbleContentNode`). The render-cache key
  (`ensurePageView` / `currentPageLayout`) includes a **pending-edit discriminator**
  (`(updatingMedia?.richText).map { ObjectIdentifier($0) }`) because `stableVersion` doesn't bump during a
  pending edit; and `PendingUpdateMessageManager.add` **publishes immediately** (a media-bearing rich edit
  swallows upload progress, so the optimistic value must be visible before the upload finishes).

### Rich-message media on the wire

The media-less serializer `RichTextMessageAttribute.apiInputRichMessage()` (`photos:/documents: nil`) is **only
the fallback** (nil / secret-chat / empty-media / upload-failure). The real paths upload + assemble:

- `richMessageContentToUpload` → `assembleInputRichMessage` (`PendingMessageUploadedContent.swift`) fill
  `photos`/`documents` (already-cloud media short-circuits to cloud IDs); `uploadedRichMessage(...)` is the thin
  single-emission (`take(1)`) resolver.
- **Send** routes through `messageContentToUpload` → uploads. **Edit** sequences `uploadedRichMessage` before its
  media chain. **Incoming parse** (`SyncCore_RichTextMessageAttribute.swift`) reconstructs `media` from
  `photos`/`documents`.

### Send-options preview (long-press Send)

Long-pressing **Send** opens the send-options context screen (`ChatSendMessageContextScreen`), whose preview
bubble renders the message as it will be sent. For rich content the bubble shows the actual `InstantPage` via
`ChatSendMessageRichTextPreview` (wrapping an `InstantPageV2View` in the outgoing message theme), injected through
the `ChatSendMessageContextScreenRichTextPreview` protocol (mirroring the existing media-preview seam, since
`ChatSendMessageActionUI` cannot dep `InstantPageUI`).

- **Gating mirrors the real send paths**, built in `Chat/ChatMessageDisplaySendMessageOptions.swift` via the
  file-private `makeRichTextSendPreview(context:content:mediaPreview:)` (predicate: `mediaPreview == nil &&
  !content.isEmpty && !content.isEntityExpressible(options: [.quotesRequireRichContent])`). New-message branch feeds
  `composeInputState.content` (matching `ChatControllerNode`'s send gate; additionally skipped for
  `.customChatContents`); edit branch feeds `editMessage.inputState.content` (matching `ChatControllerLoadDisplayNode`'s
  edit gate). Plain / quote-free entity-expressible content keeps the flat-text morph. With the legacy composer,
  content is always flat → entity-expressible → no preview (so no `debugRichText` check is needed).
- **A blockquote previews as a rich bubble** (the `.quotesRequireRichContent` opt-in), even though the composer
  Send / Edit gates send a quote as plain text + a blockquote entity (they pass default options — see the
  divergence note above). So a quote-only message's preview bubble (InstantPage) renders through a different path
  than the eventually-sent message; align the two by passing `.quotesRequireRichContent` at those gates too if a
  pixel-faithful preview is wanted.
- **Morph (`MessageItemView`):** the plain-text path morphs a flat-text copy of the live field into the bubble.
  That copy can't represent rich structure (headings/lists/tables), so the rich path instead captures a **pixel
  snapshot** of the live input field on the source-state layout (before the screen hard-hides the field), positions
  it to overlay the field exactly (top-left at `(textInsets.left, 2.0)`, matching the screen's
  `sourceMessageItemFrame` math), and crossfades that snapshot into the `InstantPageV2View` as the bubble settles.
  Falls back to the flat-text crossfade if `snapshotView` returns nil.
- **Flat-copy text color is set per morph state**, keyed off `explicitBackgroundSize == nil` (`isSettled`): the
  extracted `textString` carries no base foreground color that renders correctly here (the preview node defaults it
  to **black**), so `MessageItemView` applies one explicitly and re-applies it whenever the state flips (tracked by
  `textNodeUsesOutgoingColor`). Settled (inside the outgoing bubble) → `chat.message.outgoing.primaryTextColor`;
  source / animate-out (the copy overlaying the live field) → `chat.inputPanel.inputTextColor`, so the copy matches
  the still-visible field. This is why a colored outgoing bubble shows the right color (e.g. white) instead of black,
  and why the dark-theme animate-out doesn't fall back to black. Link entities stay `outgoing.linkTextColor` in both
  states.
- **Clipping:** the page content is clipped to the bubble's inner corner radius (15pt, matching the real rich
  bubble's `image.defaultCornerRadius`) within the tail-excluded content rect `[1, width − 7]` (same as the text
  path), so images/tables round to the bubble and stay clear of the outgoing tail.

---

## 6. Draft persistence

Two layers (see `SyncCore_SynchronizeableChatInputState.swift`, `ChatInterfaceState.swift`):

- **Local** — `ChatTextInputState` persists `ChatInputContent` under the `"cm"` Codable key (back-compat-decoding
  the legacy `"at"` `ChatTextInputStateText`). So a rich draft (incl. media, via the concrete `Media`) survives an
  app restart on-device.
- **Cloud / cross-device** — `ChatInterfaceState.synchronizeableInputState` produces a
  `SynchronizeableChatInputState.Content`: `.textEntities(text,entities)` for entity-expressible content,
  `.instantPage(InstantPage)` otherwise. `ManagedSynchronizeChatInputStateOperations` builds `messages.saveDraft`.

> **Invariant — `ChatInterfaceState.parse` always overrides `composeInputState` from the flat synchronizeable
> form, but does NOT override `editMessage.inputState`.** So the `"cm"` local Codable is redundant-but-harmless
> for the composer yet load-bearing for the **edit-message** draft (preserves structure the fragmenting `"at"`
> round-trip would lose).

> **Invariant — `saveDraft` sends `message: ""` / no entities (clears the `1<<3` flag) when `richMessage` is
> set.** The InstantPage already carries the text; the receiver builds the draft **purely** from `richMessage`
> when present (`AccountStateManagementUtils` ignores `message`/`entities`), so sending the flat text duplicates
> it on the wire.

### Cross-device media sync

The cloud draft uploads its inline media (the last media-less path, now closed). Driven by the account's
**`MessageMediaPreuploadManager`, made lifecycle-aware**: `add(...)` returns a `Disposable` (a ref-counted
"need" reusing the existing `subscribers: Bag`); the last released need starts a **1 s grace timer** that
cancels + evicts the upload unless re-added; a live/in-grace context is reused, never restarted (this also
fixes a context leak — `LegacyLiveUploadInterface` holds its token until `deinit`). `synchronizeChatInputState`
resolves the rich message through `uploadedRichMessage` and holds a per-peer need on each local draft file
resource (reconciled per save, **add-before-dispose** so a surviving resource never drops to 0 holders), so the
bytes upload **once** and are shared with the eventual send. Images de-dup via the content-hash
`cachedSentMediaReference` cache (not registered).

### Re-login restore

On a fresh login the server delivers each chat's draft in the **dialog `draft` field** (`getDialogs`), not as an
`updateDraftMessage`. Drafts (rich included) restore via the shared parser
`_internal_synchronizeableChatInputState(accountPeerId:peerId:apiDraft:)` (`Sources/State/RestoreFetchedDrafts.swift`,
also called by the incremental `updateDraftMessage` path) + `_internal_applyFetchedChatInputStates`, wired into
`ResetState` (login) and `fetchChatListHole` (live session) after `updatePeers`.

> **Invariant — newer-wins, never-clear.** A fetched draft is applied only if there's no local draft OR its
> `date` is strictly newer than the local `synchronizeableInputState.timestamp` (so a live edit is never
> clobbered). Only non-empty `.draftMessage` drafts are collected (a fetch never clears; clearing stays with the
> real-time path). A pinned chat's draft appears in both the remote and pinned responses — the duplicate is
> deduped by the idempotent newer-wins guard, **not** explicitly, so don't drop the strict-`>` guard.

---

## 7. Accepted limitations & deferred work

- **Cross-device collapsed-quote fidelity:** the MTProto `Api.RichMessage`/`InputRichMessage` has no `collapsed`
  flag, so the three model quote states collapse to one on the wire (`.quote(isCollapsed:false)` /
  `.collapsedQuote` are round-trip identity; `.quote(isCollapsed:true)` normalizes to `.collapsedQuote`; `nil`/
  `false` → visible quote — required, else every synced quote would fold).
- **Custom-emoji `enableAnimation`** has no `RichText` carrier, so it canonicalizes to `true` on the reverse
  (re-derived at decoration; pinned by `test_customEmoji_enableAnimationFalse`).
- **Forum/monoforum topic drafts** and **folder/archived dialog drafts** are not restored on the `fetchChatList`
  path (separate paths; archived drafts restore when that folder is fetched).
- **Date creation** in the composer is a no-op (preservation only — an incoming date round-trips).
- **Code blocks:** no language picker; no code inside table cells; no inline formatting inside code.
- The `SynchronizeableChatInputState.Content.instantPage` cloud branch is exercised today only by structural
  blocks; everything entity-expressible takes `.textEntities`.

## Key files

| Concern | Path |
|---|---|
| value model + Codable | `TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift` |
| display-neutral conversion | `TextFormat/.../ChatInputContentConversion.swift` |
| `ChatInputContent ↔ InstantPage` | `TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift` |
| direct editor bridge | `Chat/ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift` |
| live / send / expand bridges | `ChatRichTextEditorComposer/Sources/{ComposerDocumentBridge,ComposerExpandedEditorBridge}.swift` |
| markers (mention/date, code) | `TextFormat/.../MentionDateMarkers.swift`, `CodeBlockMarkers.swift` |
| native node | `Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` |
| panel (GET/SET, node select) | `Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` |
| state value-equality | `AccountContext/Sources/ChatController.swift` |
| send / edit | `TelegramUI/Sources/ChatControllerNode.swift`, `Chat/ChatControllerLoadDisplayNode.swift` |
| rich attribute + wire | `TelegramCore/Sources/SyncCore/SyncCore_RichTextMessageAttribute.swift` |
| upload + assemble | `TelegramCore/Sources/PendingMessages/PendingMessageUploadedContent.swift` |
| draft persistence | `TelegramCore/Sources/SyncCore/SyncCore_SynchronizeableChatInputState.swift`, `ChatInterfaceState/Sources/ChatInterfaceState.swift` |
| cloud draft sync + media | `TelegramCore/Sources/State/ManagedSynchronizeChatInputStateOperations.swift`, `State/MessageMediaPreuploadManager.swift` |
| re-login restore | `TelegramCore/Sources/State/RestoreFetchedDrafts.swift` |
