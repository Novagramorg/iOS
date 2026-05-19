# Fenixuz hooks in Telegram-owned files

This file is the **source of truth** for every line of Fenixuz code that lives outside `submodules/Fenixuz/`. Each entry describes:

1. The exact file + region that is modified
2. The hook code itself
3. Why it lives outside a Fenixuz module (i.e. cannot be expressed as pure Fenixuz code)

On every `git pull upstream master`, an AI assistant uses this file to re-apply hooks if upstream code moved. **Fenixuz hooks always win** against upstream changes; surrounding upstream code is taken as-is.

> Last verified: 2026-05-19 against upstream commit `9ed152eb6b` (Fenixuz master). 2026-05-16 added DeviceAccess contacts-consent hook for Apple Review 5.1.2 rejection fix. 2026-05-19 added ApplicationContext.swift hook to defer the silent post-login contacts auto-prompt by 1 second (initial attempt that day silenced the auto-prompt entirely; that was reverted the same day after the user reported the consent + iOS alerts never appeared — the deferred version restores both alerts while still letting the Chats tab finish its layout before the alert presents). 2026-05-19 (later same day) replaced the `InAppPurchaseManager.swift` runtime gate with a complete rewrite that removes the StoreKit code path entirely (`SKPaymentQueue`, `SKProductsRequest`, `SKPayment`, `SKReceipt*` no longer reachable); also dropped the now-unused `import StoreKit` from `AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift`, and in `TelegramUI/Sources/AppDelegate.swift` both dropped the import and replaced the iOS 15+ `AppStore.showManageSubscriptions(in:)` Manage Subscriptions sheet with the web fallback URL (no StoreKit-backed subscriptions exist on this fork so the system sheet would be empty anyway).

---

## 📌 AuthorizationUI module

### `submodules/AuthorizationUI/BUILD`

In the `deps = [...]` list, append:

```python
"//submodules/Fenixuz/AppleReview:FenixuzAppleReview",
"//submodules/Fenixuz/Brand:FenixuzBrand",
```

Reason:
- `FenixuzAppleReview` — CodeEntry controller calls it for demo-account SMS auto-fill.
- `FenixuzBrand` — Splash controller calls it for emerald-green brand colors on the intro/welcome screen.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceSplashController.swift`

**Top of file — imports block.** Add after `import RMIntro`:

```swift
import FenixuzBrand
```

**Inside `init(...)` — replace the RMIntroViewController + startButton instantiation block.** Find these lines:

```swift
self.controller = RMIntroViewController(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, buttonColor: theme.intro.startButtonColor, accentColor: theme.list.itemAccentColor, regularDotColor: theme.intro.dotColor, highlightedDotColor: theme.list.itemAccentColor, suggestedLocalizationSignal: localizationSignal)

self.startButton = SolidRoundedButtonNode(title: "Start Messaging", theme: SolidRoundedButtonTheme(theme: theme), glass: false, height: 50.0, cornerRadius: 50.0 * 0.5, isShimmering: true)
```

Replace with:

```swift
// Fenixuz: brand emerald (#10B981/#059669) Telegram blue o'rniga.
let fenixuzPrimary = FenixuzBrandColors.primary
self.controller = RMIntroViewController(backgroundColor: theme.list.plainBackgroundColor, primaryColor: theme.list.itemPrimaryTextColor, buttonColor: fenixuzPrimary, accentColor: fenixuzPrimary, regularDotColor: theme.intro.dotColor, highlightedDotColor: fenixuzPrimary, suggestedLocalizationSignal: localizationSignal)

let fenixuzButtonTheme = SolidRoundedButtonTheme(backgroundColor: fenixuzPrimary, foregroundColor: .white)
self.startButton = SolidRoundedButtonNode(title: "Start Messaging", theme: fenixuzButtonTheme, glass: false, height: 50.0, cornerRadius: 50.0 * 0.5, isShimmering: true)
```

Reason: Telegram's default theme uses blue accent everywhere. Fenixuz brand colour (`#10B981` emerald green, from https://fenixuz.uz CSS palette) must replace blue specifically on the Welcome / Start Messaging screen (the most brand-defining surface). Three call-sites of `theme.list.itemAccentColor` + the button theme are swapped.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import FenixuzAppleReview
```

**Inside `viewDidAppear(_ animated: Bool)` — after `self.controllerNode.activateInput()`:**

```swift
// Fenixuz: Apple Review demo akkount uchun SMS kodni avtomatik fetch + iOS alert
if let number = self.data?.0 {
    if FenixuzDemoCodeFetcher.isDemoPhone(number) {
        self.controllerNode.fenixuzHideNextOption(true)
    }
    FenixuzDemoCodeFetcher.autoFillIfDemo(phoneNumber: number, presenter: self) { [weak self] code in
        self?.controllerNode.updateCode(code)
        self?.continueWithCode(code)
    }
}
```

Reason: `data` (phone number tuple) and `controllerNode` are `private` — Fenixuz module cannot reach them from outside. The hook reads them and delegates to `FenixuzDemoCodeFetcher`. `continueWithCode(_:)` is also private → must be invoked from inside the class.

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift`

**Immediately after the three node declarations** (`nextOptionTitleNode`, `nextOptionButtonNode`, `nextOptionArrowNode`), add:

```swift
// Fenixuz: demo phone uchun "Didn't get the code?" tugma yashirish.
// Status matn alohida UIView banner orqali ko'rsatiladi (FenixuzAppleReview module'da)
public var fenixuzDemoMode: Bool = false
public func fenixuzHideNextOption(_ hide: Bool) {
    self.fenixuzDemoMode = hide
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
// Fenixuz: demo phone'da bizning matn ustidan yozmaymiz
if !strongSelf.fenixuzDemoMode {
    strongSelf.nextOptionTitleNode.attributedText = nextOptionText
}
```

Reason: the three nodes are `private` — only a method inside this class can flip their `isHidden`. The `fenixuzDemoMode` flag blocks Telegram's countdown disposable from overwriting our demo-status content (when we ever choose to show inline status in this node — currently disabled, banner is used instead, but the guard remains so future inline-status work is safe).

---

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import FenixuzAppleReview
```

**Inside the TWO `loginWithNumber?(strongSelf.controllerNode.currentNumber, ...)` call sites** — currently around lines 415 and 426. Each lives inside a closure (one in `confirmationController.proceed`, one in the small-layout `TextAlertAction.defaultAction`). Insert ONE LINE BEFORE each `loginWithNumber?(...)` call:

```swift
// Fenixuz: demo phone uchun xmax.uz SMS forwarder polling'ni shu paytda boshlaymiz.
FenixuzDemoCodeFetcher.prewarmIfDemo(phoneNumber: strongSelf.controllerNode.currentNumber)
```

Reason: **Apple App Store rejection 2026-05-15** — the demo phone (`+998335999479`) login was taking 240s+ in App Review because polling started only when the CodeEntry screen appeared (after MTProto round-trip), and the polling logic had a 20-attempt minimum-wait + a baseline-change requirement. Pre-warming at the PhoneEntry "Next" tap kicks off polling 2-5 seconds earlier, and combined with the simplified acceptance logic in `FenixuzDemoCodeFetcher` (drop initialFillAfter from 20→0, drop baseline gate, drop maxAttempts from 180→60), end-to-end login now completes in <15s typical.

The `prewarmIfDemo` call is a no-op for any non-demo number, so real users are unaffected.

---

## 🔄 Pull conflict workflow (manual, AI-assisted)

Whenever `git pull upstream master` is run:

1. Run a checkpoint:
   ```sh
   git tag pre-pull-checkpoint-$(date +%Y%m%d-%H%M)
   git branch backup-before-merge-$(date +%Y%m%d)
   ```
2. `git pull upstream master --no-rebase`
3. If merge conflicts surface in any of the files listed above, **do NOT auto-resolve**. Instead:
   - Open `submodules/Fenixuz/HOOKS.md` (this file)
   - For each conflicted file, locate its hook block above
   - Manually re-apply the hook at the new line position (upstream code wins for everything else; Fenixuz hook re-inserted)
   - Ask the AI assistant: *"Re-apply the Fenixuz hook for `<file>` based on HOOKS.md"*
4. Run `./run.sh` and verify a clean build before deleting checkpoint tags

**Never** merge upstream changes without re-applying hooks. If a hook is silently dropped, the consequence is silent feature-breakage (demo auto-fill stops, custom Settings panel disappears, intro screen reverts to blue, etc.).

---

## 🧱 Adding a new hook

When you must touch a Telegram-owned file for a new Fenixuz feature:

1. Put 100% of the logic into `submodules/Fenixuz/<Feature>/`
2. Keep the Telegram-side hook to 1–8 lines: an import + a single function call OR a tiny accessor method
3. **Append a new section to this file** documenting the exact hook code and reason
4. Commit the HOOKS.md update in the same commit as the hook itself

If a hook grows beyond ~10 lines, refactor: move state into a Fenixuz module and expose a single delegate-style call site.

---

## 📌 DeviceAccess module — Apple App Review 5.1.2 contacts consent

### `submodules/DeviceAccess/BUILD`

In the `deps = [...]` list, append:

```python
"//submodules/Fenixuz/ContactsConsent:FenixuzContactsConsent",
```

Reason: `DeviceAccess.swift` calls `FenixuzContactsConsent.gate(...)` inside `case .contacts:` to show our in-app consent dialog before iOS's permission alert.

---

### `submodules/DeviceAccess/Sources/DeviceAccess.swift`

**Top of file — imports block.** Add as the last `import` line:

```swift
import FenixuzContactsConsent
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
                    // Fenixuz hook: Apple App Review 5.1.2 (Privacy — Data Use and Sharing).
                    // Show explicit server-upload consent dialog BEFORE iOS permission alert.
                    // NSContactsUsageDescription alone was rejected (submission d5a06920..., 2026-05-16).
                    FenixuzContactsConsent.gate(completion: completion) {
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

Reason: **Apple App Store rejection 2026-05-16, submission `d5a06920-6b5f-4167-b7fb-46c80b156aa8`, Guideline 5.1.2** — Apple rejected the app for uploading contacts to a server without an explicit in-app consent dialog. `NSContactsUsageDescription` (Info.plist) alone is iOS's *system* permission text; Apple wants a separate Fenixuz-branded dialog that names server upload and links to the Privacy Policy BEFORE iOS shows its own alert.

`DeviceAccess.authorizeAccess(to: .contacts, ...)` is the single chokepoint that all contacts-permission requests flow through (onboarding `ApplicationContext.swift`, `ContactsController.swift` "Find Friends" tab, `ComposeController.swift`, `OpenAddContact.swift`, `SuppressContactsWarning.swift`, `TelegramPermissionsUI/PermissionController.swift`, `ContactListNode.swift`). Wrapping at this one spot covers every call site automatically.

`FenixuzContactsConsent.gate(completion:perform:)` is idempotent — it caches consent in `UserDefaults` (`Fenixuz.ContactsConsent.v1`) and silently treats users with pre-existing iOS contacts permission as already-consented (upgrade path, no nag dialog after app update). The actual upload (`ContactSyncManager` → `contacts.importContacts` API) cannot start unless iOS contacts access is granted, so blocking this single function blocks the upload.

---

## 📌 RMIntro module — simulator logo + intro layout

### `submodules/RMIntro/Sources/platform/ios/RMIntroViewController.m`

**1. `loadGL` early-return for ARM64 simulator + logo creation BEFORE the return.** GLKit is not supported on ARM64 iOS simulators (only on real devices / x86_64 sims). Without this block, the simulator crashes inside `[EAGLContext initWithAPI:]`. We also create `_fenixLogoView` here (plain UIImageView, no OpenGL needed) so the intro screen still shows the Fenixuz logo in the simulator.

Look for the start of `- (void)loadGL` and ensure this block sits at the very top of the method:

```objc
- (void)loadGL
{
#if TARGET_OS_SIMULATOR && defined(__aarch64__)
    // Fenixuz fork: simulator (ARM64) GLKit'ni qo'llab-quvvatlamaydi — OpenGL
    // animatsiya'ni o'tkazib yuboramiz, lekin Fenixuz logo'ni baribir
    // qo'shamiz (plain UIImageView, OpenGL kerak emas). Aks holda
    // simulator'da intro screen bo'sh ko'rinadi (real device'da OK).
    if (!_fenixLogoView) {
        CGFloat size = 200;
        int height = 50;
        _fenixLogoView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - size / 2, height, size, size)];
        _fenixLogoView.image = [UIImage imageNamed:@"fenix_logo"];
        _fenixLogoView.contentMode = UIViewContentModeScaleAspectFit;
        _fenixLogoView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _fenixLogoView.userInteractionEnabled = NO;
        [self.view addSubview:_fenixLogoView];
    }
    return;
#endif
    // ... rest of original loadGL body (EAGLContext + GLKView setup)
```

**2. `updateLayout` guard for nil `_glkView` on simulator.** The original code does `_fenixLogoView.frame = _glkView.frame;` unconditionally. On simulator, `_glkView` is never created (we early-return in `loadGL`), so this collapses the logo to `CGRectZero`. Plus the wrapper UIScrollView covers it. Replace the single assignment with this branch:

```objc
_glkView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
if (_glkView != nil) {
    _fenixLogoView.frame = _glkView.frame;
} else {
    // Fenixuz fork: simulator path — _glkView never created (GLKit unsupported
    // on ARM64 simulator). Position the logo where the GL sphere would be.
    CGFloat logoSize = 200.0f;
    _fenixLogoView.frame = CGRectMake(
        floor((self.view.bounds.size.width - logoSize) / 2.0f),
        glViewY - statusBarHeight,
        logoSize,
        logoSize
    );
    [self.view bringSubviewToFront:_fenixLogoView];
}
```

Reason: the simulator path is Fenixuz-specific (upstream Telegram doesn't care because they build for x86_64 sims which have GLKit). Without this hook, the Fenixuz logo is invisible on every Apple-Silicon simulator demo build.

---

## 📌 sqlcipher module — Xcode 26.5 SDK compatibility

### `submodules/sqlcipher/BUILD`

**Exclude `sqlite3ext.h` from public headers.** Apple updated `iPhoneSimulator26.5.sdk/usr/include/sqlite3ext.h` to SQLite 3.50+ (added 15+ fields to `struct sqlite3_api_routines`: `txn_state`, `changes64`, `total_changes64`, `autovacuum_pages`, `error_offset`, `vtab_rhs_value`, `vtab_distinct`, `vtab_in`, `vtab_in_first`, `vtab_in_next`, `deserialize`, `serialize`, `db_name`, `value_encoding`, `is_interrupted`, `stmt_explain`, `get_clientdata`, `set_clientdata`, ...). Sqlcipher's vendored `sqlite3ext.h` is ~3.36 era and doesn't have these fields. Clang Modules verifier rejects the build with: *"`sqlite3_api_routines::X` from module `SQLite3.Ext` is not present in definition of `struct sqlite3_api_routines` in module `sqlcipher`."*

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

Apple Submission ID `d5a06920-6b5f-4167-b7fb-46c80b156aa8` (iPad Air 11", reviewed 2026-05-18) rejected the app under 3.1.1 because the reviewer reached `BotCheckoutController` from `@PremiumBot` and could pay 269 990 UZS for an Annual Premium Subscription — i.e. a digital subscription via card, bypassing IAP. The Fenixuz fork cannot allow that path on App Store builds. We do not implement IAP for Premium ourselves (Telegram's server does not honour IAP receipts from non-official clients), so we block the fiat-card flow and direct the reviewer to the official Telegram app instead.

Detection rule lives in `FenixuzAppStoreIAP.shouldBlock(currency:hasSubscriptionPeriod:)`:
- `invoice.currency != "XTR"` (Stars stay allowed — Apple already approved them under IAP)
- `invoice.subscriptionPeriod != nil` (only recurring fiat subscriptions are blocked; one-off bot payments for physical goods continue to work)

The gate is intentionally **build-independent** (no `isAppStoreBuild` check). Reason: Telegram's server never credits Premium for non-official clients regardless of build flavour, and registering StoreKit products for `uz.fenixuz.app` would be theatre — the receipt would still fail server-side. Running the gate in dev/simulator also lets us verify the behaviour without flipping a build flag. The `isAppStoreBuild` static stays on `FenixuzAppStoreIAP` purely as a logging hint set in `AppDelegate.swift`.

UI: localized `UIAlertController` with two actions — `Open App Store` (deep-links to `itms-apps://apps.apple.com/app/id686449807`, the official Telegram listing) and `Cancel`. Strings live in `submodules/Fenixuz/Localization/Sources/FenixuzL10n.swift` under the `iap_block_*` keys (en/uz/ru).

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list of `swift_library(name = "TelegramUI", ...)`, alongside the other Fenixuz deps, append:

```python
"//submodules/Fenixuz/AppStoreIAP:FenixuzAppStoreIAP",
```

Reason: `TelegramUI` consumes `FenixuzAppStoreIAP` from three call sites (AppDelegate, ChatController, OpenResolvedUrl) — Bazel needs the dep explicitly.

---

### `submodules/TelegramUI/Sources/AppDelegate.swift`

**Imports — append after `import ContextControllerImpl`:**

```swift
import FenixuzAppStoreIAP
```

**Right after `GlobalExperimentalSettings.isAppStoreBuild = buildConfig.isAppStoreBuild` (around line 776), insert:**

```swift
// Fenixuz: Apple 3.1.1 IAP gate uses this flag to decide whether to block @PremiumBot card checkout.
FenixuzAppStoreIAP.isAppStoreBuild = buildConfig.isAppStoreBuild
```

Reason: the Fenixuz module cannot import `BuildConfig`/`GlobalExperimentalSettings` without dragging in TelegramUI's whole graph, so we mirror the flag here once at launch.

---

### `submodules/TelegramUI/Sources/DeviceContactDataManager.swift`

**Inside `DeviceContactDataManagerImpl.init(queue:accountManager:)` (around line 511), insert TWO LINES immediately after `self.accountManager = accountManager` and BEFORE `self.accessDisposable = (DeviceAccess.authorizationStatus(...)`:**

```swift
// Fenixuz: unblock the contacts-signal subscribers at init regardless of
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
import FenixuzAppStoreIAP
```

**Inside the `else if let invoice = media as? TelegramMediaInvoice {` branch (around line 3553), in the `else` clause after the `if let receiptMessageId = invoice.receiptMessageId` check (i.e. the new-checkout path, around line 3568), insert before `let inputData = Promise<BotCheckoutController.InputData?>()`:**

```swift
// Fenixuz: Apple 3.1.1 — @PremiumBot card checkout (fiat subscription) is forbidden on App Store builds.
if FenixuzAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    FenixuzAppStoreIAP.presentBlockedAlert(on: strongSelf, languageCode: strongSelf.presentationData.strings.primaryComponent.languageCode)
    return
}
```

Reason: this is the path the May 2026 reviewer used — tapping `@PremiumBot`'s invoice message would otherwise present `BotCheckoutController` modally. The `return` exits the closure passed to `engine.data.get(...).startStandalone(next:)`, which is correct (we have fully handled the message).

---

### `submodules/TelegramUI/Sources/OpenResolvedUrl.swift`

**Imports — append after `import CreateBotScreen`:**

```swift
import FenixuzAppStoreIAP
```

**Inside `case let .invoice(slug, invoice):`, in the `else` clause after the `XTR` Stars branch (around line 1425), insert before `let checkoutController = BotCheckoutController(...)`:**

```swift
// Fenixuz: Apple 3.1.1 — block fiat-card Premium subscription checkout (slug invoices, deep link).
if FenixuzAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    let presenter: UIViewController = navigationController.topViewController ?? navigationController
    FenixuzAppStoreIAP.presentBlockedAlert(on: presenter, languageCode: presentationData.strings.primaryComponent.languageCode)
    return
}
```

Reason: covers the deep-link path (`https://t.me/$slug` resolved to an invoice). `navigationController` is already unwrapped earlier in the same block. `NavigationController` extends `UINavigationController`, so `.topViewController` is the active visible screen and the right place to present a UIKit alert.

---

### `submodules/WebUI/BUILD`

In the `deps = [...]` list of `swift_library(name = "WebUI", ...)`, prepend at the top (before SwiftSignalKit):

```python
"//submodules/Fenixuz/AppStoreIAP:FenixuzAppStoreIAP",
```

Reason: `WebUI` consumes `FenixuzAppStoreIAP` from `WebAppController.swift` — Bazel needs the dep explicitly.

---

### `submodules/WebUI/Sources/WebAppController.swift`

**Imports — append after `import AlertComponent`:**

```swift
import FenixuzAppStoreIAP
```

**Inside `case "web_app_open_invoice":`, in the `else` branch after the `XTR` Stars handling (around line 1296), insert before `let checkoutController = BotCheckoutController(...)`:**

```swift
// Fenixuz: Apple 3.1.1 — block fiat-card Premium subscription checkout from inside Web Apps.
if FenixuzAppStoreIAP.shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil) {
    let presenter: UIViewController = navigationController.topViewController ?? navigationController
    FenixuzAppStoreIAP.presentBlockedAlert(on: presenter, languageCode: strongSelf.presentationData.strings.primaryComponent.languageCode)
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
    "//submodules/Fenixuz/AppStoreIAP:FenixuzAppStoreIAP",
    "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    "//submodules/TelegramCore:TelegramCore",
],
```

Reason: only three dependencies remain after the rewrite — `FenixuzAppStoreIAP` (for the blocking alert), `SwiftSignalKit` (for `Signal`), and `TelegramCore` (for `SomeTelegramEngine` and `AppStoreTransactionPurpose`). The dropped deps were StoreKit-related (transaction persistence, receipt parsing, product hashing, price-string formatting) and have no consumer now.

---

### `submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift` — full rewrite

The file used to be ~930 lines of `SKPaymentQueue` / `SKProductsRequest` / `SKPayment` / `SKReceipt` glue. After **2026-05-19** it is a ~145-line stub that:

1. Drops `import StoreKit`, `import Postbox`, `import TelegramStringFormatting`, `import TelegramUIPreferences`, `import PersistentStringHash`.
2. Imports only `Foundation`, `SwiftSignalKit`, `TelegramCore`, `FenixuzAppStoreIAP`.
3. Removes every `SKPaymentTransactionObserver` / `SKProductsRequestDelegate` conformance — `InAppPurchaseManager` is a plain `NSObject` again.
4. Removes the `SKPaymentQueue.default().add(self)` registration in `init` and the matching `remove(self)` in `deinit`. There is no longer any deinit because nothing needs cleanup.
5. Keeps the **public surface** byte-for-byte compatible for the 13 consumer modules that import this file:
   - `class InAppPurchaseManager: NSObject` with `init(engine: SomeTelegramEngine)`.
   - `class Product: Equatable` with `id`, `isSubscription`, `price`, `priceValue`, `priceCurrencyAndAmount`, `pricePerMonth`, `defaultPrice`, `multipliedPrice`. The `SKProduct`-backed init is replaced with a private no-arg init (no consumer constructs `Product` themselves; it was only ever returned by `availableProducts`). The Equatable conformance becomes identity comparison since no instance is ever produced.
   - `enum PurchaseState`, `enum PurchaseError`, `enum RestoreState` — cases unchanged.
   - `struct ReceiptPurchase` — fields unchanged; gets a public memberwise init because `PremiumIntroScreen` types arrays of this struct.
   - `var canMakePayments: Bool` — now permanently `false`.
   - `var availableProducts: Signal<[Product], NoError>` — now permanently `.single([])`.
   - `func buyProduct(_:quantity:purpose:) -> Signal<PurchaseState, PurchaseError>` — presents `FenixuzAppStoreIAP.presentBlockedAlertOnTop()` and returns `.fail(.cancelled)`.
   - `func restorePurchases(completion:)` — presents the alert and calls `completion(.failed)` on the main queue.
   - `func finishAllTransactions()` — no-op.
   - `func getReceiptPurchases() -> [ReceiptPurchase]` — returns `[]`.

Reason: **Apple App Store rejection 2026-05-18, submission `d5a06920-6b5f-4167-b7fb-46c80b156aa8`, Guideline 3.1.1.** The earlier May 2026 revision gated the StoreKit funnel at runtime with `if FenixuzAppStoreIAP.shouldBlockIAP { ... }`. That worked, but the binary still contained reachable StoreKit code — the IPA shipped `SKPaymentQueue.default().add(self)` at launch, a 700-line `SKPaymentTransactionObserver` extension, a `SKProductsRequest` lifecycle, and a `getReceiptData()` / `parseReceipt(...)` chain. App Review's static analysis can flag any of those in a future submission. This rewrite removes the StoreKit code entirely so:

- `grep -r 'import StoreKit' submodules/` returns zero hits.
- `grep -r 'SK\(Payment\|Product\|Receipt\)' submodules/` returns zero hits outside comments / docs.
- The `FenixuzAppStoreIAP` alert remains the user-facing behaviour for every Subscribe / Buy / Restore tap — same UX as before, just no StoreKit pipeline behind it.

The `Product` class is preserved as a public type only because 6 consumer files type arrays as `[InAppPurchaseManager.Product]` and the StarsPurchaseScreen / PremiumIntroScreen / etc. `combineLatest` chains type their Signals as `Signal<[InAppPurchaseManager.Product], NoError>`. Since `availableProducts` returns `[]`, no `Product` is ever instantiated, so the no-op stub bodies are safe.

Consumers that previously checked `if product.isSubscription` or used `product.priceCurrencyAndAmount` continue to compile but never run those branches — the arrays they iterate are always empty. The IAP alert fires at the moment the user taps Subscribe / Buy / Restore, before any unreachable consumer code is touched.

---

## 📋 Current hook inventory (quick summary)

| File | Hook type | Purpose |
|---|---|---|
| `AuthorizationUI/BUILD` | +2 lines (deps) | wire FenixuzAppleReview + FenixuzBrand into AuthorizationUI |
| `AuthorizationSequenceSplashController.swift` | +1 import, ~5 lines hook | emerald-green brand on Welcome / Start Messaging |
| `AuthorizationSequenceCodeEntryController.swift` | +1 import, ~9 lines hook | auto-fill SMS code for demo account via xmax.uz |
| `AuthorizationSequenceCodeEntryControllerNode.swift` | ~10 lines accessor + 3-line guard | private-field access for demo mode + countdown overwrite block |
| `AuthorizationSequencePhoneEntryController.swift` | +1 import, +2 prewarm calls (1 line each) | pre-warm SMS forwarder polling on demo phone confirmation (Apple Review timeout fix) |
| `DeviceAccess/BUILD` | +1 line (dep) | wire FenixuzContactsConsent into DeviceAccess |
| `DeviceAccess/Sources/DeviceAccess.swift` | +1 import, +3 wrapper lines | server-upload consent dialog before iOS Contacts permission (Apple Review 5.1.2 rejection fix) |
| `TelegramUI/BUILD` | +1 line (dep) | wire FenixuzAppStoreIAP into TelegramUI |
| `TelegramUI/Sources/AppDelegate.swift` | +1 import, +2 lines | propagate `isAppStoreBuild` flag to FenixuzAppStoreIAP at launch |
| `TelegramUI/Sources/ApplicationContext.swift` (line ~698) | wraps body in `Queue.mainQueue().after(1.0, { ... })` + 7-line comment | defer post-login contacts auto-prompt 1s so it presents on the stable Chats keyWindow instead of racing the auth-to-tab-bar transition (2026-05-19 regression fix v2; v1 had silenced the prompt entirely which killed the Fenixuz consent + iOS native alerts) |
| `TelegramUI/Sources/ChatController.swift` | +1 import, +5 lines | block @PremiumBot card checkout on App Store builds (Apple 3.1.1) |
| `TelegramUI/Sources/OpenResolvedUrl.swift` | +1 import, +6 lines | block slug-deep-link Premium invoice card checkout |
| `WebUI/BUILD` | +1 line (dep) | wire FenixuzAppStoreIAP into WebUI |
| `WebUI/Sources/WebAppController.swift` | +1 import, +7 lines | block Web-App-initiated Premium invoice card checkout |
| `InAppPurchaseManager/BUILD` | rewritten deps list | wire FenixuzAppStoreIAP + drop StoreKit-era deps (Postbox / StringFormatting / UIPreferences / PersistentStringHash) |
| `InAppPurchaseManager/Sources/InAppPurchaseManager.swift` | full rewrite (930 → ~145 lines) | remove StoreKit code path entirely; public API preserved as fail-fast stubs that present the Fenixuz IAP alert |
| `TelegramUI/Sources/AppDelegate.swift` (line ~35, ~890) | -1 import, -5 lines | drop `import StoreKit` + replace `AppStore.showManageSubscriptions(in:)` with the existing web fallback (no StoreKit-backed subscriptions exist on this fork) |
| `AuthorizationUI/Sources/AuthorizationSequencePaymentScreen.swift` (line ~29) | -1 import | drop now-unused `import StoreKit` (the only `AppStore*` symbol was `AppStoreTransactionPurpose` which is a TelegramCore type, not StoreKit) |
| `RMIntro/Sources/platform/ios/RMIntroViewController.m` | ~30 lines (loadGL block + updateLayout branch) | Fenixuz logo visible on Apple-Silicon simulator |
| `sqlcipher/BUILD` | ~10 lines (header split) | Xcode 26.5 SDK sqlite3ext.h module conflict fix |

**Total Telegram-owned files modified: 20** (6 BUILD + 12 Swift + 1 Objective-C + 1 sqlcipher). All Fenixuz logic itself lives in:
- `submodules/Fenixuz/AppleReview/` — demo-code fetcher + iOS alert
- `submodules/Fenixuz/AppStoreIAP/` — Apple 3.1.1 IAP gate (May 2026 rejection fix)
- `submodules/Fenixuz/Brand/` — central colour palette
- `submodules/Fenixuz/ContactsConsent/` — Apple App Review 5.1.2 server-upload consent gate
