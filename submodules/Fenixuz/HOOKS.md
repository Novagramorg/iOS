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

### `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryControllerNode.swift` — visible QR login button (2026-06-08)

**Top of file — imports block.** Add after `import Markdown`:

```swift
import FenixuzLocalization
```

**Inside `AuthorizationSequencePhoneEntryControllerNode` class body** — after `private var qrNode: ASImageNode?`:

```swift
// Fenixuz: visible "Log in by QR code" text button on the phone-entry screen.
private let qrLoginButtonNode: ASButtonNode
```

**Inside `init(...)` — after `proceedNode.accessibilityIdentifier` line** (before `super.init()`):

```swift
// Fenixuz: visible QR-code login button — text-only, styled like Telegram's secondary login links.
self.qrLoginButtonNode = ASButtonNode()
let qrTitle = FenixuzL10n(strings).auth_qrLoginButton
self.qrLoginButtonNode.setTitle(qrTitle, with: Font.regular(17.0), with: theme.list.itemAccentColor, for: .normal)
self.qrLoginButtonNode.setTitle(qrTitle, with: Font.regular(17.0), with: theme.list.itemAccentColor.withAlphaComponent(0.6), for: .highlighted)
self.qrLoginButtonNode.accessibilityLabel = qrTitle
self.qrLoginButtonNode.accessibilityTraits = .button
```

**Inside `init(...)` — after `self.contactSyncNode.isHidden = true`** (the addSubnode block):

```swift
// Fenixuz: QR login button — only shown when there is an account context (account != nil)
// and screen is wide enough (same guard as proceedNode). Hidden on small-layout path.
self.addSubnode(self.qrLoginButtonNode)
self.qrLoginButtonNode.isHidden = (account == nil)
```

**Inside `init(...)` — after `self.proceedNode.pressed = { ... }` closure:**

```swift
// Fenixuz: "Log in by QR code" — tap creates qrNode on demand (same as debugQrTap)
// and calls refreshQrToken() which exports the login token + renders the QR image.
self.qrLoginButtonNode.addTarget(self, action: #selector(self.qrLoginButtonTapped), forControlEvents: .touchUpInside)
```

**New method — after `debugQrTap(_:)` (around line 712):**

```swift
// Fenixuz: tap handler for the visible "Log in by QR code" button.
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
// Fenixuz: QR button visible only on full-size screens and only when account context exists.
self.qrLoginButtonNode.isHidden = (self.account == nil)
```

**Inside `containerLayoutUpdated` — inside the `else` branch (small-layout path), after `self.managedAnimationNode.isHidden = true`:**

```swift
self.qrLoginButtonNode.isHidden = true
```

**Inside `containerLayoutUpdated` — immediately after `transition.updateFrame(node: self.proceedNode, frame: buttonFrame)`:**

```swift
// Fenixuz: position the QR login button just above the Continue button, centred.
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

Reason: `refreshQrToken()` is `private` — it cannot be called from a Fenixuz module. The entire QR-login session-export machinery (MTProto `auth.exportLoginToken`, `tg://login?token=…` URL, `qrCode(...)` Signal, token-expiry refresh loop, `loginTokenSuccess`/`loginTokenMigrateTo` handling) already exists in this file and works correctly — it was only reachable via a hidden `#if DEBUG && false` gesture on `noticeNode`. This hook surfaces it as a standard visible button with no new logic. The `account == nil` guard mirrors the upstream condition: when `account == nil` (change-number flow), the button stays hidden. Demo flow is completely unaffected — `qrLoginButtonTapped` does not touch `checkPhone`, `prewarmIfDemo`, or any code-entry path.

---

### `submodules/AuthorizationUI/BUILD` — +1 FenixuzLocalization dep (2026-06-08)

Append to `deps = [...]`:

```python
"//submodules/Fenixuz/Localization:FenixuzLocalization",
```

Reason: `AuthorizationSequencePhoneEntryControllerNode.swift` now imports `FenixuzLocalization` to read `FenixuzL10n(strings).auth_qrLoginButton` for the visible QR button label (en/uz/ru). Bazel requires all transitive imports to be in `deps`.

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
| `AuthorizationUI/BUILD` | +3 lines (deps) | wire FenixuzAppleReview + FenixuzBrand + FenixuzLocalization into AuthorizationUI |
| `AuthorizationSequenceSplashController.swift` | +1 import, ~5 lines hook | emerald-green brand on Welcome / Start Messaging |
| `AuthorizationSequenceCodeEntryController.swift` | +1 import, ~9 lines hook | auto-fill SMS code for demo account via xmax.uz |
| `AuthorizationSequenceCodeEntryControllerNode.swift` | ~10 lines accessor + 3-line guard | private-field access for demo mode + countdown overwrite block |
| `AuthorizationSequencePhoneEntryControllerNode.swift` | +1 import, +1 property, ~30 lines | visible "Log in by QR code" button surfacing the existing hidden QR flow (2026-06-08) |
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
| `ChatListHeaderComponent/Sources/NavigationButtonComponent.swift` | +7 lines in icon-frame branch | clamp oversized PDF artboards (FenixGhostActive 455x491 pt → 25x27 pt); set contentMode = .scaleAspectFit (2026-06-08 size fix) |

**Total Telegram-owned files modified: 21** (6 BUILD + 13 Swift + 1 Objective-C + 1 sqlcipher). All Fenixuz logic itself lives in:
- `submodules/Fenixuz/AppleReview/` — demo-code fetcher + iOS alert
- `submodules/Fenixuz/AppStoreIAP/` — Apple 3.1.1 IAP gate (May 2026 rejection fix)
- `submodules/Fenixuz/Brand/` — central colour palette
- `submodules/Fenixuz/ContactsConsent/` — Apple App Review 5.1.2 server-upload consent gate

## 📌 Ghost mode button + Vazifalar tab (2026-06-04)

### `submodules/ChatListUI/Sources/ChatListController.swift` — Ghost mode nav-bar button

Ghost mode = read messages without sending read receipts. The chat-list nav bar shows a toggle
button when `pro_messager` UserDefaults key `show_ghost_mode_button == true`; the active state is
stored in `is_ghost_mode_active`. Implemented entirely inside `ChatListController` (no Fenixuz
submodule): `ghostModeButton` property, `updateGhostModeButton()`, a `FenixSettingsChanged`
NotificationCenter observer, and the button is appended in `rightButtons`.

- **2026-06-04 icon change:** the button uses a custom Fenixuz ghost glyph
  **`Contact List/FenixGhostIcon`** (template imageset; eyes + background are alpha holes) via
  `NavigationButtonComponent.Content.iconTinted(imageName:accent:)`. Toggle state is shown by tint:
  ON (active) → `theme.list.itemAccentColor`; OFF → `panelControlColor` (grey). Previously it reused
  upstream PDF assets `Contact List/MakeVisibleIcon` / `MakeInvisibleIcon` (a person-on-a-platform
  contact glyph that read as "block / remove person"). The ghost PNGs (@1x/@2x/@3x) were generated
  from an owner-supplied image into
  `submodules/TelegramUI/Images.xcassets/Contact List/FenixGhostIcon.imageset` (RGB black + source
  alpha, template-rendering-intent).

### `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift`

Added two `Content` cases: `systemIcon(name: String)` (renders `UIImage(systemName:)` at pointSize 20 /
weight .medium) and `iconTinted(imageName: String, accent: Bool)` (bundle asset tinted with
`theme.list.itemAccentColor` when `accent`, else `panelControlColor`). The shared icon render branch now
computes the tint colour and bakes the SF-Symbol / accent state into the icon cache key (so a toggle
re-renders). Used by the ghost button above. Additive only — existing `.text` / `.more` / `.icon` /
`.proxy` cases keep the `panelControlColor` tint.

**2026-06-08 icon size clamp:** in the `if var iconSize = iconView.image?.size` branch (icon frame
computation), added a `maxIconDimension = 28.0 pt` scale-down clamp before setting `iconView.frame`.
Vector PDF assets (FenixGhostActive / FenixGhostInactive) have large native artboards — without the
clamp their `image.size` fills most of the screen. Clamp only shrinks oversized images (PNG icons that
are already ≤28 pt are unaffected). Also sets `iconView.contentMode = .scaleAspectFit` so the PDF
scales correctly inside the clamped frame. No other icon cases or `.text` / `.more` / `.proxy` branches
are touched.

### `submodules/TelegramUI/Sources/TelegramRootController.swift` + `submodules/TelegramUI/BUILD` — Vazifalar (Tasks) tab hidden

The Vazifalar (Tasks) tab was removed from the tab bar per owner request (2026-06-04). Same pattern
as the already-paused AI tab: `import FenixuzTasks`, the `tasksTabController(...)` creation/append in
`addRootControllers`, the `self.scheduledTasksController` assignment, and the append in
`updateRootControllers` are all commented out; the `//submodules/Fenixuz/Tasks:FenixuzTasks` dep is
commented out in `TelegramUI/BUILD`. The `FenixuzTasks` module + SQLite store are kept on disk for a
future re-enable (uncomment the 4 spots). The `scheduledTasksController` property stays (nil).

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — STT (ovoz→matn) button

Custom Fenixuz speech-to-text round button in the chat input panel (`setupSttButton` /
`layoutSttButton` / `sttButtonPressed` / `updateSttButtonAppearance`, plus the `sttButton*` fields,
`FenixuzSpeechToText` import, and a left-inset reservation). Reads `pro_messager` UserDefaults
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
  (`fenixuzLowMemoryObserver`, registered in `init`, removed in `deinit`) that calls
  `postbox.clearCaches()` + `account.resetCachedData()` on every NON-primary active account. Reads the
  account list via the public `activeAccountContexts` signal (`|> take(1)`) to avoid racing the private
  `activeAccountsValue` mutation queue. Purely additive; uses the same calls already made on
  primary-switch (line ~777-778), so no behavior change. Reduces jetsam risk in the current all-active
  world.
- **Stage 2 (2026-06-05 — working-set cap = 3, shipped):** all account RECORDS stay logged in, but only
  the `fenixuzMaxLiveAccounts` (3) most-recently-used are kept as live `AccountContext`s; the rest stay
  suspended (not loaded → no Postbox/threads/sync). Edits in the `accountManager.accountRecords()`
  pipeline:
  - Working-set computed each pass (`fenixuzOrdered`/`fenixuzWorkingSet`): primary first, then prior
    recency (`fenixuzRecencyOrder`), then the rest by sortIndex; first N = live.
  - `accountWithId` is gated on `fenixuzWorkingSet.contains(id)` (suspended records never open a Postbox).
  - The removal loop also unloads loaded accounts that fell out of the working-set (LRU eviction); the
    primary is always in the working-set so it is never evicted.
  - Switching to a suspended account (via the Accounts screen → `switchToAccount`) makes it primary →
    next pipeline pass loads it and evicts the LRU tail (~1-2s cold start).
  - A name cache (`fenixuzNameCacheDisposable` → UserDefaults `pro_messager` / `fenixuz_account_names`,
    keyed by `peerId.toInt64()`) records each live account's `debugDisplayTitle` so suspended accounts
    can be labelled in the Accounts screen.
  - **Accounts screen** (NOT a Telegram-owned file): `submodules/Fenixuz/ProMessager/Sources/FenixAccountsController.swift`
    lists every logged-in record (live + suspended) and switches on tap. Reached from Settings →
    Fenixuz → "Barcha accountlar" (a row added in `FenixSettingsController.swift`, also Fenixuz-owned).
  - **Known v1 limitations** (push token registration unchanged): suspended accounts keep their existing
    server-side push registration, so push keeps working in the common case; an APNs token *rotation*
    while an account is suspended would drop its push until it is next made live. VoIP calls to a
    suspended account are not presented (no live session). Both are acceptable for the hold-many-accounts
    use case; revisit by widening `otherAccountUserIds` to all logged-in uids + a PushKit resume path.
  - Users with ≤3 accounts see IDENTICAL behaviour (no regression) — the cap only engages at 4+.
  - **2026-06-05 discoverability hook (3 Telegram-owned files):** the built-in Settings accounts section
    only lists the live working-set, which confused the owner ("4-account yo'qoldi"). Added a
    "Barcha accountlar" disclosure row (id 101, icon `PresentationResourcesSettings.devices`) directly
    in the accounts section ABOVE the Add Account row, navigating to `fenixAccountsController`:
    `PeerInfoSettingsItems.swift` (~147, the row), `PeerInfoScreen.swift` (`PeerInfoSettingsSection`
    enum + `case fenixAccounts`, ~165), `PeerInfoScreenSettingsActions.swift` (`case .fenixAccounts:
    push(fenixAccountsController(...))`, ~70 — file already imports `FenixuzProMessager`; the
    PeerInfoScreen BUILD already depends on it). Settings stays compact at 100+ logins by design
    (owner: "Settings UI cho'zilib ketmaydi").
  - **2026-06-05 cap 3 → 1 (owner request):** only the SELECTED account is live; every other login is
    suspended. Every account switch is now a cold load (~1-2s) in exchange for absolute-minimum
    RAM/CPU/network. Because no other live rows exist, the accounts section in
    `PeerInfoSettingsItems.swift` was made unconditional (`if !settings.accountsAndPeers.isEmpty` →
    `do`) so "Barcha accountlar" + "Add Account" stay reachable. Accounts-screen footer text updated.
  - **2026-06-05 localization:** all multi-account strings moved to `FenixuzL10n` (`accounts_*` keys,
    en/uz/ru — "All Accounts" / "Barcha accountlar" / "Все аккаунты", summary, Current/Active/sleeping,
    footer). The Settings row in `PeerInfoSettingsItems.swift` reads
    `FenixuzL10n(presentationData.strings).accounts_allAccounts` — required `import FenixuzLocalization`
    + `//submodules/Fenixuz/Localization:FenixuzLocalization` dep in `PeerInfoScreen/BUILD`.
  - **2026-06-08 tab-bar long-press switcher fix:** `tabBarItemContextAction` in
    `PeerInfoScreen.swift` (~line 7128) used to read `other` from `accountsAndPeersValue` — which
    is sourced from `activeAccountsAndPeers()` → `activeAccountContexts` (live only, cap=1 → empty).
    Fix: added two new properties `fenixAllAccountsValue` / `fenixAllAccountsDisposable` (set up in
    the same `isSettings` block around line 6571) that subscribe to `accountManager.accountRecords()`
    + name cache (`fenixuz_account_names` UserDefaults) so all logged-in records are available.
    `tabBarItemContextAction` now iterates `fenixAllAccountsValue` for non-current rows and renders
    them as `ContextMenuActionItem` entries (text + arrow icon). Primary account row kept as
    `AccountPeerContextItem` (live peer available). This is purely additive — nothing removed.
    No BUILD change needed (PeerInfoScreen/BUILD already imports Postbox which provides `accountRecords()`).
  - **2026-06-08 username cache:** `SharedAccountContext.swift` (`fenixuzNameCacheDisposable` block,
    ~line 858) now also persists `@username` (or `+phone`) per account under
    `fenixuz_account_usernames` (same UserDefaults suite `pro_messager`). Purely additive —
    name cache unchanged, new key added in parallel.
  - **2026-06-08 FenixAccountsController — username + avatar:** `AccountRow` now carries `username`
    and `livePeer` fields. Live accounts get real avatar via `context + iconPeer` on
    `ItemListDisclosureItem`; suspended accounts get a colored initials monogram (`UIGraphicsImageRenderer`,
    no new deps). `additionalDetailLabel` shows `@username` / `+phone` beneath the name.
    Username sourced from live peer when available, else `fenixuz_account_usernames` cache.
  - **2026-06-11 real avatar for suspended accounts (disk cache):** suspended accounts had no live
    peer, so both switchers (tab-bar long-press menu + `FenixAccountsController`) drew only a colored
    initials circle, never the account's real photo. Fix mirrors each live account's rendered avatar
    to disk keyed by peerId, then loads it for suspended rows.
    - **Write:** `SharedAccountContext.swift` — added `import AvatarNode` (already a BUILD dep),
      a `fenixuzAvatarDiskCache` property, and a `FenixAccountAvatarDiskCache.update(accounts:)` call
      inside the existing `fenixuzNameCacheDisposable` handler (made `[weak self]`). The manager calls
      `peerAvatarCompleteImage(account:peer:size:round:)` (120×120 round) and writes a PNG to
      `Caches/fenixuz-account-avatars/<peerId>.png`, re-rendering only when the avatar's
      `resource.id.stringRepresentation` changes (tracked in UserDefaults `fenixuz_account_avatar_versions`);
      clears the file when an account has no photo. Module-level helper `fenixAccountAvatarCachePath(peerId:)`.
    - **Read:** `FenixAccountSwitchContextItem.swift` gained a `peerId` init param and prefers
      `fenixContextCachedAccountAvatar(peerId:)` over the initials image. `PeerInfoScreen.swift`
      `tabBarItemContextAction` passes `peerId: peerId`. `FenixAccountsController.swift` suspended rows
      prefer `fenixCachedAccountAvatar(peerId:)` before `fenixInitialsAvatar`. Path formula duplicated
      (different modules, same main-app Caches dir) — consistent with the existing initials-helper duplication.
      No BUILD changes (read sites need only Foundation/UIKit). Purely additive; initials remain the fallback.
  - **2026-06-08 — `AccountContext/Sources/AccountContext.swift` protocol extension (upstream):**
    Added 4 members to `SharedAccountContext` protocol (`fenixuzPinnedAccountsSignal`,
    `fenixuzLoadPinnedAccounts()`, `fenixuzSavePinnedAccounts(_:)`,
    `fenixuzTogglePinnedAccount(recordId:primaryRecordId:)`). This lets `FenixAccountsController`
    (in `FenixuzProMessager`, which cannot import `TelegramUI`) call these methods via the protocol
    without an `as! SharedAccountContextImpl` cast. Purely additive — no existing protocol members
    changed; implementations live entirely in `SharedAccountContextImpl`.
  - **2026-06-08 — user-controlled pinned set (max 5 live):** `fenixuzMaxLiveAccounts` raised 1→5.
    New `fenixuzPinnedAccountsPromise` (`ValuePromise<Set<Int64>>`) seeded from
    `fenixuz_active_accounts` (UserDefaults `pro_messager`, array of `Int64` record ids).
    Public helpers on `SharedAccountContextImpl`: `fenixuzLoadPinnedAccounts()`,
    `fenixuzSavePinnedAccounts(_:)`, `fenixuzTogglePinnedAccount(recordId:primaryRecordId:)`,
    `fenixuzPinnedAccountsSignal`. Working-set recomputed on BOTH `accountRecords()` changes AND
    pin changes via `combineLatest(accountManager.accountRecords(), fenixuzPinnedAccountsPromise.get())`.
    New working-set rule: `{primary} ∪ {pinned records that exist}`, capped at 5.
    Non-pinned, non-primary accounts remain suspended. Primary is always live and never evicted.
    `FenixAccountsController` updated: `isPinned` field in `AccountRow`; state labels use badge
    colors (accent=Current, green=Active, plain-text=Sleeping); long-press on a non-primary row
    shows an `ActionSheetController` with "Activate (No Sleep)" or "Put to Sleep"; attempting to
    activate a 6th live account shows a `UIAlertController` warning and aborts. New L10n keys
    `accounts_activate`, `accounts_putToSleep`, `accounts_maxLiveTitle`, `accounts_maxLiveBody`,
    `accounts_maxLiveOk` (en/uz/ru) in `FenixuzL10n.swift`.

## 📌 Edited-history gate + Camera picker localization (2026-06-08)

### `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift`

**Around line 1184 — the `EditedMessageHistoryAttribute` check.** Wrap with a UserDefaults gate:

```swift
// Fenixuz: edited history action — only shown when user has enabled it in Settings.
let editedHistoryEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "edited_history_enabled") as? Bool ?? true
if editedHistoryEnabled, let _ = messages[0].attributes.first(where: { $0 is EditedMessageHistoryAttribute }) {
    // ... existing action append ...
}
```

Reason: `edited_history_enabled` flag (default `true`) is toggled from Fenixuz Settings → Chat section. Gate is a one-liner wrapping the existing condition; default `true` means zero behavior change for existing users. The `UserDefaults` read is the cheapest possible gate — the context-menu build path already runs on the main queue.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/BUILD`

Added `"//submodules/Fenixuz/Localization:FenixuzLocalization"` to `deps`.

Reason: `ChatTextInputPanelNode.swift` now imports `FenixuzLocalization` to localize the camera-picker action sheet.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift`

**Top of file — imports block.** Add after `import FenixuzSpeechToText`:

```swift
import FenixuzLocalization
```

**Inside `presentCameraSelection` closure (around line 925) — replace hardcoded strings.** Was:

```swift
ActionSheetButtonItem(title: "Oldi Camera", ...)
ActionSheetButtonItem(title: "Orqa Camera", ...)
```

Replace with:

```swift
// Fenixuz: localized camera picker labels (was hardcoded "Oldi Camera"/"Orqa Camera").
let l10n = FenixuzL10n(presentationInterfaceState.strings)
ActionSheetButtonItem(title: l10n.cameraPicker_front, ...)
ActionSheetButtonItem(title: l10n.cameraPicker_back, ...)
```

`cameraPicker_front` / `cameraPicker_back` strings: en "Front Camera" / "Back Camera", uz "Old kamera" / "Orqa kamera", ru "Передняя камера" / "Задняя камера".

Reason: the original Fenixuz implementation hardcoded Uzbek-only labels visible to all users. `presentationInterfaceState.strings` is already in scope (the surrounding block uses it), so creating `FenixuzL10n` from it costs nothing extra.

---

## 📌 First-launch Tips + App Store update check (2026-06-08)

Two new Fenixuz modules: `FenixuzTips` and `FenixuzUpdateCheck`. Both fire post-login via a single deferred block in `AuthorizedApplicationContext.init`.

### `submodules/TelegramUI/BUILD`

In the `deps = [...]` list, append (alongside the existing Fenixuz deps):

```python
"//submodules/Fenixuz/Tips:FenixuzTips",
"//submodules/Fenixuz/UpdateCheck:FenixuzUpdateCheck",
```

### `submodules/TelegramUI/Sources/ApplicationContext.swift`

**Imports — append after `import BrowserUI`:**

```swift
import FenixuzTips
import FenixuzUpdateCheck
```

**At the very end of `AuthorizedApplicationContext.init(...)` — after the `VoiceChatController` overlay block, before the closing `}`:**

```swift
// Fenixuz: post-login feature tips + App Store update check.
// Deferred 1s so the Chats tab finishes its layout before a modal appears
// (same pattern as the contacts auto-prompt deferral documented in HOOKS.md).
// Tips take priority on first launch; update check runs on subsequent launches.
let capturedContext = self.context
let capturedRootController = self.rootController
Queue.mainQueue().after(1.0, {
    let presentationData = capturedContext.sharedContext.currentPresentationData.with { $0 }
    guard let topVC = capturedRootController.viewControllers.last as? UIViewController else { return }
    if FenixuzTipsScreen.shouldShowOnFirstLaunch {
        // First launch: show Tips screen (update check runs next launch).
        let tipsVC = FenixuzTipsScreen.makeController(presentationData: presentationData)
        topVC.present(tipsVC, animated: true)
    } else {
        // Subsequent launches: non-blocking update check.
        FenixuzUpdateChecker.checkAndPresentIfNeeded(on: topVC, presentationData: presentationData)
    }
})
```

Reason: the Tips screen must present on the stable Chats window (not racing the auth→tab-bar transition). Both features depend on a live `AccountContext` (theme, language) so they belong here, not in `AppDelegate`. The 1s defer matches the existing contacts-auto-prompt deferral pattern. Tips fires once (guarded by `fenixuz_tips_shown` in `pro_messager` UserDefaults). The update check fires on every subsequent launch but shows at most one alert per session (`sessionAlertShown` static flag in `FenixuzUpdateChecker`).

---

## 📌 Gold "Fenixuz" Settings row (2026-06-08)

Owner request: the **Fenixuz** entry in Settings must be gold ("tilla") so it stands out in the list.
The row now renders a gold title + a gold **flame** icon (Fenix = phoenix/fire branding) instead of the
old grey `PresentationResourcesSettings.security` shield.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/ListItems/PeerInfoScreenDisclosureItem.swift` — generic `titleColor`

Added an optional `titleColor: UIColor? = nil` to `PeerInfoScreenDisclosureItem` (property + init param)
and changed the one line that sets the title colour:
`let textColorValue = item.titleColor ?? presentationData.theme.list.itemPrimaryTextColor`.
Generic + additive: every other disclosure row passes `nil` and is unchanged; only the Fenixuz row
overrides it. No BUILD change.

### `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` — gold Fenixuz row

`+import FenixuzProMessager` (BUILD already depends on `//submodules/Fenixuz/ProMessager:FenixuzProMessager`).
The Fenixuz row now passes `titleColor:` a theme-adaptive gold — `0xFFCC33` (dark) / `0xC8951A` (light,
deeper for white-background contrast) — and `icon: fenixuzSettingsIcon(systemName: "flame.fill", color: .gold)`.

### `submodules/Fenixuz/ProMessager/Sources/FenixuzSettingsIcons.swift` (Fenixuz-owned)

Made `FenixuzIconColor` enum + `fenixuzSettingsIcon(systemName:color:)` `public` so the icon helper can be
reused from the PeerInfoScreen module, and added a `.gold` case (`0xD4AF37` classic metallic gold).

---

## 📌 Ghost mode ad-reporting suppression (2026-06-08, Task #7)

### `submodules/TelegramCore/Sources/TelegramEngine/Messages/AdMessages.swift`

Three functions call TG servers to report ad views/clicks. All three are guarded with the
`isFenixuzGhostModeActive` check so no sponsored-message telemetry is sent while Ghost mode is ON.

**1. `AdMessagesHistoryContextImpl.markAsSeen(opaqueId:)` (~line 592)**
Return type: `Void` (sets a disposable on `maskAsSeenDisposables` and returns). Guard before the signal:

```swift
// Fenixuz Ghost mode: do NOT report "seen" to TG servers when ghost is active.
if isFenixuzGhostModeActive { return }
```

**2. `_internal_markAdAction(account:opaqueId:media:fullscreen:)` (~line 688)**
Return type: `Void`. Guard at top of function:

```swift
// Fenixuz Ghost mode: do NOT report ad clicks to TG servers when ghost is active.
if isFenixuzGhostModeActive { return }
```

**3. `_internal_markAdAsSeen(account:opaqueId:)` (~line 704)**
Return type: `Void`. Guard at top of function:

```swift
// Fenixuz Ghost mode: do NOT report sponsored message views to TG servers when ghost is active.
if isFenixuzGhostModeActive { return }
```

`isFenixuzGhostModeActive` is the existing internal global in
`submodules/TelegramCore/Sources/Fenixuz/FenixuzGhostMode.swift` — same module, no import needed.
These guards cover both the chat sponsored-message context (`AdMessagesHistoryContextImpl`) AND the
global-search sponsored-peer context (both eventually call the `_internal_*` free functions).

---

## 📌 Ghost mode nav-button new icons (2026-06-08, Task #13)

### New imagesets in `submodules/TelegramUI/Images.xcassets/Contact List/`

Two new imagesets added with user-supplied vector PDFs:

**`FenixGhostActive.imageset`** — purple filled ghost with dark eyes (multicolor PDF).
- `Contents.json`: single universal PDF, `preserves-vector-representation: true`, **no** `template-rendering-intent`.
- Used for Ghost ON state. Rendered with `.alwaysOriginal` so purple + dark eyes are preserved.

**`FenixGhostInactive.imageset`** — thin outline ghost (near-invisible raw; needs tint).
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
    ? .iconOriginal(imageName: "Contact List/FenixGhostActive")
    : .iconTinted(imageName: "Contact List/FenixGhostInactive", accent: false)
```

- ON  → `FenixGhostActive` rendered original (purple filled, multicolor).
- OFF → `FenixGhostInactive` rendered template tinted `panelControlColor` (grey outline, clearly visible).

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
// Fenixuz: NSE writes the full int64 PeerId as "peerId" in userInfo.
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

New Fenixuz file (NOT a hook in a Telegram-owned file): `submodules/TelegramCore/Sources/Fenixuz/FenixuzGhostReadOnSend.swift` —
`public func fenixuzForceReadHistory(account:peerId:)`. No-op when Ghost is off. When Ghost is on it does the canonical
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
    if isFenixuzGhostModeActive, let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
        _internal_applyMaxReadIndexInteractively(transaction: transaction, stateManager: account.stateManager, index: topIndex)
    }
    return result
}
|> afterCompleted {
    // Push the read receipt to the server so the other side sees "read".
    if isFenixuzGhostModeActive { let _ = fenixuzForceReadHistory(account: account, peerId: peerId).startStandalone() }
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
`fenixuzForceReadHistory` also uses `.Cloud` for both the local read and the server `maxId`.

### 2. Pinned "Active / No Sleep" accounts stay live — `submodules/TelegramUI/Sources/SharedWakeupManager.swift`

Root cause of "pinned account gets no background notification": `updateAccounts()` only granted
`shouldBeServiceTaskMaster = .always` to the foreground primary; pinned non-primary accounts got `.never`, which closes
their MTProto connection (`Account.swift:1377-1386` → `network.shouldKeepConnection`). So they never received messages until
switched to.

New helper before `updateAccounts(...)`:

```swift
private func fenixuzPinnedIds() -> Set<Int64> {
    let arr = (UserDefaults(suiteName: "pro_messager")?.array(forKey: "fenixuz_active_accounts") as? [Int64]) ?? []
    return Set(arr)
}
```

At the top of `updateAccounts(...)`: `let fenixuzPinned = self.fenixuzPinnedIds()`. In the active-branch
`for (account, primary, tasks)` loop the condition changed from `(self.inForeground && primary)` to
`(self.inForeground && (primary || isPinnedWorkingSet))` where `let isPinnedWorkingSet = fenixuzPinned.contains(account.id.int64)`.
Suspended (non-working-set) accounts are not in `accountsAndTasks`, so they stay suspended. Key/format matches
`SharedAccountContextImpl.fenixuzLoadPinnedAccounts()` exactly (`pro_messager` / `fenixuz_active_accounts` as `[Int64]`).

### 3. Tab-bar account switcher rows show avatar + username — `PeerInfoScreen.swift` (updates the 2026-06-08 entry above)

New Fenixuz file (auto-globbed, no BUILD change): `…/PeerInfoScreen/Sources/FenixAccountSwitchContextItem.swift` — a
`ContextMenuCustomItem` modeled on `AccountPeerContextItem`: left = 30pt colored initials avatar, two lines (name +
`@username`/`+phone`), tap → `switchToAccount`. In `tabBarItemContextAction`, the non-current `fenixAllAccountsValue` loop now
appends `.custom(FenixAccountSwitchContextItem(...), false)` instead of a text-only `ContextMenuActionItem` with an arrow icon.
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
if isFenixuzGhostModeActive {
    return .complete()
}
```
Suppresses the `messages.readReactions` sync (marking "I've seen who reacted to my messages") when Ghost is on. Return type `Signal<Void, NoError>`. (The separate guard at ~143 targets `readMessageContents` inside `oneOperation` — a different function.)

### `submodules/TelegramCore/Sources/State/AccountViewTracker.swift`
`getMessagesViews` call (~line 723) — increment flag made conditional:
```swift
increment: isFenixuzGhostModeActive ? .boolFalse : .boolTrue
```
When Ghost is on, channel post view counters are NOT bumped, but the request still runs so the user still SEES view counts (no UI regression). Deliberately NOT a blanket guard.

---

## 📌 2026-06-16 — quick-wins batch (haptic, voice-translate, chat-lock biometric)

### `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/NavigationButtonComponent.swift` — menu haptic (#42)

**Inside `pressed()` (~line 103):** a `switch self.component?.content` guard fires a `UIImpactFeedbackGenerator(style: .light)` only for the three Fenixuz-added content types — `.iconOriginal`, `.iconTinted`, and `.systemIcon`. The upstream cases `.icon`, `.text`, `.more`, and `.proxy` deliberately fall through with no haptic so existing upstream button UX is unchanged.

```swift
@objc private func pressed() {
    // Fenixuz: light haptic for Fenixuz-added icon button types (iconOriginal, iconTinted, systemIcon).
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

Reason: upstream `.pressed()` had no haptic. Fenixuz ghost-mode, STT, and header buttons use the three new content types; the haptic covers all of them in one place without touching the upstream `.icon`/`.text`/`.more`/`.proxy` code paths (those belong to upstream UX — changing them would affect chat navigation buttons, compose button, proxy button, etc.).

---

### `submodules/ChatListUI/Sources/ChatListController.swift` — story-camera button haptic (#42)

**Inside the story-camera `NavigationButtonComponent` pressed closure (~line 7177):**

```swift
// Fenixuz: light haptic on story camera button tap.
let generator = UIImpactFeedbackGenerator(style: .light)
generator.impactOccurred()
```

Inserted immediately before the existing `parentController.displayContinueLiveStream()` / `openStoryCamera(fromList:)` branch.

Reason: the story-camera button uses `.icon(imageName:)` content type — the upstream case that `NavigationButtonComponent.pressed()` intentionally does NOT add haptic to. The story-camera is a Fenixuz UX surface (custom placement, custom icon `"Chat List/AddStoryIcon"`) and should have haptic feedback; adding it here in the action closure is the only path that works without touching the upstream `.icon` render path.

---

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — STT haptic + voice→translate (#42, #25)

**`sttButtonPressed()` (~line 5904) — two Fenixuz additions:**

**1. Haptic (#42):**

```swift
// Fenixuz: selection haptic on STT record start/stop toggle.
let sttHaptic = UISelectionFeedbackGenerator()
sttHaptic.selectionChanged()
```

Fires at the very start of `sttButtonPressed()` before the early-return for the `isSttRecording` case, so both start and stop get feedback.

**2. Voice→translate (#25):**

```swift
// Fenixuz #25: translate the finished transcription before it lands in the input field.
// Inline TelegramCore translate (importing FenixuzProMessager here would create a module cycle).
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

Set immediately after `self.sttManager` is created/reused. The translate-on/off flag and target language are read inside `SpeechToTextManager` from the `pro_messager` UserDefaults suite — not here. If translation is disabled or the engine call fails, `completion(text)` passes through the raw transcription unchanged. The `translateHandler` is an inline closure rather than a separate module import because importing `FenixuzProMessager` from `ChatTextInputPanelNode` (which is a dependency of `TelegramUI`, which is a dependency of `FenixuzProMessager`) would create a circular module dependency.

---

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` — chat-lock context menu with passwordType (#46)

**Around lines 494–513 — the `.remove` and `.set` callers in the per-chat pincode context-menu action:**

`.remove` caller (~line 494): `ChatPincodeViewController(mode: .remove(passwordType: ChatPincodeManager.shared.getMetadata(for: peerId).passwordType, onVerify: ..., onSuccess: ...))` — passes `passwordType:` read from `getMetadata(for:)` so the verify screen shows dots (PIN) or a text field (alphanumeric) matching whatever the user set up.

`.set` caller (~line 505): `ChatPincodeViewController(mode: .set(onSuccess: { code, passwordType, biometricEnabled in ChatPincodeManager.shared.setPincode(code, for: peerId, type: passwordType, biometricEnabled: biometricEnabled) }))` — the `onSuccess` closure now carries `(code, passwordType, biometricEnabled)` and forwards all three to `ChatPincodeManager.setPincode(_:for:type:biometricEnabled:)`.

Reason: `ChatPincodeMode.remove` and `.set` gained `passwordType:` and `biometricEnabled:` parameters when `FenixuzChatLock` was updated to support both PIN and alphanumeric passwords. These call sites in the upstream-owned `ChatContextMenus.swift` must match the new API signatures or the project will not build. `getMetadata(for:)` is a new public method on `ChatPincodeManager.shared` that returns a `ChatLockMetadata` struct carrying both `passwordType` and `biometricEnabled`.

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

## 📌 2026-06-16 (c) — folder unlock + chat-lock menu localization

### `submodules/TelegramCore/Sources/State/UserLimitsConfiguration.swift` (~line 163)
`self.maxFoldersCount = max(1000, getValue("dialog_filters_limit", ...))` — lifts the CLIENT-side folder-count gate so the Premium "Limit Reached" upsell never triggers. NOTE: the Telegram **server** still enforces its own cap on `messages.updateDialogFilter`, so true count is server-bounded.

### `submodules/ChatListUI/Sources/ChatListFilterPresetListController.swift` (~line 282)
`var effectiveDisplayTags: Bool? = displayTags` (was gated by `if isPremium`) — unlocks the "Show Folder Tags" toggle for everyone. Tag rendering is fully client-side.

### `submodules/ChatListUI/Sources/ChatContextMenus.swift` (~line 484)
`pincodeTitle` now uses `FenixuzChatLockStrings.menuRemove / .menuSet` (localized en/uz/ru) instead of the hardcoded Uzbek `"🔒 Pincode qo'yish"`.

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

`sendCurrentMessage(...)` ichida, mavjud `// PRO MESSAGER: Automatic Translation` (#31) anchor'dan OLDIN yangi `// FENIX-HOOK #37` bloki qo'shildi (qatorlar 4690–4756).

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

Sozlama: `pro_messager` UserDefaults `send_confirm_enabled` (default `false`). Toggle `FenixSettingsController.swift` — Protection seksiyasida (stableId = 45), `FenixSendConfirmStrings` namespace (public). Har 3 hook inline langCode switch ishlatadi (FenixuzProMessager import → module cycle xavfi bor edi).

### `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — Python bilan qo'llandi, 2026-06-17

`mediaActionButtons.micButton.stopRecording` callback'iga `// FENIX-HOOK #38` bloki qo'shildi (~qator 905–950).

Logika: `send_confirm_enabled` true bo'lsa, `interfaceInteraction.stopMediaRecording()` + `tooltipController?.dismiss()` chaqirilgandan SO'NG `UIAlertController` (`.alert` style) ko'rsatiladi (textAlertController shu modulda mavjud emas — PresentationDataUtils dep yo'q). "Yuborish" → `sendRecordedMedia(false, false)`. "Bekor qilish" → `deleteRecordedMedia()`. False holda — asl xatti-harakat (to'g'ridan-to'g'ri send).

Present: `UIApplication.shared.windows.first?.rootViewController` orqali top presented VC.

Anchor (noyob Python): START=`self.mediaActionButtons.micButton.stopRecording = { [weak self] in\n`, END=`        self.mediaActionButtons.micButton.updateLocked = { [weak self] _ in`.

### `submodules/TelegramUI/Sources/ChatController.swift` — Python bilan qo'llandi, 2026-06-17

`sendSticker:` callback ichida, `addToTransitionNodeIfNeeded()` dan keyin `// FENIX-HOOK #38` bloki qo'shildi (~qator 2414–2457).

Logika: `send_confirm_enabled` true bo'lsa, `transformEnqueueMessages` avval bajariladi va `textAlertController(context:updatedPresentationData:title:text:actions:)` bilan dialog ko'rsatiladi. "Yuborish" → `sendMessages(fenixTransformed)`. "Bekor qilish" → bo'sh. Present: `strongSelf.present(... in: .window(.root))`.

Anchor (noyob Python): `addToTransitionNodeIfNeeded()\n                    let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting, postpone: postpone)\n                    strongSelf.sendMessages(transformedMessages)\n                } else if schedule {`.

### `submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift` — Python bilan qo'llandi, 2026-06-17

`sendGift` context menu action ichiga `// FENIX-HOOK #38` bloki qo'shildi (~qator 1162–1204).

Logika: `send_confirm_enabled` true bo'lsa, `f(.dismissWithoutContent)` avval chaqiriladi (context menu yopiladi), keyin `textAlertController(context:title:text:actions:)` dialog. "Yuborish" → `controllerInteraction?.sendGift(message.id.peerId)`. "Bekor qilish" → bo'sh. Present: `controllerInteraction?.presentController(fenixAlert38, nil)`.

Anchor (noyob Python): `            }, action: { _, f in\n                let _ = controllerInteraction.sendGift(message.id.peerId)\n                f(.dismissWithoutContent)\n            })))`.

## 📌 2026-06-17 — Feature #30: Sticker Auto-Add (after text message)

Sozlama: `pro_messager` UserDefaults `auto_sticker_enabled` (default `false`). Toggle `FenixSettingsController.swift` — Messaging seksiyasida (stableId = 28), `FenixAutoStickerStrings` private namespace. Disable qilinganda `auto_sticker_data` key ham o'chiriladi.

Saqlash: sticker yuborilganda `PostboxEncoder.encodeRootObject(TelegramMediaFile)` → `makeData()` → `base64EncodedString()` → `auto_sticker_data` key'iga yoziladi.

Yuborish: `sendCurrentMessage` ichida `sendMessages(...)` chaqirilishidan OLDIN `PostboxDecoder(buffer: MemoryBuffer(data:)).decodeRootObject() as? TelegramMediaFile` bilan decode → `FileMediaReference.standalone(media:).abstract` → `EnqueueMessage.message(text:"", ...)` qo'shiladi. Faqat `.message` shaped birinchi elementli array'larda ishlaydi (forward-only holat bilan aralashmaydi).

### `submodules/TelegramUI/Sources/ChatController.swift` — Python bilan qo'llandi, 2026-06-17

`sendSticker:` callback ichida, `let replyMessageSubject = ...` va `let messages: [EnqueueMessage] = [...]` orasiga `// FENIX-HOOK #30` bloki qo'shildi (~qator 2404–2413).

Logika: `fileReference.media` (non-optional `TelegramMediaFile`) → `PostboxEncoder.encodeRootObject` → `makeData().base64EncodedString()` → `UserDefaults(suiteName:"pro_messager").set(..., forKey:"auto_sticker_data")`.

Anchor (noyob Python): `let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject\n\n                let messages: [EnqueueMessage]  = [.message(text: "",`.

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` — Python bilan qo'llandi, 2026-06-17

`doSend` closure ichida, `self.sendMessages(messages, ...)` chaqirilishidan OLDIN `// FENIX-HOOK #30` bloki qo'shildi (~qator 5123–5152).

Logika: `auto_sticker_enabled` true + `messages` bo'sh emas + `messages[0]` `.message` case + `auto_sticker_data` base64 decode + `PostboxDecoder.decodeRootObject() as? TelegramMediaFile` → `FileMediaReference.standalone(media:).abstract` → yangi `EnqueueMessage.message(text:"", ...)` `messages` array oxiriga qo'shiladi.

Anchor (noyob Python): `                    self.sendMessages(messages, silentPosting, scheduleTime, repeatPeriod, messages.count > 1, postpone)\n                }`.


### `submodules/ItemListUI/Sources/Items/ItemListSwitchItem.swift` — titleBadge y-position fix — 2026-06-17
Native `titleBadgeComponent` (NEW badge) y-position used `(contentSize.height - badge)/2` — the full row center. On rows WITH a subtitle the badge dropped onto the subtitle text and covered words ("auto-downl[NEW]all networks"). Changed to `titleNode.frame.minY + (titleNode.height - badge)/2` so the badge aligns to the title line regardless of subtitle. Title-only rows (ChannelStatsController) unaffected — math identical. Python.


## 📌 2026-06-17 — Feature #34: Heart Effect (auto-attach ❤️ message effect)

Sozlama: `pro_messager` UserDefaults `heart_effect_enabled` (default `false`). Toggle `FenixSettingsController.swift` — Messaging seksiyasida (stableId = 29), `FenixHeartEffectStrings` private namespace.

Resolver: `FenixHeartEffect` (xuddi shu fayl oxirida). Toggle ON bo'lganda `context.engine.stickers.availableMessageEffects()` dan `emoticon` `❤` bilan boshlanadigan NON-premium effektni topib, uning `id` sini `fenix_heart_effect_id` (Int) key'iga cache qiladi. `availableMessageEffects()` bir martalik cache read bo'lgani uchun sovuq cache holatida 4 marta (1.5s oraliq) retry qiladi.

No-Backend: heart effekt reaction-asosli (`isPremium == false`) — barcha userlar yubora oladi, Telegram serveri qabul qiladi. Premium emoji'dan farqli (theatre EMAS).

### `submodules/TelegramUI/Sources/ChatControllerNode.swift` (~qator 5047) — Python bilan qo'llandi, 2026-06-17

`sendCurrentMessage` ichida, tanlangan effekt bloki (`if !messages.isEmpty, let messageEffect { ... }`) dan KEYIN `// FENIX-HOOK #34` bloki qo'shildi.

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
