# Fenixuz hooks in Telegram-owned files

This file is the **source of truth** for every line of Fenixuz code that lives outside `submodules/Fenixuz/`. Each entry describes:

1. The exact file + region that is modified
2. The hook code itself
3. Why it lives outside a Fenixuz module (i.e. cannot be expressed as pure Fenixuz code)

On every `git pull upstream master`, an AI assistant uses this file to re-apply hooks if upstream code moved. **Fenixuz hooks always win** against upstream changes; surrounding upstream code is taken as-is.

> Last verified: 2026-05-12 against upstream commit `156ce73315` (Fenixuz master).

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

## 📋 Current hook inventory (quick summary)

| File | Hook type | Purpose |
|---|---|---|
| `AuthorizationUI/BUILD` | +2 lines (deps) | wire FenixuzAppleReview + FenixuzBrand into AuthorizationUI |
| `AuthorizationSequenceSplashController.swift` | +1 import, ~5 lines hook | emerald-green brand on Welcome / Start Messaging |
| `AuthorizationSequenceCodeEntryController.swift` | +1 import, ~9 lines hook | auto-fill SMS code for demo account via xmax.uz |
| `AuthorizationSequenceCodeEntryControllerNode.swift` | ~10 lines accessor + 3-line guard | private-field access for demo mode + countdown overwrite block |
| `RMIntro/Sources/platform/ios/RMIntroViewController.m` | ~30 lines (loadGL block + updateLayout branch) | Fenixuz logo visible on Apple-Silicon simulator |
| `sqlcipher/BUILD` | ~10 lines (header split) | Xcode 26.5 SDK sqlite3ext.h module conflict fix |

**Total Telegram-owned files modified: 6** (2 BUILD + 3 Swift + 1 Objective-C). All Fenixuz logic itself lives in:
- `submodules/Fenixuz/AppleReview/` — demo-code fetcher + iOS alert
- `submodules/Fenixuz/Brand/` — central colour palette
