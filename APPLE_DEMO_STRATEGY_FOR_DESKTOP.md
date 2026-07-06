# Promt — Apple/Microsoft Store demo account strategy (Telegram Desktop fork uchun)

## Kontekst

Men Telegram-iOS fork (FenixUz) ustida ishlayman. Apple App Review uchun "demo account" muammosini hal qildim. Endi sen Telegram Desktop fork ustida ishlayapsan va Microsoft Store / Mac App Store / Snap Store review uchun shu strategiyani moslashtir.

Telegram (yoki uning fork'lari) review'ga jo'natilganda, review xodimi login qilishi kerak. Lekin:

1. Real telefon raqami berib bo'lmaydi (privacy)
2. Demo raqamiga SMS yuborish kerak, lekin Uzbekistan raqamlariga SMS Apple data center'idan kechikadi yoki kelmaydi
3. Telegram'ning ichki "fake login" mexanizmi yo'q (foreign apps'da xizmat ko'rsatishni rad etadi)
4. Reviewer 2-3 daqiqa kutib turolmaydi — kutsa, **timeout** sababli reject qiladi

## Bizning yechim (3 qatlamli)

### 1-qatlam: tashqi SMS forwarder (xmax.uz)

`xmax.uz/code.php` — bizning serverda turgan oddiy endpoint. Demo raqamga kelgan oxirgi SMS kodni JSON formatda qaytaradi:

```
GET https://xmax.uz/code.php
→ ["12345"]   yoki bo'sh
```

Backend qanday SMS oladi:
- Demo raqam (`+998335999479`) bizning Android telefonimizga qo'yilgan
- Telefonda SMS forwarder app (masalan, "SMS Forwarder" — har qanday) o'rnatilgan, kelayotgan SMS'ni `xmax.uz`'ga POST qiladi
- `code.php` shu kodni database (yoki sodda Redis/file)'da saqlaydi va GET orqali oxirgisini qaytaradi

**Sen Desktop tomonda bu backend'ga tegmaysan** — u allaqachon ishlamoqda. Sen faqat `https://xmax.uz/code.php`'ga GET so'rov yuborib kod olasan.

### 2-qatlam: client-side polling + auto-fill

Bizning iOS modulimiz (`FenixuzDemoCodeFetcher.swift`) ikki nuqtaga ulanadi:

**A. Phone Entry screen'ida `prewarmIfDemo(phoneNumber)`**
- Foydalanuvchi telefon raqamini kiritib **Next** bosgan zahoti chaqiriladi
- Agar raqam `+998335999479` bo'lsa → xmax.uz polling shu zahoti boshlanadi (background'da)
- MTProto SMS yuborish ~2-5 sekund davom etadi; shu vaqt ichida polling allaqachon ishlab turadi → CodeEntry ekran ochilganda kod ko'pincha allaqachon kelgan bo'ladi
- Demo bo'lmagan raqamlar uchun **no-op** (real foydalanuvchilarga ta'sir yo'q)

**B. Code Entry screen'ida `autoFillIfDemo(phoneNumber, presenter, applyCode)`**
- Demo raqam aniqlangach, dialog ko'rsatadi: *"Demo Mode — Fetching verification code. This usually takes 2-10 seconds."*
- Polling davom etadi (yoki prewarm'dan kelgan kodni darhol ishlatadi)
- Kod kelishi bilan dialog yopiladi va `applyCode(code)` chaqiriladi — bu Telegram'ning o'z CodeEntry input'ini to'ldiradi va auto-submit qiladi
- Dialog'da **"Cancel auto-fill"** tugmasi bor — reviewer xohlasa qo'lda kiritishi mumkin

**C. "Didn't get the code?" tugmani yashirish**
- Telegram CodeEntry'da 30s'dan keyin "Resend SMS" tugma ko'rinadi va countdown chiqadi
- Demo mode'da bu reviewer'ni chalg'itadi → biz uni hide qilamiz (`fenixuzHideNextOption(true)`)

### 3-qatlam: 2FA cloud password

Demo akkauntda 2FA yoqilgan. Cloud password: `Xabarchi` (bu Telegram'ning ikkinchi ekrandagi parol). Review notes'da yozilgan. Auto-fill faqat SMS kodni qiladi — 2FA parolni reviewer qo'lda kiritadi (yoki sen ham auto-fill qilsang bo'ladi, lekin bu Telegram core flow'iga deeper hook qo'shadi).

## Kritik o'rganilgan parametrlar (qattiq sinab topilgan)

| Parametr | Qiymat | Sabab |
|---|---|---|
| `pollInterval` | 0.5s | xmax.uz juda chidamli, 0.5s normal |
| `perRequestTimeout` | 15s | xmax.uz ~7s'da javob beradi. Past timeout (5s) — har bir request fail bo'ladi |
| `hardTimeout` | 60s | Yagona "give up" yo'li. Reviewer kutmaydi |
| Consecutive errors auto-cancel | **YO'Q** | Eski versiya 3 ta error'da cancel qilardi → reviewer bo'sh ekranda qolardi. Faqat hardTimeout |
| Stale baseline check | **YO'Q** | xmax.uz JORIY valid kodni qaytaradi (eski stale emas). "Stale" deb rad qilsak — infinite loop. Birinchi to'g'ri 4-5 raqamli kodni darhol qabul qil va submit qil. Agar eski bo'lsa, Telegram'ning o'zi `PHONE_CODE_INVALID` qaytaradi va foydalanuvchi qo'lda kiritadi (60s kutishdan yaxshi) |
| Min digit count | 4 | Telegram kodlari 5-6 raqam, lekin guard 4 |
| Max digit count | 6 | `String(digits.prefix(6))` |
| `lastSubmittedCode` guard | bor | Bir kod ikki marta submit qilinmasligi uchun |

## Hook nuqtalari (Telegram code ichida)

Telegram Desktop (tdesktop, Qt/C++) yoki Telegram-Win (yangi C#/Avalonia) qanday bo'lishidan qat'iy nazar, login flow odatda 3 ekrandan iborat:

1. **Country / Phone Number entry** — bizga `Next` tugmasi ustiga hook kerak (1-2 qator: `if (DemoMode::isDemoPhone(phone)) DemoCodeFetcher::prewarm();`)
2. **Code Entry** — bizga `viewDidAppear`/`showEvent` ustiga hook kerak: dialog'ni ochish va kod kelishi bilan code input'ga set qilish + submit chaqirish
3. **(ixtiyoriy)** "Resend SMS" / countdown UI elementlarini demo mode'da yashirish

Hook'lar maksimum 2-3 qator bo'lishi kerak. Asosiy mantiq alohida modulda yashaydi (bizning iOS'da `submodules/Fenixuz/AppleReview/`). Desktop'da bu alohida class/namespace bo'lishi mumkin: `DemoLogin::CodeFetcher`.

## Desktop'ga moslashtirishda diqqat qilish kerak narsalar

1. **HTTP client** — iOS'da `URLSession`, Desktop'da `QNetworkAccessManager` (Qt) yoki `HttpClient` (.NET) yoki `libcurl` (native C++). Async polling kerak — UI'ni bloklamasdan.

2. **Timer** — iOS'da `Timer.scheduledTimer`, Desktop'da `QTimer` yoki framework ekvivalenti. UI thread'da ishlatish.

3. **UI dialog** — iOS'da `UIAlertController`, Desktop'da `QMessageBox` (Qt) yoki `MessageBox` (Avalonia/Win). Cancel tugmasi shart.

4. **Code injection into Telegram's code input** — Telegram Desktop'da code entry odatda `Ui::InputField` (Qt) bo'ladi. `setText()` + Telegram'ning o'z submit logikasini chaqirish kerak (ko'pincha `_code->setText(code); checkCode();` shaklida).

5. **Thread safety** — barcha state mutatsiyalar bitta thread'da (asosiy GUI thread). iOS kodimda `DispatchQueue.main.async` — Desktop'da `QMetaObject::invokeMethod(this, ..., Qt::QueuedConnection)`.

6. **Idempotency** — `prewarm` bir nechta marta chaqirilishi xavfsiz bo'lishi kerak (foydalanuvchi Back bosib qaytsa).

7. **Debug logging** — `qDebug() << "[DemoLogin] ..."` formatida, `#ifdef _DEBUG` ostida.

8. **Demo phone constant** — `const QString DEMO_PHONE = "+998335999479";`. Solishtirishda faqat raqamlarni qoldirish: `phone.remove(QRegExp("\\D"))`.

## Apple/Microsoft review notes (siz reviewer'ga yuborasiz)

Demo akkaunt info'sini quyidagi shaklda yozing (har bir store uchun adaptat qiling):

```
Demo phone: +998 33 599 94 79
2FA cloud password: Xabarchi

The SMS code is auto-fetched and pre-filled by the app — you do NOT need
to receive a real SMS. After tapping "Next" on the phone entry screen,
wait 2-10 seconds; the verification code will appear automatically and
the app will sign in. A small dialog confirms the auto-fill.

If auto-fill fails for any reason, tap "Cancel auto-fill" and contact us
at admin@fenixuz.uz — we will provide a manual code within a few hours.
```

## Yodda tut

- Bu strategiya **production foydalanuvchilarga ta'sir qilmaydi** — barcha mantiq `if (isDemoPhone) { ... }` guard'i ostida. Boshqa raqamlar uchun no-op.
- Real foydalanuvchi tasodifan `+998335999479`'ni kiritsa, polling boshlanadi lekin kod kelmaydi (chunki real raqam emas), 60s timeout va manual entry. Yon-effekt minimal.
- xmax.uz endpoint'i bizning ixtiyorimizda — sen unga POST qilmaysan, faqat GET. Auth shart emas (oddiy demo helper).
- Server-side: agar xmax.uz down bo'lib qolsa, butun strategiya ishlamaydi → review fail. Backend uptime monitor o'rnat (UptimeRobot bepul versiyasi yetadi).

## Test checklist (commit'dan oldin)

- [ ] Demo bo'lmagan raqam → hech qanday dialog chiqmaydi, normal Telegram flow
- [ ] Demo raqam → Phone Entry "Next" → CodeEntry ochilganda dialog bor → 2-15s ichida kod auto-fill → login muvaffaqiyatli
- [ ] Demo raqam + xmax.uz ataylab down → 60s'da dialog "timeout" matnini ko'rsatadi → "Cancel auto-fill" tugmasi ishlaydi → manual kiritish mumkin
- [ ] Reviewer Back bosib qaytsa va yana login qilsa → state reset bo'ladi, qayta ishlaydi
- [ ] Build release mode'da debug print'lar yo'q

Kerak bo'lsa bizning iOS kodimizni reference uchun ber: `submodules/Fenixuz/AppleReview/Sources/FenixuzDemoCodeFetcher.swift` (~325 qator, hammasi bitta file'da).
