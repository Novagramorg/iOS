# Framework export lists

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Framework export lists (computed by the build)

`TelegramUIFramework` and `TelegramCoreFramework` export only the symbols their clients use.
- **`TelegramUIFramework`:** its clients are the app binary and the Share, Notification Content,
  Broadcast Upload and Notification Service extensions. It exports 194 of 161,496 public
  symbols in release (214 in debug), which cut it by 13.6 MB (−11.9%).
- **`TelegramCoreFramework`:** its clients are TelegramUI, the app binary and all six extensions.
  It exports 5,279 of 39,436 in release, which cut it by 1.4 MB (−9.2%).

Together, `.ipa` −5.4 MB. The symbol tables went, and so did the unused public code they kept alive.

**Release builds only** (`select` on `:debug`): debug builds export everything, so the per-archive
scans don't run there. A client symbol missing from a list therefore shows up only as a *release*
link error. The list is computed, never checked in. `framework_exported_symbols` (`Telegram/framework_exported_symbols.bzl`)
intersects the undefined symbols of the clients' compiled archives with the symbols the
framework's own archives define. It is then passed through `ios_framework`'s `exported_symbols_lists`.
Each archive is scanned by its own cached action, so an edit rescans only the archives it
changed; a full scan of TelegramUI's debug archives takes ~8.5 s.
There is no cycle: clients *compile* against module interfaces, so the order is client
compile → list → framework link → client link.

- **A new client of either framework** (an extension, or a library of the app binary) must be
  added to that rule's `clients`. A missing one fails that client's link with undefined symbols;
  it never fails at runtime.
- **A new framework under either framework** (a new entry in its `frameworks`) must be added to
  that rule's `provided_by_frameworks`. Otherwise its symbols would be listed as exports the framework
  doesn't define, and `ld` rejects that.
- **Nothing may look up the app's own symbols by name at runtime** (`dlsym`); there is none today.
  `NSClassFromString` and Swift type and conformance lookup use runtime metadata, not exports.
- Count a binary's imports with `xcrun dyld_info -imports`. `nm -u` shows nothing for these
  chained-fixup binaries.
