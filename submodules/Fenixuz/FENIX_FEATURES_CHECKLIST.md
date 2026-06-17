# 📋 Fenixuz Pro Messenger — Imkoniyatlar Holati (Status Checklist)

> **Eslatma:** Bu fayl shaxsiy reja-hujjat (personal planning artifact). Upstream Telegram'ga aloqasi yo'q va git'ga track qilinmaydi.
> **Sana:** 2026-06-12
> **Yangilandi:** 2026-06-17 — #25, #42, #46, #23 done bo'ldi (#23 apply hook bugun qo'shildi). + #24 Chat ID copy, #35 auto-download disable. + #37 send-translate, #38 send-confirm (voice/sticker/gift, real iPhone'da tasdiqlandi). + #30 sticker auto-add (real iPhone'da tasdiqlandi).
> **Manba:** `Pro Messenger Imkoniyatlari.pdf` (46 ta feature, kod auditi asosida)
> **Maqsad:** Har bir feature qaysi holatda — qaysi biri tayyor, qaysi biri yarim, qaysi biri umuman yo'q — tezda ko'rish.

> 🚫 **NO BACKEND siyosati (2026-06-17):** Bu fork faqat Telegram original serveri bilan ishlaydi — o'z backend / API / to'lov tizimi yo'q. Backend talab qiladigan featurelar (#6, #7, #33) ⏸ **PAUSE**. Qolgan hamma narsa Telegram native server + lokal (SQLite/UserDefaults) bilan. **No Backend bilan qila olamiz: 17 ta.**

---

## 📊 Umumiy Progress

```
Done       ✅  25 / 46
Partial    🟡   3 / 46
Missing    ❌  17 / 46
Out-scope  ⚪️   1 / 46
```

**Bajarilgan (done):** `[█████░░░░░] 52%`

**Done + Partial (qisman ham hisobga olinsa):** `[██████░░░░] 59%`

> Hisob-kitob: 24 done + 3 partial + 18 missing + 1 out-of-scope = 46 ta. Out-of-scope (Kanal istoriyasi) upstream Telegram'da bor, shu sabab "qoldi" ro'yxatiga kirmaydi.

---

## 🏷 Legend (Belgilar)

| Belgi | Ma'nosi | Tushuntirish |
|:---:|---|---|
| ✅ | **done** | To'liq ishlaydi, kod va hook joyida |
| 🟡 | **partial** | Qisman bor — asosiy qism ishlaydi, ba'zi qismlari yetishmaydi |
| ❌ | **missing** | Umuman yo'q — kod topilmadi, noldan yozish kerak |
| ⚪️ | **out-of-scope** | Upstream Telegram'da allaqachon bor, Fenixuz qo'shmagan |

---

## 🗂 Master Jadval (Barcha 46 feature)

| # | Holat | Feature | Evidence (fayl / modul) | Qoldi (kerak bo'lgan ish) |
|:---:|:---:|---|---|---|
| 1 | ❌ | Bot token bilan login | Kod topilmadi (`submodules/Fenixuz`, `AuthorizationUI`, `HOOKS.md`) | Login ekraniga bot token kiritish maydoni + bot account session + MTProto bot auth flow |
| 2 | ✅ | QR kod bilan login | `AuthorizationSequencePhoneEntryControllerNode.swift:333-790` (qrLoginButtonNode); `HOOKS.md:125-216`; `FenixuzL10n.swift` (auth_qrLoginButton) | — |
| 3 | ✅ | 10 ta telegram account ulash | `AccountUtils.swift:13` (max=999); `HOOKS.md:786-920`; `SharedAccountContext.swift`; `FenixAccountsController.swift` | Spec'dan oshib ketgan (999). Hozir 5 live + cheksiz suspended |
| 4 | 🟡 | Settings menu asosiy oynaga ko'chirildi | `FenixSettingsController.swift` (to'liq Settings paneli); `HOOKS.md:1027-1051` | Panel asosiy tab'da emas, Telegram Settings > Fenixuz row ichida. Spec asosiy menyuni xohlaydi |
| 5 | ❌ | Chat topuvchi (username search) | Kod topilmadi (ChatFinder / SearchByUsername yo'q) | Username bo'yicha kanal/guruh/chat/bot qidirish UI + backend + natija ko'rsatish |
| 6 | ⏸ | Promo Kod (referral, 1000 so'm) | Kod topilmadi (promo / referral yo'q) | ⏸ paused — No Backend siyosati — pause |
| 7 | ⏸ | Analytics (yuklab olish statistikasi) | Kod topilmadi (analytics moduli yo'q) | ⏸ paused — No Backend siyosati — pause |
| 8 | ✅ | Ghost rejimi | `ChatListController.swift:7416` (ghostModeButton); `FenixSettingsController.swift`; `FenixuzGhostMode.swift`; `HOOKS.md:712-1300` | — |
| 9 | ❌ | Proxy tezkor tugma + long-press menu | Kod topilmadi (`.proxy` faqat NavigationButtonComponent.Content turi, feature emas — HOOKS.md:739,746,1116) | ChatListController'ga proxy tugma UI + NetworkSettings + long-press menu + default proxy ro'yxati |
| 10 | ✅ | O'zgartirilgan xabarlarni saqlash + tarix | `EditedMessageHistoryController.swift`; `ChatInterfaceStateContextMenus.swift:1184-1186`; `HOOKS.md:922-937` | — |
| 11 | 🟡 | O'chirilgan xabarlarni saqlash (3 rejim) | `ChatHistoryEntriesForView.swift:168-170` (show_deleted_messages filter); `FenixSettingsController.swift` (.deletedMessages) | Faqat oddiy show/hide. Yo'q: (1) kim o'chirgani, (2) 3-rejim tanlovi, (3) cache tozalash, (4) ikki marta o'chirish |
| 12 | ❌ | Umumiy parol (global lock) | Faqat per-chat pincode bor (`ChatPincodeManager.swift:13-40`). App-wide lock yo'q | Global-lock moduli (butun app'ni himoya qiluvchi yagona parol); AppDelegate launch integratsiyasi; pin/parol/barmoq |
| 13 | ✅ | Har bir chatga alohida parol | `ChatPincodeManager.swift`; `NavigateToChatController.swift:35,37,39` (isLocked + ChatPincodeViewController) | — |
| 14 | 🟡 | Begonalardan himoya rejimi | `ProForeignUserBlockHelper.swift`; `ChatHistoryEntriesForView.swift:111-114` (block_foreign_users) | Yo'q: (1) foreign-user xabarida edited/deleted history auto-enable, (2) haqiqiy xabar rad etish UI |
| 15 | ✅ | Storylarni yashirish rejimi | `ChatListControllerNode.swift:2403-2404` (shouldDisplayStoriesInChatListHeader); `FenixSettingsController.swift` (.showStories) | — |
| 16 | ✅ | Story-yashirish tugmasini ko'rsatish/yashirish | `FenixSettingsController.swift:48,168-169` (.showStories toggle); `ChatListControllerNode.swift:2403-2404` | — |
| 17 | ❌ | Tavsiya jildlar bo'limi | Kod topilmadi (FenixuzL10n / FenixSettingsController'da tavsiya yo'q); `TodoFolder` struct'da recommendation flag yo'q | Tavsiya jildlar (Admins/Personal) UI; TodoFolder'ga recommendation field; bir-tap adopt logikasi |
| 18 | ❌ | Jildga icon qo'shish/o'zgartirish | `TodoStorage.swift:5-26` (TodoFolder'da icon field yo'q); `TodoListController` icon ishlatmaydi | Icon picker UI; TodoFolder + SQLite schema'ga `icon` field; jild ro'yxatida icon render |
| 19 | ❌ | Birinchi ishga tushganda default jildlar tavsiyasi | First-launch detection yo'q (`Tasks/Sources`); UserDefaults flag yo'q | First-launch gate (SharedAccountContext/ApplicationContext); 'Personal'+'Admins' auto-create; takrorlanmaslik flag |
| 20 | ❌ | Jildlar icon ko'rinishida | Folder tab'lar faqat matn. Icon view mode yo'q (Feature 18 oldin kerak) | Feature 18'dan keyin: ChatListUI folder tab header'da icon render; text/icon view toggle |
| 21 | ❌ | First-launch jild stili (icon/text) so'rovi | First-launch jild-stili dialogi yo'q (`Tasks/`, `ApplicationContext.swift`); UserDefaults key yo'q | First-launch onboarding modal (Feature 19'dan keyin): 'Icon View' / 'Text View' tanlovi; UserDefaults'ga saqlash |
| 22 | ✅ | Kontakt sizni saqlaganini ko'rsatish | `FenixSettingsController.swift:252-254` (showMutualContactSymbol); `ContactsPeerItem.swift:788,967-972,978` (🤝 emoji) | — |
| 23 | ✅ | To'liq oq (white) rejim rangi o'zgartirildi | `FenixSettingsController.swift (FenixWhiteThemeAccent.applyToLightThemes); FenixuzBrandColors.swift (lightThemeAccentValue 0x10B981); ProMessager/BUILD (+TelegramUIPreferences)` | — (toggle-based; color picker keyin xohlansa qo'shiladi) |
| 24 | ✅ | Chat ID ko'rsatish (top-right menu) | `ChatContextMenus.swift (Copy Chat ID action — peerId.toInt64() → UIPasteboard + UndoOverlay); HOOKS.md (2026-06-17)` | — (toggle'siz, action har doim mavjud) |
| 25 | ✅ | Translate voice to chat | `SpeechToTextManager.swift:232-253 (translateHandler → engine.translate); HOOKS.md:1344` | — |
| 26 | ✅ | Text style (preset) | `FenixTextStyleController.swift` (enum FenixTextStyle, 'text_style'); `ChatControllerNode.swift:4890-4894` | — |
| 27 | ✅ | View first message | 'show_view_first_message' (`FenixSettingsController`, `PeerInfoScreenPerformButtonAction.swift`, `ChatController.swift`) | — |
| 28 | ✅ | Voice-to-text button (chat past) | `ChatTextInputPanelNode.swift:301-303, 5784-5840` (sttButton); 'stt_enabled' → SpeechToTextManager | — |
| 29 | ✅ | Round video old/orqa kamera tanlash | `ChatTextInputPanelNode.swift:925-970` (presentCameraSelection; cameraPicker_front / cameraPicker_back) | — |
| 30 | ✅ | Automatic text adder | `ChatController.swift (sticker saqlash) + ChatControllerNode.swift (matndan keyin enqueue) + FenixSettings toggle; FENIX-HOOK #30` | — |
| 31 | ✅ | Translate function default-on | `FenixTranslateController.swift` (auto_translate_enabled + auto_translate_lang); `ChatControllerNode.swift:4691-4703` | — |
| 32 | ⚪️ | Kanal istoriyasi (o'zgarishlar log) | `ChatRecentActionsController` (upstream); native 'Channel Info > Recent Actions' | Agar custom admin-log UI kerak bo'lsa, yangi Fenixuz moduli kerak (hozir yo'q) |
| 33 | ⏸ | Promo code dashboard (alohida dastur) | Kod / UI / HOOKS.md havolasi yo'q | ⏸ paused — No Backend siyosati — pause |
| 34 | ✅ | Yurakcha animatsiyasi (.heart) | ❤️ message effect (non-premium) — send path hook + toggle | Done |
| 35 | ✅ | Auto yuklab olishni boshqarish | `FenixSettingsController.swift (autoDownloadDisabled toggle → updateMediaDownloadSettingsInteractively, cellular/wifi.enabled = !value)` | — |
| 36 | ❌ | Maxsus forward (egasi ko'rinmaydi) | Forward-hiding moduli yo'q | 'special forward' state moduli + forward UI'ga hook (sender attribution'ni yashirish) |
| 37 | ✅ | Yuborishda translate (per-chat til) | `ChatControllerNode.swift (auto-translate hook + translate_confirm_enabled toggle); FENIX-HOOK #37` | — |
| 38 | ✅ | Ovoz/stiker/gift yuborishda tasdiq dialog | `ChatControllerMediaRecording.swift (voice, sendMediaRecording), ChatController.swift (sticker), ChatInterfaceStateContextMenus.swift (gift) — fenix bypass-flag; real iPhone'da tasdiqlandi` | — |
| 39 | ✅ | Jild/filter yorliqlarini yashirish | `FenixSettingsController.swift:47` (.hideFolders); `FenixuzL10n.swift:260-271`; `HOOKS.md:704`; key 'hide_folders' | — |
| 40 | ✅ | Sozlamalar uchun deep-link | `PeerInfoScreen.swift:4965` (tg://settings/{id}); `PeerInfoSettingsItems.swift:242`; context menu 'Copy Link' (4966-4989) | — |
| 41 | ❌ | Pro Messenger kanal avto-pin | Kod topilmadi (ru/uz language pin logikasi yo'q); HOOKS.md / FenixuzL10n'da yo'q | `ChannelAutoPin/` moduli: (1) ru/uz til'dan kanal aniqlash, (2) join'da auto-pin, (3) obuna bo'lsa yashirish, (4) hook |
| 42 | ✅ | Menu itemlarda haptic animatsiya | `NavigationButtonComponent.swift:107 (UIImpactFeedbackGenerator); HOOKS.md:1306` | — |
| 43 | ❌ | One-time ovoz/dumaloq video | Disappearing media kodi yo'q (ephemeral / self-destruct topilmadi) | `FenixuzDisappearingMedia` moduli + message metadata flag + input panel toggle + ko'rilgandan keyin o'chirish |
| 44 | ❌ | Bildirish/budilnik (vaqt+musiqa) | Alarm/reminder kodi yo'q (scheduled notification moduli yo'q) | `FenixuzAlarms` moduli + unread detection + vaqt+ovoz tanlash UI + background task + notification hook |
| 45 | ❌ | Kanal join-request avto-qabul | Auto-accept kodi yo'q; Settings toggle yo'q | Per-channel auto-accept moduli + ProMessager Settings toggle + channel-join-request path'ga hook (darhol approve) |
| 46 | ✅ | Secret chat + parol | `ChatPincodeManager.swift` + `ChatPincodeViewController.swift`; `NavigateToChatController.swift`; `ChatContextMenus.swift`; `ChatLockBiometricHelper.swift (LAContext Face/Touch ID); ChatPincodeManager.swift:20 (.pin/.text)` | — |

---

## 🧩 Mavzular Bo'yicha (Themed Checklists)

> GitHub task syntax — `- [x]` bajarilgan, `- [ ]` qolgan. Partial'lar `- [ ]` deb belgilangan (chunki to'liq emas).

### 🔑 Login / Account

- [ ] **#1** Bot token bilan login — ❌ missing
- [x] **#2** QR kod bilan login — ✅ done
- [x] **#3** 10 ta telegram account ulash — ✅ done (999 gacha)
- [ ] **#4** Settings menu asosiy oynaga ko'chirildi — 🟡 partial (Settings ichida, asosiy tab'da emas)
- [ ] **#5** Chat topuvchi (username search) — ❌ missing

### 👻 Ghost / Maxfiylik (Privacy)

- [x] **#8** Ghost rejimi — ✅ done
- [ ] **#12** Umumiy parol (global lock) — ❌ missing
- [ ] **#14** Begonalardan himoya rejimi — 🟡 partial
- [ ] **#36** Maxsus forward (egasi ko'rinmaydi) — ❌ missing

### 💾 Xabar Saqlash (Message Persistence)

- [x] **#10** O'zgartirilgan xabarlarni saqlash + tarix — ✅ done
- [ ] **#11** O'chirilgan xabarlarni saqlash (3 rejim) — 🟡 partial (faqat show/hide)

### 🔒 Qulflash (Locking)

- [x] **#13** Har bir chatga alohida parol — ✅ done
- [x] **#46** Secret chat + parol — ✅ done
- [ ] **#12** Umumiy parol (global lock) — ❌ missing *(Maxfiylik bilan umumiy)*

### 📁 Jildlar / Story (Folders & Stories)

- [x] **#15** Storylarni yashirish rejimi — ✅ done
- [x] **#16** Story-yashirish tugmasini ko'rsatish/yashirish — ✅ done
- [x] **#39** Jild/filter yorliqlarini yashirish — ✅ done
- [ ] **#17** Tavsiya jildlar bo'limi — ❌ missing
- [ ] **#18** Jildga icon qo'shish/o'zgartirish — ❌ missing
- [ ] **#19** Birinchi ishga tushganda default jildlar tavsiyasi — ❌ missing
- [ ] **#20** Jildlar icon ko'rinishida — ❌ missing
- [ ] **#21** First-launch jild stili (icon/text) so'rovi — ❌ missing

### 🎤 STT / Tarjima (Speech & Translate)

- [x] **#26** Text style (preset) — ✅ done
- [x] **#28** Voice-to-text button (chat past) — ✅ done
- [x] **#31** Translate function default-on — ✅ done
- [x] **#25** Translate voice to chat — ✅ done
- [x] **#30** Automatic text adder — ✅ done
- [x] **#37** Yuborishda translate (per-chat til) — ✅ done

### 💬 Chat Menu / UX

- [x] **#22** Kontakt sizni saqlaganini ko'rsatish — ✅ done
- [x] **#27** View first message — ✅ done
- [x] **#29** Round video old/orqa kamera tanlash — ✅ done
- [x] **#40** Sozlamalar uchun deep-link — ✅ done
- [x] **#24** Chat ID ko'rsatish (top-right menu) — ✅ done
- [x] **#34** Yurakcha animatsiyasi (.heart) — ✅ done (❤️ message effect, private chat, toggle)
- [x] **#38** Ovoz/stiker/gift yuborishda tasdiq dialog — ✅ done
- [x] **#42** Menu itemlarda haptic animatsiya — ✅ done
- [ ] **#43** One-time ovoz/dumaloq video — ❌ missing

### ⚙️ Sozlama / Infra (Settings & Infrastructure)

- [ ] **#9** Proxy tezkor tugma + long-press menu — ❌ missing
- [x] **#23** To'liq oq (white) rejim rangi o'zgartirildi — ✅ done
- [x] **#35** Auto yuklab olishni boshqarish — ✅ done
- [ ] **#41** Pro Messenger kanal avto-pin — ❌ missing
- [ ] **#44** Bildirish/budilnik (vaqt+musiqa) — ❌ missing
- [ ] **#45** Kanal join-request avto-qabul — ❌ missing

### 🌐 Tashqi (External / Backend)

- [ ] **#6** Promo Kod (referral, 1000 so'm) — ❌ missing ⏸ (No Backend pause)
- [ ] **#7** Analytics (yuklab olish statistikasi) — ❌ missing ⏸ (No Backend pause)
- [ ] **#33** Promo code dashboard (alohida dastur) — ❌ missing ⏸ (No Backend pause)
- [x] **#32** Kanal istoriyasi (o'zgarishlar log) — ⚪️ out-of-scope (upstream'da bor)

---

## 🔧 Qolgan Ishlar (Remaining)

> Faqat **partial 🟡** va **missing ❌** itemlar. Out-of-scope (#32) bu yerda yo'q. Aniq keyingi qadamlar bilan.

### 🟡 Partial (yarim tayyor — yakunlash kerak)

| # | Feature | Keyingi qadam |
|:---:|---|---|
| 4 | Settings menu asosiy oynaga | Panel'ni asosiy tab bar / main menu'ga chiqarish (hozir Settings > Fenixuz row ichida) |
| 11 | O'chirilgan xabarlar (3 rejim) | 3-rejim UI (hide/show/track-who); DeletedMessageAttribute'ga deleter metadata; cache clear tugma; delete-twice logika |
| 14 | Begonalardan himoya | To'liq mode UI toggle; foreign-user xabarida edited/deleted auto-enable; phonebook'da yo'q kontaktlarga send-block |

### ❌ Missing (noldan yozish kerak)

| # | Feature | Keyingi qadam (qisqacha) |
|:---:|---|---|
| 1 | Bot token bilan login | Token kiritish maydoni + bot session + MTProto bot auth flow |
| 5 | Chat topuvchi (username) | Username qidiruv UI + backend + natija ro'yxati |
| 9 | Proxy tezkor tugma | ChatListController proxy tugma + NetworkSettings + long-press menu + default ro'yxat |
| 12 | Umumiy parol (global lock) | App-wide lock moduli + AppDelegate launch + pin/parol/barmoq |
| 17 | Tavsiya jildlar | Tavsiya jildlar UI + TodoFolder recommendation field + bir-tap adopt |
| 18 | Jildga icon | Icon picker UI + TodoFolder/SQLite `icon` field + render |
| 19 | Default jildlar (first-launch) | First-launch gate + 'Personal'+'Admins' auto-create + flag |
| 20 | Jildlar icon ko'rinishida | (Feature 18'dan keyin) folder tab header'da icon render + view toggle |
| 21 | First-launch jild stili so'rovi | (Feature 19'dan keyin) onboarding modal: Icon/Text tanlovi + UserDefaults |
| 36 | Maxsus forward | 'special forward' state moduli + forward UI hook (sender yashirish) |
| 41 | Kanal avto-pin | `ChannelAutoPin/` moduli (til aniqlash + join'da pin + obuna'da yashirish + hook) |
| 43 | One-time ovoz/video | `FenixuzDisappearingMedia` + metadata flag + input toggle + ko'rilgach o'chirish |
| 44 | Bildirish/budilnik | `FenixuzAlarms` + unread detect + vaqt+ovoz UI + background task + notification hook |
| 45 | Join-request avto-qabul | Per-channel auto-accept moduli + Settings toggle + join-request path hook |

### ⏸ Backend (PAUSED)

> No Backend siyosati (2026-06-17) — bu featurelar backend / API / to'lov tizimi talab qiladi, fork esa faqat Telegram original serveri bilan ishlaydi. Siyosat o'zgarmaguncha to'xtatilgan. Missing umumiy soni ichida sanaladi.

| # | Feature | Nega pause |
|:---:|---|---|
| 6 | Promo Kod (1000 so'm) | ⏸ PAUSED — No Backend (referral tracking + to'lov backend kerak) |
| 7 | Analytics | ⏸ PAUSED — No Backend (usage metrics backend + dashboard kerak) |
| 33 | Promo code dashboard | ⏸ PAUSED — No Backend (alohida backend app + API kerak) |

---

## 📌 Xulosa (Quick Reference)

| Holat | Soni | Foiz |
|---|:---:|:---:|
| ✅ Done | 24 | 52% |
| 🟡 Partial | 3 | 7% |
| ❌ Missing | 18 | 39% |
| ⚪️ Out-of-scope | 1 | 2% |
| **Jami** | **46** | **100%** |

> ⏸ Backend paused: 3 (#6, #7, #33) · 🛠 No Backend bilan qila olamiz: 18

> **Eng yaqin yutuqlar (low-hanging fruit):** Qolgan partial'lar (#4, #11, #14) nisbatan kichik ishlar — to'liq qilishga arzaydi.
> **Eng katta bloklar:** #6, #7, #33 (promo/analytics/dashboard) — backend + tashqi infra talab qiladi, faqat iOS bilan yopilmaydi.

---

*Generated 2026-06-12 • Updated 2026-06-17 · No Backend siyosati 2026-06-17 • Pro Messenger Imkoniyatlari.pdf • Fenixuz fork (Telegram-iOS)*
