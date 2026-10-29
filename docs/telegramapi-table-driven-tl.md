# TelegramApi: table-driven TL

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## TelegramApi: Swift payload structs over table-described storage (table-driven TL, steps 1–5)

`Api.X.Cons_y` is a **`@frozen` Swift struct holding one `TLObject`**. `TLObject` is the only
Objective-C class in TelegramApi: a hand-written **non-NSObject root** (MRC, `TelegramApiObjC`
module, `submodules/TelegramApi/ObjC`) with its own reference counting, weak support, and
table-driven `-dealloc` and description. It carries no ivars of its own beyond a 24-byte header.
Each payload's fields live in extra bytes allocated by `TLObjectAllocate(info)`, at offsets the
generator computes (`TLSchemaLayout.storageLayout`):
- `int32` fields first, then every other field 8-aligned (`int256` is 32 bytes), each group in
  schema order;
- then the `uint64_t` presence mask for optional scalars.

The Swift accessors (`@_alwaysEmitIntoClient` + `@inline(__always)`, so they have no symbols)
load at those offsets, and the initializers and `Api.functions` builders store at them. The
engine, `-dealloc` and description read the same offsets from the schema table. **No class,
ivar or runtime name lookup remains.** The blob's image format is documented at the top of
`build-system/SwiftTL/Sources/SwiftTL/SchemaBlob.swift`.

**The schema is `submodules/TelegramApi/swift_scheme.tl`, and Bazel generates the code from it on
every build.** The `TelegramApiGenerated` genrule runs the host tool `//build-system/SwiftTL:SwiftTL`
and declares a fixed file list: `Api0`…`Api43.swift` (`--swift-file-count`, types spread evenly),
`TLApiSchemaData.m`, and the tests' `SchemaFixtures.swift`/`SchemaAccessorProbes.swift`. Nothing
generated is checked in for Bazel; changing the schema is the whole change.
- **SwiftPM reads a locally generated copy** in `Sources/`, `ObjC/` and `Tests/SwiftPMGenerated`
  (TelegramCore's `Package.swift`, which Telegram-Mac builds, depends on TelegramApi's). It is
  gitignored (since 2026-10-15; Telegram-Mac ignores it too): `swift_scheme.tl` is the source of
  truth, so run `submodules/TelegramApi/generate-swiftpm.sh` before a SwiftPM build or
  `swift test`, and again after the schema or the generator changes. Bazel's globs are
  non-recursive so it never compiles that copy; keep them so. **Only ever regenerate all three
  directories together (the script does):** Swift and `TLApiSchemaData.m` from different runs
  disagree on offsets and corrupt memory silently. Nothing checks the pair at run time (one genrule
  action or one script run always writes both); `SchemaTableTests.testHashesMatch` and
  `AccessorProbeTests` catch it in the tests.
- **No header is generated.** `TLApiTypes.h` and the umbrella header are static, and the counts
  and hash are `extern const`s defined in the generated `TLApiSchemaData.m`. A generated public
  header would be on both Bazel's and SwiftPM's include paths, where either copy can shadow the
  other.

**Parsing, serialization and function calls run in a C engine** (`ObjC/Sources/TLEngine.m`)
driven by the table. The generated Swift has no `parse_*`/`serialize`/`descriptionFields`
bodies:
- `Api.parse` falls through to `tlParseTopLevel`;
- `serialize` and `descriptionFields` come from shared `TLObjectBacked` extensions
  (`Sources/TLObjectSupport.swift`);
- storage access lives in `Sources/TLStorage.swift`.

**The schema table is a zlib-compressed image** (blob v3):
- `SwiftTL` (`SchemaBlob.swift`) serializes the layout, including every field offset and each
  constructor's size and presence-mask offset, into a pointer-free image. It is emitted as a
  `const` byte array in the generated `TLApiSchemaData.m`.
- `ObjC/Sources/TLSchemaLoader.m` inflates it once, validates it, and builds the
  `TLTypeInfo`/`TLConstructorInfo`/`TLFieldInfo`/`TLFunctionInfo` structs on the heap. The
  validation covers every field and mask lying inside its object's storage.
- Access goes through `TLApiTypeAt`/`TLApiConstructorAt` (ascending id)/`TLApiFunctionAt`/
  `TLApiFunctionConstructorAt`/`TLApiConstructorWithId`.
- `TLApiSchemaHash` covers the schema and the layout-algorithm version (`SwiftTL-Storage/1`).
  At run time it serves only `tlVerifyClientLayout()` (below); the loader validates the image's
  structure, not its hash. **The 24-byte header size is assumed, not checked** (a user decision): adding an
  ivar to `TLObject` would shift every field. Don't.

Compiler-invisible rules:
- **Only TelegramCore depends on TelegramApi.** Bazel `visibility` on both TelegramApi targets
  admits only `//submodules/TelegramCore`, and TelegramCore's public interface exposes no `Api`
  types. Tests of TelegramCore's Api conversions live in `//submodules/TelegramCore:TelegramCoreTests`.
  TelegramCore's 340 files use `internal import TelegramApi`, so the compiler rejects any public
  TelegramCore declaration that exposes an `Api` type, and importers of TelegramCore no longer load
  TelegramApi implicitly. Neither guard stops an explicit `import TelegramApi` elsewhere: rules_swift
  puts every transitive module on the search path (verified: a probe file in TextFormat's tests
  compiled). So do not add one outside TelegramCore.
- **TelegramApi's symbols are not exported from `TelegramCoreFramework`.** Nothing outside
  TelegramCore uses them, so the framework's computed export list (see "Framework export lists")
  leaves them out. That once took `-unexported_symbol` patterns and cut 1.74 MB, of which 470 KB was
  dead-stripped code.
- **`tlFunction` must stay unspecialized** (`@_semantics("optimize.sil.specialize.generic.never")`).
  Otherwise each of the ~40 result types gets its own closure copy. Check:
  `nm .build/release/TelegramApi.o | xcrun swift-demangle | grep -c "specialization.*tlFunction"` → 0.
- **The schema code generator and engine are trusted; there is no per-constructor wire test.**
  `SchemaGoldenTests` (digests of every fixture recorded from the pre-engine Swift) was removed on
  2026-10-15: every schema change failed it until the new entries were recorded on a frozen
  pre-engine generator. `GoldenTests` keeps about 15 hand-written fixtures whose bytes and logger
  output were recorded pre-engine; never re-record those on the engine.
- **Unknown constructors are logged with their exact id, even after an earlier field failed.**
  That requires the engine to stop where the old Swift parser stopped: a primitive's id in an
  object field consumes the primitive, and a string whose length overruns still skips its
  padding. `Tests/ParseFailureTests.swift` pins the literal log lines; it was validated against
  the pre-engine parser, so do not edit its expectations to match new behaviour.
- **A bytes field's getter returns a new `Buffer` on every access.** Never take a raw pointer
  from it (`x.field.data`, `x.field.size` inside a `memcpy`); copy with `makeData()` or
  bind the `Buffer` inside `withExtendedLifetime`. This was a real use-after-free
  (inline callback button data).
- **Offsets are baked into Swift and into the table; they must agree.** `AccessorProbeTests`
  (generated probes) reads every field of every fixture through the Swift accessors and compares
  it with the table-driven description; since the fixtures are built through the Swift
  initializers, that also checks construction (Swift offsets) against the table. Change
  `storageLayout` only together with the layout version in
  `main.swift`'s hash string.
- **Accessor offsets are part of TelegramCore's compiled code.** They are
  `@_alwaysEmitIntoClient`, so a TelegramApi regeneration needs TelegramCore recompiled. Bazel
  does that. SwiftPM and Xcode incremental builds were seen NOT to recompile a client whose
  inlined accessor changed. `tlVerifyClientLayout()`, called from `initializedNetwork`, carries the
  hash as an inlined literal and traps on a stale client. Clean-build clients after regenerating
  outside Bazel.
- **`Api` enums print their constructor name only** (`CustomStringConvertible`, from the table),
  never field values: `"\(value)"` bypasses the logger's redaction. Reflection metadata stays on.
  Turning it off for TelegramApi in release was measured at −188 KB and kept on by choice. The
  logger goldens pass either way.
- **Generated locals are `_tl`-prefixed** (`_tlObject`, `_tlPresent`, `_tlValue`). `tlStore` is
  generic, so a TL field shadowing an unprefixed local would compile and store the wrong value.
- **Not NSObject on purpose.** `TLObject` inherits nothing Swift can see, and the payload structs
  inherit nothing at all, so a TL field named `hash` or `description` is always the field.
- **Payload fields are read-only.** To change one, construct a new `Cons_y`.
- **The module is MRC.** SwiftPM compiles ObjC *with* ARC by default, so the SwiftPM targets pass
  `-fno-objc-arc` (`unsafeFlags`); Bazel uses `copts = ["-fno-objc-arc"]`. `TLObject.m` `#error`s
  under ARC. `-autorelease` uses `+[NSAutoreleasePool addObject:]`, because `CFAutorelease`
  recurses and crashes. References stored in payload storage are +1; Swift stores them through
  `tlStoreReference`.
- **Logger redaction depends on nested values being Swift enums**
  (`tlDescriptionFields` maps through `tlTypeRegistry`). `GoldenTests` pins the logger
  output with redaction on; `Tests/LoggerDescription.swift` is a verbatim copy of
  `TelegramCore/Sources/State/Serialization.swift` — re-copy it when that file changes.
- **Foreign reference types (C structs) were tried and rejected**: they need iOS 16.4
  (metadata kind 0x204), and multi-payload enums leak them on Swift 6.4.
- Tests: `swift test --package-path submodules/TelegramApi` after `generate-swiftpm.sh` (and
  `-c release -Xswiftc -enable-testing`), `swift test --package-path build-system/SwiftTL`;
  Bazel: `Make.py test --target //submodules/TelegramApi:TelegramApiTests`.
