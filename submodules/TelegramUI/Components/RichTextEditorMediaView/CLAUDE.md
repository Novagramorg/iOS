# RichTextEditorMediaView — module guide

Host-side renderers for media (photo / video / location / audio) embedded in the **RichText editor**
(`submodules/TelegramUI/Components/RichTextEditor`, behind the `debugRichText` flag). The editor owns a
narrow seam — `RichTextMediaItemView` (a `UIView` with `update(size:)`) — and resolves each `.media`
block to one of these views via a host-registered provider, then positions/sizes/culls it
(`DocumentCanvasView+Media.syncMediaItemViews`). This module supplies the concrete views; it depends on
`AccountContext`/`TelegramCore` (so it can't live inside the editor package, which is account-free).

## Types

- **`MediaItemNodeView`** — the `RichTextMediaItemView` adapter + **3-way dispatcher** by media kind,
  created once per media occurrence at three call sites (`RichTextAttachmentScreen`, `ChatControllerNode`,
  `ChatInterfaceStateInputPanels`). Accepts a `cornerRadius: CGFloat = 0` init param: when > 0 and the
  audio branch was NOT taken, sets `layer.cornerRadius` + `masksToBounds` on the container (child fills
  bounds, so the rounded rect clips it). Photo/video/location round to 10pt at the two composer call
  sites; audio stays square (check is `audioView == nil`); `RichTextAttachmentScreen` (article editor)
  leaves the default 0 and stays square.
  - **audio** (`.file` && (`isMusic` || `isVoice`)) → `StandaloneInstantPageAudioView` (a playable,
    themeable row; `audioColorOverride` themes it to the editor accent/text scheme).
  - **location** (`.geo`) → `StandaloneInstantPageImageView` + an `InstantPageMapAttribute`
    (600×300, zoom 15) — the InstantPage `.geo` snapshot+pin path.
  - **photo / video** (everything else, incl. image-mime `.file`) → **`RichTextMediaContentComponent`**
    hosted in a `ComponentHostView<Empty>`.
- **`RichTextMediaContentComponent`** — the composable ComponentFlow renderer for **one** still/video
  poster. Owns its own `TransformImageNode` + media-fetch signal + aspect-fill layout + (video) a static
  `RadialStatusNode.play(.white)` overlay, **decoupled from `InstantPageImageNode`**. Signal sources match
  the old shared path: `.image` → `chatMessagePhoto` (+`chatMessagePhotoInteractiveFetched`); image-mime
  `.file` → `instantPageImageFile` (+`freeMediaFileInteractiveFetched`); video `.file` → `chatMessageVideo`.

## Load-bearing invariants

- **`RichTextMediaContentComponent.==` compares identity only** (`context ===` + `media.id`), NOT any
  per-layout value. The editor calls `update(size:)` every layout pass; equality must hold across resizes
  so the fetch signal is **bound once** (a `didBind`/`boundMediaId` guard in the `View`). Comparing a
  changing value here would re-issue the fetch every pass → flicker / wasted fetches.
- **Interaction is control-scoped via `hitTest` — the poster passes through to the editor.** The component
  now carries interactive chrome (a glass "more" button); to make it tappable WITHOUT stealing the editor's
  own taps (caret placement / media-select highlight), the whole media path is a **hit-test pass-through**:
  - `RichTextMediaContentComponent.View.hitTest` returns the button ONLY when the touch lands on it (routed
    through the button's `GlassBackgroundContainerView`, whose own `hitTest` is already control-or-nil), else
    `nil`. **Add any future controls to this override** — do NOT rely on `isUserInteractionEnabled` alone.
  - `MediaItemNodeView.hitTest` forwards into the photo/video `contentHost` and returns the control, or `nil`
    for the poster area and for the audio/location branches entirely (those stay non-interactive as before).
    Standard visibility/`point(inside:)` guards keep a culled (hidden) media view from claiming a touch.
  - Editor side (`RichTextEditor` module): `mediaOverlay` is a **`MediaPassthroughOverlayView`** (interactive,
    but `hitTest` returns `nil` unless a media view claims the touch), and the canvas's recognizers yield to a
    claimed touch via `gestureRecognizer(_:shouldReceive:)` (→ the media control gets a clean, un-cancelled
    touch). The contract is: *"if the media view returns anything from `hitTest`, leave it be; otherwise run
    the editor's default tap logic."* The button ACTION (`moreButtonPressed`) is still an empty stub — the
    plumbing lands first.
- **Aspect-FILL** (`dimensions.cgSize.aspectFilled(availableSize)`) — the editor already sizes the host
  rect to the media aspect (so fill == exact fit), and fill is the right primitive for future mosaic
  cropping. `emptyColor` placeholder = `theme.list.mediaPlaceholderColor`.
- **View-frame ownership** (repo-wide rule): the component lays out against `bounds`; the editor owns the
  view's frame via `update(size:)`. `MediaItemNodeView` only frames its single child to its own `bounds`.
- Audio is **caption-less** in the editor model; location/audio rendering is byte-unchanged from the
  pre-component implementation (only the photo/video branch was rewritten).

## Future iterations (planned, not yet implemented)

- **Higher-quality video poster.** Video currently shows the file's small embedded thumbnail (via
  `chatMessageVideo` — same source as the old `InstantPageImageNode` path; runtime-confirmed low-res
  2026-06-29). A future pass should load a larger representation or a generated frame for the poster.
- **Interaction:** the hit-test plumbing is in place (taps reach the component's controls — see the
  interaction invariant above); still to wire are the actual actions — the "more" button menu
  (`moreButtonPressed` is an empty stub) and tap / long-press (open / preview / context menu).
- **Mosaic / slideshow:** a separate composing component that lays out several
  `RichTextMediaContentComponent`s (grouped media). The single-medium component is built composable —
  no editor-seam coupling — specifically so this wrapper can reuse it directly.

## History

The photo/video renderer was extracted from the shared `InstantPageImageNode` path into the standalone
`RichTextMediaContentComponent` on 2026-06-29 (build-green + runtime-verified on iPhone 17). Location and
audio were intentionally left on the `StandaloneInstantPage*` views. (Per the RichTextEditor convention,
the per-phase design spec/plan are not retained in-tree — this file is the durable record.)
