# tgcalls WASM-core Phase 2: WASI module + WAMR runtime (design)

Date: 2026-07-02
Status: approved (design review in session), Phase 2 of 4
Depends on: Phase 1 (`2026-07-01-tgcalls-wasm-core-pump-design.md`), complete at
submodule `458a404` / parent `b169c794` on this branch.

## Context

Phase 1 proved the pump boundary natively: `ReferenceCallCore` (control logic,
JSON events/commands, includes only `CallCoreABI.h` + json11 + std) drives
`CallCoreHost` (PeerConnection/ADM/crypto/SCTP harness) through a C ABI, and
`InstanceV2PumpImpl` passes the full interop matrix against stock
`InstanceV2ReferenceImpl` wire-compatibly. Phase 2 makes the core an actual
runtime-loaded WASM module and freezes ABI v1.

Machine/toolchain reality (verified 2026-07-02): no wasi-sdk, wasmtime, WAMR or
emscripten present — everything is acquired hermetically through Bazel. The
core and json11 are exception-free (verified: no throw/try/catch; json11 has
only an old-MSVC `noexcept` shim), so a `-fno-exceptions` WASI build needs no
code surgery.

## Goal / success criteria

`reference-core-abi1.wasm`, built inside the Bazel graph from the same
`ReferenceCallCore.cpp`, loaded at runtime by a WAMR-backed backend selected
per call, wire-identical behavior. Done when:

1. `bazel build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
   from clean also produces the `.wasm` (genrule in the graph, `data` dep).
2. The Phase-1 matrix re-passes with the WASM core on every pump side
   (rows W1–W6 below), plus backend cross-interop rows W7–W8.
3. ABI-freeze hardening is in: `abiVersion` mismatch refusal, IPv6 ICE-URL
   fix, `stop()` hardening, deviation comments (the Phase-1 backlog).
4. Full iOS app build (`Make.py … debug_sim_arm64`) is green with WAMR + the
   WAMR backend compiled into the `TgVoipWebrtc` target (build-proof only —
   no app code calls it).

## Non-goals (Phase 2)

- No module signing, no remote delivery, no server-flag selection (Phase 3/4).
- No wasmtime: WAMR interpreter is the single runtime on every platform (one
  behavior to debug; wasmtime can join in CI later if speed demands).
- No AOT/JIT, no WASM threads/SIMD.
- No app-side wiring of the WASM backend (iOS is build-proof only).
- No kill-switch fallback: a module that fails to load/instantiate fails the
  call fast (`stateUpdated(Failed)`); graceful fallback is Phase 4.

## Architecture

```
                    ┌── InstanceV2PumpImpl (unchanged) ──┐
                    │            CallCoreHost            │
                    │   selects backend per call from    │
                    │   customParameters.wasm_core_path  │
                    │      ┌──────────┴──────────┐       │
                    │ NativeCoreBackend   WamrCoreBackend│
                    │  (linked tgcalls_    (loads .wasm  │
                    │   core_* symbols,     file, WAMR   │
                    │   Phase-1 path,       interpreter, │
                    │   zero change)        per-call     │
                    │                       instance)    │
                    └──────────┬──────────────┬──────────┘
                               │              │
                    ReferenceCallCore    reference-core-abi1.wasm
                    (native library)     = SAME ReferenceCallCore.cpp
                                           + json11.cpp
                                           + wasm_module_entry.cpp
                                           compiled by wasi-sdk genrule
```

## Components

### 1. Hermetic wasi-sdk + genrule (parent repo)

- `MODULE.bazel`: two sha256-pinned `http_archive`s for the wasi-sdk **33.0**
  release — `wasi-sdk-33.0-arm64-macos` and `wasi-sdk-33.0-arm64-linux`
  (covering the Mac dev host and the ARM64 Docker/Fargate path); each with a
  minimal `build_file_content` exporting `bin/clang++` + `share/wasi-sysroot`.
  Pins verified 2026-07-02; URLs + sha256 live in MODULE.bazel and the
  implementation plan. Host-platform `select()` picks the archive.
- `submodules/TgVoipWebrtc/BUILD`: genrule `reference_core_wasm` compiling
  exactly `ReferenceCallCore.cpp` + `third-party/json11.cpp` +
  `v2wasm/wasm_module_entry.cpp` with
  `--target=wasm32-wasip1 -std=c++17 -O2 -fno-exceptions -fno-rtti
  -mexec-model=reactor -Wl,--no-entry -I<tgcalls src root>`, output
  `reference-core-abi1.wasm`.
  Exports are declared with `__attribute__((export_name(...)))` in the entry
  file — no linker `--export` flags. The `.wasm` is a `data` dep of
  `tgcalls_cli` (built alongside, addressable as a runfile/bazel-bin path).
- `wasm_module_entry.cpp` is **never** added to the native source lists; it is
  compiled only by the genrule.

### 2. WASM module ABI (ABI v1, module form) — documented in `CallCoreABI.h`

Function pointers cannot cross the WASM boundary; the module form maps ABI v1
as (one module instance per call — the instance IS the handle):

| C ABI | Module form |
|---|---|
| `tgcalls_core_create(config, emit, user)` | export `core_init(config_ptr, config_len)`; import `env.host_emit(ptr, len)` |
| `tgcalls_core_on_event(core, data, len)` | export `core_on_event(ptr, len)` |
| `tgcalls_core_destroy(core)` | instance destruction (no export) |
| buffer passing | exports `rt_alloc(len) -> ptr`, `rt_free(ptr)`; for each event the host `rt_alloc`s, copies in, calls `core_on_event`, then `rt_free`s after it returns (the module never keeps event buffers — it copies what it retains); `host_emit` payloads are copied out by the host during the call (WASM linear-memory contract, unchanged) |

`wasm_module_entry.cpp` holds a single `ReferenceCallCore` instance (created by
`core_init`), forwards `core_on_event`, and implements `rt_alloc`/`rt_free`
over malloc. `CallCoreABI.h` gains a "Module form" doc section stating this
mapping, and its `abiVersion` sentence is made true (see hardening).

### 3. Vendored WAMR (parent repo, `third-party/wamr/`)

- WAMR **2.4.5** (2026-06-29) (exact tag + sha pinned in the implementation plan),
  Apache-2.0, vendored source subset: `core/iwasm/interpreter`,
  `core/iwasm/common`, `core/iwasm/libraries/libc-wasi` (and its uvwasi-free
  sandboxed impl), `core/shared/{platform/{darwin,linux,common/posix},
  mem-alloc,utils}`.
- `cc_library` config: `WASM_ENABLE_INTERP=1`, `WASM_ENABLE_FAST_INTERP=1`,
  `WASM_ENABLE_LIBC_WASI=1`, everything else (JIT/AOT/threads/sockets) off —
  the iOS-legal interpreter configuration. If iOS needs a platform shim beyond
  the darwin glue, it is vendored alongside.
- WASI capabilities granted to modules: **none** (no preopened dirs, no env,
  no args). libc-wasi exists only to satisfy libc's fd_write/abort plumbing;
  the host sandboxes the module's stdio to /dev/null via
  wasm_runtime_set_wasi_args_ex (without it the module would inherit real
  process stdio). Filesystem, env, args, sockets: none.

### 4. Backend seam (tgcalls submodule, `v2wasm/`)

- `CallCoreBackend.h`: small C++ interface — `create(configJson, emitFn)`,
  `onEvent(const uint8_t*, size_t)`, destructor tears down. The emit callback
  signature and queueing semantics are exactly Phase 1's (commands queued by
  the host, drained after the call returns; no re-entry).
- `NativeCoreBackend.{h,cpp}`: wraps the linked `tgcalls_core_*` functions.
  Default backend; Phase-1 behavior byte-for-byte.
- `WamrCoreBackend.{h,cpp}`: `wasm_runtime_full_init` (system allocator,
  process-once), reads the `.wasm` file, `wasm_runtime_load` +
  `wasm_runtime_instantiate` per call (stack 512 KB, module-managed heap),
  registers `env.host_emit` through `RuntimeInitArgs` at
  `wasm_runtime_full_init` (equivalent to `wasm_runtime_register_natives`),
  resolves the four exports, single `exec_env` used only from the media
  thread.
  **Trust boundary:** every `(ptr, len)` arriving from the module
  (`host_emit` args) is validated with `wasm_runtime_validate_app_addr`
  before reading; malformed traps/OOB → treated as module failure →
  `stateUpdated(Failed)` (fail-fast, no fallback in Phase 2).
- Selection in `CallCoreHost`: parse `Descriptor.config.customParameters` as
  JSON; if key `wasm_core_path` (string, non-empty) is present → WamrCoreBackend
  with that path; else NativeCoreBackend. The unmodified `customParameters`
  string still reaches the core config verbatim (the core ignores unknown keys).
- CLI: `--wasm-core <path>` / `--wasm-core2 <path>` (mirroring
  `--version`/`--version2`) set `customParameters` to
  `{"wasm_core_path":"<path>"}` on the caller / callee descriptor (wholesale —
  CLI descriptors carry no other customParameters, so no merge logic).

### 5. ABI-freeze hardening (lands before the WASM leg; Phase-1 backlog)

- **abiVersion refusal:** on `core_ready` with `abiVersion != 1`, the host
  logs LS_ERROR, sets a `_isCoreDisabled` flag (drops all further commands and
  events), and calls `stateUpdated(State::Failed)` directly — making
  `CallCoreABI.h`'s "refuse a mismatch" sentence true.
- **IPv6 ICE URLs (core):** in `ReferenceCallCore`'s ICE-server mapping, skip
  entries with empty host, and bracket hosts containing `:` as `[host]`
  (stock's `HostAsURIString()` behavior; `SocketAddress` cannot cross the
  boundary).
- **stop() hardening (host):** `RTC_DCHECK(!_isDeliveringEvent &&
  !_isProcessingCommands)` at the top of `stop()`; a second `stop()` invokes
  its completion immediately with an empty `FinalState` instead of silently
  dropping it.
- **Comments:** intentional error-path deviations from stock (SLD
  send-on-failure, SRD flush-on-failure skipped on `ok:false`) and the
  deferred-delivery ordering invariant on `deliverEvent`.
- Testbench `CLAUDE.md`: add `v2wasm/` to the project-structure list.

### 6. iOS build-proof

`WamrCoreBackend.cpp` + `CallCoreBackend`/`NativeCoreBackend` join both native
source lists (as Phase 1 files did); BOTH targets (`tgcalls_core`, which the
CLI links, and the `TgVoipWebrtc` objc_library) gain the `wamr` dep. No app code references the WAMR backend
(pump versions aren't reachable from the app in Phase 2); the gate is the full
`debug_sim_arm64` app build staying green with WAMR compiled and linked for
the iOS configuration. The `.wasm` genrule is NOT a dependency of any iOS
target.

## Validation matrix

All `tgcalls_cli --mode p2p … --quiet`, exit 0 = pass. "wasm-pump" = pump
version + `--wasm-core`(2) pointing at the bazel-built module.

| # | caller | callee | extra |
|---|---|---|---|
| W1 | 11.0.0-pump (wasm) | 11.0.0 stock | — |
| W2 | 11.0.0 stock | 11.0.0-pump (wasm) | — |
| W3 | 11.0.0-pump (wasm) | 11.0.0-pump (wasm) | — |
| W4 | 11.0.0-pump (wasm) | 11.0.0 stock | `--drop-rate 0.3 --delay 50-200 --duration 30` |
| W5 | 10.0.0-pump (wasm) | 10.0.0 stock | V1 signaling path |
| W6 | stretch | | `run-local-test.sh -n 50` symmetric wasm-pump |
| W7 | 11.0.0-pump (wasm) | 11.0.0-pump (native) | backend cross-interop |
| W8 | 11.0.0-pump (wasm) | 11.0.0-pump (wasm) | `--drop-rate 0.3 --delay 50-200 --duration 30` |

Plus native regression: Phase-1 rows 1–3 re-run (native backend untouched by
the seam refactor). Builds: CLI+module from clean, and the full iOS app build.

## Risks / open items

- **WAMR-on-iOS-config compile** is the biggest unknown retired by this phase
  (that is why the build-proof is in scope). Mitigation: interpreter-only
  config, darwin/posix glue, shim vendored if needed.
- **wasi-sdk archive fetch** adds the first bzlmod `http_archive` network
  dependency to a repo that vendors its rules — pinned by sha256, cached by
  Bazel; offline builds keep working after first fetch.
- **Interpreter performance** is a non-risk for the control plane (KB-scale
  JSON at a few events/sec; Phase-1 measurements: SDP messages < 8 KB).
- **Determinism drift native-vs-wasm** (double formatting in json11 dump,
  libc differences): W7 exercises it; if the wire logs diverge textually while
  remaining protocol-valid, that is acceptable — byte-parity is required
  against STOCK, not between backends.
- **Runaway modules are not defended in Phase 2:** interpreter-only WAMR with
  THREAD_MGR=0 has no instruction metering or interruption — an infinite loop
  in core_on_event blocks the media thread and wedges the call; memory.grow is
  bounded only by the wasm32 4 GB page cap (allocation failure is graceful).
  Defense until Phase 4 is module provenance (first-party, CLI-validated); the
  Phase-4 kill-switch design must add a host-side watchdog or instruction
  metering.

## Phasing recap (updated)

1. ~~Native pump boundary~~ (done, this branch).
2. **This spec:** hermetic WASI module + WAMR runtime + ABI v1 freeze + iOS
   build-proof.
3. iOS app integration behind an experimental flag; embedded modules;
   server-flag selection (App Store 2.5.2-compliant A/B).
4. Signed remote delivery (TestFlight/Android); dynamic `Meta::versions()`
   from module registry; kill-switch + native fallback.

## Validation results (Phase 2)

Run 2026-07-02, binary + module built via the task-4 Bazel targets
(`bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli`,
`bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm`; tgcalls submodule
commit `bd00c77`, tasks 1–4 tip). All 7 runnable matrix rows passed on the
first attempt — no core, backend, or harness fixes were required. W6 (the
mass-test stretch row) was skipped: `run-local-test.sh`'s arg parser (`case
$1 in -n|-j|-d|--drop-rate|--delay|--mode|--version) ... *) echo Usage...;
exit 1`) has no pass-through for unrecognized flags, so it cannot forward
`--wasm-core`/`--wasm-core2` to the binary; per the task brief this is
recorded as an honest skip rather than a script hack.

| # | command | exit | established | notes |
|---|---|---|---|---|
| W1 | `--mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE` | 0 | yes (0.022s) | caller Established (wasm pump) / callee Reconnecting (native stock) |
| W2 | `--mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet --wasm-core2 $WASM` | 0 | yes (0.028s) | caller Reconnecting (native stock) / callee Established (wasm pump); caller backend defaults untouched, only `--wasm-core2` set |
| W3 | `--mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM` | 0 | yes (0.040s) | both sides wasm (wasm-core2 defaults to wasm-core); both Established |
| W4 | `--mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM --wasm-core2 NONE` | 0 | yes (3.489s) | wasm pump caller vs native stock callee under 30% loss; BWE non-zero |
| W5 | `--mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE` | 0 | yes (0.021s) | V1 signaling path (ExternalSignalingConnection, no gzip) through the wasm core |
| W6 | *(skipped — see above)* | — | — | `run-local-test.sh` cannot forward `--wasm-core`; not attempted, no script changes made |
| W7 | `--mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE` | 0 | yes (0.024s) | wasm-backed caller vs native-backed callee (backend cross-interop); both Established |
| W8 | `--mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM` | 0 | yes (1.737s) | both sides wasm, 30% loss + 50-200ms delay; both Established, BWE non-zero |

All eight (well, seven-run) rows additionally reported `Errors: none` and
`BWE non-zero: yes`, matching the Phase-1 pass criteria.

**Native regression** (Phase-1 rows 1–3 re-run unmodified, no `--wasm-core`,
confirming the native backend is untouched by the seam refactor):

| # | command | exit | established | notes |
|---|---|---|---|---|
| NR1 | `--mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet` | 0 | yes (0.011s) | caller Established / callee Reconnecting |
| NR2 | `--mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet` | 0 | yes (0.012s) | caller Reconnecting / callee Established |
| NR3 | `--mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet` | 0 | yes (0.013s) | both sides Established |

All three exactly reproduce the Phase-1 results recorded in
`2026-07-01-tgcalls-wasm-core-pump-design.md` (rows 1–3): same exit codes,
same establishment pattern, no drift.

**iOS build-proof:** `debug_sim_arm64` app build (full `Make.py build`,
`appstore-configuration.json`, `--buildNumber=1`) completed successfully in a
single attempt (no retry needed) — `INFO: Build completed successfully, 5959
total actions`, `Target //Telegram:Telegram up-to-date: bazel-bin/Telegram/Telegram.ipa`,
elapsed 160s critical path. Verified `WamrCoreBackend.o` /
`NativeCoreBackend.o` were compiled under the iOS sim config object path
(`bazel-out/ios_sim_arm64-dbg-ios-sim_arm64-min13.0-.../bin/submodules/TgVoipWebrtc/_objs/TgVoipWebrtc/arc/WamrCoreBackend.o`,
distinct from the native CLI's `darwin_arm64-fastbuild` object), confirming
WAMR + the pluggable backend now compile for the iOS toolchain/configuration
— this phase's headline risk-retirement. No app code references the WAMR
backend yet (by design; Phase 3 wires the experimental flag).

Fixes applied: **0**. No wire-format, ABI, backend, or harness changes were
needed across the W-matrix, the native regression, or the iOS build. The only
non-runtime change in this task is a whitespace-only cleanup (re-indenting
two `tgcalls_core` srcs entries in `submodules/TgVoipWebrtc/BUILD` from 4 to 8
spaces to match the surrounding list, a review nit carried over from Task 4).

## Phase 3 backlog (from Phase-2 final branch review, 2026-07-02)

- Module size: build with -Os + wasm-strip when packaging for remote delivery.
- Spurious Failed after completed stop in the trap-during-stop path (suppress
  or document the post-completion stateUpdated(Failed)).
- WamrCoreBackend: comment at set_custom_data that static-ctor-time emissions
  are silently dropped (earliest legal emit is core_init).
- third-party/wamr: prune vendored-but-uncompiled utils/uncommon files or note
  them; AARCH64-only comment (add BUILD_TARGET_X86_64 + invokeNative_em64.s via
  select() if an x86_64 config ever needs it); optional CI grep asserting no
  sigaction symbol in the linked archive.
- Host-side watchdog / instruction metering design for runaway modules
  (prerequisite knowledge for the Phase-4 kill-switch).
