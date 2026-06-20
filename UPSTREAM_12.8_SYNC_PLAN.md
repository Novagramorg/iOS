# Upstream Telegram-iOS 12.8 → Novagram (Fenixuz fork) — Master Sync Plan

> Generated 2026-06-21. Fork at **12.7.6** (`versions.json` → `"app": "12.7.6"`), upstream at **12.8** (`upstream/master`, checked out clean at `/tmp/tg-upstream-12.8`).
> This is the human-approved master plan. Execute phase by phase, build after each, never drop checkpoints until demo-login + IAP gate are re-verified.

---

## 1. Executive summary

We are integrating **upstream 12.8** into our **Novagram** fork (currently **12.7.6**). The fork is user-facing "Novagram" but keeps internal module names / bundle id (`uz.fenixuz.app`) / file names as "Fenixuz". All custom code lives in `submodules/Fenixuz/*` with 1–3 line hooks in Telegram-owned files, indexed in `submodules/Fenixuz/HOOKS.md`.

### Headline new features in 12.8

| Feature | Where | User-visible? |
|---|---|---|
| **InstantPage V2 + Rich Text Messages** (AI-streaming rich-data bubbles: headings, tables, lists, formulas, "Thinking…" blocks, progressive reveal, anchor nav) | `InstantPageUI`, new `RichTextMessageAttribute`, `ChatMessageRichDataBubbleContentNode` V1→V2 rewrite | Yes — the flagship |
| **Bot Connection Review** | TelegramCore — `NewBotConnectionReview`, OrderedItemList id 31 | Yes (Business bots) |
| **Web Browser Settings sync** | TelegramCore — `AccountWebBrowserSettings`, PreferencesKey 49 | Yes (Settings) |
| **Typing Drafts** (live preview of peer typing) | Postbox view classes + TelegramCore flow | Yes |
| **Paid Messages / no-paid-message exceptions** | TelegramUI + TelegramCore | Yes (server-gated) |
| **Monoforum / channel Direct-Messages suggested posts** | TelegramUI | Yes (server-gated) |
| **Link-open confirmation alerts w/ inline webpage preview** | new `OpenUserGeneratedUrl` + `AlertWebpagePreviewComponent` + `AlertHeaderComponent` | Yes |
| **Gift-based Chat Themes** | `ChatThemeScreen` | Yes |
| **iOS-26 Liquid Glass per-corner GlassBackground API** | `GlassBackgroundComponent` (86 consumers) | Cosmetic |
| **Unified Sessions/Websites/Connected-Bot screen** | `RecentSessionScreen` | Yes |
| **Reworked multi-mode AdsInfoScreen** | `AdsInfoScreen` | Yes |
| **WatchApp restoration** (new SwiftUI `tgwatch` app — *deleted in our fork, user wants it back*) | `Telegram/WatchApp/` | Yes (watchOS) |

Underneath all of this: a **mechanical MTProto/TL regeneration** (54 net-new constructor hashes) and upstream's continuation of the **Postbox → TelegramEngine refactor** across ~219 TelegramUI files — the same migration our fork runs wave-by-wave, which is *refactor noise* for features but *high-conflict* because both sides edit the same lines.

### Total effort estimate

| Cluster | Effort | Conflict risk |
|---|---|---|
| 1. InstantPage V2 + Rich Text Messages | **XL** | High |
| 2. MTProto API layer (TelegramApi) | **S** | Low |
| 3. TelegramCore new features (RichText/BotReview/WebBrowser/TypingDrafts) | **L** | High |
| 4. WatchApp restoration | **L** | Medium |
| 5. Fenixuz hook conflict (demo auth + IAP gate) | **L** | High |
| 6. Broad TelegramUI (non-rich-text) features + refactor noise | **XL** | High |

**Aggregate: roughly 3–4 weeks of focused integration work** (two XL clusters dominate). The two XL clusters (1 and 6) are the long poles; everything else is gated behind the MTProto + TelegramCore foundation. The risk profile is dominated by **hook preservation in 4 mega-diff files** (`ChatController.swift`, `SharedAccountContext.swift`, `ChatControllerNode.swift`, `AccountStateManagementUtils.swift`) and the **two business-critical hook families** (demo login auto-fill, Apple 3.1.1 IAP gate).

> **Pre-existing gap surfaced during analysis (decide before merge):** HOOKS.md documents Apple 3.1.1 IAP BotCheckout gates in `ChatController.swift`, `OpenResolvedUrl.swift`, and `WebAppController.swift` — **these are NOT in the working tree** (verified: 0 hits in all three at HEAD). The fork currently relies only on the `InAppPurchaseManager` stub, which does **not** cover the fiat-card BotCheckout path that caused the May-2026 rejection. See §4 and §7.

---

## 2. Dependency-ordered integration sequence

**MTProto API is the foundation — it must land first.** Everything else compiles against it. Phases are numbered; each phase ends with `./run.sh` + smoke test before the next begins.

> **Phase 0 — Safety (always first).** Checkpoint tag + backup branch (see §6).

| Phase | Cluster | What lands | Why this order |
|---|---|---|---|
| **1** | Cluster 2 | **MTProto / TelegramApi** wholesale directory replacement | Foundation. Every other cluster's API calls compile against it. Pure generated code, zero fork hooks. |
| **2** | Cluster 3 (+ Cluster 1's TelegramCore data-model files) | **TelegramCore data model + send/store/sync pipeline**: `RichTextMessageAttribute`, `NewBotConnectionReview`, `AccountWebBrowserSettings`, Typing-Drafts views, `.fbs` schemas | Data model must exist before any UI. Must land *with* TelegramApi (paired) — changed constructors need consumers or TelegramApi won't compile cleanly. RichText + Typing-Draft must land together (shared `AddPeerLiveTypingDraftUpdate` signature change). |
| **3** | Cluster 5 | **Auth/Fenixuz hook reconciliation** (demo auth, IAP gate, `AuthorizationSequenceController` Postbox→Engine absorb) | Depends on TelegramCore exposing `EngineCodableEntry` + `engine.resources.storeResourceData`. Lands early so demo-login is verified before the big UI clusters churn. |
| **4** | Cluster 1 (UI) | **InstantPage V2 renderer + rich bubble** (new modules `StreamingTextReveal`, `ShimmeringMask`, V2 InstantPageUI files, `ChatMessageRichDataBubbleContentNode` rewrite, 3 chat hook files) | Renderer is inert without the Phase-2 data model. Heaviest hook risk (`ChatControllerNode.swift`). |
| **5** | Cluster 6 | **Broad TelegramUI features** (Paid Messages, Monoforum, alert/link cluster, Gift Themes, GlassBackground, Sessions, Ads) + Postbox-refactor noise reconciliation | Depends on Phase 1+2 API and shares the Postbox-refactor track. Largest fan-out. |
| **6** | Cluster 4 | **WatchApp restoration** | Fully independent — off by default, no rich-text dependency. Land last so it never blocks core work. Can also be parallelized any time after Phase 0. |

**Pairing rule:** Phases 1 and 2 must land back-to-back (TelegramApi + TelegramCore are a paired landing; a half-landed state breaks the send path). Do **not** ship partial rich-text.

---

## 3. Per-cluster integration detail

### Cluster 1 — InstantPage V2 + Rich Text Messages  ·  Effort XL · Conflict High · **Phase 4** (TelegramCore parts in Phase 2)

**Summary.** The largest single feature in 12.8: a complete second InstantPage renderer ("V2") plus a new rich-text message type. A rich message is a `RichTextMessageAttribute` carrying an `InstantPage` (sent with `text:""`), drawn by `ChatMessageRichDataBubbleContentNode` via the V2 layout/renderer with AI-streaming progressive reveal, inline animated custom emoji, server-sent "Thinking…" blocks, "Show more" partial-page fetch, and anchor navigation. Our fork has **none** of the data model and **zero** MTProto wire support. Our existing 478-line `ChatMessageRichDataBubbleContentNode` is the OLD V1 webpage-Instant-View bubble; 12.8 rewrites it to 1554 lines. This lands as **one coherent unit** — renderer is useless without the attribute, attribute is useless without the TL layer.

**New files (counts).** ~17 new files: 10 `InstantPageUI/Sources/InstantPageV2*` + adapter/anchor/media files; 2 brand-new Bazel modules (`StreamingTextReveal`, `ShimmeringMask`); `SyncCore_RichTextMessageAttribute.swift`; `InstantPagePreviewText.swift`; `CustomEmojiMarkdownMarker.swift`; `InstantPageToMarkdown.swift`; plus regenerated `TelegramApi/Sources/Api42.swift`.

**Our files to edit (highlights).**
- **3 HOOK FILES (highest risk):** `ChatControllerNode.swift` (PRO MESSAGER auto-translate @~4690/4764, auto-text-adder @~4934, inlineStickers @~4796 — rich-send gate lands @~4860 in the *same* `sendCurrentMessage` function), `ChatInterfaceStateContextMenus.swift` (FenixuzEditedHistory @1219 + rich Copy), `Chat/ChatControllerLoadDisplayNode.swift` (sendMessages hook @981 + rich edit-load/save).
- `ChatMessageRichDataBubbleContentNode.swift` (V1 478→V2 1554 full replace) + its BUILD.
- `ChatMessageBubbleItemNode.swift` (+237, bubble selection, NOT a hook file — 3-way merge), `ChatMessageItem.swift` (+29).
- `ChatControllerInteraction.swift` — new field `scrollToMessageIdWithAnchor`; **init signature change ripples to every construction site** including any Fenixuz construction.
- TelegramCore: `SyncCore_RichText.swift` (+287), `SyncCore_InstantPage.swift` (+200), `ApiUtils/RichText.swift` + `InstantPage.swift`, `.fbs` schemas, `StoreMessage_Telegram.swift`, `StandaloneSendMessage.swift`, `FetchedMediaResource.swift`, `MessageUtils.swift`, `TelegramEngineMessages.swift` (`requestFullRichText`).
- Broad `effectiveMedia` swap set (~30 files: shared-media/gallery/playback/downloads). Type-identical `[Media]` swaps — compiles even if a site is missed → needs runtime QA, not just green build.

**Conflict risk: HIGH.** `ChatControllerNode.swift` is the worst — upstream rewrote `sendCurrentMessage` and the rich-send gate lands inside the same function as 3 Fenixuz hooks. Naive merge drops auto-translate + auto-sticker (silent breakage). Resolve manually one block at a time per HOOKS.md policy.

**Bazel BUILD changes.**
- Create 2 NEW packages: `StreamingTextReveal/BUILD` (deps: `[]`), `ShimmeringMask/BUILD` (deps: ComponentFlow, Display, HierarchyTrackingLayer).
- `InstantPageUI/BUILD` adds: InvisibleInkDustNode, EmojiTextAttachmentView, AnimationCache, MultiAnimationRenderer, SemanticStatusNode, TextProcessingScreen, Pasteboard, ComponentFlow, ShimmeringMask (all present except ShimmeringMask).
- `ChatMessageRichDataBubbleContentNode/BUILD`: drop `//submodules/Postbox`; add TextFormat, ChatMessageDateAndStatusNode, ChatControllerInteraction, TextLoadingEffect, TextSelectionNode, StreamingTextReveal.
- `.fbs` schemas regenerated by existing flatc genrule — **do NOT hand-edit checked-in `*_generated.swift`**.
- TelegramApi BUILD globs `Sources/` → automatic.

**Ordered steps.**
1. (Phase 1) Land MTProto/TL layer.
2. (Phase 2) Land TelegramCore data model: copy `SyncCore_RichTextMessageAttribute.swift`; apply `SyncCore_RichText.swift`/`SyncCore_InstantPage.swift` (enum-arity changes are compile-enforced — grep `.text(`/`.blocks(`/`.blockQuote(` repo-wide incl. `BrowserInstantPageContent.swift`, `CachedFaqInstantPage.swift`, `BrowserReadability.swift`); edit `.fbs`, let flatc regenerate; apply `ApiUtils/RichText.swift` + `InstantPage.swift`.
3. (Phase 2) Send/store/fetch pipeline: `StoreMessage_Telegram.swift` (incoming reconstruct + tag-index — the linchpin), `StandaloneSendMessage.swift` (flag bit 23), `SyncCore_StandaloneAccountTransaction.swift`, `FetchedMediaResource.swift`, `MessageUtils.swift`, `TelegramEngineMessages.swift`.
4. (Phase 4) Create `StreamingTextReveal` + `ShimmeringMask` modules; build in isolation.
5. Land TextFormat `CustomEmojiMarkdownMarker.swift` + `ChatTextInputAttributes`/`StringWithAppliedEntities` edits.
6. Land 10 new InstantPageUI V2 files + ~19 existing-file edits + BUILD deps; build InstantPageUI in isolation (largely self-contained).
7. Land BrowserUI (`BrowserMarkdown.swift` + `InstantPageToMarkdown.swift`) + TelegramStringFormatting (`InstantPagePreviewText.swift`, `MessageContentKind.swift`).
8. Add `ChatControllerInteraction.scrollToMessageIdWithAnchor`; fix every construction site.
9. Replace `ChatMessageRichDataBubbleContentNode.swift` + BUILD; wire selection + `getAnchorRect` in `ChatMessageBubbleItemNode.swift` + `ChatMessageItem.swift` (3-way merge).
10. **CAREFULLY re-apply the 3 HOOK FILES one at a time** (manual reconcile, not auto-merge). Update HOOKS.md in same commits.
11. Apply the broad `effectiveMedia` swap set (~30 files).
12. Full `./run.sh`; verify: markdown table/heading/list → rich bubble; edit → reconstructs markdown; copy → markdown on clipboard; demo-login auto-fill still works; Fenixuz Settings/Tasks/EditedHistory unaffected.

---

### Cluster 2 — MTProto API layer (TelegramApi/Sources)  ·  Effort S · Conflict Low · **Phase 1**

**Summary.** `TelegramApi/Sources` is 100% machine-generated MTProto/TL bindings. No `.tl` schema in repo (external codegen). 12.8 is a pure layer bump: mechanical regeneration redistributing constructors across the numbered `Api*.swift` files. **Our fork has ZERO divergence here** — TelegramApi is absent from HOOKS.md, has no Fenixuz hooks. The file SET is name-identical between fork and upstream (no brand-new filenames, no orphans). 54 net-new constructor hashes are the real payload.

**New files.** None brand-new. `Api41.swift`/`Api42.swift` content fully replaced; all 42 `Api*.swift` regenerated/redistributed. `SecretApiLayer*.swift`, `Buffer.swift`, `DeserializeFunctionResponse.swift`, `TelegramApi.h`, `TelegramApiLogger.swift` byte-identical.

**Our files to edit.** **NONE.** `BUILD` and `Package.swift` are identical to upstream (zero diff) — leave untouched.

**Conflict risk: LOW.** No hooks to lose. Only risk is a compile mismatch with consumers (10 schema entries changed/removed upstream — all standard Instant-View/page types, none Fenixuz-custom). Mitigated by pairing with TelegramCore (Phase 2).

**Bazel BUILD changes.** None (globs `Sources/`).

**Ordered steps.**
1. Land FIRST.
2. Confirm `git status` clean under `submodules/TelegramApi/Sources/` (no WIP).
3. Replace directory wholesale: `rsync --delete` / `cp` of each `Api*.swift` from upstream. Safe — name-identical set, no fork-local files.
4. Do NOT touch BUILD/Package.swift.
5. Sanity-check registry grew: `grep -c 'dict\[' Api0.swift` ≈ 1619 after copy (was 1575).
6. **Do NOT partially copy individual `Api*.swift`** — upstream moved constructors between file numbers; partial copy → duplicate/missing-symbol errors. Atomic only.
7. Build; any break surfaces as "missing Api.X case" in TelegramCore → signal to land Phase 2, NOT to hand-edit TelegramApi.
8. Verify demo-login end-to-end after full build (auth exercises a large API surface).

---

### Cluster 3 — TelegramCore new features  ·  Effort L · Conflict High · **Phase 2**

**Summary.** Four data/sync-layer features: (1) **RichTextMessageAttribute** (registered via `declareEncodable`, threaded through send/edit/store). (2) **Bot Connection Review** (`NewBotConnectionReview`, OrderedItemList namespace 31, `updateNewBotConnection` update, `confirmBotConnectionReview(botId:)`). (3) **Web Browser Settings sync** (`AccountWebBrowserSettings`, PreferencesKey 49, hourly `managedWebBrowserSettingsUpdates`). (4) **Typing Drafts** (`TypingDraftsView`/`AllTypingDraftsView` + PostboxViewKey cases). Our Postbox **already has** the typing-draft backing store — only the two view classes + Views.swift registration are missing — but the TelegramCore flow still uses the OLD `AddPeerLiveTypingDraftUpdate` signature, so it upgrades in lockstep with RichText.

**New files (7).** `SyncCore_RichTextMessageAttribute.swift`, `SyncCore_NewBotConnectionReview.swift`, `BotConnectionReviews.swift`, `AccountWebBrowserSettings.swift`, `ManagedWebBrowserSettingsUpdates.swift`, `Postbox/TypingDraftsView.swift`, `Postbox/AllTypingDraftsView.swift`. All copy-verbatim.

**Our files to edit (keystones).** `AccountManager.swift` (declareEncodable — **hand-merge**), `AccountIntermediateState.swift` (keystone enum changes), `AccountStateManagementUtils.swift` (most-rewritten, carries EditedHistory hook), `SyncCore_Namespaces.swift` (id 31, key 49), `Views.swift` (Postbox view keys), `OrderedListsData.swift`, `TelegramEngineAccountData.swift`, `AccountTaskManager.swift`, plus the full send/edit/store pipeline (`StoreMessage_Telegram.swift`, `EnqueueMessage.swift`, `RequestEditMessage.swift`, `PendingUpdateMessageManager.swift`, `StandaloneSendMessage.swift`, `PendingMessageManager.swift`, `Message.swift`, `TelegramEngineMessages.swift`, `SyncCore_StandaloneAccountTransaction.swift`).

**Conflict risk: HIGH — two confirmed Fenixuz collisions:**
- **`AccountManager.swift` declareEncodable block** — our fork registers `EditedMessageHistoryAttribute` + `DeletedMessageAttribute`. Wholesale upstream copy DROPS both → silent break of Edited-message-history viewer. **Hand-merge:** keep both Fenixuz lines, add only the RichText line.
- **`AccountStateManagementUtils.swift`** — carries HOOKS.md EditedHistory gate (~line 1184) AND is the most-rewritten file (301-line diff incl. `MergePeerPresences → UpdatedApiPresence`). Re-apply by **anchor** (`messages[0].attributes.first(where: { $0 is EditedMessageHistoryAttribute })`), not line number.
- **`EnqueueMessage.swift`** carries the Ghost read-on-send hook (HOOKS.md §1) + auto-sticker hook — re-apply both on merged file.
- Engine-typealias/Postbox-refactor collision: **NONE** — all 7 new files are TelegramCore/Postbox-internal and correctly `import Postbox` (only `@_exported import Postbox` is banned). No DB schema-version bump needed.

**Bazel BUILD changes.** None — TelegramCore globs `Sources/**/*.swift`, Postbox globs `Sources/*.swift`. 7 new files auto-picked-up. No new module deps (all import existing Foundation/Postbox/SwiftSignalKit/TelegramApi/MtProtoKit). Confirm TelegramApi regenerated first.

**Ordered steps.**
1. Land TelegramApi (Phase 1) + InstantPage/RichText TelegramCore files first.
2. Copy the 7 new files verbatim.
3. `SyncCore_Namespaces.swift`: add `OrderedItemList.NewBotConnectionReviews = 31` + `PreferencesKeyValues.webBrowserSettings = 49` + the `PreferencesKeys.webBrowserSettings` ValueBoxKey block. **Verify no Fenixuz preference already squats on 49.**
4. `AccountManager.swift`: hand-merge — keep both Fenixuz declareEncodable lines, add RichText.
5. `AccountIntermediateState.swift` (keystone): add `PeerLiveTypingDraftUpdateContent` enum, change `AddPeerLiveTypingDraftUpdate` to `(content:)`, add UpdateNewBotConnection/WebBrowserSettings/WebBrowserException ops. Reconcile `MergePeerPresences→UpdatedApiPresence`.
6. `AccountStateManagementUtils.swift`: re-apply EditedHistory hook by anchor on the rewritten file, then add `updateNewBotConnection` parse, RichMessage parse sites, final-apply handlers.
7. `Views.swift`: add `.typingDrafts`/`.allTypingDrafts` keys + hash/equality arms (keep upstream's `.contacts` hash bump 16→24) + dispatch.
8. `OrderedListsData.swift`: add NewBotConnectionReviews item (skip the unrelated ItemCollections enum — belongs to a different cluster).
9. `TelegramEngineAccountData.swift`: add `confirmBotConnectionReview(botId:)`. `AccountTaskManager.swift`: add `managedWebBrowserSettingsUpdates(...)`.
10. Thread RichText through the send/edit/store pipeline; re-apply Ghost read-on-send hook on `EnqueueMessage.swift`.
11. `./run.sh` + Fenixuz smoke: demo-login, EditedHistory viewer opens (confirms declareEncodable survived), Ghost read-on-send still marks read.

---

### Cluster 4 — WatchApp restoration  ·  Effort L · Conflict Medium · **Phase 6** (independent)

See dedicated **§5 — WatchApp restoration** below for the full plan.

---

### Cluster 5 — Fenixuz hook conflict (demo auth + Apple 3.1.1 IAP gate)  ·  Effort L · Conflict High · **Phase 3**

**Summary.** Protects the two business-critical hook families: Apple-Review **demo-account SMS auto-fill** (login flow) and **Apple 3.1.1 IAP/Premium-checkout block**. Good news: demo-login hooks all present and cleanly separable. **Serious pre-existing gap:** 3 of 4 documented IAP BotCheckout gates (`ChatController`, `OpenResolvedUrl`, `WebAppController`) + the `AppDelegate isAppStoreBuild` line are **NOT in the tree** — HOOKS.md is stale/aspirational for them (confirmed during this analysis: 0 hits in all three). Separately, 12.8 moved ahead on Postbox→TelegramEngine (`CodableEntry→EngineCodableEntry`, `postbox.mediaBox→engine.resources`) which must be absorbed in `AuthorizationSequenceController`.

**New files.** NONE — this is a per-file hook-reconciliation cluster.

**Our files to edit (highlights).**
- `HOOKS.md` (**fix FIRST** — reconcile stale IAP-gate doc to reality, or restore the gates).
- Demo/brand auth files: `AuthorizationSequenceCodeEntryController.swift` (LOW), `…CodeEntryControllerNode.swift` (LOW/MED), `…PhoneEntryController.swift` (LOW), `…PhoneEntryControllerNode.swift` (MED/HIGH — ~224-line QR-login hook), `…SplashController.swift` (LOW), `…Controller.swift` (LOW + absorb Postbox→Engine), `…PasswordEntryController.swift` (companion).
- `InAppPurchaseManager.swift` (**KEEP our 153-line stub, DISCARD upstream 931-line StoreKit version**) + BUILD (keep 3-dep, discard upstream 5-dep).
- `ChatController.swift` / `OpenResolvedUrl.swift` / `WebAppController.swift` (IAP gates — **DECISION**, currently absent).
- `AppDelegate.swift` (StoreKit-removal hooks present LOW; `isAppStoreBuild` line absent; absorb upstream icon-list + ProxyServerPreviewScreen — MED).
- `TelegramCore/.../Payments/AppStore.swift` (upstream removed `RestoreAppStoreReceiptError` — verify no fork consumer before deleting).

**Conflict risk: HIGH.** See §7 for the per-file table.

**Bazel BUILD changes.** `InAppPurchaseManager/BUILD`: keep 3-dep list (FenixuzAppStoreIAP, SwiftSignalKit, TelegramCore), discard upstream's StoreKit-era 5-dep. `AuthorizationUI/BUILD`: retain 3 Fenixuz deps. `TelegramUI/BUILD` + `WebUI/BUILD`: add `//submodules/Fenixuz/AppStoreIAP` dep **only if** the 3 BotCheckout gates are restored.

**Ordered steps.** See §7 (this cluster IS the hook-protection plan). Key sequence: (0) checkpoint → (1) reconcile HOOKS.md + decide on IAP gates → (2) merge/pull → (3) keep our InAppPurchaseManager wholesale → (4) re-apply 5 LOW demo/brand hooks by anchor → (5) absorb Postbox→Engine in `AuthorizationSequenceController` → (6) re-apply 224-line QR hook LAST → (7) AppDelegate hooks → (8) optionally restore 3 IAP gates → (9–10) remaining ChatController stickers + AppStore.swift verify → (11) build + manual demo-login + invoice-block smoke.

---

### Cluster 6 — Broad TelegramUI (non-rich-text) features + refactor noise  ·  Effort XL · Conflict High · **Phase 5**

**Summary.** Of ~350 changed `.swift` under `submodules/TelegramUI/Components/`, **219 (63%) change ONLY by removing `import Postbox` + renaming Postbox→Engine types** — upstream's continuation of the same migration our fork runs wave-by-wave. **Refactor NOISE for features, HIGH conflict because both sides edit the same lines.** Genuine new features: Paid Messages / no-paid exceptions; Monoforum suggested-posts; link-open confirmation alerts (new `OpenUserGeneratedUrl` + `AlertWebpagePreviewComponent` + `AlertHeaderComponent`); Guest-chat tooltip; Gift-based Chat Themes; iOS-26 Liquid Glass `GlassBackground` per-corner API (86 consumers); unified Sessions/Websites/Connected-Bot `RecentSessionScreen`; multi-mode `AdsInfoScreen`. **`StreamingTextReveal` + `ShimmeringMask` belong to Cluster 1 — do NOT double-port here.**

**New files (counts).** ~12: `OpenUserGeneratedUrl` (+BUILD), `AlertWebpagePreviewComponent` (+BUILD), `AlertHeaderComponent` (+BUILD), `ChatControllerDisplayGuestChatMessageTooltip.swift`, `ChatSendMessageRichTextPreview.swift` (+ the two rich-text modules owned by Cluster 1).

**Our files to edit.** `ChatController.swift` (2749-line diff — heaviest), `SharedAccountContext.swift` (1257), `ChatInterfaceStateContextMenus.swift`, `ChatTextInputPanelNode.swift`, `PeerInfoSettingsItems.swift` (ProMessager/Tasks Settings entries), `ChatControllerOpenLinkContextMenu.swift`, `NavigateToChatController.swift`, `OpenResolvedUrl.swift`, `StoreDownloadedMedia.swift`, `GlassBackgroundComponent.swift`, `ChatThemeScreen.swift`, `RecentSessionScreen.swift`, `AdsInfoScreen.swift`, `HOOKS.md`. (~18 hooked files total.)

**Conflict risk: HIGH.** Postbox→Engine overlap is the biggest risk — careless merge reverts our completed waves or double-applies renames. The `diff-filter=D` list flags **our OWN assets** as "removed upstream" (`FenixAccountSwitchContextItem.swift`, `FenixGhost*` imagesets, `IconTasks` tab icon) — these MUST be kept, do not delete. Many real features (Paid Messages, Monoforum) are server-gated → may render dead UI; verify they don't crash on nil server config.

**Bazel BUILD changes.** Add 5 new packages' BUILD: `OpenUserGeneratedUrl`, `AlertWebpagePreviewComponent`, `AlertHeaderComponent`, `ShimmeringMask`, `StreamingTextReveal` (last two only if Cluster 1 ported). Add as deps in `TelegramUI/BUILD` where consumed. Upstream DELETES `//submodules/Postbox` from ~219 component BUILD files — accepting those edits must stay in **lockstep** with matching source `import Postbox` removals.

**Ordered steps.**
1. **TRIAGE FIRST:** split ~350 changes into (a) Postbox-only refactor (219 files) via `git diff HEAD upstream/master -- submodules/TelegramUI/ | grep '^-import Postbox'`, and (b) real diffs. Treat (a) as the refactor track.
2. **Decide Postbox-refactor policy:** (i) accept upstream import-removals wholesale for non-hooked leaf files (fast, jumps our wave plan ahead), or (ii) keep ours + re-apply only real hunks. **Recommend (i) for non-hooked leaves, (ii) for our 18 hooked files.** Record decision before touching code.
3. Land the alert/link cluster as a unit: copy 3 new dirs + BUILD, wire `SharedAccountContext.openUserGeneratedUrl`, re-apply `ChatControllerOpenLinkContextMenu` changes.
4. Port `GlassBackgroundComponent` CornerRadii/customRoundedRect API (additive), then accept 86 consumer call-site updates.
5. Port real features individually, each gated on its TelegramCore API: Paid Messages, Monoforum (both heavily edit ChatController), Gift Themes (ChatThemeScreen), Guest tooltip, Sessions RecentSessionScreen, multi-mode AdsInfoScreen.
6. For each of 18 hooked files: AI-assisted one-file-at-a-time re-apply against HOOKS.md (highest: ChatController 2749, SharedAccountContext 1257).
7. Update HOOKS.md with new line numbers in same commits.
8. EXCLUDE StreamingTextReveal + ShimmeringMask (Cluster 1).
9. `./run.sh` + verify demo-login + 5 Fenixuz features (Tasks tab, ProMessager Settings, Ghost read-on-send, account-switch context item, chat-lock) intact before dropping backup tag.

---

## 4. Hook protection — per-file conflict table

> **Re-apply strategy (per `Telegram-iOS/CLAUDE.md` upstream-pull policy):** Fenixuz hooks always win; upstream code wins around them. Re-apply **by anchor, never by line number**. AI-assisted, one file at a time. Never auto-accept either side. Update HOOKS.md in the same commit. HOOKS.md is the source of truth (1612 lines; "Last verified 2026-05-19 against `9ed152eb6b`").

**Business-critical (🔴 — a silent loss = App Store rejection):**

| File | Hook | Risk | Re-apply anchor |
|---|---|---|---|
| 🔴 `AuthorizationSequenceCodeEntryController.swift` | demo auto-fill in `viewDidAppear` | LOW | after `activateInput` |
| 🔴 `AuthorizationSequenceCodeEntryControllerNode.swift` | `fenixuzHideNextOption` + countdown-overwrite guard | LOW/MED | after the 3 nextOption node decls; guard inside `currentTimeoutTime>0` branch (the one preceded by `authorizationNextOptionText(...timeout:...)`) |
| 🔴 `AuthorizationSequencePhoneEntryController.swift` | 2× `prewarmIfDemo` | LOW | before each `loginWithNumber?` |
| 🔴 `AuthorizationSequencePhoneEntryControllerNode.swift` | ~224-line visible QR-login button + `showQrOverlay` (replaces upstream `debugQrTap` body) | **MED/HIGH** | `import FenixuzLocalization`; `qrLoginButtonNode`; init setup/addSubnode/addTarget; `containerLayoutUpdated` visibility+frame; `showQrOverlay`/`dismissQrOverlay`/`applyQrOverlayLayout`. **Re-apply LAST.** Verify `refreshQrToken()`/`qrNode` still upstream (they are). |
| 🔴 `AppStoreIAP` gate — `ChatController.swift` ~3568 | bot invoice tap `shouldBlock` | **DECISION (absent)** | new-checkout else-branch before inputData Promise |
| 🔴 `AppStoreIAP` gate — `OpenResolvedUrl.swift` ~1425 | `t.me/$slug` deep-link invoice | **DECISION (absent)** | else-branch after XTR Stars, before `BotCheckoutController` |
| 🔴 `AppStoreIAP` gate — `WebAppController.swift` ~1296 | `web_app_open_invoice` | **DECISION (absent)** | after XTR handling, before `BotCheckoutController` (+ `sendInvoiceClosedEvent(...cancelled)`) |
| 🔴 `InAppPurchaseManager.swift` | 153-line StoreKit-removal stub | take OURS wholesale | public API byte-identical to upstream's — consumers compile unchanged |

**Other Fenixuz hooks in changed files (🟡):**

| File | Hook | Risk |
|---|---|---|
| 🟡 `ChatControllerNode.swift` | PRO MESSAGER auto-translate @4690/4764, auto-text-adder @4934, inlineStickers @4796 (rich-send gate lands @4860 same function) | **HIGH — Cluster 1** |
| 🟡 `ChatInterfaceStateContextMenus.swift` | FenixuzEditedHistory action @1219 | MED |
| 🟡 `Chat/ChatControllerLoadDisplayNode.swift` | sendMessages hook @981 | MED |
| 🟡 `AccountManager.swift` | declareEncodable `EditedMessageHistoryAttribute` + `DeletedMessageAttribute` | **HIGH — hand-merge** |
| 🟡 `AccountStateManagementUtils.swift` | EditedHistory gate ~1184 | **HIGH — anchor by `EditedMessageHistoryAttribute`** |
| 🟡 `EnqueueMessage.swift` | Ghost read-on-send (§1) + auto-sticker | HIGH |
| 🟡 `ChatController.swift` | sticker #30 (~2415), #38 (~2300/2443), Ghost read-on-send | HIGH (2749-line diff) |
| 🟡 `SharedAccountContext.swift` | demo/IAP + account-switch hooks | HIGH (1257-line diff) |
| 🟡 `PeerInfoSettingsItems.swift` | ProMessager / Tasks Settings entries | MED |
| 🟡 `AuthorizationSequenceSplashController.swift` | emerald brand colors | LOW |
| 🟡 `AuthorizationSequenceController.swift` | 2FA-back `displayBack` (@919/938/1325, untouched upstream) + absorb Postbox→Engine | MED |
| 🟡 `AuthorizationSequencePasswordEntryController.swift` | 2FA-back companion | LOW |
| 🟡 `AppDelegate.swift` | StoreKit-removal + NSE peerId fallback + Novagram icon list | MED |
| 🟡 `OpenResolvedUrl.swift` | (refactor + optional IAP gate) | LOW (file barely changed) |
| 🟡 `StoreDownloadedMedia.swift` | (currently modified in working tree) | LOW |

**Total: 27 changed hook-bearing files** spanning AuthorizationUI, TelegramUI, TelegramCore, Postbox, and config. The 4 mega-diff files (`ChatController.swift`, `SharedAccountContext.swift`, `ChatControllerNode.swift`, `AccountStateManagementUtils.swift`) carry the most risk because a 1–3 line hook is easy to lose in a 1000–2700-line diff → silent feature breakage.

**Re-apply strategy summary:**
1. Checkpoint-commit before touching any mega-diff file.
2. Open HOOKS.md, locate the hook block, find its **anchor** (surrounding upstream code), re-apply at the new position.
3. Build after each file (or each small batch).
4. After all hooks re-applied: run the Fenixuz feature smoke (demo-login, EditedHistory viewer, Ghost read-on-send, Tasks tab, ProMessager Settings, account-switch context item, chat-lock).

---

## 5. WatchApp restoration

The user explicitly wants the deleted `tgwatch` SwiftUI watch app back, under **Apple team ZDBP5RSRZF (Vipads MCHJ)** and **Novagram bundle `uz.fenixuz.app`**.

**What was deleted.** The entire NEW standalone watch app `Telegram/WatchApp/` (957 tracked files: independent `tgwatch.xcodeproj` SwiftUI app + local SPM packages TDShim/RLottieKit/WebPKit/OpusKit/QRCodeGenerator), the glue files `Telegram/prebuilt_watchos.bzl` + `Telegram/prebuilt_watchos_build.sh`, and the 169-line watch-embed block in `build-system/Make/Make.py`.

> **Leave alone:** the OLD legacy ObjC `Telegram/Watch/` tree — byte-identical to upstream, referenced by no BUILD target.

**How it embeds.** Custom Bazel rule `apple_prebuilt_watchos_application` shells to `xcodebuild -scheme "tgwatch Watch App" -configuration Release`, codesigns with the watchkitapp profile; host `ios_application` consumes via `watch_application = select({":embedWatchAppSetting": ":TelegramWatchApp", ...})`. **OFF by default** (`embedWatchApp=False`), device-configs only → **ZERO effect on simulator `./run.sh`**, zero dependency on rich-text work. Bundle id flows automatically: `{telegram_bundle_id}.watchkitapp` → `uz.fenixuz.app.watchkitapp` (config already resolves `telegram_bundle_id=uz.fenixuz.app`); watch Info.plist derives `WKCompanionAppBundleIdentifier` via `$(PRODUCT_BUNDLE_IDENTIFIER:base)` — no plist patching per host.

**Bazel BUILD changes — 4 additive splices to `Telegram/BUILD` (take ONLY the watch hunks):**
1. After `local_provisioning_profile` load (~line 36): `load("//Telegram:prebuilt_watchos.bzl", "apple_prebuilt_watchos_application")`.
2. Near config_settings (~line 101): `bool_flag(name="embedWatchApp", default=False)` + `config_setting(name="embedWatchAppSetting", flag_values={":embedWatchApp":"True"})`.
3. Before host `ios_application(name="Telegram")` (~line 1727): `apple_prebuilt_watchos_application(name="TelegramWatchApp", bundle_id="{telegram_bundle_id}.watchkitapp".format(...), tags=["manual"])`.
4. Inside host `ios_application`: `watch_application = select({":embedWatchAppSetting": ":TelegramWatchApp", "//conditions:default": None})`.

> **⚠️ BRANDING TRAP:** the same `Telegram/BUILD` upstream diff also flips `bundle_name` Novagram→Telegram, swaps Fenix* alternate icons for upstream's, drops PrivacyManifest, sets `composer_icon_folders`. **These are NOT watch changes — do NOT take them** (they revert the Novagram rebrand). Splice ONLY the 4 watch hunks.

Plus: `Make.py` 169-line block (5 BazelCommandLine fields + `set_watch_app()`, the `resolve_watch_provisioning_profile()` guard, the `if arguments.embedWatchApp:` gate, 5 argparse args on both build+remote subparsers), `RemoteBuild.py` 5 `guest_build_sh` lines (~139).

**Ordered steps.**
1. Copy `prebuilt_watchos.bzl` + `prebuilt_watchos_build.sh` into `Telegram/` (verbatim).
2. Copy the entire `Telegram/WatchApp/` tree (957 files) from upstream.
3. **Scrub stale personal team** `C67CF9S4VU → ZDBP5RSRZF`: `project.yml` (~line 72 DEVELOPMENT_TEAM) + `tgwatch.xcodeproj/project.pbxproj` (lines ~470/634/656). (Apple-team rule forbids leaving `C67CF9S4VU` on sight even though `CODE_SIGNING_ALLOWED=NO` at xcodebuild time.)
4. Apply the 4 additive `Telegram/BUILD` splices — watch hunks ONLY, skip branding hunks.
5. Port `Make.py` 169-line block + `RemoteBuild.py` 5 lines (purely additive).
6. **Apple Developer portal (team ZDBP5RSRZF):** register App ID `uz.fenixuz.app.watchkitapp`, create App Store + Development provisioning profiles, add as `WatchApp.mobileprovision` (the `.watchkitapp→WatchApp` mapping already exists in `BuildConfiguration.py`).
7. Smoke-test isolation: normal `./run.sh` builds unchanged (proves zero coupling).
8. Standalone target: `bazel build //Telegram:TelegramWatchApp --define=watchApiId=35846757 --define=watchApiHash=... --define=buildNumber=1` (unsigned).
9. Device build once profile exists: `Make.py build --configurationPath=build-system/appstore-configuration.json --embedWatchApp --watchApiId=35846757 --watchApiHash=67cdc52f3eda13727603d4e779ee2894`; verify signed `Watch/` payload in IPA.
10. Document the 4 splice points + Make.py/RemoteBuild.py block in HOOKS.md.
11. Track the 957+2 new files in git.

**⚠️ Main risk — provisioning (Apple portal, not code):** `resolve_watch_provisioning_profile()` HARD-RAISES on any distribution build if `WatchApp.mobileprovision` is absent (host `ios_application` does NOT re-sign the watch app → unsigned `Watch/` payload ships → silent App Store rejection, error 90389-class). **Create the App ID + profile under ZDBP5RSRZF first. Until then, keep `publish.sh` WITHOUT `--embedWatchApp`** so releases keep shipping (no watch) instead of failing. Watch min-OS is **watchOS 26.0** (project.yml) — upstream's choice; do not lower. First `xcodebuild` resolves `QRCodeGenerator` from GitHub (needs network; rule sets `requires-network`) → fully offline build will fail package resolution. **No Fenixuz hooks inside the watch tree** (verified zero Fenixuz/Novagram strings) — nothing of ours is at risk inside `WatchApp/`; only `Telegram/BUILD` + `Make.py` + `RemoteBuild.py` are touched, all additive.

---

## 6. Safety protocol

**Phase 0 — before any code touches (mandatory):**
```bash
git tag pre-pull-checkpoint-$(date +%Y%m%d-%H%M)
git branch backup-before-merge-$(date +%Y%m%d)
git status --short | grep -v '^??'   # confirm no unexpected WIP before proceeding
```
> Current working tree has 14 modified files (Localizable.strings, IntentHandler.swift, HOOKS.md, etc.) + untracked screenshots — **commit or stash these into the checkpoint first** so the merge starts clean.

**During — build after EACH phase via `./run.sh`:**
```bash
rm -f /tmp/run-sh-output.log && nohup bash run.sh > /tmp/run-sh-output.log 2>&1 &
disown 2>/dev/null
until grep -qE "Build muvaffaqiyatli|ERROR: Build did NOT" /tmp/run-sh-output.log; do sleep 5; done
tail -25 /tmp/run-sh-output.log
```
- A green build is NOT sufficient — `effectiveMedia` swaps and Postbox renames compile even when a site is missed.
- Checkpoint-commit before touching any of the 4 mega-diff hook files.

**After EACH phase — Fenixuz regression smoke (must pass before next phase):**
1. **Demo login auto-fill** — enter `+998335999479`, confirm the code field auto-fills (the App Store reviewer path). **Non-negotiable.**
2. **Apple 3.1.1 IAP gate** — if the 3 BotCheckout gates are restored (§7 decision 1a): tap a Premium/subscription invoice → must end at the localized block alert, NOT `BotCheckoutController`. If not restored: it opens BotCheckout (current unguarded state) — note the risk.
3. EditedHistory viewer opens (confirms the two `declareEncodable` lines survived).
4. Ghost read-on-send still marks chats read.
5. Tasks tab, ProMessager Settings, account-switch context item, chat-lock all present.
6. Emerald intro screen + visible QR-login button + overlay.

**Only after demo-login + IAP gate + all Fenixuz features verified → drop the checkpoint tag + backup branch.** If anything regresses, roll back to `pre-pull-checkpoint-*` / `backup-before-merge-*`.

**Do NOT `git push` without explicit user permission.** Local commits only.

---

## 7. Open questions / decisions for the user

1. **🔴 Restore the 3 Apple 3.1.1 IAP BotCheckout gates?** (recommended.) HOOKS.md claims gates in `ChatController.swift` (~3568), `OpenResolvedUrl.swift` (~1425), `WebAppController.swift` (~1296) — **but they are NOT in the tree** (verified 0 hits). The `@PremiumBot` fiat-subscription path that caused rejection `d5a06920-...` reaches `BotCheckoutController` directly, bypassing the `InAppPurchaseManager` stub → **currently UNGUARDED**. A 12.8 resubmission could re-trigger 3.1.1 rejection. Restore (low effort, stable anchors) or knowingly ship without?
   - If restore: also add `FenixuzAppStoreIAP.isAppStoreBuild` line in AppDelegate + the `//submodules/Fenixuz/AppStoreIAP` dep to `TelegramUI/BUILD` + `WebUI/BUILD`.

2. **Postbox→TelegramEngine refactor policy** (Cluster 6, 219 files). Recommended: accept upstream's import-removals wholesale for non-hooked leaf files (fast, jumps our wave-by-wave plan ahead), keep ours + re-apply hunks for the 18 hooked files. Confirm this is acceptable vs. preserving the strict wave sequence.

3. **WatchApp Apple portal setup.** Restoring the watch app requires registering App ID `uz.fenixuz.app.watchkitapp` + provisioning profiles under team ZDBP5RSRZF **before** any distribution build with `--embedWatchApp`. Who creates these in the portal, and do you want the watch shipped in the next App Store build or deferred (code restored, `publish.sh` left without `--embedWatchApp`)?

4. **AppDelegate alternate-app-icon list** (cosmetic). Upstream reverted to Blue/Premium icons; Novagram wants Fenix/Novagram icons. Confirm we keep the Novagram icon set (default assumption: yes).

5. **`RestoreAppStoreReceiptError` deletion** — upstream removed this enum from `TelegramCore/.../Payments/AppStore.swift`. Default: grep-verify no fork consumer references it, then accept the deletion. (Our stub does not use it.)

6. **Ship rich-text as one unit** — confirm we will NOT ship a partial rich-text state (half-landed sends/renders nothing and risks corrupting the send path). The cluster is inert until the TelegramApi layer lands; Phases 1+2 must be paired.
