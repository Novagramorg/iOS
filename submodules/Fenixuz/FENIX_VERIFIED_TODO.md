# Fenixuz — Verified TODO Roadmap

> **Sana:** 2026-06-17 · **Manba:** kod bilan tasdiqlangan audit (eski `FENIX_FEATURES_CHECKLIST.md` / `PRO_MESSENGER_FEATURE_ANALYSIS.md` o'rnini bosadi — ular STALE edi).
>
> **Siyosat:** No-Backend (faqat Telegram native serveri) + faqat **native'da YO'Q**, bizning Fenixuz **hook** bo'la oladigan ishlar. Native allaqachon qiladigan narsalarni QAYTA qurmaymiz.
>
> **Audit xulosasi:** eski hujjat "18 missing" degan — aslida ~9 tasi allaqachon done yoki native. Faqat quyidagilar HAQIQATAN qilinishi kerak.

---

## ✅ QILISH KERAK — genuine, native-absent (bizning hook bo'la oladi)

| # | Feature | Qiymat | Effort | No-Backend yo'l (hook) |
|:-:|---|:--:|:--:|---|
| **#18** | Folder icon picker (native field bor, UI yo'q) | Med | S-M | `ChatListFilter.emoticon` allaqachon bor+synced — faqat **picker UI** kerak |
| **#45** | Join-request avto-qabul (per-channel) | Med | M | native `_internal_updateInvitationRequest(approve:)` + per-channel flag + arrival hook |
| **#19** | Default folders (first-launch) | Med | M | first-launch flag → default folder(lar) auto-create (native ChatListFilter create) |
| **#20** | Folders icon ko'rinishida | Med | M | `ChatListFilterTabContainerNode` shortTitle/emoji render bor — icon-only mode + toggle |
| **#21** | First-launch folder stil so'rovi | Low | S | #19 dan keyin: modal Icon/Text → UserDefaults |
| **#1** | Bot token login (niche) | Med | M | `importBotAuthorization` API bor (Api40), UI yo'q — AuthorizationUI'ga input + wire |
| **#44** | Budilnik/eslatma (vaqt+ovoz) | Med | L | yangi module: unread detect + time/sound UI + `UNUserNotificationCenter` local schedule |

### Per-feature plan (implementation tartibida)

**1. #18 — Folder icon picker** *(eng arzon real win)*
- Native `ChatListFilter.emoticon: String?` allaqachon mavjud va serverga sync bo'ladi (`ChatListFiltering.swift:263,290,306`).
- Yetishmaydi: folder tahrirlash ekranida (`ChatListFilterPresetController.swift`) emoticon tanlash UI qatori.
- Hook: preset controller'ga emoji-picker row qo'shish → `filter.emoticon` set. Bazel dep o'zgartirish shart emas (native field).

**2. #45 — Join-request avto-qabul**
- ProMessager Settings'da per-channel toggle (yoki kanal context menyusida).
- Native `_internal_updateInvitationRequest(approve: true)` (`InvitationLinks.swift:7`) — manual'ni avtomatga aylantirish: join-request kelish path'iga hook, flag bo'lsa auto-approve.
- UserDefaults: `fenix_autoaccept_<peerId>`.

**3. #19 → #21 → #20 — Folders cluster** *(bog'liq, bitta sprint)*
- #19: first-launch flag → default folder(lar) auto-create.
- #21: #19'dan keyin onboarding modal — Icon/Text stil tanlovi → UserDefaults `fenix_folder_style`.
- #20: `ChatListFilterTabContainerNode` da icon-only render mode (`shortTitle`/emoji bor) + stil flag'iga bog'lash.

**4. #1 — Bot token login** *(niche, oxirroq)*
- `importBotAuthorization` (`TelegramApi/.../Api40.swift`) bor, call-site yo'q.
- AuthorizationUI'ga bot-token input ekrani + `AuthorizationSequenceController` route + xato handling.

**5. #44 — Budilnik** *(eng katta, L)*
- Yangi module `submodules/Fenixuz/Alarms/`: unread detect + vaqt+ovoz picker UI + `UNUserNotificationCenter` local notification scheduling (+ background refresh).

---

## ⛔️ QURMAYMIZ — allaqachon DONE yoki NATIVE (audit dalili)

> Bularni qayta taklif qilmang — kod bilan tasdiqlangan.

| # | Eski hujjat | Haqiqat (dalil) |
|:-:|---|---|
| #4 | partial | ✅ DONE — `PeerInfoSettingsItems.swift:20` (proMessager = tepa seksiya), :242 gold "FenixuzPro" |
| #5 | missing | NATIVE — `searchRemotePeers(scope: .everywhere)` + `resolvePeerByName` (global @username) |
| #9 | missing | NATIVE — `ChatListController.swift:7236` header `proxyButton` |
| #11 | partial | core DONE — `show_deleted_messages` ishlaydi (`ChatHistoryEntriesForView.swift:168`) |
| #12 | missing | NATIVE — Telegram Passcode Lock (Settings → Privacy) |
| #14 | partial | core DONE — begona userni yashiradi (`ChatHistoryEntriesForView.swift:111`, `ChatListNodeEntries.swift:687`) |
| #17 | missing | NATIVE — suggested folders (`ChatListFeaturedFilter`, `ChatListFiltering.swift:1207`) |
| #34 | missing | ✅ DONE (2026-06-17) — heart message effect, commit `ea0b5ec` |
| #36 | missing | NATIVE — `ForwardOptionsMessageAttribute.hideNames` + "Hide Senders Name" UI |
| #43 | missing | NATIVE — view-once voice/video (`AutoremoveTimeoutMessageAttribute`, `viewOnceTimeout`) |
| #41 | — | ❌ **RAD ETILDI (2026-06-17)** — roziliksiz auto-join = **Apple xavfi (CRITICAL)** + kanal username hardcode brittle. QURILMAYDI. |

---

## ⏸ PAUSE — Backend kerak (No-Backend siyosati bilan to'xtatilgan)

| # | Feature | Sabab |
|:-:|---|---|
| #6 | Promo Kod (referral) | o'z serveri kerak |
| #7 | Analytics (yuklab olish stat) | o'z serveri kerak |
| #33 | Promo code dashboard | alohida dastur + server |

---

## 📌 Tavsiya etilgan tartib

1. **#18** Folder icon picker — arzon, native field tayyor (S-M)
2. **#45** Join-request avto-qabul (M)
3. **#19 → #21 → #20** Folders cluster (M, bitta sprint)
4. **#1** Bot token login (M, niche)
5. **#44** Budilnik (L, oxirgi)

> Har feature: implement → `./run.sh -r` (real iPhone) → test → bu faylda ✅ → `git commit`. Upstream fayl tegilsa → `HOOKS.md` (Python).
