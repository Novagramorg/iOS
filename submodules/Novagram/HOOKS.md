# Novagram hooks in Telegram-owned files

This file is the **source of truth** for every line of Novagram code that lives outside `submodules/Novagram/`. Each entry describes:

1. The exact file + region that is modified
2. The hook code itself
3. Why it lives outside a Novagram module (i.e. cannot be expressed as pure Novagram code)

On every upstream update (`submodules/Novagram/scripts/novagram-upstream-update.sh`, see "Pull conflict workflow"), an AI assistant uses this file to re-apply hooks if upstream code moved. **Novagram hooks always win** against upstream changes; surrounding upstream code is taken as-is.

> Last verified: 2026-05-19 against upstream commit `9ed152eb6b` (Novagram master). 2026-05-16 added DeviceAccess contacts-consent hook for Apple Review 5.1.2 rejection fix. 2026-05-19 added ApplicationContext.swift hook to defer the silent post-login contacts auto-prompt by 1 second (initial attempt that day silenced the auto-prompt entirely; that was reverted the same day after the user reported the consent + iOS alerts never appeared — the deferred version restores both alerts while still letting the Chats tab finish its layout before the alert presents). 2026-05-19 (later same day) replaced the `InAppPurchaseManager.swift` runtime gate with a complete rewrite that removes the StoreKit code path entirely (`SKPaymentQueue`, `SKProductsRequest`, `SKPayment`, `SKReceipt*` no longer reachable); also dropped the now-unused `import StoreKit` from `AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift`, and in `TelegramUI/Sources/AppDelegate.swift` both dropped the import and replaced the iOS 15+ `AppStore.showManageSubscriptions(in:)` Manage Subscriptions sheet with the web fallback URL (no StoreKit-backed subscriptions exist on this fork so the system sheet would be empty anyway). 2026-07-17 added the "Deleted messages (anti-delete)" section documenting `DeletedMessageAttribute` (new TelegramCore file) plus its five Telegram-owned hook sites (AccountManager registration, AccountStateManagementUtils delete interception, ChatHistoryEntriesForView display filter, StringForMessageTimestampStatus label, ChatHistoryListNode reactivity gate) — this feature previously had zero HOOKS.md coverage despite touching 5 upstream files, a merge risk now closed. 2026-07-17 (same day, Wave 2) updated that section: `DeletedMessageAttribute` gained a `timestamp: Int32` payload (key `"t"`, backward-compatible decode), `AccountStateManagementUtils.swift`'s delete interception is now itself gated on `show_deleted_messages` (capture+retain only when ON, real delete when OFF — previously capture was unconditional and only display was gated), and `StringForMessageTimestampStatus.swift`'s label now renders the captured deletion time. Also flagged (not fixed) a pre-existing gap: `AccountManager.swift:247`'s `declareEncodable` factory still ignores its decoder argument, so the persisted timestamp does not currently survive a disk decode round-trip — see the ⚠️ note in that section. 2026-07-17 (later same day) added the "Bot token login" section documenting the new `submodules/TelegramCore/Sources/NovagramBotAuthorization.swift` file plus three `AuthorizationUI` hook sites (`AuthorizationSequencePhoneEntryController(+Node)` secondary button, `AuthorizationSequenceController` screen wiring) and the `AuthorizationUI/BUILD` dep — login-only, additive, existing phone-login path untouched. 2026-07-17 (later same day) added the "Novagram banner ads" section documenting the OURS-FIRST `.link` `ChatListNotice` injection in `GlobalControlPanelsContext.swift` (producer branch + dismiss branch) and the click-report branch in `ChatListUI/Sources/ChatListControllerNode.swift`, plus the `GlobalControlPanelsContext/BUILD` dep addition (`ChatListUI/BUILD` and `NovagramAds/BUILD` needed no change — already satisfied by the earlier search-ads/chat-ads hooks). 2026-08-26 (Wave 3) closed two remaining gaps in the "Deleted messages" feature: `AccountManager.swift`'s `declareEncodable` factory now honors its decoder so the persisted `timestamp` survives a disk decode / app relaunch (previously flagged in Wave 2 as a known gap, now fixed — line moved `:247` → `:251`), `SyncCore_StandaloneAccountTransaction.swift` gained a `DeletedMessageAttribute` carry-forward (same shape as the existing `EditedMessageHistoryAttribute` one, fixing the same groups/channels re-sync loss), and — the actual P0 fix — `Telegram/NotificationService/Sources/NotificationService.swift` received its first-ever Novagram hook: the notification extension's silent `MESSAGE_DELETED` handling is now gated on the toggle too, via a new shared/App-Group-aware helper (`submodules/TelegramCore/Sources/Novagram/NovagramShowDeletedMessages.swift`, also wired into `AccountStateManagementUtils.swift`'s two capture-gate call sites) — this fixes anti-delete silently doing nothing whenever the app was backgrounded, which is when a peer's delete most commonly arrives. 2026-08-27 added two independent hooks: `ResolvePeerByName.swift` gained a `ResolvedPeerByPhone`/`EngineResolvedPeerByPhone` split so `TelegramEnginePeers.swift`'s new `resolvePeerByPhoneWithStatus(phone:ageLimit:)` (and `ChatControllerOpenPhoneContextMenu.swift`, which now calls it) can tell a failed RPC apart from a genuine "not on Telegram" answer — the phone context menu previously collapsed both into the same "This number is not on Telegram" text, now a failed lookup gets a "Try Again" action (no "Invite to Telegram") and an honest `phoneMenu_lookupFailed` message instead; and `TelegramPresentationData/BUILD` + `PresentationData.swift`'s `dictFromLocalization` now run every server-delivered language-pack string through the new `NovagramBrandStrings.applyBrand(to:)` (`submodules/Novagram/Brand/Sources/NovagramBrandStrings.swift`), rewriting "Telegram"/"TELEGRAM" to "Novagram"/"NOVAGRAM" everywhere except a `protectedPhrases` allowlist (Premium/Stars/Business/Passport/Desktop/Web/App/Terms/Team) — this is the fix for the 286 hand-rebranded strings in the bundled `en.lproj/Localizable.strings` never reaching a logged-in user, since `PresentationStrings` is actually built from the server's `langpack.getLangPack`, not the bundle.

---

## 🔀 Upstream 13.1.1 merge and the short history (2026-10-28)

**History.** Telegram force-pushed `TelegramMessenger/Telegram-iOS` master in October 2026: the commit merged on
2026-10-12 (`3e543cc192`) is gone from it, so a plain `git merge upstream/master` took a 2019 merge base. `main` was
rebuilt without Telegram's history (the old one is in `~/Documents/Novagram-backups/Telegram-iOS-before-reroot-2026-10-28.bundle`):

- `added telegram 13.0 source from upstream f1dd7a2dbd`: upstream's tree at `f1dd7a2dbd` (same tree as `3e543cc192`).
- `added novagram on top of telegram 13.0`: all our work up to `e3fe797097` in one commit.
- `updated telegram to fb0e62ba8a (2026-10-22)`: a snapshot of upstream 13.1.1, merged into main.

Every snapshot commit carries an `Upstream-Commit: <sha>` line; the update script finds the last one in main and
puts the next snapshot on top of it, so the merge base is always the previous snapshot.

**Merging.** `-X ignore-space-change`: a formatter had re-indented and rewritten (`let _ =` → `_ =`) many Telegram
files on our side. Without it 37 files conflicted, with it 25, and most remaining hunks were that noise
(upstream's side was taken there). Hooks ported to moved or deleted upstream code:

| File | What changed upstream | Hook now |
| --- | --- | --- |
| `ChatListHeaderComponent/Sources/NavigationButtonComponent.swift` | deleted (`16b065d8d0`, one glass `NavigationBarComponent`) | gone; its `.systemIcon` / `.iconTinted` / `.iconOriginal` cases, the 28 pt clamp and the haptic are replaced by `NovagramHeaderIcons` (`Novagram/ForeignUserBlock/Sources/ChatList_NovagramHeaderIcons.swift`, images made once) |
| `ChatListUI/Sources/ChatListController.swift` | header buttons are `NavigationBarComponent.Button` | `ghostModeButton` / the fold button are `NavigationBarComponent.Button(content: .image(NovagramHeaderIcons...))`, light haptic in their actions; the vault filter and `foldableButtons` stay in `rightButtons` |
| `TelegramUI/Sources/ChatControllerNode.swift` | the send loop moved into `chatComposerTextMessages` (TextFormat) | per piece: `NovagramOutgoingText.apply(text:entities:businessLinkSetup:)` (`Novagram/Messenger/Sources/NovagramOutgoingText.swift`) appends Auto Text, regenerates entities with upstream's rule and adds the Text Style entity |
| `TelegramCore/Sources/State/AccountStateManagementUtils.swift` | `.EditMessage` merge moved into `mergedServerMessageUpdate` (also used by feed pages) | `novagramAppendEditHistory` runs on the merged message's attributes in `.EditMessage` only |
| `TabBarUI/Sources/TabBarContollerNode.swift` | no search button in iPhone Duo's side placement | `search: sidePlacement != nil ? nil : { …always a search state… }()` |
| `TelegramUI/Sources/TelegramRootController.swift` | a removed selected tab selects Chats; a News tab (`showNewsTab`) | upstream's `selectedIndex`, then the bot layout selects Chats by identity; `currentShowNewsTab` is kept like `currentShowCallsTab` and a bot session hides News too (Chats + Settings only) |
| `CallScreen/Sources/Components/ButtonGroupView.swift` | `centeredX` band for iPhone Duo | our 5-button spacing formula + upstream's band |
| `ContactListUI/Sources/ContactsController.swift`, `ChatListUI/Sources/ChatListController.swift` (Secret Vault long press on the title) | the header's `titleContentView` is gone, the bar draws the title | the title hit test uses `headerView.navigationBarComponentView?.primaryTitleView` |
| `Novagram/BotTokenLogin`, `Novagram/CurrencyRates` (ours) | `NavigationBarTheme` lost its background, separator and `style` arguments (every bar is glass) | the same arguments as upstream's `AuthorizationSequenceController` / `NavigationBarTheme(rootControllerTheme:edgeEffectColor:)` |
| `AccountContext/Sources/AccountContext.swift`, `TelegramUI/Sources/NavigateToChatController.swift` | `showsUnreadChatsBackBadge` added | both parameters, upstream's first, then `isSecretRead` |

**Postbox visibility** (upstream's refactor lets only listed packages depend on Postbox):

- `submodules/Postbox/BUILD`, `clients` package group: `"//submodules/Novagram/...",` (one line, after `MediaPlayer`).
- `build-system/Make/PostboxImportCheck.py`: `'submodules/Novagram/'` in `EXEMPT_PREFIXES` (the check runs in `Make.py` only, not in `run.sh`).
- `SettingsUI/Sources/Notifications/NotificationsAndSoundsController.swift`: our `import Postbox` was unused, removed.
- `TelegramUI/Components/Chat/ChatTextInputPanelNode/BUILD`: our unused `//submodules/Postbox` dep removed.
- TelegramCore switched every file to `internal import TelegramApi`; our two TelegramCore files
  (`NovagramBotAuthorization.swift`, `Novagram/NovagramGhostReadOnSend.swift`) do the same, a plain import is an error now.

Also: `versions.json` takes upstream's 13.1.1 / Xcode 27.1; submodules `tgcalls` → `8d6dd4c61e`, `mtproto-engine` →
`da4b217021` from `TelegramMessenger/mtproto-engine` (run `git submodule sync` once).

The `NavigationButtonComponent` sections further down are history.

---

## 🪶 Thin hooks and the formatter (2026-10-28)

Each line we change in a Telegram file is a line an upstream update can conflict on. Three rules keep that number small:

1. **No formatter on Telegram files.** `~/.claude/scripts/auto-lint.sh` (swiftlint --fix after every Edit/Write) reads
   `.claude/auto-lint-only` at the repo root and lints only the files it lists: `submodules/Novagram/*.swift`,
   `submodules/TelegramCore/Sources/Novagram/*.swift` and `*/Novagram*.swift`. The file is local (`.claude/` is gitignored);
   recreate it on a new machine. Before 2026-10-28 swiftlint rewrote whole Telegram files (`let _ =` → `_ =`, unused
   closure parameters → `_`, `async()` → `async`, re-indent): 9 856 such lines in 83 files were put back to upstream's text
   (`ChatController.swift` went from +1291/-1165 to +154/-26 against upstream).
2. **Thin hooks** (see "Adding a new hook"): the logic lives in `submodules/Novagram/`, the Telegram file keeps an import
   and a 1–3 line call. Fat hooks are thinned one at a time, when we work on them anyway.
3. **Weekly upstream updates.** `~/Library/Application Support/Novagram/novagram-upstream-weekly.sh` runs every Monday at
   10:00 (launchd `uz.novagram.upstream-weekly`): trial merges of GitHub's `main` of both forks against Telegram's master in
   small mirrors (`~/Library/Caches/novagram-upstream/`), result as a macOS notification and in
   `~/Library/Logs/novagram-upstream-weekly.log`. It never touches a working copy. The update itself is
   `submodules/Novagram/scripts/novagram-upstream-update.sh`.

**Fat-hook backlog** (our lines in Telegram files against upstream 13.1.1, whitespace ignored, 2026-10-28; 157 Swift files,
~4 970 added lines). Thin the top ones first:

| Telegram file | Ours | What is in it |
| --- | --- | --- |
| `Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` | +473 | speech-to-text, round video from gallery, send-confirm, composer buttons |
| `TelegramUI/Sources/SharedAccountContext.swift` | +388 | account switching, hidden-chats factory, Novagram screens |
| `ChatListUI/Sources/ChatListController.swift` | +363 | ghost/fold buttons, Secret Vault, folder style, chat lock, ads |
| `Telegram/NotificationService/Sources/NotificationService.swift` | +323 | multi-account and Ghost notification handling |
| `AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` | +265 | demo login, bot token login, QR logo |
| `TelegramUI/Sources/ChatControllerNode.swift` | +179 | send-path features (heart effect, translate, sticker auto-add) |
| `TelegramUI/Sources/ChatController.swift` | +142 | chat lock, auto-accept, edited history, ghost |
| `TelegramUI/Sources/AppDelegate.swift` | +122 | managers started at launch |
| `PeerInfoScreen/Sources/PeerInfoScreenPerformButtonAction.swift` | +137 | profile actions |
| `AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift` | +128 | demo login |
| `TelegramCore/Sources/State/AccountStateManagementUtils.swift` | +108 | ghost mode, deleted messages, edited history |
| `ChatListUI/Sources/ChatContextMenus.swift` | +116 | chat menu items (hide, lock, recent actions) |

`InAppPurchaseManager.swift` (+70/-1113) is the App Store IAP gate: removing upstream's code there is the feature.

---

## 🔀 Upstream 13.0 merge (2026-10-12)

> Upstream `release-13.0.0` (`f1dd7a2dbd`) `feature/upstream-13.0` branch'ga merge qilindi: `git merge --no-ff -X ignore-space-change release-13.0.0` (alohida worktree `../Telegram-iOS-13`). To'liq reja va o'zgarishlar ro'yxati: repo root'dagi `UPSTREAM_13.0_MERGE_PLAN.md` va `UPSTREAM_13.0_CHANGES.md`. Hook nazorati: main'dagi 1707 ta Novagram/Novagram qatoridan faqat quyida yozilgan, ataylab olib tashlanganlari kamaydi.

**Olib tashlangan hook'lar** (upstream o'zi tuzatgan yoki almashtirgan): #172 SearchBarNode (bb5b4f5a3c), #188 TGMediaPickerPhotoStripView (37abd7a04a), #189 ChatInterfaceInputContexts (f09120e85f), #190 SSubscriber (7f6f87843c), #195 OpenInOptionsScreen (allaqachon upstream'da), #212 widget MinOS genrule (upstream ham min iOS 15.0), #220 `EmptyInputView` import pin (upstream o'zining `EmptyKeyboardInputView`'ini qo'shgan), #221 UIScene (`Novagram/SceneLifecycle` moduli o'chirildi, upstream `SceneDelegate` ishlatiladi, 13a2694420), #222 `UIViewController+Navigation.m` (upstream `internalGetKeyboardForScene`, 93af3a138e).

**Yangi joyga ko'chirilgan / qayta ulangan hook'lar:**
- `ChatListController.swift` (#78): qidiruvdagi long-press endi upstream'ning `dismissPreviewing` oqimida; `ChatPincodeManager.shared.isLocked(peer.id)` tarmog'i qulflangan chatda preview'ni yopadi. Upstream secret chat `.extracted` tarmog'ini olib tashlagan (secret chat'lar ham preview oladi).
- `ChatController.swift`: `ignorePreviewTap` guard'i upstream'ning wallet TonConnect route blokidan keyin turadi.
- `GlobalControlPanelsContext.swift` (#111): closure parametri `configuration` → `needsPasswordSetup` (upstream), oxirida bizning `bannerNotice` va erta return.
- `VideoMessageCameraScreen.swift` (#61): `pendingCameraPosition` endi `cameraImpl.isDualCameraSupported(forRoundVideo:)` bilan birga.
- `AuthorizationSequencePhoneEntryControllerNode.swift` (#114): `DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)` + bizning `playbackMode: .loop`.
- `SyncCore_StandaloneAccountTransaction.swift` (#21, #33): bizning 2 ta carry-forward (edit history, 🗑) upstream'ning `EphemeralReplacementMessageAttribute` carry-forward'idan oldin.
- `NotificationService.swift` (#137): `novagramIncomingCallIsVideo` upstream'ning `recipientAccountName` property'si yonida.
- `IntentContacts.swift` (#168): `"Novagram"` label tekshiruvi upstream'ning yangi `matchingDeviceContact(_:)` ichida (:83), auto-merge bo'lgan.
- `CallKitIntegration.swift` (#165): `CXProviderConfiguration(localizedName: "Novagram")` saqlandi (upstream `CXProviderConfiguration()` ga o'tgan; `-Wwarning DeprecatedDeclaration` bor).
- `InAppPurchaseManager.swift` (#176): butun fayl bizniki, StoreKit yo'q. `AppDelegate.swift` (#177): Manage Subscriptions faqat web URL, upstream'ning `AppStore.showManageSubscriptions` olinmadi.
- `Telegram/BUILD`: bizning ikkinchi `UIApplicationSceneManifest` o'chirildi (upstream manifest `SceneDelegate` bilan). `ton` / `tc` URL scheme'lar olib tashlandi (Wallet gate), `tonsite` qoldi.
- `en.lproj/Localizable.strings` (#161): upstream'ning yangi kalitlari Novagram bilan (`Settings.LogoutConfirmationTextWithWallets`, `Conversation.UnsupportedMedia.*`).
- `.bazelrc`: upstream (SourceKit BSP `index_build` bloki yo'q) + bizning disk-cache GC comment'i. 2026-10-13: GC endi yoqilgan (20GB, 14 kun), lekin faqat `run.sh` / `publish.sh` / `release.sh` da, `--disk_cache="$CACHE_DIR/disk"` yonida. Comment shuni aytadi; `.bazelrc` ga GC flag qo'yilmaydi. `sqlcipher/BUILD` (#214): upstream `load(...)` + bizning `sqlite3ext.h` exclusion.
- BUILD union: `SettingsUI/BUILD` (#202 + PasscodeCore, WalletContext), `ChatTextInputPanelNode/BUILD` (#206 + RichTextEditorCore), `StoryContainerScreen/BUILD` (#209 + UrlWhitelist).

**13.0 API uchun compile fix'lar (merge'dan keyingi commit):**
- `third-party/vosk/BUILD`: `load("@rules_cc//cc:objc_library.bzl", "objc_library")` — Bazel 9'da native `objc_library` yo'q.
- ChatLock `ChatPincodeViewController.swift`, BotTokenLogin `AuthorizationSequenceBotTokenEntryControllerNode.swift`, Analytics `NovagramAnalyticsController.swift`: `DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)` + `import LottieSettings` + BUILD'ga `//submodules/LottieSettings:LottieSettings`. `.noAccountFallback` = rlottie, ya'ni 13.0'gacha ishlatilgan renderer.
- NovagramMessenger `NovagramAccountItem.swift`: `previousItem` / `nextItem` o'rniga `neighbors: ListViewItemNeighbors` va `itemListNeighbors(item:topFacet:bottomFacet:)` (upstream 22271266f8).
- `InAppPurchaseManager.swift` (#176): `PurchaseState.waiting` / `.pending` va `buyProduct(..., reportPending: Bool = false)` — faqat API stub, hech qachon emit qilinmaydi, StoreKit yo'q.
- `NotificationService.swift` (#137): upstream `senderPerson`'ni olib tashlagan; qo'ng'iroq caller'i endi `sender`'dan yasaladi (`novagramCallerPerson` extension, `novagramRingingCallContent` yonida).
- **Yangi hook** `submodules/Camera/CameraLegacy/Sources/LegacyCamera.swift`: round video uchun old/orqa kamera fix'i (`setPosition`'da guard + `stopRunning`/`startRunning` + `invalidate(switchAudio: !isRoundVideo)` + `markPositionChange`, va round video `startRecording` oldidan `markPositionChange`). Avval eski `Camera.swift`'da edi (b56b9b0cb3); upstream kamera kodini `CameraLegacy` / `CameraNeo`'ga bo'lgan, round video uchun default — Neo. Neo yo'lini qurilmada tekshirish kerak.

**Bazel 9 build fix'lari (birinchi 13.0 build'da topilgan):**
- `run.sh`, `publish.sh`, `release.sh`: `--disk_cache="$CACHE_DIR"` → `--disk_cache="$CACHE_DIR/disk"`. Bazel 9 output base'ni (`bazel-user-root`) disk cache papkasi ichida qabul qilmaydi. `run.sh`'dagi favqulodda tozalash ham `disk/cas`'ni o'chiradi. Eski `~/telegram-bazel-cache/{cas,ac}` keraksiz.
- `submodules/Novagram/AutoProxy/BUILD`: `Resources/**/*` glob'iga `allow_empty = True` (modulda resurs yo'q; Bazel 9 bo'sh glob'ni xato deydi).
- `NotificationService.swift`: `novagramCallerPerson` extension'i `@available(iOS 15.2, *) novagramRingingCallContent` doc-comment'idan yuqorida turadi (atribut funksiyadan ajralib qolmasin).
- `run.sh -r`: development profillar nusxalangandan keyin `provisioning/BUILD` (`exports_files`) qayta yoziladi. Avval ro'yxat profillar nusxalanishidan oldin yozilardi va yangi checkout'da (worktree) bo'sh qolib, device build "no such target ...mobileprovision" bilan yiqilardi.
- Natija: `./run.sh` Bazel 9.2.0 + Xcode 27.1 bilan to'liq build bo'ldi; 12.9.9 → 13.0 upgrade (DB, sozlamalar, passcode migration) simulator'da tekshirildi.

**Wallet gate (merge'dan keyingi commit):**
- **Yangi hook** `submodules/WalletContext/Sources/WalletContext.swift`: fayl darajasida `private let novagramWalletEnabled = false` va `WalletConfiguration.with(appConfiguration:)` ichida `isAvailable = novagramWalletEnabled && (...wallet_available...)`. Shu bitta joyni 26 ta kirish nuqtasi (Settings "Money" qatori, profil "Send Money", attach menu, `t.me/sendgrams`, TON Connect) va fon wallet engine'i (streaming, backup) tekshiradi, shuning uchun server wallet'ni yoqsa ham Novagram'da u o'chiq turadi.
- **Wallet'ni yoqishdan oldin majburiy:** (1) `WalletReceiveScreen`'dagi onramp "Buy" tugmasini yashirish (exchange litsenziyasi yo'q, Apple 3.1.5(iii)); (2) `NovagramBrandStrings.protectedPhrases`'ga wallet iboralarini qo'shish ("paid by Telegram", "Telegram covers", "not even Telegram", "Telegram's datacenters", "Telegram couldn't", "Digital currency for Telegram", "Telegram Support"), aks holda "paid by Novagram" kabi noto'g'ri da'vo chiqadi; (3) App Privacy'ni yangilash (financial info, toncenter). Wallet o'chiq paytda bular ko'rinmaydi, shuning uchun hozir qilinmadi.
- `en.lproj/Localizable.strings`: `PasscodeSettings.LockTelegram` = "Lock Novagram" (13.0'da qo'shilgan, hamma userga ko'rinadi).

---

## 📋 Novagram features va hooklar (2026-10-10)

> 1–44, 86 va 89: Settings → Novagram Settings (ilovadagi tartibda). 45–85, 87 va 88: Settings'dan tashqaridagi features.
> Hooks: Telegram-owned fayllardagi barcha Novagram o'zgarishlari, feature bo'yicha. Har bir hookning kodi va anchor'i quyidagi 📌 bo'limlarda.

### 1. Novagram Settings

> Settings → Novagram Settings. Tartib ilovadagi bilan bir xil.

#### Novagram haqida

1. **Novagram haqida**: har bir imkoniyat qanday yoqiladi, qanday ishlaydi va qanday o'chiriladi.

#### Accountlar

2. **Barcha accountlar**: barcha accountlar ro'yxati (joriy, faol, uyquda). Shu yerdan "Faollashtirish (Uyqusiz)" yoki "Uyquga qo'yish".

#### Interfeys

3. **Jildlarni yashirish**: chatlar ro'yxati tepasidagi papka tablarini vaqtincha yashiradi.
4. **Hikoyalar paneli**: chatlar ro'yxati tepasidagi stories panelini ko'rsatadi yoki yashiradi.
5. **Mutual kontakt belgisi**: sizni ham kontaktiga saqlaganlar yonida 🤝 belgisi chiqadi.
6. **Cheksiz pin**: 1000 tagacha chatni pin qilish mumkin. Limitdan ortiq pinlar faqat shu iPhone'da saqlanadi.

#### Chat

7. **O'chirilgan xabarlar**: boshqalar o'chirgan xabarlar chatda qoladi, 🗑 belgisi va o'chirilgan vaqti bilan.
8. **Tahrirlangan xabar tarixi**: xabarning barcha oldingi versiyalari (matn va media) saqlanadi. Ko'rish: xabarni long-press → "Tahrir tarixi".
9. **Birinchi xabarga o'tish**: profil menyusiga "View First Message" qo'shiladi va chatning eng birinchi xabariga o'tadi.
10. **Ghost rejimi tugmasi**: chatlar ro'yxati tepasiga Ghost tugmasi qo'shiladi. Ghost yoqilganda "ko'rildi", "yozyapti" va "onlayn" signallari yuborilmaydi.
11. **Kamerani tanlash**: video-xabar tugmasini long-press qilib old yoki orqa kamerani tanlash.
12. **Galereyadan dumaloq video**: galereyadagi videoni dumaloq video-xabar qilib yuborish (1 daqiqagacha).
13. **Imzosiz forward**: xabar menyusiga "Imzosiz forward qilish" qo'shiladi. Xabar yuboruvchi nomisiz forward qilinadi.

#### Xabarlar

14. **Yozuv uslubi**: har bir chiquvchi xabarga bitta format qo'llanadi (Bold, Italic, Monospace, Strikethrough, Underline yoki Spoiler).
15. **Avto-matn qo'shimchasi**: har bir xabar oxiriga o'zingiz yozgan matn (imzo, hashtag) avtomatik qo'shiladi.
16. **Avto-tarjima**: chiquvchi xabarlar yuborishdan oldin tanlangan tilga tarjima qilinadi.
17. **Tarjima tugmasi**: har bir matnli xabar menyusida "Translate" chiqadi.
18. **Tarjima tili**: "Translate" uchun maqsad tilni tanlash va til paketlarini yuklab olish.
19. **Yuborishda tarjima so'rovi**: Send bosilganda tarjimani yoki aslini yuborish so'raladi.
20. **Avtomatik sticker**: har bir matnli xabardan keyin oxirgi yuborilgan sticker ham yuboriladi.
21. **Yurakcha effekti**: yuborilgan xabarlarga ❤️ animatsion effekt avtomatik qo'shiladi.

#### Ovoz → Matn

22. **Ovozni matnga o'girish**: mikrofon yonida STT tugmasi chiqadi. Aytilgan gap matnga aylanib input'ga yoziladi.
23. **Tanish tili**: STT tilini tanlash. O'zbek tili offline Vosk modeli orqali taniladi.
24. **Ovozli xabarlarni tarjima qilish**: ovozdan olingan matn avtomatik tarjima qilinadi.

#### CarPlay

86. **CarPlay**: mashinada Siri Novagram xabarlarini o'qib beradi va javobingizni ovoz bilan yuboradi. Qator Siri ruxsatining holatini ko'rsatadi: ruxsat bo'lsa yashil, rad etilgan bo'lsa ogohlantirish va iOS Settings'ga o'tish tugmasi; ilovaga qaytganda holat o'zi yangilanadi.

#### Himoya

25. **Xorijiy raqamlarni bloklash**: boshqa davlat raqamlaridan kelgan chat, xabar va bildirishnomalarni yashiradi.
26. **Chat qulfi**: avval asosiy pinkod o'rnatiladi. Keyin chatni long-press → "Qulf o'rnatish" (PIN yoki parol, Face ID/Touch ID ham ishlaydi).
27. **Avto-yuklashni o'chirish**: mobil tarmoq va Wi-Fi'da barcha media avto-yuklashni o'chiradi.
28. **Yuborishdan oldin so'rash**: ovozli xabar, sticker yoki sovg'a yuborishdan oldin tasdiq so'raladi.
29. **NovagramProxy'ni yoqish**: Telegram bloklangan hududda avtomatik SOCKS5 proxy orqali ulanadi.

#### Ko'rinish

30. **Yorqin temada brand rangi**: yorqin (oq) temada Novagram ko'k rangi accent bo'ladi.

#### Chat qulfi

31. **Yashirin chatlar**: tanlangan chatlar alohida kod-parol ortiga yashiriladi va ovozsiz qilinadi. Ochish uchun "Chats" sarlavhasi long-press qilinadi.
32. **Face ID bilan ochish**: yashirin chatlarni Face ID yoki Touch ID bilan ochish.

#### Xabar eslatmasi

33. **O'qilmagan xabar eslatmasi**: xabar belgilangan vaqtda o'qilmasa lokal eslatma keladi.
34. **Eslatma vaqti**: 1 dan 60 daqiqagacha.
35. **Eslatma ovozi**: 12 ta ohangdan biri, standart ovoz yoki "Yo'q".

#### Imkoniyatlar

36. **Tavsiya etilgan papkalar**: bir bosishda Shaxsiy, O'qilmagan, Kanallar va Botlar papkalari yaratiladi.
89. **Kirgandan keyin papka taklifi**: akkauntga kirgandan keyingi «Papkalar qo'shilsinmi?» oynasi endi standart holda o'chiq, shu switch bilan yoqiladi (faqat Novagram fayllari, hook yo'q).
37. **Admin papkalar**: siz ega (👑) yoki admin (🔑) bo'lgan guruh va kanallar 4 ta avto-papkaga ajratiladi.
38. **Papka ko'rinishi**: papka tablari uchun Ikonkalar, Matn yoki Avtomatik ko'rinish.
39. **Kanal tarixi tugmasi**: siz admin bo'lgan kanal menyusiga "So'nggi amallar" qo'shiladi.
40. **Avto-qabul qilish**: guruh va kanalga qo'shilish so'rovlari avtomatik qabul qilinadi.
41. **Novagram Settings havolasini ulashish**: `tg://settings/novagrampro` havolasini nusxalash yoki ulashish. Istalgan qatorni long-press qilsangiz, aynan o'sha qatorga olib boradigan havola chiqadi.
42. **Hikoyalarni saqlash va sifat**: boshqalarning hikoyalarini saqlash va video hikoyalarni HD ko'rish (Premium'siz).
43. **Butun chatni tarjima qilish**: butun chatni bir yo'la tarjima qilish (Premium'siz).

#### Reklama

> Yashirin bo'lim. Ochish uchun sahifani 10 marta tez bosing.

44. **Reklamani ko'rsatish**: kanal, bot, qidiruv va banner reklamalarini yoqadi yoki o'chiradi.

---

### 2. Settings'dan tashqaridagi features

#### CarPlay

87. **CarPlay ekrani**: CarPlay'da Novagram so'nggi chatlar ro'yxatini ko'rsatadi. Chat bosilganda Siri o'qilmagan xabarlarni o'qiydi yoki javobni ovoz bilan yuboradi; yuqoridagi tugma Siri orqali yangi xabar boshlaydi. Kanallar (javob yozib bo'lmaydi), yashirin, qulflangan, maxfiy chatlar va Saved Messages chiqmaydi; passcode qulfida ro'yxat bo'sh. Tanlangan chat mute bo'lsa ham Siri uni o'qiydi. Mute qilinmagan chatlar tepada, mute qilinganlar pastdagi "Ovozsiz" bo'limida.

#### Login

45. **QR kod orqali kirish**: telefon raqam ekranida QR kod bilan kirish tugmasi.
46. **Bot token bilan kirish**: telefon raqami o'rniga bot token bilan kirish. Bot sessiyasida faqat Chats va Settings tablari bor.
47. **Login ekranidagi NovagramProxy**: bloklangan hududda login'dan oldin proxy'ni yoqadigan tugma.
48. **2FA "Orqaga" tugmasi**: 2FA parol ekranidan orqaga qaytish mumkin, user ekranda qamalib qolmaydi.

#### Chat va xabarlar

49. **Tahrirlab yuborish**: forward qilinayotgan post tahrirlanadi va "Forwarded from" hamda "edited" belgisisiz yangi xabar bo'lib ketadi.
50. **Maxfiy ko'rish**: chatlar ro'yxatida long-press. Chat "o'qildi" signali yubormasdan ochiladi.
51. **Chat ID'ni nusxalash**: chatlar ro'yxatida long-press qilib chat ID'sini nusxalash.
52. **Profildagi ID qatori**: user, guruh va kanal profilida ID ko'rinadi (guruh va kanalda `-100…` formatida). Bosilsa nusxalanadi.
53. **Novagram Info**: profil "…" menyusida ID, turi, username va Premium/Scam/Fake belgilari chiqadi.
54. **Telefon raqamda "Qayta urinish"**: tarmoq xatosi "Telegram'da yo'q" deb ko'rsatilmaydi, o'rniga "Qayta urinish" chiqadi.

#### Chat ro'yxati va papkalar

55. **Papka ikonkasini tanlash**: papka tahrirlash ekranida emoji ikonka tanlanadi (Premium'siz).
56. **Cheksiz papka va teglar**: papka limiti oshirilgan, "Show Folder Tags" Premium'siz ishlaydi.
57. **Header tugmalarini yig'ish**: Stories, Ghost va Proxy tugmalari 2 tadan ko'p bo'lsa bitta chevron ortiga yig'iladi.

#### Multi-account

58. **999 tagacha account**: account limiti 999, Premium shart emas.
59. **Uyquchi accountlar**: joriy va 5 tagacha faol account doim ulangan turadi. Qolganlari uxlaydi, lekin push keladi va 1–2 soniyada uyg'onadi.
60. **Tab bar'dan account almashtirish**: Settings tabini long-press qilganda barcha accountlar avatar va username bilan chiqadi.
61. **Bildirishnomalarni tozalash**: o'qilgan xabar bildirishnomasi barcha faol accountlarda o'chadi.

#### Qo'ng'iroq va bildirishnomalar

62. **Kiruvchi qo'ng'iroq fallback**: ilova yopiq bo'lsa ham qo'ng'iroq ringtone va vibratsiya bilan jiringlaydi.
63. **Uxlayotgan accountga qo'ng'iroq**: uxlayotgan accountga qo'ng'iroq kelsa account uyg'otiladi.
64. **Bildirishnomada yuboruvchi rasmi**: push'da yuboruvchining avatari ko'rinadi (Communication Notifications).
88. **Video qo'ng'iroqda speaker**: kamera yoqilganda ham speaker tugmasi flip tugmasi yonida qoladi (5 ta tugma). Headset bo'lmasa video ovozi gromkada; quloq dinamikda qolib ketsa ~1 s ichida gromkaga qaytadi. Foydalanuvchi o'zi tanlagan quloq dinamik saqlanadi.

#### Ilova va Settings

65. **Novagram Settings qatori**: Settings'dagi oltin rangli qator. Barcha Novagram sozlamalari shu yerda.
66. **Novagram Bots**: kategoriyalarga bo'lingan foydali botlar katalogi.
67. **Analytics**: Novagram foydalanuvchilari (qurilmalar) va faol accountlar soni.
68. **Settings havolalari**: `tg://settings/novagrampro/<feature>` havolasi kerakli qatorni ochib, uni belgilab ko'rsatadi.
69. **Ilova ikonkalari**: 7 ta Nova ikonka (Ko'k, Feruza, Binafsha, Pushti, To'q sariq, Qora, Qizil).
70. **Imkoniyatlar ekrani (Tips)**: birinchi ishga tushishda asosiy imkoniyatlar bir marta ko'rsatiladi.
71. **Yangilanish tekshiruvi**: App Store'da yangi versiya bo'lsa "Yangilanish mavjud" alerti chiqadi.
72. **Haptic**: header tugmalari, story kamera va STT tugmasi bosilganda yengil vibratsiya beradi.

#### Brand va til

73. **Novagram brendi**: ilova nomi, ikonka, ko'k rang (`#0A9BF5`) va intro ekrani Novagram'niki.
74. **Server matnlarida Novagram**: server'dan keladigan tarjimalardagi "Telegram" so'zi "Novagram"ga almashtiriladi.
75. **Tizimdagi Novagram nomi**: CallKit, Share, Widget, Siri, Photos albomi, kontakt label'i va ruxsat so'rovlarida ham "Novagram" yoziladi.
76. **Xitoy tili**: Settings → Language'da Simplified va Traditional Chinese bor. Novagram ekranlari ham xitoychaga tarjima qilingan.
77. **4 tilli Novagram matnlari**: barcha Novagram matnlari en, uz, ru va zh tillarida. Boshqa tillarda English chiqadi.

#### Reklama va statistika

78. **Kanal reklamasi**: kanallardagi sponsored joyda Novagram reklamasi ko'rsatiladi.
79. **Banner reklama**: chatlar ro'yxati tepasida Novagram banneri chiqadi. Yopilgan banner qayta chiqmaydi.
80. **Qidiruv reklamasi**: global qidiruvda so'rovga mos promoted kanal yoki bot "mening natijalarim"dan keyin turadi.
90. **Bot reklamasi**: bot chatining tepasidagi panelda Novagram reklamasi ("X" faqat shu reklamani yashiradi).
81. **Anonim statistika**: anonim device ID bilan o'rnatishlar va faol accountlar soni yuboriladi (ATT shart emas).

#### Apple talablari

82. **IAP blok (3.1.1)**: ilova ichida Premium yoki Stars sotib olib bo'lmaydi (StoreKit olib tashlangan). Alert @PremiumBot'ga yo'naltiradi.
83. **To'lov bo'limi faqat ko'rish uchun**: Premium, Stars, TON, Business va Gift ekranlari ko'rinadi, lekin xarid tugmalari bloklangan.
84. **Kontaktlar roziligi (5.1.2)**: iOS Contacts ruxsatidan oldin kontaktlar serverga yuklanishiga rozilik so'raladi.
85. **Demo login**: Apple Review demo raqami kiritilsa SMS kod avtomatik to'ldiriladi.

---

### 3. Hooks

> Telegram-owned fayllardagi Novagram o'zgarishlari, feature bo'yicha. Qavs ichida modul nomi.

#### Accountlar

1. `AccountUtils.swift` (AccountUtils): account limiti 999.
2. `DeleteAccountOptionsController.swift`, `LogoutOptionsController.swift` (SettingsUI): hardcoded 3/4 o'rniga umumiy limit ishlatiladi.
3. `AccountContext.swift` (AccountContext): pinned accountlar uchun 4 ta protokol a'zosi.
4. `SharedAccountContext.swift` (TelegramUI): 5 tagacha live account (LRU), pinned accountlar, ism/username/avatar keshi. Xotira kam bo'lsa kesh tozalanadi.
5. `SharedWakeupManager.swift` (TelegramUI): pinned accountlar doim ulangan turadi.
6. `PeerInfoSettingsItems.swift` (PeerInfoScreen): Settings'da "Barcha accountlar" qatori.
7. `PeerInfoScreen.swift` (PeerInfoScreen): Settings tabini long-press qilganda barcha accountlar chiqadi.
8. `PeerInfoScreenSettingsActions.swift` (PeerInfoScreen): "Barcha accountlar" ekranini ochadi, Add Account limiti.
9. `NovagramAccountSwitchContextItem.swift` (PeerInfoScreen, yangi fayl): account qatori (avatar, ism, @username).

#### Interfeys

10. `ChatListController.swift` (ChatListUI): **Jildlarni yashirish**: faqat "All Chats" tabi qoladi.
11. `ChatListControllerNode.swift` (ChatListUI): **Hikoyalar paneli**: stories paneli yashiriladi.
12. `ContactsPeerItem.swift` (ContactsPeerItem): **Mutual kontakt belgisi**: kontakt nomi yonida 🤝 chiqadi.
13. `TogglePeerChatPinned.swift` (TelegramCore): **Cheksiz pin**: pin limiti 1000.
14. `NovagramLocalPins.swift` (TelegramCore, yangi fayl): **Cheksiz pin**: server limitidan ortiq pinlar qurilmada saqlanadi.
15. `Holes.swift`, `ResetState.swift`, `ManagedSynchronizePinnedChatsOperations.swift` (TelegramCore): **Cheksiz pin**: server bilan sync'da lokal pinlar qaytadan qo'shiladi.
16. `TelegramEnginePeers.swift` (TelegramCore): **Cheksiz pin**: o'chirilganda ortiqcha pinlar olib tashlanadi.

#### O'chirilgan xabarlar

17. `DeletedMessageAttribute.swift` (TelegramCore, yangi fayl): o'chirilgan xabar belgisi va o'chirilgan vaqti.
18. `NovagramShowDeletedMessages.swift` (TelegramCore, yangi fayl): toggle App Group orqali NotificationService'ga ham ko'rinadi.
19. `AccountManager.swift` (TelegramCore): `DeletedMessageAttribute` registratsiyasi.
20. `AccountStateManagementUtils.swift` (TelegramCore): o'chirish kelganda xabar o'chirilmaydi, unga belgi qo'yiladi.
21. `SyncCore_StandaloneAccountTransaction.swift` (TelegramCore): re-sync'da 🗑 belgisi saqlanadi.
22. `HistoryViewStateValidation.swift` (TelegramCore): tarix tekshiruvida saqlangan xabar o'chirilmaydi.
23. `NotificationService.swift` (NotificationService): ilova fonda bo'lsa ham o'chirilgan xabar saqlanadi.
24. `AppDelegate.swift` (TelegramUI): har launch'da toggle App Group'ga ko'chiriladi.
25. `ChatHistoryEntriesForView.swift` (TelegramUI): toggle o'chiq bo'lsa o'chirilgan xabarlar ko'rsatilmaydi.
26. `ChatHistoryListNode.swift` (TelegramUI): toggle o'zgarsa ochiq chat darhol yangilanadi.
27. `StringForMessageTimestampStatus.swift` (TelegramUI): xabar ostida "🗑 O'chirilgan · vaqt" yoziladi.

#### Tahrirlangan xabar tarixi

28. `SyncCore_EditedMessageHistoryAttribute.swift` (TelegramCore, yangi fayl): xabarning eski versiyalari (matn va media).
29. `NovagramEditHistoryCapture.swift` (TelegramCore, yangi fayl): tarixni yozadigan umumiy helper.
30. `AccountManager.swift` (TelegramCore): `EditedMessageHistoryAttribute` registratsiyasi.
31. `AccountStateManagementUtils.swift` (TelegramCore): tahrir kelganda tarix yoziladi.
32. `RequestEditMessage.swift` (TelegramCore): o'zingizning birinchi tahriringiz ham saqlanadi.
33. `SyncCore_StandaloneAccountTransaction.swift` (TelegramCore): guruh va kanal re-sync'da tarix yo'qolmaydi.
34. `ChatInterfaceStateContextMenus.swift` (TelegramUI): xabar menyusida "Tahrir tarixi" (toggle bilan).

#### Birinchi xabarga o'tish

35. `ChatController.swift` (AccountContext): `navigateToFirstMessage()` protokol a'zosi.
36. `ChatController.swift` (TelegramUI): `navigateToFirstMessage()` va chatdagi avatar menyularida "View First Message".
37. `PeerInfoScreenPerformButtonAction.swift` (PeerInfoScreen): user, guruh va kanal profilining "…" menyusida "View First Message".

#### Ghost rejimi

38. `NovagramGhostMode.swift` (TelegramCore, yangi fayl): `isNovagramGhostModeActive`, Ghost uchun umumiy tekshiruv.
39. `NovagramGhostReadOnSend.swift` (TelegramCore, yangi fayl): javob yuborilganda chat o'qilgan bo'ladi.
40. `EnqueueMessage.swift` (TelegramCore): xabar yuborilganda chat o'qilgan qilinadi.
41. `ApplyMaxReadIndexInteractively.swift` (TelegramCore): forum, topic va saved chatlar uchun o'qildi/o'qilmadi belgisi yuborilmaydi.
42. `SynchronizePeerReadState.swift` (TelegramCore): read receipt yuborilmaydi.
43. `AccountContext.swift` (TelegramUI): `applyMaxReadIndex` ishlamaydi.
44. `MarkAllChatsAsRead.swift` (TelegramCore): "Hammasini o'qilgan qilish" serverga yuborilmaydi.
45. `ManagedAccountPresence.swift` (TelegramCore): "onlayn" holati yuborilmaydi.
46. `ManagedLocalInputActivities.swift` (TelegramCore): "yozyapti" yuborilmaydi.
47. `ManagedSynchronizeViewStoriesOperations.swift` (TelegramCore): story ko'rilgani yuborilmaydi.
48. `Stories.swift` (TelegramCore): story ko'rishlar soni oshmaydi.
49. `AccountViewTracker.swift` (TelegramCore): kanal post ko'rishlar soni oshmaydi, reaksiyalar "ko'rildi" bo'lmaydi.
50. `ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift` (TelegramCore): reaksiya va mention o'qilgani yuborilmaydi.
51. `ManagedConsumePersonalMessagesActions.swift` (TelegramCore): reaksiya va poll uchun `readMessageContents` yuborilmaydi.
52. `ManagedSynchronizeConsumeMessageContentsOperations.swift` (TelegramCore): ovozli va video xabar "eshitildi" deb yuborilmaydi.
53. `MarkMessageContentAsConsumedInteractively.swift` (TelegramCore): media "ochildi" deb yuborilmaydi.
54. `PeerMessagesMediaPlaylist.swift` (TelegramUI): ovozli xabar tinglansa ham "eshitildi" bo'lmaydi.
55. `SecretMediaPreviewController.swift` (GalleryUI): yo'qoladigan media ochilgani yuborilmaydi.
56. `StandaloneSendMessage.swift`, `PendingMessageManager.swift` (TelegramCore): screenshot bildirishnomasi yuborilmaydi.
57. `AdMessages.swift` (TelegramCore): reklama "ko'rildi" va click yuborilmaydi.
58. `ChatListController.swift` (ChatListUI): chatlar tepasida Ghost tugmasi (yoqiq/o'chiq ikonka).
59. ~~`NavigationButtonComponent.swift` (TelegramUI)~~: upstream faylni o'chirdi (2026-10-28), ghost ikonkalari endi `NovagramHeaderIcons` da.
60. `NovagramGhostActive/Inactive/Icon.imageset` (TelegramUI, yangi asset): Ghost ikonkalari.

#### Chat

61. `ChatTextInputPanelNode.swift` (TelegramUI): **Kamerani tanlash**: long-press'da old/orqa kamera menyusi chiqadi (lokalizatsiya qilingan, klaviatura bilan to'qnashuv tuzatilgan, default OFF).
62. `ChatTextInputPanelNode.swift` (TelegramUI): **Galereyadan dumaloq video**: kamera menyusida "Galereya" bandi.
63. `ChatInterfaceStateContextMenus.swift` (TelegramUI): **Imzosiz forward**: xabar menyusida "Imzosiz forward qilish".
64. `ChatControllerForwardMessages.swift` (TelegramUI): **Imzosiz forward**: bir martalik "nomsiz" bayrog'i o'qiladi va tozalanadi.

#### Xabarlar

65. `ChatControllerNode.swift` (TelegramUI): **Yozuv uslubi** va **Avto-matn**: yuborishda xabarga format va matn qo'shiladi.
66. `ChatController.swift` (TelegramUI): **Yozuv uslubi**: ikkinchi yuborish yo'lida ham format qo'llanadi.
67. `ChatControllerNode.swift` (TelegramUI): **Avto-tarjima** (#31) va **Yuborishda tarjima so'rovi** (#37). Rich xabarda ishlamaydi.
68. `ChatInterfaceStateContextMenus.swift` (TelegramUI): **Tarjima tugmasi**: "Translate" doim chiqadi.
69. `ChatController.swift` (TelegramUI): **Tarjima tili**: maqsad til Novagram sozlamasidan olinadi.
70. `ChatController.swift` (TelegramUI): **Avtomatik sticker** (#30): oxirgi yuborilgan sticker saqlanadi.
71. `ChatControllerNode.swift` (TelegramUI): **Avtomatik sticker** (#30) matndan keyin yuboriladi. **Yurakcha effekti** (#34) qo'shiladi.

#### Ovoz → Matn

72. `ChatTextInputPanelNode.swift` (TelegramUI): STT tugmasi (chapda) va haptic. Long-press'da til va ovozli tarjima sozlamalari ochiladi. Default OFF.

#### Himoya

73. `ChatListNodeEntries.swift` (ChatListUI): **Xorijiy raqamlar**: chatlar ro'yxatida ko'rinmaydi.
74. `ChatHistoryEntriesForView.swift` (TelegramUI): **Xorijiy raqamlar**: ularning xabarlari yashiriladi.
75. `NotificationService.swift` (NotificationService): **Xorijiy raqamlar**: ulardan bildirishnoma chiqmaydi.
76. `AccountContext.swift` (TelegramUI): **Xorijiy raqamlar**: davlat kodini solishtirish uchun o'z raqamingiz saqlanadi.
77. `ChatContextMenus.swift` (ChatListUI): **Chat qulfi**: "Qulf o'rnatish/olib tashlash" bandi (faqat asosiy pinkod bo'lsa).
78. `ChatListController.swift` (ChatListUI): **Chat qulfi**: qulflangan chatning preview'i ko'rsatilmaydi.
79. `NavigateToChatController.swift` (TelegramUI): **Chat qulfi**: chatga kirishda PIN/Face ID so'raladi. "Pinkodni unutdingizmi?" asosiy pinkod orqali ishlaydi.
80. `ChatControllerMediaRecording.swift` (TelegramUI): **Yuborishdan oldin so'rash** (#38): ovozli xabar tasdig'i.
81. `ChatController.swift` (TelegramUI): **Yuborishdan oldin so'rash** (#38): sticker tasdig'i.
82. `ChatInterfaceStateContextMenus.swift` (TelegramUI): **Yuborishdan oldin so'rash** (#38): sovg'a tasdig'i.
83. `AppDelegate.swift` (TelegramUI): **NovagramProxy**: launch'da proxy tekshiriladi va tiklanadi.
84. `AuthorizationSequencePhoneEntryController.swift` (AuthorizationUI): **NovagramProxy**: login ekranida proxy tugmasi.

#### Yashirin chatlar

85. `ChatListController.swift` (ChatListUI): ochish (sarlavhani long-press yoki 10 tap), Hide/Unhide, story bar filtri. Papka tablari va compose tugmasi yashiriladi, Face ID default yoqiladi.
86. `ChatListContainerItemNode.swift`, `ChatListNode.swift` (ChatListUI): yashirin chatlar ro'yxati rejimi.
87. `ChatListNodeEntries.swift` (ChatListUI): yashirin chatlar asosiy ro'yxatdan olib tashlanadi. Yashirin ro'yxatda Archive yo'q.
88. `ChatListEmptyNode.swift` (ChatListUI): bo'sh holatda o'rdak sticker.
89. `ChatContextMenus.swift` (ChatListUI): "Unhide" bandi. Mute default holatga qaytadi.
90. `ContactsController.swift`, `ContactsControllerNode.swift`, `ContactListNode.swift`, `ContactContextMenus.swift` (ContactListUI): kontaktlarda yashirish va ko'rsatish. "Contacts" sarlavhasidan ham ochiladi.
91. `CallListNodeEntries.swift`, `CallListControllerNode.swift` (CallListUI): yashirin chatlarning qo'ng'iroqlari ko'rinmaydi.
92. `Toolbar.swift`, `ToolbarNode.swift` (Display), `TabBarContollerNode.swift` (TabBarUI): toolbar'da qo'shimcha "Yashirish" tugmasi.
93. `AccountContext.swift` (AccountContext), `SharedAccountContext.swift` (TelegramUI): yashirin ro'yxat ekrani factory'si.

#### Xabar eslatmasi

94. `ApplicationContext.swift` (TelegramUI): eslatma menejeri ishga tushadi.

#### Imkoniyatlar

95. `ApplicationContext.swift` (TelegramUI): **Tavsiya etilgan papkalar**: birinchi launch'da taklif qilinadi.
96. `AppDelegate.swift` (TelegramUI): **Admin papkalar** (#47): global monitor.
97. `ChatListController.swift` (ChatListUI): **Papka ko'rinishi** (#21): tab nomi tanlangan uslubda chiqadi.
98. `ChatContextMenus.swift` (ChatListUI): **Kanal tarixi tugmasi** (#32): kanal menyusida "So'nggi amallar".
99. `ChatController.swift` (TelegramUI): **Avto-qabul qilish** (#45): chat ochilganda so'rovlar qabul qilinadi.
100. `AppDelegate.swift` (TelegramUI): **Avto-qabul qilish** (#45): launch'da va har 60 soniyada tekshiriladi.
101. `OpenResolvedUrl.swift`, `OpenUrl.swift` (TelegramUI): **Settings havolalari** (#40): `tg://settings/novagrampro[/<feature>]`.
102. `StoryItemSetContainerComponent.swift` (StoryContainerScreen): **Hikoyalarni saqlash**: story yuklab olish va HD Premium'siz.
103. `StoryChatContent.swift` (StoryContainerScreen), `ChatListController.swift` (ChatListUI), `ChatHistoryListNode.swift` (TelegramUI): **Hikoyalar sifati**: HD sozlamasi Premium'siz ishlaydi.
104. `ChatTranslationPanelNode.swift` (TranslateHeaderPanelComponent): **Butun chatni tarjima**: tarjima paneli Premium'siz.
105. `ChatControllerContentData.swift`, `ChatHistoryListNode.swift` (TelegramUI): **Butun chatni tarjima**: tarjima xabarlarga qo'llanadi.
106. `LocalizationListControllerNode.swift` (SettingsUI): **Butun chatni tarjima**: Settings → Language'dagi switch ochiq.

#### Reklama

107. `ChatHistoryListNode.swift` (TelegramUI): kanal reklamasi (v2) bizning backend'dan keladi — ommaviy, 1000+ obunachili kanalda, oxirgi postdan keyin; "ko'rildi" (`view`) shu yerda. "Reklamani ko'rsatish" toggle shu yerda tekshiriladi.
108. `ChatController.swift` (TelegramUI): reklama bosilganda `click` (kanal, bot paneli va reklama ichidagi havola) — avval navbatga yoziladi, keyin havola ochiladi, Telegram serveriga yuborilmaydi; bot panelidagi menyu — bizning "Reklama haqida / Shikoyat".
109. `ChatInterfaceStateContextMenus.swift` (TelegramUI): o'z reklamamizda faqat "Reklama haqida" va "Shikoyat qilish" (Premium "Hide" / "Remove" yo'q).
110. `ChatListSearchListPaneNode.swift` (ChatListUI): qidiruvda "mening natijalarim"dan keyin, global natijalardan oldin promoted kanal/bot.
111. `GlobalControlPanelsContext.swift` (TelegramUI): chatlar ro'yxati tepasida banner (Telegram'ning xavfsizlik ogohlantirishlaridan keyin, account muzlatilganda ko'rsatilmaydi) va uni yopish.
112. `ChatListControllerNode.swift` (ChatListUI): banner bosilganda click hisoboti va havola (bosiladigan bo'lsa).
232. `ChatControllerContentData.swift` (TelegramUI): bot chatining tepasidagi panelga bizning BOT reklamamiz.
233. `ChatControllerNode.swift` (TelegramUI): bot paneli ko'ringanda `view`; panel "X" i reklamani faqat lokal yashiradi.
234. `ChatMessageBubbleItemNode.swift` (ChatMessageBubbleItemNode): bizning kanal reklamamizda yopish "X" yo'q.
235. `ChatListNoticeItem.swift` (ChatListHeaderNoticeComponent): yopib bo'lmaydigan bannerda "X" yo'q.
236. `run.sh`, `publish.sh`, `release.sh`: `--define=novagramAdsEnvironment` (`NOVAGRAM_ADS_ENVIRONMENT` `local-secrets.sh` dan, faqat o'rnatilgan bo'lsa uzatiladi).
238. `UniversalVideoGalleryItem.swift`, `VideoAdComponent.swift` (GalleryUI): to'liq ekran pleerda bizning video banner (playback vaqti bo'yicha); Telegram'niki faqat fallback, Premium'ga hech qachon.
239. `ChatHistoryEntriesForView.swift` (TelegramUI): oxirgi post album bo'lsa ham bizning reklama undan keyin chiqadi.
240. `ChatMessageWebpageBubbleContentNode.swift` (ChatMessageWebpageBubbleContentNode): bizning reklamada "what's this?" — Novagram "Reklama haqida / Shikoyat".

#### Login

113. `AuthorizationSequencePhoneEntryController.swift` (AuthorizationUI): nav-bar'da QR va bot-token ikonkalari.
114. `AuthorizationSequencePhoneEntryControllerNode.swift` (AuthorizationUI): QR overlay. Intro telefon animatsiyasi takrorlanadi.
115. `AuthorizationSequenceController.swift` (AuthorizationUI): bot-token ekranini ochadi, 2FA "Orqaga" ulangan.
116. `AuthorizationSequencePasswordEntryController.swift` (AuthorizationUI): 2FA ekranida "Orqaga" tugmasi.
117. `NovagramBotAuthorization.swift` (TelegramCore, yangi fayl): bot token bilan avtorizatsiya.
118. `NovagramBotSession.swift` (TelegramCore, yangi fayl): bot sessiyasi helper'lari.
119. `AccountStateManagementUtils.swift` (TelegramCore): bot sessiyada chatlar ro'yxatga chiqadi, DM unread ishlaydi.
120. `ManagedChatListHoles.swift`, `ManagedMessageHistoryHoles.swift` (TelegramCore): bot sessiyada chat va tarix yuklanishi qotib qolmaydi.
121. `ManagedPendingPeerNotificationSettings.swift` (TelegramCore): bot sessiyada mute saqlanadi.
122. `ChatListFiltering.swift` (TelegramCore): bot sessiyada papka tablari ishlaydi.
123. `TelegramRootController.swift` (TelegramUI): bot sessiyada faqat Chats va Settings tablari.
124. `PeerInfoScreenSettingsActions.swift` (PeerInfoScreen): telefonsiz bot accountdan chiqish.
125. `AppDelegate.swift` (TelegramUI): telefonsiz bot account uchun nom.
241. `AuthorizationSequencePhoneEntryControllerNode.swift` (AuthorizationUI): QR login markazida Novagram logotipi (`NovagramQrLogo.image`, `ecl: "Q"`), QR 240pt da chiziladi.

#### Chat va xabarlar (Settings'dan tashqari)

126. `ChatMessageActionOptions.swift` (TelegramUI): **Tahrirlab yuborish** (#39): forward menyusidagi band.
127. `ChatContextMenus.swift` (ChatListUI): **Maxfiy ko'rish** va **Chat ID'ni nusxalash** (#24).
128. `PeerInfoProfileItems.swift` (PeerInfoScreen): **Profildagi ID qatori**, bosilsa nusxalanadi.
129. `PeerInfoScreenPerformButtonAction.swift` (PeerInfoScreen): **Novagram Info** profil "…" menyusida.
130. `ResolvePeerByName.swift`, `TelegramEnginePeers.swift` (TelegramCore): **Telefon raqam**: tarmoq xatosi alohida natija bo'lib qaytadi.
131. `ChatControllerOpenPhoneContextMenu.swift` (TelegramUI): **Telefon raqam**: xatoda "Qayta urinish" va to'g'ri xabar chiqadi.

#### Papkalar

132. `ChatListFilterPresetController.swift` (ChatListUI): papka muharririda "Ikonka" qatori (#18).
133. `NovagramFolderIconPicker.swift` (ChatListUI, yangi fayl): emoji ikonka tanlash ekrani (#18).
134. `UserLimitsConfiguration.swift` (TelegramCore): papka limiti 1000.
135. `ChatListFilterPresetListController.swift` (ChatListUI): "Show Folder Tags" Premium'siz.
136. `ChatListController.swift` (ChatListUI): header tugmalari chevron ortiga yig'iladi.

#### Qo'ng'iroqlar

137. `NotificationService.swift` (NotificationService): CallKit ishlamasa qo'ng'iroq ringtone bilan jiringlaydi.
138. `SharedAccountContext.swift`, `AppDelegate.swift` (TelegramUI): uxlayotgan accountga qo'ng'iroq kelsa account uyg'otiladi.
139. `Telegram/BUILD`: `INStartCallIntent` activity type.
140. `PresentationCall.swift` (TelegramCallsUI): qo'ng'iroq diagnostikasi uchun log qatori.
232. `SharedCallAudioContext.swift` (TelegramCallsUI): sessiya oxirgi bergan route (`sessionReportedAudioOutput`); `setCurrentAudioOutput` guard'i sessiya boshqa route'ni ko'rsatib turganda so'rovni tashlamaydi, shuning uchun video qo'ng'iroq quloq dinamikda qotib qolmaydi.
233. `CallControllerNodeV2.swift` (TelegramCallsUI): `userChosenAudioOutput` + `noteAudioOutputChosenByUser`; video paytidagi 1 s speaker timer foydalanuvchi tanlagan quloq dinamikni qaytarib yubormaydi.
234. `CallController.swift` (TelegramCallsUI): foydalanuvchi chiqish tanlaganda (2 ta chiqishli toggle va sheet) node'ga `noteAudioOutputChosenByUser` aytiladi.
235. `PrivateCallScreen.swift` (CallScreen): kamera yoqilganda speaker tugmasi flip camera'dan keyin qoladi (5 ta tugma).
236. `ButtonGroupView.swift` (CallScreen): 5 ta tugmada oraliq ekran eniga moslashadi (36pt dan 8pt gacha).
237. `TelegramCallsUI/Tests/NovagramSpeakerReapplyTests.swift` (yangi fayl, upstream modul ichida): 232-hook uchun regression testlar.

#### Bildirishnomalar

141. `Telegram/BUILD`: Communication Notifications entitlement (push'da yuboruvchi rasmi).
142. `NotificationService.swift` (NotificationService): bo'sh yoki umumiy "new message" bannerlari chiqmaydi (yashirin boshlash, bo'sh content fallback, 20 s watchdog, xom bannerlarni tozalash).
143. `NotificationService.swift` (NotificationService): bo'sh xizmat bannerlari `fenixuz_blank` belgisi bilan tozalanadi.
144. `AppDelegate.swift` (TelegramUI): NSE boyitmagan bannerlar tozalanadi, `peerId` uchun fallback.
145. `SharedNotificationManager.swift` (TelegramUI): o'qilgan xabar bildirishnomasi har bir live accountda o'chadi.
146. `ApplicationContext.swift` (TelegramUI): faqat primary account uchun ishlaydigan eski tozalash olib tashlangan.
147. `NotificationsAndSoundsController.swift` (SettingsUI): "Barcha accountlardan bildirishnomalar" bo'limi doim ko'rinadi.

#### Ilova va Settings

148. `PeerInfoSettingsItems.swift` (PeerInfoScreen): oltin "Novagram Settings", "Novagram Bots" va "Analytics" qatorlari (lokalizatsiya qilingan).
149. `PeerInfoScreenDisclosureItem.swift` (PeerInfoScreen): qator nomi uchun ixtiyoriy rang.
150. `PeerInfoScreen.swift`, `PeerInfoScreenSettingsActions.swift` (PeerInfoScreen): Bots va Analytics ekranlarini ochish.
151. `ItemListDisclosureItem.swift` (ItemListUI): Bots ro'yxatida avatar o'lchamini sozlash mumkin.
152. `AppDelegate.swift` (TelegramUI): Analytics ishga tushadi. `LogoutOptionsController.swift` (SettingsUI): tasdiqlangan logout statistikaga yuboriladi (2026-10-26).
153. `PrivacyInfo.xcprivacy` (Telegram app): anonim Device ID (Analytics, tracking yo'q).
154. `NovagramAnalyticsDuck.imageset` (TelegramUI, yangi asset): Analytics sahifasi rasmi.
155. `ApplicationContext.swift` (TelegramUI): birinchi launch'da Tips, keyingilarida App Store yangilanish tekshiruvi.
156. `AppDelegate.swift` (TelegramUI), `ThemeSettingsAppIconItem.swift` (SettingsUI): 7 ta Nova ikonka va ularning lokalizatsiya qilingan nomlari.
157. `Info.plist`, `Telegram/BUILD`, `Nova*Icon.alticon` (Telegram app): alternate ikonka fayllari.
158. `ChatListController.swift` (ChatListUI): header (ghost, fold) va story kamera tugmalarida haptic, tugmalarning o'z action'ida (2026-10-28 dan).
159. `ItemListSwitchItem.swift` (ItemListUI): switch'dagi "NEW" badge joyi tuzatilgan.
224. `PeerInfoSettingsItems.swift` (PeerInfoScreen): Settings tab'ining eng pastida (`support` section ostida) ilova versiyasi — "Novagram 13.0 (85)". Matn `NovagramAppVersion.displayText` (UpdateCheck moduli), hook — `PeerInfoScreenCommentItem(id: 100, ...)` + `import NovagramUpdateCheck` (2026-10-12). 2026-10-27 dan: qatorni 20 s bosib turish Developer bo'limini ochadi/yashiradi (`novagramLongPressDuration` / `novagramLongPressAction` = `NovagramDeveloperSection`), batafsil pastda "Developer section".
242. `PeerInfoScreenCommentItem.swift` (PeerInfoScreen): ixtiyoriy yashirin long press — item'da 2 ta `var` (`novagramLongPressDuration`, `novagramLongPressAction`), node `update`'ida `NovagramHiddenLongPress(view:recognizesSimultaneously: true)` + `import NovagramChannelStats` (2026-10-27, #224 uchun).
243. `PeerInfoSettingsItems.swift` (PeerInfoScreen): Analytics ostida "Valyuta kurslari" qatori (id 4), faqat Developer switch "Show currency rates" yoqiq bo'lsa; `NovagramCurrencyRatesEntry.open(context:)` + `import NovagramCurrencyRates` (2026-10-27).
244. `PeerInfoScreen.swift` (PeerInfoScreen): Settings data signal `NovagramDeveloperFlags.refreshing(...)` bilan o'ralgan (#243 qatori jonli chiqadi/yo'qoladi) + `import NovagramMessenger` (2026-10-27).

#### Brand va til

160. `PresentationData.swift` (TelegramPresentationData): server tarjimalaridagi "Telegram" so'zi "Novagram"ga almashtiriladi.
161. `en.lproj/Localizable.strings` (Telegram app): ichki matnlarda "Novagram" ("NOVAGRAM TONES" ham).
162. `InfoPlist.strings` (18 til), `InfoBazel.plist` (Telegram app): ruxsat so'rovlari matnida "Novagram".
163. `AppIntentVocabulary.plist` (19 til): Siri lug'atida "Novagram".
164. `Telegram/BUILD`: `bundle_name = "Novagram"`.
165. `CallKitIntegration.swift` (TelegramCallsUI): qo'ng'iroq ekranida "Novagram".
166. `Share/…/Localizable.strings`, `WidgetKitWidget/…/Localizable.strings`, `IntentHandler.swift`, `WidgetItems.swift`: Share, Widget va Siri matnlarida "Novagram".
167. `StoreDownloadedMedia.swift` (TelegramUI): Photos albomi "Novagram".
168. `DeviceContactData.swift` (AccountContext), `DeviceContactDataManager.swift` (TelegramUI), `IntentContacts.swift` (SiriIntents): kontakt label'i "Novagram", eski "Telegram" ham taniladi.
169. `AuthorizationSequenceSplashController.swift` (AuthorizationUI): Welcome ekranida brand rangi.
170. `RMIntroViewController.m` (RMIntro): simulator'da intro logosi.
171. `tgwatch Watch App/Info.plist` (WatchApp): watch ilovada "Novagram".
172. `SearchBarNode.swift` (SearchBarNode): xitoy tilida qidiruvdagi "x" tugmasi joyida turadi. **13.0: olib tashlandi, upstream bb5b4f5a3c o'zi tuzatgan.**
173. `TextProcessingTranslateContentComponent.swift` (TelegramUI): `zh-hans` → `zh`, shunda tarjima ishlaydi.
174. `LocalizationListControllerNode.swift` (SettingsUI): Settings → Language'da xitoy tili.
175. Telegram fayllaridagi Novagram matnlari (`ChatContextMenus`, `ChatController`, `ChatControllerNode`, `ChatInterfaceStateContextMenus` va boshqalar): `zh` tarjimasi qo'shilgan.

#### Apple talablari

176. `InAppPurchaseManager.swift` (InAppPurchaseManager): StoreKit olib tashlangan, har bir xaridda alert chiqadi.
177. `AppDelegate.swift` (TelegramUI), `AuthorizationSequencePaymentScreen.swift` (AuthorizationUI): `import StoreKit` olib tashlangan, obunalar web'da boshqariladi.
178. `PeerInfoSettingsItems.swift` (PeerInfoScreen): to'lov bo'limi faqat ko'rish uchun.
179. `DeviceAccess.swift` (DeviceAccess): iOS Contacts ruxsatidan oldin rozilik dialogi (5.1.2).
180. `DeviceContactDataManager.swift` (TelegramUI): kontakt ruxsati bo'lmasa ham chat ochiladi.
181. `TelegramRootController.swift` (TelegramUI): Contacts tabi qayta yoqilgan.
182. `AuthorizationSequencePhoneEntryController.swift` (AuthorizationUI): demo raqamda SMS polling oldindan boshlanadi.
183. `AuthorizationSequenceCodeEntryController.swift`, `AuthorizationSequenceCodeEntryControllerNode.swift` (AuthorizationUI): demo kod avtomatik to'ldiriladi, "Kod kelmadimi?" yashiriladi.

#### Crash fixlar (upstream xatolari)

184. `AnimatedStickerFrameSource.swift` (AnimatedStickerNode) va unga test: buzilgan sticker kesh fayli crash qilmaydi.
185. `EmojiHeaderComponent.swift`, `ReactionContextNode.swift`, `QuickShareToastScreen.swift`, `EmojiStatusSelectionComponent.swift`, `StoryItemSetContainerComponent.swift`: parabolik animatsiyada nolga bo'lish tuzatilgan.
186. `HLSVideoJSNativeContentNode.swift` (TelegramUniversalVideoContent): HLS range tekshiriladi.
187. `VolumeButtons.swift` (Utils): deinit main thread'da bajariladi.
188. `TGMediaPickerPhotoStripView.m` (LegacyComponents): media picker'da count mos kelmasa reload qilinadi. **13.0: olib tashlandi, upstream 37abd7a04a.**
189. `ChatInterfaceInputContexts.swift` (TelegramUI): eskirgan matn uzunligi tufayli bo'ladigan crash. **13.0: olib tashlandi, upstream f09120e85f.**
190. `SSubscriber.m` (SSignalKit): disposal race. **13.0: olib tashlandi, upstream 7f6f87843c.**
191. `PasskeysScreen.swift` (TelegramUI): `preconditionFailure` o'rniga anchor qaytariladi.
192. `NewContactScreen.swift` (TelegramUI): update re-entrancy.
193. `FFMpegMediaFrameSourceContext.swift`, `MediaPlayerNode.swift` (MediaPlayer): story video oxiridan o'tib ketganda Timer crash.
194. `LocationUtils.swift`, `LocationViewControllerNode.swift` (LocationUI): ETA shimmer qotib qolmaydi (ruxsat va timeout).
195. `OpenInOptionsScreen.swift` (OpenInExternalAppUI): "Open In" ikonkalari bosiladi (upstream cherry-pick). **13.0: upstream'da bor, hook yo'q.**

#### BUILD dependency'lar

196. `AuthorizationUI/BUILD`: AppleReview, Brand, Localization, AutoProxy, BotTokenLogin.
197. `CallListUI/BUILD`: SecretVault.
198. `ChatListUI/BUILD`: StoryUnlock, ChatLock, SecretVault, ForeignUserBlock, NovagramAds, Localization.
199. `ContactListUI/BUILD`: SecretVault, ChatLock.
200. `DeviceAccess/BUILD`: ContactsConsent.
201. `InAppPurchaseManager/BUILD`: AppStoreIAP (StoreKit davridagi deplar olib tashlangan).
202. `SettingsUI/BUILD`: PremiumUnlock, Localization, Analytics (logout statistikasi, 2026-10-26).
203. `TelegramPresentationData/BUILD`: Brand.
204. `TelegramUI/BUILD`: PremiumUnlock, StoryUnlock, ChatLock, SecretVault, ForeignUserBlock, EditedHistory, Localization, Tips, UpdateCheck, UnreadReminder, NovagramMessenger, Analytics, AutoProxy, NovagramAds, ForwardEdit.
205. `ChatMessageDateAndStatusNode/BUILD`: Localization.
205b. `GalleryUI/BUILD`, `ChatMessageWebpageBubbleContentNode/BUILD`: NovagramAds (faqat `NovagramSponsoredBridge`).
206. `ChatTextInputPanelNode/BUILD`: SpeechToText, Localization, RoundVideoFromGallery.
207. `GlobalControlPanelsContext/BUILD`: NovagramAds.
208. `PeerInfoScreen/BUILD`: NovagramMessenger, Localization, Analytics, UpdateCheck (versiya footer'i, #224), CurrencyRates (#243, 2026-10-27).
209. `StoryContainerScreen/BUILD`: StoryUnlock.
210. `TranslateHeaderPanelComponent/BUILD`: PremiumUnlock.
211. `AnimatedStickerNode/BUILD`: unit test target'lari.

#### Build

212. `Telegram/BUILD`: minimum iOS 15.0, widget uchun ham. **13.0: upstream ham 15.0; widget genrule olib tashlangan.**
213. 39 ta `BUILD` fayl: iOS 15 deprecation'lari error emas, warning bo'ladi.
214. `sqlcipher/BUILD`: Xcode 26.5 SDK uchun `sqlite3ext.h` private qilingan.
215. `run.sh`: device build'da push entitlement (`aps_environment`).
216. `Telegram/BUILD`: upstream watch app qaytarilganda fork sozlamalari saqlab qolingan (`composer_icon_folders = []`, `:PrivacyManifest`).
217. `project.yml`, `project.pbxproj` (WatchApp): Team ID `ZDBP5RSRZF`.
218. `ChatInputTextNode.swift` (TelegramUI): input diagnostika log'i (faqat DEBUG).
219. `run.sh`: Xcode versiyasi o'rnatilgan Xcode'dan olinadi, Swift 6.4 warning'lari error bo'lmaydi.
220. `ChatControllerNode.swift` (TelegramUI): Swift 6.4 uchun `EmptyInputView` importi aniqlashtirilgan. **13.0: olib tashlandi, upstream `EmptyKeyboardInputView` (fdcd002ef5).**
221. `AppDelegate.swift` (TelegramUI), `Telegram/BUILD`, `TelegramUI/BUILD`: UIScene life cycle (`NovagramSceneDelegate`), iOS 27 SDK bilan ilova ochilishi uchun. **13.0: olib tashlandi, upstream `SceneDelegate` (13a2694420); `Novagram/SceneLifecycle` o'chirildi.**
222. `UIViewController+Navigation.m` (UIKitRuntimeUtils): iOS 27'da yashirin klaviatura API chaqirilmaydi, ilova ishga tushganda to'xtamaydi. **13.0: olib tashlandi, upstream 93af3a138e.**
223. `publish.sh`, `release.sh`: App Store build uchun Swift 6.4 flag'lari.

#### CarPlay

225. `Telegram/BUILD`: CarPlay entitlement `com.apple.developer.carplay-communication` (`uz.fenixuz.app` va simulator bundle). Telegram'ning eski `carplay-messaging` kaliti bizning profillarda yo'q. `IntentsSupported` esa yana upstream bilan bir xil (pull'da upstream'niki olinadi).
226. `run.sh`: yangi `my-config.json` va `my-device-config.json` `enable_siri: true` bilan yaratiladi.
227. `publish.sh`: imzolangan IPA'da CarPlay yoki Siri entitlement'i bo'lmasa ogohlantiradi.
228. `AppIntentVocabulary.plist` (en, ru, uz): `INSearchForMessagesIntent` misollari; `uz` da o'zbekcha `INSendMessageIntent` misollari.
229. `AppDelegate.swift` (TelegramUI): `import NovagramCarPlay`; `configurationForConnecting` ichida `NovagramCarPlaySupport.configure(...)` (CarPlay template scene delegate'i); ishga tushishda `NovagramCarPlaySupport.start(sharedContext:)`.
230. `TelegramUI/BUILD`: `//submodules/Novagram/CarPlay:NovagramCarPlay` dep.
231. `IntentHandler.swift`, `IntentMessages.swift` (SiriIntents): CarPlay'da tanlangan chat (`conversationIdentifiers`) to'g'ridan-to'g'ri o'qiladi (`unreadMessages(account:peerIds:)`), mute bo'lsa ham va 20 ta chatdan tashqarida bo'lsa ham.

---

## 📌 AuthorizationUI module

### `submodules/AuthorizationUI/BUILD`

In the `deps = [...]` list, append:

```python
"//submodules/Novagram/AppleReview:NovagramAppleReview",
"//submodules/Novagram/Brand:NovagramBrand",
```

Reason:

- `NovagramAppleReview` — CodeEntry controller calls it for demo-account SMS auto-fill.
- `NovagramBrand` — Splash controller calls it for emerald-green brand colors on the intro/welcome screen.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceSplashController.swift`

**Top of file — imports block.** Add after `import RMIntro`:

```swift
import NovagramBrand
```

**Inside `init(...)` — replace the RMIntroViewController + startButton instantiation block.** Find these lines:

```swift
self.controller = RMIntroViewController(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, buttonColor: theme.intro.startButtonColor, accentColor: theme.list.itemAccentColor, regularDotColor: theme.intro.dotColor, highlightedDotColor: theme.list.itemAccentColor, suggestedLocalizationSignal: localizationSignal)

self.startButton = SolidRoundedButtonNode(title: "Start Messaging", theme: SolidRoundedButtonTheme(theme: theme), glass: false, height: 50.0, cornerRadius: 50.0 * 0.5, isShimmering: true)
```

Replace with:

```swift
// Novagram: brand emerald (#10B981/#059669) Telegram blue o'rniga.
let novagramPrimary = NovagramBrandColors.primary
self.controller = RMIntroViewController(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, buttonColor: novagramPrimary, accentColor: novagramPrimary, regularDotColor: theme.intro.dotColor, highlightedDotColor: novagramPrimary, suggestedLocalizationSignal: localizationSignal)

let novagramButtonTheme = SolidRoundedButtonTheme(backgroundColor: novagramPrimary, foregroundColor: .white)
self.startButton = SolidRoundedButtonNode(title: "Start Messaging", theme: novagramButtonTheme, glass: false, height: 50.0, cornerRadius: 50.0 * 0.5, isShimmering: true)
```

Reason: Telegram's default theme uses blue accent everywhere. Novagram brand colour (`#10B981` emerald green, from https://fenixuz.uz CSS palette) must replace blue specifically on the Welcome / Start Messaging screen (the most brand-defining surface). Three call-sites of `theme.list.itemAccentColor` + the button theme are swapped.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import NovagramAppleReview
```

**Inside `viewDidAppear(_ animated: Bool)` — after `self.controllerNode.activateInput()`:**

```swift
// Novagram: Apple Review demo akkount uchun SMS kodni avtomatik fetch + iOS alert
if let (number, _, codeType, nextType, _, _, _) = self.data {
    if NovagramDemoCodeFetcher.isDemoPhone(number) {
        self.controllerNode.novagramHideNextOption(true)
    }
    // Kod boshqa faol sessiyaga yuborilgan bo'lsa SMS-forwarder uni ko'rmaydi —
    // fetcher SMS'ga qayta so'rov yuborishi kerak.
    var codeSentToOtherSession = false
    if case .otherSession = codeType, nextType != nil {
        codeSentToOtherSession = true
    }
    NovagramDemoCodeFetcher.autoFillIfDemo(
        phoneNumber: number,
        presenter: self,
        codeSentToOtherSession: codeSentToOtherSession,
        requestSmsFallback: { [weak self] in self?.requestNextOption?() },
        applyCode: { [weak self] code in
            self?.controllerNode.updateCode(code)
            self?.continueWithCode(code)
        }
    )
}
```

Reason: `data` (phone number tuple) and `controllerNode` are `private` — Novagram module cannot reach them from outside. The hook reads them and delegates to `NovagramDemoCodeFetcher`. `continueWithCode(_:)` is also private → must be invoked from inside the class.

**Updated 2026-08-21 (v4).** The hook now also forwards the _code delivery channel_. When the
demo account has another active Telegram session, the server sends the login code in-app
(`SentAuthorizationCodeType.otherSession`) instead of by SMS — the SMS forwarder behind
the review code endpoint then never sees it and the backend keeps serving the previous code, so
auto-fill sat at the "Demo Mode" alert for the full 60s and gave up. `requestSmsFallback`
wraps the controller's private `requestNextOption` (→ `resendAuthorizationCode`, i.e.
`auth.resendCode`) so the fetcher can force a real SMS. `nextType != nil` mirrors the upstream
condition at `AuthorizationSequenceController.swift:~691` — with a nil `nextType` that closure
opens the "did not get the code" reporting UI instead of resending, which must not happen
unattended during review.

**Done (2026-10-26): the demo code endpoint is out of this repo.** The URL and the demo phone live
only in the private NovagramServices SDK (v1.1.0), vendored as
`submodules/Novagram/Services/Frameworks/NovagramServices.xcframework` (static, iOS slices,
values XOR-masked at build time; one import target `//submodules/Novagram/Services:NovagramServicesSDK`). `NovagramDemoCodeFetcher` asks `ServicesClient().reviewLogin`
(`isConfigured`, `isReviewPhone`, `fetchCode`) and keeps its own tuned polling. To change the URL or
the phone: edit `.env` in the SDK repo, run `LINKAGE=static SLICES=ios scripts/build-xcframework.sh`
there and copy `build/NovagramServices-static.xcframework` to `submodules/Novagram/Services/Frameworks/`
as `NovagramServices.xcframework` (steps: the SDK's `docs/INTEGRATION.md`).
Masking is obfuscation, not encryption (see the SDK's `SECURITY.md`).

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift`

**Immediately after the three node declarations** (`nextOptionTitleNode`, `nextOptionButtonNode`, `nextOptionArrowNode`), add:

```swift
// Novagram: demo phone uchun "Didn't get the code?" tugma yashirish.
// Status matn alohida UIView banner orqali ko'rsatiladi (NovagramAppleReview module'da)
public var novagramDemoMode: Bool = false
public func novagramHideNextOption(_ hide: Bool) {
    self.novagramDemoMode = hide
    self.nextOptionTitleNode.isHidden = hide
    self.nextOptionButtonNode.isHidden = hide
    self.nextOptionArrowNode.isHidden = hide
}
```

**Inside the SMS-case countdown disposable block** (`if let timeout = timeout {` branch — typically around line 442–465), find the line that reads:

```swift
strongSelf.nextOptionTitleNode.attributedText = nextOptionText
```

Replace with:

```swift
// Novagram: demo phone'da bizning matn ustidan yozmaymiz
if !strongSelf.novagramDemoMode {
    strongSelf.nextOptionTitleNode.attributedText = nextOptionText
}
```

Reason: the three nodes are `private` — only a method inside this class can flip their `isHidden`. The `novagramDemoMode` flag blocks Telegram's countdown disposable from overwriting our demo-status content (when we ever choose to show inline status in this node — currently disabled, banner is used instead, but the guard remains so future inline-status work is safe).

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` + `…PhoneEntryController.swift` — QR login (UPDATED 2026-06-27)

> **2026-06-27 update — supersedes the detailed blocks below.** The QR-login **entry moved from
> the in-form text button to a nav-bar QR icon (toolbar)**, and the QR overlay now has a reachable
> exit. Authoritative source = `git diff`; the hook points are:
>
> **Node (`…PhoneEntryControllerNode.swift`):**
>
> - `import NovagramLocalization` (unchanged — `showQrOverlay()` reads `NovagramL10n(strings).auth_qrLoginButton`).
> - Overlay state vars `qrOverlayNode / qrNode / qrOverlayTitleNode / qrOverlayInstructionNode / qrOverlayCancelNode / qrOverlayBackNode` + `var qrOverlayVisibilityChanged: ((Bool) -> Void)?`.
> - `func presentQrOverlay()` (public entry the controller's nav-bar icon calls) → `showQrOverlay()`.
> - `showQrOverlay()` builds the full-bleed overlay (title, 240×240 QR, instruction, bottom **Cancel**, **top-left back chevron** = SF Symbol `chevron.left`), calls **`self.view.endEditing(true)`** (root-cause fix), then fires `qrOverlayVisibilityChanged?(true)`. Both Cancel and back target `dismissQrOverlay`.
> - `dismissQrOverlay()` fires `qrOverlayVisibilityChanged?(false)`, removes the overlay, re-arms the token listener.
> - `applyQrOverlayLayout()` centres the block and pins the back button top-left at `(8, statusBarHeight+4, 44, 44)`.
> - The old in-form `qrLoginButtonNode` text button + `qrLoginButtonTapped()` are **removed**.
>
> **Controller (`…PhoneEntryController.swift`):**
>
> - `updateNavigationItems()`: on full-size layouts (`width >= 360`, `account != nil`, not in-progress) sets `navigationItem.rightBarButtonItem` to `UIBarButtonItem(image: UIImage(systemName: "qrcode"), …)` → `qrIconPressed()` → `controllerNode.presentQrOverlay()`.
> - `loadDisplayNode()` wires `controllerNode.qrOverlayVisibilityChanged = { self?.handleQrOverlayVisibility($0) }`.
> - `handleQrOverlayVisibility(_:)` tracks `isQrOverlayVisible`, `view.endEditing(true)` + hides the QR icon while the overlay is up; on dismiss restores the icon (`updateNavigationItems()`) and re-focuses the phone field (`activateInput()`).
>
> Reason: the overlay's only exit was a bottom **Cancel** centred in full-screen height while the
> keyboard was up → it sat **behind the keyboard**, with no top/nav-bar exit → users were trapped.
> Fix = resign the keyboard on open + add a guaranteed-visible top-left back button; and per the
> user's request, move the entry from an in-form text link to a nav-bar QR icon. (A nav-bar back
> button was tried first but the full-bleed overlay covers the nav bar, so the back button lives
> _inside_ the overlay.)

<details><summary>Historical (2026-06-08) — original in-form text-button hook, now superseded</summary>

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` — visible QR login button (2026-06-08)

**Top of file — imports block.** Add after `import Markdown`:

```swift
import NovagramLocalization
```

**Inside `AuthorizationSequencePhoneEntryControllerNode` class body** — after `private var qrNode: ASImageNode?`:

```swift
// Novagram: visible "Log in by QR code" text button on the phone-entry screen.
private let qrLoginButtonNode: ASButtonNode
```

**Inside `init(...)` — after `proceedNode.accessibilityIdentifier` line** (before `super.init()`):

```swift
// Novagram: visible QR-code login button — text-only, styled like Telegram's secondary login links.
self.qrLoginButtonNode = ASButtonNode()
let qrTitle = NovagramL10n(strings).auth_qrLoginButton
self.qrLoginButtonNode.setTitle(qrTitle, with: Font.regular(17.0), with: theme.list.itemAccentColor, for: .normal)
self.qrLoginButtonNode.setTitle(qrTitle, with: Font.regular(17.0), with: theme.list.itemAccentColor.withAlphaComponent(0.6), for: .highlighted)
self.qrLoginButtonNode.accessibilityLabel = qrTitle
self.qrLoginButtonNode.accessibilityTraits = .button
```

**Inside `init(...)` — after `self.contactSyncNode.isHidden = true`** (the addSubnode block):

```swift
// Novagram: QR login button — only shown when there is an account context (account != nil)
// and screen is wide enough (same guard as proceedNode). Hidden on small-layout path.
self.addSubnode(self.qrLoginButtonNode)
self.qrLoginButtonNode.isHidden = (account == nil)
```

**Inside `init(...)` — after `self.proceedNode.pressed = { ... }` closure:**

```swift
// Novagram: "Log in by QR code" — tap creates qrNode on demand (same as debugQrTap)
// and calls refreshQrToken() which exports the login token + renders the QR image.
self.qrLoginButtonNode.addTarget(self, action: #selector(self.qrLoginButtonTapped), forControlEvents: .touchUpInside)
```

**New method — after `debugQrTap(_:)` (around line 712):**

```swift
// Novagram: tap handler for the visible "Log in by QR code" button.
// Mirrors debugQrTap but is always reachable by the user (no debug gesture required).
@objc private func qrLoginButtonTapped() {
    if self.qrNode == nil {
        let qrNode = ASImageNode()
        qrNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 64.0 + 16.0), size: CGSize(width: 200.0, height: 200.0))
        self.qrNode = qrNode
        self.addSubnode(qrNode)
    }
    self.refreshQrToken()
}
```

**Inside `containerLayoutUpdated` — inside the `if layout.size.width > 320.0` branch, after `self.animationNode.visibility = true`:**

```swift
// Novagram: QR button visible only on full-size screens and only when account context exists.
self.qrLoginButtonNode.isHidden = (self.account == nil)
```

**Inside `containerLayoutUpdated` — inside the `else` branch (small-layout path), after `self.managedAnimationNode.isHidden = true`:**

```swift
self.qrLoginButtonNode.isHidden = true
```

**Inside `containerLayoutUpdated` — immediately after `transition.updateFrame(node: self.proceedNode, frame: buttonFrame)`:**

```swift
// Novagram: position the QR login button just above the Continue button, centred.
// Height = 44pt (standard tap target). Spacing = 12pt above the Continue button.
let qrButtonHeight: CGFloat = 44.0
let qrButtonWidth: CGFloat = maximumWidth - inset * 2.0
let qrButtonY = buttonFrame.minY - 12.0 - qrButtonHeight
let qrButtonFrame = CGRect(
    x: floorToScreenPixels((layout.size.width - qrButtonWidth) / 2.0),
    y: qrButtonY,
    width: qrButtonWidth,
    height: qrButtonHeight
)
transition.updateFrame(node: self.qrLoginButtonNode, frame: qrButtonFrame)
```

Reason: `refreshQrToken()` is `private` — it cannot be called from a Novagram module. The entire QR-login session-export machinery (MTProto `auth.exportLoginToken`, `tg://login?token=…` URL, `qrCode(...)` Signal, token-expiry refresh loop, `loginTokenSuccess`/`loginTokenMigrateTo` handling) already exists in this file and works correctly — it was only reachable via a hidden `#if DEBUG && false` gesture on `noticeNode`. This hook surfaces it as a standard visible button with no new logic. The `account == nil` guard mirrors the upstream condition: when `account == nil` (change-number flow), the button stays hidden. Demo flow is completely unaffected — `qrLoginButtonTapped` does not touch `checkPhone`, `prewarmIfDemo`, or any code-entry path.

</details>

---

### `submodules/AuthorizationUI/BUILD` — +1 NovagramLocalization dep (2026-06-08)

Append to `deps = [...]`:

```python
"//submodules/Novagram/Localization:NovagramLocalization",
```

Reason: `AuthorizationSequencePhoneEntryControllerNode.swift` now imports `NovagramLocalization` to read `NovagramL10n(strings).auth_qrLoginButton` for the visible QR button label (en/uz/ru). Bazel requires all transitive imports to be in `deps`.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import NovagramAppleReview
```

**Inside the TWO `loginWithNumber?(strongSelf.controllerNode.currentNumber, ...)` call sites** — currently around lines 415 and 426. Each lives inside a closure (one in `confirmationController.proceed`, one in the small-layout `TextAlertAction.defaultAction`). Insert ONE LINE BEFORE each `loginWithNumber?(...)` call:

```swift
// Novagram: demo phone uchun xmax.uz SMS forwarder polling'ni shu paytda boshlaymiz.
NovagramDemoCodeFetcher.prewarmIfDemo(phoneNumber: strongSelf.controllerNode.currentNumber)
```

Reason: **Apple App Store rejection 2026-05-15** — the demo phone login was taking 240s+ in App Review because polling started only when the CodeEntry screen appeared (after MTProto round-trip), and the polling logic had a 20-attempt minimum-wait + a baseline-change requirement. Pre-warming at the PhoneEntry "Next" tap kicks off polling 2-5 seconds earlier, and combined with the simplified acceptance logic in `NovagramDemoCodeFetcher` (drop initialFillAfter from 20→0, drop baseline gate, drop maxAttempts from 180→60), end-to-end login now completes in <15s typical.

The `prewarmIfDemo` call is a no-op for any non-demo number, so real users are unaffected.

---

## 📌 Bot token login (login-only, LIMITED bot-session UX) — 2026-07-17

Lets a user log in with a **bot token** (`123456:ABC-...`) instead of a phone number, via the MTProto RPC `auth.importBotAuthorization`. This is a **secondary, additive entry point** on the existing phone-entry screen — the phone-number send-code/verify-code path (`sendAuthorizationCode` / `authorizeWithCode` / `resendAuthorizationCode` in `Authorization.swift`) is completely untouched. The manager has accepted the resulting session's limited bot UX (a bot session does not populate a normal chat list/history the way a user session does) as an acceptable trade-off for this feature — it is login-only, not a chat client for the bot.

`auth.importBotAuthorization` is **atomic** — one round trip, no code/password step — so per the design constraint it is **not** added as a case of `UnauthorizedAccountStateContents` (that enum drives the phone flow's multi-step server-authoritative state machine). Instead the bot-token screen is pushed **locally** by `AuthorizationSequenceController`, the same pattern already used for passkey login.

### `submodules/TelegramCore/Sources/NovagramBotAuthorization.swift` (NEW FILE, 55 lines)

This is a **new Telegram-owned file** (lives in `TelegramCore/Sources/`, not under `submodules/Novagram/`) — an exception to the "Novagram logic lives in a Novagram module" rule, made necessary by `switchToAuthorizedAccount(transaction:account:isSupportUser:)` (`Authorization.swift:18`) being `internal` (no access modifier). A Novagram module outside the `TelegramCore` Bazel target cannot call it; making it `public` would widen a call surface that upstream deliberately keeps module-private. Placing the new function in a file inside `TelegramCore/Sources/` instead keeps `switchToAuthorizedAccount`'s visibility **unchanged** (still `internal`, confirmed at `Authorization.swift:18` — no modifier was touched) while still reusing it directly, since Bazel's `srcs = glob(["Sources/**/*.swift"])` (`TelegramCore/BUILD:6-8`) picks up any file dropped in that tree as part of the same compilation unit/module.

Full contents — `ImportBotAuthorizationError` enum (`.invalidToken` / `.limitExceeded` / `.generic`) and:

```swift
public func importBotAuthorization(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, apiId: Int32, apiHash: String, botToken: String) -> Signal<Void, ImportBotAuthorizationError>
```

It calls `Api.functions.auth.importBotAuthorization(flags: 0, apiId:apiHash:botAuthToken:)` (`TelegramApi/Sources/Api42.swift:2416`), maps `ACCESS_TOKEN_INVALID`/`ACCESS_TOKEN_EXPIRED` → `.invalidToken`, `FLOOD_WAIT*` → `.limitExceeded`, anything else → `.generic`. On success it mirrors the tail of the phone flow's own completion sequence — `storeFutureLoginToken`, builds an `AuthorizedAccountState`, calls `initializedAppSettingsAfterLogin`, `transaction.setState(state)`, then `accountManager.transaction { switchToAuthorizedAccount(transaction:account:isSupportUser: false) }` — the exact same helpers `sendAuthorizationCode` and `authorizeWithCode` already use, so account-switch behavior (sort order, `setCurrentId`, `removeAuth`) is identical to a phone login.

**No BUILD change required** — `TelegramCore/BUILD` already depends on `TelegramApi`, `MtProtoKit`, `SwiftSignalKit`, and `Postbox` (the four imports this file needs), and the `glob()` above requires no explicit `srcs` entry.

### `submodules/Novagram/BotTokenLogin/` module (target `NovagramBotTokenLogin`)

Pure-UI Novagram module, two files:

- `Sources/AuthorizationSequenceBotTokenEntryController.swift` (135 lines) — `ViewController` subclass, simplified clone of `AuthorizationSequencePasswordEntryController`: single text field + "Next", `public var loginWithToken: ((String) -> Void)?` callback, `public init(sharedContext:presentationData:back:displayBack:)`.
- `Sources/AuthorizationSequenceBotTokenEntryControllerNode.swift` (222 lines) — the node: title, a notice label ("Bot rejimi cheklangan: chat ro'yxati va tarix ko'rinmaydi" — surfaces the LIMITED bot-session caveat to the user up front), the token `TextFieldNode`, and a `SolidRoundedButtonNode` "Kirish".

`BUILD` deps (`Display`, `AsyncDisplayKit`, `TelegramPresentationData`, `AccountContext`, `TelegramCore`, `SwiftSignalKit`, `PresentationDataUtils`, `ProgressNavigationButtonNode`, `AuthorizationUtils`, `AnimatedStickerNode`, `TelegramAnimatedStickerNode`, `SolidRoundedButtonNode`) all resolve against the module's actual imports — verified by grepping every symbol used in both source files (`TextFieldNode`/`AccessibilityAreaNode`/`HapticFeedback`/`UITracingLayerView` → `Display`; `AnimatedStickerNodeLocalFileSource`/`DefaultAnimatedStickerNodeImpl` → `AnimatedStickerNode`/`TelegramAnimatedStickerNode`; `AuthorizationLayoutItem`/`layoutAuthorizationItems` → `AuthorizationUtils`). `TelegramCore` and `PresentationDataUtils` are declared but currently unused by either source file — harmless (Bazel doesn't fail on an unused dep) and left as-is per minimal-diff; not worth a churn-only removal commit.

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift`

**Property, next to `loginWithPasskey` (lines 65–66):**

```swift
// Novagram: fired when the "Bot token bilan kirish" secondary button is tapped.
public var loginWithBotToken: (() -> Void)?
```

**Wiring, inside `loadDisplayNode()` right after the `retryPasskey` closure (lines 251–254):**

```swift
// Novagram: secondary "Bot token bilan kirish" button → let the sequence controller push the token screen.
self.controllerNode.botTokenPressed = { [weak self] in
    self?.loginWithBotToken?()
}
```

No new import needed — this file only forwards a closure, it never references `AuthorizationSequenceBotTokenEntryController` directly.

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift`

Adds one secondary text button, styled and positioned like a link, sitting just above the "Continue" button:

- **Declaration** (line 324): `private let botTokenButton: HighlightableButtonNode` — `HighlightableButtonNode` is defined in `Display/Source/HighlightableButton.swift`, already imported; no new import.
- **Callback** (line 346): `var botTokenPressed: (() -> Void)?`
- **Init** (lines 450–453): instantiate + `setTitle("Bot token bilan kirish", ...)` + accessibility label/traits.
- **`addSubnode`** (line 470) and **target wiring** (line 475): `self.botTokenButton.addTarget(self, action: #selector(self.botTokenButtonPressed), forControlEvents: .touchUpInside)`.
- **Visibility** — toggled alongside `proceedNode` in both `containerLayoutUpdated` branches: `isHidden = false` on the wide layout (line 673), `isHidden = true` on the narrow/small layout (line 679).
- **Layout** (lines 701–704): measured and positioned 14pt above the Continue button's frame, horizontally centered.
- **Tap handler** (lines 726–727): `@objc private func botTokenButtonPressed() { self.botTokenPressed?() }`.

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift`

**Import (line 26):**

```swift
import NovagramBotTokenLogin
```

**Wiring, inside `phoneEntryController(...)` (the factory starting at line 162), right after the passkey `loginWithPasskey` block (lines 361–364):**

```swift
// Novagram: secondary entry point — push the bot-token login screen.
controller.loginWithBotToken = { [weak self] in
    self?.presentBotTokenEntry()
}
```

**New private methods (lines 370–412)**, mirroring the existing `passwordEntryController(...)` / `codeEntryController(...)` singleton-reuse pattern:

```swift
// Novagram: builds the bot-token login screen, mirroring passwordEntryController(...). auth.importBotAuthorization
// is atomic, so this is pushed locally (like passkey) instead of routing through UnauthorizedAccountStateContents.
private func botTokenEntryController() -> AuthorizationSequenceBotTokenEntryController {
    for c in self.viewControllers {
        if let c = c as? AuthorizationSequenceBotTokenEntryController {
            return c
        }
    }
    let controller = AuthorizationSequenceBotTokenEntryController(sharedContext: self.sharedContext, presentationData: self.presentationData, back: { [weak self] in
        guard let strongSelf = self else { return }
        let _ = strongSelf.popViewController(animated: true)
    })
    controller.loginWithToken = { [weak self, weak controller] token in
        guard let strongSelf = self else { return }
        controller?.inProgress = true
        strongSelf.actionDisposable.set((importBotAuthorization(accountManager: strongSelf.sharedContext.accountManager, account: strongSelf.account, apiId: strongSelf.apiId, apiHash: strongSelf.apiHash, botToken: token)
        |> deliverOnMainQueue).startStrict(error: { [weak self, weak controller] error in
            guard let strongSelf = self, let controller = controller else { return }
            controller.inProgress = false
            let text: String
            switch error {
            case .invalidToken: text = "Bot token noto'g'ri yoki eskirgan."
            case .limitExceeded: text = strongSelf.presentationData.strings.Login_CodeFloodError
            case .generic: text = strongSelf.presentationData.strings.Login_UnknownError
            }
            controller.present(textAlertController(sharedContext: strongSelf.sharedContext, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }))
    }
    return controller
}

private func presentBotTokenEntry() {
    self.pushViewController(self.botTokenEntryController())
}
```

`self.apiId` / `self.apiHash` (lines 43–44/71–72) are pre-existing controller properties, already threaded through from `sendAuthorizationCode`'s call site — no new plumbing needed. On success, `importBotAuthorization`'s Signal completes with no `.next` value and no error, so there's no explicit success handler here: `switchToAuthorizedAccount` (called inside `NovagramBotAuthorization.swift`) already flips `AccountManager`'s current account, and the app's existing root-controller account-switch observer takes it from there — same as the phone flow's own `.loggedIn` completion.

### `submodules/AuthorizationUI/BUILD`

`deps = [...]` already contains (line 55):

```python
"//submodules/Novagram/BotTokenLogin:NovagramBotTokenLogin",
```

Reason: `AuthorizationSequenceController.swift` imports `NovagramBotTokenLogin` for `AuthorizationSequenceBotTokenEntryController`.

### Post-login incoming messages → chat list (2026-07-17)

Follow-up so that messages arriving **after** bot login (a user DMs the bot, or a group/channel the bot is in gets a message) materialize a chat-list row. Pre-login history is still unavailable (bots can't call `messages.getDialogs`/`getHistory`), but live updates flow through the normal update pipeline and are now persisted into the chat list.

**Root cause:** the update pipeline (`AccountStateManager` → `replayFinalState`) is not gated off for bots and writes incoming messages to Postbox history via `transaction.addMessages(...)`. But an incoming message alone never sets **chat-list inclusion** — that only comes from the dialog-sync paths (`messages.getDialogs`/`getPeerDialogs`), which bots can't use. So a bot session's peers stay `.notIncluded` and never show a row (`ChatListIndexTable` default). The fix forces inclusion for a bot session's message peers.

#### `submodules/TelegramCore/Sources/NovagramBotSession.swift` (NEW FILE, ~45 lines)

New Telegram-owned file (same rationale/exception as `NovagramBotAuthorization.swift` — it calls the `internal` helper `updatePeerChatInclusionWithMinTimestamp` from `UpdatePeers.swift:5`, so it must live inside the `TelegramCore` glob). Contents:

- `setNovagramBotSession(transaction:isBot:)` / `novagramIsBotSession(transaction:) -> Bool` — persist/read a per-account-postbox preference marking the session as a bot. Stored under a **length-8** `ValueBoxKey` (`0x46656E78426F7431` = "FenxBot1") which cannot collide with the upstream length-4 preference keys.
- `novagramIsBotSession(transaction:accountPeerId:) -> Bool` — robust variant used by `replayFinalState`: returns true if the login flag is set **OR** the account's own peer has `botInfo` (i.e. it is a bot). The peer check makes the fix work **retroactively** for accounts logged in before the flag existed — no re-login needed.
- `novagramForceBotChatInclusion(isBotSession:transaction:messages:location:)` — for a bot session, on `.UpperHistoryBlock` messages, calls `updatePeerChatInclusionWithMinTimestamp(..., forceRootGroupIfNotExists: true)` per peer so the chat materializes from the message alone. **No-op for normal accounts** (guard on `isBotSession`). Has a `#if DEBUG` `NOVAGRAM_BOTLOGIN` log used to confirm updates flow during device testing.

No BUILD change — picked up by `TelegramCore/BUILD`'s `glob()`.

#### `submodules/TelegramCore/Sources/NovagramBotAuthorization.swift` (hook, +3 lines)

Right after `transaction.setState(state)`, add `setNovagramBotSession(transaction: transaction, isBot: true)` so the account is tagged at login time.

#### `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift` (2 one-line hooks)

- Near the top of `replayFinalState(...)` (right after `var peerIdsWithAddedSecretMessages = Set<PeerId>()`): `let novagramBotSession = novagramIsBotSession(transaction: transaction, accountPeerId: accountPeerId)` — read once per replay (retroactive peer-based detection).
- In the `.AddMessages` operation handler, immediately after `_ = transaction.addMessages(messages, location: location)`: `novagramForceBotChatInclusion(isBotSession: novagramBotSession, transaction: transaction, messages: messages, location: location)`.

### Chat-list hole removal for bot sessions (2026-07-17)

Even with inclusion forced, the chat list rendered **empty** because a fresh account has a top **chat-list hole** that the client fills via `messages.getDialogs`. Bots get `BOT_METHOD_INVALID` on `getDialogs`, so `managedChatListHoles` retried the fetch forever (observed: ~140 `getDialogs` calls in a couple of minutes) and the list view stayed stuck on the unresolved hole — the locally-materialized chats never showed.

- **`submodules/TelegramCore/Sources/NovagramBotSession.swift`** — added `novagramManagedChatListHole(postbox:network:accountPeerId:groupId:hole:) -> Signal<Never, NoError>`: for a bot session it `replaceChatListHole(..., hole: nil)` (removes the hole so the list is treated as loaded); for a normal account it calls the original `fetchChatListHole(...)` unchanged. Requires `import SwiftSignalKit` (added to the file).
- **`submodules/TelegramCore/Sources/State/ManagedChatListHoles.swift`** — one-line hook: the `for (entry, disposable) in added` loop calls `novagramManagedChatListHole(...)` instead of `fetchChatListHole(...)` directly.

### DM unread count, group/channel open, and folders for bot sessions (2026-07-17)

Three follow-ups, all bot-gated, all logic in `NovagramBotSession.swift` with 1-line hooks in Telegram-owned files:

**DM unread count.** Bots can't call `getPeerDialogs`/`getHistory`, which normally seed a DM's `PeerReadState`; without a read state, an incoming DM never increments the unread count (`MessageHistoryReadStateTable.addIncomingMessages` only increments when a state already exists). Groups/channels differ because their read state is seeded from the channel `pts` in the update stream (`updateReadChannelInbox`), no `getDialogs` needed.

- `NovagramBotSession.swift` — `novagramInitializeBotDMReadState(isBotSession:transaction:messages:location:)`: for an incoming `CloudUser` message with no existing `.Cloud` read state, seeds `resetIncomingReadStates([peerId: [.Cloud: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false)]])`.
- `State/AccountStateManagementUtils.swift` — 1-line hook **immediately before** `_ = transaction.addMessages(messages, location: location)` (so the add's own `addIncomingMessages` increments through the normal path, and no failing `.Validate`/`getPeerDialogs` sync is queued). Only post-session-start messages count (historical unread lives only in `getDialogs`, unreachable for a bot).

**Opening a group/channel chat.** Opening a chat fills history via `messages.getHistory`; for a bot that returns `BOT_METHOD_INVALID`, the fetch errors on the first try (`Holes.swift` `maxRetries: 0`), so `transaction.removeHole(...)` never runs and the chat view stays stuck on the hole — the received "you were added" service message never renders.

- `NovagramBotSession.swift` — `novagramManagedMessageHistoryHole(accountPeerId:network:postbox:hole:direction:space:count:)`: for a bot session `transaction.removeHole(..., range: 1 ... (Int32.max - 1))`; otherwise the original `fetchMessageHistoryHole(...)`. Both `|> ignoreValues`.
- `State/ManagedMessageHistoryHoles.swift` — the `case let .peer(hole):` fetch site calls `novagramManagedMessageHistoryHole(...)` instead of `fetchMessageHistoryHole(...)`.

**Folders (chat list filters).** Rendering is 100% local, but the folder tab strip needs ≥2 tabs, the first being `.allChats` — which only arrives from the server's `getDialogFilters` (`dialogFilterDefault`), blocked for bots. So a bot-created folder yields a single-tab state and no strip appears.

- `NovagramBotSession.swift` — `novagramEnsureAllChatsForBotFilters(transaction:filters:)`: for a bot session, if `filters` is non-empty and lacks `.allChats`, prepends `.allChats`. (`normalize()` only prunes `updates`, never touches `.allChats`, so this is stable.)
- `TelegramEngine/Peers/ChatListFiltering.swift` — `_internal_updateChatListFiltersInteractively`: 1-line hook right after `f(state.filters)` (changed `let updatedFilters` → `var`).

### Logout for a bot session (2026-07-17)

"Log Out" did nothing for a bot account. Root cause: `PeerInfoScreenSettingsActions.swift` `case .logout` gated the whole action on `let phoneNumber = user.phone` — a bot has **no phone number** (`user.phone == nil`), so the `if let` failed and `logoutOptionsController` was never pushed. No `logoutFromAccount` call ever reached the core (confirmed: absent from app-logs).

- `TelegramUI/.../PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift` — dropped the `let phoneNumber = user.phone` requirement (keep only `if case let .user(user) = self.data?.peer`) and pass `phoneNumber: user.phone ?? ""` to `logoutOptionsController(...)`. The phone is only used for the "Change Number" sub-screen, so `""` is harmless; normal accounts are unchanged (`?? ""` never triggers for them).

### Multi-account back button + bot-token icon (2026-07-17)

**Add-account "Cancel"/back button was missing for bot accounts (user got trapped).** The phone-entry screen shows a Cancel button only when `!otherAccountPhoneNumbers.1.isEmpty`, but that list was built (`AppDelegate.swift` ~line 1316) by mapping each existing account to `user.phone` and dropping the ones with no phone — i.e. **all bot accounts**. So with only bot accounts logged in, adding another account showed no back button.

- `TelegramUI/Sources/AppDelegate.swift` — in the account→phone map, for a `.user` peer with no `phone` fall back to `@username`/`firstName` (`user.phone ?? user.addressName.flatMap { "@\($0)" } ?? (user.firstName ?? "Bot")`) so bot accounts are included in the list. Normal accounts unchanged (`?? ` never triggers).

**Bot-token login moved from a bottom text link to a nav-bar icon** (next to QR), per request.

- `AuthorizationSequencePhoneEntryControllerNode.swift` — the bottom `botTokenButton` is now always hidden (wide-layout `isHidden` set to `true` at ~line 673; it was `false`).
- `AuthorizationSequencePhoneEntryController.swift` — `updateNavigationItems()` full-size branch now sets `rightBarButtonItems = [qrItem, botItem]` (index 0 = rightmost, so the bot icon sits just LEFT of the QR icon). The bot icon is Telegram's own chatbot/robot glyph `UIImage(bundleImageName: "Item List/Icons/Chatbot")`, scaled 30→24pt (template) to match the QR icon. New `@objc botTokenIconPressed()` calls `self.loginWithBotToken?()` (same flow as the old bottom button).

### Bot session tab bar — only Chats + Settings (2026-07-18)

A bot can't use Contacts (no `contacts.getContacts`) or Calls, so those tabs are hidden for a bot session; only Chats + Settings remain.

- `TelegramCore/Sources/NovagramBotSession.swift` — `public func novagramIsBotSessionSignal(account:) -> Signal<Bool, NoError>`: one-shot postbox read (bot-ness never changes in a session).
- `TelegramUI/Sources/TelegramRootController.swift` — added `isBotAccount` / `currentShowCallsTab` / `botAccountDisposable`. `addRootControllers`/`updateRootControllers` skip the Contacts and Calls appends when `isBotAccount`; after the initial build, a `novagramIsBotSessionSignal` subscription sets `isBotAccount = true` and calls `updateRootControllers(...)` to collapse the tab bar (selecting Chats). Regular accounts are unaffected. (Search accessory + the other tabs are untouched.)

### Muting a peer didn't stick in a bot session (2026-07-18)

Muting a channel/user/group in a bot session had no effect — notifications kept coming. (Audited via a 6-agent Opus 4.8 workflow.) Root cause is LOCAL, not server: bots receive no APNs push (the notifications are locally generated from the live update stream). Muting writes only PENDING settings; `pushPeerNotificationSettings` (`ManagedPendingPeerNotificationSettings.swift`) then tries to sync to the server, but a bot's peer has no accessHash → `apiInputPeer` is nil → it hits a branch that **discards the pending settings without committing them to CURRENT**. `getEffective` falls back to current → the peer reverts to unmuted → notifications resume.

- `TelegramCore/Sources/NovagramBotSession.swift` — `novagramCommitPendingSettingsIfBot(transaction:peerId:settings:)`: for a bot session, `transaction.updateCurrentPeerNotificationSettings([peerId: settings])` so the mute holds. No-op for normal accounts.
- `TelegramCore/Sources/State/ManagedPendingPeerNotificationSettings.swift` — two 1-line hooks calling the helper **before** the pending-discard, on both `apiInputPeer==nil` branches: the outer else (uses `peerId`) and the inner non-thread else (uses `notificationPeerId`).

Deliberately NOT fixed in the NSE (it doesn't run for bot sessions) and NOT by fabricating access hashes (would break other peer API calls). Needs on-device confirmation that a muted bot-session peer no longer notifies.

### Known limitation (by design, manager-accepted)

- **Pre-login history is not available** — bots can't call `messages.getDialogs`/`getHistory`, so chats/messages that existed before login won't backfill. Only post-login activity appears (surfaced to the user via the entry screen's notice text).
- **Group/channel messages depend on the bot's server-side privacy mode** — a bot with BotFather privacy mode ON only receives commands/mentions/replies in groups; to see all group messages the bot owner must disable privacy mode. This is a Telegram server rule, not client-side.
- Still a **login-only** feature: no bot-specific chat UI was built.

---

## 📌 TelegramUI module

### `submodules/TelegramUI/Sources/ChatHistoryListNode.swift` (2026-06-27, reactive gate 2026-07-07)

**Hook A — top import block (after `import Postbox`, ~line 38)**. Add:

```swift
import NovagramMessenger
```

**Hook B — inside `init(...)`, the `var adMessages:` declaration block (~line 828)**. Leave the plain condition (no one-shot Bool read) and add a comment:

```swift
var adMessages: Signal<(interPostInterval: Int32?, messages: [Message], startDelay: Int32?, betweenDelay: Int32?), NoError>
// Novagram: fenix_show_ads — NovagramPro Ads toggle. The gate is applied reactively below.
if case .bubbles = mode, let adMessagesContext {
```

**Hook C — right after the `} else { adMessages = .single((nil, [], nil, nil)) }` block that finishes building the ad source (~line 921), before `let clientId = Atomic<Int32>(...)`**. Add:

```swift
        // Novagram: reactively suppress ads when the toggle is off; re-reads live on NovagramShowAdsChanged.
        adMessages = NovagramShowAdsGate.gate(empty: (nil, [], nil, nil), source: adMessages)
```

Reason: `ChatHistoryListNode.init` builds the ad source (`adMessagesContext.state`, or empty for CloudUser / non-bubbles). `NovagramShowAdsGate.gate` (in `NovagramMessenger`, file `NovagramShowAdsGate.swift`) wraps that source so it emits an empty tuple while `fenix_show_ads` is off and mirrors the real source while on. The gate is driven by `NovagramShowAdsGate.enabledSignal`, which re-reads the UserDefaults key on every `.novagramShowAdsChanged` notification — posted by `NovagramSettingsController.updateShowAds`. Result: flipping the toggle takes effect **live** in already-open chats (no reopen needed), replacing the previous one-shot init-time read. Feature #6: NovagramPro Ads Easter-egg section. The `fakeAds` experimental path is untouched. Telegram's own sponsored content CAN reach this fork (seen on a real device: a Telegram video ad in the full-screen player), so it is not safe to assume it never arrives; since 2026-10-22 it is only shown as a fallback when Novagram has no ad, and never to Premium users (see "Novagram Ads v2" below). This toggle hides both.

---

### `PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` — payment section shown view-only + redirect to Premium bot (2026-07-20)

Reverses the earlier full hide of the Settings **payment section**. The block that builds the `.payment` rows — **Telegram Premium** (`Settings_Premium` → `.premium`), **Telegram Stars** (`Settings_Stars` → `.stars`), **My TON** (`Settings_MyTon` → `.ton`), **Telegram Business** (`Settings_Business` → `.businessSetup`), **Send a Gift** (`Settings_SendGift` → `.premiumGift`) — used to be wrapped in a `/* ... */` block comment (~lines 281–338, that hide was never itself in HOOKS.md). The comment is now removed, so all five rows render again (still upstream-conditional on `isPremiumDisabled` / Stars & TON balances — unchanged).

The rows open the real Premium/Stars/Business/Gift screens **view-only**; their Subscribe/Buy/Send buttons stay blocked by the existing IAP gates (`InAppPurchaseManager.buyProduct` → `NovagramAppStoreIAP.shouldBlockIAP`, plus the bot-invoice sites). Upstream ships this block live, so a clean merge already leaves the rows visible — the merge risk here is _re-applying the old hide by mistake_, so on conflict keep the rows.

**Redirect target changed — `submodules/Novagram/AppStoreIAP/Sources/NovagramAppStoreIAP.swift`:** the blocked-purchase alert now opens `https://t.me/PremiumBot` (new constant `premiumBotURL`, falls back to `officialTelegramAppStoreURL`) instead of the App Store page, so the purchase reads as completed inside the official Telegram app. Strings `iap_block_message` and `iap_block_open_app_store` in `NovagramL10n.swift` updated to match ("Open Telegram Premium").

⚠️ **Apple 3.1.1 anti-steering:** redirecting a Subscribe button to a purchase destination (@PremiumBot) is stronger steering than the previous "download the official app" App Store link, and than the deliberately steering-free ads case above. This is a re-rejection risk — kept per explicit product decision (2026-07-20).

---

### `submodules/TelegramUI/BUILD` (2026-06-27)

In the `deps = [...]` list, append:

```python
"//submodules/Novagram/Messenger:NovagramMessenger",
```

Reason: `ApplicationContext.swift` calls `NovagramRecommendedFolders.presentFirstLaunchPromptIfNeeded` (first-launch folders prompt, Feature #19/#21). The module was already a transitive dep (via PeerInfoScreen) but is now also a direct dep of TelegramUI.

---

### `submodules/TelegramUI/Sources/ApplicationContext.swift` (2026-06-27)

**Top of file — imports block.** Add after `import NovagramUnreadReminder`:

```swift
import NovagramMessenger
```

**Inside the `AuthorizedApplicationContext` `init` (or `setupContext`) block — immediately after the `if self.rootController.rootTabController == nil { self.rootController.addRootControllers(showCallsTab: self.showCallsTab) }` block (~line 255):**

```swift
// Novagram: one-time first-launch prompt to add recommended folders (#19/#21)
NovagramRecommendedFolders.presentFirstLaunchPromptIfNeeded(context: self.context, rootController: self.rootController)
```

Reason: `NovagramRecommendedFolders` needs a `NavigationController` reference to call `.present(_:in:)` on it. `self.rootController` is a `TelegramRootController: NavigationController` and is already available at this point. The function guards on the `fenix_features_firstrun_done` UserDefaults key so it fires at most once, and delays the alert 2.5 s to avoid competing with the Tips/UpdateCheck prompt that fires at 1.0 s.

---

## 📌 Novagram Ads v2 — ad serving v2, NovagramAds SDK 3.0 (2026-10-22, SDK 3.0 migration 2026-10-23)

Our own ads (serving v2) in four Telegram surfaces plus the chat-list banner. Re-applies the hook SHAPES of the removed v1 integration (commit `5a4e334c74`) with v2 data. Backend contract: `NovagramAds/docs/NOVAGRAM_ADS_API_UZ.md` (§2.1–2.6, §3, §4, §6). Novagram ads are shown to EVERY user, Telegram Premium included; Telegram's own ads only as a fallback when ours is empty, and never for Premium users. Every surface (ours and Telegram's) is switched off by the hidden NovagramPro "Remove all ads" toggle (`NovagramShowAdsGate`; ON = `fenix_show_ads == false`). That row has no deep link.

**Product rule (every surface): Novagram ads first; Telegram's ads only as a fallback and never for Premium users.** When our backend has an ad for the slot, ours is shown and all its events (view, click, video_open, action, report) go only to our backend. Telegram's own ad for that slot is shown only when ours is empty (`ads: []`, error, or hidden locally) — through Telegram's unchanged path — and never to a Telegram Premium user. Telegram's sponsored content does reach this fork (seen: search sponsored peers, channel ads, the in-video banner), so the rule is enforced in code: `NovagramSponsored.oursFirst` (channel message, bot panel, search; pending → none/ad so Telegram's ad never flashes before ours resolves) and `NovagramVideoAdHandleImpl.resolveBanner` (video banner). Each change of the visible source is logged at debug level as `<SLOT> source=novagram|telegram|none`.

**Module:** `submodules/Novagram/Sponsored/` — target `NovagramSponsored` (module `NovagramSponsored`, `-warnings-as-errors`).

- `Frameworks/NovagramAds.xcframework` — the SDK binary (STATIC, iOS device + simulator, min iOS 15, library evolution), imported as the private target `:NovagramAdsSDK` (`apple_static_xcframework_import`). Only `NovagramSponsored` imports it, and `NovagramSponsored` is a dep of exactly three BUILD files: TelegramUI, ChatListUI, GlobalControlPanelsContext (never TelegramCore / Postbox). Like every TelegramUI dep it links statically into `TelegramUIFramework`, which some app extensions also load, but no extension code path calls it (an extension target). To update the SDK, replace the whole `.xcframework` folder with the new static build.
- `novagram_environment.bzl` — `novagram_environment_source` rule. Reads `--define=novagramAdsEnvironment` (`ctx.var`; `development` or `production`, empty = production, anything else fails the build in Starlark) and writes a small generated Swift constant (`NovagramSponsoredGeneratedEnvironment.name`). The SDK binary carries everything else it needs.
- `Sources/NovagramSponsored.swift` — core: lazily created shared `SDKClient`; one `SDKAdsSession` (started once) + one `SDKBannerFeed` per account, keyed by `context.account.peerId.id._internalGetInt64Value()`; `flush()` on `UIApplication.didEnterBackgroundNotification`; targeting (`phone_country` = ISO-2 of the account phone via `PhoneNumberFormat.lookupCountryIdByNumber` + `currentCountriesConfiguration`, else nil; `lang` = `strings.baseLanguageCode`; `platform` "ios"; app version from the bundle); served-ad registry by `random_id`; local hide set (report / bot "X") that re-filters the ad signals; `recordViewIfOurs` / `recordClickIfOurs` / `hideIfOurs` used by the hooks.
- `NovagramAdMessage.swift` — builds the sponsored `Message` (same shape as `CachedMessage.toMessage` / `fakeAds`): `AdMessageAttribute(opaqueId: "novagram:<random_id>", url: ad.url, buttonText: "View channel"/"Open bot" by `button_type` (uz/ru/en), sponsorInfo: other_info, canReport: true, hasContentMedia: photo != nil)`, text = `ad.text`, author title = `ad.displayTitle`, message id = positive non-zero FNV-1a 32-bit of `random_id` (Telegram's own sponsored message uses id 0 and the bot panel compares ids only, so a switch between theirs and ours, or a hidden ad, must change the id; the channel path replaces ids anyway), media from `ad.media`: PHOTO as `TelegramMediaImage`, VIDEO as `TelegramMediaFile` (`.Video` attribute with the server's width/height/duration so the 16:9 frame is reserved before the file arrives); both use `HttpReferenceMediaResource`, which TelegramCore's fetcher downloads whole over HTTPS into the media box, keyed by url (files are immutable); Telegram's own pipeline then shows them (muted inline autoplay for the video). Debug builds only: `NOVAGRAM_ADS_DEBUG_MEDIA=photo:<url>|video:<url>` replaces the media and `NOVAGRAM_ADS_DEBUG_CHANNEL_ID=-100…` replaces the `channel_id` sent for an eligible channel (verification fixtures; `#if DEBUG`, never in release).
- `Bridge/NovagramSponsoredBridge.swift` — second target `NovagramSponsoredBridge` (deps: Postbox, TelegramCore, AccountContext, Display only). GalleryUI and the bubble components cannot depend on `NovagramSponsored` (cycle: `NovagramSponsored → NovagramMessenger → CallListUI → InviteLinksUI → PeerInfoAvatarListNode → GalleryUI`), so they use this bridge: the `novagram:` check, server display durations, and the `NovagramAdsProvider` / `NovagramVideoAdHandle` protocols. `NovagramAdsRegistry.init` installs the implementation (`NovagramAdsBridgeProvider`) on the first use of the core, which happens at app start (the chat-list banner source).
- `NovagramVideoAds.swift` — VIDEO slot (below): per-channel playback-time schedule shared by all gallery items of a channel, plus the bridge provider.
- `NovagramAdActions.swift` — the `action` event: after a click, watches engine data for joining the promoted CHANNEL (participation status left → member; nothing when already a member at click time) or the user's own `/start` in the promoted BOT (`PostboxViewKey.topChatMessage`), within 55 min of the serve; sent once with the click's `random_id`, after the click is queued. No hooks.
- `NovagramChannelAds.swift`, `NovagramBotAds.swift`, `NovagramSearchAds.swift`, `NovagramBannerAds.swift` — the four surfaces (below). `NovagramAdMenu.swift` — About / Report (six reasons, then hide + "Thanks, your report was sent" even on failure). `NovagramSponsoredStrings.swift` — uz/ru/en strings.

**How to tell OUR ad from Telegram's:** `AdMessageAttribute.opaqueId` is UTF-8 `novagram:<random_id>` (`NovagramSponsored.isOurs(opaqueId:)`). Chat-list banners use notice ids `novagram-banner:<uuid>` (closable) / `novagram-banner-fixed:<uuid>` (no "X"). Every hook below no-ops for anything without these prefixes, so Telegram's own ads and notices behave exactly as before.

**Environment flow:** `build-system/local-secrets.sh` (gitignored, `export NOVAGRAM_ADS_ENVIRONMENT=development` for QA builds; leave it unset or empty for production) is sourced by `run.sh` / `publish.sh` / `release.sh`, which pass `--define=novagramAdsEnvironment="$NOVAGRAM_ADS_ENVIRONMENT"` **only when it is set** (`${NOVAGRAM_ADS_ENVIRONMENT:+…}`) → `novagram_environment_source` → `NovagramSponsoredGeneratedEnvironment` → `SDKEnvironment(rawValue:) ?? .production` → `SDKClient(configuration: SDKConfiguration(environment:))`. No key, no domain and no URL is part of the app's build inputs or of any tracked file.

**Advertiser photo (2026-10-23):** `promoted.avatar_url` is shown the way Telegram shows its own sponsor photo — as the sponsored message's small inline image (`message.media`, `hasContentMedia: false`) in the channel bubble and the bot panel; Telegram never draws the synthetic author's avatar on those surfaces. `NovagramAdAvatar.load` takes it only for an ad without PHOTO / VIDEO media and only for a valid https url, downloads it through `HttpReferenceMediaResource` into the media box (the download is not cancelled by the wait), and adds it only when the file arrived within 3 s and decodes as an image; otherwise the ad renders exactly as before, without a photo. The search row shows the real resolved Telegram peer with its own photo, so it is not touched. No hooks; message ids unchanged.

### `submodules/TelegramUI/Sources/ChatHistoryListNode.swift` — channel sponsored message

1. Import (after `import NovagramMessenger`, ~line 40): `import NovagramSponsored`.
2. Ad source (~line 1000), the `else` of the `fakeAds` branch, was `adMessages = adMessagesContext.state`:

```swift
} else {
    // Novagram: OUR ad first in public channels with 1000+ subscribers, else Telegram's.
    adMessages = NovagramChannelAds.adMessages(context: context, peerId: peerId, fallback: adMessagesContext.state)
}
```

`adMessages(...)` emits `(nil, [ourMessage], nil, nil)` (interPostInterval nil = one fixed ad after the last post) when the channel is a public broadcast channel (has a username) with ≥ 1000 subscribers — every channel, no exceptions (`ParticipantCount`, waits ≤ 4 s for it, unknown → no request) — and the backend has an ad for `channel_id = -(1_000_000_000_000 + peerId.id)`; otherwise `fallback` (Telegram's) unchanged — except empty for Premium users (product rule, `oursFirst`). Still wrapped by Hook C (`NovagramShowAdsGate.gate`).

3. Seen (`markAdAsSeen(opaqueId:)`, ~line 3088), inside `if !self.seenAdIds.contains(opaqueId) { … }`:

```swift
// Novagram: OUR ad counts its view on the Novagram backend; Telegram's ads go on as before.
if !NovagramSponsored.recordViewIfOurs(opaqueId: opaqueId) {
    self.adMessagesContext?.markAsSeen(opaqueId: opaqueId)
}
```

Both seen triggers funnel here (visible-range scan, and the fixed-ad trigger in `ChatControllerLoadDisplayNode.swift` `contentPositionChanged` at offset ≤ 50, i.e. the whole ad on screen). The SDK sends one `view` per `random_id`.

### `submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift` — our ad after an album post

1. Import (after `import NovagramForeignUserBlock`, ~line 16): `import NovagramSponsored`.
2. Fixed ad insertion (~line 707), was `if !entries.isEmpty, case let .MessageEntry(lastMessage, _, _, _, _, _) = entries[entries.count - 1], let message = adMessage {`:

```swift
// Novagram: OUR ad may also follow a last post that is an album (MessageGroupEntry); Telegram's ads keep the MessageEntry-only rule.
var adAnchorMessage: Message?
if case let .MessageEntry(lastMessage, _, _, _, _, _)? = entries.last {
    adAnchorMessage = lastMessage
} else if case let .MessageGroupEntry(_, groupMessages, _)? = entries.last, let adAttribute = adMessage?.adAttribute, NovagramSponsored.isOurs(opaqueId: adAttribute.opaqueId) {
    adAnchorMessage = groupMessages.last?.0
}
if let lastMessage = adAnchorMessage, let message = adMessage {
```

Root cause of "served but not rendered" (2026-10-22, `@Novagramtg`): the channel's last post was a 3-photo album, so the last history entry was `.MessageGroupEntry` and the upstream check (MessageEntry only) never appended the fixed ad. Not related to opening via `post=`.

### `submodules/TelegramUI/Sources/ChatController.swift` — click + bot-panel menu

1. Import (after `import NovagramLocalization`, ~line 150): `import NovagramSponsored`.
1b. `openMessage` for an ad message with a video file (~line 1498), was a bare `markAction(..., media: true, ...)`:

```swift
// Novagram: OUR ad's video opening full screen is a Novagram video_open, never Telegram's markAction.
if !NovagramSponsored.recordVideoOpenIfOurs(opaqueId: adAttribute.opaqueId) {
    self.chatDisplayNode.adMessagesContext?.markAction(opaqueId: adAttribute.opaqueId, media: true, fullscreen: false)
}
```

The gallery then opens as before; a tap on the full-screen ad video goes `performAction(.ad)` → `openAd` → `activateAdAction` → our click (contract §3.3: video_open, then click).

2. `openUrl` interaction (~line 3446), a link tap inside an ad message (photo ads auto-link urls). Inside the existing `if let message, let adAttribute = … AdMessageAttribute {`, before its `markAction(...)` line:

```swift
// Novagram: a link tap inside OUR ad is a Novagram click (queued, then the link opens); never sent to Telegram.
let skipAlert = skipConcealedAlert
if NovagramSponsored.recordClickIfOurs(opaqueId: adAttribute.opaqueId, thenOpen: { [weak strongSelf] in
    guard let strongSelf else {
        return
    }
    if let performOpenURL = strongSelf.performOpenURL {
        performOpenURL(message, url, progress)
    } else {
        strongSelf.openUrl(url, concealed: concealed, forceExternal: forceExternal, skipConcealedAlert: skipAlert, message: message, allowInlineWebpageResolution: urlData.allowInlineWebpageResolution, progress: progress)
    }
}) {
    return
}
```

The closure repeats the two open calls that follow the `if` block (same arguments), so our link opens exactly like any other, only after the click is queued. Without this hook `markAction` would send our `novagram:<token>` to Telegram's server. `skipAlert` is a `let` copy so the escaping closure captures no mutable local (see CLAUDE.md, Swift 6.4 capture bug).

3. `activateAdAction` (~line 5145), before the existing `markAction(...)` + `openUrl(...)` lines (both unchanged):

```swift
// Novagram: OUR ad queues its Novagram click first, then opens the url (contract §4.4); Telegram's ads go on as before.
let adProgress = progress
if NovagramSponsored.recordClickIfOurs(opaqueId: adAttribute.opaqueId, thenOpen: { [weak self] in self?.controllerInteraction?.openUrl(ChatControllerInteraction.OpenUrl(url: adAttribute.url, concealed: false, external: true, progress: adProgress)) }) {
    return
}
```

`recordClickIfOurs(opaqueId:thenOpen:)` awaits `session.recordClick` (it only writes the event to the on-disk queue, a few ms; the request goes later) and then runs `thenOpen` on the main queue. For Telegram's ads it returns false and does not call `thenOpen`. This covers the channel bubble (button, title, avatar, media) AND the bot panel tap (it also calls `activateAdAction`). `adProgress` is a `let` copy of the `var progress` (same Swift 6.4 reason).

4. `adContextAction` (~line 5155), right after `guard let self`:

```swift
// Novagram: OUR ad (bot panel) gets the Novagram About / Report sheet instead of Telegram's screen.
if let adAttribute = message.adAttribute, NovagramAdMenu.presentIfOurs(opaqueId: adAttribute.opaqueId, context: self.context, present: { [weak self] c in self?.present(c, in: .window(.root)) }) {
    return
}
```

### `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` — channel ad menu

1. Import (after `import NovagramLocalization`, ~line 42): `import NovagramSponsored`.
2. First statement inside `if messages.count == 1, let adAttribute = messages[0].adAttribute {` (~line 531):

```swift
// Novagram: OUR Novagram ad gets its own menu (About / Report, no Premium "Hide" / "Remove").
if let items = NovagramAdMenu.contextMenuItems(opaqueId: adAttribute.opaqueId, context: context, present: { [weak controllerInteraction] c in controllerInteraction?.presentController(c, nil) }) {
    return .single(ContextController.Items(content: .list(items)))
}
```

Replaces the v1 `isNovagramAd` gate on `SponsoredMessageMenu_Hide`: our ad (canReport: true) would otherwise get Telegram's About screen, Telegram's report flow and the Premium "Remove ad" upsell.

### `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift` — no "X" on our channel ad

No import, no BUILD change (inline prefix check). Contract §3.7: nobody gets an "X" on channel ads.

1. ~line 1994, was `if isAd { needsShareButton = true }` (the side button of an ad is the close "X" → `openNoAdsDemo`):

```swift
let isAd = item.content.firstMessage.adAttribute != nil
// Novagram: OUR Novagram ad (opaqueId "novagram:…") has no close "X" — nobody can hide channel ads.
let isNovagramAd = (item.content.firstMessage.adAttribute.flatMap { String(data: $0.opaqueId, encoding: .utf8) } ?? "").hasPrefix("novagram:")
if isAd && !isNovagramAd {
    needsShareButton = true
} else if isNovagramAd {
    // The ad belongs to a broadcast channel, so the branches above turned the side pill on;
    // for an ad that pill is the close "X". Menu stays on long-press / "what's this?".
    needsShareButton = false
}
```

The `else if` matters: an ad message's `peerId` is the broadcast channel, so the generic channel-post branches above already set `needsShareButton = true`; without forcing it off, the side pill (close "X" + "…") still appeared on our ad (seen in QA 2026-10-22). About / Report remain on long-press and the "what's this?" badge.

2. ~line 4544, the in-bubble close button, was `if let _ = item.message.adAttribute {`:

```swift
// Novagram: no in-bubble close "X" on OUR Novagram ad (opaqueId "novagram:…").
if let adAttribute = item.message.adAttribute, !(String(data: adAttribute.opaqueId, encoding: .utf8) ?? "").hasPrefix("novagram:") {
```

### `submodules/TelegramUI/Sources/ChatControllerContentData.swift` — bot panel source

1. Import (after `import NovagramPremiumUnlock`, ~line 19): `import NovagramSponsored`.
2. ~line 697, was `adMessage = adMessagesContext.state |> map { $0.messages.first }`:

```swift
// Novagram: OUR bot ad first in the bot panel, else Telegram's (unchanged).
adMessage = NovagramBotAds.panelMessage(context: context, peerId: adMessagesContext.peerId, fallback: adMessagesContext.state |> map { $0.messages.first })
```

Requests `.bot(username:)` only for bot users with a username; non-bot chats get Telegram's value untouched (the panel is drawn for bots only). For bots: Telegram's ad only as a fallback, never for Premium users (`oursFirst`). Our message has its own id (see `NovagramAdMessage`), so the `adMessage?.id` comparison in this file (~line 768) re-renders the panel when ours replaces Telegram's or is hidden by its "X". The panel itself is still drawn by Telegram's rule in `ChatControllerNode` (bot chat, history loaded, ≥ 3 messages, bot not blocked).

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` — bot panel view + "X"

1. Import (after `import NovagramLocalization`, ~line 79): `import NovagramSponsored`.
2. First line inside `if displayAdPanel, let adMessage = self.chatPresentationInterfaceState.adMessage {` (~line 1583):

```swift
// Novagram: the panel shows OUR ad's whole text now, so it counts as a view (once per random_id).
if let adAttribute = adMessage.adAttribute { NovagramSponsored.recordViewIfOurs(opaqueId: adAttribute.opaqueId) }
```

3. Panel `close:` closure (~line 1611), after its `guard let self, let adMessage …`:

```swift
// Novagram: OUR bot ad's "X" just hides it locally for this random_id (no Premium upsell).
if let adAttribute = adMessage.adAttribute, NovagramSponsored.hideIfOurs(opaqueId: adAttribute.opaqueId) {
    return
}
```

Contract §3.2: the "X" sends nothing to the server.

### `submodules/ChatListUI/Sources/ChatListSearchListPaneNode.swift` — search sponsored row

Same shape as the v1 `.novagramAdPeer` hooks, but the row now sits where the contract wants it (§3.1): after "my results" (local peers), before Telegram's own sponsored row and the global results, under the "Global search" header.

1. Import (after `import FetchManagerImpl`): `import NovagramSponsored`.
2. `ChatListSearchEntryStableId`: `case novagramAdPeerId(EnginePeer.Id)`.
3. `ChatListSearchEntry`: `case novagramAdPeer(EnginePeer, String, Int, PresentationTheme, PresentationStrings, ChatListSearchSectionExpandType, String?)` (peer, random_id token, index, theme, strings, global expand type, query) — handled in `stableId`, `==`, `<` (lhs case after `.localPeer`, before `.adPeer`; added to `.localPeer`'s `return true` group and to `.adPeer` / `.globalPeer`'s `return false` groups) and `item(...)`: `ContactsPeerItem` with `isAd: true` (Telegram's localized "Ad" pill + menu button), header `.globalPeers`, tap → `NovagramSearchAds.recordClick(token:thenOpen:)` whose `thenOpen` calls `interaction.peerSelected` (the click is queued first, contract §4.4), ad button → `NovagramSearchAds.presentMenu` (About / Report, presented with `interaction.present`), `visibilityUpdated` → `NovagramSearchAds.recordView`.
4. `foundRemotePeers` tuple widened to `(…, Bool, NovagramPromotedPeer?)`; in the `.chats` branch (~line 2758) the result of `searchAdPeers(query:)` goes through `NovagramSearchAds.adPeers(context:query:telegramAdPeers:)` (product rule: OUR promoted peer after the ~0.5 s debounce for normalized queries of 3–32 characters, resolved with `resolvePeerByName`; Telegram's ad peers only when ours is empty, never for Premium; ([], nil) at once so results never wait). Every other branch passes `nil`. Fixes "two ads in search" (ours + Telegram's `@novas`).
5. Entry insert right before `if !adsHidden { for peer in foundRemotePeers.2 {`: `.novagramAdPeer(...)` when `foundRemotePeers.4` is set, not already listed (`existingPeerIds`) and passes `filteredPeer`. Not gated by `adsHidden` (ads for everyone).

### `submodules/TelegramUI/Components/GlobalControlPanelsContext/Sources/GlobalControlPanelsContext.swift` — banner producer + dismiss

1. Import (after `import UndoUI`, ~line 11): `import NovagramSponsored`.
2. `suggestedChatListNoticeSignal` (~line 353): `NovagramBannerAds.bannerNotice(context: context)` appended as the last `combineLatest` input and `bannerNotice` as the last closure parameter. In the `mapToSignal` body, right AFTER Telegram's security notices (`.reviewLogin`, `.reviewBotConnection`, `.setupPassword` — the `if suggestions.contains(.setupPassword) …` block) and before the birthday / freeze / promotional ladder (~line 377):

```swift
// Novagram: OUR Novagram banner — after Telegram's security notices, above the promotional ones; never while frozen.
if let bannerNotice, accountFreezeConfiguration.freezeUntilDate == nil {
    return .single(.link(id: bannerNotice.id, url: bannerNotice.url, title: ServerSuggestionInfo.Item.Text(string: bannerNotice.title, entities: []), subtitle: ServerSuggestionInfo.Item.Text(string: bannerNotice.text, entities: [])))
}
```

Order matters: a non-closable Novagram banner must never hide a new-session / bot-connection review, the password setup prompt or the account-freeze notice (while frozen our banner is skipped, so `.accountFreeze` below shows). `bannerNotice(context:)` emits nil first (the `combineLatest` never waits for our network call), refreshes the account's `SDKBannerFeed` on subscribe and on `willEnterForeground` (the feed throttles to 15 min), shows the first live banner this account has not closed in this run, reloads when that banner's `ends_at` passes (timer replaced on every reload), and is gated by `NovagramShowAdsGate`. The mapping to `.link` lives on this side so `NovagramSponsored` needs no GlobalControlPanelsContext dep (no cycle).

3. Slot gate (while "Remove all ads" is ON the slot holds NO promo, no Telegram server suggestion and no Novagram banner; only security notices stay). The `suggestedChatListNoticeDisposable` source is wrapped:

```swift
// Novagram: "Remove all ads" ON empties the slot (Telegram's promos and our banner), security notices stay.
self.suggestedChatListNoticeDisposable = (NovagramSponsored.gatedNotice(suggestedChatListNoticeSignal, isSecurity: { $0.isNovagramSecurityNotice })
|> deliverOn(self.queue))
```

and `ChatListNotice` gets `var isNovagramSecurityNotice: Bool` (true for `.reviewLogin`, `.reviewBotConnection`, `.setupPassword`, `.accountFreeze`; everything else is a promo/suggestion). Security notices are first in the ladder (the freeze notice precedes every promo), so filtering the final value is exact: a promo can never hide a security notice. `NovagramSponsored.gatedNotice` (`NovagramSponsored.swift`) re-reads the toggle live (`NovagramShowAdsGate.enabledSignal`), so flipping it applies at once; with ads ON nothing changes. This is the only producer of the chat-list notice slot (`ChatListNoticeItem` / `ChatListControllerNode` only render it). macOS equivalent: `NovagramBannerAds.suggestions` returns `[]` while the gate is off.

4. `dismissChatListNotice`, `case let .link(id, _, _, _):` (~line 666):

```swift
// Novagram: closing OUR banner goes to the Novagram backend, not Telegram's suggestions.
if !NovagramBannerAds.dismissIfOurs(noticeId: id, context: self.context) {
    _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: id).startStandalone()
}
```

`dismissIfOurs` hides the banner at once, then `feed.dismiss` (persisted, retried later when offline).

### `submodules/ChatListUI/Sources/ChatListControllerNode.swift` — banner tap

1. Import (after `import GlassControls`, ~line 32): `import NovagramSponsored`.
2. Notice tap switch (~line 1485), was `case let .link(_, url, _, _): …openUrl(url)`:

```swift
case let .link(id, url, _, _):
    // Novagram: OUR banner counts the click and opens only when tappable; Telegram's links unchanged.
    if let url = NovagramBannerAds.urlForTap(noticeId: id, url: url, context: self.context) {
        self.effectiveContainerNode.currentItemNode.interaction?.openUrl(url)
    }
```

`urlForTap` returns `url` unchanged for Telegram's notices; for ours it fires `feed.click` in the background and returns the link, or nil for a banner with an empty / non-https/tg link.

### `submodules/TelegramUI/Components/ChatList/ChatListHeaderNoticeComponent/Sources/ChatListNoticeItem.swift` — non-closable banner

No import (inline prefix check). ~line 452, `.link` split out of the `hasCloseButton = true` group:

```swift
case let .link(id, _, _, _):
    // Novagram: a non-closable Novagram banner has no "X" (id "novagram-banner-fixed:…").
    hasCloseButton = !id.hasPrefix("novagram-banner-fixed:")
```

Contract §2.4: `dismissible: false` → no "X".

### `submodules/TelegramUI/Components/Chat/ChatMessageWebpageBubbleContentNode/Sources/ChatMessageWebpageBubbleContentNode.swift` — "what's this?" on our ad

1. Import (after `import ChatControllerInteraction`, ~line 22): `import NovagramSponsoredBridge`.
2. `activateBadgeAction` (~line 116), first lines inside `if let strongSelf = self, let item = strongSelf.item {`:

```swift
// Novagram: OUR ad's "what's this?" opens the Novagram About / Report sheet, not Telegram's screen.
if NovagramSponsoredBridge.isOurs(item.message) { item.controllerInteraction.adContextAction(item.message, strongSelf.contentNode, nil); return }
```

BUILD: `//submodules/Novagram/Sponsored:NovagramSponsoredBridge` added to this component's deps.

Tap targets of OUR channel bubble (checked on the prod-account simulator, 2026-10-22): button and text/title area → `activateAdAction` → one click (accepted); PHOTO media → `openMessage` → `activateAdAction` → click; VIDEO media → video_open (hook 1b above) then full-screen tap → click; text links → click (`openUrl` hook); "what's this?" → our About / Report (not a click). There is no name header or avatar on ad bubbles in channels.

### `submodules/GalleryUI/Sources/Items/UniversalVideoGalleryItem.swift` — VIDEO slot (banner in the full-screen player)

Telegram's own video-ad schedule here is WALL-CLOCK (`CFAbsoluteTimeGetCurrent()` + start/between delays, a 0.5 s timer). OUR schedule runs on PLAYBACK time in `NovagramVideoChannelState` (accumulated only while the item reports playing): request `.video(channelId:messageId:)` when a channel video first plays (same channel eligibility as the channel slot); first banner after `start_delay`; auto-hide after `max_display_duration`; close allowed after `min_display_duration`; next due `between_delay` later via `session.nextVideoAd` (cache bypass); `ads: []` → no banner, retried `between_delay` later. All four values come from the response (`SDKAdVideoTimers.fallback` only when a degraded response omits them). The state is per (account, channel), shared by every gallery item of the channel, so a neighbouring video neither requests again nor resets the timers. The countdown component gets a playback-based origin (`now − playback elapsed`) so it stands still while paused.

1. Import (~line 42): `import NovagramSponsoredBridge`.
2. Overlay property (~line 235): `var novagramVideoAd: NovagramVideoAdHandle?`.
3. `setMessage` (~line 254), after `self.message = message`: `self.novagramVideoAd = NovagramSponsoredBridge.provider?.videoAdHandle(context:message:onUpdate:)` (onUpdate re-runs `updateLayout` with `validLayout`).
4. `updateLayout` (~line 354), right after Telegram's `for (time, maybeMessage) in self.adSchedule` loop: `if let novagramVideoAd = self.novagramVideoAd { currentAd = novagramVideoAd.resolveBanner(telegram: currentAd) }` — ours wins; Telegram's only when ours has none (no request in flight, no ad this session), the toggle is on and the user is not Premium.
5. Seen (~line 361): `markAdAsSeen` only when `self.novagramVideoAd?.recordViewIfOurs(adMessage) != true`.
6. Close control `action:` (~line 389): `if let novagramVideoAd = self.novagramVideoAd, novagramVideoAd.closeIfOurs(adMessage, available: available) { return }` — before `min_display_duration` the X is inactive; `presentPremiumDemo` never runs for ours.
7. Banner tap `adAction:` (~line 403): `clickIfOurs(adMessage, open:)` queues our click, hides the banner, then opens the url through `performAction(.url(...))`; `markAdAction` never sees our opaqueId.
8. Item status observer (~line 1828), after `strongSelf.hasStartedOnce = hasStarted`: `strongSelf.overlayContentNode.novagramVideoAd?.setPlaying(isPlaying)`.
9. `openMoreMenu` (~line 3348): our ad gets the Novagram About / Report sheet (`presentMenuIfOurs`) instead of `adMenuMainItems` (no Premium "Remove ads").

### `submodules/GalleryUI/Sources/Items/VideoAdComponent.swift` — server display durations

1. Import (~line 16): `import NovagramSponsoredBridge`.
2. ~line 234, the countdown's hardcoded `minDisplayDuration: 10, maxDisplayDuration: 30` become `novagramDurations?.min ?? 10` / `novagramDurations?.max ?? 30` with `let novagramDurations = NovagramSponsoredBridge.displayDurations(component.message._asMessage())` — nil (Telegram's values unchanged) for Telegram's ads.

BUILD: `//submodules/GalleryUI/BUILD` gains `"//submodules/Novagram/Sponsored:NovagramSponsoredBridge"`.

### Build scripts — `run.sh` (~line 492), `publish.sh` (~line 240), `release.sh` (~lines 306 + 327)

Next to the other `--define`s:

```sh
    `# ads environment (development | production) from build-system/local-secrets.sh; passed only when set, else production` \
    ${NOVAGRAM_ADS_ENVIRONMENT:+"--define=novagramAdsEnvironment=$NOVAGRAM_ADS_ENVIRONMENT"} \
```

`release.sh` did not source `local-secrets.sh` before; it now does (after the "Resurs" line) and warns when `NOVAGRAM_ADS_ENVIRONMENT` is empty (the build then uses production). Its other behaviour is unchanged.

### BUILD dependency additions

- `//submodules/TelegramUI/BUILD` — `"//submodules/Novagram/Sponsored:NovagramSponsored"` (before ForwardEdit).
- `//submodules/ChatListUI/BUILD` — same dep (after ForeignUserBlock).
- `//submodules/TelegramUI/Components/GlobalControlPanelsContext/BUILD` — same dep (last).
- `//submodules/GalleryUI/BUILD` and `//submodules/TelegramUI/Components/Chat/ChatMessageWebpageBubbleContentNode/BUILD` — `"//submodules/Novagram/Sponsored:NovagramSponsoredBridge"` (the bridge only; these sit below `NovagramSponsored` in the graph).

**Follow-ups (not built yet):** `avatar_url` images (search row, bot panel, bubble, video banner).

---

## 🔄 Pull conflict workflow (manual, AI-assisted)

`main` has no Telegram history: Telegram's code comes in as snapshot commits (see "Upstream 13.1.1 merge and the short
history"). One command does an update, about once a week:

```sh
submodules/Novagram/scripts/novagram-upstream-update.sh --check   # what upstream has and a trial merge, changes nothing
submodules/Novagram/scripts/novagram-upstream-update.sh           # snapshot, feature/upstream-<date>, merge, hook check, ./run.sh
```

1. On a conflict it stops (exit 2) and lists each file with its number of `// Novagram` lines. For each one, **do
   NOT auto-resolve**: find its hook block in this file and re-apply the hook on upstream's code (upstream wins for
   everything else). Hunks where our side differs only by the old formatter noise take upstream's side.
2. `git add` the files, `git commit`, then `submodules/Novagram/scripts/novagram-upstream-update.sh --finish`.
3. `--finish` updates the submodules upstream moved, compares the `// Novagram` lines per file with main's, runs
   `verify-hooks.sh` and builds. A hook ported on purpose (its upstream file was deleted) is passed with
   `NOVAGRAM_HOOKS_REVIEWED=1`. Unmarked hooks are not counted: check that every line we added to a conflicted file is
   still there (or ported).
4. Check the app on screen (the script lists the hook files upstream changed), then
   `git switch main && git merge --ff-only <branch> && git push origin main && git branch -d <branch>`. No force-push.
5. Document every ported hook here, in the same commit.

**Never** merge upstream changes without re-applying hooks. If a hook is silently dropped, the consequence is silent feature-breakage (demo auto-fill stops, custom Settings panel disappears, intro screen reverts to blue, etc.).

---

## 🧱 Adding a new hook

When you must touch a Telegram-owned file for a new Novagram feature:

1. Put 100% of the logic into `submodules/Novagram/<Feature>/`
2. Keep the Telegram-side hook to 1–3 lines: an import + a single function call OR a tiny accessor method
   (`let (text, entities) = NovagramOutgoingText.apply(...)`, `content: .image(NovagramHeaderIcons.ghostMode(isActive:))`)
3. Never reformat the lines around the hook: change only the lines the hook needs (see "Thin hooks and the formatter")
4. **Append a new section to this file** documenting the exact hook code and reason
5. Commit the HOOKS.md update in the same commit as the hook itself

If a hook grows beyond ~3 lines, refactor: move state into a Novagram module and expose a single delegate-style call site.
When you work on an existing fat hook (the backlog below), thin it in the same change.

---

## 📌 DeviceAccess module — Apple App Review 5.1.2 contacts consent

### `submodules/DeviceAccess/BUILD`

In the `deps = [...]` list, append:

```python
"//submodules/Novagram/ContactsConsent:NovagramContactsConsent",
```

Reason: `DeviceAccess.swift` calls `NovagramContactsConsent.gate(...)` inside `case .contacts:` to show our in-app consent dialog before iOS's permission alert.

---

### `submodules/DeviceAccess/Sources/DeviceAccess.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import NovagramContactsConsent
```

**Inside `authorizeAccess(to:...)` — wrap the entire `case .contacts:` body** (currently around lines 519–544). Find:

```swift
                case .contacts:
                    let _ = (self.contactsPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { value in
                        if let value = value {
                            completion(value)
                        } else {
                            switch CNContactStore.authorizationStatus(for: .contacts) {
                                case .notDetermined:
                                    let store = CNContactStore()
                                    store.requestAccess(for: .contacts, completionHandler: { authorized, _ in
                                        self.contactsPromise.set(.single(authorized))
                                        completion(authorized)
                                    })
                                case .authorized:
                                    self.contactsPromise.set(.single(true))
                                    completion(true)
                                case .limited:
                                    self.contactsPromise.set(.single(true))
                                    completion(true)
                                default:
                                    self.contactsPromise.set(.single(false))
                                    completion(false)
                            }
                        }
                    })
```

Replace with:

```swift
                case .contacts:
                    // Novagram hook: Apple App Review 5.1.2 (Privacy — Data Use and Sharing).
                    // Show explicit server-upload consent dialog BEFORE iOS permission alert.
                    // NSContactsUsageDescription alone was rejected (submission d5a06920..., 2026-05-16).
                    NovagramContactsConsent.gate(completion: completion) {
                        let _ = (self.contactsPromise.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { value in
                            if let value = value {
                                completion(value)
                            } else {
                                switch CNContactStore.authorizationStatus(for: .contacts) {
                                    case .notDetermined:
                                        let store = CNContactStore()
                                        store.requestAccess(for: .contacts, completionHandler: { authorized, _ in
                                            self.contactsPromise.set(.single(authorized))
                                            completion(authorized)
                                        })
                                    case .authorized:
                                        self.contactsPromise.set(.single(true))
                                        completion(true)
                                    case .limited:
                                        self.contactsPromise.set(.single(true))
                                        completion(true)
                                    default:
                                        self.contactsPromise.set(.single(false))
                                        completion(false)
                                }
                            }
                        })
                    }
```

Reason: **Apple App Store rejection 2026-05-16, submission `d5a06920-6b5f-4167-b7fb-46c80b156aa8`, Guideline 5.1.2** — Apple rejected the app for uploading contacts to a server without an explicit in-app consent dialog. `NSContactsUsageDescription` (Info.plist) alone is iOS's _system_ permission text; Apple wants a separate Novagram-branded dialog that names server upload and links to the Privacy Policy BEFORE iOS shows its own alert.

`DeviceAccess.authorizeAccess(to: .contacts, ...)` is the single chokepoint that all contacts-permission requests flow through (onboarding `ApplicationContext.swift`, `ContactsController.swift` "Find Friends" tab, `ComposeController.swift`, `OpenAddContact.swift`, `SuppressContactsWarning.swift`, `TelegramPermissionsUI/PermissionController.swift`, `ContactListNode.swift`). Wrapping at this one spot covers every call site automatically.

`NovagramContactsConsent.gate(completion:perform:)` is idempotent — it caches consent in `UserDefaults` (`Fenixuz.ContactsConsent.v1`) and silently treats users with pre-existing iOS contacts permission as already-consented (upgrade path, no nag dialog after app update). The actual upload (`ContactSyncManager` → `contacts.importContacts` API) cannot start unless iOS contacts access is granted, so blocking this single function blocks the upload.

---

## 📌 RMIntro module — simulator logo + intro layout

### `submodules/RMIntro/Sources/platform/ios/RMIntroViewController.m`

**1. `loadGL` early-return for ARM64 simulator + logo creation BEFORE the return.** GLKit is not supported on ARM64 iOS simulators (only on real devices / x86_64 sims). Without this block, the simulator crashes inside `[EAGLContext initWithAPI:]`. We also create `_novagramLogoView` here (plain UIImageView, no OpenGL needed) so the intro screen still shows the Novagram logo in the simulator.

Look for the start of `- (void)loadGL` and ensure this block sits at the very top of the method:

```objc
- (void)loadGL
{
#if TARGET_OS_SIMULATOR && defined(__aarch64__)
    // Novagram fork: simulator (ARM64) GLKit'ni qo'llab-quvvatlamaydi — OpenGL
    // animatsiya'ni o'tkazib yuboramiz, lekin Novagram logo'ni baribir
    // qo'shamiz (plain UIImageView, OpenGL kerak emas). Aks holda
    // simulator'da intro screen bo'sh ko'rinadi (real device'da OK).
    if (!_novagramLogoView) {
        CGFloat size = 200;
        int height = 50;
        _novagramLogoView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - size / 2, height, size, size)];
        _novagramLogoView.image = [UIImage imageNamed:@"novagram_logo"];
        _novagramLogoView.contentMode = UIViewContentModeScaleAspectFit;
        _novagramLogoView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _novagramLogoView.userInteractionEnabled = NO;
        [self.view addSubview:_novagramLogoView];
    }
    return;
#endif
    // ... rest of original loadGL body (EAGLContext + GLKView setup)
```

**2. `updateLayout` guard for nil `_glkView` on simulator.** The original code does `_novagramLogoView.frame = _glkView.frame;` unconditionally. On simulator, `_glkView` is never created (we early-return in `loadGL`), so this collapses the logo to `CGRectZero`. Plus the wrapper UIScrollView covers it. Replace the single assignment with this branch:

```objc
_glkView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
if (_glkView != nil) {
    _novagramLogoView.frame = _glkView.frame;
} else {
    // Novagram fork: simulator path — _glkView never created (GLKit unsupported
    // on ARM64 simulator). Position the logo where the GL sphere would be.
    CGFloat logoSize = 200.0f;
    _novagramLogoView.frame = CGRectMake(
        floor((self.view.bounds.size.width - logoSize) / 2.0f),
        glViewY - statusBarHeight,
        logoSize,
        logoSize
    );
    [self.view bringSubviewToFront:_novagramLogoView];
}
```

Reason: the simulator path is Novagram-specific (upstream Telegram doesn't care because they build for x86_64 sims which have GLKit). Without this hook, the Novagram logo is invisible on every Apple-Silicon simulator demo build.

---

## 📌 sqlcipher module — Xcode 26.5 SDK compatibility

### `submodules/sqlcipher/BUILD`

**Exclude `sqlite3ext.h` from public headers.** Apple updated `iPhoneSimulator26.5.sdk/usr/include/sqlite3ext.h` to SQLite 3.50+ (added 15+ fields to `struct sqlite3_api_routines`: `txn_state`, `changes64`, `total_changes64`, `autovacuum_pages`, `error_offset`, `vtab_rhs_value`, `vtab_distinct`, `vtab_in`, `vtab_in_first`, `vtab_in_next`, `deserialize`, `serialize`, `db_name`, `value_encoding`, `is_interrupted`, `stmt_explain`, `get_clientdata`, `set_clientdata`, ...). Sqlcipher's vendored `sqlite3ext.h` is ~3.36 era and doesn't have these fields. Clang Modules verifier rejects the build with: _"`sqlite3_api_routines::X` from module `SQLite3.Ext` is not present in definition of `struct sqlite3_api_routines` in module `sqlcipher`."_

Patch:

```python
# Xcode 26.5 SDK fix: sqlite3ext.h ni PUBLIC HEADER'dan chiqaramiz.
public_headers = glob([
    "PublicHeaders/**/*.h",
], exclude = ["PublicHeaders/**/sqlite3ext.h"])

private_headers = glob([
    "PublicHeaders/**/sqlite3ext.h",
])

objc_library(
    name = "sqlcipher",
    ...
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ], exclude = public_headers + private_headers, allow_empty=True) + private_headers,
    hdrs = public_headers,
    ...
)
```

Reason: sqlcipher's amalgamated `.c` files inline `sqlite3ext.h` content with `SQLITE_CORE=1` (the public-API redefinition is disabled), so its internal compilation does not need `sqlite3ext.h` as a public header. External consumers (TelegramCore, etc.) only use `sqlite3.h` and `sqlite3session.h`. Therefore `sqlite3ext.h` can be moved to internal-only without breaking anything, and the module conflict disappears.

This hook becomes obsolete the day sqlcipher upstream merges SQLite 3.50+ — at that point the vendored `sqlite3ext.h` will match Apple's again. Until then this exclude must persist across upstream pulls.

---

## 📌 App Store IAP gate (Apple guideline 3.1.1) — May 2026 rejection fix

Apple Submission ID `d5a06920-6b5f-4167-b7fb-46c80b156aa8` (iPad Air 11", reviewed 2026-05-18) rejected the app under 3.1.1 because the reviewer reached `BotCheckoutController` from `@PremiumBot` and could pay 269 990 UZS for an Annual Premium Subscription — i.e. a digital subscription via card, bypassing IAP. The Novagram fork cannot allow that path on App Store builds. We do not implement IAP for Premium ourselves (Telegram's server does not honour IAP receipts from non-official clients), so we block the fiat-card flow and direct the reviewer to the official Telegram app instead.

Detection rule lives in `NovagramAppStoreIAP.shouldBlock(currency:hasSubscriptionPeriod:)`:

- `invoice.currency != "XTR"` (Stars stay allowed — Apple already approved them under IAP)
- `invoice.subscriptionPeriod != nil` (only recurring fiat subscriptions are blocked; one-off bot payments for physical goods continue to work)

The gate is intentionally **build-independent** (no `isAppStoreBuild` check). Reason: Telegram's server never credits Premium for non-official clients regardless of build flavour, and registering StoreKit products for `uz.fenixuz.app` would be theatre — the receipt would still fail server-side. Running the gate in dev/simulator also lets us verify the behaviour without flipping a build flag. The `isAppStoreBuild` static stays on `NovagramAppStoreIAP` purely as a logging hint set in `AppDelegate.swift`.

UI: localized `UIAlertController` with two actions — `Open App Store` (deep-links to `itms-apps://apps.apple.com/app/id686449807`, the official Telegram listing) and `Cancel`. Strings live in `submodules/Novagram/Localization/Sources/NovagramL10n.swift` under the `iap_block_*` keys (en/uz/ru).

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list of `swift_library(name = "TelegramUI", ...)`, alongside the other Novagram deps, append:

```python
"//submodules/Novagram/AppStoreIAP:NovagramAppStoreIAP",
```

Reason: `TelegramUI` consumes `NovagramAppStoreIAP` from three call sites (AppDelegate, ChatController, OpenResolvedUrl) — Bazel needs the dep explicitly.

---

### `submodules/TelegramUI/Sources/AppDelegate.swift`

**Imports — append after `import ContextControllerImpl`:**

```swift
import NovagramAppStoreIAP
```

**Right after `GlobalExperimentalSettings.isAppStoreBuild = buildConfig.isAppStoreBuild` (around line 776), insert:**

```swift
// Novagram: Apple 3.1.1 IAP gate uses this flag to decide whether to block @PremiumBot card checkout.
NovagramAppStoreIAP.isAppStoreBuild = buildConfig.isAppStoreBuild
```

Reason: the Novagram module cannot import `BuildConfig`/`GlobalExperimentalSettings` without dragging in TelegramUI's whole graph, so we mirror the flag here once at launch.

---

### `submodules/TelegramUI/Sources/DeviceContactDataManager.swift`

**Inside `DeviceContactDataManagerImpl.init(queue:accountManager:)` (around line 511), insert TWO LINES immediately after `self.accountManager = accountManager` and BEFORE `self.accessDisposable = (DeviceAccess.authorizationStatus(...)`:**

```swift
// Novagram: unblock the contacts-signal subscribers at init regardless of
// iOS permission state, so chat-detail rendering and other downstream UI
// never deadlock when permission is `.notDetermined`, `.denied`,
// `.limited`, or `.restricted`. Two init-time defaults:
//   1. personNameDisplayOrder ValuePromise (otherwise upstream only sets
//      it inside the `.allowed` branch, leaving subscribers stalled).
//   2. accessInitialized flag (otherwise `basicData(updated:)` and
//      `importable(updated:)` skip the immediate callback for new
//      subscribers when permission stays in `.notDetermined`).
// The accessDisposable below still overrides these with real device
// data when permission becomes `.allowed`. Apple Review §5.1.1
// compliance: messaging must work without granting contacts (a
// non-essential permission).
self.personNameDisplayOrder.set(.firstLast)
self.accessInitialized = true
```

Reason: **2026-05-19 — chat-tap regression root-cause fix.** Empirically verified across all four contacts authorization states (`.notDetermined`, `.denied`, `.limited`, `.authorized`): chat detail rendering only succeeded when status was `.authorized`. Two upstream behaviors gate downstream consumers on permission state:

1. The `personNameDisplayOrder` `ValuePromise` only fires inside the `.allowed` branch (line ~535), so `combineLatest(... personNameDisplayOrder.get() ...)` or `personNameDisplayOrder.get() |> take(1)` consumers block indefinitely in every other state.
2. `accessInitialized` only flips to `true` when the disposable runs (so for `.notDetermined` it stays `false`), and `basicData(updated:)` / `importable(updated:)` skip the immediate-callback path when it's `false` — new subscribers wait forever for the first emission.

Both gates were independently broken. Either alone wasn't enough; the chat-list tap flow happens to subscribe through both code paths and stalls on whichever still hasn't emitted. Setting both defaults at init breaks both deadlocks without disrupting the upstream behaviour: when permission becomes `.allowed`, the disposable overwrites our defaults with real device-derived values. When permission becomes `.denied`/`.limited`/`.restricted`, the disposable calls `updateAll([:])` which re-emits empty data to subscribers — a no-op since they already received our empty defaults.

Apple Review §5.1.1 (Privacy — Data Use and Sharing — Access) requires core features (messaging) to work without granting non-essential permissions (contacts). Reviewers tap "Don't Allow" as standard policy; shipping without this fix would re-trigger rejection.

---

### `submodules/TelegramUI/Sources/ChatController.swift`

**Imports — append after `import TextProcessingScreen`:**

```swift
import NovagramAppStoreIAP
```

**Inside the `else if let invoice = media as? TelegramMediaInvoice {` branch (around line 3553), in the `else` clause after the `if let receiptMessageId = invoice.receiptMessageId` check (i.e. the new-checkout path, around line 3568), insert before `let inputData = Promise<BotCheckoutController.InputData?>()`:**

```swift
// Novagram: Apple 3.1.1 — @PremiumBot card checkout (fiat subscription) is forbidden on App Store builds.
if NovagramAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    NovagramAppStoreIAP.presentBlockedAlert(on: strongSelf, languageCode: strongSelf.presentationData.strings.primaryComponent.languageCode)
    return
}
```

Reason: this is the path the May 2026 reviewer used — tapping `@PremiumBot`'s invoice message would otherwise present `BotCheckoutController` modally. The `return` exits the closure passed to `engine.data.get(...).startStandalone(next:)`, which is correct (we have fully handled the message).

---

### `submodules/TelegramUI/Sources/OpenResolvedUrl.swift`

**Imports — append after `import CreateBotScreen`:**

```swift
import NovagramAppStoreIAP
// Novagram: Feature #40 — tg://settings/novagrampro deep link
import NovagramMessenger
```

**Inside `case let .invoice(slug, invoice):`, in the `else` clause after the `XTR` Stars branch (around line 1425), insert before `let checkoutController = BotCheckoutController(...)`:**

```swift
// Novagram: Apple 3.1.1 — block fiat-card Premium subscription checkout (slug invoices, deep link).
if NovagramAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    let presenter: UIViewController = navigationController.topViewController ?? navigationController
    NovagramAppStoreIAP.presentBlockedAlert(on: presenter, languageCode: presentationData.strings.primaryComponent.languageCode)
    return
}
```

Reason: covers the deep-link path (`https://t.me/$slug` resolved to an invoice). `navigationController` is already unwrapped earlier in the same block. `NavigationController` extends `UINavigationController`, so `.topViewController` is the active visible screen and the right place to present a UIKit alert.

**Inside `case let .settings(section):` → `case let .path(path):`, after the `path.isEmpty` guard and BEFORE `handleSettingsPathUrl(...)` (around line 980), insert:**

```swift
// Novagram Feature #40: tg://settings/novagrampro → NovagramPro settings screen
if path == "novagrampro" {
    navigationController.pushViewController(novagramSettingsController(context: context))
    return
}
```

Reason: `tg://settings/<path>` resolves to `ResolvedUrl.settings(.path(path))`. This intercept catches `path == "novagrampro"` before the generic `handleSettingsPathUrl` helper is reached and pushes `novagramSettingsController` instead. `NovagramMessenger` is already a dep of `TelegramUI/BUILD` (added for ApplicationContext.swift); the import here is a second consumer in the same module, so no BUILD change is needed.

---

### `submodules/WebUI/BUILD`

In the `deps = [...]` list of `swift_library(name = "WebUI", ...)`, prepend at the top (before SwiftSignalKit):

```python
"//submodules/Novagram/AppStoreIAP:NovagramAppStoreIAP",
```

Reason: `WebUI` consumes `NovagramAppStoreIAP` from `WebAppController.swift` — Bazel needs the dep explicitly.

---

### `submodules/WebUI/Sources/WebAppController.swift`

**Imports — append after `import AlertComponent`:**

```swift
import NovagramAppStoreIAP
```

**Inside `case "web_app_open_invoice":`, in the `else` branch after the `XTR` Stars handling (around line 1296), insert before `let checkoutController = BotCheckoutController(...)`:**

```swift
// Novagram: Apple 3.1.1 — block fiat-card Premium subscription checkout from inside Web Apps.
if NovagramAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    let presenter: UIViewController = navigationController.topViewController ?? navigationController
    NovagramAppStoreIAP.presentBlockedAlert(on: presenter, languageCode: strongSelf.presentationData.strings.primaryComponent.languageCode)
    strongSelf.sendInvoiceClosedEvent(slug: slug, result: .cancelled)
    return
}
```

Reason: third entry point — a bot's WebApp triggers `web_app_open_invoice` JSON. We also call `sendInvoiceClosedEvent(..., result: .cancelled)` so the bot's JS side learns the flow ended (matches the semantics of the existing `cancelled` callback).

---

### `submodules/InAppPurchaseManager/BUILD`

The original BUILD pulled in `Postbox`, `TelegramStringFormatting`, `TelegramUIPreferences`, `PersistentStringHash` because the old StoreKit-driven implementation needed them. After the full rewrite (next section) those imports are gone and the BUILD's `deps = [...]` should read exactly:

```python
deps = [
    "//submodules/Novagram/AppStoreIAP:NovagramAppStoreIAP",
    "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    "//submodules/TelegramCore:TelegramCore",
],
```

Reason: only three dependencies remain after the rewrite — `NovagramAppStoreIAP` (for the blocking alert), `SwiftSignalKit` (for `Signal`), and `TelegramCore` (for `SomeTelegramEngine` and `AppStoreTransactionPurpose`). The dropped deps were StoreKit-related (transaction persistence, receipt parsing, product hashing, price-string formatting) and have no consumer now.

---

### `submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift` — full rewrite

The file used to be ~930 lines of `SKPaymentQueue` / `SKProductsRequest` / `SKPayment` / `SKReceipt` glue. After **2026-05-19** it is a ~145-line stub that:

1. Drops `import StoreKit`, `import Postbox`, `import TelegramStringFormatting`, `import TelegramUIPreferences`, `import PersistentStringHash`.
2. Imports only `Foundation`, `SwiftSignalKit`, `TelegramCore`, `NovagramAppStoreIAP`.
3. Removes every `SKPaymentTransactionObserver` / `SKProductsRequestDelegate` conformance — `InAppPurchaseManager` is a plain `NSObject` again.
4. Removes the `SKPaymentQueue.default().add(self)` registration in `init` and the matching `remove(self)` in `deinit`. There is no longer any deinit because nothing needs cleanup.
5. Keeps the **public surface** byte-for-byte compatible for the 13 consumer modules that import this file:
   - `class InAppPurchaseManager: NSObject` with `init(engine: SomeTelegramEngine)`.
   - `class Product: Equatable` with `id`, `isSubscription`, `price`, `priceValue`, `priceCurrencyAndAmount`, `pricePerMonth`, `defaultPrice`, `multipliedPrice`. The `SKProduct`-backed init is replaced with a private no-arg init (no consumer constructs `Product` themselves; it was only ever returned by `availableProducts`). The Equatable conformance becomes identity comparison since no instance is ever produced.
   - `enum PurchaseState`, `enum PurchaseError`, `enum RestoreState` — cases unchanged.
   - `struct ReceiptPurchase` — fields unchanged; gets a public memberwise init because `PremiumIntroScreen` types arrays of this struct.
   - `var canMakePayments: Bool` — now permanently `false`.
   - `var availableProducts: Signal<[Product], NoError>` — now permanently `.single([])`.
   - `func buyProduct(_:quantity:purpose:) -> Signal<PurchaseState, PurchaseError>` — presents `NovagramAppStoreIAP.presentBlockedAlertOnTop()` and returns `.fail(.cancelled)`.
   - `func restorePurchases(completion:)` — presents the alert and calls `completion(.failed)` on the main queue.
   - `func finishAllTransactions()` — no-op.
   - `func getReceiptPurchases() -> [ReceiptPurchase]` — returns `[]`.

Reason: **Apple App Store rejection 2026-05-18, submission `d5a06920-6b5f-4167-b7fb-46c80b156aa8`, Guideline 3.1.1.** The earlier May 2026 revision gated the StoreKit funnel at runtime with `if NovagramAppStoreIAP.shouldBlockIAP { ... }`. That worked, but the binary still contained reachable StoreKit code — the IPA shipped `SKPaymentQueue.default().add(self)` at launch, a 700-line `SKPaymentTransactionObserver` extension, a `SKProductsRequest` lifecycle, and a `getReceiptData()` / `parseReceipt(...)` chain. App Review's static analysis can flag any of those in a future submission. This rewrite removes the StoreKit code entirely so:

- `grep -r 'import StoreKit' submodules/` returns zero hits.
- `grep -r 'SK\(Payment\|Product\|Receipt\)' submodules/` returns zero hits outside comments / docs.
- The `NovagramAppStoreIAP` alert remains the user-facing behaviour for every Subscribe / Buy / Restore tap — same UX as before, just no StoreKit pipeline behind it.

The `Product` class is preserved as a public type only because 6 consumer files type arrays as `[InAppPurchaseManager.Product]` and the StarsPurchaseScreen / PremiumIntroScreen / etc. `combineLatest` chains type their Signals as `Signal<[InAppPurchaseManager.Product], NoError>`. Since `availableProducts` returns `[]`, no `Product` is ever instantiated, so the no-op stub bodies are safe.

Consumers that previously checked `if product.isSubscription` or used `product.priceCurrencyAndAmount` continue to compile but never run those branches — the arrays they iterate are always empty. The IAP alert fires at the moment the user taps Subscribe / Buy / Restore, before any unreachable consumer code is touched.

---

## 📋 Current hook inventory (quick summary)

| File                                                                                                                                                                                                                   | Hook type                                                                                                                                                                      | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AuthorizationUI/BUILD`                                                                                                                                                                                                | +3 lines (deps)                                                                                                                                                                | wire NovagramAppleReview + NovagramBrand + NovagramLocalization into AuthorizationUI                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `AuthorizationSequenceSplashController.swift`                                                                                                                                                                          | +1 import, ~5 lines hook                                                                                                                                                       | emerald-green brand on Welcome / Start Messaging                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `AuthorizationSequenceCodeEntryController.swift`                                                                                                                                                                       | +1 import, ~9 lines hook                                                                                                                                                       | auto-fill SMS code for demo account via xmax.uz                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `AuthorizationSequenceCodeEntryControllerNode.swift`                                                                                                                                                                   | ~10 lines accessor + 3-line guard                                                                                                                                              | private-field access for demo mode + countdown overwrite block                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `AuthorizationSequencePhoneEntryControllerNode.swift`                                                                                                                                                                  | +1 import, +1 property, ~30 lines                                                                                                                                              | visible "Log in by QR code" button surfacing the existing hidden QR flow (2026-06-08)                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `AuthorizationSequencePhoneEntryController.swift`                                                                                                                                                                      | +1 import, +2 prewarm calls (1 line each)                                                                                                                                      | pre-warm SMS forwarder polling on demo phone confirmation (Apple Review timeout fix)                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `DeviceAccess/BUILD`                                                                                                                                                                                                   | +1 line (dep)                                                                                                                                                                  | wire NovagramContactsConsent into DeviceAccess                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `DeviceAccess/Sources/DeviceAccess.swift`                                                                                                                                                                              | +1 import, +3 wrapper lines                                                                                                                                                    | server-upload consent dialog before iOS Contacts permission (Apple Review 5.1.2 rejection fix)                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `TelegramUI/BUILD`                                                                                                                                                                                                     | +1 line (dep)                                                                                                                                                                  | wire NovagramAppStoreIAP into TelegramUI                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `TelegramUI/Sources/AppDelegate.swift`                                                                                                                                                                                 | +1 import, +2 lines                                                                                                                                                            | propagate `isAppStoreBuild` flag to NovagramAppStoreIAP at launch                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `TelegramUI/Sources/ApplicationContext.swift` (line ~698)                                                                                                                                                              | wraps body in `Queue.mainQueue().after(1.0, { ... })` + 7-line comment                                                                                                         | defer post-login contacts auto-prompt 1s so it presents on the stable Chats keyWindow instead of racing the auth-to-tab-bar transition (2026-05-19 regression fix v2; v1 had silenced the prompt entirely which killed the Novagram consent + iOS native alerts)                                                                                                                                                                                                                                                                               |
| `TelegramUI/Sources/ChatController.swift`                                                                                                                                                                              | +1 import, +5 lines                                                                                                                                                            | block @PremiumBot card checkout on App Store builds (Apple 3.1.1)                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `TelegramUI/Sources/OpenResolvedUrl.swift`                                                                                                                                                                             | +1 import, +6 lines                                                                                                                                                            | block slug-deep-link Premium invoice card checkout                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `WebUI/BUILD`                                                                                                                                                                                                          | +1 line (dep)                                                                                                                                                                  | wire NovagramAppStoreIAP into WebUI                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `WebUI/Sources/WebAppController.swift`                                                                                                                                                                                 | +1 import, +7 lines                                                                                                                                                            | block Web-App-initiated Premium invoice card checkout                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `InAppPurchaseManager/BUILD`                                                                                                                                                                                           | rewritten deps list                                                                                                                                                            | wire NovagramAppStoreIAP + drop StoreKit-era deps (Postbox / StringFormatting / UIPreferences / PersistentStringHash)                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `InAppPurchaseManager/Sources/InAppPurchaseManager.swift`                                                                                                                                                              | full rewrite (930 → ~145 lines)                                                                                                                                                | remove StoreKit code path entirely; public API preserved as fail-fast stubs that present the Novagram IAP alert                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `TelegramUI/Sources/AppDelegate.swift` (line ~35, ~890)                                                                                                                                                                | -1 import, -5 lines                                                                                                                                                            | drop `import StoreKit` + replace `AppStore.showManageSubscriptions(in:)` with the existing web fallback (no StoreKit-backed subscriptions exist on this fork)                                                                                                                                                                                                                                                                                                                                                                                 |
| `AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift` (line ~29)                                                                                                                                          | -1 import                                                                                                                                                                      | drop now-unused `import StoreKit` (the only `AppStore*` symbol was `AppStoreTransactionPurpose` which is a TelegramCore type, not StoreKit)                                                                                                                                                                                                                                                                                                                                                                                                   |
| `RMIntro/Sources/platform/ios/RMIntroViewController.m`                                                                                                                                                                 | ~30 lines (loadGL block + updateLayout branch)                                                                                                                                 | Novagram logo visible on Apple-Silicon simulator                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `sqlcipher/BUILD`                                                                                                                                                                                                      | ~10 lines (header split)                                                                                                                                                       | Xcode 26.5 SDK sqlite3ext.h module conflict fix                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `ChatListHeaderComponent/Sources/NavigationButtonComponent.swift`                                                                                                                                                      | +7 lines in icon-frame branch                                                                                                                                                  | clamp oversized PDF artboards (NovagramGhostActive 455x491 pt → 25x27 pt); set contentMode = .scaleAspectFit (2026-06-08 size fix)                                                                                                                                                                                                                                                                                                                                                                                                               |
| `ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` (2026-06-23)                                                                                                                                             | +4 lines in `setupSttButton()`, +~100 lines new method                                                                                                                         | STT long-press quick-settings: language picker + voice-translate toggle + translate-target-lang nested sheet (Vosk branch — no Whisper, no BUILD change)                                                                                                                                                                                                                                                                                                                                                                                      |
| `TelegramUI/BUILD` + `AppDelegate.swift` (2026-06-27)                                                                                                                                                                  | +1 dep, +1 import, +6-line launch hook                                                                                                                                         | start NovagramAnalytics once shared context ready (device + account counting)                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `PeerInfoScreen/{BUILD, PeerInfoScreen.swift, PeerInfoSettingsItems.swift, PeerInfoScreenSettingsActions.swift}` (2026-06-27)                                                                                          | +1 dep, +1 enum case, +2 imports, +1 row, +1 action case                                                                                                                       | "Analytics" Settings row → NovagramAnalyticsController                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `PeerInfoScreen/{PeerInfoScreen.swift, PeerInfoSettingsItems.swift, PeerInfoScreenSettingsActions.swift}` (2026-07-06)                                                                                                 | +1 enum case `.novagramBots`, +1 row under NovagramPro (id 2), +1 action case                                                                                                  | "Novagram Bots" Settings row → novagramBotsController (surface Bots directly in Settings for faster discovery; reuses NovagramMessenger, no new dep)                                                                                                                                                                                                                                                                                                                                                                                            |
| `PeerInfoScreen/PeerInfoSettingsItems.swift` (2026-07-06)                                                                                                                                                              | 1 string literal                                                                                                                                                               | Settings row renamed "NovagramPro" → "Novagram Settings" (the Pro name read as a paid tier)                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `PeerInfoScreen/PeerInfoSettingsItems.swift` (2026-07-16)                                                                                                                                                              | 3 row `text:` literals → `NovagramSettingsSectionStrings.{settings,bots,analytics}RowTitle(langCode:)`, +1 `novagramLangCode` line                                                   | localize the 3 Novagram section rows (Settings/Bots/Analytics) — were hardcoded English while the app UI was Uzbek. Uses app language `strings.baseLanguageCode`, NOT `Locale.current`. Strings live in `NovagramMessenger/NovagramBotsData.swift` (`NovagramSettingsSectionStrings`). Analytics page title in `NovagramAnalytics/NovagramAnalyticsController.swift` localized the same way.                                                                                                                                                         |
| `ChatListUI/Sources/ChatContextMenus.swift` (2026-07-06)                                                                                                                                                               | 1 line in ChatLock item                                                                                                                                                        | pincode context-menu icon Pin/Unpin → "Chat/Context Menu/Lock" (emoji stripped from titles in NovagramL10n+ChatLock — icon+emoji double was wrong)                                                                                                                                                                                                                                                                                                                                                                                             |
| `TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` + `TelegramUI/Sources/ChatControllerForwardMessages.swift` + `TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift` + `TelegramUI/BUILD` (2026-07-07) | +1 import, +1 dep, +1 context item, +1 one-shot consume local, 3 expressions                                                                                                   | "Forward Without Name" (revised): the `pro_messager/forward_hide_names` toggle (NovagramPro, default OFF) no longer force-hides names on every forward — it now EXPOSES a per-message long-press context item "Forward without name" (NovagramL10n.context_forwardWithoutName). Tapping it sets one-shot `pro_messager/forward_hide_names_once`, which the forward-destination sites consume-and-reset (OR'd with `!hasNotOwnMessages`, own-messages-always-hide preserved). LoadDisplayNode fallback reverted to upstream `hideNames: false`. |
| `TelegramCore/Sources/TelegramEngine/Peers/TogglePeerChatPinned.swift` (2026-07-06)                                                                                                                                    | let→var, +4 lines                                                                                                                                                              | "Unlimited Pins": client pin limit → 1000 when `pro_messager/unlimited_pins` is set; upstream swallows pin-sync server errors, extra pins stay device-local (NovagramPro toggle, default OFF)                                                                                                                                                                                                                                                                                                                                                 |
| `PeerInfoScreen/Sources/PeerInfoProfileItems.swift` (2026-07-06)                                                                                                                                                       | +2 imports, +2 rows                                                                                                                                                            | "ID" row with tap-to-copy in user profiles (raw id) and channels/groups (`-100…` Bot API format); toast via UndoUI, string `profile_idCopied`                                                                                                                                                                                                                                                                                                                                                                                                 |
| `Telegram/Telegram-iOS/PrivacyInfo.xcprivacy` (2026-06-27)                                                                                                                                                             | +1 purpose string                                                                                                                                                              | declare anonymous Device ID collection for Analytics (Tracking=false → no ATT)                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `TelegramUI/BUILD` + `AppDelegate.swift` (2026-07-04)                                                                                                                                                                  | +1 dep, +1 import, +9-line launch hook                                                                                                                                         | start NovagramAutoProxy at launch (re-apply/self-heal NovagramProxy when the toggle is on)                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `AppDelegate.swift` (2026-07-07)                                                                                                                                                                                       | +1 import, +14-line launch hook                                                                                                                                                | start NovagramAutoAcceptManager global monitor on the active account (Feature #45 proactive auto-accept; NovagramMessenger already a dep)                                                                                                                                                                                                                                                                                                                                                                                                       |
| `AuthorizationUI/BUILD` + `AuthorizationSequencePhoneEntryController.swift` (2026-07-04)                                                                                                                               | +1 dep, +1 import, +~30 lines                                                                                                                                                  | login-screen "NovagramProxy" nav button — enable proxy before login in blocked countries                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `TelegramCore/Sources/SyncCore/SyncCore_EditedMessageHistoryAttribute.swift` (fork-ADDED file; media v2 2026-07-07)                                                                                                    | whole file (~115 lines)                                                                                                                                                        | `EditedMessageHistoryEntry` + `EditedMessageHistoryAttribute` — stores previous versions of edited messages; v2 adds `media: [Media]` (backward-compatible decode)                                                                                                                                                                                                                                                                                                                                                                            |
| `TelegramCore/Sources/NovagramEditHistoryCapture.swift` (fork-ADDED file; 2026-07-21)                                                                                                                                   | whole file (~55 lines)                                                                                                                                                         | `novagramAppendEditHistory(previousMessage:newText:newMedia:into:)` — single shared capture helper; also carries an existing history forward when an update brings no text/media change (so it is not silently dropped)                                                                                                                                                                                                                                                                                                                        |
| `TelegramCore/Sources/State/AccountStateManagementUtils.swift` (`.EditMessage`, ~line 4599; updated 2026-07-21)                                                                                                        | 1-line hook (was ~28-line inline block)                                                                                                                                        | call `novagramAppendEditHistory(...)` (capture logic moved into the shared helper)                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `TelegramCore/Sources/PendingMessages/RequestEditMessage.swift` (2026-07-21)                                                                                                                                           | +3 lines × 4 update branches                                                                                                                                                   | call `novagramAppendEditHistory(...)` in the own-edit result handler so a user's OWN first edit is recorded — the previous code replaced the message with the server copy (dropping the attribute) before the state-manager path could see a text change, so history only began at the SECOND edit                                                                                                                                                                                                                                             |
| `TelegramCore/Sources/SyncCore/SyncCore_StandaloneAccountTransaction.swift` (`mergeMessageAttributes`, 2026-07-21)                                                                                                     | +19 lines                                                                                                                                                                      | carry `EditedMessageHistoryAttribute` forward across message re-add/replace (`.InsertExistingMessage` → `justUpdate`), like the existing `AudioTranscription`/`DerivedData`/`RichText` entries. Without it, channel & group messages re-arriving via `getChannelDifference` newMessages dropped the captured history — this is why History worked in **private chats but not groups/channels**                                                                                                                                                |
| `TelegramCore/Sources/Account/AccountManager.swift` (line ~246)                                                                                                                                                        | +1 line                                                                                                                                                                        | `declareEncodable(EditedMessageHistoryAttribute.self, ...)` Postbox type registration                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `Telegram/NotificationService/Sources/NotificationService.swift` (`.deleteMessage(ids)`, ~line 2434; 2026-08-26)                                                                                                       | +1 comment block, +1 gate read, capture loop replaces unconditional delete (~30 lines)                                                                                         | anti-delete P0 fix: retain (don't erase) messages on silent MESSAGE_DELETED push while app is backgrounded, when `show_deleted_messages` is on — first-ever Novagram hook in this file                                                                                                                                                                                                                                                                                                                                                         |
| `TelegramCore/Sources/Novagram/NovagramShowDeletedMessages.swift` (fork-ADDED file; 2026-08-26)                                                                                                                          | whole file (~36 lines)                                                                                                                                                         | `isNovagramShowDeletedMessagesEnabled` — App-Group-aware toggle read (local suite first, then App Group fallback) so the NotificationService extension sees the same value as the main app                                                                                                                                                                                                                                                                                                                                                     |
| `TelegramCore/Sources/SyncCore/SyncCore_StandaloneAccountTransaction.swift` (`mergeMessageAttributes`, 2026-08-26)                                                                                                     | +23 lines                                                                                                                                                                      | carry `DeletedMessageAttribute` forward across message re-add/replace, same shape as the existing `EditedMessageHistoryAttribute` entry above — without it, retained messages lost their 🗑 marker on group/channel re-sync                                                                                                                                                                                                                                                                                                                   |
| `TelegramUI/Sources/AppDelegate.swift` (line ~1228; 2026-08-26)                                                                                                                                                        | +1 line                                                                                                                                                                        | `NovagramSharedDefaults.syncShowDeletedMessages()` — backfill the App Group mirror on every launch for users who had the toggle on before Wave 3 shipped                                                                                                                                                                                                                                                                                                                                                                                         |
| `TelegramCore/Sources/TelegramEngine/Peers/ResolvePeerByName.swift` (2026-08-27)                                                                                                                                       | new enum `ResolvedPeerByPhone`, RPC body renamed to `_internal_resolvePeerByPhoneWithStatus`, old function now a 9-line `map` wrapper, +1 new enum `EngineResolvedPeerByPhone` | distinguish a failed phone lookup (RPC error) from a genuine "not on Telegram" server answer                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `TelegramCore/Sources/TelegramEngine/Peers/TelegramEnginePeers.swift` (2026-08-27)                                                                                                                                     | `resolvePeerByPhone` reimplemented (~8 lines), +1 new method `resolvePeerByPhoneWithStatus` (~16 lines)                                                                        | engine-facade equivalent of the same distinction; existing callers of `resolvePeerByPhone` unaffected                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `TelegramUI/Sources/Chat/ChatControllerOpenPhoneContextMenu.swift` (2026-08-27)                                                                                                                                        | +1 import, ~18-line result-branch, +1 "Try Again" menu action, 1 footer-text ternary                                                                                           | phone context menu offers "Try Again" (no "Invite to Telegram") + an honest failure message instead of stating a failed lookup as "not on Telegram"                                                                                                                                                                                                                                                                                                                                                                                           |
| `TelegramPresentationData/BUILD` (2026-08-27)                                                                                                                                                                          | +1 line (dep)                                                                                                                                                                  | wire NovagramBrand into TelegramPresentationData                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `TelegramPresentationData/Sources/PresentationData.swift` (2026-08-27)                                                                                                                                                 | +1 import, 7 assignment sites in `dictFromLocalization` wrapped                                                                                                                | rewrite "Telegram"/"TELEGRAM" → "Novagram"/"NOVAGRAM" in every server-delivered language-pack string (the bundled `Localizable.strings` rebrand never reached a logged-in user)                                                                                                                                                                                                                                                                                                                                                               |

**Total Telegram-owned files modified: 46** (7 BUILD + 36 Swift + 1 Objective-C + 1 sqlcipher + 1 Privacy manifest). Recounted 2026-08-27 by adding this changeset's 5 newly-hooked files (1 BUILD + 4 Swift: `ResolvePeerByName.swift`, `TelegramEnginePeers.swift`, `ChatControllerOpenPhoneContextMenu.swift`, `TelegramPresentationData/BUILD`, `PresentationData.swift`) to the 2026-08-26 total of 41 (6 BUILD + 32 Swift + 1 Objective-C + 1 sqlcipher + 1 Privacy manifest). All Novagram logic itself lives in:

- `submodules/Novagram/AppleReview/` — demo-code fetcher + iOS alert
- `submodules/Novagram/AppStoreIAP/` — Apple 3.1.1 IAP gate (May 2026 rejection fix)
- `submodules/Novagram/Brand/` — central colour palette
- `submodules/Novagram/ContactsConsent/` — Apple App Review 5.1.2 server-upload consent gate

## 📌 NovagramProxy — opt-in auto SOCKS5 proxy (2026-07-04)

User-facing brand: **NovagramProxy**. An opt-in toggle, **default OFF**. When ON, the app auto-finds
a working SOCKS5 proxy from a bundled pool and routes this user's Telegram connection through it, so a
user in ANY blocked country can reach Telegram without configuring a proxy by hand. The proxy host is
never surfaced by the toggle. Three Telegram-owned hook sites, each a one-liner into the Novagram module:

**(a) Launch** — `submodules/TelegramUI/Sources/AppDelegate.swift` + `submodules/TelegramUI/BUILD`:
`import NovagramAutoProxy` + a `sharedContextPromise |> take(1)` block calling
`NovagramAutoProxyManager.shared.start(sharedContext:)` (right after the NovagramAnalytics block).
`start()` no-ops unless the toggle is on; if on it re-applies / self-heals the proxy. BUILD +1 dep.

**(b) Settings toggle** — `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift`
(Novagram-owned): an "Enable NovagramProxy" `ItemListSwitchItem` in the Protection section (mirrors
`blockForeignUsers`; key `novagram_proxy_enabled` in the `pro_messager` suite). Handler calls
`NovagramAutoProxyManager.shared.setEnabled(value, sharedContext: context.sharedContext)`. NovagramMessenger
BUILD +1 dep.

**(c) Login screen** — `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift`

- `AuthorizationUI/BUILD`: `import NovagramAutoProxy` + a left nav-bar `lock.shield` button
  (`novagramProxyPressed`) shown on first login (free left slot when there are no other accounts),
  presenting a themed alert that enables/disables via `setEnabled(!isOn, sharedContext: self.sharedContext)`.
  Essential because a blocked user cannot reach the in-app Settings BEFORE logging in. BUILD +1 dep.

All logic lives in `submodules/Novagram/AutoProxy/`:

- Writes shared proxy settings via `updateProxySettingsInteractively` — the running account (auth OR
  unauth) observes the change and routes its connection through the proxy automatically. No
  dependency on a live account/network, so it works PRE-login and stays merge-stable (only the
  public proxy API is touched, not `SharedAccountContext` internals).
- **Gate (Apple-safe):** the proxy is applied ONLY when the `novagram_proxy_enabled` toggle is on
  (default OFF). A US Apple reviewer never turns it on, so the demo-account login flow is unaffected.
- **Never overrides the user's own proxy;** turning the toggle OFF removes only our proxy.
- **Self-heal:** a proxy we set earlier that has since died is re-checked and rotated to a live one
  on the next launch (or when the toggle is (re)enabled).
- `NovagramRussiaDetector` (offline RU region / time-zone check) is retained in the module but NOT
  used as a gate in this design — kept ready for an optional "auto-on in Russia" mode.
- Proxy pool: bundled `Resources/russia_proxies.txt` (Webshare `host:port:user:pass`, used as
  SOCKS5), loaded shuffled. Health is verified end-to-end by `NovagramSocks5Probe`
  (Network.framework: SOCKS5 username/password auth + CONNECT to a Telegram DC) BEFORE enabling;
  `NovagramProxyProbeSession` probes candidates in concurrent batches and enables the first live one.
- Bundling: `apple_resource_bundle` (`NovagramAutoProxyResources`) attached via `data =`, read with
  `Bundle(for: NovagramAutoProxyManager.self)` → nested `.bundle` (MetalEngine pattern).

To swap the proxy list later, replace `submodules/Novagram/AutoProxy/Resources/russia_proxies.txt`
(same `host:port:user:pass` format) and rebuild — no code change needed.

## 📌 Ghost mode button (2026-06-04)

### `submodules/ChatListUI/Sources/ChatListController.swift` — Ghost mode nav-bar button

Ghost mode = read messages without sending read receipts. The chat-list nav bar shows a toggle
button when `pro_messager` UserDefaults key `show_ghost_mode_button == true`; the active state is
stored in `is_ghost_mode_active`. Implemented entirely inside `ChatListController` (no Novagram
submodule): `ghostModeButton` property, `updateGhostModeButton()`, a `NovagramSettingsChanged`
NotificationCenter observer, and the button is appended in `rightButtons`.

- **2026-06-04 icon change:** the button uses a custom Novagram ghost glyph
  **`Contact List/NovagramGhostIcon`** (template imageset; eyes + background are alpha holes) via
  `NavigationButtonComponent.Content.iconTinted(imageName:accent:)`. Toggle state is shown by tint:
  ON (active) → `theme.list.itemAccentColor`; OFF → `panelControlColor` (grey). Previously it reused
  upstream PDF assets `Contact List/MakeVisibleIcon` / `MakeInvisibleIcon` (a person-on-a-platform
  contact glyph that read as "block / remove person"). The ghost PNGs (@1x/@2x/@3x) were generated
  from an owner-supplied image into
  `submodules/TelegramUI/Images.xcassets/Contact List/NovagramGhostIcon.imageset` (RGB black + source
  alpha, template-rendering-intent).

## 📌 Folder display style — Feature #21 (2026-07-07)

### `submodules/ChatListUI/Sources/ChatListController.swift` — filter-tab title style

The "Folder display style" setting (Icons / Text / Automatic, `pro_messager` key
`fenix_folder_display_style`) drives how chat-list filter TABS render. Two minimal hooks:

- **Import:** `import NovagramForeignUserBlock` added next to the other Novagram imports
  (after `import NovagramSecretVault`). `NovagramForeignUserBlock` was already a `ChatListUI` BUILD
  dep, so no BUILD change was needed.
- **`reloadFilters()` tab build (~line 4008):** the `.filter` case now exposes the folder
  `emoticon` and routes the title through `NovagramFolderStyle.resolveTabTitle(title, emoticon:)`
  instead of passing `title` directly. For style `"icon"` (and a non-empty emoticon) the helper
  returns a `ChatFolderTitle` whose text is the emoticon (renders the folder emoji as the tab);
  `"text"`/`"auto"`/no-emoticon keep the upstream text title.

Helper lives in the Novagram module: `submodules/Novagram/ForeignUserBlock/Sources/ChatList_NovagramFolderStyleHelper.swift`
(Novagram-owned, auto-globbed). Live refresh reuses the existing `NovagramSettingsChanged`
NotificationCenter observer (`ChatListController.novagramMessengerSettingsChanged` → `reloadFilters()`):
`NovagramSettingsController.openFolderStyle` now posts `NovagramSettingsChanged` after persisting the
style, so switching Icons/Text/Automatic rebuilds the tabs immediately.

### `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift`

Added two `Content` cases: `systemIcon(name: String)` (renders `UIImage(systemName:)` at pointSize 20 /
weight .medium) and `iconTinted(imageName: String, accent: Bool)` (bundle asset tinted with
`theme.list.itemAccentColor` when `accent`, else `panelControlColor`). The shared icon render branch now
computes the tint colour and bakes the SF-Symbol / accent state into the icon cache key (so a toggle
re-renders). Used by the ghost button above. Additive only — existing `.text` / `.more` / `.icon` /
`.proxy` cases keep the `panelControlColor` tint.

**2026-06-08 icon size clamp:** in the `if var iconSize = iconView.image?.size` branch (icon frame
computation), added a `maxIconDimension = 28.0 pt` scale-down clamp before setting `iconView.frame`.
Vector PDF assets (NovagramGhostActive / NovagramGhostInactive) have large native artboards — without the
clamp their `image.size` fills most of the screen. Clamp only shrinks oversized images (PNG icons that
are already ≤28 pt are unaffected). Also sets `iconView.contentMode = .scaleAspectFit` so the PDF
scales correctly inside the clamped frame. No other icon cases or `.text` / `.more` / `.proxy` branches
are touched.

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — STT (ovoz→matn) button

Custom Novagram speech-to-text round button in the chat input panel (`setupSttButton` /
`layoutSttButton` / `sttButtonPressed` / `updateSttButtonAppearance`, plus the `sttButton*` fields,
`NovagramSpeechToText` import, and a left-inset reservation). Reads `pro_messager` UserDefaults
`stt_enabled` / `stt_language`.

- **2026-06-04 placement fix:** the button was moved from the RIGHT (it sat at
  `textInputContainerBackgroundFrame.maxX + 6`, which collided with / overran the send button once the
  input had text during recording) to the **LEFT, next to the attachment button** — a stable slot that
  never moves when the input gains text. Mechanism: reserve 46pt via `textFieldInsets.left += 46` when
  `showSttButton` (sttEnabled && no voice-message recording && no customLeftAction && not extended
  search); position at `textInputContainerBackgroundFrame.minX - 6 - 40`. The old right-side 46pt
  reservation and the mic-button push were removed. Default `stt_language` corrected `uz-UZ` → `en-US`
  (Apple has no Uzbek recogniser; the old default produced silent empty results).

- **2026-06-05 visibility fix:** the button was a plain `HighlightTrackingButton` with a hardcoded
  faint alpha fill (`black 0.05` light / `white 0.1` dark). The dark fill was nearly invisible on dark
  wallpapers, so the button appeared to "disappear" while the native voice mic (a `GlassBackgroundView`)
  stayed visible. Fixed by rebuilding the STT button on the same iOS-26 Liquid-Glass `GlassBackgroundView`
  the attachment / voice buttons use: a `sttButtonBackground` (GlassBackgroundView) hosting a transparent
  `sttButton` + a `sttButtonIcon` (`GlassBackgroundView.ContentImageView`), added to
  `glassBackgroundContainer.contentView` (not `self.view`) so the material samples the wallpaper
  identically. Idle tint = `currentSttGlassTint()` (`.panel`/`.clear`, matching `defaultGlassTintColor`);
  recording tint = red custom glass + white icon + pulse. Fields `sttButtonBackgroundView`/
  `sttButtonIconView` renamed to `sttButtonBackground`/`sttButtonIcon` and retyped; `layoutSttButton`
  now positions in container-content coordinates (dropped the `containerOffset`/`self.view` conversion).

- **2026-06-23 long-press quick-settings (Vosk branch):** holding the STT mic button for 0.4s presents
  an `ActionSheetController` with two sections:
  - **Section A "🌐 Til"** — lists `SpeechToTextManager.supportedLanguages` (named tuples `(id, name)`).
    The currently active locale (`pro_messager` / `"stt_language"`, default `"en-US"`) is marked "✓".
    Tapping writes the chosen `id` to `"stt_language"`.
  - **Section B "🔄 Ovozli tarjima"** — (i) toggle button showing "Ovozli tarjima: BOR ✅" /
    "Ovozli tarjima: YO'Q" that flips `"voice_translate_enabled"` (Bool); (ii) "Tarjima tili: <name>"
    button that opens a second (nested) `ActionSheetController` listing all `supportedLanguages` to pick
    the translate target, writing the 2-letter code (`lang.id.prefix(2).lowercased()`) to
    `"auto_translate_lang"` (default `"en"`). Display name resolved by matching on 2-letter prefix.
  - **Cancel group** — `presentationData.strings.Common_Cancel`, bold.

  Implementation lives entirely in the new `@objc private func sttButtonLongPressed(_:)` method
  (~100 lines) and the 4-line `UILongPressGestureRecognizer` setup in `setupSttButton()` (right after
  `button.addTarget(...sttButtonPressed...)`). No BUILD change needed — `NovagramSpeechToText` was
  already the only Novagram dep here; no Whisper symbols are used.

  Presentation path: `self.view.window?.endEditing(true)` (dismiss keyboard first) then
  `interfaceInteraction.chatController()?.present(sheet, in: .window(.root))` — identical to the
  existing camera-picker long-press action sheet in this file.

### `submodules/AccountUtils/Sources/AccountUtils.swift` — multi-account limit raised

**2026-06-05 fix:** with 3 accounts logged in, "Add Account" showed the upstream "Limit Reached / buy
Premium" screen — the REAL add-account gate is a hardcoded `maximumAvailableAccounts = 3` (4 premium)
pattern repeated in THREE files that the original 3→20 raise never touched:
`PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift` (~233, the Settings gate the user hits),
`SettingsUI/Sources/LogoutOptionsController.swift` (~142) and
`SettingsUI/Sources/DeleteAccountOptionsController.swift` (~204). All three now read
`maximumNumberOfAccounts` / `maximumPremiumNumberOfAccounts` (AccountUtils already imported in each).
Constants raised 20 → **999** (effectively unlimited; safe because the working-set cap keeps ≤3 live).

`maximumNumberOfAccounts` 3 → **20** and `maximumPremiumNumberOfAccounts` 4 → 20 (owner request,
2026-06-04). Client-side cap only (Telegram's server does not limit how many login sessions one app
holds, so no Premium is required). The add-account gate reads `maximumNumberOfAccounts`
(`accountsAndPeers.count + 1 < maximumNumberOfAccounts`). Note: actually keeping ~20 accounts active is
memory-heavy on iOS (jetsam risk + 24MB NSE limit); the cap itself is harmless.

### `submodules/TelegramUI/Sources/SharedAccountContext.swift` — multi-account scaling (50-100+ accounts)

Audit (2026-06-05) of the multi-account cost found: every logged-in account is turned into a full
active `AccountContext` simultaneously (`activeAccountsValue!.accounts.append(...)`, ~line 739) with
**no cap**. Each costs an open SQLite Postbox (page cache, the #1 OOM driver), 2+ OS threads, and
launch-time `resetStateManagement()` work; all Postbox transactions serialize on a single
`Postbox.sharedQueue`, so launch/foreground with many accounts storms one thread → UI "freeze". The
MTProto network is already bounded to primary + task-pending accounts (`SharedWakeupManager`), and push
works server-side via registered tokens (the NSE opens only the ONE target account's Postbox), so push
is safe at any account count.

- **Stage 1 (2026-06-05 — memory relief, shipped):** a `didReceiveMemoryWarningNotification` observer
  (`novagramLowMemoryObserver`, registered in `init`, removed in `deinit`) that calls
  `postbox.clearCaches()` + `account.resetCachedData()` on every NON-primary active account. Reads the
  account list via the public `activeAccountContexts` signal (`|> take(1)`) to avoid racing the private
  `activeAccountsValue` mutation queue. Purely additive; uses the same calls already made on
  primary-switch (line ~777-778), so no behavior change. Reduces jetsam risk in the current all-active
  world.
- **Stage 2 (2026-06-05 — working-set cap = 3, shipped):** all account RECORDS stay logged in, but only
  the `novagramMaxLiveAccounts` (3) most-recently-used are kept as live `AccountContext`s; the rest stay
  suspended (not loaded → no Postbox/threads/sync). Edits in the `accountManager.accountRecords()`
  pipeline:
  - Working-set computed each pass (`novagramOrdered`/`novagramWorkingSet`): primary first, then prior
    recency (`novagramRecencyOrder`), then the rest by sortIndex; first N = live.
  - `accountWithId` is gated on `novagramWorkingSet.contains(id)` (suspended records never open a Postbox).
  - The removal loop also unloads loaded accounts that fell out of the working-set (LRU eviction); the
    primary is always in the working-set so it is never evicted.
  - Switching to a suspended account (via the Accounts screen → `switchToAccount`) makes it primary →
    next pipeline pass loads it and evicts the LRU tail (~1-2s cold start).
  - A name cache (`novagramNameCacheDisposable` → UserDefaults `pro_messager` / `fenixuz_account_names`,
    keyed by `peerId.toInt64()`) records each live account's `debugDisplayTitle` so suspended accounts
    can be labelled in the Accounts screen.
  - **Accounts screen** (NOT a Telegram-owned file): `submodules/Novagram/Messenger/Sources/NovagramAccountsController.swift`
    lists every logged-in record (live + suspended) and switches on tap. Reached from Settings →
    Novagram → "Barcha accountlar" (a row added in `NovagramSettingsController.swift`, also Novagram-owned).
  - **Known v1 limitations** (push token registration unchanged): suspended accounts keep their existing
    server-side push registration, so push keeps working in the common case; an APNs token _rotation_
    while an account is suspended would drop its push until it is next made live. VoIP calls to a
    suspended account are not presented (no live session). Both are acceptable for the hold-many-accounts
    use case; revisit by widening `otherAccountUserIds` to all logged-in uids + a PushKit resume path.
    **2026-09-18:** the PushKit resume path now exists — a call to a suspended account wakes it for the
    length of the call. See "Incoming calls" at the end of this file.
  - Users with ≤3 accounts see IDENTICAL behaviour (no regression) — the cap only engages at 4+.
  - **2026-06-05 discoverability hook (3 Telegram-owned files):** the built-in Settings accounts section
    only lists the live working-set, which confused the owner ("4-account yo'qoldi"). Added a
    "Barcha accountlar" disclosure row (id 101, icon `PresentationResourcesSettings.devices`) directly
    in the accounts section ABOVE the Add Account row, navigating to `novagramAccountsController`:
    `PeerInfoSettingsItems.swift` (~147, the row), `PeerInfoScreen.swift` (`PeerInfoSettingsSection`
    enum + `case novagramAccounts`, ~165), `PeerInfoScreenSettingsActions.swift` (`case .novagramAccounts:
push(novagramAccountsController(...))`, ~70 — file already imports `NovagramMessenger`; the
    PeerInfoScreen BUILD already depends on it). Settings stays compact at 100+ logins by design
    (owner: "Settings UI cho'zilib ketmaydi").
  - **2026-06-05 cap 3 → 1 (owner request):** only the SELECTED account is live; every other login is
    suspended. Every account switch is now a cold load (~1-2s) in exchange for absolute-minimum
    RAM/CPU/network. Because no other live rows exist, the accounts section in
    `PeerInfoSettingsItems.swift` was made unconditional (`if !settings.accountsAndPeers.isEmpty` →
    `do`) so "Barcha accountlar" + "Add Account" stay reachable. Accounts-screen footer text updated.
  - **2026-06-05 localization:** all multi-account strings moved to `NovagramL10n` (`accounts_*` keys,
    en/uz/ru — "All Accounts" / "Barcha accountlar" / "Все аккаунты", summary, Current/Active/sleeping,
    footer). The Settings row in `PeerInfoSettingsItems.swift` reads
    `NovagramL10n(presentationData.strings).accounts_allAccounts` — required `import NovagramLocalization`
    - `//submodules/Novagram/Localization:NovagramLocalization` dep in `PeerInfoScreen/BUILD`.
  - **2026-06-08 tab-bar long-press switcher fix:** `tabBarItemContextAction` in
    `PeerInfoScreen.swift` (~line 7128) used to read `other` from `accountsAndPeersValue` — which
    is sourced from `activeAccountsAndPeers()` → `activeAccountContexts` (live only, cap=1 → empty).
    Fix: added two new properties `novagramAllAccountsValue` / `novagramAllAccountsDisposable` (set up in
    the same `isSettings` block around line 6571) that subscribe to `accountManager.accountRecords()`
    - name cache (`fenixuz_account_names` UserDefaults) so all logged-in records are available.
      `tabBarItemContextAction` now iterates `novagramAllAccountsValue` for non-current rows and renders
      them as `ContextMenuActionItem` entries (text + arrow icon). Primary account row kept as
      `AccountPeerContextItem` (live peer available). This is purely additive — nothing removed.
      No BUILD change needed (PeerInfoScreen/BUILD already imports Postbox which provides `accountRecords()`).
  - **2026-06-08 username cache:** `SharedAccountContext.swift` (`novagramNameCacheDisposable` block,
    ~line 858) now also persists `@username` (or `+phone`) per account under
    `fenixuz_account_usernames` (same UserDefaults suite `pro_messager`). Purely additive —
    name cache unchanged, new key added in parallel.
  - **2026-07-31 phone cache:** `SharedAccountContext.swift` (same `novagramNameCacheDisposable`
    block, ~line 960) now also persists the account's phone as `+<digits>` under
    `fenixuz_account_phones` (same UserDefaults suite `pro_messager`). The username cache stores
    only ONE identity string per account (`@handle` **or** `+phone`), so a sleeping account with a
    username had no phone to render once the Accounts row grew to three lines. Purely additive —
    name + username caches unchanged, third key written in the same `if changed` block. Backfill is
    forward-only: an account already asleep shows `—` for the phone until it next goes live.
    Read side: `NovagramAccountsController.swift` `cachedAccountPhones()`.
  - **2026-06-08 NovagramAccountsController — username + avatar:** `AccountRow` now carries `username`
    and `livePeer` fields. Live accounts get real avatar via `context + iconPeer` on
    `ItemListDisclosureItem`; suspended accounts get a colored initials monogram (`UIGraphicsImageRenderer`,
    no new deps). `additionalDetailLabel` shows `@username` / `+phone` beneath the name.
    Username sourced from live peer when available, else `fenixuz_account_usernames` cache.
  - **2026-06-11 real avatar for suspended accounts (disk cache):** suspended accounts had no live
    peer, so both switchers (tab-bar long-press menu + `NovagramAccountsController`) drew only a colored
    initials circle, never the account's real photo. Fix mirrors each live account's rendered avatar
    to disk keyed by peerId, then loads it for suspended rows.
    - **Write:** `SharedAccountContext.swift` — added `import AvatarNode` (already a BUILD dep),
      a `novagramAvatarDiskCache` property, and a `NovagramAccountAvatarDiskCache.update(accounts:)` call
      inside the existing `novagramNameCacheDisposable` handler (made `[weak self]`). The manager calls
      `peerAvatarCompleteImage(account:peer:size:round:)` (120×120 round) and writes a PNG to
      `Caches/novagram-account-avatars/<peerId>.png`, re-rendering only when the avatar's
      `resource.id.stringRepresentation` changes (tracked in UserDefaults `fenixuz_account_avatar_versions`);
      clears the file when an account has no photo. Module-level helper `novagramAccountAvatarCachePath(peerId:)`.
    - **Read:** `NovagramAccountSwitchContextItem.swift` gained a `peerId` init param and prefers
      `novagramContextCachedAccountAvatar(peerId:)` over the initials image. `PeerInfoScreen.swift`
      `tabBarItemContextAction` passes `peerId: peerId`. `NovagramAccountsController.swift` suspended rows
      prefer `novagramCachedAccountAvatar(peerId:)` before `novagramInitialsAvatar`. Path formula duplicated
      (different modules, same main-app Caches dir) — consistent with the existing initials-helper duplication.
      No BUILD changes (read sites need only Foundation/UIKit). Purely additive; initials remain the fallback.
  - **2026-06-08 — `AccountContext/Sources/AccountContext.swift` protocol extension (upstream):**
    Added 4 members to `SharedAccountContext` protocol (`novagramPinnedAccountsSignal`,
    `novagramLoadPinnedAccounts()`, `novagramSavePinnedAccounts(_:)`,
    `novagramTogglePinnedAccount(recordId:primaryRecordId:)`). This lets `NovagramAccountsController`
    (in `NovagramMessenger`, which cannot import `TelegramUI`) call these methods via the protocol
    without an `as! SharedAccountContextImpl` cast. Purely additive — no existing protocol members
    changed; implementations live entirely in `SharedAccountContextImpl`.
  - **2026-06-08 — user-controlled pinned set (max 5 live):** `novagramMaxLiveAccounts` raised 1→5.
    New `novagramPinnedAccountsPromise` (`ValuePromise<Set<Int64>>`) seeded from
    `fenixuz_active_accounts` (UserDefaults `pro_messager`, array of `Int64` record ids).
    Public helpers on `SharedAccountContextImpl`: `novagramLoadPinnedAccounts()`,
    `novagramSavePinnedAccounts(_:)`, `novagramTogglePinnedAccount(recordId:primaryRecordId:)`,
    `novagramPinnedAccountsSignal`. Working-set recomputed on BOTH `accountRecords()` changes AND
    pin changes via `combineLatest(accountManager.accountRecords(), novagramPinnedAccountsPromise.get())`.
    New working-set rule: `{primary} ∪ {pinned records that exist}`, capped at 5.
    Non-pinned, non-primary accounts remain suspended. Primary is always live and never evicted.
    `NovagramAccountsController` updated: `isPinned` field in `AccountRow`; state labels use badge
    colors (accent=Current, green=Active, plain-text=Sleeping); long-press on a non-primary row
    shows an `ActionSheetController` with "Activate (No Sleep)" or "Put to Sleep"; attempting to
    activate a 6th live account shows a `UIAlertController` warning and aborts. New L10n keys
    `accounts_activate`, `accounts_putToSleep`, `accounts_maxLiveTitle`, `accounts_maxLiveBody`,
    `accounts_maxLiveOk` (en/uz/ru) in `NovagramL10n.swift`.
  - **2026-06-22 logout-of-last-live-account fix (CRITICAL):** logging out the only live/primary
    account dumped the user to the LOGIN SCREEN even though their other accounts were still logged in
    (they only _looked_ removed). Cause: `logoutFromAccount` marks the record `.loggedOut`; the pipeline
    `map` (~line 645) filters logged-out records out, so `records[primaryId] == nil`; with nothing
    pinned `novagramOrdered` was empty → empty working-set → no account loaded → `primary == nil` →
    `beginNewAuth()`. No data is ever deleted — every record-removal site is bounded to a single id, so
    survivors are orphaned, not destroyed, and fully recoverable. Fix (additive, `SharedAccountContext.swift`
    ~line 720, inside the working-set builder): when `novagramOrdered` is empty, promote the lowest-`sortIndex`
    surviving record into the working-set (restores upstream's "switch to the next account on logout"), then
    advance the persisted `currentRecordId` to it via `accountManager.transaction { setCurrentId(...) }` so the
    "current" badge / cold-launch pointer aren't left dangling. No-op in every normal case (valid primary,
    genuine last-account logout → login screen still correct, auth flow). Nothing removed or commented.

## 📌 Edited-history gate + Camera picker localization (2026-06-08)

### `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift`

**Around line 1184 — the `EditedMessageHistoryAttribute` check.** Wrap with a UserDefaults gate:

```swift
// Novagram: edited history action — only shown when user has enabled it in Settings.
let editedHistoryEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "edited_history_enabled") as? Bool ?? true
if editedHistoryEnabled, let _ = messages[0].attributes.first(where: { $0 is EditedMessageHistoryAttribute }) {
    // ... existing action append ...
}
```

Reason: `edited_history_enabled` flag (default `true`) is toggled from Novagram Settings → Chat section. Gate is a one-liner wrapping the existing condition; default `true` means zero behavior change for existing users. The `UserDefaults` read is the cheapest possible gate — the context-menu build path already runs on the main queue.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/BUILD`

Added `"//submodules/Novagram/Localization:NovagramLocalization"` to `deps`.

Reason: `ChatTextInputPanelNode.swift` now imports `NovagramLocalization` to localize the camera-picker action sheet.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`

**Top of file — imports block.** Add after `import NovagramSpeechToText`:

```swift
import NovagramLocalization
```

**Inside `presentCameraSelection` closure (around line 925) — replace hardcoded strings.** Was:

```swift
ActionSheetButtonItem(title: "Oldi Camera", ...)
ActionSheetButtonItem(title: "Orqa Camera", ...)
```

Replace with:

```swift
// Novagram: localized camera picker labels (was hardcoded "Oldi Camera"/"Orqa Camera").
let l10n = NovagramL10n(presentationInterfaceState.strings)
ActionSheetButtonItem(title: l10n.cameraPicker_front, ...)
ActionSheetButtonItem(title: l10n.cameraPicker_back, ...)
```

`cameraPicker_front` / `cameraPicker_back` strings: en "Front Camera" / "Back Camera", uz "Old kamera" / "Orqa kamera", ru "Передняя камера" / "Задняя камера".

Reason: the original Novagram implementation hardcoded Uzbek-only labels visible to all users. `presentationInterfaceState.strings` is already in scope (the surrounding block uses it), so creating `NovagramL10n` from it costs nothing extra.

---

## 📌 First-launch Tips + App Store update check (2026-06-08)

Two new Novagram modules: `NovagramTips` and `NovagramUpdateCheck`. Both fire post-login via a single deferred block in `AuthorizedApplicationContext.init`.

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list, append (alongside the existing Novagram deps):

```python
"//submodules/Novagram/Tips:NovagramTips",
"//submodules/Novagram/UpdateCheck:NovagramUpdateCheck",
```

### `submodules/TelegramUI/Sources/ApplicationContext.swift`

**Imports — append after `import BrowserUI`:**

```swift
import NovagramTips
import NovagramUpdateCheck
```

**At the very end of `AuthorizedApplicationContext.init(...)` — after the `VoiceChatController` overlay block, before the closing `}`:**

```swift
// Novagram: post-login feature tips + App Store update check.
// Deferred 1s so the Chats tab finishes its layout before a modal appears
// (same pattern as the contacts auto-prompt deferral documented in HOOKS.md).
// Tips take priority on first launch; update check runs on subsequent launches.
let capturedContext = self.context
let capturedRootController = self.rootController
Queue.mainQueue().after(1.0, {
    let presentationData = capturedContext.sharedContext.currentPresentationData.with { $0 }
    guard let topVC = capturedRootController.viewControllers.last as? UIViewController else { return }
    if NovagramTipsScreen.shouldShowOnFirstLaunch {
        // First launch: show Tips screen (update check runs next launch).
        let tipsVC = NovagramTipsScreen.makeController(presentationData: presentationData)
        topVC.present(tipsVC, animated: true)
    } else {
        // Subsequent launches: non-blocking update check.
        NovagramUpdateChecker.checkAndPresentIfNeeded(on: topVC, presentationData: presentationData)
    }
})
```

Reason: the Tips screen must present on the stable Chats window (not racing the auth→tab-bar transition). Both features depend on a live `AccountContext` (theme, language) so they belong here, not in `AppDelegate`. The 1s defer matches the existing contacts-auto-prompt deferral pattern. Tips fires once (guarded by `fenixuz_tips_shown` in `pro_messager` UserDefaults). The update check fires on every subsequent launch but shows at most one alert per session (`sessionAlertShown` static flag in `NovagramUpdateChecker`).

---

## 📌 Unread Message Reminder / Xabar eslatmasi (2026-06-22)

New Novagram module `NovagramUnreadReminder` (`submodules/Novagram/UnreadReminder/`). Client-side local reminder for unread messages. Settings live in NovagramPro (`NovagramSettingsController.swift`, "Xabar eslatmasi" section — pure Novagram module, no hook). The manager is started post-login from `ApplicationContext.swift`.

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list, append (alongside the existing Novagram deps):

```python
"//submodules/Novagram/UnreadReminder:NovagramUnreadReminder",
```

### `submodules/TelegramUI/Sources/ApplicationContext.swift`

**Imports — append after `import NovagramUpdateCheck`:**

```swift
import NovagramUnreadReminder
```

**Inside `AuthorizedApplicationContext.init(...)` — immediately after `let capturedRootController = self.rootController`, before the `Queue.mainQueue().after(1.0, { ... })` Tips/UpdateCheck block:**

```swift
// Novagram: start the unread-message reminder manager (Xabar eslatmasi).
// Self-retained per account; tracks unread state and schedules a local reminder.
NovagramUnreadReminderManager.startIfNeeded(context: capturedContext)
```

Reason: the manager needs a live `AccountContext` (engine + accountManager) to subscribe to the account's total unread count via the public `renderedTotalUnreadCount(accountManager:engine:)` signal, so it belongs here (one `AuthorizedApplicationContext` per primary account). It is **not** deferred — unread tracking should begin as soon as the session is authorized. The manager self-retains in a private static `[Int64: NovagramUnreadReminderManager]` keyed by account peer id (so the hook stays a single additive line instead of requiring a new stored property on `AuthorizedApplicationContext`). All scheduling uses `UNUserNotificationCenter`; the reminder fires only when the app is backgrounded with messages unread past the configured threshold, and is cancelled on read (count → 0) or foreground. Settings keys (in `pro_messager` suite): `unread_reminder_enabled` (Bool, default false), `unread_reminder_minutes` (Int, default 5), `unread_reminder_sound` (String, default "default").

---

## 📌 Gold "Novagram" Settings row (2026-06-08)

Owner request: the **Novagram** entry in Settings must be gold ("tilla") so it stands out in the list.
The row now renders a gold title + a gold **flame** icon (Novagram = phoenix/fire branding) instead of the
old grey `PresentationResourcesSettings.security` shield.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/ListItems/PeerInfoScreenDisclosureItem.swift` — generic `titleColor`

Added an optional `titleColor: UIColor? = nil` to `PeerInfoScreenDisclosureItem` (property + init param)
and changed the one line that sets the title colour:
`let textColorValue = item.titleColor ?? presentationData.theme.list.itemPrimaryTextColor`.
Generic + additive: every other disclosure row passes `nil` and is unchanged; only the Novagram row
overrides it. No BUILD change.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` — gold Novagram row

`+import NovagramMessenger` (BUILD already depends on `//submodules/Novagram/Messenger:NovagramMessenger`).
The Novagram row now passes `titleColor:` a theme-adaptive gold — `0xFFCC33` (dark) / `0xC8951A` (light,
deeper for white-background contrast) — and `icon: novagramSettingsIcon(systemName: "flame.fill", color: .gold)`.

### `submodules/Novagram/Messenger/Sources/NovagramSettingsIcons.swift` (Novagram-owned)

Made `NovagramIconColor` enum + `novagramSettingsIcon(systemName:color:)` `public` so the icon helper can be
reused from the PeerInfoScreen module, and added a `.gold` case (`0xD4AF37` classic metallic gold).

---

## 📌 Ghost mode ad-reporting suppression (2026-06-08, Task #7)

### `submodules/TelegramCore/Sources/TelegramEngine/Messages/AdMessages.swift`

Three functions call TG servers to report ad views/clicks. All three are guarded with the
`isNovagramGhostModeActive` check so no sponsored-message telemetry is sent while Ghost mode is ON.

**1. `AdMessagesHistoryContextImpl.markAsSeen(opaqueId:)` (~line 592)**
Return type: `Void` (sets a disposable on `maskAsSeenDisposables` and returns). Guard before the signal:

```swift
// Novagram Ghost mode: do NOT report "seen" to TG servers when ghost is active.
if isNovagramGhostModeActive { return }
```

**2. `_internal_markAdAction(account:opaqueId:media:fullscreen:)` (~line 688)**
Return type: `Void`. Guard at top of function:

```swift
// Novagram Ghost mode: do NOT report ad clicks to TG servers when ghost is active.
if isNovagramGhostModeActive { return }
```

**3. `_internal_markAdAsSeen(account:opaqueId:)` (~line 704)**
Return type: `Void`. Guard at top of function:

```swift
// Novagram Ghost mode: do NOT report sponsored message views to TG servers when ghost is active.
if isNovagramGhostModeActive { return }
```

`isNovagramGhostModeActive` is the existing internal global in
`submodules/TelegramCore/Sources/Novagram/NovagramGhostMode.swift` — same module, no import needed.
These guards cover both the chat sponsored-message context (`AdMessagesHistoryContextImpl`) AND the
global-search sponsored-peer context (both eventually call the `_internal_*` free functions).

---

## 📌 Ghost mode nav-button new icons (2026-06-08, Task #13)

### New imagesets in `submodules/TelegramUI/Images.xcassets/Contact List/`

Two new imagesets added with user-supplied vector PDFs:

**`NovagramGhostActive.imageset`** — purple filled ghost with dark eyes (multicolor PDF).

- `Contents.json`: single universal PDF, `preserves-vector-representation: true`, **no** `template-rendering-intent`.
- Used for Ghost ON state. Rendered with `.alwaysOriginal` so purple + dark eyes are preserved.

**`NovagramGhostInactive.imageset`** — thin outline ghost (near-invisible raw; needs tint).

- `Contents.json`: single universal PDF, `preserves-vector-representation: true`, `template-rendering-intent: template`.
- Used for Ghost OFF state. Rendered as template tinted `panelControlColor` (grey).

### `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift`

Added new `Content` case:

```swift
case iconOriginal(imageName: String)
```

This renders a bundle PDF asset with `.alwaysOriginal` rendering mode, preserving multicolor (no tint).
Cache key suffix `:original` ensures toggling between `iconOriginal` / `iconTinted` forces a re-render.
All existing `.text` / `.more` / `.icon` / `.systemIcon` / `.iconTinted` / `.proxy` cases are unchanged.

### `submodules/ChatListUI/Sources/ChatListController.swift` — `updateGhostModeButton()` (~line 7416)

Ghost button content is now state-dependent:

```swift
let ghostContent: NavigationButtonComponent.Content = isGhostModeActive
    ? .iconOriginal(imageName: "Contact List/NovagramGhostActive")
    : .iconTinted(imageName: "Contact List/NovagramGhostInactive", accent: false)
```

- ON → `NovagramGhostActive` rendered original (purple filled, multicolor).
- OFF → `NovagramGhostInactive` rendered template tinted `panelControlColor` (grey outline, clearly visible).

---

## 📌 Multi-account notification clear-on-read fix (2026-06-08)

**Bug:** Delivered push notifications were NOT removed when the user opened/read a chat on a non-primary account. They piled up. Root cause: the clear-on-read subscription was wired only to the primary account (`ApplicationContext.swift:777`). With the dynamic multi-account working-set (cap=5), up to 5 accounts can be live simultaneously, each receiving push notifications from its own Telegram server session.

### `submodules/TelegramUI/Sources/SharedNotificationManager.swift`

Two new private properties added inside the class:

```swift
private var readClearDisposables: [AccountRecordId: Disposable] = [:]
private var readClearAccountsDisposable: Disposable?
```

In `init(...)`, after the existing `accountsAndKeysDisposable` block, a new subscription is added that observes the same `accounts: Signal<[(Account, Bool)], NoError>` signal already passed to `SharedNotificationManager`. For each emission:

1. Dispose and remove entries for accounts that left the live set.
2. For accounts that just entered the live set (no existing entry), subscribe to `account.stateManager.appliedIncomingReadMessages` and call `clearNotificationsManager.append(id)` + `commitNow()` for each emitted `[MessageId]`.

The `deinit` disposes `readClearAccountsDisposable` and all entries in `readClearDisposables`.

`SharedNotificationManager` already holds `clearNotificationsManager` and receives the `accounts` signal — no new dependencies needed. The primary account is in the live set, so it is also handled here.

Reason: `SharedNotificationManager` is the natural home because (a) it already holds `clearNotificationsManager`, (b) it already receives the live-accounts signal, and (c) it is account-manager-scoped (not primary-scoped like `AuthorizedApplicationContext`).

### `submodules/TelegramUI/Sources/ApplicationContext.swift` (line ~777)

The per-primary subscription:

```swift
self.removeNotificationsDisposable = (context.account.stateManager.appliedIncomingReadMessages
|> deliverOnMainQueue).start(next: { [weak self] ids in
    if let strongSelf = self {
        strongSelf.context.sharedContext.applicationBindings.clearMessageNotifications(ids)
    }
})
```

was replaced with a comment. `SharedNotificationManager` now covers all live accounts including the primary, so this subscription is redundant and would cause double-clearing if kept. `removeNotificationsDisposable` stays declared and nil'd; its `dispose()` call in `deinit` is a safe no-op.

### `submodules/TelegramUI/Sources/AppDelegate.swift` (line ~443, secondary fix)

In the `getNotificationIds` closure inside `ClearNotificationsManager.init(...)`, the `peerId` construction from notification `userInfo` now has a fallback:

```swift
// Novagram: NSE writes the full int64 PeerId as "peerId" in userInfo.
// Fall back to it if from_id/chat_id/channel_id were absent.
if peerId == nil {
    if let peerIdRaw = payload["peerId"] as? String, let peerIdInt = Int64(peerIdRaw) {
        peerId = PeerId(peerIdInt)
    } else if let peerIdRaw = payload["peerId"] as? Int64 {
        peerId = PeerId(peerIdRaw)
    }
}
```

This improves identifier match rate for notifications where the NSE stored a full `PeerId` int64 but the standard `from_id`/`chat_id`/`channel_id` keys were absent (e.g. encrypted payload fallback path).

**Silent-removal check:** The removed primary subscription produced one behavior: clear delivered notifications when the primary account's chats were read. That behavior is fully preserved by `SharedNotificationManager`'s new per-account subscriptions (primary is always in the live set). No previously-working behavior is dropped.

---

## 📌 2026-06-09 — multi-account + Ghost session fixes

Four fixes shipped together this day.

### 1. Ghost mode "read on send" — `submodules/TelegramCore/Sources/PendingMessages/EnqueueMessage.swift`

New Novagram file (NOT a hook in a Telegram-owned file): `submodules/TelegramCore/Sources/Novagram/NovagramGhostReadOnSend.swift` —
`public func novagramForceReadHistory(account:peerId:)`. No-op when Ghost is off. When Ghost is on it does the canonical
local read (`_internal_applyMaxReadIndexInteractively`) AND fires a direct `messages.readHistory` / `channels.readHistory`
for the peer (bypassing the Ghost suppression in `SynchronizePeerReadState.swift`), so replying reveals the read state.
Auto-globbed by `TelegramCore/BUILD` (`Sources/**/*.swift`).

**2026-06-11 — hook MOVED to the core enqueue funnel.** The original hook lived in
`ChatController.sendMessages(...)` (TelegramUI). It did not reliably fire for the actual text-send path (the badge
stayed unread after replying in Ghost). The fix moves it to the single function every send path funnels through:
`public func enqueueMessages(account:peerId:messages:)` in `EnqueueMessage.swift`:

```swift
return account.postbox.transaction { transaction -> [MessageId?] in
    let result = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages)
    // Ghost: sending implies reading — clear the local unread badge inside the send transaction.
    // MUST use namespace: .Cloud — the namespace-agnostic top returns the just-enqueued PENDING
    // (Local-namespace) message and marks the WRONG read state, leaving Cloud incoming unread.
    if isNovagramGhostModeActive, let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
        _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: account.stateManager, index: topIndex)
    }
    return result
}
|> afterCompleted {
    // Push the read receipt to the server so the other side sees "read".
    if isNovagramGhostModeActive { let _ = novagramForceReadHistory(account: account, peerId: peerId).startStandalone() }
}
```

**Two root causes (both fixed, verified on simulator — unread count 1→0):**

1. **Hook placement:** the old `ChatController.sendMessages` hook never fired for text replies — text sends route through
   `ChatControllerLoadDisplayNode.swift:981` (`chatDisplayNode.sendMessages` closure) → `enqueueMessages(account:…)`,
   NOT `controller.sendMessages`. Core-level placement in `enqueueMessages` is UI-path-independent.
2. **Namespace:** `getTopPeerMessageIndex(peerId:)` (no namespace) returns the just-enqueued pending message in
   `Namespaces.Message.Local`; applying the read there does not clear the Cloud incoming unread. Must pass `.Cloud`.

Reason: Ghost suppresses passive read receipts; without this, sending a reply leaves the incoming messages unread (local
badge + server). The old `ChatController` hook was removed (a 3-line pointer comment is left at the former site).
`novagramForceReadHistory` also uses `.Cloud` for both the local read and the server `maxId`.

### 2. Pinned "Active / No Sleep" accounts stay live — `submodules/TelegramUI/Sources/SharedWakeupManager.swift`

Root cause of "pinned account gets no background notification": `updateAccounts()` only granted
`shouldBeServiceTaskMaster = .always` to the foreground primary; pinned non-primary accounts got `.never`, which closes
their MTProto connection (`Account.swift:1377-1386` → `network.shouldKeepConnection`). So they never received messages until
switched to.

New helper before `updateAccounts(...)`:

```swift
private func novagramPinnedIds() -> Set<Int64> {
    let arr = (UserDefaults(suiteName: "pro_messager")?.array(forKey: "fenixuz_active_accounts") as? [Int64]) ?? []
    return Set(arr)
}
```

At the top of `updateAccounts(...)`: `let novagramPinned = self.novagramPinnedIds()`. In the active-branch
`for (account, primary, tasks)` loop the condition changed from `(self.inForeground && primary)` to
`(self.inForeground && (primary || isPinnedWorkingSet))` where `let isPinnedWorkingSet = novagramPinned.contains(account.id.int64)`.
Suspended (non-working-set) accounts are not in `accountsAndTasks`, so they stay suspended. Key/format matches
`SharedAccountContextImpl.novagramLoadPinnedAccounts()` exactly (`pro_messager` / `fenixuz_active_accounts` as `[Int64]`).

### 3. Tab-bar account switcher rows show avatar + username — `PeerInfoScreen.swift` (updates the 2026-06-08 entry above)

New Novagram file (auto-globbed, no BUILD change): `…/PeerInfoScreen/Sources/NovagramAccountSwitchContextItem.swift` — a
`ContextMenuCustomItem` modeled on `AccountPeerContextItem`: left = 30pt colored initials avatar, two lines (name +
`@username`/`+phone`), tap → `switchToAccount`. In `tabBarItemContextAction`, the non-current `novagramAllAccountsValue` loop now
appends `.custom(NovagramAccountSwitchContextItem(...), false)` instead of a text-only `ContextMenuActionItem` with an arrow icon.
Username read once from `UserDefaults("pro_messager")["fenixuz_account_usernames"]` keyed by `String(peerId)`.

### 4. QR login overlay (fixes overlap) — `AuthorizationSequencePhoneEntryControllerNode.swift` (updates the 2026-06-08 QR entry above)

`qrLoginButtonTapped` / `debugQrTap` no longer create a 200x200 `qrNode` pinned at top-left (which overlapped the form). Both
now call a new `showQrOverlay()` that builds a full-bleed `ASDisplayNode` overlay (theme background) over the form, vertically
centered: title + 240x240 QR `ASImageNode` + instruction text + a `Common_Cancel` button. `dismissQrOverlay()` disposes the token
loop and restores the form; `applyQrOverlayLayout()` re-centers it in `containerLayoutUpdated`. `refreshQrToken()` is unchanged.

---

## 📌 2026-06-09 (b) — Ghost mode: close remaining seen/presence leaks

Audit of all client→server "seen/read/view/typing" signals found 2 genuine gaps (the other
candidates — typing, story-read, content-consumed, online presence — were already guarded via the
INLINE `UserDefaults(suiteName: "pro_messager").bool(forKey: "is_ghost_mode_active")` form at
`ManagedLocalInputActivities.swift:145`, `ManagedSynchronizeViewStoriesOperations.swift:122`,
`MarkMessageContentAsConsumedInteractively.swift:7`, `ManagedAccountPresence.swift:46`).

### `submodules/TelegramCore/Sources/State/ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift`

`synchronizeMarkAllUnseenReactions(...)` (~line 290) — guard at the top, before the peer guards:

```swift
if isNovagramGhostModeActive {
    return .complete()
}
```

Suppresses the `messages.readReactions` sync (marking "I've seen who reacted to my messages") when Ghost is on. Return type `Signal<Void, NoError>`. (The separate guard at ~143 targets `readMessageContents` inside `oneOperation` — a different function.)

### `submodules/TelegramCore/Sources/State/AccountViewTracker.swift`

`getMessagesViews` call (~line 723) — increment flag made conditional:

```swift
increment: isNovagramGhostModeActive ? .boolFalse : .boolTrue
```

When Ghost is on, channel post view counters are NOT bumped, but the request still runs so the user still SEES view counts (no UI regression). Deliberately NOT a blanket guard.

---

## 📌 2026-06-16 — quick-wins batch (haptic, voice-translate, chat-lock biometric)

### `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift` — menu haptic (#42)

**Inside `pressed()` (~line 103):** a `switch self.component?.content` guard fires a `UIImpactFeedbackGenerator(style: .light)` only for the three Novagram-added content types — `.iconOriginal`, `.iconTinted`, and `.systemIcon`. The upstream cases `.icon`, `.text`, `.more`, and `.proxy` deliberately fall through with no haptic so existing upstream button UX is unchanged.

```swift
@objc private func pressed() {
    // Novagram: light haptic for Novagram-added icon button types (iconOriginal, iconTinted, systemIcon).
    switch self.component?.content {
    case .iconOriginal, .iconTinted, .systemIcon:
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    default:
        break
    }
    self.component?.pressed(self)
}
```

Reason: upstream `.pressed()` had no haptic. Novagram ghost-mode, STT, and header buttons use the three new content types; the haptic covers all of them in one place without touching the upstream `.icon`/`.text`/`.more`/`.proxy` code paths (those belong to upstream UX — changing them would affect chat navigation buttons, compose button, proxy button, etc.).

---

### `submodules/ChatListUI/Sources/ChatListController.swift` — story-camera button haptic (#42)

**Inside the story-camera `NavigationButtonComponent` pressed closure (~line 7177):**

```swift
// Novagram: light haptic on story camera button tap.
let generator = UIImpactFeedbackGenerator(style: .light)
generator.impactOccurred()
```

Inserted immediately before the existing `parentController.displayContinueLiveStream()` / `openStoryCamera(fromList:)` branch.

Reason: the story-camera button uses `.icon(imageName:)` content type — the upstream case that `NavigationButtonComponent.pressed()` intentionally does NOT add haptic to. The story-camera is a Novagram UX surface (custom placement, custom icon `"Chat List/AddStoryIcon"`) and should have haptic feedback; adding it here in the action closure is the only path that works without touching the upstream `.icon` render path.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — STT haptic + voice→translate (#42, #25)

**`sttButtonPressed()` (~line 5904) — two Novagram additions:**

**1. Haptic (#42):**

```swift
// Novagram: selection haptic on STT record start/stop toggle.
let sttHaptic = UISelectionFeedbackGenerator()
sttHaptic.selectionChanged()
```

Fires at the very start of `sttButtonPressed()` before the early-return for the `isSttRecording` case, so both start and stop get feedback.

**2. Voice→translate (#25):**

```swift
// Novagram #25: translate the finished transcription before it lands in the input field.
// Inline TelegramCore translate (importing NovagramMessenger here would create a module cycle).
// The on/off flag + target language are read inside SpeechToTextManager from "pro_messager".
self.sttManager?.translateHandler = { [weak self] text, lang, completion in
    guard let self, let context = self.context else {
        completion(text)
        return
    }
    let _ = (context.engine.messages.translate(text: text, toLang: lang)
    |> deliverOnMainQueue).startStandalone(next: { result in
        completion(result?.0 ?? text)
    }, error: { _ in
        completion(text)
    })
}
```

Set immediately after `self.sttManager` is created/reused. The translate-on/off flag and target language are read inside `SpeechToTextManager` from the `pro_messager` UserDefaults suite — not here. If translation is disabled or the engine call fails, `completion(text)` passes through the raw transcription unchanged. The `translateHandler` is an inline closure rather than a separate module import because importing `NovagramMessenger` from `ChatTextInputPanelNode` (which is a dependency of `TelegramUI`, which is a dependency of `NovagramMessenger`) would create a circular module dependency.

---

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — chat-lock context menu with passwordType (#46)

**Around lines 494–513 — the `.remove` and `.set` callers in the per-chat pincode context-menu action:**

`.remove` caller (~line 494): `ChatPincodeViewController(mode: .remove(passwordType: ChatPincodeManager.shared.getMetadata(for: peerId).passwordType, onVerify: ..., onSuccess: ...))` — passes `passwordType:` read from `getMetadata(for:)` so the verify screen shows dots (PIN) or a text field (alphanumeric) matching whatever the user set up.

`.set` caller (~line 505): `ChatPincodeViewController(mode: .set(onSuccess: { code, passwordType, biometricEnabled in ChatPincodeManager.shared.setPincode(code, for: peerId, type: passwordType, biometricEnabled: biometricEnabled) }))` — the `onSuccess` closure now carries `(code, passwordType, biometricEnabled)` and forwards all three to `ChatPincodeManager.setPincode(_:for:type:biometricEnabled:)`.

Reason: `ChatPincodeMode.remove` and `.set` gained `passwordType:` and `biometricEnabled:` parameters when `NovagramChatLock` was updated to support both PIN and alphanumeric passwords. These call sites in the upstream-owned `ChatContextMenus.swift` must match the new API signatures or the project will not build. `getMetadata(for:)` is a new public method on `ChatPincodeManager.shared` that returns a `ChatLockMetadata` struct carrying both `passwordType` and `biometricEnabled`.

---

### `submodules/TelegramUI/Sources/NavigateToChatController.swift` — chat-lock verify gate with passwordType + biometricEnabled (#46)

**`navigateToChatControllerImpl(_:)` (~line 38):** the `.verify` caller now passes both `passwordType:` and `biometricEnabled:` sourced from `ChatPincodeManager.shared.getMetadata(for: targetPeerId)`:

```swift
let pincodeVC = ChatPincodeViewController(
    mode: .verify(
        passwordType: ChatPincodeManager.shared.getMetadata(for: targetPeerId).passwordType,
        biometricEnabled: ChatPincodeManager.shared.getMetadata(for: targetPeerId).biometricEnabled,
        onVerify: { code in
            ChatPincodeManager.shared.verify(code, for: targetPeerId)
        },
        onSuccess: { ... }
    ),
    presentationData: presentationData
)
```

Reason: same API change as above — `ChatPincodeMode.verify` now requires `passwordType:` and `biometricEnabled:`. This is the gate that intercepts every chat navigation and shows the lock screen before opening the chat; it must pass the correct credential type so the lock screen renders dots (PIN) or a text field, and the correct biometric flag so Face ID / Touch ID is attempted on appear.

---

## 📌 2026-07-03 — Feature #46: Master Pincode (Chat Lock master toggle + "Forgot pincode?" recovery)

A single global **master** pincode now gates the whole per-chat lock feature and doubles as a recovery key. It is set from **Settings → NovagramPro → Protection → "Chat Lock"** and lives entirely in `NovagramChatLock` (`ChatPincodeManager` master API: `isMasterEnabled()`, `setMasterPincode(_:type:biometricEnabled:)`, `verifyMaster(_:)`, `getMasterMetadata()`, `removeMaster()`, `disableChatLock()`; stored under the reserved keychain / UserDefaults-fallback account `__fenix_master__`, which cannot collide with a numeric `peerId.toInt64()`). Two upstream hooks below; everything else is inside Novagram modules.

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — gate the per-chat lock item behind the master (#46) — 2026-07-03

The per-chat "Set / Remove Pincode" context-menu item (the `if !isSavedMessages {` block right after the `// MARK: - Pincode lock/unlock` comment, ~line 488) is now additionally gated by the master:

```swift
// Novagram #46: per-chat lock item only appears once a master pincode is set.
if !isSavedMessages && ChatPincodeManager.shared.isMasterEnabled() {
```

Reason: per spec the per-chat "Set Pincode" action must only appear once a master pincode has been configured. `ChatPincodeManager.shared.isMasterEnabled()` is the single source of truth. Applied via Python (not Edit) to keep the upstream diff minimal.

### `submodules/TelegramUI/Sources/NavigateToChatController.swift` — "Forgot pincode?" master recovery in the verify gate (#46) — 2026-07-03

The `.verify` gate that intercepts navigation to a locked chat (~line 40) now passes `onForgot:` (a closure only when `ChatPincodeManager.shared.isMasterEnabled()`, else `nil`). Tapping "Forgot pincode?" presents a SECOND `ChatPincodeViewController` in `.verify` mode against the MASTER (`getMasterMetadata()` type/biometric, `verifyMaster(_:)`). On master success it removes THIS chat's lock (`removePincode(for: targetPeerId)`), dismisses the lock UI, sets `chatPincodeBypassPeerId = targetPeerId`, re-calls `navigateToChatControllerImpl(params)`, then resets the bypass — mirroring the existing `onSuccess` bypass pattern. A `weak var weakLockNav` holds the first nav controller so the master screen can be presented on top of it without a retain cycle. The master screen is created with `ChatPincodeViewController(..., isMasterRecovery: true)` (2026-07-03) so it renders a distinct title/subtitle ("Enter master pincode" / "Unlocks this chat and removes its pincode") instead of the identical-looking "Enter PIN" / "Chat is locked" — users kept getting confused about what to type. `isMasterRecovery` is a plain init param (default `false`), NOT a `.verify` associated value, so no other call site or destructure changes.

Reason: `ChatPincodeMode.verify` gained an optional `onForgot: (() -> Void)? = nil` associated value (Swift allows default values on enum associated values, so every other caller keeps compiling; the only `.verify` construction site in the whole tree is this gate). The recovery flow needs the file-private `chatPincodeBypassPeerId` and must re-enter `navigateToChatControllerImpl`, so it has to live in this upstream file. Applied via Python (not Edit) to keep the upstream diff minimal.

---

## 📌 2026-06-16 (c) — folder unlock + chat-lock menu localization

### `submodules/TelegramCore/Sources/State/UserLimitsConfiguration.swift` (~line 163)

`self.maxFoldersCount = max(1000, getValue("dialog_filters_limit", ...))` — lifts the CLIENT-side folder-count gate so the Premium "Limit Reached" upsell never triggers. NOTE: the Telegram **server** still enforces its own cap on `messages.updateDialogFilter`, so true count is server-bounded.

### `submodules/ChatListUI/Sources/ChatListFilterPresetListController.swift` (~line 282)

`var effectiveDisplayTags: Bool? = displayTags` (was gated by `if isPremium`) — unlocks the "Show Folder Tags" toggle for everyone. Tag rendering is fully client-side.

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` (~line 484)

`pincodeTitle` now uses `NovagramChatLockStrings.menuRemove / .menuSet` (localized en/uz/ru) instead of the hardcoded Uzbek `"🔒 Pincode qo'yish"`.

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — Copy Chat ID (#24) — 2026-06-17

After the chat-lock Pincode block (~line 514), a "Copy Chat ID" context-menu action was added (guarded by `if !isSavedMessages`). It copies `peerId.toInt64()` to `UIPasteboard.general.string` and shows an `UndoOverlayController(.copy(text:))` confirmation. Titles are inline en/uz/ru (no Localization-module dependency). No toggle — the action is always present. Applied via Python (not Edit) to keep the upstream diff minimal.

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — Secret read localization — 2026-06-17

Secret-read context-menu item (~line 470) had a hardcoded Uzbek title; localized to inline en/uz/ru via languageCode. Behavior unchanged (isSecretRead: true). Python.

### `submodules/TelegramUI/Sources/ChatController.swift` — Sticker send-confirm all-branches fix (#38) — 2026-06-17

The #38 sticker confirm initially sat only in the silentPosting branch (so normal sends bypassed it). Moved to the top of the sendSticker callback to cover every branch; a fenix_sticker_bypass UserDefaults flag re-sends after the user confirms. Python.

### `submodules/TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift` — Voice send confirm (#38) — 2026-06-17

Voice confirm was first mis-placed at micButton.stopRecording (ChatTextInputPanelNode) — but stopMediaRecording() auto-sends, so the dialog came too late. Reverted that hook, and placed the confirm at the top of sendMediaRecording() (the actual voice send entry; auto-send routes here too) with a fenix_voice_bypass flag that re-sends after confirm. Python.

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — Camera picker keyboard fix (#29) — 2026-06-17

The front/back camera-selection ActionSheet presented in .window(.root) sat below the keyboard window (invisible when keyboard open). Added view.window?.endEditing(true) before present so the keyboard dismisses first. Python.

### `submodules/TelegramUI/Sources/TelegramRootController.swift` (~line 281) — 2026-06-16

Contacts tab re-enabled (`controllers.append(self.contactsController!)` uncommented). Was hidden during the Apple 5.1.2 contacts-privacy review; the `DeviceAccess.authorizeAccess(.contacts)` consent hook (see contacts-consent section above) now gates all contacts access, so the Find-Friends tab presents the consent alert before reading contacts.

---

## 📌 2026-06-17 — Feature #37: Send-Translate 2-tap confirm

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` (~line 4690) — Python bilan qo'llandi

`sendCurrentMessage(...)` ichida, mavjud `// PRO MESSAGER: Automatic Translation` (#31) anchor'dan OLDIN yangi `// NOVAGRAM-HOOK #37` bloki qo'shildi (qatorlar 4690–4756).

Maqsad: foydalanuvchi `translate_confirm_enabled` sozlamasini yoqsa, yuborishdan oldin tasdiq dialogi chiqadi. Mavjud `#31` avtomatik tarjimadan farqi — bu so'raydi, avtomatik qilmaydi.

Shart: `overrideText == nil && confirmEnabled && !proTranslateLang.isEmpty && currentInputText.length > 0 && !hasTranslateAttr`

Agar shart bajarilsa:

1. Input maydon tozalanadi (mavjud `#31` pattern bilan bir xil)
2. `textAlertController(context:title:text:actions:)` bilan alert ko'rsatiladi, `controller.present(..., in: .window(.root))` bilan present qilinadi
3. "Translate & Send" → `engine.messages.translate` → muvaffaqiyatda `pro_translated` attr bilan `sendCurrentMessage(overrideText:)`, xatoda fallback original + attr
4. "Send Original" → original matn + `pro_translated` attr bilan `sendCurrentMessage(overrideText:)` (qayta confirm oldini oladi)
5. `return` — `#31` hook ishlamaydi (confirm allaqachon hal qildi)

Anchor (noyob): `            // PRO MESSAGER: Automatic Translation\n`
Tasdiqlash: `python3 -c "content=open('...ChatControllerNode.swift').read(); assert content.count('// PRO MESSAGER: Automatic Translation') == 1"`

NOTE: there are TWO tab-build paths — the init (~line 223, startup) and `updateRootControllers` (~line 281, calls-tab toggle). BOTH now append `contactsController` so the Contacts tab shows at launch and survives a calls-tab refresh.

---

## 📌 2026-06-17 — Feature #38: Send-Confirm Dialog (voice, sticker, gift)

Sozlama: `pro_messager` UserDefaults `send_confirm_enabled` (default `false`). Toggle `NovagramSettingsController.swift` — Protection seksiyasida (stableId = 45), `NovagramSendConfirmStrings` namespace (public). Har 3 hook inline langCode switch ishlatadi (NovagramMessenger import → module cycle xavfi bor edi).

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — Python bilan qo'llandi, 2026-06-17

`mediaActionButtons.micButton.stopRecording` callback'iga `// NOVAGRAM-HOOK #38` bloki qo'shildi (~qator 905–950).

Logika: `send_confirm_enabled` true bo'lsa, `interfaceInteraction.stopMediaRecording()` + `tooltipController?.dismiss()` chaqirilgandan SO'NG `UIAlertController` (`.alert` style) ko'rsatiladi (textAlertController shu modulda mavjud emas — PresentationDataUtils dep yo'q). "Yuborish" → `sendRecordedMedia(false, false)`. "Bekor qilish" → `deleteRecordedMedia()`. False holda — asl xatti-harakat (to'g'ridan-to'g'ri send).

Present: `UIApplication.shared.windows.first?.rootViewController` orqali top presented VC.

Anchor (noyob Python): START=`self.mediaActionButtons.micButton.stopRecording = { [weak self] in\n`, END=`        self.mediaActionButtons.micButton.updateLocked = { [weak self] _ in`.

### `submodules/TelegramUI/Sources/ChatController.swift` — Python bilan qo'llandi, 2026-06-17

`sendSticker:` callback ichida, `addToTransitionNodeIfNeeded()` dan keyin `// NOVAGRAM-HOOK #38` bloki qo'shildi (~qator 2414–2457).

Logika: `send_confirm_enabled` true bo'lsa, `transformEnqueueMessages` avval bajariladi va `textAlertController(context:updatedPresentationData:title:text:actions:)` bilan dialog ko'rsatiladi. "Yuborish" → `sendMessages(novagramTransformed)`. "Bekor qilish" → bo'sh. Present: `strongSelf.present(... in: .window(.root))`.

Anchor (noyob Python): `addToTransitionNodeIfNeeded()\n                    let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting, postpone: postpone)\n                    strongSelf.sendMessages(transformedMessages)\n                } else if schedule {`.

### `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` — Python bilan qo'llandi, 2026-06-17

`sendGift` context menu action ichiga `// NOVAGRAM-HOOK #38` bloki qo'shildi (~qator 1162–1204).

Logika: `send_confirm_enabled` true bo'lsa, `f(.dismissWithoutContent)` avval chaqiriladi (context menu yopiladi), keyin `textAlertController(context:title:text:actions:)` dialog. "Yuborish" → `controllerInteraction?.sendGift(message.id.peerId)`. "Bekor qilish" → bo'sh. Present: `controllerInteraction?.presentController(novagramAlert38, nil)`.

Anchor (noyob Python): `            }, action: { _, f in\n                let _ = controllerInteraction.sendGift(message.id.peerId)\n                f(.dismissWithoutContent)\n            })))`.

## 📌 2026-06-17 — Feature #30: Sticker Auto-Add (after text message)

Sozlama: `pro_messager` UserDefaults `auto_sticker_enabled` (default `false`). Toggle `NovagramSettingsController.swift` — Messaging seksiyasida (stableId = 28), `NovagramAutoStickerStrings` private namespace. Disable qilinganda `auto_sticker_data` key ham o'chiriladi.

Saqlash: sticker yuborilganda `PostboxEncoder.encodeRootObject(TelegramMediaFile)` → `makeData()` → `base64EncodedString()` → `auto_sticker_data` key'iga yoziladi.

Yuborish: `sendCurrentMessage` ichida `sendMessages(...)` chaqirilishidan OLDIN `PostboxDecoder(buffer: MemoryBuffer(data:)).decodeRootObject() as? TelegramMediaFile` bilan decode → `FileMediaReference.standalone(media:).abstract` → `EnqueueMessage.message(text:"", ...)` qo'shiladi. Faqat `.message` shaped birinchi elementli array'larda ishlaydi (forward-only holat bilan aralashmaydi).

### `submodules/TelegramUI/Sources/ChatController.swift` — Python bilan qo'llandi, 2026-06-17

`sendSticker:` callback ichida, `let replyMessageSubject = ...` va `let messages: [EnqueueMessage] = [...]` orasiga `// NOVAGRAM-HOOK #30` bloki qo'shildi (~qator 2404–2413).

Logika: `fileReference.media` (non-optional `TelegramMediaFile`) → `PostboxEncoder.encodeRootObject` → `makeData().base64EncodedString()` → `UserDefaults(suiteName:"pro_messager").set(..., forKey:"auto_sticker_data")`.

Anchor (noyob Python): `let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject\n\n                let messages: [EnqueueMessage]  = [.message(text: "",`.

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` — Python bilan qo'llandi, 2026-06-17

`doSend` closure ichida, `self.sendMessages(messages, ...)` chaqirilishidan OLDIN `// NOVAGRAM-HOOK #30` bloki qo'shildi (~qator 5123–5152).

Logika: `auto_sticker_enabled` true + `messages` bo'sh emas + `messages[0]` `.message` case + `auto_sticker_data` base64 decode + `PostboxDecoder.decodeRootObject() as? TelegramMediaFile` → `FileMediaReference.standalone(media:).abstract` → yangi `EnqueueMessage.message(text:"", ...)` `messages` array oxiriga qo'shiladi.

Anchor (noyob Python): `                    self.sendMessages(messages, silentPosting, scheduleTime, repeatPeriod, messages.count > 1, postpone)\n                }`.

### `submodules/ItemListUI/Sources/Items/ItemListSwitchItem.swift` — titleBadge y-position fix — 2026-06-17

Native `titleBadgeComponent` (NEW badge) y-position used `(contentSize.height - badge)/2` — the full row center. On rows WITH a subtitle the badge dropped onto the subtitle text and covered words ("auto-downl[NEW]all networks"). Changed to `titleNode.frame.minY + (titleNode.height - badge)/2` so the badge aligns to the title line regardless of subtitle. Title-only rows (ChannelStatsController) unaffected — math identical. Python.

## 📌 2026-06-17 — Feature #34: Heart Effect (auto-attach ❤️ message effect)

Sozlama: `pro_messager` UserDefaults `heart_effect_enabled` (default `false`). Toggle `NovagramSettingsController.swift` — Messaging seksiyasida (stableId = 29), `NovagramHeartEffectStrings` private namespace.

Resolver: `NovagramHeartEffect` (xuddi shu fayl oxirida). Toggle ON bo'lganda `context.engine.stickers.availableMessageEffects()` dan `emoticon` `❤` bilan boshlanadigan NON-premium effektni topib, uning `id` sini `fenix_heart_effect_id` (Int) key'iga cache qiladi. `availableMessageEffects()` bir martalik cache read bo'lgani uchun sovuq cache holatida 4 marta (1.5s oraliq) retry qiladi.

No-Backend: heart effekt reaction-asosli (`isPremium == false`) — barcha userlar yubora oladi, Telegram serveri qabul qiladi. Premium emoji'dan farqli (theatre EMAS).

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` (~qator 5047) — Python bilan qo'llandi, 2026-06-17

`sendCurrentMessage` ichida, tanlangan effekt bloki (`if !messages.isEmpty, let messageEffect { ... }`) dan KEYIN `// NOVAGRAM-HOOK #34` bloki qo'shildi.

Logika: `heart_effect_enabled` true + foydalanuvchi effekt tanlamagan (`messageEffect == nil`) + `messages[0]` `.message` case + **private chat** (`chatLocation.peerId.namespace == CloudUser` — guruh/kanal/secret chatga BIRIKTIRMAYDI, native effekt private-only) + `fenix_heart_effect_id != 0` → `messages[0]` ga `EffectMessageAttribute(id:)` qo'shiladi (faqat allaqachon effekt yo'q bo'lsa). Foydalanuvchi qo'lda tanlagan effektni bekor qilmaydi, forward-only sendga tegmaydi.

Anchor (noyob Python): `attributes.append(EffectMessageAttribute(id: messageEffect.id))`.

## 📌 2026-06-17 — Feature #18: Folder Icon Picker

Native `ChatListFilter.emoticon: String?` allaqachon bor + serverga sync bo'ladi, lekin iOS folder-editorida uni tanlash UI yo'q edi. Qo'shildi.

### `submodules/ChatListUI/Sources/ChatListFilterPresetController.swift` — Python bilan qo'llandi, 2026-06-17

- State: `ChatListFilterPresetControllerState` ga `var emoticon: String?` qo'shildi; init `emoticon: initialPreset?.emoticon`.
- Arguments: `openIconPicker: () -> Void` qo'shildi.
- Yangi entry `.icon(emoticon:)` — Name seksiyasida, `ItemListDisclosureItem` ("Folder Icon" / "Papka ikonkasi", label = joriy emoji), tap → `arguments.openIconPicker()`.
- `openIconPicker`: `ActionSheetController` — 18 ta preset emoji (emoji-only buttonlar, til-neytral) + "Remove icon" (destructive) + Cancel; tanlash → `updateState { $0.emoticon = emoji }`.
- Save-sitelar (5): `.filter(... emoticon: currentPreset?.emoticon/initialPreset?.emoticon ...)` → `emoticon: state.emoticon` (foydalanuvchi tanlovi saqlanadi). Lines 879–1002 (kategoriya update'da emoticon-ni saqlovchi `emoticon: emoticon`) TEGILMADI.

Anchor (noyob Python): `var color: PeerNameColor?\n    var colorUpdated: Bool = false`.

## 📌 2026-06-20 — 2FA password screen "Back" button (login lockout fix)

Bug: 2-Step Verification "Your Password" ekrani BIRINCHI account login'da (boshqa account yo'q) navigation stack'ning ROOT'i bo'lib qoladi → back button yo'q → user qamalib qoladi, qaytish/dismiss imkonsiz. Tuzatish: root bo'lganda explicit "Back" tugmasi qo'shildi (signUp'dagi `displayCancel` patterniga o'xshash). Tugma `back()` ni chaqiradi (auth state'ni `.phoneEntry` ga qaytaradi).

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePasswordEntryController.swift` — 2026-06-20

- `private let back: () -> Void` property qo'shildi; init `back: @escaping () -> Void` ni `self.back = back` bilan saqlaydi.
- Init signature: `displayBack: Bool = true` parametri qo'shildi.
- `navigationBar?.backPressed = { [weak self] in self?.back() }` (oldin to'g'ridan-to'g'ri `back()` edi).
- `if displayBack { navigationItem.leftBarButtonItem = UIBarButtonItem(title: strings.Common_Back, style: .plain, target: self, action: #selector(self.backPressed)) }`.
- Yangi `@objc private func backPressed() { self.back() }`.

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceController.swift` — 2026-06-20

- Factory `passwordEntryController(hint:suggestReset:syncContacts:)` → `...syncContacts:displayBack:)`.
- Init call'ga `}, displayBack: displayBack)` qo'shildi.
- `.passwordEntry` case (~1326): `displayBack: self.otherAccountPhoneNumbers.1.isEmpty` (splash yo'q = root = tugma ko'rsatiladi; splash bor = auto back chevron ishlaydi, TEGILMADI).

## 📌 2026-06-20 — "Telegram" wordmark → "Novagram" (brand wordmarks only; extensions + targets)

User-visible joylarda app O'ZINI "Telegram" deb ko'rsatayotgan brand wordmark'lar Novagram'ga o'zgartirildi. FAQAT brand wordmark (app o'z nomi) — service/network/feature/URL/legal references TEGILMADI ("Telegram cloud", "Telegram Premium", "The Telegram Team", t.me, telegram.org, Telegram FZ-LLC, "Download Telegram on desktop" — bular Telegram tarmog'iga real ishora, o'zgarmaydi). en.lproj'da 264 ta "Telegram" qiymat bor — ~7 tasi brand wordmark edi (tuzatildi), qolgani service/feature (qoldi). Non-en tillar Telegram serveridan langpack orqali keladi (kodda o'zgartirib bo'lmaydi); barcha hardcoded fix'lar til-neytral.

### `submodules/TelegramCallsUI/Sources/CallKitIntegration.swift:161` — CallKit pill (CIRCLED)

- `CXProviderConfiguration(localizedName: "Telegram")` → `"Novagram"`. iOS qo'ng'iroq pill/Dynamic Island'da ko'rsatadigan nom. (Icon `Call/CallKitLogo` = monoxrom template glyph, TEGILMADI.)

### `Telegram/Share/en.lproj/Localizable.strings:2-3` — Share extension auth alert

- `Share.AuthTitle` "Log in to Telegram" → "Log in to Novagram"; `Share.AuthDescription` "Open Telegram and log in to share." → "Open Novagram...". (Main app allaqachon Novagram edi; extension o'z nusxasini saqlaydi — rebrand o'tkazib yuborgan.)

### `Telegram/WidgetKitWidget/en.lproj/Localizable.strings:2` — Widget extension

- `Widget.AuthRequired` "Open Telegram and log in." → "Open Novagram and log in.".

### `Telegram/SiriIntents/IntentHandler.swift:963` — Siri/Shortcuts widget-edit locked error

- `NSLocalizedDescriptionKey: "Open Telegram and enter passcode to edit widget."` → "Open Novagram...". (Hardcoded, langpack emas.)

### `submodules/WidgetItems/Sources/WidgetItems.swift:401` — widget locked text (yuqoridagining egizi)

- `generalLockedText: "Open Telegram and enter passcode to edit widget."` → "Open Novagram...".

### `Telegram/Telegram-iOS/en.lproj/Localizable.strings:7538` — notification sounds header

- `Notifications.TelegramTones` qiymati "TELEGRAM TONES" → "NOVAGRAM TONES" (app o'z bundled ohanglari; "SYSTEM TONES" ning yonida). KEY o'zgarmadi.

### `submodules/TelegramUI/Sources/StoreDownloadedMedia.swift:12` — Photos albom nomi

- `let albumName = "Telegram"` → `"Novagram"`. Bitta konstanta lookup (13-qator predicate) + create (25-qator) ni boshqaradi. Eski "Telegram" albom (agar bo'lsa) joyida qoladi — yangi saqlash "Novagram" albomga tushadi (kutilgan rebrand oqibati).

### Contact label (Contacts app'da ko'rinadi; SiriIntents extension o'qiydi)

- `submodules/AccountContext/Sources/DeviceContactData.swift:211` — WRITE: `label: "Telegram"` → `"Novagram"`.
- READ sitelar (backward-compat — eski "Telegram" yozuvlar buzilmasligi uchun IKKALASINI ham match qiladi):
  - `submodules/TelegramUI/Sources/DeviceContactDataManager.swift:148,161,215` (×3) va `Telegram/SiriIntents/IntentContacts.swift:77`: `address.label == "Telegram"` → `(address.label == "Telegram" || address.label == "Novagram")`.

**Barcha edit'lar Python/Bash bilan qilingan (Edit-tool formatter'ni chetlab o'tish uchun) → minimal diff, upstream stil saqlangan.**

Anchor: `case let .passwordEntry(hint, _, _, suggestReset, syncContacts):` va `private func passwordEntryController(hint: String, suggestReset: Bool, syncContacts: Bool`.

## WatchApp restoration (12.8 sync, Phase 6 — 2026-06-22)

The standalone `tgwatch` SwiftUI watch app was deleted from the fork; restored from `upstream/master` (12.8). **Zero Novagram hooks live inside `Telegram/WatchApp/`** (verified). Off by default (`embedWatchApp=False`) → **zero effect on simulator `./run.sh`** (build green + app launches, 0 watch build lines). Legacy ObjC `Telegram/Watch/` left untouched.

**What was restored (verbatim from upstream):**

- `Telegram/WatchApp/` (957 files: `tgwatch.xcodeproj` SwiftUI app + SPM packages TDShim/RLottieKit/WebPKit/OpusKit/QRCodeGenerator).
- Glue: `Telegram/prebuilt_watchos.bzl`, `Telegram/prebuilt_watchos_build.sh`.
- `build-system/Make/Make.py` + `RemoteBuild.py` — taken wholesale from upstream (fork had **no** own changes to these; verified no novagram/novagram/apiId markers), restoring the `--embedWatchApp` flow (`set_watch_app`, `resolve_watch_provisioning_profile`, argparse args).

**Novagram customization inside the watch tree (re-apply on any future watch re-sync):**

- Team scrub `C67CF9S4VU` → `ZDBP5RSRZF` (Vipads MCHJ, Apple-team rule) in `Telegram/WatchApp/project.yml:72` (`DEVELOPMENT_TEAM`) + `tgwatch.xcodeproj/project.pbxproj` (`DevelopmentTeam`/`DEVELOPMENT_TEAM` ×3, ~470/634/656).

**`Telegram/BUILD` — 4 ADDITIVE watch splices (take ONLY these; PRESERVE Novagram branding):**

1. After the `local_provisioning_profile` load: `load("//Telegram:prebuilt_watchos.bzl", "apple_prebuilt_watchos_application")`.
2. Before `config_setting(name = "projectIncludeReleaseSetting")`: `bool_flag(name="embedWatchApp", default=False)` + `config_setting(name="embedWatchAppSetting", ...)`. (`bool_flag` already loaded.)
3. Before `ios_application(name = "Telegram", bundle_name = "Novagram",`: the `apple_prebuilt_watchos_application(name="TelegramWatchApp", bundle_id="{telegram_bundle_id}.watchkitapp", tags=["manual"])` target.
4. Inside that `ios_application` (before `deps = [":Main", ":Lib"]`): `watch_application = select({":embedWatchAppSetting": ":TelegramWatchApp", "//conditions:default": None})`.

- ⚠️ **BRANDING TRAP:** upstream's `Telegram/BUILD` diff also flips `bundle_name` Novagram→Telegram, swaps Novagram\* icons, drops PrivacyManifest — these were **NOT taken**. `bundle_name = "Novagram"`, `alternate_icon_folders` (NovagramYellow/Green/Gradient **at the time — superseded 2026-07-09, see "Alternate app icon set: 3 Novagram → 7 Nova" near the end of this file for the current list**), `composer_icon_folders = []`, `:PrivacyManifest` all preserved.

**Remaining to SHIP the watch (user-side, deferred — not done here):** register App ID `uz.fenixuz.app.watchkitapp` + watchkitapp provisioning profile under team `ZDBP5RSRZF`, drop `WatchApp.mobileprovision` into the codesigning material. Until then keep `publish.sh` **WITHOUT** `--embedWatchApp` (an `--embedWatchApp` distribution build HARD-RAISES without that profile by design). watchOS min target = 26.0. First standalone watch build needs network (QRCodeGenerator SPM resolve).

**Verification:** hook fingerprint identical before/after (371 markers, 0 lost); `./run.sh` green; app launches; 0 watch-related simulator build lines (zero coupling).

---

## 📌 Analytics page — Novagram Statistics API (2026-06-27, moved to the SDK 2026-10-26)

Novagram "Analytics" Settings page with the two counters the Android app shares (same server, so
the numbers match across iOS, macOS and Android). Since 2026-10-26 the server is reached only
through the private NovagramServices SDK (`services.statistics`); its base URL and `x-api-key`
are masked inside the SDK binary and are NOT in this repo (never add them back).

- **"Number of Novagram users"** (`downloads`) — devices that ever installed the app, counted
  once per device id.
- **"Active accounts"** (`active`) — devices that hold at least one signed-in account right now.

The server counts DEVICES by `device_id` (a random UUID in the Keychain, service
`uz.fenixuz.app.Analytics`, account `deviceId`; it survives reinstall). Do not change those
names: every existing device would be counted again. When each call is sent:

| Moment | Call |
| --- | --- |
| First open after install; on success `uz.fenixuz.app.Analytics.installRegistered` = true in UserDefaults | `POST /v1/install` |
| Every account that is added and has loaded (first login, every Profile → Add Account) | `POST /v1/account/create` |
| Every logout the user confirms (Settings → Edit → Log Out → "Log out?" OK) | `POST /v1/account/delete`, then `/create` again if other accounts stay signed in |
| Every emission of the account list | reconcile with the Keychain flag `deviceActive` (repairs failed calls and sessions ended remotely) |
| The Analytics page opens | `GET /v1/stats` |

All logic lives in the Novagram-owned module `submodules/Novagram/Analytics/` (`NovagramAnalytics`):
`NovagramStatisticsClient` (bridge to the SDK), `NovagramAnalyticsManager` (device id, flags, account
observation, `accountWillLogOut`), `NovagramAnalyticsController` (the UI page). In a build whose SDK
has no Statistics values every call is a no-op and the page shows "—". SDK docs: `docs/SERVICES.md`
and `docs/INTEGRATION.md` in the SDK repo.

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list (Novagram block), append:

```python
"//submodules/Novagram/Analytics:NovagramAnalytics",
```

Reason: `AppDelegate.swift` calls `NovagramAnalyticsManager.shared.start(...)`.

### `submodules/TelegramUI/Sources/AppDelegate.swift`

**Top imports — add after `import TelegramCore`:**

```swift
import NovagramAnalytics
```

**In `application(_:didFinishLaunchingWithOptions:)`, immediately after the `self.sharedContextPromise.set(...)` block:**

```swift
// Novagram Analytics — once the shared context is ready, count this device (once per
// physical device) and observe account contexts to count new account registrations.
let _ = (self.sharedContextPromise.get()
|> take(1)
|> deliverOnMainQueue).start(next: { sharedApplicationContext in
    NovagramAnalyticsManager.shared.start(sharedContext: sharedApplicationContext.sharedContext)
})
```

Reason: needs the live `SharedAccountContext` (created asynchronously) to read `activeAccountContexts`. Cannot live in a Novagram module because the shared context is only reachable from AppDelegate.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/BUILD`

In the `deps = [...]` list (Novagram block), append:

```python
"//submodules/Novagram/Analytics:NovagramAnalytics",
```

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift`

In `enum PeerInfoSettingsSection`, add after `case novagramAccounts`:

```swift
case analytics
```

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift`

**Top imports — add after `import NovagramMessenger`:**

```swift
import NovagramAnalytics
```

**Settings rows — add right after the "Novagram Settings" (ex-"NovagramPro") row in the `.novagramMessenger` section:**

```swift
items[.novagramMessenger]!.append(PeerInfoScreenDisclosureItem(id: 1, text: "Analytics", icon: novagramSettingsIcon(systemName: "chart.bar.fill", color: .lightBlue), action: {
    interaction.openSettings(.analytics)
}))
```

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift`

**Top imports — add after `import NovagramMessenger`:**

```swift
import NovagramAnalytics
```

**In `openSettings(section:)` switch — add after the `.novagramAccounts` case:**

```swift
case .analytics:
    push(novagramAnalyticsController(context: self.context))
```

### `submodules/SettingsUI/BUILD` (2026-10-26)

In the `deps = [...]` list, after `"//submodules/Novagram/Localization:NovagramLocalization"`, append:

```python
"//submodules/Novagram/Analytics:NovagramAnalytics",
```

Reason: `LogoutOptionsController.swift` calls `NovagramAnalyticsManager.shared.accountWillLogOut(...)`.
No cycle: NovagramAnalytics depends only on lower-level modules.

### `submodules/SettingsUI/Sources/LogoutOptionsController.swift` (2026-10-26)

**Top of file — imports block.** Add after `import WalletContext`:

```swift
import NovagramAnalytics
```

**Inside the `logout:` closure**, in the "Log out?" alert's `Common_OK` `TextAlertAction`, insert
right BEFORE `let _ = logoutFromAccount(id: context.account.id, ...)`:

```swift
// Novagram: statistics — a confirmed logout sends /v1/account/delete (and /create again if accounts remain).
NovagramAnalyticsManager.shared.accountWillLogOut(accountId: context.account.id)
```

Reason: the product rule is "every confirmed logout sends `/v1/account/delete`". The alert's
action closure is private to this file, so the call has to sit here. The manager knows the other
signed-in accounts and re-sends `/v1/account/create` when some remain (the server counts devices).
Cancel does nothing.

### `Telegram/Telegram-iOS/PrivacyInfo.xcprivacy`

The existing **Device ID** collected-data-type entry gains a second purpose `NSPrivacyCollectedDataTypePurposeAnalytics` (alongside `…AppFunctionality`). The analytics device id is an app-generated random UUID kept in the Keychain (NOT IDFA/IDFV), `NSPrivacyCollectedDataTypeTracking = false` → no ATT prompt required.

### `submodules/TelegramUI/Images.xcassets/NovagramAnalyticsDuck.imageset/` (fork-added asset)

New vector imageset (the colorful duck-with-megaphone-on-a-podium hero illustration), `preserves-vector-representation`. Loaded by the Analytics page via `UIImage(bundleImageName: "NovagramAnalyticsDuck")`. `TelegramUI/BUILD` globs `Images.xcassets/**` so no BUILD change is needed. Re-add this imageset on any asset-catalog reset.

### Page design + glass back button (2026-06-27 redesign)

`NovagramAnalyticsController.swift` was redesigned to an iOS HIG + Telegram-native look (duck hero 140 pt + silhouette shadow, "App usage numbers" subtitle, two side-by-side rounded stat cards with the number + caption + inline `info.circle`, whole-card tap → explanation alert, light/dark correct).

The nav back button is an **iOS 26 "glass" chevron-in-a-circle** matching the native PeerInfo (Novagram settings) back button: `backButtonImage(circleColor:chevronColor:)` bakes an accent chevron inside a neutral translucent circle (`UIColor(rgb: 0x767680)` @ 0.16 light / 0.30 dark) into one `UIImage(.alwaysOriginal)`, set as a standard `self.navigationItem.leftBarButtonItem = UIBarButtonItem(image:…, target: self, action: #selector(backPressed))`. `backPressed` pops via `NavigationController.filterController(self, animated:)`. Why baked-image and not the system glass node: the nav bar's own glass treatment only applies to its internal back node, unreachable from a custom button; and the empty-title `backButtonAppearanceWithTitle: ""` route collapses the hit area and swallows taps. `updateBackButton()` re-renders on every theme change. **No `UIKitRuntimeUtils` dep needed** (the earlier empty-title approach was abandoned).

> NOTE: `submodules/Novagram/Analytics/Sources/NovagramAnalyticsConfig.swift` still has empty `databaseURL` / `authToken` placeholders pending the Android developer's Firebase project details (RTDB URL, counter paths, write auth). Fill these to activate the counters.

---

## 📌 2026-06-27 — Feature #32: Channel Recent Actions context-menu item

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — Recent Actions (#32)

**Location:** inside `chatContextMenuItems(...)` → the `if !isSavedMessages {` block that contains the Mute, Secret-read, Pincode, and Copy-Chat-ID items. Inserted after the "Copy Chat ID" block (after the `if !isSavedMessages { ... }` for Copy-Chat-ID, before the closing `}` of the outer `if !isSavedMessages` block).

**Code added:**

```swift
// MARK: - Channel Recent Actions (Feature #32)
// Only shown when the NovagramPro toggle is ON and the peer is a
// channel/supergroup where the current user is an admin or creator.
if case let .channel(channel) = peer,
   channel.adminRights != nil || channel.flags.contains(.isCreator),
   UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_channel_history_button") == true {
    let histLang = presentationData.strings.primaryComponent.languageCode
    let recentActionsTitle: String
    switch histLang {
    case "uz": recentActionsTitle = "So\u{02BC}nggi amallar"
    case "ru": recentActionsTitle = "Недавние действия"
    default:   recentActionsTitle = "Recent actions"
    }
    items.append(.action(ContextMenuActionItem(text: recentActionsTitle, icon: { theme in
        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadingList"), color: theme.contextMenu.primaryColor)
    }, action: { _, f in
        f(.default)
        let recentActionsController = context.sharedContext.makeChatRecentActionsController(context: context, peer: peer, adminPeerId: nil, starsState: nil)
        chatListController?.push(recentActionsController)
    })))
}
```

**Gate conditions (all must be true):**

1. `UserDefaults(suiteName: "pro_messager").bool(forKey: "fenix_channel_history_button") == true` — NovagramPro Features toggle (already wired in `NovagramSettingsController.swift` since before this commit).
2. `peer` is `.channel` (not user, legacyGroup, or secretChat) — prevents the item appearing on DMs.
3. `channel.adminRights != nil || channel.flags.contains(.isCreator)` — the current user is an admin or creator in that channel, matching the same access rule Telegram uses on its own ChannelAdmins → "Recent Actions" row.

**Action:** calls `context.sharedContext.makeChatRecentActionsController(context:peer:adminPeerId:starsState:)` (existing API, signature in `AccountContext.swift` line 1411; existing call site in `ChannelAdminsController.swift` line 734), then pushes the returned `ViewController` via `chatListController?.push(controller)`.

**Localization:** inline `switch langCode` (same pattern as Copy Chat ID / Secret Read / Pincode) — "Recent actions" / "Soʼnggi amallar" (Uzbek) / "Недавние действия" (Russian). No `NovagramLocalization` module import needed.

**No new BUILD dependency** — `ChatListUI` already imports `AccountContext` (which declares `makeChatRecentActionsController`). No new Novagram module created; logic is a pure 1-liner call into an existing shared-context API.

Reason: `makeChatRecentActionsController` and `chatListController?.push(...)` are only reachable inside this Telegram-owned file (not from a Novagram module). The check `channel.adminRights != nil || channel.flags.contains(.isCreator)` reads a property of `TelegramChannel`, which is only accessible after pattern-matching `EnginePeer` — both operations require the file-internal `peer` variable captured in the map closure. The hook is therefore irreducibly a call site here, not in a Novagram module.

---

## 📌 TelegramUI module — Feature #45 Auto-accept join requests (2026-06-27)

### `submodules/TelegramUI/Sources/ChatController.swift`

**Imports — append after `import TextProcessingScreen`:**

```swift
import NovagramMessenger
```

**Inside `viewDidAppear(_:)` — add before the closing `}` of the method (after the `powerSavingMonitoringDisposable` block, around line 7922):**

```swift
// Novagram: Feature #45 — auto-approve pending join requests when chat opens
if let peerId = self.chatLocation.peerId {
    NovagramAutoAcceptManager.autoApproveIfNeeded(context: self.context, peerId: peerId, peer: self.presentationInterfaceState.renderedPeer?.chatMainPeer)
}
```

Reason: `chatLocation.peerId`, `context`, and `presentationInterfaceState.renderedPeer?.chatMainPeer` are all internal to `ChatController` — they cannot be accessed from a Novagram module. All business logic (flag check, admin-rights check, rate-limit, API call) lives in `NovagramAutoAcceptManager` inside `NovagramMessenger`. The hook is a 3-line delegate call.

**Implementation file:** `submodules/Novagram/Messenger/Sources/NovagramAutoAcceptManager.swift` (picked up automatically by the NovagramMessenger BUILD glob — no BUILD change needed).

**No new BUILD dep for TelegramUI** — `NovagramMessenger` is already a direct dep of `TelegramUI/BUILD` (added for ApplicationContext.swift / OpenResolvedUrl.swift hooks).

### 2026-07-07 — made auto-accept proactive (launch scan + 60 s poll) instead of open-chat-only

The original implementation only fired from `viewDidAppear`, so requests for chats the admin never opened were never approved. Reworked `NovagramAutoAcceptManager` (Novagram module — no upstream change there) to add `startGlobalMonitor(context:)` / `stopGlobalMonitor()` which scan the chat list, filter to admin channels/groups, read each peer's `CachedChannelData/CachedGroupData.inviteRequestsPending`, and only call `updateAll(.approve)` when pending > 0. Fast path now resolves a nil peer via `engine.data` and also gates on pending count; the per-peer debounce dropped from 300 s → 15 s so newly-arrived requests aren't suppressed.

**New upstream hook — `submodules/TelegramUI/Sources/AppDelegate.swift`:** `+1 import (`import NovagramMessenger`) +14-line launch block` right after the NovagramAutoProxy start block. It takes `sharedContextPromise |> take(1)`, then observes `sharedContext.activeAccountContexts` and calls `NovagramAutoAcceptManager.startGlobalMonitor(context: primary)` (or `stopGlobalMonitor()` when no account is active). Applied via Python (not Edit) to keep the diff minimal. `NovagramMessenger` is already a `TelegramUI/BUILD` dep — no BUILD change.

**Settings toggle — `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift` (Novagram module):** the `updateAutoAccept` handler now calls `startGlobalMonitor(context:)` on ON and `stopGlobalMonitor()` on OFF so enabling triggers an instant scan.

---

## 📌 2026-07-03 — chat-lock: fix persistence + enforce lock on long-press preview

Three changes fixing the per-chat pincode (it set-but-never-saved, and long-press leaked chat content).

### `submodules/Novagram/ChatLock/Sources/ChatPincodeViewController.swift` — dismissSelf completion fix (Novagram module, not upstream)

`dismissSelf(completion:)` was calling `self.dismiss(animated:completion:)`. `ChatPincodeViewController` inherits `Display.ViewController`, whose `dismiss(animated:completion:)` override **drops the completion** (`Display/Source/ViewController.swift:575`), so `onSuccess` never ran → `setPincode`/verify/remove callbacks were dead. Fixed by dismissing the enclosing **plain UIKit** `UINavigationController` (`self.navigationController`), which bypasses the Display override and fires UIKit's real completion.

### `submodules/Novagram/ChatLock/Sources/ChatPincodeManager.swift` — keychain→UserDefaults hashed fallback (Novagram module, not upstream)

Fake-codesigned dev/simulator builds carry no keychain entitlement (`application-identifier`/`keychain-access-groups` absent — only `get-task-allow`), so every `SecItem*` returns `errSecMissingEntitlement (-34018)` and writes silently failed. Keychain stays the primary store (works on properly-signed App Store builds); when it rejects a write, the credential now persists as a **salted SHA-256 hash** in `UserDefaults.standard` (never plaintext). `isLocked`/`verify`/`removePincode`/metadata read the fallback on keychain miss.

### `submodules/ChatListUI/Sources/ChatListController.swift` — suppress message preview for locked chats (UPSTREAM hook)

Long-pressing a chat builds a `mode: .standard(.previewing)` `ChatController` as the context-menu preview, which rendered the messages of a **locked** chat without asking for the pincode. Two hook sites now check `ChatPincodeManager.shared.isLocked(...)` and, when locked, use a no-content `.location(ChatListContextLocationContentSource(...))` source (menu still works, no message peek):

- `activateChatPreview` closure (~line 1932, `else if ... isLocked(peer.peerId)`) — main chat list.
- `peerContextAction` closure (~line 2018, `else if ... isLocked(peer.id)`) — search results.
  Also added `import NovagramChatLock` at the top. `NovagramChatLock` is already in `submodules/ChatListUI/BUILD` (line 13, used by ChatContextMenus.swift) — no BUILD change needed. Applied via Python (not Edit) to keep the upstream diff minimal.

---

## 📌 Secret Vault (hidden chats behind a separate PIN) — added 2026-07-04

Feature module: `submodules/Novagram/SecretVault/` (`NovagramSecretVault`) — `SecretVaultManager` (vaulted peerId set + enabled cache), `SecretVaultRevealGestureRecognizer` (10-tap title trigger), `SecretVaultStrings`. Vault PIN is stored by `ChatPincodeManager` (module `NovagramChatLock`) under a reserved account `__fenix_vault__`, fully independent from the ChatLock master. Vaulted chats are hidden from the main list AND auto-muted (`updatePeerMuteSetting … Int32.max`) so no push leaks them; unhide/disable unmutes (`… 0`).

### `submodules/Display/Source/Toolbar.swift`

Add a 4th optional action to `Toolbar` (backward-compatible, default `nil`):

```swift
    public let extraAction: ToolbarAction?
    public init(leftAction: ToolbarAction?, rightAction: ToolbarAction?, middleAction: ToolbarAction?, extraAction: ToolbarAction? = nil) {
        …
        self.extraAction = extraAction
    }
```

Reason: the main chat-list edit toolbar has 3 slots all used (Read/Archive/Delete); the bulk "Hide to Vault" needs a 4th. Cannot live in a Novagram module — `Toolbar` is a Display type.

### `submodules/Display/Source/ToolbarNode.swift`

`enum ToolbarActionOption { case left; case right; case middle; case extra }` — add `case extra`.

### `submodules/TabBarUI/Sources/TabBarContollerNode.swift`

In the `GlassControlPanelComponent` toolbar (`centralItem:`), render `toolbarData.extraAction` as a SECOND grouped item next to Archive, dispatching `self.toolbarActionSelected(.extra)`. Reason: the root chat list renders its edit toolbar via the tab bar's Glass control panel; the extra action must be wired there. Reuses the existing `items:` array (no Glass-component layout change).

### `submodules/ChatListUI/Sources/Node/ChatListNode.swift`

`struct ChatListNodeState`: add `public var novagramVaultMode: Bool = false` and `public var novagramVaultRevision: Int = 0` (+ two `==` comparisons). Reason: the entries builder reads mode from `state` (already reactive through the combine); bumping `novagramVaultRevision` forces a rebuild when the vaulted set changes.

### `submodules/ChatListUI/Sources/Node/ChatListNodeEntries.swift`

`import NovagramSecretVault`. In `chatListNodeEntriesForView`, inside `loop: for entry in view.items` (just before the Foreign User Block), after `peerId` is resolved:

```swift
        if let peerId = peerId {
            if state.novagramVaultMode {
                if !SecretVaultManager.shared.isVaulted(peerId) { continue loop }
            } else if isMainTab && SecretVaultManager.shared.isVaulted(peerId) && SecretVaultManager.shared.isEnabled {
                continue loop
            }
        }
```

Reason: single choke point for every main-list row; `isMainTab` guarantees archive/folders are untouched. Mirrors the ForeignUserBlock skip.

### `submodules/ChatListUI/Sources/ChatListController.swift`

- `import NovagramChatLock`, `import NovagramSecretVault`.
- Stored props: `fileprivate let novagramIsVaultList: Bool`, `novagramVaultGesturesAttached`, `novagramVaultChangedObserver`.
- `init(...)`: new trailing param `novagramIsVaultList: Bool = false` + assignment.
- `displayNodeDidLoad()`: if `novagramIsVaultList`, set node `state.novagramVaultMode = true`.
- `viewDidAppear`: call `novagramSetupSecretVaultIfNeeded()` (registers the `.novagramSecretVaultChanged` observer that bumps `novagramVaultRevision`; on the main list attaches the 10-tap + long-press title recognizers → PIN verify → push the vault list).
- `deinit`: remove `novagramVaultChangedObserver`.
- Toolbar build (`.chatList(.root)`): add `extraAction` = "Hide" (main) / "Unhide" (vault, `parentController.novagramIsVaultList`) when `SecretVaultManager.shared.isEnabled`.
- `toolbarActionSelected`: handle `.extra` → `novagramSetChatsVaulted(!novagramIsVaultList, …)`.
- New methods after `archiveChats`: `novagramSetupSecretVaultIfNeeded`, `novagramVaultLongPress`, `novagramOpenSecretVault`, `novagramPresentVaultList`, `novagramSetChatsVaulted` (add/remove vault + mute/unmute + Undo overlay).

Reason: all require private controller state (node, toolbar, nav) — cannot be a pure Novagram module.

### BUILD deps

- `submodules/ChatListUI/BUILD` deps += `//submodules/Novagram/SecretVault:NovagramSecretVault`.
- `submodules/Novagram/Messenger/BUILD` deps += `//submodules/Novagram/SecretVault:NovagramSecretVault`.

### Novagram-owned (not upstream) — `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift`

New `NovagramSection.secretVault` section: `secretVaultEnabled` toggle + `secretVaultFooter`. Toggle ON → `ChatPincodeViewController(.set)` → `setVaultPincode`; OFF → `.verify` vault → unmute+`clearVault`+`removeVault`. `refreshSecretVault` reconciles the switch in `didAppear` (mirrors Feature #46 Chat Lock master).

### Secret Vault — follow-up 2026-07-04 (forgot-PIN recovery + unhide)

- **`submodules/Novagram/SecretVault/Sources/SecretVaultBiometric.swift`** (module-owned) — `LAContext` device-owner (Face ID / passcode) auth for the "Forgot vault PIN?" path.
- **`submodules/ChatListUI/Sources/ChatListController.swift`** — in `novagramOpenSecretVault` the verify screen's `onForgot` (was `nil`) now runs `SecretVaultBiometric.authenticateDeviceOwner` → on success dismisses the PIN modal and opens the vault. The independent vault PIN has no master, so device-owner auth is the recovery.
- **`submodules/ChatListUI/Sources/ChatContextMenus.swift`** — `import NovagramSecretVault`; add an "Unhide from Vault" long-press context-menu item (after the ChatLock item) shown when `SecretVaultManager.shared.isVaulted(peerId)` → `removeFromVault([peerId])` + unmute. Reason: the pushed vault list (`.chatList(.root)`, not a tab-bar child) does not render the bulk edit toolbar, so unhide is offered per-chat via long-press.

---

## 📌 Round video from gallery (2026-07-06)

**Feature:** long-pressing the video-message button opens a picker sheet where an option **"Photos"** lets the user pick a gallery video and send it as a **round video note** (`.instantRoundVideo`). Gated by NovagramPro toggle `round_video_from_gallery` (default **OFF** — `isEnabled` reads `?? false`). Module: `submodules/Novagram/RoundVideoFromGallery/` (`NovagramRoundVideoFromGallery`) — mirrors `VideoMessageCameraScreen.sendVideoRecording` (MediaEditorValues `.videoMessage` + `LocalFileVideoMediaResource` + `.instantRoundVideo`), fed a PHPicker video cropped to a centered square, capped at 60s, enqueued via `enqueueMessages`.

**Hooked upstream files (re-inject on upstream pull):**

1. `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`
   - Added `import NovagramRoundVideoFromGallery` (next to the existing `import NovagramLocalization`).
   - Inside the `presentCameraSelection` closure action sheet: the first `ActionSheetItemGroup` is built as `var novagramCameraItems: [ActionSheetItem] = []`; the Front + Back buttons are appended only when `long_press_camera_selection` is on, and the `l10n.cameraPicker_gallery` ("Photos") button only when `NovagramRoundVideoFromGalleryFlow.isEnabled`. The gallery button calls that calls `NovagramRoundVideoFromGalleryFlow.present(context:peerId:threadId:replySubject:from:)` using `presentationInterfaceState.chatLocation.peerId/threadId`, `presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel` (2026-07-16: threads the active swipe-reply through so a round video sent from the gallery preserves its reply instead of sending as a plain message), + `interfaceInteraction.chatController()`. This block is already a Novagram hook (camera-picker localization, 2026-06-08) — extend it.

2. `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/BUILD`
   - Added dep `//submodules/Novagram/RoundVideoFromGallery:NovagramRoundVideoFromGallery`.

**Fixed 2026-08-21 — the gallery toggle no longer depends on the camera picker.**
`presentCameraSelection` used to open with `if !longPressCameraSelection { return }`, so the whole
sheet — and with it the "Photos" item — was dead whenever **Camera picker** was off, even with
**Round video from gallery** on. That contradicts the gallery toggle's own subtitle ("Adds a
\"Photos\" option to the video-message camera menu…"), which says nothing about the camera picker,
and the Settings UI, which renders the two as sibling switch rows (`NovagramSettingsController.swift`
entries 6 and 7).

**Two coupled edits are required — one alone is a bug.** `TGModernConversationInputMicButton.m`
fires `micButtonInteractionBegan` → (0.19s) `beginRecording`, then (0.4s)
`micButtonInteractionPresentCameraSelection`. So the recorder starts _before_ the sheet appears, and
the existing `beginRecording` hook suppresses that start whenever the sheet is coming:

1. `beginRecording` closure — the suppression condition must consider **both** toggles:
   `let willPresentCameraSelection = longPressCameraSelection || NovagramRoundVideoFromGalleryFlow.isEnabled`
   then `if !isVideo || !willPresentCameraSelection { interfaceInteraction.beginMediaRecording(isVideo) }`.
   Without this the 0.4s sheet lands on top of a live camera.
2. `presentCameraSelection` closure — `if !longPressCameraSelection && !roundVideoFromGallery { return }`.

**The sheet always carries a way back to the recorder.** Once it opens, `beginRecording` has
deliberately skipped starting the recorder, so an item that reaches the camera is mandatory —
otherwise a gallery-only user cannot shoot a round video at all. With **Camera picker** on that is
the Front/Back pair; with only **Round video from gallery** on the user never asked to choose a lens,
so a single `l10n.cameraPicker_camera` ("Camera") item stands in and clears
`VideoMessageCameraScreen.pendingCameraPosition` to `nil` first, so it always opens the default
(front) camera rather than a lens left over from an earlier sheet.

| Camera picker | Round video from gallery | Long-press on the video button                                             |
| ------------- | ------------------------ | -------------------------------------------------------------------------- |
| off           | off                      | records immediately, no sheet (unchanged)                                  |
| on            | off                      | sheet: Front / Back (unchanged)                                            |
| on            | on                       | sheet: Front / Back / Photos (unchanged)                                   |
| off           | on                       | sheet: **Camera / Photos** — was: recorded immediately, Photos unreachable |

New string: `submodules/Novagram/Localization/Sources/NovagramL10n.swift` → `cameraPicker_camera`
(en "Camera", uz "Kamera", ru "Камера").

**Fork-only files (pure Novagram, no upstream conflict):**

- `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift` — `roundVideoFromGallery` toggle (enum case, section, stableId 8, equality, item builder, state field/init/equality, entries.append, arguments decl/init/assign/closure) mirroring `editedHistoryEnabled`. UserDefaults key `round_video_from_gallery`, default ON.
- `submodules/Novagram/Localization/Sources/NovagramL10n.swift` — `cameraPicker_gallery`, `settings_chat_roundVideoGallery_title`, `settings_chat_roundVideoGallery_subtitle`.

---

## 📌 Edited history — full media capture (2026-07-07)

The edited-message history (long-press → History, gated by `pro_messager/edited_history_enabled`) now preserves the previous MEDIA of an edited message, not only the text.

### `submodules/TelegramCore/Sources/SyncCore/SyncCore_EditedMessageHistoryAttribute.swift` (fork-ADDED file)

Schema v2: `EditedMessageHistoryEntry` gained `public let media: [Media]` (default `[]` in `init`).

- Postbox encode: `encoder.encodeGenericObjectArray(self.media.map { $0 as PostboxCoding }, forKey: "media")` (same pattern as `SyncCore_InstantPage.swift`).
- Postbox decode: `decoder.decodeObjectArrayForKey("media").compactMap { $0 as? Media }` — missing key returns `[]`, so attributes stored before v2 keep loading (text-only). NO migration needed.
- Codable path intentionally drops media (`self.media = []` in `init(from:)`); persistence only ever goes through PostboxCoding.
- `associatedMediaIds` now also returns `entry.media` ids (best-effort render-time resolution).
- Equatable compares media by `map { $0.id }`.

### `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift` — `.EditMessage` handler (~line 4599)

Fork-owned capture (predates this doc; documented now). 2026-07-07 rework captured text+media; **2026-07-21** the inline ~28-line block was extracted into the shared helper `novagramAppendEditHistory(...)` (see below) and is now a single call:

```swift
novagramAppendEditHistory(previousMessage: previousMessage, newText: message.text, newMedia: message.media, into: &updatedAttributes)
```

- Still: history entry created when **text OR media changed** (webpage previews filtered out), entry timestamp = previous `EditedMessageAttribute.date` else `previousMessage.timestamp`, idempotent on re-delivered identical edits.
- New in 2026-07-21: when the update brings **no** text/media change, an already-captured history is now carried forward instead of being dropped by the server copy's attribute set.
- Upstream translation-carryover branch (`previousMessage.text == message.text`) left untouched above the call.

On upstream merge conflict: keep the upstream translation/factcheck code, re-insert the `// Novagram: capture the previous version` call between the translation `if` and the `FactCheckMessageAttribute` block.

### `submodules/TelegramCore/Sources/NovagramEditHistoryCapture.swift` (fork-ADDED file, 2026-07-21) + `RequestEditMessage.swift` own-edit fix

**Bug fixed:** the History viewer only appeared after a message was edited **2+ times**; a single edit showed nothing. Cause: a user's OWN edit goes through `PendingMessages/RequestEditMessage.swift`, whose result handler replaced the message with the server copy (preserving only flags/localTags/media, **dropping `EditedMessageHistoryAttribute`** and capturing no previous version). The same updates were then fed to `stateManager.addUpdates(result)`, but by then the stored text already equalled the server text, so the `.EditMessage` capture saw no change. The original version was therefore never recorded for own edits, and the history only started accumulating from the second observed change.

**Fix:**

- New file `NovagramEditHistoryCapture.swift` — the single `novagramAppendEditHistory(previousMessage:newText:newMedia:into:)` helper, now called from both edit paths. Idempotent across the two: once one path has stored the pre-edit version, the other sees no change and carries the existing history forward (no duplicate, no drop).
- `RequestEditMessage.swift` — in all **4** inline update branches (`updateEditMessage`, `updateNewMessage`, `updateEditChannelMessage`, `updateNewChannelMessage`) the return now threads `updatedAttributes` (server attributes + captured history) through `.withUpdatedAttributes(updatedAttributes)`. `previousMessage` in this closure still holds the pre-edit text, so the first edit is captured deterministically.
- TelegramCore `BUILD` globs `Sources/**/*.swift`, so the new file needs no BUILD change.
- Note: this fixes OWN edits and other people's edits observed live. Edits made to a message **before it was loaded** on this device still cannot be recovered — Telegram exposes no server-side edit history, so the feature is inherently capture-on-observe.

**Follow-up fix (same day) — `SyncCore_StandaloneAccountTransaction.swift` `mergeMessageAttributes`:** after the above, History worked in **private chats but NOT in groups/channels**. Root cause: `EditedMessageHistoryAttribute` is local-only (server never sends it). Channel & group messages are re-added via `getChannelDifference` newMessages, which for an already-stored id runs Postbox `MessageHistoryIndexTable.addMessages` → `.InsertExistingMessage` → `MessageHistoryTable.justUpdate` → `seedConfiguration.mergeMessageAttributes(previous, &updated)`. That closure only carries forward a whitelist of local-only attributes (`AudioTranscription`, `DerivedData`, `RichText`); `EditedMessageHistoryAttribute` was missing, so every channel re-sync overwrote the message with the server copy and dropped the captured history. Private-chat messages don't take the `.InsertExistingMessage` re-add path (their edits go through `.EditMessage`/`updateMessage`, preserved by the helper), which is exactly why DMs worked and groups/channels didn't. Fix: added an `EditedMessageHistoryAttribute` carry-forward block to `mergeMessageAttributes` (append `previous`'s attribute when `updated` has none — and the server copy never has one). `telegramPostboxSeedConfiguration` (this file, ~line 30) is the single seed config used by every account (`Account.swift:260,1711`), so one edit covers all accounts. On upstream merge conflict: re-add the `EditedMessageHistoryAttribute` block after the `RichTextMessageAttribute` block inside `mergeMessageAttributes`.

**Localization (same day):** the context-menu item label was a hardcoded English `"History"`. Replaced with `NovagramL10n(chatPresentationInterfaceState.strings).context_editHistory` (new `NovagramL10n` string — en "Edit History", uz "Tahrirlash tarixi", ru "История правок"). `import NovagramLocalization` was already present in `ChatInterfaceStateContextMenus.swift` (line ~40, used by `context_forwardWithoutName`), so no BUILD change.

### `submodules/TelegramCore/Sources/Account/AccountManager.swift` (line ~246, pre-existing)

`declareEncodable(EditedMessageHistoryAttribute.self, f: { EditedMessageHistoryAttribute(decoder: $0) })` — required Postbox type registration for the attribute.

### Fork-only files (no upstream conflict)

- `submodules/Novagram/EditedHistory/Sources/EditedMessageHistoryController.swift` — entry node now renders the previous media: photo/video thumbnail via `chatMessagePhoto` / `chatMessageVideo` (`.standalone` reference — cloud media re-fetches on demand), play-icon overlay for videos, filename+size text row for documents, generic "Media" row otherwise.
- `submodules/Novagram/EditedHistory/Sources/EditedHistoryStrings.swift` — NEW, module-local en/uz/ru strings ("File"/"Fayl"/"Файл", "Media"/"Media"/"Медиа").
- `submodules/Novagram/EditedHistory/BUILD` — +1 dep `//submodules/PhotoResources:PhotoResources`.

## 📌 2026-07-07 — ItemListDisclosureItem: configurable iconPeer avatar size

### `submodules/ItemListUI/Sources/Items/ItemListDisclosureItem.swift` — UPSTREAM hook

Added a backward-compatible `iconPeerSize: CGFloat = 40.0` init parameter (plus its stored
property and assignment) so a caller can enlarge the `iconPeer` avatar. The layout consumes
it in two spots:

- min row height: `max(height, (item.iconPeer != nil ? item.iconPeerSize : 40.0) + verticalInset * 2.0)`
- avatar frame: `let avatarSize: CGFloat = item.iconPeerSize`

The `40.0` default keeps every existing call site byte-identical (rows without an avatar, and
avatar rows that do not pass the new arg, are unchanged). Only Novagram Bots passes a custom
value. On upstream merge: re-apply the param + the two layout reads; nothing else references it.

### Novagram caller (not upstream) — `submodules/Novagram/Messenger/Sources/NovagramBotsController.swift`

Passes `iconPeerSize: 56.0` on the bot-row `ItemListDisclosureItem` so bot avatars render at
chat-list size instead of the default 40pt.

### Related (same feature) — reminder sound now resolves from the framework bundle + Library/Sounds

`submodules/Novagram/UnreadReminder/Sources/NovagramUnreadReminderSettings.swift` gained
`soundsBundle` (Bundle(for: BundleToken.self)) and `installBundledSoundsIfNeeded()` (copies the
bundled .caf into <App>/Library/Sounds). Bazel packs a swift_library's `data` into its FRAMEWORK,
not the app root, so `Bundle.main.url` returned nil (silent preview) and `UNNotificationSound(named:)`
could not resolve the tone. `NovagramReminderSoundPreview` now reads from `soundsBundle`; the manager
calls `installBundledSoundsIfNeeded()` before scheduling. All three are Novagram-module files (no
upstream hook).

## 📌 2026-07-07 — Secret Vault: Face ID default-ON + more reminder tones

### `submodules/ChatListUI/Sources/ChatListController.swift` — UPSTREAM hook (novagramOpenSecretVault)

`novagramOpenSecretVault` now calls `ChatPincodeManager.shared.migrateVaultBiometricDefaultIfNeeded()`
before reading vault metadata. Face ID / Touch ID was fully wired to vault unlock already
(verify screen `viewDidAppear` → `attemptBiometricIfNeeded`), but gated behind a default-OFF
"Unlock with Face ID" toggle, so users never saw it. The migration flips the vault biometric
flag ON once (flag `fenix_vault_biometric_default_on_v1`) when the device supports biometrics,
so opening hidden chats prompts Face ID automatically. PIN stays the always-present fallback;
a later manual OFF sticks (the migration runs only once).

### `submodules/Novagram/ChatLock/Sources/ChatPincodeManager.swift` (module-owned)

Added `migrateVaultBiometricDefaultIfNeeded()`.

### Reminder tones (module-owned) — `submodules/Novagram/UnreadReminder/Sources/NovagramUnreadReminderSettings.swift` + `Sounds/`

soundOptions expanded 5 → 12 tones (added marimba, crystal, droplet, ping, pulse, harp, signal
as bundled .caf; names in `NovagramL10n.settings_reminder_soundName`). Apple's own Settings tones
cannot be used by a 3rd-party app for notifications — only bundled files / .default — so these are
original synthesized tones (like Telegram bundles its own).

---

## 📌 2026-07-09 — Alternate app icon set: 3 Novagram → 7 Nova (glass icons) + localized names

The alternate-icon picker (Settings → app icon) dropped the 3 old flat Novagram icons
(NovagramYellowIcon / NovagramGreenIcon / NovagramGradientIcon) in favor of 7 new "Nova" glass-style
icons: NovaBlueIcon, NovaTealIcon, NovaPurpleIcon, NovaPinkIcon, NovaOrangeIcon, NovaBlackIcon,
NovaRedIcon. AppIconLLCIcon stays the default, unchanged. PNG assets live in
`Telegram/Telegram-iOS/<Name>.alticon/` (8 files each, same naming convention the Novagram folders
used: `<Name>@2x/@3x`, `<Name>Ipad[@2x]`, `<Name>LargeIpad@2x`, `<Name>NotificationIcon[@2x/@3x]`).

**Supersedes the branding-trap note in the WatchApp-restoration section above (2026-06-22 entry) —
that note said `alternate_icon_folders` (NovagramYellow/Green/Gradient) must be preserved on merges;
the CURRENT list is the 7 Nova names below. Do not restore NovagramYellow/Green/Gradient.**

### `submodules/TelegramUI/Sources/AppDelegate.swift` — UPSTREAM hook (patched via python3, not Edit, per auto-lint policy)

`getAvailableAlternateIcons` icon list: the 3 `PresentationAppIcon(name: "Novagram...", ...)` entries
were replaced 1:1 with 7 Nova entries (same array shape; `AppIconLLCIcon` / `isDefault: true`
untouched). Internal `name:`/`imageName:` string equals the icon's `.alticon` folder basename in
every case.

### `submodules/SettingsUI/Sources/Themes/ThemeSettingsAppIconItem.swift` — UPSTREAM hook (patched via python3, not Edit) + newly localized

The hardcoded `var name = "Icon"` / `switch icon.name { case "NovagramYellowIcon": name = "Sariq" ... }`
display-name switch (Uzbek-only literal strings, no en/ru at all) is replaced with a
`NovagramL10n`-backed switch: `let novagramL10n = NovagramL10n(item.strings)`, then each case reads
`novagramL10n.iconName_<color>` (default/blue/teal/purple/pink/orange/black/red). Added
`import NovagramLocalization` after the existing `import AppBundle`. `item.strings:
PresentationStrings` is the item's own existing stored property (line 41) — call site uses the
positional `NovagramL10n(_:)` initializer (matches the convention used everywhere else in the
codebase, e.g. `AuthorizationSequencePhoneEntryControllerNode.swift:751`).

### `submodules/SettingsUI/BUILD`

Added dep (first Novagram dep in this BUILD file):

```python
"//submodules/Novagram/Localization:NovagramLocalization",
```

Reason: `ThemeSettingsAppIconItem.swift` now imports `NovagramLocalization` for `NovagramL10n`.

### `Telegram/Telegram-iOS/Info.plist` (fork-owned) — both `CFBundleAlternateIcons` dicts (iPhone `CFBundleIcons` + iPad `CFBundleIcons~ipad`)

Same 3→7 swap, mirroring the exact per-icon shape the Novagram entries already used:

- iPhone dict: `CFBundleIconFiles = [<Name>, <Name>NotificationIcon]`
- iPad dict: `CFBundleIconFiles = [<Name>Ipad, <Name>LargeIpad, <Name>NotificationIcon]`

Both blocks patched via python3 exact-string replacement — this file is tab-indented throughout,
so a scripted replacement was used to avoid any tab/space drift a hand-typed Edit could introduce.

### `Telegram/BUILD` (fork-owned)

`alternate_icon_folders` list: same 3→7 swap (feeds the `filegroup` list-comprehension that globs
each `Telegram-iOS/{name}.alticon/*.png` a few lines below it).

### `submodules/Novagram/Localization/Sources/NovagramL10n.swift` (fork-owned)

Added 8 new `pick(en:uz:ru:)`-backed properties under a new `// MARK: - Alternate app icon names`
section (right after `settings_chat_editedHistory_subtitle`): `iconName_default`, `iconName_blue`,
`iconName_teal`, `iconName_purple`, `iconName_pink`, `iconName_orange`, `iconName_black`,
`iconName_red`.

**Verified identical across every layer** (AppDelegate icon list ↔ Info.plist keys ↔ `.alticon`
folder basename ↔ `Telegram/BUILD` `alternate_icon_folders` string), for `AppIconLLCIcon` plus all
7 Nova names.

---

## 📌 Communication Notifications entitlement (push avatar / comm-style) — 2026-07-20

`Telegram/BUILD` line ~560. Upstream gates the `com.apple.developer.usernotifications.communication`
entitlement to Telegram's own bundle ids only:

```python
communication_notifications_fragment = official_communication_notifications_fragment if telegram_bundle_id in official_bundle_ids else ""
```

**Novagram hook — extend the condition with our App Store bundle ONLY (do NOT add to `official_bundle_ids`,
which is also read at BUILD:495/501/523 for VOIP/CarPlay/associated-domains — that would grant collateral
entitlements):**

```python
communication_notifications_fragment = official_communication_notifications_fragment if (telegram_bundle_id in official_bundle_ids or telegram_bundle_id == "uz.fenixuz.app") else ""
```

**Why:** without the entitlement, the NSE's `content.updating(from: INSendMessageIntent)`
(`Telegram/NotificationService/Sources/NotificationService.swift:696`) throws and is swallowed by the
print-only catch (:697-699), so lock-screen pushes render in plain app-icon style (no sender avatar, no
iOS-15 communication presentation) even though decryption works and the sender name + text render fine.
The entitlement only lands in the main-app `TelegramEntitlements` (BUILD:582-599, bound to the
`ios_application` at :1776) — the extensions incl. the NSE do NOT carry it, so only the `uz.fenixuz.app`
App ID needs the "Communication Notifications" capability + a regenerated App Store distribution profile
(`Fenixuz_AppStore.mobileprovision`). The capability is Apple self-serve (not approval-gated). Main-app
Info.plist already has `NSUserActivityTypes`→`INSendMessageIntent` (BUILD:1655-1658, upstream), so no
other change is needed. Avatar photo is cache-only (`peerAvatar()` :468, no fetch): real photo for
active contacts, monogram for never-opened senders.

---

## 📌 Deleted messages (anti-delete) — 2026-07-17 (Wave 2 same day: capture gating + real timestamp) · Wave 3 2026-08-26 (persisted-timestamp decode fix + notification-extension P0 gate)

NovagramPro feature: instead of letting a peer's message deletion actually remove the message
from the local Postbox, the fork can retain it (marked with a `DeletedMessageAttribute` that now
carries the actual deletion time) and show it inline with a "🗑 Deleted" label + timestamp,
exactly where it used to sit in the conversation — but only while the user toggle is on.

**Wave 2 change (same day as Wave 1 above):** capture is now itself gated by the toggle, not just
display. When `show_deleted_messages` is ON, a server-driven delete is intercepted and the message
is retained (marked, not removed). When OFF, the delete goes through unmodified — the message is
actually removed from Postbox, matching vanilla Telegram behaviour. (Wave 1 always retained+marked
every delete regardless of the toggle, and only gated _display_ in
`ChatHistoryEntriesForView.swift`; that display-side filter is unchanged and still needed as a
second gate for messages that were retained earlier while the toggle was on and are still sitting
in Postbox after the user turns it off.)

**Setting:** `show_deleted_messages`, suite `pro_messager`, default `false`, owned by
`NovagramMessenger` (`NovagramSettingsController.swift`). Same suite as every other NovagramPro
toggle (`fenix_show_ads`, `block_foreign_users`, etc. — see the NovagramMessenger sections above).

### `submodules/TelegramCore/Sources/Message/DeletedMessageAttribute.swift` (Wave 2: added `timestamp`)

The whole attribute, in full, after Wave 2:

```swift
import Foundation
import Postbox

public class DeletedMessageAttribute: MessageAttribute, Equatable {
    public let timestamp: Int32

    public init(timestamp: Int32) {
        self.timestamp = timestamp
    }

    public convenience init() {
        self.init(timestamp: 0)
    }

    required public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }

    public static func == (lhs: DeletedMessageAttribute, rhs: DeletedMessageAttribute) -> Bool {
        return lhs.timestamp == rhs.timestamp
    }
}
```

Before (Wave 1) this was a zero-payload marker: empty `init()`, empty `init(decoder:)`, empty
`encode(_:)`, `==` always `true`. Wave 2 adds a stored `timestamp: Int32` (the deletion time,
`Date().timeIntervalSince1970` at capture time — see the `AccountStateManagementUtils.swift` hook
below), encoded under key `"t"`. The parameterless `convenience init()` is kept so any code still
constructing the old way keeps compiling, defaulting to `timestamp: 0` — until Wave 3 (2026-08-26,
see below) this included the `AccountManager.swift` registration factory itself, which called this
parameterless init on every decode; Wave 3 switched it to call `init(decoder:)` instead.
`decodeInt32ForKey("t", orElse: 0)` makes decoding **backward-compatible**: an attribute encoded by
Wave 1 (no `"t"` key present in its bytes) decodes to `timestamp: 0` instead of throwing/crashing.

✅ **Fixed 2026-08-26 (Wave 3):** `AccountManager.swift:251`'s registration factory used to ignore
the decoder it's handed and always construct a fresh `DeletedMessageAttribute()` (i.e.
`timestamp: 0`). Postbox's heterogeneous-attribute decode path
(`PostboxDecoder.decodeRootObject()` → `decodeObjectForKey("_")` → `typeStore.decode(hash,
decoder:)` in `submodules/Postbox/Sources/Coding.swift`) calls **this factory**, not
`DeletedMessageAttribute.init(decoder:)` directly — so every re-decode from the on-disk store
(`MessageHistoryTable.swift`'s `decodeRootObject()` call sites) discarded the persisted timestamp
and replaced it with `0`, even for freshly-encoded Wave 2 data: the in-memory instance created at
capture time (in `AccountStateManagementUtils.swift`) held the correct timestamp only until the
next disk round-trip (app relaunch, or any history-view rebuild that re-decodes from Postbox) — the
"🗑 Deleted · <time>" label would then silently lose its time and fall back to the bare "🗑 Deleted"
text. Wave 3 applies the one-line fix that was flagged (but deliberately left unapplied) here since
Wave 2 — see the updated `AccountManager.swift:251` entry below for the fix itself.

Reason: a marker attribute — its presence flags a message as retained-after-delete; its (now
non-zero) payload records when that happened. Lives in `TelegramCore` (not a Novagram module)
because `MessageAttribute` conformance requires `Postbox` and every downstream consumer
(`AccountStateManagementUtils.swift`, `ChatHistoryEntriesForView.swift`,
`StringForMessageTimestampStatus.swift`) already depends on `TelegramCore`; a Novagram module would
need to be a new dependency of all three instead. No BUILD change needed — `TelegramCore/BUILD`
sources via `glob(["Sources/**/*.swift", ...])` (see `srcs = glob([...` at the top of the file), so
the field addition needed no BUILD edit.

---

### `submodules/TelegramCore/Sources/Account/AccountManager.swift:251` (Wave 3: FIXED 2026-08-26 — decoder now honored)

Inside the `declaredEncodables` static-let block, alongside every other `declareEncodable(...)`
call for a `MessageAttribute`/`Codable` type:

```swift
declareEncodable(DeletedMessageAttribute.self, f: { DeletedMessageAttribute(decoder: $0) })
```

Before Wave 3 (unchanged since Wave 1, when this line lived at `:247`): `f: { _ in
DeletedMessageAttribute() }` — the underscore discards the `PostboxDecoder` argument and always
built a fresh zero-payload instance. The line number moved `:247` → `:251` between Wave 2 and
Wave 3 because upstream added unrelated `declareEncodable(...)` calls above it in the interim
(always re-grep `DeletedMessageAttribute.self` here rather than trusting a cached line number).

Reason: every `PostboxCoding` type must be registered here or Postbox cannot decode it back out of
the on-disk keyed archive on next launch — an unregistered attribute silently vanishes across app
relaunches (the exact bug this line prevents for the attribute's _presence_). But until Wave 3, the
factory ignoring its decoder meant the attribute's _timestamp_ did not survive that same
round-trip: the "🗑 Deleted · <time>" label lost its time on every app relaunch (or any
history-view rebuild that re-decodes from Postbox) and fell back to the bare "🗑 Deleted" text,
even though the in-memory copy created at capture time (`AccountStateManagementUtils.swift`) held
the correct value the whole time. Wave 3 applies the fix flagged (but deliberately left unapplied)
back in Wave 2: `f: { DeletedMessageAttribute(decoder: $0) }` forwards the decoder into
`DeletedMessageAttribute.init(decoder:)` — the same initializer already used everywhere else
Postbox decodes this type — so the persisted `"t"` key is now read back correctly.

---

### `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift:4449-4546` (Wave 2: gated on `show_deleted_messages`)

Two `AccountStateMutationOperation` cases in the state-application switch —
`.DeleteMessagesWithGlobalIds(ids)` (4449-4505) and `.DeleteMessages(ids)` (4507-4546) — are
intercepted before they reach Postbox's real delete path, but (Wave 2 change) **only when the
toggle is on**. Both cases now read the setting first and branch on it:

```swift
case let .DeleteMessages(ids):
    let novagramShowDeleted = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
    if novagramShowDeleted {
        var actuallyDeletedIds: [MessageId] = []
        var retainedMessageIds: Set<MessageId> = []

        for id in ids {
            if let message = transaction.getMessage(id) {
                if message.attributes.contains(where: { $0 is DeletedMessageAttribute }) {
                    retainedMessageIds.insert(id)
                } else {
                    var newAttributes = message.attributes.filter { !($0 is DeletedMessageAttribute) }
                    newAttributes.append(DeletedMessageAttribute(timestamp: Int32(Date().timeIntervalSince1970)))

                    let storeForwardInfo = message.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    transaction.updateMessage(id, update: { _ in
                        return .update(StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: newAttributes, media: message.media))
                    })
                    retainedMessageIds.insert(id)
                }
            } else {
                actuallyDeletedIds.append(id)
            }
        }

        if !actuallyDeletedIds.isEmpty {
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: actuallyDeletedIds, manualAddMessageThreadStatsDifference: { id, _, remove in
                addMessageThreadStatsDifference(threadKey: id, remove: remove, addedMessagePeer: nil, addedMessageId: nil, isOutgoing: false)
            })
        }
        deletedMessageIds.append(contentsOf: actuallyDeletedIds.map { .messageId($0) })
        deletedMessageIds.append(contentsOf: retainedMessageIds.map { .messageId($0) })
    } else {
        if !ids.isEmpty {
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, manualAddMessageThreadStatsDifference: { id, _, remove in
                addMessageThreadStatsDifference(threadKey: id, remove: remove, addedMessagePeer: nil, addedMessageId: nil, isOutgoing: false)
            })
        }
        deletedMessageIds.append(contentsOf: ids.map { .messageId($0) })
    }
```

(`.DeleteMessagesWithGlobalIds` does the identical `novagramShowDeleted` gate keyed by global id
instead of `MessageId`: same capture-attribute-and-`updateMessage` branch when `true` — plus it maps
retained message ids back to their global ids before excluding them from the delete batch — and the
same unmodified `transaction.deleteMessagesWithGlobalIds(ids, ...)` + cached-media cleanup when
`false`, identical to Wave 1's always-on path.)

The rule, same in both cases: `novagramShowDeleted` is read once at the top of the case (`let
novagramShowDeleted = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages")
?? false`).

- **ON:** if the message still exists locally and does NOT already carry `DeletedMessageAttribute`,
  re-write it in place with the attribute added — now constructed as
  `DeletedMessageAttribute(timestamp: Int32(Date().timeIntervalSince1970))`, capturing the moment of
  interception as the deletion time — via `updateMessage` (not `deleteMessages`). This message is
  added to `retainedMessageIds`, not `actuallyDeletedIds` / the equivalent global-id list. Only
  messages that are already gone locally (`transaction.getMessage(id) == nil`, e.g. never synced) or
  already marked deleted (avoid double-marking / overwriting the original deletion timestamp when
  the peer double-deletes) fall through to the real `_internal_deleteMessages` /
  `transaction.deleteMessagesWithGlobalIds` call.
- **OFF (Wave 2 change):** the entire capture block is skipped — the `ids`/`ids` (global) go
  straight to `_internal_deleteMessages` / `transaction.deleteMessagesWithGlobalIds` unmodified,
  exactly as vanilla Telegram would. No retention, no attribute, no `updateMessage` call at all.

Reason: this is the actual "anti-delete" mechanism — the single chokepoint where every server-driven
delete (peer deletes for me/everyone, `updates.deleteMessages`, `updates.deleteChannelMessages`)
lands during state application. Intercepting here means every delete surface in the app (chat UI,
notifications, sync) is covered without hooking each one individually. Wave 2 moves the toggle read
from being purely a _display_ gate (`ChatHistoryEntriesForView.swift`, hook below) to also being a
_capture_ gate here: with the feature off, this fork now behaves identically to vanilla Telegram
(real deletes, no residual retained messages silently accumulating in Postbox for a feature the user
isn't using); with it on, behaviour matches Wave 1 exactly, plus the retained attribute now carries
a real timestamp instead of being a bare marker. `deletedMessageIds` (the function's return-side
accumulator used to drive UI invalidation/animations) still receives both retained and
actually-deleted ids in the ON branch (and all-deleted ids in the OFF branch), so the chat list /
message list still gets a change notification and re-runs its filter (see the
`ChatHistoryEntriesForView.swift` hook below) — a retained message just doesn't disappear from the
underlying data, only (optionally) from the rendered view.

---

### `submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift:155,169-171`

Inside the entries-loop, a hoisted read before the `loop: for entry in view.entries` (line 154 is
`var count = 0`):

```swift
let showDeletedMessages = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
loop: for entry in view.entries {
```

then inside the loop, right after the existing `pendingRemovedMessages` skip-check (line 165-167):

```swift
if !showDeletedMessages && message.attributes.contains(where: { $0 is DeletedMessageAttribute }) {
    continue
}
```

Reason: this is the display filter — the message is retained in Postbox (see the state-management
hook above) but is skipped when building the rendered chat-history entries unless the user has
`show_deleted_messages` on. The `UserDefaults` read is hoisted **outside** the per-entry loop (a
single read reused for every entry) rather than reading it once per message — this function runs
once per history-view transform and the view can contain hundreds of entries, so a per-entry
UserDefaults hit would be a needless syscall in the hot path. No new import needed: `TelegramCore`
(for `DeletedMessageAttribute`) is already imported at the top of this file (line 4); the toggle is
read directly via `Foundation.UserDefaults` rather than through a `NovagramMessenger` API call, matching
the existing style of every other inline `pro_messager` read in this codebase (see
`ChatController.swift`'s `blockForeignUsers` read for precedent).

---

### `submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/Sources/StringForMessageTimestampStatus.swift:223-230` (Wave 2: shows the deletion time)

Right before the function's final `return dateText`:

```swift
if let del = message.attributes.first(where: { $0 is DeletedMessageAttribute }) as? DeletedMessageAttribute {
    if del.timestamp > 0 {
        let deletedTimeText = stringForMessageTimestamp(timestamp: del.timestamp, dateTimeFormat: dateTimeFormat)
        dateText = "🗑 " + NovagramL10n(strings).status_deletedMessage + " · " + deletedTimeText + " " + dateText
    } else {
        dateText = "🗑 " + NovagramL10n(strings).status_deletedMessage + " " + dateText
    }
}
```

Wave 1 only ever appended the bare "🗑 Deleted" label. Wave 2 pulls the attribute instance itself
out (`as? DeletedMessageAttribute`, not just the earlier `contains(where:)` existence check) to read
its `timestamp`. When `timestamp > 0` (a real deletion time was captured — see the
`AccountStateManagementUtils.swift` hook above), it renders that time via the same
`stringForMessageTimestamp(...)` helper already used elsewhere in this function for the message's
own `dateText`, separated by `" · "`. When `timestamp == 0` — either genuinely old data encoded
before Wave 2 (see the backward-compat note in the `DeletedMessageAttribute.swift` entry above), or
(pre-2026-08-26 only — the gap was fixed in Wave 3, see the `AccountManager.swift:251` entry above)
a decode that hit the old factory-ignores-decoder bug — it falls back to the Wave 1 label with no
time, so no "🗑 Deleted · Jan 1, 1970" ever renders.

Reason: the localized "Deleted" label (+ now, time) shown next to the timestamp when a
retained-but-deleted message is visible (only reachable when `show_deleted_messages` is on — see
the display-filter hook above; if the filter hides the message this code path is simply never
reached for it). String key `status_deletedMessage` lives in
`submodules/Novagram/Localization/Sources/NovagramL10n.swift:252` (en/uz/ru). `import
NovagramLocalization` was already present in this file (line 9, added for an earlier hook) and
`NovagramLocalization` was already a dep of this component's BUILD file
(`submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/BUILD`) — no new import or
BUILD change needed for this hook. No new import needed for `stringForMessageTimestamp` either —
it's a top-level function already defined/used elsewhere in this same file.

---

### `submodules/TelegramUI/Sources/ChatHistoryListNode.swift:1885-1887` — reactivity (2026-07-17)

Immediately before the `historyViewTransitionDisposable` combineLatest chain, wraps the existing
`historyViewUpdate` signal:

```swift
// Novagram: re-run the history transform live when the "show deleted messages" toggle flips (mirrors the ads gate).
historyViewUpdate = combineLatest(queue: messageViewQueue, historyViewUpdate, NovagramShowDeletedGate.reloadSignal)
|> map { $0.0 }
```

`NovagramShowDeletedGate` lives in `submodules/Novagram/Messenger/Sources/NovagramShowDeletedGate.swift`
(pure Novagram code, not itself a hook — listed here only because it is the counterpart half of this
hook). It exposes:

```swift
public extension NSNotification.Name {
    static let novagramShowDeletedChanged = NSNotification.Name("NovagramShowDeletedChanged")
}

public enum NovagramShowDeletedGate {
    public static var reloadSignal: Signal<Void, NoError> {
        return Signal { subscriber in
            subscriber.putNext(())
            let observer = NotificationCenter.default.addObserver(forName: .novagramShowDeletedChanged, object: nil, queue: .main) { _ in
                subscriber.putNext(())
            }
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
```

The notification is posted from `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift:1440-1442`
(Novagram-owned, not a hook — reference only), inside the `updateShowDeletedMessages` argument
closure:

```swift
}, updateShowDeletedMessages: { value in
    UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_deleted_messages")
    NotificationCenter.default.post(name: .novagramShowDeletedChanged, object: nil)
```

Reason: `ChatHistoryEntriesForView.swift`'s filter (hook above) reads `show_deleted_messages` fresh
every time the history-view transform runs — but that transform only re-runs when Postbox's
underlying `historyViewUpdate` signal emits, i.e. on actual message changes. Without this hook,
flipping the toggle in NovagramPro settings would do nothing until the user backed out of the chat
and reopened it (the transform wouldn't re-run to pick up the new UserDefaults value). Wrapping
`historyViewUpdate` in `combineLatest(...)` with `NovagramShowDeletedGate.reloadSignal` — which emits
once immediately and again every time `.novagramShowDeletedChanged` posts — forces one extra transform
pass right after the toggle flips, in every already-open chat, live. This mirrors the exact
pattern already used for the ads toggle (`NovagramShowAdsGate.gate(...)`, hook C in the
"TelegramUI module" section above), except the ads gate wraps the ad-message _source_ signal
directly while this gate wraps the _trigger_ for re-running the whole history transform (the
filter itself lives in a different file, `ChatHistoryEntriesForView.swift`, so there is no single
signal to gate — the reload has to be pushed from the outside).

`import NovagramMessenger` was already present in this file (added 2026-06-27 for
`NovagramShowAdsGate`, see hook A in the "TelegramUI module" section above) — `NovagramShowDeletedGate` is
in the same module, so no new import or BUILD dep was needed. `NovagramShowDeletedGate.swift` itself
is picked up automatically by `NovagramMessenger/BUILD`'s `srcs = glob(["Sources/**/*.swift"])`.

---

### BUILD changes for this feature: none (still true after Wave 2)

Every file this feature touches already had its required dependency wired in from an earlier hook
batch. Wave 2 only edited method bodies inside already-covered files (`DeletedMessageAttribute.swift`
gained a field, `AccountStateManagementUtils.swift` and `StringForMessageTimestampStatus.swift`
gained branches) — no new files, no new imports, no new deps:

- `TelegramCore/BUILD` and `NovagramMessenger/BUILD` both glob their `Sources/`, so the two new files
  (`DeletedMessageAttribute.swift`, `NovagramShowDeletedGate.swift`) needed no BUILD edit.
- `TelegramUI/BUILD` already depends on `//submodules/Novagram/Messenger:NovagramMessenger`
  (added 2026-06-27, see the "TelegramUI module" section above) — covers both
  `ChatHistoryListNode.swift`'s `NovagramShowDeletedGate` import and (transitively, already imported)
  `TelegramCore` for `DeletedMessageAttribute` in `ChatHistoryEntriesForView.swift` and
  `AccountStateManagementUtils.swift`.
- `ChatMessageDateAndStatusNode/BUILD` already depends on
  `//submodules/Novagram/Localization:NovagramLocalization`.

---

## 📌 Deleted messages (anti-delete) — Wave 3, 2026-08-26 (persisted-timestamp decode fix + notification-extension P0 gate)

Two more gaps in the same feature, found and closed the same day. The `AccountManager.swift`
decode fix is documented above (rewritten in place, following this file's per-wave convention of
updating a file's one canonical entry rather than duplicating it). The rest of Wave 3 is new: a
shared, App-Group-aware toggle helper (`NovagramShowDeletedMessages.swift`), the two
`AccountStateManagementUtils.swift` capture-gate call sites switched over to it, a
`DeletedMessageAttribute` carry-forward in `SyncCore_StandaloneAccountTransaction.swift` (same bug
shape the `EditedMessageHistoryAttribute` carry-forward fixed on 2026-07-21 — re-synced
group/channel messages silently dropped the marker), and — the actual P0 — the toggle now gates the
NotificationService extension's own delete handling, the code path that runs while the app is
backgrounded and was, until today, completely unaware the "Deleted messages" toggle existed.

### `submodules/TelegramCore/Sources/Novagram/NovagramShowDeletedMessages.swift` (Wave 3: NEW file)

The whole file:

```swift
import Foundation

// Novagram "Deleted messages" (anti-delete) — single source of truth for the gate.
//
// The interesting part is WHERE this gets read. AccountStateManagementUtils runs in two
// processes: the main app, and the NotificationService extension (via standaloneStateManager /
// standalonePollDifference). `UserDefaults(suiteName: "pro_messager")` is a plain suite, not an
// App Group one, so it resolves to a *per-process* preferences container — the extension reading
// it always got `false`, took the vanilla delete path, and permanently erased the message from
// the shared Postbox before the app ever woke up. That is why the feature looked like it worked
// with the app open and silently did nothing with the app backgrounded.
//
// So: read the local suite first (authoritative in the main app, and the fast path), then fall
// back to the App Group suite, which the main app mirrors on every launch and on every toggle
// flip (see NovagramSharedDefaults in NovagramMessenger). Both bundle-id shapes are tried because
// the app is "uz.fenixuz.app" while the extension is "uz.fenixuz.app.NotificationService" —
// the App Group is named after the former in both processes.
@inline(__always)
internal var isNovagramShowDeletedMessagesEnabled: Bool {
    if UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") == true {
        return true
    }
    guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
        return false
    }
    if UserDefaults(suiteName: "group.\(bundleId)")?.bool(forKey: "show_deleted_messages") == true {
        return true
    }
    if let lastDotRange = bundleId.range(of: ".", options: [.backwards]) {
        let baseBundleId = String(bundleId[..<lastDotRange.lowerBound])
        if UserDefaults(suiteName: "group.\(baseBundleId)")?.bool(forKey: "show_deleted_messages") == true {
            return true
        }
    }
    return false
}
```

Reason: `AccountStateManagementUtils.swift`'s delete-interception cases (below) run in both the
main app and the NotificationService extension, but a plain `UserDefaults(suiteName:)` container is
per-process — the extension reading `"pro_messager"` directly always got `false` and took the real
delete path. This computed var centralizes the read: local suite first (fast path, authoritative in
the main app), then the App Group suite as fallback, trying both `group.<bundleId>` and
`group.<bundleId minus last component>` since the main app's bundle id (`uz.fenixuz.app`) and the
extension's (`uz.fenixuz.app.NotificationService`) differ but share one App Group named after the
former. This is a new fork-added file directly under `submodules/TelegramCore/Sources/Novagram/`,
joining `NovagramGhostMode.swift` and `NovagramGhostReadOnSend.swift` as small standalone
markers/gates that live in TelegramCore because their consumers (`AccountStateManagementUtils.swift`
chief among them) already depend on TelegramCore — a Novagram module would need to become a new
dependency of every consumer instead. No BUILD change needed: `TelegramCore/BUILD` globs
`Sources/**/*.swift`.

---

### `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift:4434,4492` (Wave 3: capture gate reads the shared helper)

Both `novagramShowDeleted` reads — `.DeleteMessagesWithGlobalIds(ids)` at `:4434` and
`.DeleteMessages(ids)` at `:4492` (line numbers shifted from Wave 2's `:4449`/`:4507` for the same
upstream-churn reason noted in the `AccountManager.swift` entry above) — change from:

```swift
let novagramShowDeleted = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
```

to:

```swift
let novagramShowDeleted = isNovagramShowDeletedMessagesEnabled
```

Everything else in both cases (the capture-and-retain loop, the `actuallyDeletedIds` /
`retainedMessageIds` split, the ON/OFF branching documented in the Wave 2 entry above) is
unchanged — only the toggle read itself moved into the shared helper.

Reason: in the main app this is a behavior-preserving refactor (`isNovagramShowDeletedMessagesEnabled`
checks the same `"pro_messager"` suite first). The actual fix is for the path where this same
function runs _inside_ the NotificationService extension (`standaloneStateManager` /
`standalonePollDifference` — see the file header comment on `NovagramShowDeletedMessages.swift`):
before Wave 3, that process always read `false` here and fell through to the real delete,
regardless of the user's toggle. This is a different code path from the next hook (in
`NotificationService.swift` itself), which intercepts the silent `MESSAGE_DELETED` push directly,
before it ever reaches this shared state-application switch. Both were real, independent gaps;
closing only one would still have left the other silently dropping retained messages.

---

### `submodules/TelegramCore/Sources/SyncCore/SyncCore_StandaloneAccountTransaction.swift` (Wave 3: `DeletedMessageAttribute` carry-forward)

Inside the `mergeMessageAttributes:` seed-configuration closure, right after the existing
`EditedMessageHistoryAttribute` carry-forward block:

```swift
// Novagram: DeletedMessageAttribute is local-only too (the anti-delete marker we write
// instead of really deleting). Same re-sync path as the edit history above would strip
// it, so a retained message silently loses its 🗑 label — or, with the toggle off,
// reappears as an ordinary message. Carry it forward.
var previousDeleted: DeletedMessageAttribute?
for attribute in previous {
    if let attribute = attribute as? DeletedMessageAttribute {
        previousDeleted = attribute
        break
    }
}
if let previousDeleted {
    var found = false
    for i in 0 ..< updated.count {
        if let _ = updated[i] as? DeletedMessageAttribute {
            found = true
            break
        }
    }
    if !found {
        updated.append(previousDeleted)
    }
}
```

Reason: exactly the same bug shape that broke Edited-history in groups/channels (see the
`EditedMessageHistoryAttribute` entry, 2026-07-21, above): `DeletedMessageAttribute` is a
local-only marker the server never sends, so a message re-arriving via `getChannelDifference`
newMessages (`.InsertExistingMessage` → `justUpdate`) would get replaced by the server's copy —
which has no `DeletedMessageAttribute` — silently dropping the retention marker. With the toggle
on, a previously-retained message would pop back to looking like an ordinary (never-deleted)
message the next time its group/channel re-synced. Carrying it forward, unconditionally (matching
the unconditional style of the `AudioTranscription`/`DerivedData`/`RichText` entries already in
this closure), keeps the marker — and its timestamp — intact across re-syncs, consistent with "a
retained message stays retained until explicitly restored." No BUILD change: `TelegramCore/BUILD`
globs `Sources/**/*.swift`.

---

### `Telegram/NotificationService/Sources/NotificationService.swift:2434` (Wave 3 — THE P0 FIX, first-ever Novagram hook in this file)

Inside `case let .deleteMessage(ids):` (the handler for a silent `MESSAGE_DELETED` push), right
before the existing `stateManager.postbox.transaction { ... }` delete call:

```swift
let mediaBox = stateManager.postbox.mediaBox
// Novagram: anti-delete ("Deleted messages" toggle). Telegram sends a silent
// MESSAGE_DELETED push and THIS extension is what removes the message from the
// shared Postbox whenever the app is backgrounded — so the app-side gate in
// AccountStateManagementUtils never gets to see the delete at all. Read the
// toggle from the App Group suite (the "pro_messager" suite is per-process and
// always reads false here) and, when it is on, mark the message instead of
// deleting it, with the same logic as the in-app path. Delivered-banner removal
// below is unchanged either way — the peer did delete it, we only keep the row.
let novagramShowDeleted = UserDefaults(suiteName: appGroupName)?.bool(forKey: "show_deleted_messages") ?? false
let _ = (stateManager.postbox.transaction { transaction -> Void in
    if novagramShowDeleted {
        var actuallyDeletedIds: [MessageId] = []
        for id in ids {
            guard let message = transaction.getMessage(id) else {
                actuallyDeletedIds.append(id)
                continue
            }
            if message.attributes.contains(where: { $0 is DeletedMessageAttribute }) {
                // Already marked — don't overwrite the original deletion time.
                continue
            }
            var newAttributes = message.attributes.filter { !($0 is DeletedMessageAttribute) }
            newAttributes.append(DeletedMessageAttribute(timestamp: Int32(Date().timeIntervalSince1970)))

            let storeForwardInfo = message.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            transaction.updateMessage(id, update: { _ in
                return .update(StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: newAttributes, media: message.media))
            })
        }
        if !actuallyDeletedIds.isEmpty {
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: actuallyDeletedIds, deleteMedia: true)
        }
    } else {
        _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, deleteMedia: true)
    }
}
|> deliverOn(strongSelf.queue)).start(completed: {
    // ... unchanged: delivered-notification removal logic
```

`appGroupName` is the existing local (`"group.\(baseAppBundleId)"`) declared at the top of this
handler's `init?` around line 791 — already in scope this deep in, since the whole notification
pipeline is one long nested-closure chain off that `init?`. No new import: `TelegramCore` (for
`DeletedMessageAttribute`, `_internal_deleteMessages`, `StoreMessage`, …) was already imported at
the top of this file. No BUILD change: `Telegram/NotificationService/BUILD` already depends on
`//submodules/TelegramCore:TelegramCore` (this file uses TelegramCore extensively already,
unrelated to Novagram).

Reason: **this is the actual root cause of the bug, not `AccountStateManagementUtils.swift`.**
Telegram delivers a delete as a silent push (`MESSAGE_DELETED`), iOS wakes `NotificationService`
to process it, and — until this hook — the extension's `case let .deleteMessage(ids):` branch
called `_internal_deleteMessages(...)` unconditionally, erasing the message from the shared
Postbox before the main app's own delete-interception gate (in `AccountStateManagementUtils.swift`)
ever got a chance to run. So "anti-delete" only ever worked while the app was open in the
foreground — a peer deleting a message while this user had the app backgrounded (the common case)
silently defeated the feature every time, with no error and no indication anything was skipped.
`NotificationService.swift` had **zero** Novagram hooks before this change; it is now a
Telegram-owned file the fork touches, and this entry is its first line in `HOOKS.md`. The
delivered-notification-removal logic that follows is unchanged either way — the peer did delete the
message from their side regardless of the toggle, so the local push banner for it is always
cleared; the toggle only decides whether the _message itself_ survives in Postbox.

---

### `submodules/Novagram/Messenger/Sources/NovagramShowDeletedGate.swift` (Wave 3: `NovagramSharedDefaults` mirror — Novagram-owned, not itself a hook)

Appended to the existing file (which already held `novagramShowDeletedChanged` +
`NovagramShowDeletedGate.reloadSignal`, documented under Wave 1/2 above):

```swift
// MARK: - App Group mirror (so the notification extension can see the toggle)

/// The "Deleted messages" flag has to be readable from the NotificationService extension: Telegram
/// pushes a silent `MESSAGE_DELETED` and the extension is what actually removes the message from
/// the (shared) Postbox, long before the app's own state manager ever sees the delete.
///
/// `UserDefaults(suiteName: "pro_messager")` is a plain suite, so it resolves to a *per-process*
/// container — the extension reading it always gets `false`. Mirror the value into the App Group
/// suite, which both processes really do share.
public enum NovagramSharedDefaults {
    /// Key is deliberately the same as in the `pro_messager` suite so the two stay easy to trace.
    public static let showDeletedMessagesKey = "show_deleted_messages"

    /// Main-app side only. The extension derives its own name by stripping its bundle-id suffix.
    public static var appGroupName: String? {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            return nil
        }
        return "group.\(bundleId)"
    }

    /// Copies the current `show_deleted_messages` value into the App Group suite. Safe to call
    /// repeatedly; also acts as the backfill for users who had the toggle on before this shipped.
    public static func syncShowDeletedMessages() {
        guard let appGroupName = self.appGroupName, let shared = UserDefaults(suiteName: appGroupName) else {
            return
        }
        let value = UserDefaults(suiteName: "pro_messager")?.bool(forKey: self.showDeletedMessagesKey) ?? false
        shared.set(value, forKey: self.showDeletedMessagesKey)
    }
}
```

Reason: the write-side counterpart to `NovagramShowDeletedMessages.swift`'s read-side fallback above
— instead of making every reader re-derive both App Group name shapes, the main app proactively
copies its `"pro_messager"` value into the App Group suite whenever it might have changed (see the
two call sites below). Novagram-owned file (`submodules/Novagram/Messenger/`), so this entry is
reference-only, listed here because it is the necessary counterpart to the two genuine hooks that
call it (`NovagramSettingsController.swift` and `AppDelegate.swift`, both below). No BUILD change:
`NovagramMessenger/BUILD` globs `Sources/**/*.swift`, and this is the same file `NovagramShowDeletedGate`
already lives in, so no new dependency anywhere that already imports `NovagramMessenger`.

---

### `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift:1600-1604` (Wave 3: sync on toggle flip — Novagram-owned, not itself a hook)

The `updateShowDeletedMessages` argument closure gained one line:

```swift
}, updateShowDeletedMessages: { value in
    UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_deleted_messages")
    // The notification extension can only see the App Group suite, and it is the process that
    // handles the MESSAGE_DELETED push while the app is backgrounded.
    NovagramSharedDefaults.syncShowDeletedMessages()
    NotificationCenter.default.post(name: .novagramShowDeletedChanged, object: nil)
```

Reason: the moment the user flips the toggle is the moment the App Group mirror can go stale, so
sync immediately rather than waiting for the next launch. Novagram-owned file, not a hook — listed
for context, same as the `NotificationCenter.default.post(...)` line right after it (already
documented under Wave 1/2 above).

---

### `submodules/TelegramUI/Sources/AppDelegate.swift:1223-1228` (Wave 3: launch backfill)

Just before the existing "Novagram Analytics" launch block:

```swift
// Novagram: mirror the "Deleted messages" toggle into the App Group suite. The
// NotificationService extension handles the MESSAGE_DELETED push while the app is
// backgrounded, and a plain UserDefaults suite is per-process so it cannot read the app's
// own copy. Running this every launch also backfills users who had the toggle on before
// the mirror existed.
NovagramSharedDefaults.syncShowDeletedMessages()
```

Reason: covers the gap `NovagramSettingsController.swift`'s on-flip sync (above) can't: a user who
turned the toggle on _before_ Wave 3 shipped has a `"pro_messager"` value with no corresponding App
Group mirror yet, and won't touch the Settings toggle again just to create one. Running the sync
unconditionally on every launch is idempotent (same value in, same value out, most days) and
guarantees the mirror exists before the user backgrounds the app and a delete push arrives.
`import NovagramMessenger` was already present in this file (line 7, added 2026-06-27 for
`NovagramShowAdsGate`) — `NovagramSharedDefaults` lives in the same module, so no new import or BUILD dep.

---

### BUILD changes for Wave 3: none

Every file Wave 3 touches already had its required dependency wired in from an earlier hook batch,
or globs its sources:

- `TelegramCore/BUILD` globs `Sources/**/*.swift` — covers the new `NovagramShowDeletedMessages.swift`
  and the edited `AccountManager.swift` / `AccountStateManagementUtils.swift` /
  `SyncCore_StandaloneAccountTransaction.swift`.
- `NovagramMessenger/BUILD` globs `Sources/**/*.swift` — covers the `NovagramShowDeletedGate.swift` addition.
- `TelegramUI/BUILD` already depends on `//submodules/Novagram/Messenger:NovagramMessenger` (added
  2026-06-27) — covers `AppDelegate.swift`'s `NovagramSharedDefaults` call.
- `Telegram/NotificationService/BUILD` already depends on `//submodules/TelegramCore:TelegramCore` —
  covers the new hook's `DeletedMessageAttribute` / `_internal_deleteMessages` / `StoreMessage`
  references; this file uses TelegramCore throughout, independent of Novagram.

---

## 📌 2026-07-22 — Location page: ETA permission flow + timeout fallbacks (stuck-shimmer fix)

**Files:** `submodules/LocationUI/Sources/LocationUtils.swift` (`getExpectedTravelTime`) and
`submodules/LocationUI/Sources/LocationViewControllerNode.swift` (static-location `eta` signal).

**Root cause (confirmed on device 2026-07-22, `[NovagramETA]` logs):** with location access denied,
MapKit's `calculateETA` (source = `MKMapItem.forCurrentLocation()`) returns `kCLErrorDomain
Code=1` on the first request after launch and then **never invokes the completion handler at
all** on subsequent requests. Upstream's eta pipeline has no timeout, drops any tuple containing
`.calculating`, and SwiftSignalKit `combineLatest` never completes until all inputs complete —
so one starved callback froze the page at the seeded `(.calculating, .calculating)`: permanent
shimmer / never-appearing directions buttons (`LocationInfoListItem.swift:351`). Fork's
LocationUI is byte-identical to upstream/master 12.9.2 tip — fork-only hardening, nothing to
cherry-pick.

**Hook A — `LocationUtils.swift` `getExpectedTravelTime`:**

1. Permission pre-check at the top: if `CLLocationManager.authorizationStatus()` is not
   `authorizedWhenInUse`/`authorizedAlways`, emit `.unknown` + complete immediately (instant
   "Get Directions" button, no doomed MapKit request). Also protects the live-location per-row
   ETA badges (`LocationViewControllerNode.swift` ~line 600 calls the same function).
2. One-shot `SwiftSignalKit.Timer(timeout: 15.0)` fallback on the authorized path: emits
   `.unknown` + completes + `directions.cancel()` if `calculateETA` stays silent; the callback
   and the `ActionDisposable` both invalidate it. `Subscriber` ignores post-completion events —
   the timer-vs-callback race is safe. Timer stays alive via strong captures in the
   `calculateETA` closure (retained by MapKit) and the disposable.
3. `#if DEBUG` `[NovagramETA]` NSLog lines (start/callback/TIMEOUT/disposed) kept for future
   regression debugging; compiled out of release builds.

**Hook B — `LocationViewControllerNode.swift` static-location `eta`:**

1. `etaAuthorization` gate before the ETA requests: `.notDetermined` →
   `DeviceAccess.authorizeAccess(to: .location(.send), ...)` (standard system prompt via
   `requestWhenInUseAuthorization`, presented through `interaction.present`); every other status
   resolves instantly with no alerts (denied stays silent). Grant → real ETA flow; deny →
   `.single((.unknown, .unknown))`.
2. Chain-level `|> timeout(20.0, queue: .mainQueue(), alternate: .single((.unknown, .unknown)))`
   around the `combineLatest |> mapToSignal` pair filter — second safety net (that inner signal
   emits nothing until a terminal pair, so `timeout` acts as a hard cap from subscription).
3. `#if DEBUG` `[NovagramETA] deliver` NSLog in the big `combineLatest` subscriber.

**Upstream-merge note:** if upstream rewrites `getExpectedTravelTime` or the `eta` construction,
re-apply both hooks at the new positions (upstream code wins around them; the permission gate,
the 15s timer, and the 20s chain timeout are the non-negotiable parts).

### BUILD changes: none

`LocationUI/BUILD` already had every needed dep (`import SwiftSignalKit`, `import DeviceAccess`,
`import CoreLocation` were all already present in the touched files).

---

## 📌 2026-07-22 — Open In sheet: app tiles not tappable (upstream cherry-pick)

**File:** `submodules/OpenInExternalAppUI/Sources/OpenInOptionsScreen.swift` — `OpenInAppView.init`

**Hook:** two lines — `self.iconView.isUserInteractionEnabled = false` and
`self.titleLabel.isUserInteractionEnabled = false`. The icon `TransformImageView` and the title
`UILabel` are subviews of a `UIControl` and were swallowing touches, so tapping the Maps/Yandex
tiles on the location "Open In" sheet did nothing (reproduced on device 2026-07-22).

This is a verbatim early cherry-pick of the `OpenInOptionsScreen.swift` hunk of upstream commit
`5df5e0a2c6` ("Various fixes", 2026-06-11) — the next `git pull upstream master` converges to
identical code, so expect no conflict (or a trivial both-sides-identical one). No other hunks of
that commit were taken.

### BUILD changes: none

---

## 📌 2026-07-22 — Upstream release-12.9.2 merge (12.8 → 12.9.2)

Merged upstream `release-12.9.2` (254 commits, 994 files, MTProto layer 227→228) into the fork on branch `merge/upstream-12.9.2`, commit `8a8857e0be`. 24 content conflicts resolved (per-file agents, "hooks win, upstream around them"). Post-merge audit of **238 hook-sites: 0 lost, 225 present as documented, 4 adapted, 9 stale-doc entries corrected below.** Build green first pass (`./run.sh`, 4900 actions, 0 errors).

### Adapted during this merge (behavior preserved, anchors changed)

1. **EnqueueMessage.swift — Ghost read-on-send**: upstream split the transaction into a `(resultIds, ephemeralMessageIds)` tuple + a new `|> map` ephemeral-send stage. The in-transaction `.Cloud` read is now at ~614-616, `afterCompleted { novagramForceReadHistory }` re-attached after the new map stage (~626-631).
2. **ChatControllerNode.swift — #37 Send-Translate / #31 auto-translate**: hooks gained a `!sendAsRichMessage` guard (~4955) so upstream's new rich-message send path (tables/headings/lists) bypasses plain-text auto-translate — otherwise formatting would be destroyed. Auto Text Adder likewise remains text-path-only.
3. **ChatTextInputPanelNode.swift — STT**: `onTextUpdate`/`onError` closures rewired to the new `richTextInputNode` API (`loadTextInputNodeIfNeeded()` + `self.text` setter). Same replace-whole-input behavior. Line refs in older sections shifted (e.g. `sttButtonPressed` ~5904 → ~6160).
4. **ChatListSearchListPaneNode.swift — Novagram search ads**: re-applied into upstream's new communities-search structure; `foundRemotePeers` is now a 5-tuple ending in `NovagramPromotedChannel?`; new `communityId != nil` scoped-search branch deliberately returns `nil` ad (no global promo inside a community).

### Stale-doc corrections (absent BEFORE this merge too — not merge losses; verified against pre-merge `dfb547b0ce`)

- **NovagramAppStoreIAP per-site hooks** (`ChatController.swift` bot-invoice gate, `OpenResolvedUrl.swift` slug gate, `WebAppController.swift` + `WebUI/BUILD`, `AppDelegate.swift` import/isAppStoreBuild mirror, `TelegramUI/BUILD` dep): all superseded by the 2026-05-19 full StoreKit-removal rewrite — the IAP gate lives ONLY in `InAppPurchaseManager.swift` now. Those older § blocks are historical.
- **ApplicationContext.swift 1s contacts-prompt defer**: removed before this merge; the file carries only upstream's own `didAppear`/`after(0.15)` logic. (A comment at ~834 still references the defer — harmless.)
- **Send-Confirm #38 voice @ `micButton.stopRecording`**: superseded — the hook moved to `sendMediaRecording()` (already documented in the later entry); the 2108-2116 paragraph is historical.
- **WatchApp team scrub**: `C67CF9S4VU` had crept back via a tgwatch re-sync; re-scrubbed to `ZDBP5RSRZF` on 2026-07-22 (`project.yml` + `tgwatch.xcodeproj/project.pbxproj`, 4 spots). Re-apply on every future watch re-sync.

### Undocumented hooks discovered by the audit (documented here now)

- `AccountContext.swift` (AccountContext module): `isRealPremium` member on the `AccountContext` protocol.
- `AccountContext/Sources/ChatController.swift`: `navigateToFirstMessage()` on the `ChatController` protocol (View First Message).

> ⚠️ Line numbers in sections written before 2026-07-22 may have shifted ±20-60 lines after this merge. The `// Novagram:` comment anchors remain authoritative — locate hooks by grep, not by line number.

## 📌 2026-07-22 — Force per-message Translate always-on (NovagramPro)

`submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` (~line 1483). The pre-existing `showProTranslate` hook (reads `pro_messager` suite key `show_translate_messages`; the code's default is `false` (`?? false`), corrected 2026-09-23) forces the `showTranslate:` argument of `canTranslateText(...)` true — BUT `canTranslateText` (upstream `TranslateUI/Sources/Translate.swift`, unchanged by us) still runs Apple `NLLanguageRecognizer` on the first 64 chars and hides Translate for short/undetectable text or the user's own languages. Users reported Translate appearing on some messages but not others ("small words yes, big words no") — that is upstream behavior, not a bug.

Per user request (2026-07-22) Translate must appear on EVERY message. Added right after the `canTranslateText` call:

```swift
// Novagram: when the NovagramPro "translate messages" toggle is on, force Translate onto every
// non-empty text message, bypassing Apple language detection ...
if showProTranslate && !messageText.isEmpty {
    canTranslate = true
}
```

Ordering matters: the force is BEFORE the SecretChat `canTranslate = false` block, so secret chats stay excluded. Media with no caption stays excluded (`!messageText.isEmpty`). The translate action itself is Telegram's own `.translate` → `TextProcessingScreen` (server auto-detects source language), so translation works unchanged; only button visibility is forced. Toggle off `show_translate_messages` to restore native language-detection gating. No BUILD change.

---

## 📌 Runaway push notifications — two fixes (2026-07-28)

From the "notifications keep arriving although Group Chats / Channels are OFF" report (~180K users, build 12.9.2 (64)). Both changes are additive; neither removes a user-visible feature.

### A. Secret Vault unhide must restore the DEFAULT, not force an unmute

`updatePeerMuteSetting(muteInterval:)` semantics (`TelegramCore/.../ChangePeerNotificationSettings.swift:192` vs `:203`):

| value       | resulting `muteState` | effect                                                         |
| ----------- | --------------------- | -------------------------------------------------------------- |
| `Int32.max` | `.muted(until: max)`  | muted forever                                                  |
| `0`         | `.unmuted`            | **explicit per-peer exception — outranks the global category** |
| `nil`       | `.default`            | inherits Group Chats / Channels / Private Chats                |

The vault mutes a chat on hide and un-mutes it on unhide. It was passing **`0`**, which writes a permanent server-side exception: the chat then notifies forever even with "Group Chats: OFF", and shows up in the exceptions list the user never created. Upstream uses `nil` at every restore-default site (`TelegramEnginePeers.swift:437`, `ChatContextMenus.swift:912`/`:1157`, `ChatController.swift:6208`). Changed `0` → `nil` at all four vault sites:

- **`submodules/ChatListUI/Sources/ChatContextMenus.swift`** — the per-chat "Unhide from Vault" long-press action.
- **`submodules/ChatListUI/Sources/ChatListController.swift`** — `novagramSetChatsVaulted(_:peerIds:)`: hoisted `let vaultMuteInterval: Int32? = vaulted ? Int32.max : nil`, and the Undo closure's `let undoMuteInterval: Int32? = vaulted ? nil : Int32.max`.
- **`submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift`** (module-owned) — vault master toggle OFF, which loops every vaulted peer at once.

Behaviour delta to be aware of: an un-hidden chat now inherits the global category instead of being guaranteed to notify. That matches both the fork's own intent ("undo our mute") and upstream semantics. **No migration ships** — rewriting already-affected peers back to `.default` would also wipe exceptions the user created deliberately; those users clear them via Settings ▸ Notifications ▸ Group Chats ▸ Delete All Exceptions.

### B. `submodules/SettingsUI/Sources/Notifications/NotificationsAndSoundsController.swift` — "Show Notifications From: All Accounts" was invisible

```swift
// Novagram: count LOGGED-IN RECORDS, not live contexts. ...
let hasMoreThanOneAccount = context.sharedContext.accountManager.accountRecords()
|> map { view -> Bool in ... count records without .loggedOut ... return count > 1 }
|> distinctUntilChanged
```

`hasMoreThanOneAccount` gates the whole `accountsHeader` / `allAccounts` / `accountsInfo` section (`:531-535`). It was derived from `activeAccountContexts`, but the fork's account working-set (`SharedAccountContext.swift:750`, `novagramWorkingSet`) keeps only the **primary** account live — the pinned set defaults to empty (`:195`, `:204`) — so `contexts.count > 1` is permanently false and the section never rendered. Multi-account users therefore had no way to reach the one switch that stops notifications from their other accounts. Counting logged-in records restores upstream behaviour. `import Postbox` added (already a `SettingsUI/BUILD` dep, used by three sibling files) — no BUILD change.

**Note — `HOOKS.md` correction:** the working-set note at "Multi-account working set" says the cap "only engages at 4+ accounts". That is **wrong**: `novagramOrdered = [primary] + pinned` and pinned defaults to empty, so eviction engages at **2** accounts.

**Still open (needs owner approval):** an evicted account is never unregistered from APNs — `unregisterNotificationToken` has exactly two call sites (`SharedAccountContext.swift:1871`, `:1885`), both inside the `for (_, account, _) in activeAccounts` loop at `:1865`, which an evicted account is not in. So the server keeps pushing for it. Fixing that unconditionally would remove documented intended behaviour (suspended accounts keep push).

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` — looping intro phone (2026-07-30)

In `init(...)`, the `IntroPhone` sticker setup. Find:

```swift
self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroPhone"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
```

Replace `.once` with `.loop` (keep the `// Novagram:` comment above it).

Reason: upstream plays the phone once on appear and then freezes until the user starts typing, at
which point `managedAnimationNode` takes over with the per-digit dialling animation. Azimjon wants
the resting state to keep moving, matching the looping chatbot on the bot-token screen.

**A second hook in the same file is required, or the first one does nothing.** Upstream wires:

```swift
self.animationNode.completed = { [weak self] _ in
    self?.animationNode.removeFromSupernode()
    self?.managedAnimationNode.isHidden = false
}
```

That tears the node down as soon as the animation finishes — which with `.loop` fires at the end of
the first cycle, so the looping node is removed and the static dialling node takes its place. The
`.loop` change alone is a no-op.

Fix: delete that `completed` closure (replaced by a comment) and move the hand-off into
`phoneAndCountryNode.keyPressed`, which already existed for the dialling animation:

```swift
self.phoneAndCountryNode.keyPressed = { [weak self] num in
    guard let strongSelf = self else { return }
    if strongSelf.managedAnimationNode.isHidden {
        strongSelf.animationNode.removeFromSupernode()
        strongSelf.managedAnimationNode.isHidden = false
    }
    strongSelf.managedAnimationNode.animate(num: num)
}
```

Net effect: the phone loops while the field is empty, and the per-digit dialling animation still
takes over the moment the user types — **no upstream behaviour is lost**, only its trigger moves.

---

### `submodules/ChatListUI/Sources/ChatListController.swift` — Secret Vault leak via the story bar (2026-07-30)

**Bug:** a chat hidden into the Secret Vault disappeared from the chat list, but when that peer
posted a Story their avatar still appeared in the story bar at the top of the list.

**Cause:** the vault filter lived only in `ChatListUI/Sources/Node/ChatListNodeEntries.swift`, which
builds _chat-list entries_. The story bar does not come from that pipeline — it has its own feed,
`context.engine.messages.storySubscriptions(...)`, which was never filtered.

Filtering had to go at the **source**, not where the ordered list is built: `ChatListController` also
assigns `self.orderedStorySubscriptions = self.rawStorySubscriptions` directly on reset (`:928-930`),
so a filter applied only in the ordering loop would be bypassed on that path. Putting it in the
signal means every consumer — `hasStorySubscriptions`, the ordering loop, and
`shouldDisplayStoriesInChatListHeader` (so the whole bar hides when the only story was vaulted) —
sees the filtered set.

**Hook — two sites, both the same shape.** Insert after `|> deliverOnMainQueue` in the
`storySubscriptionsDisposable` (main list) and `storyArchiveSubscriptionsDisposable` (archive)
pipelines:

```swift
|> map { subscriptions -> EngineStorySubscriptions in
    return EngineStorySubscriptions(accountItem: subscriptions.accountItem, items: SecretVaultManager.shared.removingVaulted(subscriptions.items, peerId: { $0.peer.id }), hasMoreToken: subscriptions.hasMoreToken)
}
```

The filter itself is `SecretVaultManager.removingVaulted(_:peerId:)` (Novagram-owned, generic over
any peer-keyed list, no-ops when the vault is disabled or empty). `ChatListController.swift` already
imports `NovagramSecretVault` and `ChatListUI/BUILD` already carries the dep — no BUILD change.

**Nothing removed** — the map only drops vaulted peers; non-vaulted stories are untouched.

**Known scope limit:** vaulted peers' stories are hidden in _every_ story bar, including while the
user is inside the vault list (`novagramVaultMode`). If they should be visible there, that needs a
`novagramVaultMode` check threaded into the map — deliberately not done, hiding is the safer default.

**Generalise this:** any other surface that builds its own peer feed instead of going through
`ChatListNodeEntries` will have the same leak. Audit candidates: global search results, forward /
share peer pickers, contacts list, call list.

---

## Hidden Chats — empty state uses the bundled duck sticker (2026-07-31)

The pushed Hidden Chats list is a plain root `ChatListControllerImpl`, so an empty vault fell
through to the generic `.chats` empty state: "You have no conversations yet" plus a **New Message**
button that makes no sense on that screen. It now gets its own subject.

**Animation:** `ChatListNoResults` — the search-duck sticker already bundled at
`submodules/TelegramUI/Resources/Animations/ChatListNoResults.tgs`. It is byte-identical to the
`.tgs` that prompted this change, so nothing new ships and the binary does not grow. Loaded through
the normal `AnimatedStickerNodeLocalFileSource` path like every other empty state.

- **`submodules/ChatListUI/Sources/ChatListEmptyNode.swift`** — `import NovagramSecretVault`;
  `Subject` gains `case novagramVault`; `gloss = false`, `animationName = "ChatListNoResults"` +
  `buttonIsHidden = true` for it; `updateThemeAndStrings` maps it to `SecretVaultStrings.emptyTitle`
  / `.emptyText` with `buttonText = nil`.
- **`submodules/ChatListUI/Sources/ChatListContainerItemNode.swift`** — the subject selection starts
  with `if strongSelf.controller?.novagramIsVaultList == true { subject = .novagramVault }`.
- **`submodules/ChatListUI/Sources/ChatListController.swift`** — `novagramIsVaultList` went from
  `fileprivate` to internal so `ChatListContainerItemNode` (same module, different file) can read it.

`SecretVaultStrings.emptyTitle` / `.emptyText` already existed and were unused — no new strings.
`ChatListUI/BUILD` already deps on `NovagramSecretVault` — no BUILD change.

---

## Hidden Chats — long-press entry point survives the collapsed story bar (2026-07-31)

**Symptom:** long-pressing the "Chats" title did nothing; a tap expanded the story panel instead.
Reproduced on the simulator — the story panel expanded on long press.

**Root cause — two independent faults, both confirmed with runtime logging:**

1. **`findTitleView()` returns nil in this header layout.** It resolves
   `primaryContentView?.chatListTitleView`, and the root chat list's current header never builds a
   `ChatListTitleView`. The whole attach block was gated on `let titleView = self.findTitleView()`,
   so **no gesture was ever attached** — not the long press, not the 10-tap. Logged live:
   `attached=0 navbar=ChatListNavigationBar.View header=ChatListHeaderComponent.View title=nil
titleContent=nil story=StoryPeerListComponent.View`.
2. **The collapsed story bar owns the title band.** `StoryPeerListComponent.View.collapsedButton`
   (`StoryPeerListComponent.swift:1372`) is a full-width `HighlightableButton` spanning
   `minTitleX…maxTitleX`, enabled whenever the bar is collapsed (`:1722`); its `hitTest` (`:1552`)
   claims every touch there. It is a **sibling** of the title view, not a descendant — so even if
   fault 1 were fixed alone, a title-anchored recognizer still would not fire.

**Fix:** anchor the attach and the long press on the navigation bar — which always exists and is an
ancestor of every title variant — and filter by hit target.

- **`submodules/Novagram/SecretVault/Sources/SecretVaultTitleLongPressGestureRecognizer.swift`**
  (module-owned, new) — `UILongPressGestureRecognizer` subclass that fails in `touchesBegan` when a
  supplied predicate rejects the point. Filtering there (not via a delegate) means a press outside
  the title fails immediately and never cancels the touch for the view that owns it.
- **`submodules/ChatListUI/Sources/ChatListController.swift`** — `import StoryPeerListComponent`;
  in `novagramSetupSecretVaultIfNeeded` the attach is now gated on
  `chatListDisplayNode.navigationBarView.view` instead of `findTitleView()`, and the long press
  goes on that navigation bar. The 10-tap recogniser still goes on the title view when one exists
  (`if let titleView = self.findTitleView()`), so it is no longer load-bearing for the attach.
  New `novagramVaultLongPressCanBegin(at:)` accepts the press when the hit view is the title view, the
  header's `titleContentView`, or a **direct** subview of `storyPeerListView()` (the collapsed
  button).

**Nothing removed.** Verified on the simulator against the exact repro:

| Gesture                 | Before              | After                                                                                                            |
| ----------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Long press "Chats"      | story panel expands | Hidden Chats PIN screen                                                                                          |
| Short tap "Chats"       | story panel expands | story panel expands (unchanged)                                                                                  |
| Long press story avatar | context menu        | context menu (gate logs `REJECTED` — its superview is `Display.ContextExtractedContentView`, not the story list) |

**Do not re-gate the attach on `findTitleView()`.** That is what broke this, and it fails silently:
no crash, no log, the entry point simply never exists.

---

## NovagramPro toggles that now default OFF (2026-07-31)

Opt-in instead of opt-out, so a fresh install ships the stock Telegram surface and the user turns
on what they want. Only the fallback in `?? true` → `?? false` changed; stored values are untouched,
so anyone who already toggled these keeps their setting.

| Toggle                                  | Key                           | Sites                                                                                                                                                                                               |
| --------------------------------------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Round video from gallery                | `round_video_from_gallery`    | `Novagram/RoundVideoFromGallery/Sources/NovagramRoundVideoFromGalleryFlow.swift` `isEnabled`; `Novagram/Messenger/Sources/NovagramSettingsController.swift:971`                                               |
| Voice to text (STT shortcut)            | `stt_enabled`                 | `Novagram/Messenger/.../NovagramSettingsController.swift:978`; **`submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`** ×3 (`:2740`, `:6028`, `:6328`) |
| Camera picker (long-press video button) | `long_press_camera_selection` | `Novagram/Messenger/.../NovagramSettingsController.swift:969`; **`ChatTextInputPanelNode.swift`** ×2 (`:968`, `:1022`)                                                                                |

The `ChatTextInputPanelNode.swift` sites are upstream-owned and were already Novagram hooks; only the
default literal changed. Every read of these keys must stay in sync — a site left on `?? true` makes
the feature half-on (button hidden but layout inset reserved, or vice versa).

---

## Hidden Chats — Contacts page: no leak, plus hide / view-hidden from there (2026-07-31)

**Symptom:** a chat hidden from the chat list still appeared in the Contacts tab, phone number and
all. `HOOKS.md`'s own "Generalise this" note under the story-bar fix predicted exactly this — the
contacts list builds its own peer feed and never passes through `ChatListNodeEntries`.

**Filtering.** Applied inside `contactListNodeEntries`, not through the existing `filters` array,
because that array is captured once at init while this function re-runs on every rebuild and so
always reads the current vaulted set.

- **`submodules/ContactListUI/Sources/ContactListNode.swift`** — `import NovagramSecretVault`; new
  `filterVaultedPeers: Bool = false` on `ContactListNode.init` (stored, threaded to both
  `contactListNodeEntries` call sites); that function's `peers` parameter became `rawPeers` and the
  filtered `peers` is derived at the top.
- **`submodules/ContactListUI/Sources/ContactsControllerNode.swift`** — passes
  `filterVaultedPeers: true`, and its presentation signal now also combines
  `novagramSecretVaultRevisionSignal()` so hiding a contact drops the row immediately instead of after
  some unrelated update.
- **`submodules/Novagram/SecretVault/Sources/SecretVaultRevisionSignal.swift`** (module-owned, new) —
  emits once, then on every `.novagramSecretVaultChanged`.
- **`submodules/Novagram/SecretVault/Sources/SecretVaultManager.swift`** — new
  `removingVaulted(_:optionalPeerId:)` overload; the contacts list mixes Telegram peers with
  device-only contacts, and the latter have no peerId to match on (they are always kept).

**Default is `false`** — only the Contacts tab opts in. Share / forward / add-member pickers and the
contacts _search_ still show vaulted peers **on purpose**: those are deliberate "pick a person"
flows, and silently omitting someone there would look like data loss. Revisit only if asked.

**Hide from a contact row.**

- **`submodules/ContactListUI/Sources/ContactContextMenus.swift`** — `import NovagramSecretVault`;
  a Hide / Unhide item before Delete, shown only when `SecretVaultManager.shared.isEnabled`. Mute
  semantics match the chat list: `Int32.max` on hide, **`nil`** on unhide (`0` would write a
  permanent per-peer unmute exception).

**View hidden from the Contacts page.** Long press the "Contacts" title, same as the chat list.

- **`submodules/AccountContext/Sources/AccountContext.swift`** — new
  `makeNovagramVaultChatListController(context:)`. A separate factory rather than a parameter on
  `makeChatListController` so that signature and its 7 call sites stay untouched on upstream merges.
- **`submodules/TelegramUI/Sources/SharedAccountContext.swift`** — implements it (+
  `import NovagramSecretVault`, + `TelegramUI/BUILD` dep). `ContactListUI` cannot depend on
  `ChatListUI`, which is the whole reason for the factory.
- **`submodules/ContactListUI/Sources/ContactsController.swift`** — `viewDidAppear` override
  attaching the vault gesture, plus `novagramVaultLongPressCanBegin(at:)`, `novagramVaultLongPress`,
  `novagramPresentVaultList`. BUILD gains `NovagramSecretVault`, `NovagramChatLock`,
  `StoryPeerListComponent`.

**Gate hardening (applies to BOTH controllers).** The first version only accepted a press whose hit
view was the title view or the collapsed story button. Runtime logging showed that is not enough:

| Screen                   | `findTitleView()`   | title band hit view         |
| ------------------------ | ------------------- | --------------------------- |
| Contacts                 | `ChatListTitleView` | `ChatListTitleView`         |
| Chats, stories collapsed | **nil**             | story `HighlightableButton` |
| Chats, no stories        | **nil**             | the navigation bar itself   |

So with no stories the chat-list long press did nothing. Both gates now bound the press to the
centered title band — x within 28–72% of the width, y above the search field's real frame — and
then accept the title view, the header's `titleContentView`, a **direct** subview of
`storyPeerListView()` (the collapsed button), **or the navigation bar itself** (a plain text title
is not hit-testable, so "nothing interactive claimed this point" means the title).

Expanded story avatars are still rejected — they sit inside the story scroll container, so they are
not direct subviews — and keep their own long-press context menu.

---

## More NovagramPro toggles defaulting OFF (2026-07-31)

Same rationale as the earlier batch: opt-in, stored values untouched.

| Toggle           | Key                       | Sites                                                                                                                                      |
| ---------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Translate button | `show_translate_messages` | `Novagram/Messenger/.../NovagramSettingsController.swift:974`; **`submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift:1483`** |

The `ChatInterfaceStateContextMenus.swift` site is upstream-owned and was already a Novagram hook;
only the default literal changed. Both sites must stay in sync — the settings row and the actual
context-menu gate read the same key independently.

---

## Per-feature deep links into NovagramPro Settings (2026-07-31)

Feature #40 grew a second half. `tg://settings/novagrampro` used to be the only link and it always
landed at the top of the screen. Every row now has its own link, and arriving on one scrolls that
row into view and traces an accent outline around it.

```
tg://settings/novagrampro                        → screen, top, no animation   (unchanged)
tg://settings/novagrampro/<slug>                 → screen + scroll + outline
tg://settings/novagrampro?f=<slug>               → alias for the line above
```

**Why the slug rides in the path, not the query.** `OpenUrl.swift` builds the settings path from
`parsedUrl.pathComponents` only (`case "settings"` lives in the **`else`** branch of
`if let query = parsedUrl.query`), so a `tg://settings/...?f=x` URL never reaches the settings
resolver at all today — it falls through to `.unknownDeepLink`. The path form therefore needs no
parser change; the `?f=` alias is supported by one small additive hook that rewrites it.

**Novagram-owned code** (all logic lives here — the hooks below only forward):

- `submodules/Novagram/Messenger/Sources/NovagramSettingsDeepLink.swift` — `NovagramSettingsFeature`
  (44 slugs), `NovagramSettingsItemTag: ItemListItemTag`, `NovagramSettingsDeepLink.open(settingsPath:…)`,
  `.settingsPath(forUrlPath:featureParameter:)`, `.link(for:)`, `.screenLink`.
- `submodules/Novagram/Messenger/Sources/NovagramSettingsHighlight.swift` — the outline animation.
- `submodules/Novagram/Messenger/Sources/NovagramSettingsRowLinkMenu.swift` — long-press → Copy/Share.
- `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift` — `NovagramEntry.linkInfo`
  (slug + row title), `tag: self.novagramTag` on all 44 linkable rows, and
  `novagramSettingsController(context:highlightFeature:)`.
- `submodules/Novagram/Messenger/BUILD` — `+ //submodules/OverlayStatusController` (the
  "Link copied" toast). Novagram-owned BUILD, not a hook.

### `submodules/TelegramUI/Sources/OpenResolvedUrl.swift`

The Feature #40 intercept inside `case let .settings(section):` → `case let .path(path):` (after the
`path.isEmpty` guard, before `handleSettingsPathUrl(...)`, around line 980) **replaces** the old
`if path == "novagrampro" { … }` block:

```swift
// Novagram Feature #40: tg://settings/novagrampro[/<feature>] → NovagramPro settings screen
if NovagramSettingsDeepLink.open(settingsPath: path, context: context, navigationController: navigationController) {
    return
}
```

Reason: same interception point as before, but the slug parsing and the controller construction moved
into the Novagram module. `open` returns false for every non-Novagram settings path, so upstream's
`handleSettingsPathUrl` still runs for those. The `import NovagramMessenger` at the top of the file
(already documented in the earlier Feature #40 section) is unchanged.

### `submodules/TelegramUI/Sources/OpenUrl.swift`

**Imports — append after `import PresentationDataUtils`:**

```swift
// Novagram: Feature #40 — tg://settings/novagrampro?f=<feature> deep link
import NovagramMessenger
```

**Inside `if let query = parsedUrl.query, let params = QueryParameters(query) { switch host {`,
as the first case (before `case "localpeer":`, around line 434):**

```swift
// Novagram Feature #40: tg://settings/novagrampro?f=<feature>. The settings path
// below is built from pathComponents only, so a query form never reaches it —
// rewrite it here. Returns nil for every non-Novagram settings URL, which then
// falls through exactly as before.
case "settings":
    if let settingsPath = NovagramSettingsDeepLink.settingsPath(forUrlPath: parsedUrl.path, featureParameter: params[NovagramSettingsDeepLink.featureQueryKey]) {
        handleResolvedUrl(.settings(.path(settingsPath)))
        return
    }
```

Reason: purely additive — `host == "settings"` had **no** case in this branch before, so every
`tg://settings/…?query` URL ended at `.unknownDeepLink`. Returning nil from the helper reproduces
that exactly. `NovagramMessenger` is already a dep of `TelegramUI/BUILD` — no BUILD change.

### Non-obvious details

- **Slugs are permanent.** `NovagramSettingsFeature`'s raw values travel inside URLs users have already
  shared. Never rename a case or repoint one at a different row; add a new case instead. An unknown
  slug deliberately resolves to `.screen` rather than falling through, so an old app opening a newer
  link still lands somewhere sensible.
- **Scrolling uses two upstream mechanisms, not one.** `ensureVisibleItemTag` only reaches rows whose
  nodes already exist (`ItemListControllerNode` walks `forEachItemNode`), which is useless for a row
  40 items down. `initialScrollToItem` (index-based, applied on the first transition only) does the
  real work; the tag handles the already-visible case and the highlight lookup.
- **The animation is opt-in by construction.** `highlightFeature` defaults to nil, so the only caller
  that can trigger it is the deep-link handler. `PeerInfoScreenSettingsActions.swift` (Settings →
  Novagram) passes nothing and behaves exactly as before.
- **The long press needs two guards, not one.** `allowableMovement` alone is not enough: a slow drag
  can outlast `minimumPressDuration` and pop an action sheet in the middle of a scroll. The
  recognizer additionally fails itself from `touchesMoved`, and `attach` listens to
  `ItemListController.beganInteractiveDragging` to veto a press once the list starts moving.
  `cancelsTouchesInView = true` is what stops the pressed row's switch from also toggling.
- **Row hit-testing goes through layers, not views.** Some ItemList rows are layer-backed nodes;
  touching `itemNode.view` would trip an AsyncDisplayKit assertion, so the point is converted with
  `itemNode.layer.convert(_:from:)` and tested against `contentBounds`.

---

## Hidden Chats — the screen no longer inherits the root list's chrome (2026-07-31)

Three separate leaks, all the same root cause: the vault screen is its **own**
`ChatListControllerImpl` instance (`novagramIsVaultList: true`), but it runs on the root chat list's
data pipeline, so every root-list extra rode along unless explicitly excluded. They surfaced one at
a time — folder tabs, then the Archive row after a pull-to-refresh.

**1. Folder tabs listed every chat.** Each tab owns a **separate** `ChatListContainerItemNode`, and
`novagramVaultMode` was only ever set on `mainContainerNode.currentItemNode` — the "All" tab. Tapping
any other tab landed on a node with `novagramVaultMode == false`, i.e. the unfiltered root list.

- **`submodules/ChatListUI/Sources/ChatListContainerItemNode.swift`** — `init` now sets
  `novagramVaultMode` on its own `listNode` when `controller?.novagramIsVaultList == true`. Per node, so
  no node can exist without the filter.
- **`submodules/ChatListUI/Sources/ChatListController.swift`** — where `updateAvailableFilters` is
  called, the vault list is forced to `[.all]` with `tabContainerData = ([], false, nil)`, so no tab
  bar renders at all (`ChatListControllerNode` hides it once `availableFilters.count <= 1`).

Both, deliberately: the tabs do not belong on that screen, **and** the per-node filter means a
future code path that creates an item node cannot leak.

**2. Archive row was a door back to the hidden chats.** Pull-to-refresh revealed an "Archived Chats"
row; tapping it pushes the archive list, which is a different `groupId` and not vault-filtered.

- **`submodules/ChatListUI/Sources/Node/ChatListNodeEntries.swift`** — the group-reference loop is
  now `for groupReference in groupItems where !state.novagramVaultMode`, and `.EmptyIntro` (the
  contact-suggestion placeholder) is gated the same way.

**3. The empty-state duck was frozen.**

- **`submodules/ChatListUI/Sources/ChatListEmptyNode.swift`** — `playbackMode` is `.loop` for
  `.novagramVault`, `.once` for everything else. Upstream's empty states play once because they sit
  under a call-to-action button; this screen has no button, so a stopped animation reads as broken.
  Verified by diffing the sticker's pixels across ~12 s — every sample differs.

**If another root-list element shows up on this screen, gate it on `state.novagramVaultMode` here**
rather than adding a new screen. The pattern to look for is anything appended under
`if !view.hasLater, case .chatList = mode`.

**4. Compose and add-story buttons removed from the screen.** Same inheritance problem as the tabs
and the Archive row — both are root-list actions.

- **`submodules/ChatListUI/Sources/ChatListController.swift`** — `ChatListLocationContext.rightButtons`
  drops `rightButton` (compose) and `storyButton` when `parentController?.novagramIsVaultList == true`.
  Filtered in the getter, not at the two assignment sites, so a later assignment cannot put them
  back. The left **Edit** button stays — it is how chats get selected and unhidden. Proxy and
  ghost-mode buttons stay too; they are status/utility, not root-list navigation.

---

## Hidden Chats — Calls tab no longer leaks a hidden peer's call history (2026-07-31)

Same class as the Contacts leak, and the third surface `HOOKS.md` predicted under the story-bar fix's
"Generalise this" note. The call list builds its own feed straight from the message view, so it
never passed through `ChatListNodeEntries` and every hidden peer's calls stayed listed.

- **`submodules/CallListUI/Sources/CallListNodeEntries.swift`** — `import NovagramSecretVault`;
  `.message` entries whose `topMessage.id.peerId` is vaulted are skipped, and `groupCalls` runs
  through `removingVaulted`. `isEnabled` is read once per rebuild, not per row.
- **`submodules/CallListUI/Sources/CallListControllerNode.swift`** — `novagramSecretVaultRevisionSignal()`
  joins the `callListNodeViewTransition` `combineLatest`, so hiding a chat drops its calls
  immediately.
- **`submodules/CallListUI/BUILD`** — `+ NovagramSecretVault`.

The empty placeholder still appears correctly when everything is filtered: `emptyStatePromise` is
fed from `countMeaningfulCallListEntries(transition.callListView.filteredEntries)`, i.e. the
post-filter entries.

**Remaining known surfaces that still show vaulted peers, deliberately:** forward / share /
add-member pickers, and the Contacts + global search. Those are "pick a person" flows where a
silently missing row reads as data loss.

---

## Novagram Settings — "Translate entire chats" toggle unlocks the Premium switch (2026-07-31)

New Settings row, entirely inside `submodules/Novagram/Messenger/` except for the three gate sites
below — those were hooked in an earlier task and are documented here for the first time, closing a
HOOKS.md coverage gap rather than changing them. Mirrors the `storyUnlockEnabled` row exactly, minus
the confirmation alert: flipping this switch is instantly reversible with no data at risk, so there
is nothing to confirm before turning it on.

**Novagram-owned (no merge risk):**

- `submodules/Novagram/PremiumUnlock/Sources/NovagramPremiumUnlock.swift` — pre-existing;
  `isTranslateChatsUnlocked` (`UserDefaults` suite `pro_messager`, key
  `fenix_translate_chats_unlock`, default `false`). Not modified by this task.
- `submodules/Novagram/Messenger/Sources/NovagramSettingsController.swift` — `NovagramEntry
.translateChatsUnlock` case (stableId `88`, sitting between `storyUnlockEnabled` = `87` and
  `featuresFooter`; `featuresFooter` bumped `88` → `89` to make room), section membership, `==`,
  `linkInfo` (slug `translate-chats-unlock`), the `ItemListSwitchItem` builder (icon
  `character.bubble.fill`, `.lightBlue`), `NovagramSettingsState.translateChatsUnlock`, and
  `NovagramSettingsArguments.updateTranslateChatsUnlock` (writes the flag then updates state — no
  alert, unlike `updateStoryUnlock`).
- `submodules/Novagram/Messenger/Sources/NovagramSettingsDeepLink.swift` —
  `NovagramSettingsFeature.translateChatsUnlock = "translate-chats-unlock"`.
- `submodules/Novagram/Messenger/Sources/NovagramTranslateUnlockStrings.swift` — new file,
  `toggleTitle`/`toggleSubtitle` en/uz/ru.
- `submodules/Novagram/Messenger/BUILD` — `+ //submodules/Novagram/PremiumUnlock:NovagramPremiumUnlock`.

**Telegram-owned gate sites (already hooked before this task; listed here only because HOOKS.md had
no entry for them yet):**

- `submodules/SettingsUI/Sources/Language Selection/LocalizationListControllerNode.swift:537`:
  ```swift
  entries.append(.translateEntire(text: presentationData.strings.Localization_TranslateEntireChat, value: translateChats, locked: !isPremium && !NovagramPremiumUnlock.isTranslateChatsUnlocked))
  ```
  `import NovagramPremiumUnlock` at line 19. `SettingsUI/BUILD` already carries the dep.
- `submodules/TelegramUI/Sources/ChatControllerContentData.swift:2201`:
  ```swift
  if (isPremium || maybeSuggestPremium || hasAutoTranslate || NovagramPremiumUnlock.isTranslateChatsUnlocked) && !isHidden {
  ```
  `import NovagramPremiumUnlock` at line 18.
- `submodules/TelegramUI/Sources/ChatHistoryListNode.swift:2178`:
  ```swift
  if let translationState, (isPremium || autoTranslate || NovagramPremiumUnlock.isTranslateChatsUnlocked) && translationState.isEnabled {
  ```
  `import NovagramPremiumUnlock` at line 42. `TelegramUI/BUILD` already carries the dep.

Why these three and only these three are safe to flip: see the doc comment on
`NovagramPremiumUnlock.isTranslateChatsUnlocked` — the gate is client-side in all three places (row
lock state, translation-state construction, and the actual apply-to-message-list check), and
`messages.translateText` has no Premium error path server-side (contrast
`messages.composeMessageWithAI`, which does surface `AICOMPOSE_FLOOD_PREMIUM`). Channel
auto-translate already routes non-Premium accounts through the identical RPC and code path today.

Do not touch these three gate sites when re-applying hooks after an upstream pull — reapply the
one-line `||`/`&&` addition verbatim; upstream's surrounding condition (`isPremium`,
`maybeSuggestPremium`, `hasAutoTranslate`, `autoTranslate`, `isHidden`,
`translationState.isEnabled`) is taken as-is.

## 📌 Generic "You have a new message" banners — NSE fallback fixes (2026-08-07)

Symptom: bursts of banners reading only `PUSH_ENCRYPTED_MESSAGE` ("You have a new message") — no sender, no text,
no avatar — that also never clear off the lock screen. Root-caused by a 127-agent audit; full write-up in
`Telegram-iOS/PUSH_AUDIT_2026-08-07.md` and `Telegram-iOS/_push-audit-2026-08-07/SYNTHESIS.md` (both untracked).

**Mechanism.** The banner is the RAW server payload: both completion sites in `NotificationService` fall through to
`contentHandler(initialContent)` whenever the `content` atomic is still nil. Real-message pushes pre-set their
content well before the poll, so a late stall still renders sender + text — the generic string is only reachable
when the NSE dies _before_ that pre-set. That whole pre-set segment has **no timeout anywhere**, builds a full
Postbox plus a live MTProto Network per invocation, and runs on ONE process-global serial queue
(`NotificationService.swift:24` `private let queue = Queue()`), which iOS shares across a burst of pushes.
Note that decrypt failures are NOT the cause — every decrypt error branch publishes an empty content first, and
iOS suppresses an empty content, so a decrypt failure yields no banner at all.

### A0. `Telegram/NotificationService/Sources/NotificationService.swift` — service pushes must start invisible (F1) ← **THE ROOT CAUSE**

Found 2026-08-07 by the owner from real-world behaviour, not from code: he runs the same account on
**three devices**. When any message arrives every device shows a correct banner. When he reads it on one
device, the server sends **`READ_HISTORY`** to the others so they can REMOVE their banner. On the iPhone that
removal sometimes failed — and instead of clearing a banner it produced a brand-new bogus one reading
"You have a new message".

Mechanism: the `loc-key` branch (`READ_HISTORY`, `MESSAGE_DELETED`, `READ_REACTION`, `READ_STORIES`,
`MESSAGE_MUTED`, `SESSION_REVOKE`) never called `updateCurrentContent`, so the content atomic stayed nil for
the entire duration of its async action. Any stall, kill or budget expiry in that window sent both completion
sites down `contentHandler(initialContent)`, which re-emits the RAW server payload — whose alert body is
`PUSH_ENCRYPTED_MESSAGE`. Removal is also the slowest thing the extension does: a measured `READ_HISTORY`
episode took **1044 ms** (`Will try to remove 6 notifications`) versus ~250 ms for a normal message push.

Fix: publish `NotificationContent(isLockedMessage: nil)` immediately on entering the branch, before the switch.
Empty content is suppressed by iOS, so the floor for a service push is "invisible" — which is what it means.
Nothing is lost: any path that genuinely needs a banner overwrites it downstream. This explains the original
report exactly (bursts of generic banners with nothing new in the app, while reading on another device) and why
single-device tests never reproduced it.

### A1. `NotificationService.swift` `NotificationContent.generate()` — never hand iOS a wholly empty content

**Confirmed root cause of the phantom banners, by controlled A/B on one device:** official Telegram cleared the
banner with no phantom; this fork produced "You have a new message". The difference is `Telegram/BUILD` gating
`com.apple.developer.usernotifications.filtering` to `ph.telegra.Telegraph`. Apple's documentation is explicit:
without that entitlement _"the system always displays the notification banner to the user."_ And iOS refuses to
draw a wholly empty banner — it falls back to the ORIGINAL server payload, whose alert body is
`PUSH_ENCRYPTED_MESSAGE`. So upstream's "suppress by returning empty content" idiom, which works for official
Telegram, actively produces a phantom banner on any fork.

Fix: in `generate()`, when title, subtitle and body are all empty, set `title = " "` (a single space keeps the
content non-empty so iOS renders OUR mutation instead of the raw payload) and, on iOS 15+,
`interruptionLevel = .passive` + `relevanceScore = 0` so the screen does not light up and no sound plays. The
notification still enters the notification list; the extension's own sweep (section A2) removes it on the next
service push. Swiftgram ships the same mitigation for the same reason.

Researched and ruled out — do not retry: `apns-collapse-id` (sender-side, pre-delivery only, cannot touch an
already-delivered banner, and an NSE cannot read or set HTTP/2 headers), `threadIdentifier` (grouping only),
`hiddenPreviewsBodyPlaceholder` (static per-category, and only applies when the _user_ hides previews),
`relevanceScore` alone (scheduled-summary ranking only), `filterCriteria` (Focus modes — a different feature),
removing the current request's own identifier (it is not a delivered notification until `contentHandler` returns),
not calling `contentHandler` (iOS then shows the original payload — strictly worse), crashing the extension
(same, plus it risks iOS refusing to launch the extension at all, which would break real message decryption).
Telegram's own engineer states on issue #1046 that the filtering entitlement is "the only way" to handle these
events. Nicegram's developer tried and publicly gave up. Full research: `_push-audit-2026-08-07/RESEARCH-2-suppression.json`.

⚠️ `minimum_os_version` stays **13.0**. Bumping it to 15.0 (to clear ASC warning 90068, required by Spring 2027)
produces **77 build errors** — upstream compiles with warnings-as-errors and many upstream APIs are deprecated in
iOS 15 (`featureIdentifier`, `typeIdentifier`, `adjustsImageWhenHighlighted`, …). Take upstream's own bump instead
of fixing their deprecations here. `.passive` is guarded with `#available(iOS 15.0, *)` so it needs no bump.

### A2. `NotificationService.swift` — sweep stray raw banners from inside the extension

In the `READ_HISTORY` removal loop, a delivered notification that resolves to no
`NotificationManagedNotificationRequestId` **and** still carries the encrypted `p` key is added to
`removeIdentifiers`. `p` survives only on notifications the extension never rewrote, so this cannot hit a real
message banner, a call, or the local reminder. Because these read receipts arrive constantly on a multi-device
account, a stray now clears on its own within minutes instead of waiting for the user to open the app.

### A. `Telegram/NotificationService/Sources/NotificationService.swift` — watchdog (F2)

In `didReceive`, after the `QueueLocalObject` is created, a 20 s watchdog runs on
`DispatchQueue.global(qos: .userInitiated)` — deliberately **not** on `queue`, which is the starved resource. If the
content atomic is still nil it takes over `contentHandler` and delivers an empty `NotificationContent`, so a stall
is silent instead of emitting the misleading generic banner. Behaviour change approved by the owner 2026-08-07:
_suppress rather than show a useless banner_ (the message still lands in the app and the badge still updates).

### B. `Telegram/NotificationService/Sources/NotificationService.swift` — nil-content hole (F6)

In the real-message branch, the `else` arm taken when `aps["alert"]` is neither a dict nor a string used to call
`completed()` with the atomic never published, which re-emitted the raw payload. It now calls
`updateCurrentContent(content)` first. Pure bug fix, no behaviour removed.

### C. `submodules/TelegramUI/Sources/AppDelegate.swift` — sweep un-enriched banners (F5)

Inside `ClearNotificationsManager`'s `getNotificationIds`, a delivered notification that resolves to no
`NotificationManagedNotificationRequestId` **and** still carries the encrypted `p` key is collected into
`novagramUnenrichedIdentifiers` and passed to `removeDeliveredNotifications(withIdentifiers:)`. `p` survives only on
notifications the NSE did **not** rewrite (an enriched one carries the NSE's own `userInfo`), so this can never
touch a real message banner, a call banner, or the local unread reminder. This is what stops the pile-up.

### D. `run.sh` — device builds had NO push entitlement at all

`run.sh` passed `aps_environment=''`, and `Telegram/BUILD` omits the `aps-environment` key entirely when that value
is empty, so `registerForRemoteNotifications()` failed and every `./run.sh -r` build got no device token — total
push silence. This is the same defect `publish.sh` carried until 2026-07-15; `run.sh` was never fixed. It now
passes `'development'` for device builds (matching `Fenixuz.mobileprovision`) and `''` for the simulator.
⚠️ `release.sh:282` still has the original `aps_environment=''` plus a stale comment claiming the App ID has no
Push capability — untrue since 2026-07-07. Fix it if that script is ever used.

### E. ✅ TEMPORARY DIAGNOSTIC — reverted 2026-08-21 for the 12.9.4 App Store build

Two diagnostics were carried while chasing the generic/blank banner bug and are now **removed**:

- `NotificationService.swift` forced `Logger.shared.logToFile = true` instead of honouring the stored setting —
  restored to `Logger.shared.logToFile = loggingSettings.logToFile`.
- `AppDelegate.swift` logged `NOVAGRAM-PUSH` with a delivered banner's top-level payload keys and its `aps` dict —
  the log line is gone; the surrounding un-enriched-banner sweep (`novagramUnenrichedIdentifiers` →
  `removeDeliveredNotifications`) is a real feature and stays.

Keep the original reasoning on record in case the diagnostic is ever needed again: `installedSharedLogger` is a
process-global, so `setupSharedLogger` installs the logger only on a **cold** process; applying a stored
`logToFile: false` there silences every **reused-process** invocation, meaning a burst of notifications leaves no
trace at all and the notification log shows only cold starts hours apart. Do not read such a log as "the NSE did
not run". The permanent fix would be to re-apply the stored setting per invocation rather than pinning it on.

### BUILD changes: none

---

## 📌 Ghost mode — reactions were marked "seen" locally (2026-08-11)

**Symptom (user, private chat):** with Ghost mode ON, someone reacts to a message I sent; I open the
chat and the reaction stops being "new" — it is marked as seen.

**What was already correct:** every client→server reaction read receipt was already suppressed —
`messages.readReactions` (`ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift:~290`) and
`messages.readMessageContents` / `channels.readMessageContents` for the reaction+poll-vote path
(`ManagedConsumePersonalMessagesActions.swift:~327`). Nothing leaked to the network.

**The gap:** the LOCAL half of the same flow ran unconditionally, so the postbox said "seen" while the
server still had the reaction unread — a silent divergence that a tag-summary resync
(`synchronizeUnseenReactionsAndPollVotesTag` → `getPeerDialogs` → `replaceMessageTagSummary`) can undo,
making the badge reappear.

### `submodules/TelegramCore/Sources/State/AccountViewTracker.swift`

`updateMarkReactionsAndVotesSeenForMessageIds(messageIds:)` (~line 1753) — guard at the very top,
before `self.queue.async` so a Ghost toggle applies to the next call immediately:

```swift
// Novagram Ghost mode: the network side already refuses to send the reaction read receipt,
// so clearing the local unseen state here would leave us saying "seen" while the server
// still has it unread. Keep both sides unread instead.
if isNovagramGhostModeActive {
    return
}
```

This is the automatic scroll-into-view path only — its two callers are
`ChatHistoryListNode.swift:~1032` (`unseenReactionsProcessingManager.process`) and `:~2635` (the
`messageIdsWithReactionsScheduledForMarkAsSeen` flush). Blocking it stops both the `.unseenReaction`
tag removal and `ReactionsMessageAttribute.withAllSeen()`.

**Deliberately left working:** the explicit "Mark All Reactions as Read" context-menu action on the
reactions navigate button (`ChatControllerLoadDisplayNode.swift:~1601`) →
`clearPeerUnseenReactionsAndPollVotesInteractively` → `updateMarkAllReactionsAndPollVotesSeen`. It is a
user-initiated action, its network half is already Ghost-guarded, and without it the reaction badge
would be unclearable while Ghost is on.

**Expected side effects (not bugs):** while Ghost is ON the unread-reaction badge stays and the reaction
pop animation replays on each chat open (throttled to 1/s per message by
`displayUnseenReactionAnimationsTimestamps`). Turning Ghost OFF and reopening the chat marks everything
read normally.

**Same pattern, deliberately NOT changed:** `updateMarkMentionsSeenForMessageIds` (~line 1650) has the
identical local/network split for unread @mentions. Left alone to keep this diff minimal — revisit if
the same complaint arrives for mentions.

### BUILD changes: none

---

## 📌 Minimum iOS raised 13.0 → 15.0 (2026-08-21)

Transporter flagged the 12.9.4 (73) upload with **warning 90068**: _"MinimumOSVersion too low. This app
has a MinimumOSVersion of 13.0. Starting in Spring 2027, all iOS apps must have a MinimumOSVersion of
15.0 or later in order to be uploaded to App Store Connect or submitted for distribution."_ It is a
warning, not an error — build 73 would still have uploaded — but the deadline is fixed, so the bump was
taken during this release. Shipped as **12.9.4 (74)**.

**Reach cost: none.** iOS 13, 14 and 15 all run on the same hardware floor — iPhone 6s / SE (1st gen)
and newer. The device cut happened at iOS 16 (which dropped 6s / 7 / SE 1st gen). This drops no device
model, only users who never updated their OS.

**No app source code was changed.** The whole migration is build configuration.

### 1. `Telegram/BUILD` — the deployment target

```python
minimum_os_version = "15.0"    # was "13.0"
```

All 16 shipped targets (app + every extension) read this one variable; none hardcodes its own. Nothing
else in the repo sets an iOS deployment target for a shipped product — no `.xcconfig`, no `.pbxproj`,
no `Package.swift`, and `build-system/Make/` passes no `--ios_minimum_os`.

### 2. `Telegram/BUILD` — the widget's own override

`genrule(name = "SetMinOsVersionWidgetExtension")` patches `WidgetExtension.appex`'s `MinimumOSVersion`
through `PatchMinOSVersion.source.sh`; upstream pinned it at **14.0** (WidgetKit needs iOS 14, and their
app minimum was lower). Changed to **15.0** — an extension never runs below its host app, so 14.0 was
both meaningless and a bundle that could trip the same 90068 check. It is the only such genrule that is
actually wired up: the `NotificationContentExtension` one is commented out at the `ipa_post_processor`
line and the `IntentsExtension` one is not referenced, which is why both already package at 15.0.

### 3. 39 BUILD files — deprecation diagnostics downgraded

**This is the part that is easy to lose and expensive to rediscover.** The project compiles with
`-Werror` (objc_library) and `-warnings-as-errors` (swift_library) in **696 of 763** BUILD files. Raising
the deployment target makes every API deprecated in iOS 14.0/15.0 start warning — and those warnings are
fatal. The first build after the bump failed with 19 compile errors across 3 targets, and fixing those
exposed further waves (3 → 5 → 1 → 1) because Bazel never builds the dependents of a failed target.

Only **iOS 14.0 and 15.0** deprecations are newly surfaced: anything deprecated in iOS 13 or earlier was
already fatal at the old minimum, and the build passed, so no such usage exists.

Every failure was deprecation-only — no API actually broke:

| Symbol                                                                                                                     | Deprecated | Still works?                                                                        |
| -------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------- |
| `adjustsImageWhenHighlighted` / `adjustsImageWhenDisabled`                                                                 | 15.0       | yes — ignored **only** under `UIButton.Configuration`, which this code does not use |
| `contentEdgeInsets` / `titleEdgeInsets` / `imageEdgeInsets`                                                                | 15.0       | same                                                                                |
| `kUTType*`, `kUTTagClass*`, `UTTypeConformsTo`, `UTTypeCreatePreferredIdentifierForTag`, `UTTypeCopyPreferredTagWithClass` | 15.0       | yes                                                                                 |
| `UIDocumentPickerMode*`, `initWithDocumentTypes:inMode:`                                                                   | 14.0       | yes                                                                                 |
| `INSearchCallHistoryIntent*`                                                                                               | 15.0       | yes — Apple states **"There is no replacement"**                                    |
| `CLLocationManager`/`PHPhotoLibrary` `authorizationStatus()`                                                               | 14.0       | yes                                                                                 |
| `UIApplication.windows` / `keyWindow`                                                                                      | 15.0       | yes                                                                                 |
| `INSendMessageIntent(recipients:…)`                                                                                        | 14.0       | yes                                                                                 |
| `WKWebViewConfiguration.preferences.javaScriptEnabled`                                                                     | 14.0       | yes                                                                                 |
| CoreText `typeIdentifier` / `featureIdentifier`                                                                            | 15.0       | yes                                                                                 |

Rewriting these would mean re-implementing Telegram's legacy camera and media-picker UI on
`UIButton.Configuration`, with real regression risk and no functional gain — and `INSearchCallHistoryIntent`
cannot be rewritten at all. So the diagnostic is downgraded instead, per target, leaving every other
warning fatal:

```python
# swift_library — ORDER MATTERS, this must come AFTER "-warnings-as-errors"
copts = [
    "-warnings-as-errors",
    "-Wwarning",
    "DeprecatedDeclaration",
]

# objc_library — order does not matter for clang
copts = [
    "-Werror",
    "-Wno-error=deprecated-declarations",
]
```

⚠️ **The Swift ordering is load-bearing.** Verified with `swiftc`: `-Wwarning DeprecatedDeclaration`
placed _before_ `-warnings-as-errors` is overridden and the build still fails; placed _after_, the group
downgrades correctly. This also rules out a global `--swiftcopt` flag, because Bazel appends a target's
own `copts` _after_ command-line copts. (A global `--copt=-Wno-error=deprecated-declarations` would work
for clang, where order is irrelevant, but it would invalidate the cache for every C/ObjC action.)

To re-find the affected targets after an upstream merge, grep the source tree for the symbols in the
table above, map each hit to its nearest owning `BUILD`, and patch those — or simply build and let the
waves tell you. The current list is whatever `git log -S DeprecatedDeclaration` shows.

### BUILD changes: `Telegram/BUILD` (variable + widget genrule) and 39 module BUILD files

---

## 📌 Phone-number context menu — honest lookup failures (2026-08-27)

Reported by real users on the App Store build: a dropped connection, a frozen account, or a
rejected method all made the phone context menu state, as fact, "This number is not on
Telegram" — because `_internal_resolvePeerByPhone` collapsed every RPC error into `nil`, the
same value it returned for a genuine "no such user" server answer.

### `submodules/TelegramCore/Sources/TelegramEngine/Peers/ResolvePeerByName.swift`

**Immediately after `_internal_resolvePeerByName`.** Find:

```swift
func _internal_resolvePeerByPhone(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    var normalizedPhone = phone
    if normalizedPhone.hasPrefix("+") {
        normalizedPhone = String(normalizedPhone[normalizedPhone.index(after: normalizedPhone.startIndex)...])
    }

    let accountPeerId = account.peerId

    return account.postbox.transaction { transaction -> CachedResolvedByPhonePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)))?.get(CachedResolvedByPhonePeer.self)
    } |> mapToSignal { cachedEntry -> Signal<PeerId?, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(cachedEntry.peerId)
        } else {
            return account.network.request(Api.functions.contacts.resolvePhone(phone: normalizedPhone))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<PeerId?, Void> in
                return account.postbox.transaction { transaction -> PeerId? in
                    // ...parse resolvedPeer, update peerId...
                    return peerId
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<PeerId?, NoError> in
                return .single(nil)
            }
        }
    }
}
```

Replace with a new result enum, the renamed RPC function returning it, and a thin wrapper that
keeps the old name and signature:

```swift
// A phone lookup has three outcomes, and collapsing the last two loses real information:
// the server answered and knows the user, the server answered and does not, or the request never
// got an answer at all (no connection, a frozen or bot session, a rejected method). The UI used to
// render all three as "this number is not on Telegram", which is a confident lie in the third case.
public enum ResolvedPeerByPhone {
    /// The server answered. `nil` means it genuinely reports no such user.
    case answered(PeerId?)
    /// The request failed. We do not know whether the number is on Telegram.
    case failed
}

func _internal_resolvePeerByPhoneWithStatus(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvedPeerByPhone, NoError> {
    // ...identical cache lookup + RPC as before, but every success wraps in .answered(...)...
    |> `catch` { _ -> Signal<ResolvedPeerByPhone, NoError> in
        // Nothing is cached here on purpose: a failed request must not poison the 48h
        // cache with a "not on Telegram" answer the server never actually gave.
        return .single(.failed)
    }
}

func _internal_resolvePeerByPhone(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    return _internal_resolvePeerByPhoneWithStatus(account: account, phone: phone, ageLimit: ageLimit)
    |> map { result -> PeerId? in
        switch result {
        case let .answered(peerId):
            return peerId
        case .failed:
            return nil
        }
    }
}
```

**At the bottom of the file.** Add:

```swift
/// Engine-level outcome of a phone lookup. Kept separate from `ResolvedPeerByPhone` so consumers
/// never see a raw `PeerId` and never have to guess what a `nil` meant.
public enum EngineResolvedPeerByPhone {
    /// The server resolved the number to this user.
    case peer(EnginePeer)
    /// The server answered and reports the number is not a Telegram account.
    case notRegistered
    /// The lookup did not complete. Whether the number is on Telegram is unknown.
    case failed
}
```

Reason: the RPC body moves into `_internal_resolvePeerByPhoneWithStatus`, which returns
`ResolvedPeerByPhone` (`.answered(PeerId?)` vs `.failed`) instead of a bare `PeerId?`.
`_internal_resolvePeerByPhone` is kept with its exact original name and signature, reimplemented as
a `map` wrapper over the new function, so its three other existing callers need no changes. The
`.failed` `catch` branch deliberately writes NOTHING to the 48-hour `CachedResolvedByPhonePeer`
cache — a failed request can no longer poison it with a "not on Telegram" answer the server never
gave. `EngineResolvedPeerByPhone` is the `TelegramEngine`-facing equivalent, consumed by the new
method in `TelegramEnginePeers.swift` below.

---

### `submodules/TelegramCore/Sources/TelegramEngine/Peers/TelegramEnginePeers.swift`

**`TelegramEngine.Peers.resolvePeerByPhone(phone:ageLimit:)`.** Find:

```swift
public func resolvePeerByPhone(phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EnginePeer?, NoError> {
    return _internal_resolvePeerByPhone(account: self.account, phone: phone, ageLimit: ageLimit)
    |> mapToSignal { peerId -> Signal<EnginePeer?, NoError> in
        guard let peerId = peerId else {
            return .single(nil)
        }
        return self.account.postbox.transaction { transaction -> EnginePeer? in
            return transaction.getPeer(peerId).flatMap(EnginePeer.init)
        }
    }
}
```

Replace with the same signature reimplemented on top of a new sibling method:

```swift
public func resolvePeerByPhone(phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EnginePeer?, NoError> {
    return self.resolvePeerByPhoneWithStatus(phone: phone, ageLimit: ageLimit)
    |> map { result -> EnginePeer? in
        switch result {
        case let .peer(peer):
            return peer
        case .notRegistered, .failed:
            return nil
        }
    }
}

/// Same lookup as `resolvePeerByPhone`, but keeps "the server says this number is not on
/// Telegram" separate from "the lookup itself did not go through". Callers that show the
/// user a verdict about the number should use this one — collapsing the two states makes
/// the app state a failed request as fact.
public func resolvePeerByPhoneWithStatus(phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EngineResolvedPeerByPhone, NoError> {
    return _internal_resolvePeerByPhoneWithStatus(account: self.account, phone: phone, ageLimit: ageLimit)
    |> mapToSignal { result -> Signal<EngineResolvedPeerByPhone, NoError> in
        switch result {
        case .failed:
            return .single(.failed)
        case let .answered(peerId):
            guard let peerId = peerId else {
                return .single(.notRegistered)
            }
            return self.account.postbox.transaction { transaction -> EngineResolvedPeerByPhone in
                guard let peer = transaction.getPeer(peerId).flatMap(EnginePeer.init) else {
                    return .notRegistered
                }
                return .peer(peer)
            }
        }
    }
}
```

Reason: `resolvePeerByPhone` keeps its exact old public signature and behaviour (collapses
`.notRegistered` and `.failed` back to `nil`) so its existing callers are unaffected.
`resolvePeerByPhoneWithStatus` is the new engine-facade method that
`ChatControllerOpenPhoneContextMenu.swift` calls when it needs to distinguish the two.

---

### `submodules/TelegramUI/Sources/Chat/ChatControllerOpenPhoneContextMenu.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import NovagramLocalization
```

**The lookup call and the start of its `next:` closure.** Find:

```swift
let _ = (self.context.engine.peers.resolvePeerByPhone(phone: number)
|> deliverOnMainQueue).start(next: { [weak self] peer in
    guard let self else {
        return
    }
    params.progress?.set(.single(false))

    var firstName = ""
```

Replace with:

```swift
let _ = (self.context.engine.peers.resolvePeerByPhoneWithStatus(phone: number)
|> deliverOnMainQueue).start(next: { [weak self] resolveResult in
    guard let self else {
        return
    }
    params.progress?.set(.single(false))

    // A failed lookup is not the same as "this number is not on Telegram" — a frozen or
    // bot session, a dropped connection or a rejected method all land here. Treat it as
    // unknown rather than telling the user something we were never told.
    let peer: EnginePeer?
    let lookupFailed: Bool
    switch resolveResult {
    case let .peer(value):
        peer = value
        lookupFailed = false
    case .notRegistered:
        peer = nil
        lookupFailed = false
    case .failed:
        peer = nil
        lookupFailed = true
    }

    var firstName = ""
```

**The `else` branch offering "Invite to Telegram" when there is no resolved peer.** Find:

```swift
} else {
    items.append(
        .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_InviteToTelegram, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Telegram"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
        f(.default)

        guard let self else {
            return
        }
        self.inviteToTelegram(numbers: [number])
    }))
    )
}
```

Add a new branch immediately before it (the `InviteToTelegram` branch itself is unchanged):

```swift
} else if lookupFailed {
    // No "Invite to Telegram" here: inviting someone who may well already be on
    // Telegram is exactly the wrong action to suggest when we do not know.
    items.append(
        .action(ContextMenuActionItem(text: NovagramL10n(self.presentationData.strings).phoneMenu_retry, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
        f(.default)

        guard let self else {
            return
        }
        self.openPhoneContextMenu(number: number, params: params)
    }))
    )
} else {
    // unchanged InviteToTelegram branch
}
```

**The footer row shown when there is no resolved peer.** Find:

```swift
let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
items.append(
    .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_NotOnTelegram, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction))
)
```

Replace with:

```swift
let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
let footerText = lookupFailed
    ? NovagramL10n(self.presentationData.strings).phoneMenu_lookupFailed
    : self.presentationData.strings.Chat_Context_Phone_NotOnTelegram
items.append(
    .action(ContextMenuActionItem(text: footerText, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction))
)
```

Reason: this view previously called `resolvePeerByPhone`, which cannot report a failure — every
non-match rendered the same "Invite to Telegram" + "This number is not on Telegram" pair, even
when the lookup itself never got an answer. It now calls `resolvePeerByPhoneWithStatus` and
branches on `EngineResolvedPeerByPhone`: a genuine `.notRegistered` keeps the existing UI
unchanged, while `.failed` swaps in a "Try Again" action (recursively re-invokes
`openPhoneContextMenu`) and a `phoneMenu_lookupFailed` footer — deliberately with no invite
option, since inviting someone who may already be on Telegram is the wrong suggestion when the
lookup status is unknown. Strings come from `NovagramL10n` (new `phoneMenu_lookupFailed` /
`phoneMenu_retry` keys, en/uz/ru, in `submodules/Novagram/Localization/Sources/NovagramL10n.swift`)
per the existing convention that Novagram strings stay in a Novagram module. No BUILD change was
needed — `TelegramUI/BUILD` already depends on `NovagramLocalization`.

---

## 📌 Brand rewrite for server-delivered localization (2026-08-27)

Investigated while checking why the app still said "Telegram" post-login: the 286 rebranded
"Novagram" strings already hand-edited into `Telegram/Telegram-iOS/en.lproj/Localizable.strings`
never reach a logged-in user. `PresentationStrings` is built from `LocalizationSettings`, whose
entries come from Telegram's own language pack (`langpack.getLangPack`); the bundled file is only
the pre-login fallback. `ru.lproj`/`uz.lproj` do not even ship a `Localizable.strings` — they are
100% server-sourced. Net effect: the entire previous rebranding effort was dead code for anyone
past the login screen.

### `submodules/TelegramPresentationData/BUILD`

In the `deps = [...]` list, prepend:

```python
# Novagram: brand rewrite for server-delivered localization (NovagramBrand has no deps of
# its own, so this cannot create a cycle with NovagramLocalization, which depends on us).
"//submodules/Novagram/Brand:NovagramBrand",
```

Reason: `PresentationData.swift`'s `dictFromLocalization` needs `NovagramBrandStrings.applyBrand(to:)`.
`NovagramBrand` has `deps = []`, so depending on it from `TelegramPresentationData` cannot create a
cycle with `NovagramLocalization`, which itself depends on `TelegramPresentationData` (for
`PresentationStrings`).

---

### `submodules/TelegramPresentationData/Sources/PresentationData.swift`

**Top of file — imports block.** Add after `import Foundation`:

```swift
import NovagramBrand
```

**`dictFromLocalization(_:)` — every assignment wrapped in the brand rewrite.** Find:

```swift
    for entry in value.entries {
        switch entry {
            case let .string(key, value):
                dict[key] = value
            case let .pluralizedString(key, zero, one, two, few, many, other):
                if let zero = zero {
                    dict["\(key)_zero"] = zero
                }
                if let one = one {
                    dict["\(key)_1"] = one
                }
                if let two = two {
                    dict["\(key)_2"] = two
                }
                if let few = few {
                    dict["\(key)_3_10"] = few
                }
                if let many = many {
                    dict["\(key)_many"] = many
                }
                dict["\(key)_any"] = other
        }
    }
```

Replace with:

```swift
    for entry in value.entries {
        switch entry {
            case let .string(key, value):
                // Novagram: every string the app renders passes through here, so this is the one
                // place where the server's language pack can be rebranded for all languages at
                // once. See NovagramBrandStrings for what is deliberately left as "Telegram".
                dict[key] = NovagramBrandStrings.applyBrand(to: value)
            case let .pluralizedString(key, zero, one, two, few, many, other):
                if let zero = zero {
                    dict["\(key)_zero"] = NovagramBrandStrings.applyBrand(to: zero)
                }
                if let one = one {
                    dict["\(key)_1"] = NovagramBrandStrings.applyBrand(to: one)
                }
                if let two = two {
                    dict["\(key)_2"] = NovagramBrandStrings.applyBrand(to: two)
                }
                if let few = few {
                    dict["\(key)_3_10"] = NovagramBrandStrings.applyBrand(to: few)
                }
                if let many = many {
                    dict["\(key)_many"] = NovagramBrandStrings.applyBrand(to: many)
                }
                dict["\(key)_any"] = NovagramBrandStrings.applyBrand(to: other)
        }
    }
```

Reason: `dictFromLocalization` builds the `[String: String]` dictionary backing `PresentationStrings`
for both the `.string` case and all six pluralised forms (`_zero`, `_1`, `_2`, `_3_10`, `_many`,
`_any`), and runs on every entry the server sends. Wrapping every assignment site here rebrands
every string the logged-in app renders, in every language — including `ru`/`uz`, which are 100%
server-sourced and never had a bundled rebrand to begin with.

**What `NovagramBrandStrings.applyBrand(to:)` actually does** (new file,
`submodules/Novagram/Brand/Sources/NovagramBrandStrings.swift`, in the existing `NovagramBrand`
target — no new BUILD target needed):

```swift
public enum NovagramBrandStrings {
    public static let brandName = "Novagram"

    /// Longest-first: `Telegram Stars` has to be claimed before `Telegram Star` can split it.
    private static let protectedPhrases: [String] = [
        "Telegram Passport",
        "Telegram Business",
        "Telegram Desktop",
        "Telegram Premium",
        "Telegram Terms",
        "Telegram Stars",
        "Telegram Star",
        "Telegram Team",
        "Telegram Web",
        "Telegram App"
    ]

    /// U+0000 cannot occur in a language-pack string, so it is safe as a placeholder marker.
    private static let marker = "\u{0}"

    public static func applyBrand(to value: String) -> String {
        guard value.contains("Telegram") || value.contains("TELEGRAM") else {
            return value
        }

        var result = value
        for (index, phrase) in protectedPhrases.enumerated() {
            guard result.contains(phrase) else { continue }
            result = result.replacingOccurrences(of: phrase, with: "\(marker)\(index)\(marker)")
        }

        result = result.replacingOccurrences(of: "TELEGRAM", with: brandName.uppercased())
        result = result.replacingOccurrences(of: "Telegram", with: brandName)

        for (index, phrase) in protectedPhrases.enumerated() {
            let placeholder = "\(marker)\(index)\(marker)"
            guard result.contains(placeholder) else { continue }
            result = result.replacingOccurrences(of: placeholder, with: phrase)
        }
        return result
    }
}
```

- **Product decision — Telegram's own products stay "Telegram".** We do not sell Premium, Stars,
  Business or Gifts (the Apple 3.1.1 IAP gate — see the "App Store IAP gate" section above — blocks
  purchasing them in-app and deep-links to the official Telegram app instead), so "Novagram
  Premium" would advertise a subscription that does not exist on this fork. Passport is a
  Telegram-hosted service; Desktop/Web/App name the official clients; Terms and Team are legal /
  organisational references to the real company. All ten are matched **longest-first** so
  `Telegram Stars` is claimed before the shorter `Telegram Star` can match the substring inside it.
- **The carve-out is phrase-based, not key-prefix-based, on purpose.** Language-pack keys like
  `Settings.Business` or `MESSAGE_GIFTCODE` carry a product name under an unrelated key prefix —
  matching the literal phrase inside the string's _value_ is what determines what it actually says;
  a key-prefix rule would either miss those or need constant re-syncing against the server's key set.
- **The U+0000 placeholder technique** avoids a two-pass ambiguity: protected phrases are swapped
  for a `\u{0}<index>\u{0}` marker (NUL cannot occur in a language-pack string) before the blanket
  `"Telegram"` → `"Novagram"` replacement runs, then swapped back afterward — so a protected
  phrase's own literal `"Telegram"` substring is never touched by the blanket pass.
- **Case sensitivity is deliberate.** Only capitalised `Telegram`/`TELEGRAM` are rewritten; lowercase
  `telegram` is left alone because it only ever appears inside URLs — all 41 occurrences found are
  `telegram.org` — so matching case-sensitively keeps every link intact without needing a URL parser.

⚠️ **Caveat for future maintainers:** this hook rewrites EVERY string the app renders, in EVERY
language, unconditionally, once it contains "Telegram"/"TELEGRAM". Any future upstream string that
legitimately needs to keep saying "Telegram" — a new product name, a new legal reference, anything
in the spirit of the existing `protectedPhrases` entries — must be added to that list in
`NovagramBrandStrings.swift`, or it will silently get rebranded to "Novagram" the next time the
server sends it.

---

## 📌 TelegramUI module — Feature #47 Admin/Owner auto-folders (2026-09-07)

Auto-managed folders for the groups/channels the user owns or admins. When the
"Admin papkalar" toggle (Settings → Novagram → Features) is on, up to 4 **real** Telegram
folders (cloud dialog filters) are created and kept in sync: `👑 Guruhlar/Groups/Группы`
(owner groups), `👑 Kanallar/Channels/Каналы` (owner channels), `🔑 Guruhlar` (admin groups),
`🔑 Kanallar` (admin channels), localized en/uz/ru, emoticon `👥`/`📢` so the folder edit
screen shows the proper icon. (A 2-folder 👑 Owner / 🔑 Admin layout was tried on 2026-09-07
and reverted the same day — the 4-folder split is the chosen product design; the migration
code below carries devices off the 2-folder layout automatically.)

Real folders on purpose: every standard folder surface (tabs, edit screen, reorder, tags,
other devices) keeps working with zero extra UI code. The manager only ever touches
`includePeers` and the DEFAULT title of the folders it created (ids remembered per account in
the `pro_messager` UserDefaults suite under `fenix_admin_folders_map_<accountPeerId>`): while
a managed folder still carries one of our default titles it is re-localized to the current app
language on every sync (folder names are server data, not UI strings — without this they would
stay frozen in the creation-time language); once the user renames it, the custom name sticks
forever. A folder the user deletes by hand becomes a tombstone (`-1` in the map) and is not
recreated until the toggle is cycled; folders left over from a reinstall are adopted by title
instead of duplicated; folders from any previous layout are migrated away on the first sync —
every map entry whose key is no longer a valid category is dropped, plus any unmapped folder
still carrying a known previous-layout title (see `legacyLayoutTitles`). Toggle OFF deletes
only the managed folders, on every account in the working set.

**Implementation file (Novagram module, no upstream change):**
`submodules/Novagram/Messenger/Sources/NovagramAdminFoldersManager.swift` — manager + strings
(picked up by the NovagramMessenger BUILD glob). Sync scans `engine.messages.chatList` (root 1000 +
archive 500), classifies via `TelegramChannel.flags.isCreator` / `.adminRights` /
`TelegramChannel.info` and `TelegramGroup.role` (skipping left/kicked/deactivated peers),
truncates each folder to `UserLimits.maxFolderChatsCount`, and applies everything in one
`updateChatListFiltersInteractively` transform (no-op transforms don't trigger a server sync).
Re-syncs on launch, account switch, app foreground (NotificationCenter observer inside the
manager — no extra upstream hook), throttled to 30 s.

**Settings toggle (Novagram module):** `NovagramSettingsController.swift` — `.adminFolders` row
(features section, stableId 82; folderStyle→featuresFooter renumbered 83–90 and the ads section
93–95 to make room — stableIds are in-memory diff identities, safe to renumber) + deep-link slug
`admin-folders` in `NovagramSettingsDeepLink.swift`.

### `submodules/TelegramUI/Sources/AppDelegate.swift` (UPSTREAM hook)

**+18-line launch block** right after the Feature #45 Auto-Accept block (before
`self.context.set(...)`), same shape: takes `sharedContextPromise |> take(1)`, observes
`sharedContext.activeAccountContexts` and calls
`NovagramAdminFoldersManager.startGlobalMonitor(context: primary)` (or `stopGlobalMonitor()` when
no account is active), so the sync follows the active account across switches:

```swift
        // Novagram Admin Folders — Feature #47. When an authorized account is active, keep the
        // auto-managed owner/admin folders (👑/🔑) in sync with the user's actual rights
        // (gated on the "fenix_admin_folders" toggle).
        _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> map { primary, _, _ -> AccountContext? in
                return primary
            }
            |> deliverOnMainQueue).start(next: { primary in
                if let primary = primary {
                    NovagramAdminFoldersManager.startGlobalMonitor(context: primary)
                } else {
                    NovagramAdminFoldersManager.stopGlobalMonitor()
                }
            })
        })
```

`import NovagramMessenger` already present (Feature #45) — **no import and no BUILD change.**

---

## 📌 PasskeysScreen — crash fix, `preconditionFailure` on a detached view (2026-09-16)

**Why:** real App Store crash, 91 devices in two weeks on 12.9.6 build 78 (Xcode Organizer group
`TelegramUIFramework: 0x1050f4000 + 20054712`, `EXC_BREAKPOINT (SIGTRAP)`).

`createPasskey()` awaits `requestPasskeyRegistration()` — a network round-trip — before it calls
`authController.performRequests()`. If the user leaves the screen during that wait, the view is no
longer in a window when AuthenticationServices asks for the presentation anchor, and the original
`preconditionFailure()` killed the app.

Crashing stack:

```
0  @objc PasskeysScreenComponent.View.presentationAnchor(for:)
1  -[ASAuthorizationController _performAuthorizationRequests:requestStyle:requestOptions:]
2  _dispatch_call_block_and_release  →  main queue
```

### `submodules/TelegramUI/Components/Settings/PasskeysScreen/Sources/PasskeysScreen.swift` (UPSTREAM hook)

Three edits, 10 lines total:

1. New stored property on `PasskeysScreenComponent.View`:

```swift
// Captured while the view is still on screen: createPasskey() awaits a network round-trip
// before performRequests(), so the view can be off-window when AuthenticationServices
// asks for the anchor.
private weak var authorizationAnchorScene: UIWindowScene?
```

2. `createPasskey()` — capture it before the `await`, right after the `guard let self` line:

```swift
self.authorizationAnchorScene = self.window?.windowScene
```

3. `presentationAnchor(for:)` — no longer traps:

```swift
func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    if let windowScene = self.window?.windowScene ?? self.authorizationAnchorScene {
        return ASPresentationAnchor(windowScene: windowScene)
    }
    // Screen was torn down mid-request. Hand back a plain anchor so AuthenticationServices
    // reports an error instead of the app dying here.
    return ASPresentationAnchor()
}
```

**On upstream pull:** if upstream rewrites `presentationAnchor(for:)`, re-apply — upstream still
traps there as of 12.9.6. Full crash analysis in `CRASH_AUDIT_12.9.6.md`.

---

## 📌 NewContactScreen — crash fix, component update re-entrancy (2026-09-16)

**Why:** real App Store crash, 222 devices in two weeks on 12.9.6 build 78 (Organizer group
`TelegramUIFramework: 0x1030b8000 + 57738692`, `EXC_BREAKPOINT (SIGTRAP)`).

`ComponentHostView._update` opens with `precondition(!self.isUpdating)`
(`submodules/ComponentFlow/Source/Host/ComponentHostView.swift:47`). `NewContactScreenComponent.View.update`
sets its own `isUpdating = true` and, just before returning, called `activateInput(tag:)` — still inside
the pass. `becomeFirstResponder` makes UIKit **synchronously** resign the currently focused field, that
field's `textFieldDidEndEditing` calls `state.updated()`, and the component update re-enters while the
host view is still updating.

Crashing stack:

```
0  ComponentHostView._update(…)                                    ← precondition trap
1  closure #1 in ComponentHostView._update(…)
2  closure #1 in ComponentView._update(…)
3  ComponentState.updated(transition:isLocal:)
4  ListTextFieldItemComponent.View.textFieldDidEndEditing(_:)
6  -[UITextField _notifyDidEndEditing]
7  -[UITextField _resignFirstResponder]
8  -[UIResponder _finishResignFirstResponderFromBecomeFirstResponder:]
11 -[UIResponder becomeFirstResponder]
14 NewContactScreenComponent.View.activateInput(tag:)
```

**User-visible trigger:** Contacts → new contact → type a first name → press **Next** on the keyboard
(`onReturn` sets `updateFocusTag` then calls `state.updated()`). Same for last name → phone, and for the
country-code picker.

### `submodules/TelegramUI/Components/Contacts/NewContactScreen/Sources/NewContactScreen.swift` (UPSTREAM hook)

One edit, at the end of `View.update(component:availableSize:state:environment:transition:)`:

```swift
if let updateFocusTag {
    // becomeFirstResponder makes UIKit synchronously resign whichever field holds focus
    // now, and that field's textFieldDidEndEditing calls state.updated() — re-entering
    // the update we are still inside, which trips ComponentHostView's
    // precondition(!isUpdating). Move the focus change to the next runloop turn.
    Queue.mainQueue().justDispatch { [weak self] in
        self?.activateInput(tag: updateFocusTag)
    }
}
```

Nothing is removed — focus is still applied, one runloop turn later. The same file already guards four
other `state.updated()` call sites with `if !self.isUpdating` (lines ~485, 511, 526, 532); this call site
was missed.

**On upstream pull:** if upstream restructures `update(...)`, re-apply. Full crash analysis in
`CRASH_AUDIT_12.9.6.md`.

---

## 📌 Animated stickers — crash fix, corrupt cache file trusted (2026-09-17)

**Why:** real App Store crash, 96 devices in two weeks on 12.9.6 build 78,
`EXC_BAD_ACCESS (SIGSEGV)` inside `AnimatedStickerCachedFrameSource.takeFrame(draw:)`.
Reached from `DefaultAnimatedStickerNodeImpl.play(firstFrame:fromIndex:)` on the playback timer —
i.e. any animated sticker or animated emoji.

The cached-animation format is a 20-byte header (five `Int32`s) followed by
`[Int32 frameLength][frameLength bytes of LZFSE]` per frame. Every field was trusted.

### `submodules/AnimatedStickerNode/Sources/AnimatedStickerFrameSource.swift` (UPSTREAM hook)

Three guards added to `AnimatedStickerCachedFrameSource`:

1. `init` — reject a file shorter than the header before the five `memcpy`s:

```swift
// The header is five Int32s. A truncated cache file would be read past its end.
if buffer.count < 20 {
    return false
}
```

2. `init` — reject nonsensical header values before `Data(count: bytesPerRow * height)`, which traps
   on a negative product:

```swift
if frameRateValue <= 0 || frameCountValue <= 0 || widthValue <= 0 || heightValue <= 0 || bytesPerRowValue < widthValue {
    return false
}
if Int(bytesPerRowValue) * Int(heightValue) > 256 * 1024 * 1024 {
    return false
}
```

3. `takeFrame(draw:)` — reject a negative `frameLength`. **This is the production SIGSEGV**: the old
   check `self.offset + 4 + Int(frameLength) > dataLength` *passes* for negative values, and
   `compression_decode_buffer` then widens it to `size_t`:

```swift
if frameLength < 0 || self.offset + 4 + Int(frameLength) > dataLength {
    return
}
```

### `submodules/AnimatedStickerNode/Tests/` + `BUILD` (NEW — upstream module)

Four regression tests and `ios_unit_test` / `ios_test_runner` targets, modelled on
`submodules/TextFormat/BUILD`. Before the fix: 2 assertions failed and the test process died with
`signal 5: Trace/BPT trap`. After: 4/4 pass. Run them with:

```sh
./build-input/bazel-8.4.2-darwin-arm64 --output_user_root="$HOME/telegram-bazel-cache/bazel-user-root" \
  test //submodules/AnimatedStickerNode:AnimatedStickerNodeTests \
  --action_env=DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  --xcode_version=26.5.0.17F42 -c dbg --ios_multi_cpus=sim_arm64 \
  --//Telegram:disableProvisioningProfiles --test_output=all
```

`Make.py test` does not work in this repo — it demands `TELEGRAM_CODESIGNING_GIT_PASSWORD`.

---

## 📌 Parabolic keyframe animations — divide by zero (2026-09-17)

**Why:** `StoryItemSetContainerComponent.View.animateOut` appears in App Store crash reports with
`SIGABRT`, raised by `CA::Layer::set_position` — a NaN position.

`generateParabollicMotionKeyframes` builds `midPoint.x = (x1 + x3) / 2`, so its denominator
`(x1 - x2) * (x1 - x3) * (x2 - x3)` reduces to `(x1 - x3)³ / 4`. When source and destination share an
x coordinate that is **zero**, so `a`, `b`, `c` are NaN, `y = a·x² + b·x + c` is NaN, and
`layer.position = …` raises.

The guard only took the safe linear branch when **both** axes were close (`&&`). Upstream already
fixed exactly this in `Calls/CallScreen/Sources/Components/KeyEmojiView.swift:147` by switching to
`||`, but left five other copies untouched. Applied the same change to all of them:

| File | Animation the user sees |
|---|---|
| `ReactionSelectionNode/Sources/ReactionContextNode.swift` | reaction flying to the message |
| `TelegramUI/Components/Chat/QuickShareScreen/Sources/QuickShareToastScreen.swift` | avatar flying on swipe-to-share |
| `TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryItemSetContainerComponent.swift` | story closing |
| `TelegramUI/Components/EmojiStatusSelectionComponent/Sources/EmojiStatusSelectionComponent.swift` | emoji status pick |
| `PremiumUI/Sources/EmojiHeaderComponent.swift` | Premium screen header |

**Not reproducible by hand** — it needs exact x alignment; 20 open/close cycles of the stories viewer
produced nothing. The defect is provable from the arithmetic and `||` is strictly safer: a parabola
through two vertically-aligned points *is* a straight line.

**On upstream pull:** if upstream ever unifies these copies into one helper, drop these hooks.

---

## 📌 Three defensive crash guards (2026-09-17)

All three are provable from the code, none could be reproduced by hand on a device, and none change
behaviour for valid input. From the same App Store crash sweep as the fixes above.

### `submodules/TelegramUniversalVideoContent/Sources/HLSVideoJSNativeContentNode.swift` (UPSTREAM hook)

`HLSJSServerSource.fileData(id:range:)` crashed with a Swift precondition failure inside
`Data.subdata` — `Data._Representation.subscript.getter`. `result.offset`/`result.size` describe what
`MediaBoxFileContextV2Impl` believes it wrote, but the partial file mapped from disk can be shorter
(a write cut short, or a flush landing after the map). Range-checked before slicing:

```swift
let lowerBound = Int(result.offset)
let upperBound = Int(result.offset + result.size)
if lowerBound >= 0 && lowerBound <= upperBound && upperBound <= data.count {
    let subData = data.subdata(in: lowerBound ..< upperBound)
    postbox.mediaBox.storeResourceData(…)
}
```

Skipping the cache store is harmless — playback reads `partialFile` from the `putNext` below, which
is outside this block.

### `submodules/Utils/VolumeButtons/Sources/VolumeButtons.swift` (UPSTREAM hook)

`AVCaptureEventHandlerImpl.__deallocating_deinit` crashed in `_dispatch_assert_queue_fail`:
`AVCaptureEventInteraction` tears down through `_UIPhysicalButtonInteraction`, which asserts it is on
the main queue. `VolumeButtonsListener.deinit → SharedContext.remove(id:) → updateListeners() →
cameraSpecificHandler = nil` runs on whichever thread dropped the listener — the sibling
`update(id:)` path is `deliverOnMainQueue`, this one never was. The deinit now hops:

```swift
let interaction = self.interaction
let context = self.context
let tearDown: () -> Void = {
    interaction.isEnabled = false
    context?.mainWindow?.viewController?.view.removeInteraction(interaction)
}
if Thread.isMainThread { tearDown() } else { Queue.mainQueue().async(tearDown) }
```

### `submodules/LegacyComponents/Sources/TGMediaPickerPhotoStripView.m` (UPSTREAM hook)

79 devices, `SIGABRT` from `-[UICollectionView _Bug_Detected_In_Client_Of_UICollectionView_Invalid_Batch_Updates:]`
via `insertItemAtIndex:`, reached from `TGMediaPickerGallerySelectedItemsModel.addSelectedItem:`.
The data source returns `selectedItemsModel.totalCount`, and the model and the collection view fall
out of step — `selectedItemsModel` is assigned after the view exists, and two selection changes can
land before the view has processed the first. Both `insertItemAtIndex:` and `deleteItemAtIndex:` now
compare the data source count with the collection view's cached count and fall back to `reloadData`
when they disagree. The thumbnail still appears, just without the insert animation.

---

## 📌 Chat input service tasks — stale length in attributed-string enumeration (2026-09-17)

**Why:** 59 devices in two weeks on 12.9.6 build 78, `SIGABRT` raised by
`-[NSRLEArray objectAtIndex:effectiveRange:runIndex:]` under
`-[NSAttributedString enumerateAttribute:inRange:options:usingBlock:]`, i.e. `NSRangeException`.

### `submodules/TelegramUI/Sources/ChatInterfaceInputContexts.swift` (UPSTREAM hook)

`serviceTasksForChatPresentationIntefaceState` captures the composer text up front:

```swift
let inputText = chatPresentationInterfaceState.interfaceState.composeInputState.inputText
```

and then, inside the `resolveInlineStickers` completion — after a **network round-trip** — enumerated
the *current* text using the *captured* one's length:

```swift
inputState.inputText.enumerateAttribute(…, in: NSRange(location: 0, length: inputText.length), …)
//                  ^^ current text                                    ^^ stale length
```

If the user shortens or clears the draft while the sticker request is in flight, the range runs past
the end of the string and `NSAttributedString` raises. Fixed by using `inputState.inputText.length`.

**Not verified on device** — reaching the code needs an unresolved custom emoji in the composer, and
custom emoji are Premium-gated server-side, so a non-Premium test account cannot get one there. The
mistake is unambiguous in the source: the enumerated string and the range now come from the same
object.

---

## 📌 SSubscriber — disposal race (2026-09-17)

**Why:** 51 devices in two weeks on 12.9.6 build 78, `EXC_BAD_ACCESS (SIGSEGV)` in `objc_retain`
inside `-[SSubscriberDisposable dispose]`, reached from `-[SSubscriber putCompletion]` under
`TGPhotoEditorController.createEditedImageWithEditorValues:…`. The photo editor is just where it
surfaced — every signal in the app goes through this code.

### `submodules/SSignalKit/SSignalKit/Source/SSignalKit/SSubscriber.m` (UPSTREAM hook)

`_disposable` was read and nilled **outside** the lock in three methods:

```objc
os_unfair_lock_unlock(&_lock);
…
if (shouldDispose) {
    [self->_disposable dispose];   // another thread can nil (and release) it right here
    self->_disposable = nil;       // double release under ARC
}
```

Two threads reaching `putCompletion` / `putError:` / `dispose` concurrently both load the same
`_disposable`, both send it `-dispose`, and both assign nil — the object is released twice and the
second `-dispose` lands on freed memory.

`_markTerminatedWithoutDisposal` in the same file already did it correctly: take the disposable under
the lock, nil it under the lock, send `-dispose` after unlocking. Applied that to `putError:`,
`putCompletion` and `dispose`. `_assignDisposable:` was already correct.

`shouldDispose` disappears — the disposable is only taken when `!_terminated`, and `[nil dispose]` is
a no-op. The second subscriber class further down the file is entirely commented out and untouched.

**Verified on device**: chats, sending, photo editing, video playback, stickers, search and settings
all behave — this is load-bearing code for every signal in the app.

---

## 📌 ChatLock — a chat could be locked with no way back (2026-09-17)

**Reported by a user**, not a crash report: they put a pincode on a chat, turned Face ID off, then
forgot the pincode. The chat could not be opened again.

### Why there was no way out

`NavigateToChatController.swift:~47` only wires the recovery handler when a master pincode exists:

```swift
onForgot: ChatPincodeManager.shared.isMasterEnabled() ? { …master recovery… } : nil
```

and `ChatPincodeViewController` hid the button whenever that handler was nil:

```swift
forgotButton.isHidden = isMasterRecovery ? (failedAttempts < 4) : (verifyOnForgot == nil)
```

The master pincode is a **separate** toggle in NovagramPro settings, off by default. So a chat locked
without it, on a device where biometrics were then switched off, had nothing at all: no Face ID, no
"Forgot pincode?", no reset. The pincode lives in the keychain, which survives deleting and
reinstalling the app, so the chat was unreachable permanently.

The device-owner reset (`resetChatLockTapped` → `authenticateThenReset`) already existed and was
already correct — it uses `.deviceOwnerAuthentication`, i.e. biometrics **or the device passcode** —
it was simply unreachable unless a master pincode had been set.

### `submodules/Novagram/ChatLock/Sources/ChatPincodeViewController.swift` (NOVAGRAM module)

- New `isVerifyMode` / `showsDeviceOwnerReset` helpers. The latter is true on the master page and on
  any plain `.verify` page with no master handler.
- Button title and `forgotTapped()` now key off that, so a verify screen with no master handler runs
  the device-owner reset instead of doing nothing.
- Visibility: the master page keeps its 4-failed-attempts gate (that button wipes every lock, it
  should not lead). A plain chat lock shows the reset **immediately** — whoever forgot the pincode
  tries once or twice and gives up, and would never reach a button that appears on the fourth
  failure. It still costs the device passcode, so showing it early gives a snooper nothing.
- `.set` / `.remove` / `.confirm` keep the button hidden — nothing to recover there.
- The confirmation alert is presented from the navigation controller
  (`(self.navigationController ?? self).present(…)`); `CRASH_AUDIT_2.0.1.md` finding #5 flagged this
  exact line as silently no-opping.

**Rejected alternatives:** forcing a master pincode at first lock (two pincodes to forget instead of
one), and email recovery (needs a server, and is weaker than a passcode that requires physical
possession of the phone).

**Verified on device**: reset appears and works with no master pincode; setup, correct unlock, master
recovery, the master page's own 4-attempt gate, the Secret Vault and lock removal all unchanged.

### Follow-up the same day: the reset button did nothing when tapped

Surfacing the button was only half of it. Testing found the reset authenticating and then silently
giving up, leaving the user on the pincode screen:

- **`LAContext` was a local `let`.** LocalAuthentication cancels an evaluation as soon as its context
  is released, and the completion block did not capture it, so ARC freed it the moment
  `authenticateThenReset()` returned — the Face ID sheet dropped away and no passcode fallback ever
  appeared. The context is now held on the view controller (and, in `ChatLockBiometricHelper`, in a
  static) until the reply arrives.
- **Two prompts fought each other.** `viewDidAppear` fires the screen's own biometric prompt; starting
  the reset evaluation on top of it made the system cancel one. `ChatLockBiometricHelper.cancelPending()`
  now invalidates the outstanding one first.
- **Failure was silent.** `if success { proceed() }` and nothing else. Now an alert explains what
  happened and offers Try Again.
- **`localizedFallbackTitle`** is set, so the passcode option is labelled in the Face ID sheet instead
  of only appearing after two failed scans.
- **The confirmation text now says the passcode works**, so someone whose Face ID is broken or off does
  not assume the reset is closed to them.

Note on behaviour: when biometrics are *available*, iOS insists on them and shows the passcode only
after failures — that is the system's own policy, not ours. When biometrics are unavailable or
disabled (the case that started this), `.deviceOwnerAuthentication` goes straight to the passcode.

---

## 📌 Incoming calls — extension fallback, suspended-account wake, call log line (2026-09-18)

**Why:** calls with long delays and frequent failures, reported across the user base. The
investigation (`CALLS_AUDIT_2026-09-18.md`) found no public Telegram call-engine or MTProto change that
our 12.9.2 base is missing for the production 1:1 engine (13.0.0). What it did find were two breaks on
the incoming-call path that only this fork has:

1. **The notification extension cannot hand a call to CallKit.** Upstream turns a PHONE_CALL_REQUEST
   (or conference-invite) push that reaches the extension into a ringing CallKit call with
   `CXProvider.reportNewIncomingVoIPPushPayload`. Apple allows that only for an extension that has
   `com.apple.developer.usernotifications.filtering`; `Telegram/BUILD` grants it to
   `ph.telegra.Telegraph` alone and our NotificationService profile does not have it, so the call always
   fails (`CXErrorDomainNotificationServiceExtension` code 2). Upstream then leaves empty content, which
   our blank-banner rewrite (build 69) makes invisible: the phone neither rang nor showed anything, and
   the caller waited until the call timed out.
2. **Calls to a suspended account were dropped.** The working-set keeps only the primary and pinned
   accounts live. The PushKit handler reported the call to CallKit, found no context for the account,
   and dropped it at once — `phone.receivedCall` was never sent. Every user with 2+ accounts was hit
   on every non-selected account.

### `Telegram/NotificationService/Sources/NotificationService.swift` (UPSTREAM hook)

- New file-level `novagramIncomingCallFallbackContent(callerTitle:callerPeerId:accountId:incomingCallMessage:payloadJson:)`,
  right before `getCurrentRenderedTotalUnreadCount`. It builds the banner upstream itself shows when iOS
  call integration is off (caller name + `incomingCallMessage`), takes the sound from `aps.sound`
  (falls back to `0.m4a`), and sets `userInfo` `peerId` / `accountId` so a tap opens the caller's chat on
  the called account — the app then connects and the call rings in-app if it is still ringing.
- In both the `.call` and the `.groupCall` branch, inside the `reportNewIncomingVoIPPushPayload`
  completion:

```swift
// Novagram: see novagramIncomingCallFallbackContent
if error != nil {
    updateCurrentContent(novagramIncomingCallFallbackContent(callerTitle: …, callerPeerId: …, accountId: …, incomingCallMessage: incomingCallMessage, payloadJson: payloadJson))
}
completed()
```

When the hand-off succeeds (once Apple grants the entitlement and the profile is regenerated) this
never runs, so nothing needs to be removed then.

**2026-09-19 — the fallback now rings like a call.** On a real TestFlight device the plain banner played
the 3-second message sound, so people took the call for an SMS. Apple's documented CallKit substitute
(`UNNotificationSound.h`, Swift name `defaultRingtone`) plays the user's ringtone and haptics for 30 seconds on
content updated from an `INStartCallIntent` with `destinationType .normal`.

- `NotificationContent` gained `var novagramIncomingCallIsVideo: Bool?` (next to `silent`).
- `generate()` — before the `INSendMessageIntent` block:

```swift
// Novagram: see novagramRingingCallContent
if #available(iOS 15.2, *), let isVideo = self.novagramIncomingCallIsVideo, let ringingContent = novagramRingingCallContent(content, caller: self.senderPerson, isVideo: isVideo) {
    return ringingContent
}
```

- New file-level `novagramRingingCallContent(_:caller:isVideo:)` (donates the `INStartCallIntent`, sets
  `defaultRingtone`, returns `content.updating(from: intent)`, nil on failure → plain banner) and
  `novagramIsVideoCall(updates:)`.
- `novagramIncomingCallFallbackContent` now also takes `callerPeer`, `isVideo`, `mediaBox`, `accountPeerId`,
  adds the caller's avatar via `addSenderInfo` and sets the flag; both call sites pass them.

### `Telegram/BUILD` (UPSTREAM hook)

`NSUserActivityTypes` in the app Info.plist fragment gained `<string>INStartCallIntent</string>` — iOS only
accepts `INStartCallIntent` communication notifications from apps that declare it.

### `submodules/TelegramUI/Sources/SharedAccountContext.swift` (UPSTREAM hook — multi-account section)

- New state next to `novagramPinnedAccountsPromise`: `novagramCallWakeHolds` (record id → number of calls
  holding it), `novagramCallWakeAccountsPromise`, `novagramCallWakeDisposables`.
- New `novagramActiveAccountContexts(waking:)` after `novagramPinnedAccountsSignal`: the same value as
  `activeAccountContexts |> take(1)`, except that a suspended account is held live first and the value
  is delivered once its context has loaded (10 s timeout — then the caller gets the accounts without it
  and falls back to upstream's drop). Private `novagramHoldAccountForCall`, `novagramReleaseAccountForCall`
  and `novagramReleaseAccountWhenCallsEnd` (from 10 s after the wake, waits until no call is ringing on
  that account and no call or group call is in progress, then releases 30 s later so rating / debug-log
  upload still have the context).
- Working-set pipeline: `combineLatest` gained `self.novagramCallWakeAccountsPromise.get()`, the mapped
  tuple gained `callWakeIds`, `distinctUntilChanged` compares it (`lhs.4`), and `novagramWorkingSet` is now
  the union of the capped set and every woken id — on top of `novagramMaxLiveAccounts`, so a ringing call never
  evicts a pinned account. `novagramRecencyOrder` is untouched.

### `submodules/TelegramUI/Sources/AppDelegate.swift` (UPSTREAM hook)

In `pushRegistryImpl`, the conference branch (~line 2344) and the 1:1 branch (~line 2465) both change
their source signal from

```swift
_ = (sharedApplicationContext.sharedContext.activeAccountContexts
|> take(1)
```

to

```swift
// Novagram: wakes the called account first if the multi-account working-set has it suspended
_ = (sharedApplicationContext.sharedContext.novagramActiveAccountContexts(waking: accountId)
```

Everything after it is upstream's code, unchanged: a live account behaves exactly as before, a woken
account is processed by the same loop, and an account that does not load in time is dropped as before.

### `submodules/TelegramCallsUI/Sources/PresentationCall.swift` (UPSTREAM hook)

One log line after `let logName = …` in the `.active` branch of `updateSessionState`:

```swift
Logger.shared.log("PresentationCall", "Novagram call \(logName) active: version \(version), allowsP2P \(allowsP2P), connections \(…), customParameters \(customParameters ?? "nil")")
```

The app never logged which engine version and server flags (`custom_parameters`, including
`inline_conference`) a call was given, so a failing call could not be tied to them.

### Deliberately not changed

- tgcalls stays at `e3069322` (upstream 12.9.2's pin). The 19 newer commits on tgcalls `development`
  change nothing in the 13.0.0 engine at default server settings, the branch describes itself as a
  testbench, and no matching tgcalls + webrtc + app-glue set has been published.
- The advertised call versions and the 12.0.0 TCP-reflector injection in
  `TelegramVoip/Sources/OngoingCallContext.swift` stay as upstream until call logs show which versions
  the server actually gives us.

### Still needed outside the code

`com.apple.developer.usernotifications.filtering` for the **NotificationService** App ID
(`uz.fenixuz.app.NotificationService`), requested with the incoming-call use case. After approval:
regenerate `Fenixuz_AppStore_NotificationService.mobileprovision` and widen the bundle-id gate in
`Telegram/BUILD`.

---

## 📌 Story video scrubbed past its last frame — Timer.start crash (2026-09-21)

Organizer, build 78: `EXC_BREAKPOINT` in `OS_dispatch_source_timer.scheduleRepeating(deadline:interval:leeway:) + 332`
← `Timer.start()` ← `MediaPlayerNode.startPolling()` ← `MediaPlayerNode.pollInner` (153 devices in 14 days,
iOS 16–26). `+332` (disassembled from the iOS 26.6.1 `libswiftDispatch`) is the `UInt64(interval * 1e9)`
"greater than UInt64.max" trap — the polling timer got a finite interval of at least 1.84e10 s.
The crashing interval sits in `x23` in the crash logs: `6.0048e14 = 2^63 / 15360` plus a 4–7 s frame time.

Chain: `MediaPlayerStreaming.story.isSeekable == false`, so `FFMpegMediaFrameSourceContext` stores the video
duration as `CMTimeMake(value: Int64.min, …)` (FFmpeg's `AV_NOPTS_VALUE` gives the same value for streams with
an unknown duration). A seek whose target is past the last video frame (scrubbing a story to its end) fell
back to `actualPts = videoStream.duration`, so `MediaPlayer.seekingCompleted` set the control timebase to
`Int64.min / timescale` ≈ -6e14 s. Seen on a device with temporary logging: `actualPts=-600479950316066.1
dur=-9223372036854775808/15360`. With sound the audio renderer re-anchors the timebase a moment later; for a
video without an audio track nothing does, and `pollInner` computed `maxTakenTime - layerTime` ≈ 6e14 s.
Note: the Novagram app config has no `ios_video_legacyplayer`, so every `NativeVideoContent` (stories included)
runs on this legacy `MediaPlayer`.

### `submodules/MediaPlayer/Sources/FFMpegMediaFrameSourceContext.swift` (UPSTREAM hook)

In `seek(timestamp:completed:)`, when no frame reaches the target, the stream duration is only used if it
is known; otherwise the last frame read is used (the upstream `else` branch that was unreachable before):

```swift
// Novagram: duration is Int64.min when unknown (non-seekable story streams, AV_NOPTS_VALUE),
// so seeking past the last frame put the timebase at about -1e14 s
if let videoStream = initializedState.videoStream, videoStream.duration.value != Int64.min {
    actualPts = videoStream.duration
} else {
    actualPts = extraVideoFrames.last!.pts
}
```

### `submodules/MediaPlayer/Sources/MediaPlayerNode.swift` (UPSTREAM hook)

The poll delay is a repeat interval that only re-checks `isReadyForMoreMediaData`; it is now capped at 1 s,
so no future bad timebase can reach the Dispatch trap:

```swift
// Novagram: capped, DispatchSourceTimer traps when the repeat interval is >= 2^64 ns (~584 years)
completion(.delay(min(max(1.0 / 30.0, state.maxTakenTime - layerTime), 1.0)))
```

Normal delays are well under 1 s, so ordinary playback is unchanged; a larger value only re-polls sooner.

## 📌 China support batch — search clear button, translate target, Chinese strings, header fold (2026-09-23)

A Chinese user wrote to support with four items: Chinese language support, "the bug with the search box at
the top", "translation doesn't work", and "can we fold the header buttons, too much stuff". Both bugs were
reproduced on the simulator with the `zh-hans-raw` pack ("Chinese (Simplified)", 99 %) before fixing.

### `submodules/SearchBarNode/Sources/SearchBarNode.swift` (UPSTREAM hook) — clear button on the field's edge

`updateLayout(boundingSize:leftInset:rightInset:transition:)`, the `.glass` branch after `textBackgroundFrame`
is built. Glass never shows the text Cancel button (the placeholder view keeps a fixed 44 pt close button), but
the frame was still sized from the measured, localized "Cancel" title. "取消" is 19 pt narrower than "Cancel"
(measured on the sim: clear button centre x = 349.8 pt in English, 368.8 pt in Chinese), so the clear (x) sat
half outside the field. The glass width is now the one English always had:

```swift
if case .glass = self.fieldStyle {
    // Novagram: glass never shows the text Cancel button (...)
    textBackgroundFrame.size.width = contentFrame.width - padding - 72.0
} else {
```

72 = 53 pt English "Cancel" + 11 + 8, so English is pixel-identical; every other language now matches it
(Uzbek "Bekor qilish" used to make the field ~37 pt narrower). The second `.glass` block further down
(the animate-in path, sized from `sourceFrame`) is untouched.

### `submodules/TelegramUI/Components/TextProcessingScreen/Sources/TextProcessingTranslateContentComponent.swift` (UPSTREAM hook) — translation echoed the original text

In `update(...)`, `case let .translate(ignoredLanguages):`, right after the `-raw` suffix is stripped from
`strings.baseLanguageCode`. A Chinese pack based on `zh-hans-raw` gave `toLanguage = "zh-hans"`, which is not
in `supportedTranslationLanguages` (`"zh"` is); `messages.composeMessageWithAI` then returned the text
unchanged, so "From English → To Chinese" showed English. Picking 中文 by hand in the language menu (code
`"zh"`) translated correctly — that confirmed the cause. Now:

```swift
if !supportedTranslationLanguages.contains(where: { $0.caseInsensitiveCompare(baseLang) == .orderedSame }) {
    baseLang = normalizeTranslationLanguage(baseLang)
}
```

Supported codes (including `pt-br` vs `pt-BR`) are left as they were; only unknown ones fall back to the plain
code, the same normalization upstream's `TranslatonSettingsController` already applies. No import needed
(`TranslateUI` was imported).

### `submodules/SettingsUI/Sources/Language Selection/LocalizationListControllerNode.swift` (UPSTREAM hook) — Chinese in Settings → Language

`import NovagramLocalization` after `import NovagramPremiumUnlock`, and at the top of the list subscription's
`start(next:)` closure (after `guard let strongSelf = self`):

```swift
let localizationListState = NovagramChineseLocalizations.adding(to: localizationListState)
```

`NovagramChineseLocalizations` (Novagram-owned, `submodules/Novagram/Localization/Sources/NovagramChineseLocalizations.swift`)
slots "Chinese (Simplified) / 简体中文" (`zh-hans-raw`) and "Chinese (Traditional) / 繁體中文" (`zh-hant-raw`) into
the alphabetical part of the official list (the server puts English and the regional language, Uzbek, first),
unless the list already has them by code **or by English name**: on a device that has used a Chinese pack the
server sends its own "Chinese (Simplified/Traditional)" entries under other codes, and an installed pack is
listed too — matching by code alone showed Chinese twice (fixed the same day). Picking a
row calls the existing `downloadAndApplyLocalization(languageCode:)`, same as `t.me/setlanguage/zh-hans-raw`.
The search list gets them too, because it is built from `currentListState`. `SettingsUI/BUILD` already had the
`NovagramLocalization` dep; `Novagram/Localization/BUILD` gained `//submodules/TelegramCore:TelegramCore`.

### Chinese for Novagram strings that live in Telegram-owned files (UPSTREAM hooks)

`NovagramL10n.languageKey(for: strings)` (new, `Novagram/Localization`) returns `"zh"` for any Chinese pack —
primary code, base (`secondaryComponent`) code or plural-rules code starting with `zh` / containing `-zh` —
because community packs have arbitrary codes (`zhcncc`, `classic-zh-cn`, `taiwan`…). Otherwise it returns the
primary code unchanged, so uz / ru / en behave exactly as before. Each hook below swapped its
`strings.primaryComponent.languageCode` (or `baseLanguageCode`) for `languageKey(for:)` and gained a
`case "zh":` next to `case "ru":`:

| File | Hook | Added |
|---|---|---|
| `AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift` | `novagramProxyPressed()` NovagramProxy alert | `import NovagramLocalization`, zh text + action |
| `TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` | #38 gift send-confirm | zh title/text/send/cancel |
| `TelegramUI/Sources/ChatController.swift` | #38 sticker send-confirm | `import NovagramLocalization`, zh line |
| `TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift` | #38 voice send-confirm | `import NovagramLocalization`, zh line |
| `TelegramUI/Sources/ChatControllerNode.swift` | #37 send-translate confirm | `import NovagramLocalization`, zh case |
| `ChatListUI/Sources/ChatContextMenus.swift` | Secret read, Copy Chat ID, Recent actions | `import NovagramLocalization`, 3 zh cases |
| `ChatListUI/Sources/ChatListFilterPresetController.swift` | folder icon row title | `import NovagramLocalization`, zh case |
| `ChatListUI/Sources/NovagramFolderIconPicker.swift` (fork file) | picker title | `import NovagramLocalization`, zh case |
| `TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` | `novagramLangCode` for the Novagram rows | `NovagramL10n.languageKey(for:)` instead of `baseLanguageCode` |

`ChatListUI/BUILD` gained `//submodules/Novagram/Localization:NovagramLocalization` (no cycle: NovagramLocalization
depends only on TelegramPresentationData + TelegramCore).

Novagram-owned string tables got `zh` everywhere (no merge risk): `NovagramL10n.swift` (`pick(en:uz:ru:zh:)`, `zh`
required so a missing one fails to compile), `NovagramAboutController.swift` (`L3.zh` required), every NovagramMessenger
strings switch + the embedded bots JSON (`NovagramBotLocalizedText.zh` optional), ChatLock, SecretVault,
SpeechToText, ContactsConsent, EditedHistory, UnreadReminder, Analytics. Device-language helpers
(`Locale.current.languageCode`) get `"zh"` on a Chinese iPhone without any `zh.lproj`.

### `submodules/ChatListUI/Sources/ChatListController.swift` (UPSTREAM hook) — header buttons fold

`ChatListLocationContext.rightButtons`: after the compose button, the story / ghost / proxy buttons are collected
into `foldableButtons`. With two or more of them, they are shown only while `NovagramHeaderFold.isExpanded`, followed
by one `.systemIcon` chevron button (`id: "novagramHeaderFold"`) that flips the flag and calls
`parentController?.requestLayout(...)` (the header re-reads `rightButtons` in `updateHeaderContent()`). With fewer
than two, nothing changes (a plain [story][compose] header looks exactly like upstream). Buttons are laid out right
to left, so the chevron is the leftmost item of the capsule and the hidden buttons slide out to its right.

`NovagramHeaderFold` (Novagram-owned, `submodules/Novagram/ForeignUserBlock/Sources/ChatList_NovagramHeaderFold.swift`,
already a ChatListUI dep and imported by this file): `pro_messager` key `fenix_header_buttons_expanded`,
default `false` = folded; chevron points left while folded, right while unfolded.

---

## 📌 Edit and Send — edit a post before forwarding it (2026-09-25)

**Owner request:** forward a post from a joined channel into their own channel without the sender's
name, but trim the text first (the source post ends with links to other channels). Editing after
sending leaves an "edited" label, and `messages.forwardMessages` cannot change the text.

**Solution:** a new option in the chat's forward-options menu (tap the forward panel above the
composer): **"Tahrirlab yuborish" / "Edit and Send"**. It opens a modal editor with the post's text
(Telegram's `TextFieldComponent`: formatting menu, custom emoji) and a media preview. Send builds new
`EnqueueMessage.message` items — the same photo/video/file re-sent by its cloud reference (nothing is
uploaded again, `.message(message:media:)` keeps file-reference revalidation working), the edited text,
no forward header. Same idea as the Bot API `copyMessage`.

It is a separate feature on purpose (owner: "alohida feature, boshqalarga bog'lamaslik kerak"):
own module, own strings (en/uz/ru/zh), no dependency on NovagramL10n or NovagramMessenger. The copies go
through `ChatControllerImpl.sendMessages`, not the composer's `sendCurrentMessage`, so auto-translate,
auto-text, text style, heart effect and auto-sticker never touch them. Send-as, silent posting,
scheduled-messages mode, topics and paid-message confirmation still apply.

Offered only for one post or one album (≤10 grouped messages) made of text, photos, videos, GIFs,
music, voice and documents. Not offered for polls, locations, contacts, dice, stories, paid media,
stickers, round videos, rich (InstantPage) messages, copy-protected chats or secret chats.
Buttons (inline keyboards) cannot be sent by users, so the editor says they are not copied.
Link preview: kept while the text still links to the previewed page; if the original had links but
no preview, the copy disables previews too.

### `submodules/Novagram/ForwardEdit/` (NOVAGRAM module, new)

- `NovagramForwardEdit.swift` — public `menuItem(context:targetPeerId:threadId:messages:present:send:)`.
- `NovagramForwardEditCopy.swift` — eligibility (`NovagramForwardEditSource`) and the copy builder.
- `NovagramForwardEditScreen.swift` — the editor screen.
- `NovagramForwardEditStrings.swift` — its own strings.

### `submodules/TelegramUI/BUILD` (UPSTREAM hook)

```
"//submodules/Novagram/ForwardEdit:NovagramForwardEdit",
```

added after the `NovagramSponsored` dep.

### `submodules/TelegramUI/Sources/Chat/ChatMessageActionOptions.swift` (UPSTREAM hook)

1. `import NovagramForwardEdit` after `import WebsiteType` (with a `// NOVAGRAM-HOOK #39` comment).
2. In `chatForwardOptions(...)`, inside the `items` map, right after the "Show/Hide Caption" item and
   before `if !items.isEmpty { items.append(.separator) }`:

```swift
// NOVAGRAM-HOOK #39 — edit before forwarding START
if let novagramEditItem = NovagramForwardEdit.menuItem(context: selfController.context, targetPeerId: peerId, threadId: selfController.chatLocation.threadId, messages: messages, present: { [weak selfController] controller in
    selfController?.push(controller)
}, send: { [weak selfController] copies in
    selfController?.presentPaidMessageAlertIfNeeded(count: Int32(copies.count), completion: { [weak selfController] postpone in
        guard let selfController else {
            return
        }
        selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil).withoutSelectionState() }) })
        selfController.sendMessages(copies, media: true, postpone: postpone)
    })
}) {
    items.append(novagramEditItem)
}
// NOVAGRAM-HOOK #39 — edit before forwarding END
```

On an upstream pull: re-apply both pieces; the anchor is the forward-options item list in
`chatForwardOptions`. If upstream renames `sendMessages` / `presentPaidMessageAlertIfNeeded` /
`withUpdatedForwardMessageIds`, map to the new names — the module itself does not change.

---

## 📌 Xcode 27.1 / Swift 6.4 build compatibility (2026-10-08)

Not a feature hook — a toolchain fix so the fork builds with Xcode 27.1 (Swift 6.4); the old
Xcode 26.5 no longer launches on the current macOS.

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` (import block, right after `import ChatEntityKeyboardInputNode`)

```swift
import ChatEntityKeyboardInputNode
// TextFieldComponent also has a public EmptyInputView and Swift 6.4 calls it ambiguous, so pin this one
// swiftlint:disable:next duplicate_imports
import class ChatEntityKeyboardInputNode.EmptyInputView
```

Reason: this file imports both `ChatEntityKeyboardInputNode` and `TextFieldComponent`, and both
declare an identical `public final class EmptyInputView`. Swift 6.4 reports `ambiguous use of
'EmptyInputView'` at `private let emptyInputView = EmptyInputView()`; the scoped import picks the
keyboard one. The `swiftlint:disable:next` line is required — `swiftlint --fix` (auto-lint hook)
treats the scoped import as a duplicate of `import ChatEntityKeyboardInputNode` and deletes it.

On an upstream pull: keep the three lines unless upstream renamed/removed one of the two
`EmptyInputView` classes (then the line can go).

Related (not a Telegram-owned file): `run.sh` now derives `--xcode_version` from the installed
Xcode and passes `--@build_bazel_rules_swift//swift:copt=-no-warnings-as-errors` (+ `exec_copt`),
because Swift 6.4's new `ImplicitStrongCapture` warning hits hundreds of upstream files that build
with `-warnings-as-errors`. `publish.sh` / `release.sh` call Bazel directly and don't pass this flag yet.

---

## 📌 2026-10-10 — Interface toggles: Hide folders, Stories panel, Mutual contact badge

Novagram Settings → Interface. Each toggle is read straight from the `pro_messager` UserDefaults suite inside an upstream file.

### `submodules/ChatListUI/Sources/ChatListController.swift` (UPSTREAM hook) — Hide folders

Anchor: `forKey: "hide_folders"` (~4058). It sits in the filter-tab builder, right after `var (_, items) = countAndFilterItems`.

```swift
let hideFolders = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "hide_folders") ?? false
if hideFolders {
    items = items.filter { item in
        if case .allChats = item.0 { return true }
        return false
    }
}
```

Only the "All Chats" tab is kept, so the tab strip disappears.

### `submodules/ChatListUI/Sources/ChatListControllerNode.swift` (UPSTREAM hook) — Stories panel

Anchor: `forKey: "show_stories"`, in the first lines of `shouldDisplayStoriesInChatListHeader(storySubscriptions:isHidden:)`.

```swift
if UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_stories") as? Bool == false {
    return false
}
```

When the key is not set, the upstream behavior stays unchanged.

### `submodules/ContactsPeerItem/Sources/ContactsPeerItem.swift` (UPSTREAM hook) — Mutual contact badge

Anchors:
- `show_mutual_contact_symbol` (~793, top of the `asyncLayout` closure; default ON).
- Three `user.flags.contains(.mutualContact) && showMutualContactSymbol` branches (~972–984). Each appends `" 🤝"` to the title.

---

## 📌 2026-10-10 — Unlimited Pins: device-local overflow (`NovagramLocalPins`)

The `pro_messager/unlimited_pins` toggle raises the client pin limit to 1000 in `TogglePeerChatPinned.swift`. Pins above the server's `dialogs_pinned_limit` are stored on the device, and every path that writes the server's pinned list merges them back.

### `submodules/TelegramCore/Sources/Novagram/NovagramLocalPins.swift` (fork-ADDED file)

`NovagramLocalPins` keeps the overflow tail per account and group under the key `unlimited_pins_local_<accountPeerId>_<groupId>`.

- API: `overflowPeerIds`, `setOverflowPeerIds`, `removePeerId`, `clearAll(accountPeerId:)`, `clearAllAccounts()` and `merged(serverItemIds:accountPeerId:groupId:)`.
- It also defines `_internal_novagramTrimPinnedChatsToServerLimit(postbox:accountPeerId:)`.
- It covers `.group` locations only (main list and archive). Nothing is stored while the toggle is off.

### `submodules/TelegramCore/Sources/State/Holes.swift`, `ResetState.swift`, `ManagedSynchronizePinnedChatsOperations.swift` (UPSTREAM hooks)

Anchor: `NovagramLocalPins.merged(` at `Holes.swift` ~1269, `ResetState.swift` ~126 and `ManagedSynchronizePinnedChatsOperations.swift` ~228. Each of these writes the merged list instead of the server's raw list:

```swift
let novagramItemIds = NovagramLocalPins.merged(serverItemIds: replacePinnedItemIds.map(PinnedItemId.peer), accountPeerId: accountPeerId, groupId: groupId)
transaction.setPinnedItemIds(groupId: groupId, itemIds: novagramItemIds)
```

`ResetState` uses `groupId: .root`. `ManagedSynchronizePinnedChatsOperations` merges `resultingItemIds` after its own reconciliation step.

### `submodules/TelegramCore/Sources/TelegramEngine/Peers/TelegramEnginePeers.swift` (UPSTREAM hook)

Anchor: `novagramTrimPinnedChatsToServerLimit` (~245). This is the facade over `_internal_novagramTrimPinnedChatsToServerLimit`. `NovagramSettingsController` calls it when the toggle is turned off, so the device-only pins are unpinned instead of staying in Postbox.

---

## 📌 2026-10-10 — Anti-delete: history validation keeps retained messages

### `submodules/TelegramCore/Sources/State/HistoryViewStateValidation.swift` (UPSTREAM hook)

Anchor: `isNovagramRetainedDeletedMessage(transaction:` at ~986 (chat branch) and ~1175 (thread branch).

The validator deletes local messages that the server no longer returns. A message the peer deleted is exactly that kind of message, so when it carries the retained-deleted marker it is skipped, with a `HistoryValidation` log line. The helper is defined in `TelegramCore/Sources/Novagram/NovagramShowDeletedMessages.swift`.

---

## 📌 2026-10-10 — View First Message + Novagram Info

### `submodules/TelegramUI/Sources/ChatController.swift` (UPSTREAM hook)

- `public func navigateToFirstMessage()` (~9552) calls `navigateToMessage(messageLocation: .index(MessageIndex.absoluteLowerBound()), animated: true, forceInCurrentChat: true)`. It is declared on the `ChatController` protocol in `AccountContext/Sources/ChatController.swift`.
- "View First message" context items at ~4703 (peer menu) and ~6072 (`avatarNode.contextAction`). They are gated by `pro_messager/show_view_first_message` (default OFF).

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenPerformButtonAction.swift` (UPSTREAM hook)

The "…" menus of user (~861), group (~1124) and channel (~1337) profiles get two items:
- "View First message", behind the same toggle. It returns to the chat and calls `chatController.navigateToFirstMessage()`.
- "Novagram Info", always shown. It opens an alert with the peer's ID, type, username and Premium/Scam/Fake flags, plus Copy.

Anchors: `show_view_first_message` and `"Novagram Info"`.

---

## 📌 2026-10-10 — Ghost mode: remaining server-signal guards

Each guard reads `isNovagramGhostModeActive` (TelegramCore) or `pro_messager/is_ghost_mode_active` (UI modules) and skips only the network side effect. The local UI still updates.

| File | Function / anchor | Suppressed while Ghost is on |
|---|---|---|
| `TelegramCore/Sources/TelegramEngine/Messages/ApplyMaxReadIndexInteractively.swift` | `_internal_toggleForumThreadUnreadMarkInteractively`, `_internal_markForumThreadAsReadInteractively`, `_internal_togglePeerUnreadMarkInteractively` | `messages.readDiscussion`, `messages.readSavedHistory`, `messages.markDialogUnread` |
| `TelegramUI/Sources/AccountContext.swift` | `applyMaxReadIndex(for:contextHolder:messageIndex:)` (~623) | returns early, so no read index is applied |
| `TelegramCore/Sources/TelegramEngine/Messages/MarkAllChatsAsRead.swift` | `_internal_markAllChatsAsRead` (~20) | "Mark all as read" requests |
| `TelegramCore/Sources/TelegramEngine/Messages/Stories.swift` | `_internal_markStoryAsSeen` (~2089) | `stories.incrementStoryViews` |
| `TelegramCore/Sources/State/ManagedSynchronizeConsumeMessageContentsOperations.swift` | `synchronizeConsumeMessageContents` (~113) | `messages.readMessageContents` ("listened" state of voice and video messages) |
| `TelegramUI/Components/MediaManager/PeerMessagesMediaPlaylist/Sources/PeerMessagesMediaPlaylist.swift` | `onItemPlaybackStarted` (~920) | `markMessageContentAsConsumedInteractively` when playback starts |
| `GalleryUI/Sources/SecretMediaPreviewController.swift` | `applyMessageView` (~551) | marking self-destructing media as consumed |
| `TelegramCore/Sources/PendingMessages/StandaloneSendMessage.swift` (~615), `TelegramCore/Sources/State/PendingMessageManager.swift` (~2194) | screenshot-notification branch | `messages.sendScreenshotNotification` |

---

## 📌 2026-10-10 — Text style, Auto-text suffix, translate target language

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` (UPSTREAM hook)

These two blocks are in the text send loop, `for originalText in breakChatInputText(...)`:
- `// PRO MESSAGER: Automatic Text Adder` (~5222). When `auto_text_enabled` is on and `auto_text_content` is not empty, it appends `" " + content` with the attributes of the last character.
- `// PRO MESSAGER: Apply default text style to outgoing messages` (~5245). `text_style` is one of `bold`, `italic`, `monospace`, `strikethrough`, `underline` or `spoiler`, and adds one `MessageTextEntity` over the whole text.

### `submodules/TelegramUI/Sources/ChatController.swift` (UPSTREAM hook)

- The same text-style block in the `sendMessage:` interaction closure (~2310).
- The Translate action (~4458) takes its target language from `UserDefaults(suiteName: "pro_messager_translation")?.string(forKey: "selected_language")` and passes it as `toLanguage:` to `presentTranslateScreen`.

---

## 📌 2026-10-10 — Block foreign numbers

The toggle is `pro_messager/block_foreign_users`, and the account's own number is cached in `pro_messager/my_phone_number`. The country-code helpers come from `NovagramForeignUserBlock`. Bots, Telegram service accounts (777000, 333000, Replies) and the account itself are never blocked.

- `submodules/TelegramUI/Sources/AccountContext.swift` (~467) saves `my_phone_number` when the account peer loads.
- `submodules/ChatListUI/Sources/Node/ChatListNodeEntries.swift` (~671) skips chat-list entries of foreign users.
- `submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift` (~111) returns no entries for a foreign user's chat.
- `Telegram/NotificationService/Sources/NotificationService.swift` (~1594) drops the push from a foreign user.

The anchor in every file is `block_foreign_users`.

---

## 📌 2026-10-10 — Story unlock: save and HD without Premium

The gate is `NovagramStoryUnlock.isEnabled` (`pro_messager/fenix_story_unlock_enabled`). It is added next to each `isPremium` check:
- `submodules/TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryItemSetContainerComponent.swift` (~7311–7436): the HD quality and Download items in the story menu.
- `StoryContainerScreen/Sources/StoryChatContent.swift` (5 sites), `submodules/ChatListUI/Sources/ChatListController.swift` (~2142) and `submodules/TelegramUI/Sources/ChatHistoryListNode.swift` (~1884): `settings.highQualityStories && (isPremium || NovagramStoryUnlock.isEnabled)`.
- `StoryContainerScreen/BUILD`: `//submodules/Novagram/StoryUnlock:NovagramStoryUnlock`.

---

## 📌 2026-10-10 — Translate entire chats: translation panel

### `submodules/TelegramUI/Components/TranslateHeaderPanelComponent/Sources/ChatTranslationPanelNode.swift` (UPSTREAM hook)

The file imports `NovagramPremiumUnlock` and has three `NovagramPremiumUnlock.isTranslateChatsUnlocked` gates:
- ~185: the panel's settings button.
- ~226: the panel gate.
- ~250: the "Translate to …" button.

`TranslateHeaderPanelComponent/BUILD` adds `//submodules/Novagram/PremiumUnlock:NovagramPremiumUnlock`.

---

## 📌 2026-10-10 — NotificationService: blank service rows

### `Telegram/NotificationService/Sources/NotificationService.swift` (UPSTREAM hook)

Service pushes that must stay invisible are rebuilt as blank content with `threadIdentifier = "novagram-service-push"` and `userInfo["fenixuz_blank"] = "1"` (~736). Later invocations remove these rows (~2672, ~2813, ~2855), so they never stack up in Notification Center. Anchor: `fenixuz_blank`.

---

## 📌 2026-10-10 — Brand: permission strings, Siri vocabulary, watch name

- `Telegram/Telegram-iOS/<lang>.lproj/InfoPlist.strings` (18 languages) and `Telegram/Telegram-iOS/InfoBazel.plist`: the permission prompts say "Novagram".
- `Telegram/Telegram-iOS/<lang>.lproj/AppIntentVocabulary.plist` (19 languages): the Siri example phrases say "Novagram".
- `Telegram/WatchApp/tgwatch Watch App/Info.plist`: the watch display name is "Novagram" (it comes with the tgwatch export).

Anchor: `Novagram`. On an upstream merge, keep our strings.

---

## 📌 2026-10-10 — Deleted-message status label dependency

- `submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/BUILD` depends on `//submodules/Novagram/Localization:NovagramLocalization`, for the "🗑 Removed" status label in `StringForMessageTimestampStatus.swift`.

---

## 📌 2026-10-10 — Debug-only input log

### `submodules/TelegramUI/Components/Chat/ChatInputTextNode/Sources/ChatInputTextNode.swift` (UPSTREAM hook)

`NSLog("NOVAGRAM_INPUT_DBG ...")` (~1336) is inside `#if DEBUG`. It logs the content height, offset and insets when the input overflows. Release builds are not affected.

---

## 📌 2026-10-10 — UIScene life cycle + private keyboard API (iOS 27 SDK launch blockers)

Apps built with the iOS 27 SDK (Xcode 27.1) are stopped at launch on iOS 27 unless they use the
scene-based life cycle ("UIScene life cycle is required for apps built with this SDK"). The App
Store build 12.9.8 (Xcode 26.5) is not affected; every build from this Mac (Xcode 27.1) is.

### `submodules/Novagram/SceneLifecycle/` (NOVAGRAM module, new) — `NovagramSceneDelegate`

`@objc(NovagramSceneDelegate)` `UIWindowSceneDelegate`. It attaches the app delegate's existing
window to the scene in `scene(_:willConnectTo:options:)` and forwards every scene callback to the
matching `UIApplicationDelegate` method, which UIKit no longer calls by itself in a scene app:
foreground/active/resign/background, `openURLContexts` → `application(_:open:options:)`,
`continue userActivity`, `performActionFor shortcutItem`, plus the launch payloads from the
connection options. It also returns `.minimal` from `preferredWindowingControlStyle(for:)`, which
`WindowRootViewController` used to provide by making itself the scene delegate.

### `Telegram/BUILD` (UPSTREAM hook) — `TelegramInfoPlist`

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
</dict>
```

No `UISceneConfigurations`: UIKit asks the app delegate for the configuration instead.

### `submodules/TelegramUI/Sources/AppDelegate.swift` (UPSTREAM hooks)

- `import NovagramSceneLifecycle`.
- `application(_:configurationForConnecting:options:)` returns a `UISceneConfiguration` with
  `delegateClass = NovagramSceneDelegate.self` (also keeps the class linked into the binary).
- `ApplicationStatusBarHost` keeps a weak `window` and reads `window.windowScene` when asked,
  instead of storing `window.windowScene` at launch: with scenes that value is still nil inside
  `didFinishLaunching`, because the scene connects afterwards.

### `submodules/TelegramUI/BUILD` (UPSTREAM hook)

`//submodules/Novagram/SceneLifecycle:NovagramSceneLifecycle` dep.

### `submodules/UIKitRuntimeUtils/Source/UIKitRuntimeUtils/UIViewController+Navigation.m` (UPSTREAM hook)

`-[UIApplication internalGetKeyboard]`: on iOS 27+ it no longer calls the private
`+[UIRemoteKeyboardWindow remoteKeyboardWindowForScreen:create:]`. With the iOS 27 SDK that call
traps (SIGTRAP, "is a private method") the first time `Window1` asks the status bar host for the
keyboard window during launch. It now looks for a scene window whose class name ends in
`RemoteKeyboardWindow` and returns nil if there is none (callers already handle nil). iOS 26 and
older keep the old path.

### `publish.sh`, `release.sh`

The release Bazel command gained the same Swift 6.4 flags as `run.sh`
(`--@build_bazel_rules_swift//swift:copt=-no-warnings-as-errors` and `exec_copt`).

Verified: iOS 27.0 simulator (launch, login screens) and iOS 26.5 simulator (launch, chat list,
`tg://` deep link, background → foreground, typing in a chat). iOS 15–18 simulators can't run on
this macOS, so those versions need a real device.

On an upstream pull: if upstream adopts the scene life cycle itself, drop this module and the
AppDelegate hooks in favour of theirs, but keep the `internalGetKeyboard` guard unless upstream
has its own.

## 📌 2026-10-13 — Hardcoded user-visible strings moved into NovagramL10n

Two hooks in Telegram-owned files and two Novagram screens had text that was fixed in one language
(Uzbek, or English for the QR hint and the Analytics screen), so the English and Russian app showed it in the wrong language.
All of it now comes from `NovagramL10n` (`en`, `uz`, `ru`, `zh`; `uz` of the QR hint keeps the English
sentence it always showed; the Analytics texts gained an Uzbek wording, they were English in every language).

| Where | What changed |
| --- | --- |
| `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` (hook #: mic button long-press sheet, `sttButtonLongPressed`) | `let l10n = NovagramL10n(presentationInterfaceState.strings)`; the sheet's six literals («Til», «Ovozli tarjima», «…: BOR/YO'Q», the «Yuborishda so'rov» note, «Tarjima tili: …») and the `XATO:` error prefix use `stt_sheet_*` keys. |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` (QR overlay, #114) | The hint under the QR code uses `NovagramL10n(self.strings).auth_qrLoginHint`. |
| `submodules/Novagram/BotTokenLogin` (Novagram-owned) | Title, notice, «Kirish» button and the paste chip use `auth_botLogin*` keys; `BUILD` gained the `NovagramLocalization` dep. |
| `submodules/Novagram/Analytics` (Novagram-owned) | Subtitle, the two stat captions and the two info alerts use `analytics_*` keys; `BUILD` gained the `NovagramLocalization` dep. |

Keys added to `Localization/Sources/NovagramL10n.swift`: `auth_qrLoginHint`, `auth_botLoginTitle`,
`auth_botLoginNotice`, `auth_botLoginProceed`, `auth_botLoginPaste`, `stt_sheet_languageHeader`,
`stt_sheet_translateHeader`, `stt_sheet_translateOn`, `stt_sheet_translateOff`,
`stt_sheet_translateBlocked`, `stt_sheet_translateLanguage(_:)`, `stt_sheet_errorPrefix`, `analytics_subtitle`,
`analytics_usersCaption`, `analytics_accountsCaption`, `analytics_usersInfo`, `analytics_accountsInfo`.

Left in English on purpose (the app's own Russian «About» text names them in English): the profile menu
entries «View First message» and «Novagram Info», and the splash button «Start Messaging» (it activates
English; on a Russian device the splash offers «Продолжить на русском»).

On an upstream pull: these edits are single-line replacements inside the hooks above; re-apply them from this table.

---

## 📌 CarPlay Communication entitlement + Siri intents — 2026-10-20

Apple granted Novagram (`uz.fenixuz.app`) **CarPlay Communication** in October 2026 (portal App ID page
`UNVDR8NLC7`); **Siri** was switched on for the same App ID on 2026-10-20. The regenerated "Novagram AppStore"
and "Novagram" profiles carry `com.apple.developer.carplay-communication` and `com.apple.developer.siri`.
CarPlay shows Novagram on the dashboard, Siri reads messages (`INSearchForMessagesIntent`) and sends replies
(`INSendMessageIntent`), and notifications reach CarPlay through upstream's `.carPlay` /
`.allowInCarPlay` options in `AppDelegate.swift`.

**1. `Telegram/BUILD` ~line 502 — the CarPlay key.** Upstream emits Telegram's legacy
`com.apple.developer.carplay-messaging` (deprecated in iOS 14) for `official_bundle_ids` only:

```python
official_carplay_fragment = """
<key>com.apple.developer.carplay-messaging</key>
<true/>
"""
carplay_fragment = official_carplay_fragment if telegram_bundle_id in official_bundle_ids else ""
```

**Novagram hook — swap the key and add our App Store bundle:**

```python
# Novagram: Novagram holds the iOS 14+ CarPlay Communication entitlement, not Telegram's older
# carplay-messaging. The simulator bundle gets the same key so CarPlay tests match the App Store build.
official_carplay_fragment = """
<key>com.apple.developer.carplay-communication</key>
<true/>
"""
carplay_fragment = official_carplay_fragment if (telegram_bundle_id in official_bundle_ids or telegram_bundle_id == "uz.fenixuz.app") else ""
```

- Never put `carplay-messaging` back: our profiles do not have it, and rules_apple fails a device build that claims it.
- rules_apple does **not** check `carplay-communication` against the profile, so losing this hook breaks no build;
  CarPlay just disappears from the next release. `publish.sh` warns when the signed IPA lacks the key or Siri.
- `official_bundle_ids` itself stays untouched (it also gates associated domains and unrestricted VoIP).

**2. `Telegram/BUILD` `IntentsInfoPlist` — `IntentsSupported` is upstream's list again (not a hook).** The 12.8
merge (`cee1a8940d`, 2026-07-06) dropped `INStartAudioCallIntent`, `INSearchForMessagesIntent`,
`INSetMessageAttributeIntent` and `INSearchCallHistoryIntent`, while their handlers stayed in
`Telegram/SiriIntents/IntentHandler.swift` and the "r"/"gr" notification categories kept pointing Siri at
`INSearchForMessagesIntent`. Without it Siri cannot read messages in CarPlay. On a pull, keep upstream's list.

**3. `build-system/appstore-configuration.json` (local, gitignored) — `"enable_siri": true`.** It adds
`com.apple.developer.siri` and `APP_CONFIG_IS_SIRI_ENABLED`; the upstream permission flow then asks every
user once for Siri access. A profile without Siri fails the device build. `run.sh` writes `"enable_siri": true`
into newly created `my-config.json` and `my-device-config.json`, so simulator and device builds match.

**4. `AppIntentVocabulary.plist` (en, ru, uz):** example phrases for `INSearchForMessagesIntent`, and Uzbek
`INSendMessageIntent` examples in `uz` (it used to be an English copy).

**5. CarPlay template scene (`submodules/Novagram/CarPlay`, module `NovagramCarPlay`) — 2026-10-20.**
With `carplay-communication` CarPlay opens Novagram as a *template* app: a tap creates a
`CPTemplateApplicationScene` hosted by `com.apple.CarPlayTemplateUIHost`. Upstream's
`configurationForConnecting` gives no delegate to roles other than `.windowApplication`, so UIKit
threw and the app died on every tap (iPhone log, 2026-10-20):

```
Novagram[917]: *** Terminating app due to uncaught exception 'NSGenericException', reason:
'Application does not implement CarPlay template application lifecycle methods in its scene delegate.'
CarPlayTemplateUIHost: [app<uz.fenixuz.app>:917] Process exited: SIGABRT
```

Telegram's own build does not hit this: its legacy `carplay-messaging` grant gets the system Siri
UI instead of a template scene. The module draws a `CPListTemplate` of recent chats as
`CPMessageListItem`s (`conversationIdentifier` = `"\(peerId.toInt64())"`, the format the Siri
extension already uses), plus a `CPMessageComposeBarButton`. Rows have no tap handler: CarPlay
hands the chat to Siri (read flow when unread, reply flow otherwise). The list scans the newest
50 chats in phone order, puts unmuted chats first and muted ones in a "Muted" section after them
(groups posting every minute had pushed private chats and bots off the short list), and keeps
only private chats and groups: broadcast channels
cannot be answered and crowded personal chats out (a test account's list was all muted job
channels). Never Saved Messages, vault-hidden or chat-locked chats, and nothing at all while the
app passcode is locked.

`submodules/TelegramUI/Sources/AppDelegate.swift` — three additions:

```swift
import NovagramCarPlay
```

```swift
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneDelegate.self
        }
        // Novagram: the CarPlay template scene gets its delegate (submodules/Novagram/CarPlay).
        NovagramCarPlaySupport.configure(configuration, for: connectingSceneSession)
        return configuration
```

```swift
        // Novagram CarPlay — the CarPlay scene lists the active account's chats.
        _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            NovagramCarPlaySupport.start(sharedContext: sharedApplicationContext.sharedContext)
        })
```

(`configure` touches only `.carTemplateApplication`; external displays still get no delegate, as
upstream intends.) `submodules/TelegramUI/BUILD` gains `"//submodules/Novagram/CarPlay:NovagramCarPlay"`.

**6. `Telegram/SiriIntents/IntentHandler.swift` + `IntentMessages.swift` — a picked chat is read directly.**
A row picked in CarPlay arrives as `INSearchForMessagesIntent.conversationIdentifiers`. Upstream
ignored it, and its "read my messages" scan also skips muted chats and looks at the newest 20 only,
so picking a muted group in CarPlay read nothing. `IntentMessages.swift` gains (before the raw-store
`unreadMessages(postbox:)`):

```swift
/// Novagram: the unread messages of the chats CarPlay's conversation list hands to Siri. ...
func unreadMessages(account: Account, peerIds: [PeerId]) -> Signal<[INMessage], NoError>
```

It takes each chat's `CombinedPeerReadState`, reads its newest 10 messages through the same settled
history view as the scan, and keeps the unread ones (newest first). In `handle(intent:)`, just before
the `castError` at the end of the `mapToSignal`:

```swift
                // Novagram: a chat picked in CarPlay's conversation list is read directly, even when
                // muted or outside the chats the scan above looks at.
                let conversationPeerIds = (intent.conversationIdentifiers ?? []).compactMap { Int64($0) }.map { PeerId($0) }
                if !conversationPeerIds.isEmpty {
                    Logger.shared.log("SiriIntents", "INSearchForMessagesIntent conversationIdentifiers: \(conversationPeerIds)")
                }
                return (conversationPeerIds.isEmpty ? messages : unreadMessages(account: account, peerIds: conversationPeerIds))
                |> castError(IntentHandlingError.self)
```

Without identifiers (Siri on the phone, announce) nothing changes.

---

## 📌 Video call speaker button and earpiece fix — 2026-10-20

**Report:** in video calls the speaker button disappears, and the sound sometimes plays from the
earpiece with no way to switch it. All files below were identical to upstream 13.0 before this
change.

**1. The button.** Upstream design: `PrivateCallScreen` puts flip camera in the speaker's slot
whenever the local camera is on (`activeLocalVideoSource != nil`). And even with a speaker
button, `CallControllerNodeV2.setupAudioOutputForVideoIfNeeded` forces `.speaker` every second
during video, so an earpiece the user picked was reverted at once.

**2. The earpiece (root cause in `SharedCallAudioContext`).** A video call records `.speaker` as
its output at construction, before the route follows. The session's route report that arrives
while the speaker default is pending is skipped (`acceptReportedAudioOutput` drops `.builtin`).
When the speaker override then does not take effect, the session sends no new report: it keeps
reporting the earpiece while the context believes in the speaker. The call screen asks for the
speaker every second, and `setCurrentAudioOutput` dropped every request:
`guard self.currentAudioOutputValue != output`. Reproduced by
`NovagramSpeakerReapplyTests.testSpeakerRequestIsReappliedWhileTheSessionStillReportsTheEarpiece`
(on the old code: 3 applied modes instead of 4, "the speaker request was dropped").

Note: on the CallKit path the override is not lost while CallKit's session is inactive.
`CallKitProviderDelegate.applyVoiceChatOutputMode` keeps a `pendingVoiceChatOutputMode` and
applies it in `provider(_:didActivate:)`.

**Hooks:**

`submodules/TelegramCallsUI/Sources/SharedCallAudioContext.swift`. After
`private var didSetCurrentAudioOutputValue: Bool = false`:

```swift
    // Novagram: the route the session itself last reported (see setCurrentAudioOutput, HOOKS.md).
    private var sessionReportedAudioOutput: AudioSessionOutput?
```

In the `availableOutputsChanged:` closure, after `self.audioOutputStateValue = (availableOutputs, currentOutput)`:

```swift
                self.sessionReportedAudioOutput = currentOutput
```

In `setCurrentAudioOutput(_:)`, the guard (was `guard self.currentAudioOutputValue != output else {`):

```swift
        // Novagram: still apply while the session reports another route, or video calls stay on the earpiece (HOOKS.md).
        guard self.currentAudioOutputValue != output || (self.sessionReportedAudioOutput.map({ $0 != output }) ?? false) else {
```

Only real session reports set the property. The optimistic value that `setCurrentAudioOutput`
publishes (and the stale state it re-publishes after 1 s) never does. So the second-by-second
request keeps reaching the session until it actually reports the speaker, and stops once it does
(`testSpeakerRequestIsNotReappliedOnceTheSessionReportsTheSpeaker`).

`submodules/TelegramCallsUI/Sources/CallControllerNodeV2.swift`. After `private var audioOutputCheckTimer: Foundation.Timer?`:

```swift
    // Novagram: the output the user picked during this call (HOOKS.md).
    private var userChosenAudioOutput: AudioSessionOutput?
```

Before `private func setupAudioOutputForVideoIfNeeded() {`:

```swift
    func noteAudioOutputChosenByUser(_ output: AudioSessionOutput) {
        self.userChosenAudioOutput = output
    }
```

In `setupAudioOutputForVideoIfNeeded`, the `default:` case of the output switch:

```swift
            default:
                // Novagram: an earpiece the user picked during the video call stays (HOOKS.md).
                if self.userChosenAudioOutput == nil || self.userChosenAudioOutput == .speaker {
                    self.setCurrentAudioOutput?(.speaker)
                }
```

`submodules/TelegramCallsUI/Sources/CallController.swift`. In `beginAudioOuputSelection`, before
both `call.setCurrentAudioOutput(output)` calls (the two-output toggle and the action sheet item):

```swift
                        (strongSelf.controllerNode as? CallControllerNodeV2)?.noteAudioOutputChosenByUser(output) // Novagram (HOOKS.md)
```

(the sheet uses `self?.controllerNode`). The cast keeps `CallControllerNodeProtocol` and the
legacy node untouched.

`submodules/TelegramUI/Components/Calls/CallScreen/Sources/PrivateCallScreen.swift`. The
`if self.activeLocalVideoSource != nil { flipCamera } else { speaker }` pair became:

```swift
        if self.activeLocalVideoSource != nil {
            buttons.insert(... .flipCamera ..., at: 0)
        }
        // Novagram: video calls keep the speaker button, right after flip camera (HOOKS.md).
        do {
            buttons.insert(ButtonGroupView.Button(content: .speaker(audioOutput: params.state.audioOutput), ...), at: self.activeLocalVideoSource != nil ? 1 : 0)
        }
```

Video row: flip, speaker, video, mute, end. Audio calls are unchanged.

`submodules/TelegramUI/Components/Calls/CallScreen/Sources/Components/ButtonGroupView.swift`.
`let buttonSpacing: CGFloat = 36.0` became:

```swift
        // Novagram: a fifth button (speaker in video calls) narrows the spacing to fit the width (HOOKS.md).
        let buttonSpacing: CGFloat = buttons.count > 4 ? max(8.0, min(36.0, floor((size.width - 32.0 - buttonSize * CGFloat(buttons.count)) / CGFloat(buttons.count - 1)))) : 36.0
```

Four buttons keep upstream's 36pt. Five give 22pt at 402pt, 15pt at 375pt and 8pt at 320pt.

**Tests:** `submodules/TelegramCallsUI/Tests/NovagramSpeakerReapplyTests.swift` (new file; the BUILD's
`Tests/**/*.swift` glob picks it up). It carries its own copies of the fake session and control,
which are private to upstream's `SharedCallAudioContextTests.swift`. Run with
`bazel test //submodules/TelegramCallsUI:TelegramCallsUITests` and run.sh's simulator flags.

**Upstream pull:** if upstream changes `setCurrentAudioOutput`'s guard or the button pair, re-apply
the intent: never drop a speaker request while the session reports another route, and keep the
speaker button in video calls.

## 📌 QR login: Novagram logo in the QR center — 2026-10-23

**Report:** on Android the "Log in by QR code" screen shows the Novagram logo in the center of the
QR code; on iOS the code was plain, and the Uzbek hint under it was the English sentence.

**Hooks** (`submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift`,
index #241; `NovagramBrand` was already in `AuthorizationUI/BUILD` deps):

1. Imports, after `import NovagramLocalization`: `import NovagramBrand`.
2. `refreshQrToken()`, `.displayToken` case, the `qrCode(...)` call (was `icon: .none`):

```swift
                // Novagram: Novagram logo in the center; "Q" error correction covers the cleared modules (HOOKS.md #241).
                _ = (qrCode(string: urlString, color: .black, backgroundColor: .white, icon: NovagramQrLogo.image.flatMap { .custom($0) } ?? .none, ecl: "Q")
```

3. Same closure, the `generate(...)` call: `imageSize` / `boundingSize` 200 → 240 (the overlay's
   `qrSize` in `applyQrOverlayLayout`), so the image is not upscaled 1.2x into the 240pt node.

**Novagram side:** `submodules/Novagram/Brand/Sources/NovagramQrLogo.swift` draws the app icon
(`novagram_logo`, the intro-screen asset in the main bundle) as a blue circle with a transparent ring.
`qrCode(... icon: .custom)` clears the center modules (`qrCodeCutout`, about 26% of the width) and
fits the image into exactly that square, so the ring is the white margin between logo and modules.
Do not enlarge the logo past the cutout. `ecl: "Q"` is what Telegram uses for its own cutout QR codes
(`ChatQrCodeScreen`); a login URL then fits version 6, which has no alignment pattern in the center.
If the asset fails to load the code falls back to `.none` (no empty hole).
`NovagramL10n.auth_qrLoginHint` is now three steps (en/uz/ru/zh), the same wording as Novagram Android.

**Upstream pull:** if upstream changes the `qrCode(...)` call in `refreshQrToken()`, keep its new
arguments and put back `icon:` and `ecl: "Q"` from step 2 and the 240pt size from step 3.

## 📌 Hidden admin screen: Settings row + long-press entry — 2026-10-23

A private SwiftUI screen (prebuilt static xcframeworks) opened from a hidden Settings row. The row is not in
the list by default. Holding "Novagram Settings" for 20 s TOGGLES it (success haptic both ways, no visual hint, the
row's normal tap does not run): when hidden, the hold first asks for the admin login through the existing
`NovagramAdsAdminAuth` prompt (the same PBKDF2 gate as "Remove all ads", reached via the public wrapper
`NovagramAdsAdminGate.requestAccess`) and shows the row only on success; when shown, the hold hides it with no
password. The state is persisted in UserDefaults (`fenix_insights_row_revealed`); visibility = iOS 16+ AND that
flag (a stored session no longer auto-shows the row, otherwise hiding could not work while signed in).
macOS mirrors this in `NovagramChannelStatsEntry.registerSettingsRowClick(window:)`. All fork code lives in
`submodules/Novagram/ChannelStats/` (`NovagramChannelStats`).

### `submodules/Novagram/ChannelStats/` (NOVAGRAM module, new)

- `Frameworks/NovagramInsights.xcframework`, `Frameworks/NovagramInsightsUI.xcframework`: static, iOS device +
  simulator slices only. `NovagramAds.xcframework` stays in `submodules/Novagram/Sponsored/Frameworks/` (the
  same static build serves ad serving and this screen; `NovagramAdsSDK` is visible to this package).
- `BUILD`: `apple_static_xcframework_import` x2. The UI one sets `weak_sdk_frameworks = ["Charts", "SwiftUI", "CoreTransferable", "_PhotosUI_SwiftUI", "TipKit", "Symbols", "_LocationEssentials", "DataDetection", "DeveloperToolsSupport"]`:
  the app minimum is iOS 15 and these exist only from iOS 16 or later (the new screens use `PhotosPicker`, Charts and TipKit; the rest is
  autolinked by the newer SwiftUI module interfaces). Do NOT add `UIUtilities`, `LightweightCodeRequirements` or `SwiftUICore`: the first two
  are missing from the simulator SDK and the third cannot be linked directly (`ld` errors out); autolinking them only warns and leaves no
  load command. Check after every SDK bump, for the simulator AND the device build, that `otool -l` of `Novagram` and `TelegramUIFramework`
  shows these as `LC_LOAD_WEAK_DYLIB` and that no `LC_LOAD_DYLIB` names a framework newer than iOS 15
  (`otool -l <binary> | grep -A2 LC_LOAD_WEAK_DYLIB`).
- `Sources/NovagramChannelStatsEntry.swift`: builds `InsightsConfiguration(environment:keychainKey:language:onClose:)` from the build's environment; row visibility (the persisted flag, thread-safe), the
  `refreshing(_:)` signal wrapper, the toggle action `revealAction(context:authorize:)` (`authorize` is the admin prompt,
  injected by the caller so this package needs no NovagramMessenger dependency) and `present(context:)` (full-screen modal over
  the top view controller, the screen's close callback dismisses it).
- `Sources/NovagramHiddenLongPress.swift`: a `UILongPressGestureRecognizer` helper for rows.

### `submodules/Novagram/Sponsored/novagram_environment.bzl`, `BUILD`, `run.sh`, `release.sh`, `publish.sh`

- `.bzl`: one rule, `novagram_environment_source(enum_name = …)`, generates `NovagramSponsoredGeneratedEnvironment` (ads) and
  `NovagramChannelStatsGeneratedEnvironment` (this package) from the same single `--define=novagramAdsEnvironment`.
- Scripts: the define is passed only when `NOVAGRAM_ADS_ENVIRONMENT` (git-ignored `build-system/local-secrets.sh`) is set.
  Empty or unset means production.
- `NovagramAds/BUILD`: `NovagramAdsSDK` visibility lists `//submodules/Novagram/ChannelStats:__pkg__`.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/` (UPSTREAM hooks)

- `BUILD`: dep `//submodules/Novagram/ChannelStats:NovagramChannelStats`.
- `Sources/PeerInfoSettingsItems.swift`: `import NovagramChannelStats`; the "Novagram Settings" item (id 0) passes
  `longPressDuration:` / `longPressAction: NovagramChannelStatsEntry.revealAction(context:authorize: NovagramAdsAdminGate.requestAccess)`; after the Analytics item (id 1) a `if NovagramChannelStatsEntry.isRowVisible(context:)`
  block appends the "Ads Analytics" item (id 3, `megaphone.fill` icon, `NovagramSettingsSectionStrings.adsAnalyticsRowTitle`);
  since 2026-10-27 the Developer switch "Novagram ads panel" (`NovagramDeveloperFlags.isAdsPanelEnabled`, iOS 16+) shows it too.
- `Sources/PeerInfoScreen.swift`: `import NovagramChannelStats`; the settings data signal is wrapped as
  `NovagramChannelStatsEntry.refreshing(peerInfoScreenSettingsData(...))` so the list rebuilds when the row flips.
- `Sources/ListItems/PeerInfoScreenDisclosureItem.swift`: optional `longPressDuration` / `longPressAction`
  init parameters (defaults: off), forwarded with `self.selectionNode.setLongPress(...)`.
- `Sources/ListItems/PeerInfoScreenSelectableBackgroundNode.swift`: `setLongPress(duration:action:)` attaches a
  `NovagramHiddenLongPress` to the row's button, only for rows that ask for it.

**Upstream pull:** if the Settings list, the disclosure item or the selection node change, re-apply the intent:
an optional long press on one row, a rebuild of the list when the hidden row flips, and the extra row.

- **Video banner click opens t.me in-app** (`GalleryUI/Sources/Items/UniversalVideoGalleryItem.swift`, our `clickIfOurs` closure): `forceExternal: !isTelegramMeLink(url), dismiss: isTelegramMeLink(url)` (+ `import UrlHandling`). Telegram's own banners open external sites; ours promote t.me channels/bots, which must open inside the app with the player dismissed.

## 📌 Fenixuz → Novagram rename — 2026-10-27

**Why:** the brand is Novagram for good (~300K users), so the internal names from the old fork
(`Fenixuz`, `Fenix`, `ProMessager`) were renamed to Novagram in one mechanical pass. No behaviour
changed. Every hook below already uses the new names: `import NovagramX`, `// Novagram:` markers,
`//submodules/Novagram/...` labels.

**Renamed:**
- `submodules/Fenixuz/` → `submodules/Novagram/`; `FenixuzX` / `FenixX` targets, files and types → `NovagramX`.
- `ProMessager/` → `Messenger/`, `FenixuzProMessager` → `NovagramMessenger` (`proMessager` → `novagramMessenger`).
- `NovagramAds/` (our layer over the Ads SDK) → `Sponsored/`, `FenixNovagramAds` → `NovagramSponsored`
  (Telegram style, as in `SponsoredMessage`; `NovagramAds` is the SDK's module name).
- `Insights/` (our layer over the Insights SDK) → `ChannelStats/`, `FenixInsights` → `NovagramChannelStats`.
- Name clashes picked by hand: `FenixCarPlay` → `NovagramCarPlaySupport`, `FenixRoundVideoFromGallery` →
  `NovagramRoundVideoFromGalleryFlow`, the private `FenixChatLockStrings` / `FenixAdsStrings` in the settings
  controller → `NovagramSettingsChatLockStrings` / `NovagramSettingsAdsStrings`.
- `TelegramCore/Sources/Fenixuz/` → `TelegramCore/Sources/Novagram/`; app icon catalog `ProMessager.xcassets` →
  `NovagramAppIcon.xcassets`; `fenix_logo` → `novagram_logo`; `Contact List/FenixGhost*` → `NovagramGhost*`.
- About screen header: "WHAT IS NOVAGRAMPRO" → "WHAT IS NOVAGRAM" (uz/ru/zh too).
- SDK binaries keep their names: `NovagramAds`, `NovagramInsights`, `NovagramInsightsUI`, `NovagramServices`.

**NEVER renamed — values stored on devices, at Apple or on this Mac** (renaming one wipes users' settings
or chat PINs, counts devices twice in statistics, or breaks App Store updates):
- bundle ids `uz.fenixuz.app` and `uz.fenixuz.app.*` extensions, App Group and Keychain groups, entitlements;
- Keychain services `uz.fenixuz.app.ChatLock`, `uz.fenixuz.app.Analytics` and their accounts (`__fenix_master__`, `__fenix_vault__`, `fenixuz_chatlock_fb_*`);
- the `pro_messager` / `pro_messager_translation` UserDefaults suites and every `fenix_*` / `fenixuz_*` key,
  `uz.fenixuz.app.*` defaults keys, `Fenixuz.ContactsConsent.v1`;
- `uz.fenixuz.theme` (theme file type), `fenixuz.unreadReminder` (scheduled notification id), the push payload key `fenixuz_blank`;
- the Postbox preference key `0x46656E78426F7431` ("FenxBot1");
- provisioning profile files `Fenixuz*.mobileprovision` that `run.sh` / `publish.sh` / `release.sh` copy;
- `https://fenixuz.uz/...` links.

**Not shipped:** `Telegram/Telegram-iOS/Novagram{Gradient,Green,Yellow}Icon.alticon` are not in
`alternate_icon_folders` in `Telegram/BUILD`, so they were never part of the app; they were only renamed.

**Upstream pull:** nothing changes in the procedure; look hooks up by their new names.

## 📌 Developer section: 20 s hold on the Settings version line — 2026-10-27

The hidden Novagram Settings section that held "Remove all ads" is now the **Developer** section with three
switches: "Remove all ads" (`fenix_show_ads`, inverted, read through `NovagramShowAdsGate`), "Show currency
rates" (`novagram_currency_rates_view`) and "Novagram ads panel" (`novagram_ads_panel`). The two new ones are
off by default, per device, and read through `NovagramDeveloperFlags` (`isCurrencyRatesViewEnabled`,
`isAdsPanelEnabled`, live `…Signal`s on `.novagramDeveloperFlagsChanged`). The rows have no deep link.

"Show currency rates" adds a "Currency rates" row under Analytics in the Settings tab (id 4). It opens
`NovagramCurrencyRatesController` (new module `submodules/Novagram/CurrencyRates/`, pushed on the root navigation
controller). The page hosts the services SDK's SwiftUI converter in a `UIHostingController`: `CurrencyCalculatorView`
(the bar button opens `MultiCurrencyView` in a second controller). Rates come from the SDK core
(`currencyRates.latest()`, cached by the SDK for the day); the theme is mapped to `ServicesUITheme`, every text is
ours (`NovagramCurrencyRatesStrings`, uz/ru/en/zh), and the views' state is kept in `pro_messager`
(`novagram_currency_converter_state` JSON, `novagram_currency_favorites`). For this, `submodules/Novagram/Services/`
moved to SDK 1.2.0 and gained `NovagramServicesUI.xcframework` (`NovagramServicesUISDK`, visible to CurrencyRates
only); both are iOS-only copies of the SDK's `-static` builds and passed `generate-secrets.sh --scan` (0 hits).
SwiftUI stays a weak load (checked with `otool -l`).

"Novagram ads panel" shows the "Ads Analytics" row (id 3, the Insights ads panel) in the Settings tab on iOS 16+,
in addition to the hidden 20 s hold on "Novagram Settings" (`PeerInfoSettingsItems.swift`:
`NovagramChannelStatsEntry.isRowVisible(context:) || NovagramDeveloperFlags.isAdsPanelEnabled`). The Settings data
signal is wrapped in `NovagramDeveloperFlags.refreshing`, which watches both the currency rates and the ads panel
switch, so the rows come and go live.

The old trigger (10 taps anywhere on the Novagram Settings page, `NovagramAdsRevealGestureRecognizer`) is
removed. Holding the version line at the bottom of the Settings tab for 20 s now toggles the section: when
hidden, the developer login prompt (`NovagramAdsAdminAuth`, the same PBKDF2 credentials, now titled
"Developer verification") must succeed first; when shown, the hold hides it with no password. A success
haptic and an alert follow both ways. The reveal flag keeps its stored key `fenix_ads_section_revealed`, so a
section revealed before stays revealed. All logic is in `NovagramMessenger/NovagramDeveloperSection.swift`.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/` (UPSTREAM hooks)

- `Sources/PeerInfoSettingsItems.swift` (#224): the version item is built into `novagramVersionItem`, then
  `novagramLongPressDuration = NovagramDeveloperSection.revealDuration` and
  `novagramLongPressAction = NovagramDeveloperSection.revealAction(context: context)` are set before it is appended.
- `Sources/ListItems/PeerInfoScreenCommentItem.swift` (#242): `import NovagramChannelStats`; the two `var`s on the
  item (default off, so no init change); in the node a `novagramLongPress: NovagramHiddenLongPress?` created in
  `update(...)` only for an item that asks for it. `recognizesSimultaneously: true` is required: the node's own
  `TapLongTapOrDoubleTapGestureRecognizer` ends after 0.3 s of holding and would otherwise make the 20 s press fail.

- `Sources/PeerInfoSettingsItems.swift` (#243): `import NovagramCurrencyRates`; after the Analytics item (id 1), an
  `if NovagramDeveloperFlags.isCurrencyRatesViewEnabled` block appends the currency rates item (id 4,
  `dollarsign.circle.fill`, green) whose action is `NovagramCurrencyRatesEntry.open(context: context)`.
- `Sources/PeerInfoScreen.swift` (#244): `import NovagramMessenger`; the settings data signal is
  `NovagramDeveloperFlags.refreshing(NovagramChannelStatsEntry.refreshing(peerInfoScreenSettingsData(...)))`.
- `BUILD` (#208): dep `//submodules/Novagram/CurrencyRates:NovagramCurrencyRates`.

**Upstream pull:** if the comment item or the Settings list change, re-apply the intent: an optional, simultaneous
long press on one comment line, the version line asking for it, the currency row under Analytics, and the list
rebuilding when its switch flips.

## 📌 Analytics page on the services SDK's StatisticsCard — 2026-10-27

**Why:** the Analytics page is drawn by the services SDK's UI module (`NovagramServicesUI.StatisticsCard`), so the
iOS and Mac apps share one layout. Kept (user, 2026-10-27): the card matches the old page 1:1. The counts come
from the SDK core.

- `Analytics/Sources/NovagramAnalyticsController.swift`: the AsyncDisplayKit page (`NovagramAnalyticsControllerNode`,
  `StatChipNode`) is replaced by a `UIHostingController` with `StatisticsCard`. The app still owns the data
  (`NovagramAnalyticsManager.shared.counts()` → `StatisticsCounts`), the texts (`NovagramL10n` analytics_*), the
  explanation alerts (`onInfo`), the title and the glass back button. The card's `header` is the BroadcastGroup duck
  (`DuckStickerView`, same rlottie renderer and silhouette shadow as before), 140 pt. Layout as before: 28 pt under
  the bar, 16 pt sides, at most 480 pt wide. Theme: the same `ServicesUITheme(PresentationTheme)` mapping as the
  currency rates page.
- `Analytics/BUILD`: deps `//submodules/TelegramStringFormatting:TelegramStringFormatting` (`localeWithStrings`) and
  `//submodules/Novagram/Services:NovagramServicesUISDK`.
- `Services/BUILD`: `NovagramServicesUISDK` visible to `//submodules/Novagram/Analytics:__pkg__`.

**Upstream pull:** nothing upstream is touched.

