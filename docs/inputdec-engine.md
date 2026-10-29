# The vendored InputDec engine and kernel

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## The vendored InputDec engine and kernel — this repo owns them (2026-09-15)

`submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC/` (the behavior
kernel) and `Sources/RichTextInputDecUpstream/` (the text engine) are **ordinary source: edit them
here.** There is no upstream to change first, no re-port, no hash list to re-record.

This reverses an arrangement that stood until 2026-09-15, and the reversal is not a preference — it
is a repair. `~/Documents/InputDec` was the source of truth for both trees, the kernel re-synced by
`InputDec/Scripts/export-behavior-kernel.sh` and the engine hand-ported under a SHA-256 list. Its
`.git` went missing on this machine between 2026-09-11 and 2026-09-12, so the authority was an
unversioned working tree on one disk while the copy in this repo was versioned and reviewed. Three
engine changes had already had to be recorded as "working tree at ⟨date⟩" because no commit existed
to name. `PORTED-FILES.sha256`, `PORTED-FILES-local.sha256` and `Scripts/verify-ported-files.sh` are
deleted with the workflow they served.

**Still generated, still pinned:** `Vendor/`'s pristine manifest JSON and
`Generated/TGRichTextInputDecContractData.m`. `VendorSnapshotIntegrityTests` (Core) hashes both
against pins recorded independently in `VENDOR.md` and the test file — no longer to forbid an edit,
but so an accidental one is caught and a deliberate one re-records the pin in the same commit. The
generator (`generate-contract-data.py`) has not been brought across yet, so prefer regenerating over
editing once it is.

**No private UIKit name reaches the binary as text (2026-10-12).** Both trees spell every private
name they cross with UIKit through `TGPN_<name>()` (XOR-encoded, generated from
`submodules/TelegramUI/Components/RichTextEditor/Scripts/private-runtime-names.txt`), compile UIKit's
callbacks under neutral `tgpn_` names added under the private ones from `+initialize`, and store the
embedded contract tables encoded. `PrivateRuntimeNamesTests` guards the sources and
`Scripts/scan-private-runtime-names.py` checks a release binary. The rules, and the one known
residual (the legacy canvas's text-checking client), are in the package `CLAUDE.md`, "Private UIKit
names are not in the binary".

**The open half is the PROOF.** Upstream also holds the engine's tests — 1,078 unit and 196 UI
cases, a stock-`UITextView` oracle host and their fixtures — and those are not here yet. Until they
are, this repo owns the engine without owning what shows it works, and `~/Documents/InputDec` must
not be deleted. That import is the next step, and it has a natural home: `Host/project.yml` already
carries an app, a unit-test bundle and a UI-test bundle.

The directory is a **sibling** of `Sources/RichTextEditorUIKit/`, deliberately: `BUILD`'s
`RichTextEditorUIKit` `swift_library` globs `Sources/RichTextEditorUIKit/**/*.swift` only, so an
`.m`/`.h` placed under that tree would compile fine under SwiftPM (whose package target picks up the
whole directory) and simply vanish from the Bazel/app build with no error.

**The kernel's real consumer is `Sources/RichTextInputDecUpstream/`.** That directory is InputDec's
actual text engine — 78 files / 16,492 lines, brought across 2026-08-26 and owned here since
2026-09-15. Its `PROVENANCE.md` is now an ORIGIN record rather than a diff against a live upstream:
it carries the revision each file was last taken at, the thirteen that were uncommitted upstream when
they were first read, and all six ways this copy differs from the tree it came from. Read it before
touching anything in there — those six are facts about the code you are editing, not paperwork. Two
are worth knowing without opening the file: every file carries a `#if TARGET_OS_IOS` wrapper (which
the export script used to add and which is now simply part of the source — it is what makes the
module compile to nothing on macOS, so a `swift build` can never be evidence about this code), and
`IDPrivateUIKit.m`'s `IDInteractionABISpec` carries an `objc_runtime_name` attribute because the
vendored carve `Host/TGRichTextInputDecHostPreflight.m` defines a class of the same name — it was
carved out of that very file — and the two would otherwise collide at link.

**The port IS on the app graph now** (2026-09-01), reached as
`//Telegram:Telegram → … → ChatRichTextEditorComposer → RichTextEngineEditor → RichTextInputDecUpstream`.
Verify with `bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'`.

This paragraph previously said the opposite, and said it was load-bearing: `IDBlockTextView` had a
`+load` that resolved the private `UIKeyboardInput` protocol by name and `@throw`ed an **uncaught**
`NSException` before `main()`, which nothing could guard and no flag could disable. That hazard is
GONE, not tolerated — upstream `442f395` moved the installation into the initializer, where a failure
lands in an existing `@catch` and becomes a failed CONSTRUCTION the host can gate on. There is no
`+load` left anywhere under `Sources/RichTextInputDecUpstream/`; check with
`grep -rn "^+ (void)load" Sources/RichTextInputDecUpstream/` before trusting this sentence, because
its predecessor was true when written and silently stopped being true.

It is also driven by a real editor now. `Sources/RichTextEngineEditor/` maps Telegram's `Document`
onto the engine and is selected by Debug Settings ▸ **"Input V3"**
(`ExperimentalUISettings.useInputDecEngine`). As of R9-inline it does links, inline code, spoilers
(hidden text plus dust) and custom emoji, and it owns the composer's edit menu.

R7 then added containers: `.code`, `.pullQuote` and `.blockQuote` round-trip through
`EngineDocumentBridge`, are drawn by real per-block decoration views, and all three Format-menu
commands (`makeCodeBlock`, `makePullQuote`, `wrapInBlockQuote`) perform. `.table` landed 2026-09-04
and `.media` 2026-09-05
(see the package `CLAUDE.md`, "R7 tables" and "R7 media" — media is an attachment atom plus a caption
line, and Backspace on it is two-step by product decision). R7-nesting (2026-09-05) made the block
quote recursive — any block at any depth, roles carrying an ancestry — see the package `CLAUDE.md`,
"R7 nesting". R7-details (2026-09-08) added the second container kind — a title line that is a
secondary region above a body a fold hides, and an indent each container contributes rather than a
depth every container is charged; see the package `CLAUDE.md`, "R7 details". R9-buttons (2026-09-09)
discharged the LAST trap, `.buttonRow` — which was never a container: it holds no child blocks, so
`EngineAncestor` gained nothing. It is a fifth `EngineBlockShape`, one attachment character for the
whole row whatever its pill count, with the pills packed by the V2-pinned packer inside a hosted
view. The same rung gave inline `textButton` pills their hosted views: they had been laying out and
drawing NOTHING, so an inline button rendered as a blank gap of exactly the right size. See the
package `CLAUDE.md`, "R9 buttons". R9-formulas (2026-09-09) wired the host's formula renderer,
which the engine had stored and never handed to its mapper — so formulas rendered as their own
LaTeX source — gave a standalone formula paragraph block rhythm, and made `insertFormula` produce a
block rather than legacy's inline atom; see "R9 formulas". R10-undo (2026-09-17) wired the article
editor's toolbar Undo/Redo, which were two constants and two traps, to the engine's own undo manager;
see the package `CLAUDE.md`, "The toolbar's undo and redo are the engine's own stack" — including the
measured open item that undo is one step per CHARACTER where legacy coalesces typing into runs.

**Exactly TWO traps are left, both `Block.<case>` in `EngineDocumentBridge` naming R7**, and neither
is reachable by any case the bridge models today. Verify with
`grep -rn richTextEngineUnimplemented submodules/TelegramUI/Components/RichTextEditor/Sources/`
before trusting this sentence: its predecessors named `insertEmoji` at R9-emoji-insertion (answered
for real in `+CustomEmoji.swift`), `R7-paste` (discharged 2026-09-17 by the global-position work) and
`R10-undo`, and each was true when written.

**The block quote is the one that shaped the design.** Every other container is 1:1 with an engine
block, so its kind is a tag in the identity table; `BlockQuote` has `children: [Block]`, so one model
block becomes N engine blocks. The view's cache is therefore `currentRoles: [EngineBlockRole]`, one
per ENGINE block, and the `Document` is DERIVED from it by a stack walk over each role's ancestry —
keyed on the quote's IDENTITY, so two adjacent quotes stay two. `currentBlocks` survives as a
computed engine-parallel projection, which is what left every consumer that indexes the cache by
engine block index untouched. Mutators must write back through `applyEngineParallelBlocks(_:)`:
assigning `Document(blocks:)` directly dissolves every quote into loose paragraphs. **A role is structure only, by type**: it holds
shapes (`EngineBlockShape`, `QuoteShape`, `TableShape`, `EngineContainerShape`), which have no field
for text. The engine's storage is the one copy of the text; `currentBlocks` and `document` are
materialised from the roles and `engine.attributedBlocks` on every read
(`EngineDocumentBridge.block(for:from:)`), and flat geometry sums the ENGINE's block lengths
(`flatOffset(ofRoleAt:)`, `flatLength(ofRoleAt:)`), which is also the axis a formula run's single
attachment character lives on. Before this held, roles carried a second copy of the text refreshed by
convention, and three device defects in one day (2026-09-04) were that copy going stale.

**Structure is decided at the surface gate and settled after the edit (2026-09).** Text reaching the
host view's UITextInput surface (`TGIDObservingBlockTextView`'s `insertText:` and
`replaceRange:withText:`, the same shape as its backspace veto) goes through `tgid_textInputGate`
BEFORE the controller edits: `RichTextEngineEditorView+SurfaceGate.swift` forwards it (the same, or
transformed — a newline inside a cell or a pull-quote/code body becomes `U+2028`, inside a language or
author line it is dropped) or vetoes it after issuing its own top-level edits (a Return in a cell or a
language line is a caret move that registers no undo step; legacy's double-Return exits and
un-makes; a replacement across cells re-issued per cell; a replacement across BLOCKS decided by
legacy's one rule, `applyReplaceOutcome` ported: a container wholly inside the range — code,
pull quote, block quote, table — is dropped with its second lines, blocks between the endpoints are
dropped, the survivor is the start block's role, else the end's, else a fresh body paragraph, a
leaf covered in part keeps its remainder as its own block, a block quote's endpoint child merges
like a paragraph, and a range with an endpoint inside a table it covers only in part is refused). Selection
deletions (`deleteBackward` with a selection, `cut:`) are issued by the host view as
`replaceRange:withText:` with empty text so they reach the gate — before that they went to the
controller, which merged by identity with no rule deciding the survivor, and every container kind
needed its own after-the-fact patch. Consequences settle at the controller's
post-edit callback (`+Settle.swift` from `engineDidFinishEdit`): blocks the edit minted are declared
by rule (a quote child, an author tail restyled to body, a split a dictation made rejoined), a
second line whose container lost its primary region becomes a body paragraph (select all and
Backspace over a code block leaves the language line's identity as the survivor), author-line
presence is fixed, a code body without its language line gets one, and the PRESENTATION of every
block the edit touched or whose role changed is re-derived from its role through the bridge
(`normalisePresentation`: presentation is a function of role and model, never carried by text —
text merged into a cell takes the cell's face, an author tail takes body, stale typing attributes
heal; ambient bold and italic are told from the user's by the engine's base-font key, which the
bridge stamps on header cells and author lines), the replay snapshot registered, typing attributes re-adopted. The
change notification only rebuilds roles by identity — unless the edit carried its plan: a structural
edit goes through `replaceFlat(_:with:adopting:)` and the funnel adopts that plan, by position, in the
edit's own notification, so there is no state in which the roles are a by-identity guess and no
plan can be built from post-edit roles (settle's rejoin once captured its plan after its own merge
and removed a role past the end: device crash, 2026-09-04). `adoptRolePlan` is for structure changes
without an edit; a count mismatch asserts. Measured facts behind this: UIKit's private
should-change delegates are never consulted; every edit issued in one run-loop cycle lands in one
undo group; the controller re-inserts its newline when a NESTED correction leaves a line separator at
its insertion point, moves its caret past nested insertions, delivers nested edits' notifications on
the next processing pass, and spins the run loop inside its own insert — none of which can happen to
an edit issued before or after its own. The host's own edits reach the gated surface too and pass
untouched (the gate and settle each know when they are the ones editing); settle never runs during a
replay. The host never edits inside the change notification. Document sets diff by model id and
replace only the differing span; empty-block typing attributes are pulled by identity from the
bridge.
Document sets diff by model id and rendered text and replace only the differing span
(`tgid_replaceBlocksInRange:withAttributedBlocks:`), attaching to the preceding block so identities
survive; empty-block typing attributes are pulled by identity from the bridge
(`installEmptyLineProviders`, positional while a set is landing). Host commands (insert table, wrap in
quote, …) keep snapshot undo and still clear history (`prepareUndoForStructuralRepair`). A host
COMMAND that issues structural edits from outside the gate frames them with
`performHostStructuralEdit`, which captures the pre-edit roles, tells the gate not to decide them and
settles once at the end — the gate decides KEYSTROKES, and an edit a rule issues already carries its
plan. Tab out of the last cell of a trailing table did not, so the gate read its `"\n"` as a Return in
a cell, ran the command again one level down and vetoed the outer edit, dropping its plan; it produced
the right document only because both plans came from the same roles a moment apart.

**`onChange` fires exactly once per edit, and two paths lost that silently.** Every paragraph mutator
(`setParagraphStyle`, `setList`, `setAlignment`, `indent`, `outdent`) and the list-continuation
reconciliation ends by putting the caret back, and a caret restore reaches `engineDidChangeSelection`
like any other selection change — so each delivered a SECOND `onChange` a run-loop turn behind its
own, because `scheduleSelectionDrivenOnChange` declines only when a notification is already owed and
these marked theirs at the end. `deliveringOneChangeNotification` marks it owed BEFORE the mutation, so
the restore joins it. Separately, while a reconciliation is pending the funnel suppresses each edit's
notification by returning BEFORE marking one owed, so a caret move in that window read the same guard
as false and scheduled a delivery the reconciliation's release could not absorb; that schedule now
defers to a pending reconciliation. Neither fix subsumes the other — reverting either alone brings its
own double delivery back. **The tests that pin this contract could not see it:** they wait for the
FIRST `onChange` and return, so the second lands after the test has finished, and the two cases that
DID notice crashed on a repeat `XCTestExpectation.fulfill` and had the whole class
(`EngineListContinuationTests`) skipped from every run rather than read.
`EngineChangeNotificationCountTests` counts deliveries over a window instead — and had to drain what
its own setup schedules first, or every case reads as 2 whatever the code does. The composer runs a
full layout pass from `onChange`.

**Where presentation goes in that editor is counter-intuitive and cost three wrong designs**: the
canvas renders each block from `block.attributedText`, so there is no render-time attribute hook.
Styling that may be SENT is written into the document and stripped on read-back; styling that must
not be sent, or must change without an edit (a spoiler's hide), goes through
`IDBlockLayout.displayDecorator`; anything font-shaped uses `IDInlineTextBaseFontAttributeName`, the
face the trait pass derives from. Views over text (emoji, dust) are positioned by the host from
`id_rectsForCanonicalRange:` — NOT through `NSTextAttachmentViewProvider`, which cannot be made to
fire at all.

The module is also still reachable from the SwiftPM test target. One suite,
`Tests/RichTextEditorUIKitTests/InputDecUpstreamHostSmokeTests.swift`, stands the host up, makes it
first responder, types into it, and pins the runtime contract gate (140 preflighted contracts — it
was 0 until the port started feeding it the pristine manifest, so it passed by checking nothing).
(`Scripts/verify-ported-files.sh` used to pin the 78 copies by SHA-256 beside it; it is gone with
the port workflow.) The smoke suite does not run automatically.

**There IS an adapter now** — `Sources/RichTextEditorUIKit/InputBackend/InputDec/Upstream/`,
`IDUpstreamInputBackend`, which drives the ported engine through Telegram's own
`RichTextInputBackend` family (this sentence read *"there is no adapter"* until phase 3b; it had been
false since phase 2, and it is exactly the kind of stale claim that reads as freshly verified). It is
**still outside the app build**: the Bazel `srcs` glob excludes that directory, `Package.swift`
compiles it for the test target only, and
`Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift` pins both
halves of that arrangement plus the derived implemented/unimplemented partition. Every requirement
the adapter does not implement reports a NAMED contract violation rather than returning a plausible
value, and a test drives every one of them. There is still **no debug screen and no production call
site**; `RichTextEditorView` stays `.legacy` and `ExperimentalUISettings.inputDecTextBackend` stays
`false`. The older `IDTextEditorBackendModuleProbe.swift` remains what it was: a compile-and-link
probe that imports `RichTextInputDecObjC` and calls one contract-manifest function.

**Phase 3b is the first change in the port that touches production**, and it is a small one:
`RichTextInputBackend` gained `acquireFirstResponder()` / `relinquishFirstResponder()` (answering
`RichTextInputResponderTransition`), because the ported engine's editing surface is a separate view
inside the host and UIKit raises no keyboard for a host that holds the first-responder role itself.
The shipping `LegacyRichTextInputBackend` answers `.hostOwnsTheRole` and touches the responder chain
**not at all** — which is both behaviour-preserving and what makes the pair recursion-proof for a
host that routes its overrides through it. **Nothing in `Sources/` calls either member yet**;
`DocumentCanvasView`'s responder overrides are unchanged, pinned by
`InputBackendSourceBoundaryTests.test_theResponderHandOffHasNoProductionCallSiteYet_R23` (a rule the
phase that wires the canvas is expected to DELETE, not edit around).

**The kernel compiles at the iOS 13 floor and is invisible to the macOS build**, which is what makes a
green `swift build` worthless as evidence about it on its own. Every vendored `.h` and `.m` except
`Host/TGRichTextInputDecModuleAnchor.m` (deliberately left unguarded, so the module has at least one
real symbol to anchor it on macOS) opens with `#if TARGET_OS_IOS`; three kernel headers
(`IDUIKitBehaviorKernel.h`, `IDUIKitInputControllerCapability.h`, `IDUIKitInteractionCapability.h`)
import `<UIKit/UIKit.h>` immediately once that guard opens, and nothing in the kernel uses
`API_AVAILABLE` or `@available` (grep returns zero hits). The consequence, verified directly in this
worktree: a macOS SwiftPM build of this target compiles eleven ~2.4 KB objects with zero defined
symbols and zero Objective-C classes (`nm -g` on all eleven is empty; none carries an
`__objc_classlist` section), while the iOS-simulator build of those same eleven `.m` files defines
**15 Objective-C classes** — confirmed two ways here: the SwiftPM iOS-simulator object files (this
worktree's own DerivedData) and Bazel's `libRichTextInputDecObjC.a` (680,856 bytes, already built
under `bazel-bin`) list the identical 15 class names, from `IDInteractionABISpec` through
`TGRichTextInputDecSelectionRect`. A broken import spelling stays green under `swift build` for
exactly this reason — see the verification traps in the package `CLAUDE.md`.

**Certified build vs. selection floor is a decision already made, not yet code.** The kernel is
*certified* against exactly one OS build (iOS 26.5 / 23F73 — the only combination it has ever run
against upstream, per `Vendor/VENDOR.md`). The backend-introduction plan committed (its decision 2,
dated 2026-08-17; the plan left the tree on 2026-10-12 and is in git history) to eventually *selecting* the ID
backend on a **floor** of iOS 17.0 rather than gating on that exact certified build — but no code
enforces this yet: there is no `IDTextEditorBackend`, no `isSupported()`, nothing beyond the probe
described above. Treat the decision as the constraint later stages must satisfy, not as a description
of anything currently running. The differential-corpus baseline
(`submodules/TelegramUI/Components/RichTextEditor/docs/input-backend-differential-baseline.md`) exists
today only for the legacy backend; the plan calls for re-running that same corpus against the ID
backend, on more than one OS build, before any wider enablement — a matching manifest type encoding
does not prove matching semantics on an OS the kernel was never certified against, and the differential
run is the only instrument that would catch a drift the manifest check cannot see.

**Upstream had no CI either** (no `.github`, `.circleci`, `Jenkinsfile` in `~/Documents/InputDec`):
its enforcement was a standing manual discipline plus the export script's own shape assertions on
every export (clean-tree scope, the host-ABI carve, no leaked canvas-shaped selectors, `VENDOR.md`
provenance). **Those assertions are gone with the export**, and three of the four were real rules
about what this code may contain rather than about how it travelled — in particular "no leaked
canvas-shaped selectors", which upstream also enforced from the other side with `IDProjectSmokeTests`
grepping its own source. Nothing in this repo enforces it today; importing that suite is part of
bringing the proof across. The one *automated* guard that remains is
`VendorSnapshotIntegrityTests`, and it covers the two generated artifacts only.

**The kernel still raises `NSException` on a contract mismatch.** Only the two manifest-resource
lookups were converted to nil-returning; seven raise sites survive (`IDUIKitBehaviorReport.m:83`,
`IDUIKitInteractionCapability.m:119,132,237`, `IDUIKitInputControllerCapability.m:134,231,534` — see
`Vendor/VENDOR.md`), including the `activeController` accessor, which raises on *any* call after
`detach()`. Swift cannot catch an `NSException`, so `TGRichTextInputDecPerform` /
`TGRichTextInputDecPerformReturningObject` (`TGRichTextInputDecExceptionGuard.h`, telegram-ios-authored,
NOT part of the vendored snapshot) are the only sanctioned crossing point. Today that rule is recorded
only as a doc comment next to the probe (`IDTextEditorBackendKernelCallPolicy` in
`IDTextEditorBackendModuleProbe.swift`); the plan assigns an automated grep-based guard
(`IDBackendCallGuardTests`) to a later stage (Task C0) to enforce it mechanically.
