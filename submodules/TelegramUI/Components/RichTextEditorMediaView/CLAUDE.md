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
- **Non-interactive today** — `isUserInteractionEnabled = false`. The component is a plain `Component`
  precisely so interaction + composition land later without structural change (see Future iterations).
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
- **Interaction:** tap / long-press (open / preview / context menu) on `RichTextMediaContentComponent`.
- **Mosaic / slideshow:** a separate composing component that lays out several
  `RichTextMediaContentComponent`s (grouped media). The single-medium component is built composable —
  no editor-seam coupling — specifically so this wrapper can reuse it directly.

## History

The photo/video renderer was extracted from the shared `InstantPageImageNode` path into the standalone
`RichTextMediaContentComponent` on 2026-06-29 (build-green + runtime-verified on iPhone 17). Location and
audio were intentionally left on the `StandaloneInstantPage*` views. (Per the RichTextEditor convention,
the per-phase design spec/plan are not retained in-tree — this file is the durable record.)
