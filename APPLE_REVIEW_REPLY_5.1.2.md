# Reply — Guideline 5.1.2

**Submission:** d5a06920-6b5f-4167-b7fb-46c80b156aa8
**New build:** 1.0.0 (15)

Build 15 adds an explicit in-app consent dialog that appears **before** iOS's system Contacts prompt, on every Contacts-access path (onboarding, Contacts tab, Find Friends, Add Contact, Compose).

**Consent dialog text:**
> FenixUz will upload your phone contacts to Telegram servers so you can find friends who already use the app. Your contacts are transmitted encrypted and you can disable Contact Sync anytime in Settings → Privacy and Security → Data Settings.
> By tapping Continue, you agree to our Privacy Policy: https://fenixuz.uz/privacy.html
> [Don't Allow] [Privacy Policy] [Continue]

No contacts leave the device until the user taps **Continue**.

**What we do with uploaded contacts:** sent to Telegram cloud (operator: Telegram FZ-LLC) only to discover which contacts already use FenixUz. Vipads MCHJ does not access or store contacts.

**Privacy Policy URL:** https://fenixuz.uz/privacy.html (contact upload covered in Section 04, retention in Section 11, deletion in Section 22). Same URL set in App Store Connect.

**Disable anytime:** Settings → Privacy and Security → Data Settings → Sync Contacts off (removes all uploaded contacts).

**Test:** demo phone +998 33 599 94 79, code arrives in the in-app banner.

— Vipads MCHJ · admin@fenixuz.uz
