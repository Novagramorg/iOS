# HOOK_INVENTORY.md — Fenixuz re-port verification index

> **Sana:** 2026-06-12
> **Manba:** `submodules/Fenixuz/HOOKS.md` dan olingan (derived).
> **Maqsad:** Bu fayl — **re-port verification index**. U Fenixuz fork tomonidan o'zgartirilgan **har bir Telegram-owned (upstream) faylni** mashina o'qiy oladigan ko'rinishda sanab beradi. Upstream tree ustiga qayta merge / re-port qilinganda, quyidagi har bir hook qayta tiklanganini (yoki saqlanib qolganini) tekshirish uchun ishlatiladi.
>
> Har bir qator: qaysi upstream faylga tegilgan, hook **name** (id), Apple uchun kritikmi, qaysi **feature** ga tegishli, **anchor** (grep token — re-port keyin shu token bilan qidiriladi), va qisqacha **desc**.

## Summary

- **Total hooks:** 46
- **Apple-critical hooks:** 18
- **Non-critical hooks:** 28

---

## 🔴 APPLE-CRITICAL hooks (BIRINCHI — eng muhim)

> **⚠️ OGOHLANTIRISH.** Quyidagi hooklar **demo-login** (Apple Review demo-account auto-fill) va **IAP 3.1.1 gate** (fiat Premium/subscription checkout bloki) bilan bog'liq. Bular har bir re-port da **byte-identical** saqlanib qolishi SHART. Agar bittasi tushib qolsa yoki o'zgartirilsa — **Apple qayta REJECT qiladi** (demo timeout yoki guideline 3.1.1). Re-port dan keyin shu jadvaldagi har bir `anchor` ni yangi tree da grep qilib mavjudligini tasdiqlang.

| File | Name | Anchor (grep token) | Purpose |
|---|---|---|---|
| `submodules/AuthorizationUI/BUILD` | `authui-fenixuz-deps` | `FenixuzAppleReview, FenixuzBrand, FenixuzLocalization` | Wire FenixuzAppleReview, FenixuzBrand, FenixuzLocalization into AuthorizationUI deps |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceSplashController.swift` | `splash-emerald-brand` | `FenixuzBrandColors.primary, fenixuzPrimary` | Replace Telegram blue with emerald-green (#10B981) on Welcome/Start Messaging screen |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift` | `codeentry-sms-autofill` | `FenixuzDemoCodeFetcher.autoFillIfDemo, FenixuzDemoCodeFetcher.isDemoPhone` | Auto-fill SMS code for demo phone via xmax.uz SMS forwarder + hide 'Didn't get the code?' option |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift` | `codeentry-demo-mode-accessor` | `fenixuzHideNextOption, fenixuzDemoMode` | Add public accessor method to hide nextOption nodes in demo mode and guard countdown overwrite |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift` | `phoneentry-prewarm-demo` | `FenixuzDemoCodeFetcher.prewarmIfDemo` | Pre-warm SMS forwarder polling on demo phone 'Next' tap (Apple Review 2026-05-15 timeout fix) |
| `submodules/DeviceAccess/BUILD` | `deviceaccess-consent-dep` | `FenixuzContactsConsent` | Wire FenixuzContactsConsent into DeviceAccess deps |
| `submodules/DeviceAccess/Sources/DeviceAccess.swift` | `contacts-consent-gate` | `FenixuzContactsConsent.gate` | Show server-upload consent dialog BEFORE iOS Contacts permission alert (Apple Review 5.1.2) |
| `submodules/TelegramUI/BUILD` | `telegramui-iap-dep` | `FenixuzAppStoreIAP` | Wire FenixuzAppStoreIAP into TelegramUI deps |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | `appdelegate-iap-flag` | `FenixuzAppStoreIAP.isAppStoreBuild` | Propagate isAppStoreBuild flag to FenixuzAppStoreIAP at launch |
| `submodules/TelegramUI/Sources/ApplicationContext.swift` | `contacts-autoinvite-deferral` | `Queue.mainQueue().after(1.0, {` | Defer post-login contacts auto-prompt 1s so it presents on stable Chats window (2026-05-19) |
| `submodules/TelegramUI/Sources/ChatController.swift` | `chatcontroller-iap-gate` | `FenixuzAppStoreIAP.shouldBlock, FenixuzAppStoreIAP.presentBlockedAlert` | Block @PremiumBot card checkout for fiat subscriptions on App Store builds (Apple 3.1.1) |
| `submodules/TelegramUI/Sources/OpenResolvedUrl.swift` | `openresolvedurl-iap-gate` | `FenixuzAppStoreIAP.shouldBlock, invoice slug` | Block slug-deep-link Premium invoice card checkout (Apple 3.1.1) |
| `submodules/WebUI/BUILD` | `webui-iap-dep` | `FenixuzAppStoreIAP` | Wire FenixuzAppStoreIAP into WebUI deps |
| `submodules/WebUI/Sources/WebAppController.swift` | `webapp-iap-gate` | `FenixuzAppStoreIAP.shouldBlock, web_app_open_invoice` | Block Web-App-initiated Premium invoice card checkout (Apple 3.1.1) |
| `submodules/InAppPurchaseManager/BUILD` | `iap-manager-rebuild` | `deps rewrite, drop StoreKit` | Rewrite BUILD deps: drop StoreKit-era modules, add FenixuzAppStoreIAP |
| `submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift` | `iap-manager-full-rewrite` | `SKPayment, SKProductsRequest, SKReceipt removed` | Full rewrite: remove StoreKit code entirely (930→145 lines), present Fenixuz IAP alert on all Subscribe/Restore/Buy |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | `appdelegate-storekit-drop` | `drop import StoreKit, AppStore.showManageSubscriptions` | Drop import StoreKit and replace Manage Subscriptions sheet with web fallback |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift` | `paymentscreen-storekit-drop` | `drop import StoreKit` | Drop now-unused import StoreKit (AppStoreTransactionPurpose is TelegramCore type) |

---

## Full hook table (BARCHA hooklar)

| File | Name | Apple? | Feature | Anchor (grep token) | Desc |
|---|---|:---:|---|---|---|
| `submodules/AuthorizationUI/BUILD` | `authui-fenixuz-deps` | 🔴 | demo-login, brand | `FenixuzAppleReview, FenixuzBrand, FenixuzLocalization` | Wire FenixuzAppleReview, FenixuzBrand, FenixuzLocalization into AuthorizationUI deps |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceSplashController.swift` | `splash-emerald-brand` | 🔴 | brand | `FenixuzBrandColors.primary, fenixuzPrimary` | Replace Telegram blue with emerald-green (#10B981) on Welcome/Start Messaging screen |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift` | `codeentry-sms-autofill` | 🔴 | demo-login | `FenixuzDemoCodeFetcher.autoFillIfDemo, FenixuzDemoCodeFetcher.isDemoPhone` | Auto-fill SMS code for demo phone via xmax.uz SMS forwarder + hide 'Didn't get the code?' option |
| `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift` | `codeentry-demo-mode-accessor` | 🔴 | demo-login | `fenixuzHideNextOption, fenixuzDemoMode` | Add public accessor method to hide nextOption nodes in demo mode and guard countdown overwrite |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` | `phoneentry-qr-button` | ⚪ | demo-login | `qrLoginButtonNode, qrLoginButtonTapped, FenixuzL10n.auth_qrLoginButton` | Surface visible 'Log in by QR code' text button on phone-entry screen (2026-06-08) |
| `submodules/AuthorizationUI/BUILD` | `authui-localization-dep` | ⚪ | demo-login | `FenixuzLocalization` | Add FenixuzLocalization dep for QR login button label (2026-06-08) |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift` | `phoneentry-prewarm-demo` | 🔴 | demo-login | `FenixuzDemoCodeFetcher.prewarmIfDemo` | Pre-warm SMS forwarder polling on demo phone 'Next' tap (Apple Review 2026-05-15 timeout fix) |
| `submodules/DeviceAccess/BUILD` | `deviceaccess-consent-dep` | 🔴 | IAP-gate | `FenixuzContactsConsent` | Wire FenixuzContactsConsent into DeviceAccess deps |
| `submodules/DeviceAccess/Sources/DeviceAccess.swift` | `contacts-consent-gate` | 🔴 | IAP-gate | `FenixuzContactsConsent.gate` | Show server-upload consent dialog BEFORE iOS Contacts permission alert (Apple Review 5.1.2) |
| `submodules/RMIntro/Sources/platform/ios/RMIntroViewController.m` | `rmintro-simulator-logo` | ⚪ | brand | `fenixLogoView, ARM64 simulator, GLKit` | Add Fenixuz logo display on ARM64 simulator (GLKit unsupported) + fix logo frame on simulator |
| `submodules/sqlcipher/BUILD` | `sqlcipher-xcode26-sdk-fix` | ⚪ | IAP-gate | `sqlite3ext.h, public_headers exclude` | Exclude sqlite3ext.h from public headers (Xcode 26.5 SDK compatibility) |
| `submodules/TelegramUI/BUILD` | `telegramui-iap-dep` | 🔴 | IAP-gate | `FenixuzAppStoreIAP` | Wire FenixuzAppStoreIAP into TelegramUI deps |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | `appdelegate-iap-flag` | 🔴 | IAP-gate | `FenixuzAppStoreIAP.isAppStoreBuild` | Propagate isAppStoreBuild flag to FenixuzAppStoreIAP at launch |
| `submodules/TelegramUI/Sources/ApplicationContext.swift` | `contacts-autoinvite-deferral` | 🔴 | IAP-gate | `Queue.mainQueue().after(1.0, {` | Defer post-login contacts auto-prompt 1s so it presents on stable Chats window (2026-05-19) |
| `submodules/TelegramUI/Sources/ChatController.swift` | `chatcontroller-iap-gate` | 🔴 | IAP-gate | `FenixuzAppStoreIAP.shouldBlock, FenixuzAppStoreIAP.presentBlockedAlert` | Block @PremiumBot card checkout for fiat subscriptions on App Store builds (Apple 3.1.1) |
| `submodules/TelegramUI/Sources/OpenResolvedUrl.swift` | `openresolvedurl-iap-gate` | 🔴 | IAP-gate | `FenixuzAppStoreIAP.shouldBlock, invoice slug` | Block slug-deep-link Premium invoice card checkout (Apple 3.1.1) |
| `submodules/WebUI/BUILD` | `webui-iap-dep` | 🔴 | IAP-gate | `FenixuzAppStoreIAP` | Wire FenixuzAppStoreIAP into WebUI deps |
| `submodules/WebUI/Sources/WebAppController.swift` | `webapp-iap-gate` | 🔴 | IAP-gate | `FenixuzAppStoreIAP.shouldBlock, web_app_open_invoice` | Block Web-App-initiated Premium invoice card checkout (Apple 3.1.1) |
| `submodules/InAppPurchaseManager/BUILD` | `iap-manager-rebuild` | 🔴 | IAP-gate | `deps rewrite, drop StoreKit` | Rewrite BUILD deps: drop StoreKit-era modules, add FenixuzAppStoreIAP |
| `submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift` | `iap-manager-full-rewrite` | 🔴 | IAP-gate | `SKPayment, SKProductsRequest, SKReceipt removed` | Full rewrite: remove StoreKit code entirely (930→145 lines), present Fenixuz IAP alert on all Subscribe/Restore/Buy |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | `appdelegate-storekit-drop` | 🔴 | IAP-gate | `drop import StoreKit, AppStore.showManageSubscriptions` | Drop import StoreKit and replace Manage Subscriptions sheet with web fallback |
| `submodules/AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift` | `paymentscreen-storekit-drop` | 🔴 | IAP-gate | `drop import StoreKit` | Drop now-unused import StoreKit (AppStoreTransactionPurpose is TelegramCore type) |
| `submodules/ChatListUI/Sources/ChatListController.swift` | `ghost-button-nav` | ⚪ | Ghost | `ghostModeButton, isGhostModeActive, FenixGhostIcon` | Ghost mode read-without-receipts nav-bar button with Fenixuz ghost icon (2026-06-04) |
| `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift` | `navbutton-icon-variants` | ⚪ | Ghost, brand | `iconTinted, iconOriginal, systemIcon cases` | Add .systemIcon / .iconTinted / .iconOriginal Content cases + icon-frame size clamp (2026-06-08) |
| `submodules/TelegramUI/Sources/TelegramRootController.swift` | `tasks-tab-hide` | ⚪ | multi-account | `tasksTabController commented out, FenixuzTasks` | Hide Vazifalar (Tasks) tab per owner request (2026-06-04) |
| `submodules/TelegramUI/BUILD` | `telegramui-tasks-hide` | ⚪ | multi-account | `FenixuzTasks commented out` | Comment out FenixuzTasks dep (Tasks tab hidden, 2026-06-04) |
| `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` | `stt-button-placement-fix` | ⚪ | STT | `sttButton, textFieldInsets.left, glass background` | Move STT button from right to left (next to attachment), fix visibility on dark wallpapers (2026-06-04/05) |
| `submodules/AccountUtils/Sources/AccountUtils.swift` | `multi-account-limit-raise` | ⚪ | multi-account | `maximumNumberOfAccounts 3→20, maximumPremiumNumberOfAccounts` | Raise account caps in three files: AccountUtils (3→20), PeerInfoScreenSettingsActions, LogoutOptionsController, DeleteAccountOptionsController (999) |
| `submodules/TelegramUI/Sources/SharedAccountContext.swift` | `multi-account-working-set` | ⚪ | multi-account | `fenixuzMaxLiveAccounts, fenixuzWorkingSet, fenixuzNameCache` | Implement working-set cap (max 5 live / up to 5 pinned accounts) with LRU eviction (Stage 2, 2026-06-05) |
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` | `accounts-all-accounts-disclosure` | ⚪ | multi-account | `FenixuzL10n.accounts_allAccounts, Barcha accountlar` | Add 'All Accounts' disclosure row in Settings (2026-06-05) |
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreen.swift` | `accounts-tab-switcher` | ⚪ | multi-account | `fenixAllAccountsValue, tabBarItemContextAction, AccountRow` | Tab-bar long-press switcher shows all logged-in accounts (live + suspended) with avatars + usernames (2026-06-08) |
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenDisclosureItem.swift` | `disclosureitem-title-color` | ⚪ | brand | `titleColor optional param` | Add optional titleColor param to PeerInfoScreenDisclosureItem (2026-06-08) |
| `submodules/TelegramUI/Sources/TelegramUIInterfaceStateContextMenus.swift` | `edited-history-gate` | ⚪ | Ghost | `editedHistoryEnabled, UserDefaults edited_history_enabled` | Gate edited-message history action on pro_messager UserDefaults flag (2026-06-08) |
| `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/BUILD` | `chattextinput-l10n-dep` | ⚪ | STT | `FenixuzLocalization` | Add FenixuzLocalization dep for camera-picker localization (2026-06-08) |
| `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` | `camera-picker-localization` | ⚪ | STT | `cameraPicker_front, cameraPicker_back, FenixuzL10n` | Localize camera-picker labels from hardcoded Uzbek to en/uz/ru (2026-06-08) |
| `submodules/TelegramUI/BUILD` | `telegramui-tips-updatecheck-deps` | ⚪ | brand | `FenixuzTips, FenixuzUpdateCheck` | Add FenixuzTips + FenixuzUpdateCheck deps (2026-06-08) |
| `submodules/TelegramUI/Sources/ApplicationContext.swift` | `tips-updatecheck-post-login` | ⚪ | brand | `FenixuzTipsScreen.shouldShowOnFirstLaunch, FenixuzUpdateChecker.checkAndPresentIfNeeded` | Show first-launch Tips screen + App Store update check post-login (deferred 1s, 2026-06-08) |
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` | `fenixuz-gold-settings-row` | ⚪ | brand | `titleColor gold, fenixuzSettingsIcon flame.fill` | Gold Fenixuz Settings row with flame icon (2026-06-08) |
| `submodules/TelegramCore/Sources/TelegramEngine/Messages/AdMessages.swift` | `ghost-mode-ad-suppression` | ⚪ | Ghost | `isFenixuzGhostModeActive, markAsSeen, markAdAction, markAdAsSeen` | Suppress ad telemetry reporting (seen/click) when Ghost mode is active (2026-06-08) |
| `submodules/ChatListUI/Sources/ChatListController.swift` | `ghost-button-icons` | ⚪ | Ghost | `FenixGhostActive, FenixGhostInactive, isGhostModeActive` | Use iconOriginal/iconTinted ghost icons (Active=purple, Inactive=grey) for Ghost button (2026-06-08) |
| `submodules/TelegramUI/Sources/SharedNotificationManager.swift` | `multi-account-notification-clear` | ⚪ | multi-account | `readClearDisposables, appliedIncomingReadMessages per-account` | Clear delivered notifications on all live accounts when read (was primary-only, 2026-06-08) |
| `submodules/TelegramUI/Sources/AppDelegate.swift` | `notification-peerId-fallback` | ⚪ | multi-account | `peerId payload fallback, NSE int64` | Add fallback peerId parsing from notification payload for NSE-written values (2026-06-08) |
| `submodules/TelegramCore/Sources/PendingMessages/EnqueueMessage.swift` | `ghost-read-on-send` | ⚪ | Ghost | `isFenixuzGhostModeActive, getTopPeerMessageIndex .Cloud` | Apply local read state + server read receipt when sending in Ghost mode (2026-06-09/11) |
| `submodules/TelegramUI/Sources/SharedWakeupManager.swift` | `pinned-accounts-always-online` | ⚪ | multi-account | `fenixuzPinnedIds, shouldBeServiceTaskMaster .always` | Keep pinned non-primary accounts live (shouldBeServiceTaskMaster = .always, 2026-06-09) |
| `submodules/TelegramCore/Sources/State/ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift` | `ghost-reaction-suppress` | ⚪ | Ghost | `isFenixuzGhostModeActive, synchronizeMarkAllUnseenReactions` | Suppress readReactions sync when Ghost is active (2026-06-09) |
| `submodules/TelegramCore/Sources/State/AccountViewTracker.swift` | `ghost-view-counter-suppress` | ⚪ | Ghost | `isFenixuzGhostModeActive, increment boolFalse/boolTrue` | Don't bump channel post view counters when Ghost is active (user still sees them, 2026-06-09) |

---

## grep tekshiruvi (re-port keyin har bir hook saqlanganini tekshirish)

Re-port (yangi upstream tree ustiga merge) dan so'ng, har bir hook hali ham mavjudligini uning `anchor` token bilan yangi tree da grep qilib tasdiqlang. Token topilsa — hook saqlangan; topilmasa — hook **tushib qolgan** va qayta qo'llanishi kerak.

```bash
# Bitta hookni tekshirish (anchor token ni shu faylda qidirish):
grep -n "FenixuzDemoCodeFetcher.autoFillIfDemo" \
  submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift

# Apple-critical IAP gate hammasini bir martada (tree bo'ylab):
grep -rn "FenixuzAppStoreIAP.shouldBlock" submodules/

# Demo-login prewarm tekshiruvi:
grep -rn "FenixuzDemoCodeFetcher.prewarmIfDemo" submodules/AuthorizationUI/

# Ghost mode core hooklar:
grep -rn "isFenixuzGhostModeActive" submodules/TelegramCore/
```

> **Tartib:** avval 🔴 APPLE-CRITICAL jadvalidagi 18 ta hookni grep qiling (bittasi ham tushmasligi shart — aks holda Apple qayta reject qiladi), keyin qolgan non-critical hooklarni.
