# Postbox → TelegramEngine refactor

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Postbox → TelegramEngine refactor (in progress)

A gradual migration is underway to eliminate direct `import Postbox` from consumer submodules in favor of `TelegramEngine`.

**Historical record:** Wave-by-wave outcomes, the running tally of Postbox-free modules, and full verbose forms of the guidance subsections below live in [`docs/superpowers/postbox-refactor-log.md`](superpowers/postbox-refactor-log.md). Read that file when you need wave-specific context, a full worked example of a pattern, or the history of a particular module's migration.

Waves landed so far (as of 2026-04-24): 45 waves plus standalone cleanups. See the log file for per-wave detail; the list of still-open migration opportunities lives in the `project_postbox_refactor_next_wave.md` memory file.

### Rules that apply to every wave

1. `TelegramCore` does **not** `@_exported import Postbox`. Once a consumer drops `import Postbox`, every remaining Postbox-type reference must use an engine-typealiased equivalent.
2. **Never typealias `Postbox`, `Account`, or `MediaBox`.** These umbrella types rename without encapsulating. Narrow utility typealiases (`MemoryBuffer`, `PostboxDecoder`, `PostboxEncoder`, `AdaptedPostboxDecoder`, `MediaResource`, …) remain allowed and expected.
3. No new engine wrapper **structs** unless the wave's spec explicitly allows — only typealiases and thin forwarding methods.
4. **Discovery first:** before adding any new engine wrapper/typealias, grep `submodules/TelegramCore/Sources/TelegramEngine/` for existing equivalents. Record the search result in the commit message.
5. **Abandonment protocol:** if a module can only be refactored by violating rule 2 or by editing a module outside the current wave's list, mark the task Abandoned with a recorded reason. Do NOT substitute a new module mid-wave.
6. Full project build per wave (`Make.py build --continueOnError`). When a wave touches a module that has an `ios_unit_test` target, run it too (`Make.py test --target <label>`).
7. **TelegramCore never imports UIKit/Display.** `TelegramCore` is shared with the Telegram-Mac codebase; its Bazel `deps` and source files must not reference UIKit, Display, or any Apple-UI framework. UIKit-needing helpers (image scaling, rendering, etc.) stay in consumer-side submodules.
8. **Never substitute Postbox protocols (`Media`, `Peer`, `Message`) with `Any` / `AnyObject`** in code that previously used them. Type erasure throws away the domain semantics that the next reader expects. Use the matching engine wrapper (`EngineMedia`, `EnginePeer`, `EngineMessage`) — extending it as needed (e.g. add a missing case-init or convenience). If neither typealias nor wrapper covers the use site, restore the original Postbox import + type for now and flag the case for a future facade. Existing `Any`/`AnyObject` parameters predating the refactor are not in scope for this rule.
9. **Functionality must not change.** Converting between types is allowed (wrap/unwrap, typealias swaps, retyping to a wrapper); behaviour is not. A green build is not proof: review the diff for equality and identity (`EngineMessage` is a class with field-wise `==`; two wrappers of one message are not `===`), hashing, overload resolution after an import is dropped, signal emission (optional vs `.never()`), default arguments and lifetimes. Record how equivalence was checked in the wave's log entry.
10. **TelegramCore's public API changes in place**, model types included: no additive accessor, init or overload is kept beside the raw one, and nothing is kept for Telegram-Mac (it follows the same refactor). Persisted encodings (PostboxCoding, FlatBuffers) stay byte-identical; keeping raw storage internal behind a retyped public surface is the default shape for model types.
11. Every wave appends its outcome to `docs/superpowers/postbox-refactor-log.md` in its own commit.
12. **The guard only shrinks.** `build-system/Make/PostboxImportCheck.py` runs before every `Make.py build`/`test` and fails when an in-scope Swift file imports Postbox without being listed in `submodules/Postbox/AllowedImporters.txt`, or a listed file no longer does. Bazel `visibility` on `//submodules/Postbox:Postbox` (`clients`, `test_clients` in its BUILD) fails a dep from any other package. A wave that frees files or packages removes them from both lists in the same commit; adding to either is a deliberate exception, made in review. The same check guards `.postbox` access:
    - An in-scope file whose code contains `.postbox` must be listed in `submodules/Postbox/AllowedPostboxAccess.txt`, and every listed file must still use it. Comments and strings don't count; code inside string interpolation does.
    - A wave that removes a file's last `.postbox` use deletes its line in the same commit.
    - `python3 build-system/Make/PostboxImportCheck.py --report` prints the access measures each wave records.

    Tests: `python3 -m unittest discover -s build-system/Make/tests`.

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

**Free-function thin forwarders in TelegramCore** (rule 3 allows):
- `engineFileSize(_ path:, useTotalFileAllocatedSize: Bool = false)` — forwards to Postbox's `fileSize(...)` (added 2026-05-04 wave 268)

**TelegramEngineUnauthorized.resources facade**: `UnauthorizedResources.storeResourceData(id: EngineMediaResource.Id, data:, synchronous:)` — bridges to `account.postbox.mediaBox.storeResourceData` (added 2026-05-04 wave 271)

For the `MediaResource` Postbox protocol, prefer the TelegramCore subtype `TelegramMediaResource` when the consumer's usage allows (note: `EngineMediaResource` is a wrapper **class**, not a typealias, so it is not interchangeable with the protocol).

### MediaResource → EngineMediaResource consumer migration

`EngineMediaResource` is a `final class` in `TelegramCore` wrapping a `MediaResource` value. Unlike the typealiases above it is **not** interchangeable with the protocol, but it does provide wrap/unwrap helpers:

- `EngineMediaResource(rawResource)` — wrap a raw `MediaResource`.
- `engineResource._asResource()` — unwrap to the raw `MediaResource`.
- `EngineMediaResource.ResourceData(rawResourceData)` — wrap `MediaResourceData`.
- `EngineMediaResource.Id(rawMediaResourceId)` — wrap `MediaResourceId`.

**Pattern for facade functions:** when a `TelegramEngine.<Area>` method leaks raw `MediaResource` in its public signature, **change the facade signature in place** to `EngineMediaResource` (and change any closure parameter types the same way). Bridge inside the facade body by calling the existing `_internal_*` function with `engineResource._asResource()` / wrapping raw inputs from inner closures with `EngineMediaResource(rawResource)`. Update all call sites in the same commit. The `_internal_*` function stays on raw `MediaResource` — it is the Postbox-facing layer.

Do **not** add opt-in `EngineMediaResource` overloads alongside raw-`MediaResource` overloads. Duplicate signatures fragment the public API and leave the leak in place forever.

For consumer modules, prefer `EngineMediaResource` as the type in properties, locals, generic arguments and function parameters when the usage is a pure type reference. Do **not** try to use `EngineMediaResource` where a class must conform to `TelegramMediaResource` (Postbox protocol) or override `isEqual(to: MediaResource)` — those remain `import Postbox`.

### Wave-selection guidance

Distilled lessons from waves 1–26. Each bullet below has a full-form counterpart in `postbox-refactor-log.md` (same subsection heading) with backstory, example scripts, and per-wave numbers.

- `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` — top-level testbench overview, build/run commands
- `submodules/TgVoipWebrtc/tgcalls/tools/cli/CLAUDE.md` — CLI test tool architecture
- `submodules/TgVoipWebrtc/tgcalls/tools/go_sfu/CLAUDE.md` — Go SFU internals
- `submodules/TgVoipWebrtc/CLAUDE.md` — tgcalls library internals + macOS/Linux build patches
- `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CLAUDE.md` — pump-boundary call core: `InstanceV2ReferenceImpl`'s control logic behind a C ABI (since Phase 2.5 a PeerConnection-projection contract: SDP munge point, transceiver/parameter/ICE-restart commands, rich stats, and since Phase 2.6 core-owned signaling framing, N named data channels, and audio/ICE config knobs), runnable natively or as a WASM module in the vendored WAMR interpreter. **Ships as call versions `18.0.0` (native core) and `19.0.0` (the same source as wasm embedded in the binary)** so a server-side A/B can measure the substrate alone; the client advertises both and the server reconciles. `customParameters.wasm_core_path` and the filesystem module loader are compiled out of the app (`TGCALLS_ALLOW_EXTERNAL_WASM_CORE`, CLI target only) — never add that define to the `TgVoipWebrtc` objc_library. A second module `variant-core-abi1.wasm` demonstrates behavior changes (fmtp munge, adaptive bitrate cap, periodic ICE restart) shipped as wasm only, CLI-loaded. Design/validation records in `docs/superpowers/specs/2026-07-*-tgcalls-wasm-*`

**Inventory at execution time, not just planning time.** Planning-time grep often undercounts. Re-inventory at Task-1 time using the full token set `\b(postbox|mediaBox|transaction|PostboxView|combinedView|MediaResource|PostboxDecoder|PostboxEncoder|MemoryBuffer)\b|^import Postbox` over the module's sources. If the count exceeds the plan, abandon before editing code rather than substituting a different module.

`./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
