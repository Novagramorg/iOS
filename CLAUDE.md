# CLAUDE.md

This file provides guidance to AI assistants working with the **Novagram fork of Telegram-iOS** (internal codename **Fenixuz** until 2026-10-27; the code now says **Novagram** too).

> **Keep this file short.** It loads into every session and has a 150k-character limit. A subsystem gets a
> few lines here (what it is, the rules that break silently) and a link; the full write-up goes in `docs/`.
> The detailed sections moved out on 2026-10-29 are verbatim in the linked files.

## Novagram fork — context

- Brand: **Novagram** — the user-visible app name + icon since 2026-06-20 (previously "Fenixuz" / display name "Fenix Uz"). Since 2026-10-27 the code says **Novagram** as well: module paths (`submodules/Novagram/`), Bazel targets and file/type names (`NovagramL10n`, `NovagramDemoCodeFetcher`, `NovagramMessenger`, `NovagramSponsored`, …). The brand is final (~300K users): do not add new `Fenix` / `Fenixuz` / `ProMessager` names. **Persisted identifiers keep their old spelling and must NEVER be renamed**: the bundle id `uz.fenixuz.app` and its extension ids, App Group and Keychain groups, the Keychain services `uz.fenixuz.app.ChatLock` / `uz.fenixuz.app.Analytics`, the `pro_messager` UserDefaults suite and every `fenix_*` / `fenixuz_*` key, `uz.fenixuz.theme`, `fenixuz.unreadReminder`, the provisioning profile files `Fenixuz*.mobileprovision`. Renaming one wipes users' settings or PINs, counts devices twice in statistics or breaks App Store updates (full list: `submodules/Novagram/HOOKS.md` → "Fenixuz → Novagram rename"). Brand accent color: Novagram blue `#0A9BF5`. Organization: **Vipads MCHJ**, Apple Team ID `ZDBP5RSRZF`, Apple ID `vipadsllc@gmail.com`.
- **Apple team rule** — every Apple reference (certs, App Store Connect, provisioning profiles, App Groups, keychain groups, `DEVELOPMENT_TEAM` in pbxproj/xcconfig) MUST point to Team ID `ZDBP5RSRZF` (Vipads MCHJ). Never a personal team. Development certs may display the individual developer's name in their label ("Apple Development: Azimjon Abdurasulov") because Apple labels Dev certs by Apple ID owner — but the **Team ID** under which they are issued is always `ZDBP5RSRZF`.
- App Store bundle: `uz.fenixuz.app` (kept in `build-system/appstore-configuration.json` for release builds).
- Simulator/dev bundle: `ph.telegra.Telegraph` (kept in `build-system/my-config.json`, fake codesigning).
- All Novagram-specific code lives in `submodules/Novagram/<Feature>/` modules. Telegram source files contain at most 1–3 line `import NovagramX` hooks. **Never** add Novagram feature code into Telegram-owned files (TelegramUI/Sources, ChatListUI/Sources, SettingsUI/Sources, AuthorizationUI/Sources, etc.) — always create or extend a Novagram submodule. When you work on an existing fat hook, move its logic into the module in the same change (backlog: `submodules/Novagram/HOOKS.md`, "Thin hooks and the formatter").
- **Our modules never import Postbox** (moved 2026-10-28): use the TelegramEngine names (`EnginePeer.Id`, `EngineRaw*`, `context.engine…`); `PostboxImportCheck.py` checks `submodules/Novagram/` like Telegram's code and `run.sh` / `publish.sh` / `release.sh` run it before building (HOOKS.md, "Our modules off Postbox").
- **Never reformat a Telegram file.** Change only the lines a hook needs. `.claude/auto-lint-only` (local, gitignored) keeps `auto-lint.sh`'s swiftlint to our own files; recreate it on a new machine (HOOKS.md says what it lists). Telegram files may be edited with the Edit tool now; check `git diff --stat` afterwards anyway.
- **Every hook in a Telegram-owned file MUST be documented in `submodules/Novagram/HOOKS.md`.** That file is the source-of-truth index used by the AI on every `git pull upstream` to re-apply hooks. If you touch a Telegram-owned file, you also touch HOOKS.md in the same commit.

### Upstream-pull conflict policy

`main` does not carry Telegram's history (rebuilt 2026-10-28, after Telegram force-pushed its master). Telegram's code
comes in as snapshot commits marked `Upstream-Commit: <sha>`; never `git pull upstream master` or `git merge
upstream/master` directly, that takes a 2019 merge base. Every update:

1. `submodules/Novagram/scripts/novagram-upstream-update.sh --check`, then without `--check`. It works on
   `feature/upstream-<date>` and never touches `main`; `-X ignore-space-change` keeps the old formatter noise out of
   the conflicts.
2. **Novagram hooks always win** — the lines themselves are non-negotiable. Upstream code wins for everything around them.
3. **AI conflict resolution is manual, one file at a time.** Open `submodules/Novagram/HOOKS.md`, locate the hook section for the conflicting file, re-apply that hook block on the upstream surroundings, commit, then run the script with `--finish`.
4. **Build and check before merging to main** — the script runs `./run.sh`; the simulator must launch, demo-login auto-fill must still work and the screens the script lists must be checked. Then `git merge --ff-only` into `main` and a normal push.
5. **Safety net:** `~/Documents/Novagram-backups/Telegram-iOS-before-reroot-2026-10-28.bundle` holds the old history.

If a hook is silently lost during a merge, the consequence is silent feature-breakage (demo auto-fill stops, custom Settings panel disappears, etc.) — this is why HOOKS.md exists and why pulls are always AI-assisted.

Active Novagram modules (as of 2026-05-08):

```
submodules/Novagram/
├── ChatLock/          (NovagramChatLock)         — Pincode + manager
├── EditedHistory/     (NovagramEditedHistory)    — Edited message history viewer
├── ForeignUserBlock/  (NovagramForeignUserBlock) — Country code helpers
├── Messenger/         (NovagramMessenger)       — Novagram Settings UI (5 controllers)
└── SpeechToText/      (NovagramSpeechToText)     — STT manager
```

`submodules/Novagram/CallRecordingKit` is a git submodule: our public GPL call recording SDK
(`Novagramorg/novagram-call-recording-kit-sdk`, shared with the Mac app), pinned by commit (no tags), owned by the iOS
session, which may push SDK fixes to its `main`. Update it by moving the pin; keep Telegram types out of it (HOOKS.md,
"Call recording").

## Build — ALWAYS use `./run.sh`

The canonical simulator build is **`./run.sh`** (Bazel-based, no Xcode UI). It does config → build → install → launch in one step, uses fake codesigning + `disableProvisioningProfiles`, auto-tunes resources to the host hardware (M4 Pro 24GB → 10 jobs / ~18GB RAM), enables `--keep_going`, `--disk_cache`, `--repository_cache`, and the right Swift module-cache features.

**Always run builds via `./run.sh`** — do NOT invoke `Make.py` directly with `appstore-configuration.json` (that path needs the gitlab codesigning repo + `TELEGRAM_CODESIGNING_GIT_PASSWORD` env var, which we don't use for Novagram dev). Calling `Make.py` directly also bypasses our resource auto-tuning and hardcoded simulator/install steps.

```sh
./run.sh                                # default: iPhone 17 Pro Max
SIM_NAME="iPhone 16 Pro" ./run.sh       # override target simulator
```

The Make.py + appstore-configuration.json + gitlab match path is reserved for the actual App Store release flow only (Phase 3) and must not be used for day-to-day iteration.

### Background-friendly invocation (for AI assistants)

Each iteration writes to `/tmp/run-sh-output.log` and ends with the line `Build muvaffaqiyatli tugadi` on success or `ERROR: Build did NOT complete successfully` on failure. The expected pattern is:

```sh
rm -f /tmp/run-sh-output.log && nohup bash run.sh > /tmp/run-sh-output.log 2>&1 &
disown 2>/dev/null

# then poll with:
until grep -qE "Build muvaffaqiyatli|ERROR: Build did NOT" /tmp/run-sh-output.log; do sleep 5; done
tail -25 /tmp/run-sh-output.log
```

First clean build ≈ 10–12 min, cache-warm incremental ≈ 1–3 min, single-file edit ≈ 30–90 s.

### Cache limits and the simulator `.app` (Novagram, 2026-10-13)

Measured 2026-10-13: a fresh output base with a warm disk cache builds in ~4 min, a no-op `run.sh` takes ~5 s, and a one-line change in a Novagram module takes ~38 s, most of it recompiling PeerInfoScreen and TelegramUI, which import it.

- **Disk cache limit.** `run.sh`, `publish.sh` and `release.sh` cap `~/telegram-bazel-cache/disk` with `--experimental_disk_cache_gc_max_size=35G` and `--experimental_disk_cache_gc_max_age=14d` (35G since 2026-10-30: 20G could not hold both the simulator and the device outputs, so a device build recompiled everything).
  - Bazel trims the cache in the background about 5 min after a build, while its server is idle.
  - Using an entry refreshes its age (measured), so only entries unused for 14 days expire.
  - Never put these flags in `.bazelrc`; the comment there explains why.
- **Output base limit.** Once a day `run.sh` runs `bazel clean` when the checkout's output base is over 30GB. Bazel never prunes old configurations on its own; the output base had reached 35GB.
- **Simulator builds produce no `.ipa`.** They pass `--define=apple.experimental.tree_artifact_outputs=1`, so the output is the folder `bazel-bin/Telegram/Telegram_archive-root/Payload/Novagram.app`, which Bazel keeps current. Use that folder as `SRC` in the recipe below instead of unzipping an `.ipa`.
- **Device builds still produce `Telegram.ipa`, and `run.sh` unzips it.** Without tree artifacts, `Telegram_archive-root/` is a stale scratch folder (see below). `run.sh` used to install from it and put a previous build on the simulator after a revert.

## Known simulator quirks

- **iOS 26.x simulator emoji font is broken** — `AppleColorEmoji.ttc` is missing. Color emojis render as `[?]` boxes (e.g. country flag picker, Telegram default monogram avatars, the Ghost button before we replaced its emoji with a bundled icon). Verify any emoji-bearing UI on a real device or an iOS 18 simulator before reporting "this is broken." For new Novagram UI, prefer SF Symbols or bundled `Item List/Icons/*` assets over color emoji in titles/buttons.
- **Country flag rendering** in the login screen uses regional-indicator emoji and inherits the same `[?]` issue on iOS 26 simulators. It's correct on real iPhone.

## Tests, simulator updates and CI

Full text, including the catalog of every app-side test target and what it pins:
[`docs/tests-and-tooling.md`](docs/tests-and-tooling.md).

- **Bazel test targets:** `Make.py test --target <label>` (same config + codesigning as `build`, forced
  `debug_sim_arm64`). Run new targets via `--target`: the default `Tests/AllTests` references a dangling
  `//submodules/TgVoipWebrtc:TgCallsTests` and fails to build. An `ios_unit_test` needs an `ios_test_runner`
  pinned to a real device/OS (e.g. `iPhone 17` / `26.5`), or the test process exits 15.
- **Host tests** bypass Make.py (macOS build, no codesigning):
  `./build-input/bazel-9.2.0-darwin-arm64 test <label>` — the `cc_test`s in `submodules/TgVoipWebrtc/BUILD`,
  `//third-party/libprisma:SyntaxHighlighterTests` (pins the code-block highlighter recursion cap
  `kMaxTokenizeDepth`, a remote DoS upstream does not fix), and the `swift_test`s
  `//submodules/MetalEngine:MetalPipelineCacheTests` and `//submodules/UrlWhitelist:UrlWhitelistTests`. The bazel
  binary is version-stamped and arch-suffixed; `versions.json` is the single pin.
- **Updating a running simulator:** `simctl install` does not replace an app whose build number is unchanged.
  Copy the whole fresh `.app` over the installed bundle (`xcrun simctl get_app_container <udid> <bundle> app`);
  the data container, and so the login, survives. Simulator builds: `SRC` is
  `bazel-bin/Telegram/Telegram_archive-root/Payload/Novagram.app` (tree artifact, see "Cache limits" above). Never
  `find` under `bazel-out` (stale device archives), never install a device build from `Telegram_archive-root/`
  (silently stale; unzip the `.ipa`), and guard the `rm -rf` on `SRC` existing. Use the dedicated K-sims (iPhone 18
  Pro): K1 `03A7DA9C-1832-49B8-9858-2F54F2FB5A04`, K2 `E643A78E-DB62-4DA4-9F54-BD0836F434AF`,
  K3 `4483DD69-685A-4FE1-89BE-65F992C271F2`; bundle `ph.telegra.Telegraph`.
- **CI** builds in tart VMs (`Make.py vm-build` / `vm-deploy-testflight` / `vm-ipa-diff`). **Every external
  download needs a sha256**, or bazel-remote re-downloads it each build and misses the 60 s `--remote_timeout`
  (`DEADLINE_EXCEEDED`). Bumping Rust means updating `rust.toolchain(sha256s = …)` in `MODULE.bazel`.
- **Vendored FFmpeg / SQLCipher upgrades** (FFmpeg: `FFMPEG_VERSION` plus pruning `ffmpeg_header_paths` in
  `submodules/ffmpeg/BUILD`; SQLCipher: regenerate the amalgamation, keep it pristine, keep the `BUILD` and
  `Package.swift` defines in sync) and the **`SqliteValueBox` self-heal policy** (only the owning read-write
  connection ever deletes the database, always `db_sqlite` + `-wal` + `-shm` together, never on a transient
  result): [`docs/vendored-upgrades.md`](docs/vendored-upgrades.md).

### Driving the simulator UI: use the Xcode MCP server

**XcodeBuildMCP is configured for this project** (`~/.claude.json` → `projects["…/telegram-ios"].mcpServers.XcodeBuildMCP`, run as `npx -y xcodebuildmcp@latest mcp`). Its tools appear as `mcp__XcodeBuildMCP__*` and are the way to **interact with** a running simulator — screenshots, `describe_ui` accessibility dumps, taps/swipes/typing, log capture. Reach for it whenever a change needs verification that a build alone can't give: flipping a Debug Settings flag, opening a chat, scrolling a list, checking that something rendered.

Do **not** fall back to `cliclick` / `osascript` / `screencapture -R` for this. Those need macOS Accessibility and Screen Recording privileges that the terminal running Claude Code does not have (`cliclick` reports "Accessibility privileges not enabled"; `screencapture -R` fails with "could not create image from rect"), and with several K-sims booted at once there is no way to identify the right Simulator window anyway. `xcrun simctl io <udid> screenshot` **does** work without extra privileges and is fine for a passive look, but it cannot drive anything.

If the `mcp__XcodeBuildMCP__*` tools are absent from a session's tool list (it has happened — the server is configured but its tools weren't exposed), say so and hand the interactive checks to the user rather than attempting the privilege-blocked fallbacks.

### Visual features and animations: verify from recorded frames

Any visual change, and always an animated one, is verified by recording the simulator and reading its frames, not by
a green build: [`AGENTS.md`](AGENTS.md), "Visual features and animations" (`simctl io recordVideo`, then
`tools/animation_sheet.py` for labelled frame sheets, per-frame numbers and per-element tracks in points).

## Code Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/methods
- **Imports**: Group and sort imports at the top of files
- **Error Handling**: Properly handle errors with appropriate redaction of sensitive data
- **Formatting**: Use standard Swift/Objective-C formatting and spacing
- **Types**: Prefer strong typing and explicit type annotations where needed
- **Documentation**: Document public APIs with comments

## Project Structure
- Core launch and application extensions code is in `Telegram/` directory
- Most code is organized into libraries in `submodules/`
- External code is located in `third-party/`

- App-side unit tests are few. The catalog (what each target pins, how to run it) is in
  [`docs/tests-and-tooling.md`](docs/tests-and-tooling.md), "App-side unit test catalog". New Postbox regression
  tests go under `submodules/Postbox/Tests/`. `PresentationStrings` cannot be built in a test process, so keep
  decisions in strings-free, testable helpers. Most modules still have no tests.

## RichTextEditor editor & the `ChatInputContent` composer

A from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`) is the native chat-composer backend — by default a **dual-field switch** (the composer uses the legacy input and latches to the native editor only when content becomes legacy-non-representable); the `useInputDecEngine` experimental flag (Debug Settings ▸ "Input V3") forces always-native with the engine editor (iOS 18.4+). "Force Text Field v2" (`forceNewTextInput`, always-native on the legacy editor) was removed 2026-10-15; `ios_rich_input_mode = 1` still gives that. (This inverted the earlier default+`forceLegacyTextInput`-opt-out scheme.) `ChatInputContent` (a TelegramCore-native value model) replaced `NSAttributedString` as the composer currency. The app-side integration — the model and its load-bearing invariants, composer ↔ editor wiring, the formatting-menu / custom-emoji-mention-date / code-block / inline-media round-trips, rich-message send / edit / pending-display, the long-press-Send send-options preview, **media pre-upload** (attached media uploads immediately and is promoted to cloud media, surviving the editor closing and reopening), and draft persistence (local, cross-device media sync, re-login restore) — lives in [`docs/richtext-composer.md`](docs/richtext-composer.md). Editor internals (the TextKit seam, layout) are the editor's own `submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md` — including the **code-block language field + syntax highlighting** (2026-08-25): a code block's language is authored in an always-visible editable line (a second leaf region on the box, so `activeStack` must resolve a box by its PRIMARY region or edits land in the wrong layout), and libprisma highlights code in both editor hosts through a host-provided seam, since the package cannot depend on the highlighter. The renderer half, and the three silent pre-existing defects that had to be fixed before any highlighting was visible, are in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md). Also **InstantPage V2 layout parity** (2026-08-14): the editor lays text out pixel-identically to the V2 renderer via the host-supplied `RichTextRenderMetrics` contract, and BOTH surfaces (composer + article editor) use the chat-message metrics, so what you type reads like the message sent. Message **rendering** is [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).

## Composer harness (`Tests/ComposerHarness`)

A standalone, loginless Bazel `ios_application` that hosts the **real** chat composer —
`ChatTextInputPanelNode` → `RichTextEditorChatInputNode` → `RichTextEngineEditorView` — against a
synthetic `AccountContext` whose only non-stubbed part is a genuine `Account` over a disposable
Postbox with networking off. It exists so an agent can drive composer operation on a deterministic
surface and turn each defect into a regression test, without a login and without touching the
logged-in Telegram on K3.

Its own [`CLAUDE.md`](Tests/ComposerHarness/CLAUDE.md) is the operating manual (build/test/run,
the scenario registry, the model-dump contract, which test tier a regression belongs in, and the
simulator-driving hazards).
Two things to know before using it: **height and inset findings are provisional** (the harness has
no `ChatControllerNode` keyboard machinery), and **unprovided app-context members trap and name
themselves** rather than returning a plausible constant.

## Embedded watch app (`Telegram/WatchApp`)

A standalone watchOS client embedded only in **device** IPAs with `--embedWatchApp` (plus `--watchApiId`,
`--watchApiHash`, `--watchSigningIdentity`, `--watchProvisioningProfile`); simulator builds never embed.
`Telegram/WatchApp/` is a **synced snapshot of the `~/build/tgwatch` repo — do not hand-edit it**; edit there and
re-sync with `tgwatch/tools/export-sources.sh`. xcodebuild runs in two Bazel actions (compile, then patch the
version + sign) so the per-build version stays out of the compile cache key; **never add `"local": "1"`** to the
compile action's `execution_requirements` (it disables every cache). Verified with development signing on
`debug_arm64` only. Details and invariants: [`docs/embedded-watch-app.md`](docs/embedded-watch-app.md).

## The vendored InputDec engine and kernel — this repo owns them (2026-09-15)

`submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC/` (behavior kernel) and `Sources/RichTextInputDecUpstream/` (text
engine) are **ordinary source: edit them here.** `~/Documents/InputDec` lost its `.git`; do not delete it — its
1,078 unit / 196 UI tests are not imported yet. Full text: [`docs/inputdec-engine.md`](docs/inputdec-engine.md);
editor internals: the package's own `CLAUDE.md`.

- On the app graph via `ChatRichTextEditorComposer → RichTextEngineEditor → RichTextInputDecUpstream`, selected by
  Debug Settings ▸ "Input V3" (`useInputDecEngine`). Read `Sources/RichTextInputDecUpstream/PROVENANCE.md` before
  touching that tree.
- Every file is wrapped in `#if TARGET_OS_IOS`, so a macOS `swift build` is no evidence about this code.
- `Vendor/`'s manifest JSON and `Generated/TGRichTextInputDecContractData.m` are hash-pinned by
  `VendorSnapshotIntegrityTests`; a deliberate change re-records the pin in the same commit.
- No private UIKit name reaches the binary as text: spell it `TGPN_<name>()`.
- The engine's storage is the one copy of the text; roles (`EngineBlockRole`) hold structure only. Mutators write
  back through `applyEngineParallelBlocks(_:)`. Structure is decided at the surface gate (`tgid_textInputGate`)
  and settled after the edit (`+Settle.swift`); `onChange` fires exactly once per edit.
- The kernel still raises `NSException`; Swift crosses only through `TGRichTextInputDecPerform*`.
- The `IDUpstreamInputBackend` adapter is outside the app build. Two `richTextEngineUnimplemented` traps remain
  (grep before trusting any count).

## iOS 26/27 windows and touch delivery

Three measured facts that are invisible from the code and each cost an investigation
([`docs/ios27-windows-and-touches.md`](docs/ios27-windows-and-touches.md) has the evidence):

- **Never call `+[UIRemoteKeyboardWindow remoteKeyboardWindowForScreen:create:]`** — it traps
  (`brk #0`) when the binary is linked against the iOS 27 SDK, which this project is. Get the keyboard
  window via `-[UIApplication internalGetKeyboardForScene:]`, which goes through the window scene's
  `keyboardSceneDelegate`. It legitimately returns nil (keyboard never created, or keyboard UI hosted
  out of process), so nil must mean "no keyboard surface", never a missing window.
- **An app can never place a window above the keyboard.** `UIRemoteKeyboardWindow` is at level
  `1e7 + 1` and `-[UIWindow _adjustedWindowLevelFromLevel:]` clamps app windows to `1e7`. Content that
  must appear over the keyboard has to be parented *into* the keyboard window — which is what
  `NavigationController`'s `globalOverlayContainerParent` and `GlobalOverlayPresentationContext` do.
- **A layer that renders nothing receives no real touches**, although `-hitTest:` still returns it:
  `backgroundColor` unassigned (`layer.backgroundColor == nil`) and no `contents` means taps never
  arrive. Transparent `layer.contents` fixes it; a near-zero background alpha only works above an
  undocumented threshold. Watch for `NavigationBackgroundNode(color: .clear)`, whose `updateColor`
  early-return means the colour is never assigned even once.

## iPhone Duo layout (reserved corners)

`ContainerViewLayout.reservedCorners` carries iPhone Duo's corner blocks (the status corner: clock, camera) from a
per-posture table, because the system's own regions are transitional for up to 0.6s after every rotation and fold;
`safeInsets` stay exactly the system's. The rules, the layout API and how to check a screen are in
[`docs/iphone-duo-layout.md`](docs/iphone-duo-layout.md); the all-screens audit is
[`docs/superpowers/duo-screen-audit-2026-10.md`](docs/superpowers/duo-screen-audit-2026-10.md). None of this shows up
as a build error:

- **Folded portrait has a side inset** (right 84, the camera block only at the top). Code that assumes "portrait has
  no side insets" is the main hazard. `UIScreen.main` is the cover screen while unfolded (use
  `mainWindowScreenBounds`), and unfolded landscape is a regular-width phone, not an iPad.
- **Content keeps to the band; bottom buttons and panels span the strip** with `bottomEdgeSideInsets()`, keeping
  clear only of folded landscape-left's bottom block. Exceptions keep the band: small centred controls on the axis of
  band-centred content, tall sheets that scroll up to the top, panels that grow upward, draggable captions.
- **Every Duo fix must reduce to the old expression** with equal side insets and no reserved corners, which is also
  why every bug shape is invisible on other devices. Verify on the Duo simulator (deep links + lldb rotation), not by
  build and review alone: a fix once changed a legacy node while the visible button was another.

## Swift 6.4: `[weak]` in a local closure that also captures a `var`

Swift 6.4 (Xcode 27) miscompiles a closure stored in a local `let` with a `[weak x]`/`[unowned x]` capture list that
**also captures a mutable local** and never escapes: the capture box is destroyed before the first call (a crash
for an NSObject `x`, a silent nil for a Swift class). Write such a closure with a strong capture
(`{ [self] i in`), which cannot cycle because it never escapes. It caused an App Store crash
(`processTodoItemItem`, ComposeTodoScreen). Details: [`docs/swift-6.4-compiler-bugs.md`](docs/swift-6.4-compiler-bugs.md).

## Swift 6.4: SimplifyCFG crash in release builds only

`BorrowUtils.swift:551: … cannot get borrow introducers` in `SimplifyCFG` crashes `swift-frontend` at `-Osize`
only, so it first shows up on CI (seen in `QrStudioCodePaths.init`, avoided with a static
`isEye(x:y:size:)`). The replay recipe and its module-cache trap are in the same doc.

## Per-module `-O` and pixel loops

Almost every module builds `-Onone` in debug; only `submodules/GradientBackground` and
`submodules/AnimatedStickerNode` set `copts = ["-O"]`. Per-pixel Swift is ~300x slower at `-Onone` (3.4 ms vs
1083 ms), so benchmark at the module's real level, and keep `composeSoftLightOverBackground` in
`GradientBackground`. CoreGraphics' `.softLight` is not PDF/CSS soft light, `vImageScale` is not CG's resampler,
and the wallpaper pattern is transparent. Details: [`docs/per-module-optimization.md`](docs/per-module-optimization.md).

## Framework export lists (computed by the build)

Release builds of `TelegramUIFramework` and `TelegramCoreFramework` export only what their clients use
(`Telegram/framework_exported_symbols.bzl`); debug exports everything, so a missing symbol is a **release-only**
link error. A new client goes into that rule's `clients`, a new framework under either into
`provided_by_frameworks`; nothing may `dlsym` the app's own symbols. Details:
[`docs/framework-export-lists.md`](docs/framework-export-lists.md).

## TelegramApi: Swift payload structs over table-described storage (table-driven TL, steps 1–5)

`Api.X.Cons_y` is a `@frozen` struct over one `TLObject` (MRC, non-NSObject root) whose fields sit at
generator-computed offsets; parsing and serialization run in a table-driven C engine (`ObjC/Sources/TLEngine.m`).
`submodules/TelegramApi/swift_scheme.tl` is the source of truth and Bazel generates the code on every build; for
SwiftPM run `submodules/TelegramApi/generate-swiftpm.sh` (it regenerates all three directories together — never
mix runs). Rules: only TelegramCore imports TelegramApi (`internal import`); a bytes field's getter returns a new
`Buffer` each time, so never keep a raw pointer from it; never add an ivar to `TLObject`; `tlFunction` stays
unspecialized; payload fields are read-only; never re-record `GoldenTests` or `ParseFailureTests` expectations.
Full text: [`docs/telegramapi-table-driven-tl.md`](docs/telegramapi-table-driven-tl.md).

## Neighbor descriptors

A `ListViewItem` sees its neighbors only through `ListViewItemNeighbors` (descriptors from `neighborDescriptor`,
read through facet protocols). **A descriptor must encode everything a neighbor reads**, because a row relayouts
only when it changes. `neighborDescriptor` has no default on purpose; use `AnyEquatable.noNeighborInfluence`.
`nil` means no neighbor, which differs from a neighbor that publishes nothing relevant. Details:
[`docs/neighbor-descriptors.md`](docs/neighbor-descriptors.md).

## View frame ownership

A view does not control its own `frame`. The parent (or a layout system) sets the frame; the view positions its own subviews against `self.bounds` in response.

This matters in two places specifically:

- **Reusable components (`UIView`/`ASDisplayNode` subclasses).** Public methods like `update(...)` / `apply(...)` rebuild internal state, mutate child frames, and read `self.bounds` to lay them out — but they do not write `self.frame`. The caller has already chosen the frame; mutating it from inside the component overrides that choice and fights the parent's next layout pass.
- **`asyncLayout`-style content nodes.** The measure pass runs off-main and returns a size; the apply step runs on main and the chat layout system positions the node. A child view that writes `self.frame` from `update()` corrupts the size the parent just measured.

Rare exceptions: top-level view-controller views integrating with the system's first-responder/inset model. If you find yourself wanting `self.frame = …` from inside a child view, refactor so the parent positions it instead.

## ChatHistoryListNode composition

`ChatHistoryListNodeImpl` composes its list behind `ChatHistoryListViewBackend`, implemented by `ListViewImpl` and
by `CoreListChatHistoryBackend` (the default for the rotated history; Debug Settings `coreListChatBackend`, server
`ios_killswitch_disable_corelist_chat_backend`). Read the choice off `usesCoreListBackend`. Compiler-invisible
rules: the π rotation stays on the wrapper; the scroll pan's view is `scrollGestureHostView`, not
`listView.view`; `let _ = self.view` in `init` is load-bearing; item nodes are one level deeper. A new
`self.listView.<member>` access adds that member to the protocol, as one intent-named member rather than a pair of
raw ones (a backend can half-implement a pair). Full text:
[`docs/chat/chat-history-list-node.md`](docs/chat/chat-history-list-node.md); the CoreList engine has its own
`CLAUDE.md`.

## Message send transition (`ChatMessageTransitionNode`)

Timing comes from one `AnimationParameters` preset per chat: `.bezier` (default, 0.3 s) or `.spring` behind Debug
Settings ▸ "Chat: spring send animation". **The history list must scroll with the bubble's vertical curve**, on
both backends. When animating a layer with these curves, pass `timingFunction: curve.timingFunction` as well as
`mediaTimingFunction` (nil for springs). Details:
[`docs/chat/message-send-transition.md`](docs/chat/message-send-transition.md).

## InstantPage V2 & rich-text messages

Typed markdown with structure message entities cannot carry is sent as a rich message (`RichTextMessageAttribute`
with an `InstantPage`) and drawn by `ChatMessageRichDataBubbleContentNode` through the InstantPage V2 renderer.
Streaming reveal, tables, custom emoji, inline buttons (`textButton`, `pageBlockButtonRow`) and document blocks,
Text Size (`contentScale`), unsupported blocks (`UnsupportedContentPill`) and rich reply quotes (`quote_rich`) are
all in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md). Traps to know first: `textButton` follows
the inline **formula** attachment path, not the inline-image one; `InstantPageTheme.withUpdatedFontStyles` rebuilds
field by field (an omitted colour reverts); `InstantPageAnchorPath` must not recurse into `.buttonRow`; scale
fonts once, from the unscaled theme.

## Rust MTProto engine on iOS

The Rust engine (`third-party/mtproto-engine`, wrapper `submodules/MTProtoRustEngine`) is linked into every iOS
build; MtProtoKit stays the default. Debug Settings ▸ `Rust MTProto [Restart App]` selects it for the next launch,
`mtproto_engine_rust_disabled` forces MtProtoKit, and two crashes in 24 h turn it off for 24 h. On iOS only that
switch changes the engine (live switching is macOS only). Build: no `-Clto`; hardware crypto is re-applied by hand
in `MODULE.bazel` (check with `third-party/mtproto-engine/scripts/verify-ios-link.sh`); repin only `mtproto_engine_crates`. Logout: a
main-session `401` logs out, refused binds alone never do, and **never loosen the logout check's conditions** —
a false logout wipes local data. Full text: [`docs/rust-mtproto-engine.md`](docs/rust-mtproto-engine.md);
internals: `third-party/mtproto-engine/docs/swift-integration.md`.

## Network telemetry (`NetworkTelemetry`)

TelegramCore records every request above the engine (`Network/RecordingNetworkEngine.swift`) and reports through
`help.saveAppLog` while `network_telemetry_enabled` is set. Recording off must cost nothing (the wrapper exists
only while recording); keep per-request work off the engines' serial queues; only active waiting counts; every
reported key is pinned by `testReportedFieldsAreAllowlisted`, and method names come only from
`FunctionDescription.name`. Details: [`docs/network-telemetry.md`](docs/network-telemetry.md).

## WEB proxy carrier (`tg://webproxy`)

A third proxy kind: obfuscated2 MTProto streams multiplexed over a hidden `WKWebView` to a `tproxy-server` relay
(client half `submodules/WebProxyTransport`). The loopback address never leaves MtProtoKit
(`MTSocksProxySettings.webProxy`); one process-wide carrier runs on `shouldKeepConnection` demand; its web view must
sit in a real view hierarchy (`WebProxyCarrierViewHost`, alpha 0.01 — zero is not equivalent); a link with a base
path must use the `0x70` marked secret; the carrier's `WKWebView` is hardened on its own and shares nothing with
Mini Apps, payments or Instant View. Details: [`docs/webproxy-carrier.md`](docs/webproxy-carrier.md).

## Postbox shared-media removal (deferred design: tombstones)

`Transaction.updateMedia(id, update: nil)` removes only media embedded in one message; for a shared record it only
decrements the count, and `updatedMedia[id] = nil` deletes the key instead of storing `.some(nil)`. Decided
2026-09-18, deferred: tombstones, never an immediate row delete. Design:
[`docs/postbox-shared-media-removal.md`](docs/postbox-shared-media-removal.md).

## Opening a channel at a post (history fill and the poll gate)

The critical path is one `messages.getHistory`: a history fill stores before it resolves, the around fill learns
the top from `offset_id_offset`, plain channels request no forum topics, and an unjoined channel's view does not
wait for the poll. Details: [`docs/chat/channel-history-and-news-feed.md`](docs/chat/channel-history-and-news-feed.md).

## News feed: parked at layer 232 (`TELEGRAM_NEWS_FEED_API`)

The app talks layer 232, which has no feed API. All News code stays: TelegramCore wraps only the lines that use the
removed API in `#if TELEGRAM_NEWS_FEED_API` (defined nowhere), each `#else` answering with an empty success. One
gate hides News, `isNewsFeedEnabled(appConfiguration:apiIsAvailable:)` reading `newsFeedApiIsAvailable`; a new
News entry point must go through it. Bringing the feed back is four steps (the define goes into TelegramCore **and**
its tests, in both `BUILD` and `Package.swift`): same doc.

## Opening a post from the News feed: the cached post first

Reachable only while the feed is on. A post opened from the feed shows the stored copy (`cachedAnchor: true`)
while its surroundings load. A channel the account is not a member of has no read state
(`NonMemberChannelReadState.swift`), and a join queues a read-state validation itself. Same doc.

## A non-contact's chat before it is accepted (suspicious peer)

While a user's chat shows the report/block panel (`CachedUserData.isSuspiciousPeer`), their incoming messages are
untrusted: links, mentions and similar entities show as plain text, buttons are hidden, their emoji status is
hidden, and nothing is marked read (reads also wait while a non-contact's settings are unknown). Sending clears
`canReport`/`canBlock` locally. Private chats only. Details:
[`docs/chat/suspicious-peer.md`](docs/chat/suspicious-peer.md).

## Postbox → TelegramEngine refactor (in progress)

Consumer modules are moving off `import Postbox` onto `TelegramEngine`. All twelve rules, the `MediaResource`
migration pattern and wave guidance: [`docs/postbox-engine-refactor.md`](docs/postbox-engine-refactor.md); wave
history: [`docs/superpowers/postbox-refactor-log.md`](docs/superpowers/postbox-refactor-log.md). The ones that bite
most:

- `TelegramCore` does not re-export Postbox. Never typealias `Postbox`, `Account` or `MediaBox`; no new engine
  wrapper structs unless the wave allows; grep `submodules/TelegramCore/Sources/TelegramEngine/` for an existing
  equivalent first. TelegramCore never imports UIKit or Display.
- Never replace `Media`/`Peer`/`Message` with `Any`/`AnyObject`; use the engine wrappers.
- **Functionality must not change**, and a green build is not proof: check equality and identity, hashing,
  overload resolution, signal emission, default arguments and lifetimes.
- TelegramCore's public API changes in place (no parallel overloads, e.g. for `EngineMediaResource`); persisted
  encodings stay byte-identical.
- **The guard only shrinks:** `build-system/Make/PostboxImportCheck.py` with
  `submodules/Postbox/AllowedImporters.txt`, `AllowedPostboxAccess.txt` and the Postbox `BUILD` visibility. A change
  that frees a file removes it from the lists in the same commit.

### Engine typealias cheat sheet (existing aliases)

```
PeerId              → EnginePeer.Id
MessageId           → EngineMessage.Id
MessageIndex        → EngineMessage.Index
MessageTags         → EngineMessage.Tags
MessageAttribute    → EngineMessage.Attribute
MessageFlags        → EngineMessage.Flags
MessageForwardInfo  → EngineMessage.ForwardInfo
MediaId             → EngineMedia.Id
PreferencesEntry    → EnginePreferencesEntry
TempBox             → EngineTempBox
PinnedItemId        → EngineChatList.PinnedItem.Id
MemoryBuffer        → EngineMemoryBuffer           (added 2026-04)
PostboxDecoder      → EnginePostboxDecoder         (added 2026-04)
PostboxEncoder      → EnginePostboxEncoder         (added 2026-04)
AdaptedPostboxDecoder → EngineAdaptedPostboxDecoder (added 2026-04)
ItemCollectionId    → EngineItemCollectionId       (added 2026-04-20)
FetchResourceSourceType → EngineFetchResourceSourceType (added 2026-04-20)
FetchResourceError  → EngineFetchResourceError     (added 2026-04-20)
```

The list above is not exhaustive: `grep -rh 'public typealias Engine' submodules/TelegramCore/Sources` lists every alias. Prefer non-`EngineRaw*` ones.

### Engine wrapper cheat sheet

Postbox types that have an engine wrapper. Prefer these to `EngineRaw*` aliases; the full table, with unwrap methods, is in the log's "Engine wrapper inventory". Not all of them are value types: `EngineMessage`, `EngineRenderedPeer` and `EngineMediaResource` are classes, so two wrappers of one raw object are not `===` (rule 9).

```
Peer → EnginePeer (_asPeer())             RenderedPeer → EngineRenderedPeer
Message → EngineMessage (_asMessage())     Media → EngineMedia (_asMedia())
MediaResource → EngineMediaResource (_asResource()); .Id, .ResourceData, .FetchStatus for its id/data/status
PeerPresence → EnginePeer.Presence         CombinedPeerReadState → EnginePeerReadCounters
ChatListTotalUnreadState → EngineTotalReadCounters   PeerGroupId → EngineChatList.Group
```

`EngineMedia.init(_:)` has a `preconditionFailure()` for any `Media` class outside its cases. Each TelegramCore media class has a case. An app-side pseudo-media class must conform to `EngineCustomMedia`, and wraps as `.custom`; today that is the three link-preview placeholders in `WallpaperPreviewMedia`. `build-system/Make/PostboxImportCheck.py` enforces this on every `Make.py build`/`test`. It fails on any in-scope class, struct, enum, protocol or extension whose inheritance list names `Media` (or `EngineRawMedia`) anywhere without also naming `EngineCustomMedia`. A grep had missed `: EngineRawMedia` conformers, and that gap let waves 455 and 458 trap on wallpaper, theme and gift link previews.

## tgcalls (`submodules/TgVoipWebrtc`)

- `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` — top-level testbench overview, build/run commands
- `submodules/TgVoipWebrtc/tgcalls/tools/cli/CLAUDE.md` — CLI test tool architecture
- `submodules/TgVoipWebrtc/tgcalls/tools/go_sfu/CLAUDE.md` — Go SFU internals
- `submodules/TgVoipWebrtc/CLAUDE.md` — tgcalls library internals + macOS/Linux build patches
- `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CLAUDE.md` — pump-boundary call core: `InstanceV2ReferenceImpl`'s control logic behind a C ABI (since Phase 2.5 a PeerConnection-projection contract: SDP munge point, transceiver/parameter/ICE-restart commands, rich stats, and since Phase 2.6 core-owned signaling framing, N named data channels, and audio/ICE config knobs), runnable natively or as a WASM module in the vendored WAMR interpreter. **Ships as call versions `18.0.0` (native core) and `19.0.0` (the same source as wasm embedded in the binary)** so a server-side A/B can measure the substrate alone; the client advertises both and the server reconciles. `customParameters.wasm_core_path` and the filesystem module loader are compiled out of the app (`TGCALLS_ALLOW_EXTERNAL_WASM_CORE`, CLI target only) — never add that define to the `TgVoipWebrtc` objc_library. A second module `variant-core-abi1.wasm` demonstrates behavior changes (fmtp munge, adaptive bitrate cap, periodic ICE restart) shipped as wasm only, CLI-loaded. Design/validation records in `docs/superpowers/specs/2026-07-*-tgcalls-wasm-*`

`./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
