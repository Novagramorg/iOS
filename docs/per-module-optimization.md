# Per-module -O and pixel loops

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Per-module `-O` and pixel loops

Almost every submodule builds `-Onone` under `--configuration=debug_*`. Exactly **two** override it with
`copts = ["-O"]`: `submodules/GradientBackground` and `submodules/AnimatedStickerNode`. Nothing about a
call site reveals which side of that line it is on.

This matters whenever per-pixel work is written in Swift. Measured over 1.41 Mpx, the wallpaper
soft-light blend runs **3.4 ms at `-O` and 1083 ms at `-Onone`** — the same source, a factor of ~300,
no build error, no symptom but a hitch. A hand-written loop that replaces a CoreGraphics call can
therefore be *much* faster in release and *much* slower in debug, which is the one direction a
release-only benchmark cannot show you.

Consequences:

- **Benchmark at the optimization level the module actually builds at.** `swiftc -O` numbers are
  meaningless for an `-Onone` module.
- `composeSoftLightOverBackground` lives in `GradientBackground` **only** because of that copt, and is
  called from `WallpaperBackgroundNode` (which is `-Onone`). Moving it "back where it belongs" for
  tidiness silently reintroduces the 1083 ms. The function comment says so; keep it.
- Swift's wide-SIMD lowering is poor at `-Onone` — `SIMD4`/`SIMD16` arithmetic there is *slower* than
  scalar (measured 1083 ms vs 448 ms for the same blend). SIMD only pays inside an `-O` module.
- Bulk `SIMD` conversions (`loadUnaligned` into `SIMD4<UInt8>`, `SIMD16<UInt8>(floatVector)`) lower
  badly even at `-O`: per-lane element access beat a 32-bit word load 3.3 ms vs 28.6 ms on the same
  kernel. Measure the load shape; do not assume the "vectorized-looking" one wins.

Two things about reimplementing a CoreGraphics operation, both learned the hard way here:

- **CoreGraphics' `.softLight` is not the PDF/CSS soft light.** It omits the `D(Cb)` highlight branch,
  so it is linear in the source with no kink at 0.5 (verified against a full 256x256 grid). A
  spec-faithful reimplementation is visibly wrong. `±1/255` is the achievable floor against CG's
  internal fixed-point rounding — float, double, integer and two-step formulations all cap there.
- **`vImageScale_ARGB8888` is not CoreGraphics' resampler.** It is ~5.5x faster for the wallpaper's
  36x80 -> full-screen stretch but moves the composed result by up to 5/255, so that stretch stays on
  `CGContext.draw`.

And the trap that produced a shipped-and-reverted wrong image: **the wallpaper pattern is transparent.**
`WallpaperResources.swift` builds it with `DrawingContext(..., clear: true)` and no `opaque:`, over a
`.clear` background, so its alpha decides which pixels blend at all. Compositing it into an opaque
buffer silently discards that and leaves untouched regions reading uninitialised memory. Any fixture
used to validate the compose must use a transparent, premultiplied, **two-colour** pattern — the symbol
image is tinted white while `customPatternColor` may be black, so "the pattern is monochrome" is false.
