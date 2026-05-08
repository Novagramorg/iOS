# Real iPhone uchun Bir Marotabalik Sozlash

Bu hujjat — `./run.sh -r` ishlashi uchun bir marotabalik manual sozlash bo'yicha qo'llanma. Hammasi Apple Developer Portal'ning veb-interfeysida bajariladi (Xcode shart emas).

**Talab qilinadigan:**
- Apple Developer akkaunt: Vipads MCHJ team (Team ID `ZDBP5RSRZF`)
- Sizning iPhone 13 Pro Max UDID: `3BFC6F79-5233-5749-90A3-3D5E512DD737`
- Veb brauzer (Safari/Chrome)
- Vaqt: ~25-35 daqiqa (bir marta, faqat birinchi setup uchun)

---

## 1-qadam — Apple Developer Portal'ga login

1. https://developer.apple.com/account ga kiring
2. Yuqori-o'ngdagi team selectorda **Vipads MCHJ** ni tanlang (Team ID `ZDBP5RSRZF`)
3. Chap menu'dan **Certificates, Identifiers & Profiles** ni oching

---

## 2-qadam — App Group yaratish (1 ta)

App Group barcha extension'lar va asosiy app o'rtasida ma'lumot almashish uchun kerak.

1. Chap menu → **Identifiers**
2. Yuqori-o'ng burchakdagi turini almashtirish dropdown → **App Groups**
3. **+** tugmasini bosing
4. Description: `Fenixuz App Group`
5. Identifier: **`group.uz.fenixuz.app`** (aniq shu, hech narsa o'zgartirmang)
6. **Continue → Register**

✅ Natija: App Group ro'yxatda paydo bo'ladi.

---

## 3-qadam — Bundle ID'lar yaratish (7 ta)

Hammasi **App IDs** turida (App Groups EMAS!).

Type dropdown'ni qaytarib **App IDs** qiling.

Har bir Bundle ID uchun shu tartib:
- **+** tugmasini bosing
- **App** tipini tanlang → Continue
- Description: yuqoridan ikkinchi ustunda yozilgan ism
- Bundle ID: **Explicit** ni tanlang, qiymatini quyidagi jadvaldan oling
- Capabilities ostida **App Groups** ni belgilang
- Pastda "Edit" tugmasi paydo bo'ladi (App Groups satrida) → bosing
- `group.uz.fenixuz.app` ni belgilang → Continue → Save
- Continue → Register

| # | Description | Bundle ID (Explicit) |
|---|---|---|
| 1 | Fenixuz (main app) | `uz.fenixuz.app` |
| 2 | Fenixuz Share Extension | `uz.fenixuz.app.Share` |
| 3 | Fenixuz Notification Service | `uz.fenixuz.app.NotificationService` |
| 4 | Fenixuz Notification Content | `uz.fenixuz.app.NotificationContent` |
| 5 | Fenixuz Widget | `uz.fenixuz.app.Widget` |
| 6 | Fenixuz Siri Intents | `uz.fenixuz.app.SiriIntents` |
| 7 | Fenixuz Broadcast Upload | `uz.fenixuz.app.BroadcastUpload` |

⚠ **Eng muhim:** Har bir Bundle ID'da "App Groups" capability'ni belgilab, `group.uz.fenixuz.app`'ni tanlash. Aks holda build fail bo'ladi.

---

## 4-qadam — iPhone UDID'ni ro'yxatdan o'tkazish

1. Chap menu → **Devices**
2. **+** tugmasini bosing
3. Platform: **iOS, iPadOS, tvOS, watchOS, visionOS**
4. Device Name: `Azimjon iPhone 13 Pro Max`
5. Device ID (UDID): **`3BFC6F79-5233-5749-90A3-3D5E512DD737`**
6. Continue → Register

✅ Natija: iPhone qurilmalar ro'yxatida paydo bo'ladi.

---

## 5-qadam — Provisioning Profile yaratish (7 ta)

Chap menu → **Profiles** → **+** tugmasi.

Har bir profil uchun:
- **iOS App Development** ni tanlang → Continue
- **App ID** dropdown'dan tegishli bundle ID'ni tanlang
- Continue
- **Certificate**: "Apple Development: Azimjon Abdurasulov" (DGZS4A5M4D) ni belgilang → Continue
- **Devices**: 4-qadamda qo'shilgan iPhone'ni belgilang → Continue
- **Provisioning Profile Name**: jadvaldan oling → Generate
- **Download** tugmasini bosing — `.mobileprovision` fayli yuklanadi

| # | Bundle ID tanlash | Profile Name (yozish) | Yuklab olingan fayl |
|---|---|---|---|
| 1 | `uz.fenixuz.app` | `Fenixuz` | `Fenixuz.mobileprovision` |
| 2 | `uz.fenixuz.app.Share` | `Fenixuz Share` | `Fenixuz_Share.mobileprovision` |
| 3 | `uz.fenixuz.app.NotificationService` | `Fenixuz NotificationService` | `Fenixuz_NotificationService.mobileprovision` |
| 4 | `uz.fenixuz.app.NotificationContent` | `Fenixuz NotificationContent` | `Fenixuz_NotificationContent.mobileprovision` |
| 5 | `uz.fenixuz.app.Widget` | `Fenixuz Widget` | `Fenixuz_Widget.mobileprovision` |
| 6 | `uz.fenixuz.app.SiriIntents` | `Fenixuz SiriIntents` | `Fenixuz_SiriIntents.mobileprovision` |
| 7 | `uz.fenixuz.app.BroadcastUpload` | `Fenixuz BroadcastUpload` | `Fenixuz_BroadcastUpload.mobileprovision` |

✅ Natija: ~/Downloads/ papkasiga 7 ta `.mobileprovision` fayl yuklanadi.

---

## 6-qadam — Profillarni loyihaga ko'chirish

Terminal'dan:

```bash
cd /Users/codingtech/Documents/Telegram-iOS

# Eski (Telegram FZ-LLC) profillarni backup
mkdir -p build-input/configuration-repository/provisioning_old_telegram_fz_llc
mv build-input/configuration-repository/provisioning/*.mobileprovision \
   build-input/configuration-repository/provisioning_old_telegram_fz_llc/

# Yangi Vipads profillarni Bazel kutgan nom bilan ko'chirish
cp ~/Downloads/Fenixuz.mobileprovision                  build-input/configuration-repository/provisioning/Telegram.mobileprovision
cp ~/Downloads/Fenixuz_Share.mobileprovision            build-input/configuration-repository/provisioning/Share.mobileprovision
cp ~/Downloads/Fenixuz_NotificationService.mobileprovision build-input/configuration-repository/provisioning/NotificationService.mobileprovision
cp ~/Downloads/Fenixuz_NotificationContent.mobileprovision build-input/configuration-repository/provisioning/NotificationContent.mobileprovision
cp ~/Downloads/Fenixuz_Widget.mobileprovision           build-input/configuration-repository/provisioning/Widget.mobileprovision
cp ~/Downloads/Fenixuz_SiriIntents.mobileprovision      build-input/configuration-repository/provisioning/Intents.mobileprovision
cp ~/Downloads/Fenixuz_BroadcastUpload.mobileprovision  build-input/configuration-repository/provisioning/BroadcastUpload.mobileprovision

# Watch profillari (hozirgi build'da watch yo'q, lekin Bazel BUILD'i kutadi — placeholder)
cp ~/Downloads/Fenixuz.mobileprovision build-input/configuration-repository/provisioning/WatchApp.mobileprovision
cp ~/Downloads/Fenixuz.mobileprovision build-input/configuration-repository/provisioning/WatchExtension.mobileprovision

# Mac keychain'ga ham yangi profillar bilim olib qo'yamiz (codesign uchun)
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
cp ~/Downloads/Fenixuz*.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

ls -la build-input/configuration-repository/provisioning/
```

Natija: 9 ta `.mobileprovision` fayl yangi Vipads profillari bilan almashtirilgan.

---

## 7-qadam — Build va install

```bash
./run.sh -r
```

Bu:
1. Bazel `--ios_multi_cpus=arm64` bilan build qiladi (~5-15 daqiqa, cache holatiga qarab)
2. Provisioning profile bilan codesign qiladi
3. iPhone'ga `xcrun devicectl device install app` orqali o'rnatadi
4. Avtomat ishga tushiradi

Birinchi marta iPhone'da app ochilganda iOS sizdan **"Trust Developer"** so'raydi:
- iPhone Settings → General → VPN & Device Management → "Apple Development: Azimjon Abdurasulov"
- Trust tugmasini bosing

Keyingi safar darhol ochiladi.

---

## Tezkor xato qaytarish jadvali

| Xato xabari | Sabab | Yechim |
|---|---|---|
| `bundle_id did not match the id in the entitlements` | Eski Telegram profillari | 6-qadamni qaytaring (cp buyruqlari) |
| `No matching provisioning profile found` | Profile noto'g'ri yoki muddati o'tgan | Apple Developer Portal'da profile'ni qayta yuklab oling |
| `device not eligible` | iPhone UDID profile'da yo'q | 4-qadamda UDID register qilinganini tekshiring, profile'ni qayta yarating (5-qadam) |
| `application-identifier mismatch` | Bundle ID profillarda noto'g'ri tartibda | Har bir `.mobileprovision` fayl nomi va ichidagi bundle ID jadvalga mos kelishini tekshiring |

---

## Profillar muddati o'tganda

Apple Development profillari **1 yil** ishlaydi. Muddat o'tgach, 5-qadamni qaytaring (har bir profile uchun "Edit → Generate"). Yuklab olib, 6-qadamdagi `cp` buyruqlarini qaytadan ishga tushiring.

App Group, Bundle ID va UDID o'zgartirilmaydi — faqat profiles yangilanadi.
