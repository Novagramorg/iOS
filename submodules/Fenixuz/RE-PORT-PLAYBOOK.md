# RE-PORT PLAYBOOK — Fenixuz iOS fork upstream'ga moslash bo'yicha qo'llanma

> Sana: **2026-06-12**
> Loyiha: `Telegram-iOS/` (Fenixuz fork) — Swift / UIKit / Bazel
> Repo root: `/Users/codingtech/Documents/Telegram/Telegram-iOS`
> Bu hujjat **git-tracked emas** (faqat `README.md` tracked). Shaxsiy ish qo'llanmasi.

Bu playbook bitta savolga javob beradi: **"upstream Telegram-iOS yangilandi — biz nima qilamiz?"**
Qisqa javob: **deyarli hech nima.** Quyida nega va qachon harakat qilishimiz batafsil yozilgan.

---

## 0. Tezkor faktlar (verified, 2026-06-12)

| Narsa | Qiymat |
|---|---|
| Upstream remote | `upstream = https://github.com/TelegramMessenger/Telegram-iOS.git` |
| Bizning fork remote | `origin = https://github.com/Fenix-Uz/iOS.git` |
| Bizning app versiyamiz | **12.7.4** |
| Upstream `master` versiyasi | **12.8** |
| 12.7 version-bump commit (anchor) | `c64653ed37` |
| 12.8 version-bump commit (anchor) | `64190e2c34` |
| `merge-base` (umumiy ajdod) | **2019-yildan** (juda eski) |
| Upstream tarix holati | **SQUASH / force-push** qiladi (history rewrite) |
| Fork modullari | `submodules/Fenixuz/<Module>/` — **14 modul, ~7000 qator, YANGI fayllar** |
| Hook'lar soni | ~30-40 ta, hammasi **IN-TREE** (tracked) fayllarda |
| Hook'lar git submodule'da bormi? | **YO'Q.** Git submodule'lar faqat C++ deps (`tgcalls`, `webrtc`, `dav1d`, `rlottie`, `td`) — biz ularni hook qilmaymiz |
| Hook ro'yxati | `submodules/Fenixuz/HOOKS.md` |
| Anchor token ro'yxati (grep tekshiruvi uchun) | `submodules/Fenixuz/HOOK_INVENTORY.md` |

**Muhim natija:** hook'lar oddiy tracked fayllarda joylashgani uchun ular **rebase/patch qilinadigan** (rebaseable). Submodule ichida bo'lganida og'riq ko'p bo'lardi — lekin unday emas. Bu bizning foydamizga.

---

## 1. Falsafa — qachon va nega re-port qilamiz

### 1.1. Asosiy qoida: feature uchun QUVMAYMIZ

Biz upstream Telegram-iOS'ning har bir yangi feature'ini ko'chirib o'tirmaymiz. Sabab oddiy:

- Bizning fork **App Store / Mac App Store review compliance** uchun mavjud (demo-login + IAP gate). U **xususiyat poygasi** (feature race) uchun emas.
- Har bir re-port — bu xavf: hook sinishi, demo-login buzilishi, IAP gate yo'qolishi. Har bir keraksiz re-port = Apple rejection ehtimoli.
- Upstream juda tez-tez force-push qiladi. Uning orqasidan har kuni yugurish — **vaqtni behuda sarflash** (YAGNI).

### 1.2. Re-port FAQAT quyidagilar MAJBUR qilganda

Re-port (yoki version bump) **faqat** quyidagi uchta sabab bo'lganda boshlanadi:

1. **API-layer deprecation** — `TelegramCore` / MTProto layer'i o'zgargan, eski API endi ishlamaydi, build sinmoqda yoki server javob bermayapti.
2. **Security** — upstream'da xavfsizlik teshigi yopilgan (CVE, MTProto fix, crypto patch) — biz ham olishimiz shart.
3. **OS-compat** — yangi iOS versiyasi chiqdi (mas: iOS 27), eski kod unda ishlamayapti yoki Apple yangi SDK majbur qilmoqda.

Agar sabab bu uchtadan biri **emas** bo'lsa (shunchaki "upstream'da chiroyli yangi sticker UI bor") — **re-port qilMAYMIZ.**

### 1.3. git = engine, qo'lda emas

Re-port qo'lda fayl ko'chirish **emas**. git bizning engine'imiz:

- "Nima o'zgargan" ni **`git diff`** topadi, ko'z bilan emas.
- Delta'ni **`git apply` / 3-way merge** qo'llaydi, copy-paste emas.
- Holatni **`git tag` / backup branch** saqlaydi, "esimda" emas.

Qo'lda ko'chirish = xato. git = haqiqat manbai.

---

## 2. Ish maydoni (workspace) — qanday tashkil qilamiz

Re-port'dan oldin ikkita alohida narsa kerak: (a) bizning fork (working repo), (b) toza upstream nusxasi (o'qish/diff uchun). Bizning ishchi repo'ga upstream'ni aralashtirib yubormaymiz.

### 2.1. Bizning fork (working repo) — allaqachon mavjud

```bash
# Bizning ishchi repo (hech qachon buni "toza upstream" sifatida ishlatma):
cd /Users/codingtech/Documents/Telegram/Telegram-iOS
git status                      # toza bo'lishi kerak ish boshlashdan oldin
git remote -v                   # origin = Fenix-Uz/iOS, upstream = TelegramMessenger
```

### 2.2. Upstream nusxasini olish — ikki variant

**Variant A — mavjud repo'ga upstream'ni fetch qilish (disk tejaydi):**

```bash
cd /Users/codingtech/Documents/Telegram/Telegram-iOS
git fetch upstream --tags       # upstream/master va teglarni oladi, working tree'ga tegmaydi
git log --oneline upstream/master -5   # nima kelganini ko'rish
```

> `git fetch` working tree'ni **o'zgartirmaydi** — faqat remote-tracking ref'larni yangilaydi. Bu xavfsiz.

**Variant B — alohida temp clone (toza maydon, tavsiya etiladi katta ish uchun):**

```bash
# Official upstream'ni butunlay alohida papkaga klonlash — bizning fork'ga tegmaydi:
git clone --depth 50 https://github.com/TelegramMessenger/Telegram-iOS.git /tmp/tg-upstream
cd /tmp/tg-upstream
git log --oneline -5
# ... diff/o'qish shu yerda. Ish tugagach: rm -rf /tmp/tg-upstream
```

> Temp clone `/tmp/` da bo'lgani uchun adashib bizning kodimizni buzib qo'ymaymiz. Bu eng xavfsiz "o'qish maydoni".

**Qadamlar (ikkala variant uchun umumiy):**

1. Ish boshlashdan oldin bizning fork `git status` toza ekaniga ishonch hosil qil.
2. **Checkpoint yarat** (3-bo'lim ⬇️ — `git tag` + backup branch). Bu MAJBURIY.
3. Upstream'ni fetch yoki temp clone qil.
4. "Nima o'zgargan" ni top (5-bo'lim... aslida 3-bo'lim ⬇️).
5. Rejim tanla (A yoki B — 4-bo'lim ⬇️).
6. Delta qo'lla, hook'larni himoya qil, har qadamdan keyin `verify-hooks.sh`.
7. Real qurilmada 2 ta Apple tekshiruvi (6-bo'lim ⬇️).

---

## 3. "NIMA o'zgargan" ni topish — `git log` vs `git diff`

Bu eng muhim bo'lim. Ikki buyruqni **aralashtirib yubormaslik** kerak — ularning vazifasi tubdan boshqacha.

### 3.1. `git log` = O'QISH uchun (insight, qaror qabul qilish)

`git log` bilan **nima o'zgarganini tushunamiz**, lekin undan kod KO'CHIRMAYMIZ:

```bash
# Versiyalararo nima sodir bo'lganini o'qish (commit xabarlar, mavzular):
git fetch upstream --tags
git log --oneline c64653ed37..64190e2c34          # 12.7 -> 12.8 oralig'idagi commitlar
git log --oneline --stat c64653ed37..64190e2c34   # qaysi fayllar tegilgan
git log -p -- submodules/TelegramCore/Sources/    # API-layer o'zgarishlarini o'qish
```

Bu bosqichda biz **qaror qabul qilamiz**: re-port kerakmi (1.2 sabablari bormi)? Agar ha — qaysi fayllar?

### 3.2. `git diff <ver>..<ver>` = KO'CHIRISH uchun (delta engine)

`git diff` bilan ikki nuqta orasidagi **aniq delta**ni olamiz va uni qo'llaymiz. Bu bizning asosiy quroli:

```bash
# Ikki version-bump nuqtasi orasidagi to'liq delta:
git diff c64653ed37..64190e2c34                                  # hammasi
git diff c64653ed37..64190e2c34 -- submodules/TelegramCore/      # faqat core layer
git diff c64653ed37..64190e2c34 -- <aniq/fayl/yoli.swift>        # bitta fayl deltasi
git diff c64653ed37..64190e2c34 -- <fayl> > /tmp/one-file.patch  # patch sifatida saqlash
```

### 3.3. NEGA per-commit `cherry-pick` EMAS

> ⚠️ **`git cherry-pick` va `git merge upstream/master` bu yerda ISHLAMAYDI.**

Sabablar (verified):

- `merge-base` 2019-yildan — bizning fork bilan upstream **~29k commit** ajragan.
- Upstream **history'ni qayta yozadi** (squash + force-push). Hatto upstream'da `safety-checkpoint-before-history-rewrite-20260511-1646` degan teg bor.
- Tarix qayta yozilgani uchun commit SHA'lar **bir xil emas** — `cherry-pick <sha>` divergence'dan o'tib ketolmaydi, ulkan konflikt beradi.
- `git merge upstream/master` = ~29k commit + ommaviy konflikt. **Hech qachon qilma.**

**To'g'ri yondashuv:** version-bump **nuqtalari** orasida `git diff` ol (state-to-state), uni patch sifatida qo'lla. Bu commit tarixiga emas, **ikki holat orasidagi farqqa** tayanadi — shuning uchun history rewrite unga ta'sir qilmaydi.

```bash
# To'g'ri pattern (state-to-state, NOT per-commit):
git diff <oldbump>..<newbump> -- <kerakli/fayllar> > /tmp/upstream-delta.patch
# keyin 3-way bilan qo'llash (4-bo'limda batafsil):
git apply --3way /tmp/upstream-delta.patch
```

---

## 4. Ikki rejim — qaysi birini tanlash

Re-port'ning ikki xil ssenariysi bor. To'g'ri rejimni tanlang.

### REJIM A — Selective feature grab (upstream → biz, tanlab)

**Qachon:** kichik, aniq bir narsa kerak (mas: `TelegramCore`'dagi bitta API fix, bitta security patch). To'liq version bump shart emas.

**Yo'nalish:** upstream → biz (faqat tanlangan fayl/qator).

**Qadamlar:**

```bash
# 1. Checkpoint (3-bo'lim majburiy bosqichi quyida).
# 2. Kerakli fayl deltasini ol:
git fetch upstream --tags
git diff c64653ed37..64190e2c34 -- submodules/TelegramCore/Sources/Foo.swift > /tmp/grab.patch

# 3. O'qib chiq — bu delta bizning hook'larga tegadimi?
less /tmp/grab.patch
git grep -n "Fenixuz" -- submodules/TelegramCore/Sources/Foo.swift   # hook bormi shu faylda?

# 4. 3-way merge bilan qo'lla (ko'r-ko'rona overwrite EMAS):
git apply --3way /tmp/grab.patch
#   -> konflikt bo'lsa: qo'lda hal qil, bizning Fenixuz qatorlarini SAQLA.

# 5. Verify:
bash submodules/Fenixuz/scripts/verify-hooks.sh

# 6. Build + real device test (6-bo'lim).
```

> Rejim A kichik va xavfsiz. Ko'pchilik holatlar shu rejim bilan yopiladi. KISS.

### REJIM B — Full version bump (biz → yangi upstream baza + fenix delta)

**Qachon:** API-layer / OS-compat **butun tree'ni** majbur qilganda (mas: 12.7.4 → 12.8 ko'chish, yangi iOS SDK). Bu og'ir operatsiya — faqat 1.2 sabablari haqiqatan majbur qilganda.

**Yo'nalish:** biz → yangi upstream baza ustiga bizning **fenix delta**ni qaytadan o'rnatamiz.

**Tamoyil:** bizning fork = `toza upstream baza` + `fenix delta`. Version bump'da bazani yangilaymiz, delta'ni ustiga qaytaramiz.

```bash
# 1. Checkpoint MAJBURIY (3-bo'lim).
# 2. Bizning fenix delta'ni AJRATIB OL (yangi baza ustiga qaytarish uchun):
bash submodules/Fenixuz/scripts/extract-fenix-delta.sh c64653ed37
#   -> /tmp/fenix-delta.patch yaratiladi:
#      (a) submodules/Fenixuz/ — bizning YANGI fayllarimiz (hech qachon konflikt bermaydi)
#      (b) hooked fayllar uchun sof fork delta'si (git diff <base>..HEAD -- <hooked file>)

# 3. Yangi upstream bazaga o't (alohida branch):
git fetch upstream --tags
git checkout -b report/12.8-bump 64190e2c34   # yangi version-bump nuqtasidan boshlanadi

# 4. Fenix delta'ni yangi baza ustiga qo'lla (3-way):
git apply --3way /tmp/fenix-delta.patch
#   -> submodules/Fenixuz/* toza tushadi (yangi fayllar).
#   -> hooked fayllarda konflikt bo'lishi mumkin -> qo'lda 3-way hal qil.
#      Fenixuz qatorlarini SAQLA, upstream'ning yangi mantiqini ustiga moslab joyла.

# 5. Har bir hooked fayl uchun verify:
bash submodules/Fenixuz/scripts/verify-hooks.sh
#   -> MISSING chiqsa: o'sha hook qo'llanmagan, qaytadan joyla.

# 6. Bazel BUILD fayllarini yangila (yangi modullar/deps bo'lsa).
# 7. To'liq build: ./run.sh   (yoki ./run.sh -r --prod release-mode reproduksiya uchun)
# 8. Real device: 2 ta Apple tekshiruvi (6-bo'lim) — MAJBURIY.
# 9. Hammasi yashil bo'lsa: main'ga merge taklif qil (push EMAS, ruxsatsiz).
```

> Rejim B og'ir va kam uchraydi. Uni faqat layer majbur qilganda boshlang. Aks holda Rejim A yetarli.

---

## 5. HOOK himoyasi — eng nozik qism

Hook = bizning fork upstream faylga qo'ygan o'zgarish (mas: `AuthorizationSequenceCodeEntryController.swift` ichidagi `fenixuzHideNextOption(true)` chaqiruvi). Re-port paytida hook'lar oson yo'qoladi. Himoya qoidalari:

### 5.1. Hech qachon ko'r-ko'rona overwrite qilma

```bash
# ❌ NOTO'G'RI — upstream faylni butunlay ustiga yozish bizning hookni o'ldiradi:
#    cp /tmp/tg-upstream/.../AuthorizationSequenceCodeEntryController.swift submodules/AuthorizationUI/...

# ✅ TO'G'RI — har doim 3-way merge, konfliktni qo'lda hal qil:
git apply --3way /tmp/grab.patch
```

> Eslatma (global CLAUDE.md): o'qimagan faylni `Write` bilan ustiga yozish — taqiqlangan. Avval `Read`, keyin `Edit`/3-way.

### 5.2. Har qadamdan keyin `verify-hooks.sh`

Har bir patch qo'llagandan **keyin darhol**:

```bash
bash submodules/Fenixuz/scripts/verify-hooks.sh
```

Bu skript Apple-critical anchor token'larni (`FenixuzDemoCodeFetcher`, `fenixuzHideNextOption`, `FenixuzAppStoreIAP`, `FenixuzBrandColors`, `FenixuzAppleReview`) grep qiladi va **bittasi yo'qolsa exit non-zero** beradi. To'liq anchor ro'yxati: `HOOK_INVENTORY.md`.

### 5.3. Apple-critical hook'larga alohida e'tibor

Ikki hook guruhi — **buzilsa, Apple bizni darhol rad etadi**:

1. **Demo-login** (`FenixuzDemoCodeFetcher`, `FenixuzAppleReview`, `fenixuzHideNextOption`):
   - `submodules/Fenixuz/AppleReview/Sources/FenixuzDemoCodeFetcher.swift` (canonical, ~325 qator, v3).
   - Hook'lar: PhoneEntry "Next" da `prewarmIfDemo()`, CodeEntry `viewDidAppear` da `autoFillIfDemo()`.
   - v3 parametrlari (`pollInterval=500ms`, `perRequestTimeout=15s`, `hardTimeout=60s`) — **O'ZGARTIRMA**.

2. **IAP gate** (`FenixuzAppStoreIAP`):
   - `submodules/Fenixuz/AppStoreIAP/Sources/FenixuzAppStoreIAP.swift`.
   - Hook'lar: `ChatController.swift`, `OpenResolvedUrl.swift`, `WebAppController.swift`, `InAppPurchaseManager.swift` `buyProduct(...)`.
   - Apple guideline 3.1.1 fix. Bypass qilinsa — **re-reject kafolatlangan**.

Re-port paytida upstream bu fayllarni qayta tuzgan bo'lsa, hook'ni o'chirmasdan **yangi mantiq ustiga qayta joylang**. `HOOKS.md` har bir hook'ning aniq joyini ko'rsatadi.

### 5.4. Silent-removal check (global protokol bilan mos)

Agar 3-way merge bizning >3 qator Fenixuz kodini o'chirib tashlasa — **STOP.** O'sha kod qanday user-visible xatti-harakat beradi? Agar demo-login yoki IAP gate bo'lsa — uni hech qachon o'chirma, qayta joyla.

---

## 6. Majburiy 2 ta Apple tekshiruvi — har re-port'da, REAL qurilmada

Build muvaffaqiyatli tugashi **tekshiruv emas.** Har bir re-port'dan keyin **real iPhone'da** (simulyator emas — demo-login tarmoqqa chiqadi) quyidagi 2 ta oqim qo'lda sinaladi:

### 6.1. Demo login auto-fill

```
1. ./run.sh -r        (yoki ./run.sh -r --prod)  — real qurilmaga o'rnat
2. Login ekrani -> telefon: +998335999479 -> "Next" bos
3. KUTILGAN: kod-entry ekrani ochiladi, kod maydoni ~7-15s ichida AVTO-to'ldiriladi
4. KUTILGAN: 2FA cloud parol so'ralsa -> Xabarchi
5. ✅ TASDIQ: "Demo login avtomatik kirdi, kod qo'lda kiritilmadi."
```

Agar kod avto-to'ldirilmasa — `FenixuzDemoCodeFetcher` hook'i buzilgan. Re-port'ni davom ettirma, hook'ni tikla.

### 6.2. IAP gate (Premium/Stars tugmasi -> alert)

```
1. Premium / Stars / Gift / Business ekranini och (mas: @PremiumBot yoki Settings -> Premium)
2. "Subscribe" / "Buy" / "Send" tugmasini bos
3. KUTILGAN: to'lov OCHILMAYDI. O'rniga localized alert chiqadi (rasmiy Telegram'ga App Store deep-link)
4. ✅ TASDIQ: "IAP gate ishlayapti, to'lov oqimi bloklandi, alert chiqdi."
```

Agar to'lov ekrani ochilsa (`BotCheckoutController` ko'rinsa) — IAP gate hook'i buzilgan. Apple 3.1.1 bo'yicha rad etadi. Re-port'ni davom ettirma, gate'ni tikla.

> Bu ikki tekshiruv **muzokara qilinmaydi.** Har ikkalasi yashil bo'lmaguncha re-port "done" emas.

---

## 7. Checkpoint — ish boshlashdan OLDIN (majburiy)

Har qanday re-port (ayniqsa Rejim B) destructive-adjacent. Global CLAUDE.md va upstream-pull policy bo'yicha **oldindan checkpoint** shart:

```bash
cd /Users/codingtech/Documents/Telegram/Telegram-iOS

# 0. Toza holatni tasdiqla:
git status                      # toza yoki kutilgan untracked bo'lishi kerak
                                # kutilmagan .env / yarim ish ko'rinsa -> STOP, so'ra.

# 1. Pre-pull checkpoint TAG (vaqt belgisi bilan):
git tag pre-pull-checkpoint-$(date +%Y%m%d-%H%M%S)

# 2. Backup branch (joriy holatni alohida branch sifatida muzlatish):
git branch backup/pre-report-$(date +%Y%m%d-%H%M%S)

# 3. (Ixtiyoriy, lekin tavsiya) checkpoint commit, agar untracked ish bo'lsa:
git add -A && git commit -m "checkpoint before report"
```

**Tiklash (re-port noto'g'ri ketsa):**

```bash
git checkout backup/pre-report-<timestamp>     # backup branch'ga qaytish
# yoki:
git reset --hard pre-pull-checkpoint-<timestamp>   # FAQAT aniq teg bilan, ehtiyot bo'lib
```

> ⚠️ `git reset --hard` — confirmation-required (global protokol). Faqat aniq checkpoint teg bilan, va faqat o'zing yaratgan checkpoint'ga. Hech qachon target'siz `git reset --hard`.

### 7.1. Push policy

- **`git push` — ruxsatsiz YO'Q.** Local commit OK, push uchun foydalanuvchidan aniq "ha" kerak.
- `upstream` remote push **DISABLED** (`DISABLED_PUSH_TO_TELEGRAM_FORBIDDEN`) — bu ataylab. Hech qachon upstream'ga push qilma.
- Re-port tugagach: `main`'ga **merge taklif qil**, o'zing merge qilma.

---

## 8. Tezkor checklist (har re-port uchun)

- [ ] `git status` toza, kutilmagan fayl yo'q
- [ ] Re-port sababi 1.2 dagi uchtadan biri (API-deprecation / security / OS-compat)? Aks holda — re-port qilma
- [ ] Checkpoint: `pre-pull-checkpoint-*` tag + `backup/pre-report-*` branch yaratildi
- [ ] Upstream fetch yoki `/tmp/tg-upstream` temp clone
- [ ] "Nima o'zgargan": `git log` bilan o'qildi, `git diff <bump>..<bump>` bilan delta olindi (cherry-pick EMAS)
- [ ] Rejim tanlandi: A (selective) yoki B (full bump)
- [ ] Delta `git apply --3way` bilan qo'llandi (ko'r-ko'rona overwrite EMAS)
- [ ] Har patch'dan keyin `verify-hooks.sh` -> hammasi PRESENT
- [ ] Bazel `BUILD` fayllari yangilandi (yangi modul/deps bo'lsa)
- [ ] To'liq build yashil (`./run.sh`)
- [ ] REAL device: demo-login avto-fill ✅
- [ ] REAL device: IAP gate alert ✅
- [ ] `main`'ga merge taklif qilindi (push EMAS, ruxsatsiz)

---

## 9. Yordamchi skriptlar

| Skript | Vazifa |
|---|---|
| `submodules/Fenixuz/scripts/verify-hooks.sh` | Apple-critical anchor token'larni grep qiladi, PRESENT/MISSING hisobot, bittasi yo'q bo'lsa exit non-zero. To'liq ro'yxat: `HOOK_INVENTORY.md` |
| `submodules/Fenixuz/scripts/extract-fenix-delta.sh <upstream-base-ref>` | (a) `submodules/Fenixuz/` qo'shilgan yo'llar ro'yxati, (b) hooked fayllar uchun sof fork delta'si; birlashtirilgan patch'ni `/tmp/fenix-delta.patch` ga yozadi |

---

## 10. Hujjat ko'rsatkichlari

| Hujjat | Joyi | Qachon o'qish |
|---|---|---|
| Bu playbook | `submodules/Fenixuz/RE-PORT-PLAYBOOK.md` | Har re-port'dan oldin |
| Hook ro'yxati | `submodules/Fenixuz/HOOKS.md` | Hooked upstream fayl tegilganda |
| Anchor token ro'yxati | `submodules/Fenixuz/HOOK_INVENTORY.md` | `verify-hooks.sh` ni kengaytirganda |
| Demo strategiyasi | `APPLE_DEMO_STRATEGY_FOR_DESKTOP.md` | Demo-fetcher kodini tahrirlaganda |
| Loyiha CLAUDE.md | `Telegram/CLAUDE.md` | Har doim (avtomatik yuklanadi) |
