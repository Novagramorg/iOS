# Rust MTProto engine on iOS, part 1: bring-up

Date: 2026-10-02. Status: design approved in conversation, spec awaiting review.
Part 2 (host transport) is `2026-10-02-ios-rust-mtproto-host-transport-design.md`.

## Goal

Ship the Rust MTProto engine (`third-party/mtproto-engine`, Swift wrapper
`submodules/MTProtoRustEngine`) inside the iOS app, selectable at runtime by a developer switch in
Debug Settings that takes effect at the next launch. MtProtoKit stays the default on iOS.

Decisions taken in the brainstorm:

- **Toggle scope:** developer switch, next launch. No remote opt-in, no live hot swap (a hot swap
  also risks `AUTH_KEY_DUPLICATED`, integration.md R3).
- **Ship scope:** the engine is linked into **every** build, App Store included. The switch alone
  decides; the hidden debug menu is reachable in App Store builds, so the switch is too.
- **v1 = part 1 + part 2.** The switch is handed to dogfooders only after both parts pass the gate
  in "Dogfood gate" below. After part 1 alone it is for the team.

Success for part 1: an iOS build in which flipping the switch and relaunching runs every main-app
account on the Rust engine (unless the factory declines), never logs an account out on the way
in or out, and changes nothing for anyone who does not flip it.

## What already exists (master `4a0a739378`)

- The seam: `NetworkEngine` / `NetworkEngineSession` / `NetworkEngineFactory`
  (`TelegramCore/Sources/Network/NetworkEngine.swift`). `resolveNetworkEngine`
  (`Network.swift:389`) picks the engine once per `Network`, from the factory in
  `NetworkInitializationArguments`, the shared-data `networkEngineSettings` (`engine_v2`), and the
  `mtproto_engine_rust_disabled` app-config kill switch.
- `NetworkEngineSettings.defaultSettings` is `.rust` on macOS and `.mtProtoKit` elsewhere.
- `RustNetworkEngineFactory` declines in app extensions, behind a WEB proxy, with datacenter
  address overrides, and when the engine fails to start or reports an unknown ABI version.
  Both engines read and write the same persisted state through `MTContext`, so switching engines
  never logs the account out.
- `rules_rust` 0.74 / Rust 1.98.1 with the `aarch64-apple-ios`, `aarch64-apple-ios-sim` and
  `x86_64-apple-ios` triples is already in `MODULE.bazel` (used by wallet-engine and tlottie).
- What iOS lacks: a Bazel build of the engine and the wrapper, a factory passed from the app, and a
  switch.

"integration.md" below is `third-party/mtproto-engine/docs/research/integration.md`;
"swift-integration.md" is `third-party/mtproto-engine/docs/swift-integration.md`.

## Measured facts this design rests on

- **The Rust standard library is linked once, not once per Rust library.**
  `TelegramUIFramework` (debug_sim_arm64 build of 2026-10-02) links both `wallet_engine_archive`
  and `tlottie_archive`. Its 31,414 Rust (`_R`-mangled) symbols contain exactly one `core` crate
  (`Csi2CM0xb2QmB`), one `alloc` (`CsdY27qFpBRCe`) and one `std` (`Cs5Pz3loLmhHy`), and one copy
  each of `core::fmt::write`, `core::panicking::panic`, `std::io::stdio::_print` and the
  `__rust_alloc` shims. Cause: every `rust_static_library` is built by the same toolchain, so each
  archive embeds identical std object members, and ld64 loads an archive member only to resolve a
  still-undefined symbol. Duplication happens only when a library is LTO'd into its own archive
  (std is then internalized into that library's objects), which is what the Cargo profile's
  `lto = "thin"` does for the macOS xcframework. `swift-integration.md` §14 risk 5 ("each carries
  its own copy of std") is therefore wrong for the Bazel build.
- **Cellular accounting already works** on the engine's own sockets: commit `72d7e51f95` detects
  `pdp_ip*` from the socket's local address (`mtproto-engine/src/interface.rs`), and the wrapper
  books WWAN bytes and sets `networkType` (`RustNetworkSession.swift:470-503`). The same commit
  closed integration gaps 1, 2, 4 and 5. `swift-integration.md` §11 ("Network type always 0") and
  §12 items 1, 2, 4, 5, 6 are stale.
- `mio` 1.2.2 sets `SO_NOSIGPIPE` on Apple platforms (`src/sys/unix/net.rs:39-50`), so a write to
  a dead socket cannot raise SIGPIPE.
- The C ABI already has `mt_session_set_online`; the wrapper hardcodes `setup.online = 0`
  (`RustNetworkSession.swift:183`). With `online` false a silently dead connection is noticed
  after ~60-135 s; with `online` true the engine uses tdlib's timing (ping every
  `max(2, 1.5·rtt+1)·0.5`..`·1` s, main-session disconnect after `2.5×` that estimate,
  `mtproto-core/src/session/mod.rs:579-597`).
- A main-session 401 currently goes `.authorizationRequired` → `networkSessionAuthorizationRequired`
  → `Network.mainSessionAuthorizationRequired` → `loggedOut` (`RustNetworkSession.swift:421-425`,
  `Network.swift:1033-1036`). `MTContext.checkIfLoggedOut` (`MTContext.m:1774`) probes whether the
  server removed the permanent auth key, at most once per 60 s per datacenter, and on a confirmed
  removal reaches the same `loggedOut` through `contextLoggedOut` (`Network.swift:917-919`).

## Design

### 1. Build and packaging

**Rust: `third-party/mtproto-engine/BUILD` (new).**

- `rust_library(mtproto_core)`, `rust_library(mtproto_engine)`, and one
  `rust_static_library(mtproto_engine_ffi_archive)` for crate `mtproto_ffi`. The test server,
  netsim, bench and fuzz crates stay Cargo-only.
- `rustc_flags` pinned, not inherited from the compilation mode (as tlottie does), so
  `debug_sim_arm64` does not build the crypto at opt-level 0:
  `-Copt-level=3 -Ccodegen-units=1 -Cpanic=abort`.
- **No `-Clto`.** This is what keeps one shared std (see measured facts). The BUILD comment says
  so.
- Third-party crates come from a new crate_universe repository `mtproto_engine_crates`
  (`from_specs`, as the wallet does), every version pinned with `=` to
  `third-party/mtproto-engine/Cargo.lock`, lockfile `//third-party/mtproto-engine:Cargo.Bazel.lock`.
  It is separate from `wallet_engine_crates` so the two lockfiles move independently; crates both
  use (`aes`, `sha2`, `hmac`, `num-bigint`, ...) are compiled twice and linked as separate copies,
  which the size measurement below records.
- **Hardware crypto must be re-applied by hand**, because Bazel does not read
  `.cargo/config.toml` or target-specific Cargo features:
  - `--cfg aes_armv8` for the `aes` crate, via `crate.annotation(crate = "aes", rustc_flags = ...)`.
  - The `asm` feature of `sha2` (Cargo enables it for `cfg(target_arch = "aarch64")`), via the spec.
    If it pulls in `sha2-asm` and that build script does not cross-compile under rules_rust, the
    fallback is sha2's intrinsics backend; the instruction check in "Testing" decides.
  Without these, crypto silently runs ~15x slower.
- C module: `objc_library(name = "MTProtoEngineFFI", module_name = "MTProtoEngineFFI")` exporting
  `crates/mtproto-ffi/include/mtproto_engine.h`, depending on the archive. The module name matches
  the macOS xcframework, so the Swift sources compile unchanged on both platforms.

**Swift: `submodules/MTProtoRustEngine/BUILD` (new).**

- `swift_library(MTProtoRustEngineMapping)` (pure Swift) and `swift_library(MTProtoRustEngine)`
  (TelegramCore, MtProtoKit, SwiftSignalKit, MTProtoEngineFFI, the mapping module), both with
  `-warnings-as-errors` like the rest of the repo. The wrapper was written for SwiftPM; expect a
  warning-cleanup pass. `Package.swift` stays for macOS.
- `MTProtoRustEngineMappingTests` becomes a host `swift_test` (the `MetalPipelineCacheTests`
  pattern). The bridge and end-to-end tests stay SwiftPM-only: they need the macOS xcframework.
- `//submodules/TelegramUI:TelegramUI` depends on `MTProtoRustEngine`, so the archive lands in
  `TelegramUIFramework`, which the extensions share; no extension embeds a second copy.

### 2. Wiring and the Debug switch

- `AppDelegate.swift:586` passes `networkEngineFactory: RustNetworkEngineFactory()`. No other call
  site changes: NotificationService, Share, SiriIntents and NotificationContent keep `nil`, in
  addition to the factory's own `isAppExtension` decline. The extensions stay on MtProtoKit until
  the engine is measured there (integration.md §6.2).
- `NetworkEngineSettings.defaultSettings` stays `.mtProtoKit` on iOS.
- `DebugController.swift`, in the `isMainApp` block next to `Network X [Restart App]` and
  `Download X [Restart App]`:
  - switch `Rust MTProto [Restart App]`, writing `updateNetworkEngineSettings(accountManager:)`
    (`.rust` / `.mtProtoKit`). Next-launch semantics, no forced `exit(0)`, like its neighbours.
  - info row `Engine: <kind>` from `context.account.network.engineKind` — the engine this account
    actually got. The switch being on does not mean Rust is running (factory declines, kill
    switch); this row is how a dogfooder knows which engine a report came from. The decline reason
    is already logged by `resolveNetworkEngine` and `rustEngineImportantLog`.
- The setting is account-manager shared data, so every account follows it; each account can be
  declined individually.
- Precedence is unchanged: `mtproto_engine_rust_disabled` (per-account app config, read when
  `Network` initializes, so a newly arrived kill switch applies one launch later), then the
  factory's declines, then the switch.

### 3. Logout safety net

In `RustNetworkSession`, `.authorizationRequired` on the **main** session calls
`context.checkIfLoggedOut(datacenterId)` instead of `delegate.networkSessionAuthorizationRequired()`,
and logs the 401 text with `rustEngineImportantLog`. Worker sessions keep their existing handling.

- A genuine remote logout still logs out: the probe sees the removed key and fires
  `contextLoggedOut` → `Network.loggedOut`, the same endpoint as today, one probe later.
- Any other main-session 401 fails only that request. An engine bug that produces a bad 401 then
  costs failing requests (recoverable by flipping the switch back) instead of the session.
- This is integration.md R1's recommendation for the experimental phase. The wrapper is shared, so
  **macOS gets it too**; the Rust engine is the macOS default, so this changes macOS behaviour (in
  the safe direction).
- The decision lives in a pure helper in `MTProtoRustEngineMapping` (main → probe, never log out).

### 4. Foreground liveness

- The seam gains `NetworkEngineSession.setOnline(_ online: Bool)`. `MtProtoKitEngine`: no-op. The
  Rust wrapper: `mt_session_set_online`; the latest value is also used as `setup.online` for
  sessions created afterwards (a pure helper in the mapping module decides the creation value).
- `Network` gains an online input and forwards it to its main session and to the worker sessions
  it creates.
- `Account` drives that input from its existing `shouldKeepOnlinePresence`
  (`primary && inForeground`, `SharedWakeupManager.swift:1150`). Only the visible account gets
  fast liveness; background service tasks and secondary accounts keep the slow timing.
- Accepted risk, measured before dogfooding: tdlib's online cadence keeps the cellular radio in
  its high-power state while the app is in the foreground, where MtProtoKit lets it go idle
  between messages. If the energy cost is material, the fix is an engine timing change, not
  `online = 0`.

## Testing

Automated:

- Host `swift_test` for the mapping module, including the two new helpers: main-session 401 maps
  to "probe" and never to "log out"; a session's creation-time `online` is the latest value set
  before creation.
- Crypto instruction check on the built `TelegramUIFramework`: the engine's AES and SHA-256 code
  must contain ARMv8 `aese`/`aesd` and `sha256h` instructions. Deterministic, and it catches a
  missing `aes_armv8`/`asm` that would otherwise silently fall back to software.
- One `core`/`alloc`/`std` among the Rust symbols, as measured above.

Build gates:

- `debug_sim_arm64` and `release_arm64` green.
- `release_arm64` size of `TelegramUIFramework` and the `.ipa`, measured on the same commit with
  and without the `MTProtoRustEngine` dependency, recorded in this spec.

Manual (the user installs and drives; the implementer builds and stops):

- Switch to Rust, relaunch: `Engine: rust`, still logged in, messages send and receive. Switch
  back: still logged in.
- Media download; foreground/background; airplane mode on/off; wifi↔cellular handoff on a device.
- SOCKS5 and MTProxy work. A WEB proxy shows `Engine: mtProtoKit` (expected until part 2).
- The kill switch forces MtProtoKit.
- Energy gauge, idle chat list on cellular, Rust vs MtProtoKit.

Done: all of the above pass.

## Dogfood gate (part 1 + part 2)

The switch goes to dogfooders only when part 1 and part 2 are both done and:

1. The host-transport torture suite shows zero wrong results, double completions and duplicate
   executions.
2. Rust over the host transport is no worse than MtProtoKit over the same interface in the bench
   quick suite (p50/p95 latency, throughput).
3. The online-ping energy cost is measured and accepted.

## Out of scope

- Remote opt-in or percentage rollout; live engine hot swap.
- The engine in app extensions.
- Datacenter address overrides (the factory keeps declining).
- MtProtoKit's DNS-over-HTTPS for proxy hostnames (`MTDNS resolveHostnameUniversal`); the
  engine's own sockets use the system resolver, as on macOS today.

## Docs

- `swift-integration.md`: mark §12 items 1, 2, 4, 5, 6 and the §11 "Network type" row as fixed by
  `72d7e51f95`; correct §14 risk 5 (std is shared under Bazel; duplication needs LTO into the
  archive); add the iOS build.
- CLAUDE.md: a short "Rust MTProto engine on iOS" section with the load-bearing invariants (no
  `-Clto`; the crypto cfg/feature flags; the Debug switch and `Engine:` row; the logout probe).
