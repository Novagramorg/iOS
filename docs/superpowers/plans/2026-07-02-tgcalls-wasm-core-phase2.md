# tgcalls WASM-core Phase 2 (WASI module + WAMR runtime) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compile `ReferenceCallCore` to `reference-core-abi1.wasm` inside the Bazel graph, load it at runtime through a WAMR-interpreter backend selected per call, freeze ABI v1 (hardening first), and prove the iOS app still builds with WAMR linked in.

**Architecture:** Per the approved spec (`docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-phase2-design.md`): hermetic sha256-pinned wasi-sdk `http_archive`s + a `cmd_bash` genrule produce the module; vendored WAMR 2.4.5 (interpreter-only, no signal handlers) runs it; a new `CallCoreBackend` seam in `CallCoreHost` picks Native vs WAMR from `customParameters.wasm_core_path`.

**Tech Stack:** wasi-sdk 33.0, WAMR-2.4.5 (fast interpreter + libc-wasi), Bazel 8.4.2 bzlmod, C++17, json11.

## Global Constraints

- Working directory: worktree root `/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch`. Two repos as in Phase 1: `v2wasm/*`, `tools/cli/*`, tgcalls `CLAUDE.md` → tgcalls submodule (branch `tgcalls-wasm-core-sketch`); `MODULE.bazel`, `submodules/TgVoipWebrtc/BUILD`, `third-party/wamr/**`, docs → parent repo.
- **Wire parity frozen:** no signaling JSON key or value strings change, ever.
- **Core discipline unchanged:** `ReferenceCallCore.*` and `wasm_module_entry.cpp` include only `v2wasm/CallCoreABI.h`, `third-party/json11.hpp`, C++17 std.
- Stock `v2/` files read-only. Vendored WAMR sources are read-only after Task 3 lands them (config via defines/BUILD only; any unavoidable source patch is a recorded deviation).
- **Pinned artifacts (verified 2026-07-02):**
  - wasi-sdk 33.0 arm64-macos: sha256 `85c997a2665ead91673b5bb88b7d0df3fc8900df3bfa244f720d478187bbdc78`
  - wasi-sdk 33.0 arm64-linux: sha256 `4f98ee738c7abb45c81a94d1461fc53cc569d1cd01498951c8184d841a027844`
  - WAMR-2.4.5 source tarball (`https://github.com/bytecodealliance/wasm-micro-runtime/archive/refs/tags/WAMR-2.4.5.tar.gz`): sha256 `1ab09d51099f276ca4a1d6629f6b589aab2bd0caa01445e05031a4bed22c199b`
  - An extracted copy already exists at `/private/tmp/claude-501/-Users-isaac-build-telegram-telegram-ios/2a15c336-a5e4-44c4-9d41-e097c735f342/scratchpad/wasm-micro-runtime-WAMR-2.4.5` (its CMake files are the reference for compile-friction fixes).
- **iOS safety invariant:** WAMR builds with `WASM_DISABLE_HW_BOUND_CHECK=1` (+ stack variant) — no signal handlers may be installed in the app process.
- Builds: `./build-input/bazel-8.4.2-darwin-arm64 build <target>`; full app check is the Make.py `debug_sim_arm64` command from the repo CLAUDE.md (needs `source ~/.zshrc`).
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Test cycle: bazel compile → CLI matrix (exit 0 + "Call established: yes" + "BWE non-zero: yes"). Bash timeouts ≥ 120s for call runs.

---

### Task 1: ABI-freeze hardening (native, before any WASM)

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h` (add `_isCoreDisabled`)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp` (refusal, stop hardening, comments)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp` (IPv6 fix, comments)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h` (truthful refusal wording + module-form section)
- Modify: `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` (project-structure entry)

**Interfaces:**
- Consumes: Phase-1 code as committed (submodule HEAD `458a404`).
- Produces: `_isCoreDisabled` gating semantics that Task 4's backend failure path reuses (`CallCoreHost::disableCoreWithFailure()` — defined here, called from more places later).

- [ ] **Step 1: Host-side refusal + disable helper.** In `CallCoreHost.h`, next to `bool _isProcessingCommands = false;` add:

```cpp
    bool _isCoreDisabled = false;
```

and in the method declarations (after `void emitErrorEvent(...)`):

```cpp
    void disableCoreWithFailure(std::string const &reason);
```

In `CallCoreHost.cpp`, replace the `core_ready` branch of `executeCommand`:

```cpp
    if (type == "core_ready") {
        if ((int)command["abiVersion"].number_value() != 1) {
            disableCoreWithFailure("core ABI version mismatch");
        }
    }
```

and add the helper (next to `emitErrorEvent`):

```cpp
void CallCoreHost::disableCoreWithFailure(std::string const &reason) {
    RTC_LOG(LS_ERROR) << "CallCoreHost: disabling core: " << reason;
    _isCoreDisabled = true;
    _pendingCommands.clear();
    if (_stateUpdated) {
        _stateUpdated(State::Failed);
    }
}
```

Gate the pump on it: in `deliverEventNow` extend the early return to
`if (!_core || _isStopped.load() || _isCoreDisabled) {`, and in
`processPendingCommands` change the loop condition to
`while (!_pendingCommands.empty() && !_isCoreDisabled) {`.

- [ ] **Step 2: stop() hardening.** Replace `CallCoreHost::stop` with:

```cpp
void CallCoreHost::stop(std::function<void(FinalState)> completion) {
    // stop() must arrive as its own media-thread task, never from inside the
    // pump (deliverEventNow below bypasses deliverEvent's deferral guard).
    RTC_DCHECK(!_isDeliveringEvent && !_isProcessingCommands);
    if (_isStopped.load()) {
        // Double stop: the first call owns the core shutdown; complete
        // immediately instead of silently dropping the completion.
        if (completion) {
            completion(FinalState());
        }
        return;
    }
    _stopCompletion = std::move(completion);
    deliverEventNow({ {"@type", "stop"} });
    _isStopped = true;
}
```

- [ ] **Step 3: deviation/ordering comments (host).** Above `deliverEvent`'s deferral branch add:

```cpp
    // Ordering invariant: an event deferred here (raised mid-drain) may be
    // overtaken by a directly-delivered event from an already-queued media
    // task. Today every consumer is gated by the core's negotiation flags
    // (_isMakingOffer/_isSettingRemoteAnswerPending), which absorb the
    // reorder; revisit if a new event type carries ordering-sensitive state.
```

Above `OnRenegotiationNeeded` in the delegate add:

```cpp
    // Stock wraps this body in PostTask (InstanceV2ReferenceImpl.cpp:483).
    // Here deliverEvent's deferral guard provides the equivalent protection:
    // any synchronous fire from inside command execution is deferred.
```

- [ ] **Step 4: deviation comments + IPv6 fix (core).** In `ReferenceCallCore.cpp`, in the `pc_set_local_done` handler add above the `ok` check:

```cpp
        // Deviation from stock: stock sends the local description without
        // checking the SLD error (InstanceV2ReferenceImpl.cpp:888-901); we
        // skip the send on failure. Same below for pc_set_remote_done: stock
        // flushes candidates/answers offers even on SRD failure.
```

In the constructor's ICE-server loop, replace the host extraction:

```cpp
        const auto rawHost = stringField(server, "host");
        if (rawHost.empty()) {
            continue;
        }
        // Stock validates via SocketAddress::IsComplete() and brackets IPv6
        // literals via HostAsURIString(); SocketAddress cannot cross the
        // boundary, so replicate the URI form here.
        const auto host = (rawHost.find(':') != std::string::npos)
            ? "[" + rawHost + "]"
            : rawHost;
```

(the existing `"turn:" + host + ":" + port` / `"stun:" + ...` lines then use this `host` unchanged — delete the old `const auto host = stringField(server, "host");` line).

- [ ] **Step 5: ABI header truth + module form.** In `CallCoreABI.h`:
  1. Replace the sentence `core echoes it in "core_ready" and the host refuses a mismatch.` with `core echoes it in "core_ready"; on mismatch the host disables the core (drops all further commands/events) and reports the call failed.`
  2. Append to the big doc comment, before the closing line of the block:

```c
// Module form (WASM). Function pointers cannot cross the module boundary;
// a .wasm module implements ABI v1 as (one module instance per call — the
// instance IS the handle):
//   exports:  core_init(config_ptr: i32, config_len: i32)
//             core_on_event(ptr: i32, len: i32)
//             rt_alloc(len: i32) -> i32
//             rt_free(ptr: i32)
//   imports:  env.host_emit(ptr: i32, len: i32)
// For each event the host rt_allocs, copies in, calls core_on_event, then
// rt_frees after it returns; the module copies anything it retains.
// host_emit payloads are copied out by the host during the call.
// tgcalls_core_destroy maps to instance destruction (no export).
```

- [ ] **Step 6: CLAUDE.md entry.** In `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md`, in the "Project Structure" list add after the `tgcalls/v2/` line:

```markdown
- `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/` — pump-boundary call core: `CallCoreABI.h` (C ABI v1), `ReferenceCallCore` (portable control logic), `CallCoreHost` (harness), `InstanceV2PumpImpl` (versions `10.0.0-pump`/`11.0.0-pump`, wire-compatible with 10.0.0/11.0.0); Phase 2 adds the `reference-core-abi1.wasm` module + WAMR backend
```

- [ ] **Step 7: Build + native regression.**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | tail -3
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo exit=$?
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet; echo exit=$?
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet; echo exit=$?
```

Expected: build success + three `exit=0`.

- [ ] **Step 8: Commit (submodule).**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp tgcalls/v2wasm/ReferenceCallCore.cpp tgcalls/v2wasm/CallCoreABI.h CLAUDE.md && \
git commit -m "feat(v2wasm): ABI v1 freeze hardening

abiVersion mismatch now disables the core and fails the call (header text
made true); stop() asserts pump invariants + handles double-stop; IPv6 ICE
hosts bracketed per stock HostAsURIString; intentional stock deviations
documented; CLAUDE.md gains the v2wasm entry.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
```

---

### Task 2: Hermetic wasi-sdk + `reference-core-abi1.wasm` genrule

**Files:**
- Modify: `MODULE.bazel` (parent repo root — add http_archive rule + two SDK repos)
- Modify: `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-phase2-design.md` (pin amendment 25.0→33.0, 2.3→2.4.5)
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp` (submodule; WASM-only)
- Modify: `submodules/TgVoipWebrtc/BUILD` (genrule `reference_core_wasm`)

**Interfaces:**
- Consumes: `ReferenceCallCore` class (`ReferenceCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit)`, `void onEvent(json11::Json const &)`).
- Produces: bazel target `//submodules/TgVoipWebrtc:reference_core_wasm` → output file `bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm` with exports `core_init`/`core_on_event`/`rt_alloc`/`rt_free` and import `env.host_emit` (Task 4's `WamrCoreBackend` resolves exactly these; Task 5 passes the bazel-bin path to `--wasm-core`).

- [ ] **Step 1: Spec pin amendment.** In the Phase-2 spec, replace `wasi-sdk **25.0**` with `wasi-sdk **33.0**` and `WAMR **2.3 series**` with `WAMR **2.4.5** (2026-06-29)`, and replace the sentence `Exact URLs + sha256 values are recorded in the implementation plan at pin time.` with `Pins verified 2026-07-02; URLs + sha256 live in MODULE.bazel and the implementation plan.`

- [ ] **Step 2: MODULE.bazel repos.** After the existing `http_file = use_repo_rule(...)` line add:

```python
http_archive = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_WASI_SDK_BUILD = """
exports_files(["bin/clang++"])
filegroup(
    name = "all_files",
    srcs = glob(["bin/**", "lib/**", "share/**"]),
    visibility = ["//visibility:public"],
)
"""

http_archive(
    name = "wasi_sdk_macos",
    urls = ["https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-arm64-macos.tar.gz"],
    sha256 = "85c997a2665ead91673b5bb88b7d0df3fc8900df3bfa244f720d478187bbdc78",
    strip_prefix = "wasi-sdk-33.0-arm64-macos",
    build_file_content = _WASI_SDK_BUILD,
)

http_archive(
    name = "wasi_sdk_linux",
    urls = ["https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-arm64-linux.tar.gz"],
    sha256 = "4f98ee738c7abb45c81a94d1461fc53cc569d1cd01498951c8184d841a027844",
    strip_prefix = "wasi-sdk-33.0-arm64-linux",
    build_file_content = _WASI_SDK_BUILD,
)
```

Note: bzlmod may reject a top-level string variable between repo rules — if `_WASI_SDK_BUILD = ...` errors ("name ... is not defined" or assignment restriction), inline the string literal into both `build_file_content` attributes verbatim.

- [ ] **Step 3: WASM entry file.** Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp`:

```cpp
// ABI v1 "module form" entry points (see CallCoreABI.h). This file is
// compiled ONLY for wasm32 by the reference_core_wasm genrule — it must
// never be added to the native source lists. One module instance per call:
// the instance is the handle, so state is a single global core.

#include "v2wasm/ReferenceCallCore.h"

#include "third-party/json11.hpp"

#include <cstdint>
#include <cstdlib>
#include <memory>
#include <string>

extern "C" {
__attribute__((import_module("env"), import_name("host_emit")))
void host_emit(const uint8_t *data, size_t len);
}

namespace {

std::unique_ptr<tgcalls::v2wasm::ReferenceCallCore> globalCore;

} // namespace

extern "C" {

__attribute__((export_name("rt_alloc")))
uint8_t *rt_alloc(size_t len) {
    return (uint8_t *)malloc(len);
}

__attribute__((export_name("rt_free")))
void rt_free(uint8_t *ptr) {
    free(ptr);
}

__attribute__((export_name("core_init")))
void core_init(const uint8_t *configJson, size_t len) {
    std::string parsingError;
    const auto config = json11::Json::parse(std::string((const char *)configJson, len), parsingError);
    globalCore = std::make_unique<tgcalls::v2wasm::ReferenceCallCore>(config, [](json11::Json::object &&command) {
        const std::string serialized = json11::Json(std::move(command)).dump();
        host_emit((const uint8_t *)serialized.data(), serialized.size());
    });
}

__attribute__((export_name("core_on_event")))
void core_on_event(const uint8_t *data, size_t len) {
    if (!globalCore || !data) {
        return;
    }
    std::string parsingError;
    const auto event = json11::Json::parse(std::string((const char *)data, len), parsingError);
    if (!event.is_object()) {
        return;
    }
    globalCore->onEvent(event);
}

} // extern "C"
```

(`ReferenceCallCore.cpp`'s existing `tgcalls_core_*` wrappers also compile into the module as dead code — they are not `export_name`-annotated, so they are not exported; harmless.)

- [ ] **Step 4: Genrule.** In `submodules/TgVoipWebrtc/BUILD`, near the top after the `sources = glob(...)` block, add:

```python
_WASM_CORE_SRCS = [
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.h",
    "tgcalls/tgcalls/v2wasm/CallCoreABI.h",
    "tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp",
    "tgcalls/tgcalls/third-party/json11.cpp",
    "tgcalls/tgcalls/third-party/json11.hpp",
]

_WASM_CORE_CMD = """
set -e
SDK_CLANG="$(execpath {sdk}//:bin/clang++)"
SDK_DIR="$$(cd "$$(dirname "$$SDK_CLANG")/.." && pwd)"
"$$SDK_CLANG" --target=wasm32-wasip1 --sysroot="$$SDK_DIR/share/wasi-sysroot" \\
    -std=c++17 -O2 -fno-exceptions -fno-rtti \\
    -mexec-model=reactor -Wl,--no-entry \\
    -Isubmodules/TgVoipWebrtc/tgcalls/tgcalls \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/third-party/json11.cpp \\
    -o $@
"""

genrule(
    name = "reference_core_wasm",
    srcs = _WASM_CORE_SRCS + select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:all_files"],
        "//conditions:default": ["@wasi_sdk_macos//:all_files"],
    }),
    outs = ["reference-core-abi1.wasm"],
    cmd_bash = select({
        "@platforms//os:linux": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_linux"),
        "//conditions:default": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_macos"),
    }),
    tools = select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:bin/clang++"],
        "//conditions:default": ["@wasi_sdk_macos//:bin/clang++"],
    }),
    visibility = ["//visibility:public"],
)
```

Friction rules: if `$(execpath @wasi_sdk_macos//:bin/clang++)` in a `tools`-referenced select errors, move the clang++ label into `srcs` and keep `$(execpath ...)`; if `--target=wasm32-wasip1` is rejected, use `wasm32-wasi`; the Linux branch is best-effort in this phase (compile-verified only if a Linux box is handy — macOS is the validation platform). Record deviations.

- [ ] **Step 5: Build + verify the module.**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc:reference_core_wasm 2>&1 | tail -3
xxd -l 8 bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
ls -la bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
```

Expected: build success; first bytes `0061 736d` (`\0asm` magic + version); size plausibly 150–600 KB. (First run downloads the ~150 MB SDK archive — allow ~5 min.)

- [ ] **Step 6: Commit (both repos).**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/wasm_module_entry.cpp && \
git commit -m "feat(v2wasm): wasm32 module entry — ABI v1 module form

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add MODULE.bazel submodules/TgVoipWebrtc/BUILD docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-phase2-design.md && \
git commit -m "build(tgcalls): hermetic wasi-sdk 33.0 + reference-core-abi1.wasm genrule

sha256-pinned arm64-macos/arm64-linux SDK archives; module built in-graph
from ReferenceCallCore + json11 + wasm entry (reactor, no-entry, -fno-exceptions).
Spec pins amended 25.0->33.0 / 2.3->2.4.5.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Vendor WAMR 2.4.5 (interpreter-only) + `//third-party/wamr:wamr`

**Files:**
- Create: `third-party/wamr/**` (parent repo — vendored subset + LICENSE)
- Create: `third-party/wamr/BUILD`

**Interfaces:**
- Consumes: pinned WAMR tarball (Global Constraints; extracted copy in the scratchpad).
- Produces: `cc_library //third-party/wamr:wamr` exposing `wasm_export.h` (include path `third-party/wamr/core/iwasm/include`); Task 4's `WamrCoreBackend.cpp` does `#include "wasm_export.h"` and uses `wasm_runtime_full_init/load/instantiate/create_exec_env/lookup_function/call_wasm/register_natives/set_custom_data/get_custom_data/addr_app_to_native/module_free`-family APIs.

- [ ] **Step 1: Vendor the subset.** From the worktree root (uses the scratchpad copy; re-download + `shasum -c` against the pinned sha256 if it is gone):

```bash
S=/private/tmp/claude-501/-Users-isaac-build-telegram-telegram-ios/2a15c336-a5e4-44c4-9d41-e097c735f342/scratchpad/wasm-micro-runtime-WAMR-2.4.5
mkdir -p third-party/wamr/core
cp $S/LICENSE third-party/wamr/
cp $S/core/version.h third-party/wamr/core/
for d in \
  core/iwasm/include core/iwasm/common core/iwasm/interpreter \
  core/iwasm/libraries/libc-wasi \
  core/shared/platform/include core/shared/platform/common \
  core/shared/platform/darwin core/shared/platform/linux \
  core/shared/mem-alloc core/shared/utils; do
  mkdir -p "third-party/wamr/$(dirname $d)" && cp -R "$S/$d" "third-party/wamr/$d"
done
find third-party/wamr \( -name "*.cmake" -o -name "SConscript" -o -name "CMakeLists.txt" \) -delete
du -sh third-party/wamr
```

Expected: a few MB. (Keep `core/iwasm/common/arch/` — the `.s` trampolines come with the `common` copy.)

- [ ] **Step 2: BUILD file.** Create `third-party/wamr/BUILD`:

```python
# WAMR 2.4.5 (Apache-2.0), interpreter-only configuration.
# iOS-safe: no JIT/AOT, no signal handlers (HW bound check disabled).
# Sources are vendored verbatim; configuration happens here via defines only.

wamr_copts = [
    "-Ithird-party/wamr/core",
    "-Ithird-party/wamr/core/iwasm/include",
    "-Ithird-party/wamr/core/iwasm/common",
    "-Ithird-party/wamr/core/iwasm/interpreter",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src",
    "-Ithird-party/wamr/core/shared/platform/include",
    "-Ithird-party/wamr/core/shared/mem-alloc",
    "-Ithird-party/wamr/core/shared/utils",
    "-DWASM_ENABLE_INTERP=1",
    "-DWASM_ENABLE_FAST_INTERP=1",
    "-DWASM_ENABLE_LIBC_WASI=1",
    "-DWASM_ENABLE_LIBC_BUILTIN=0",
    "-DWASM_ENABLE_MINI_LOADER=0",
    "-DWASM_ENABLE_AOT=0",
    "-DWASM_ENABLE_JIT=0",
    "-DWASM_ENABLE_FAST_JIT=0",
    "-DWASM_ENABLE_SIMD=0",
    "-DWASM_ENABLE_REF_TYPES=1",
    "-DWASM_ENABLE_BULK_MEMORY=1",
    "-DWASM_ENABLE_SHARED_MEMORY=0",
    "-DWASM_ENABLE_THREAD_MGR=0",
    "-DWASM_ENABLE_MULTI_MODULE=0",
    "-DWASM_ENABLE_MODULE_INST_CONTEXT=1",
    "-DWASM_DISABLE_HW_BOUND_CHECK=1",
    "-DWASM_DISABLE_STACK_HW_BOUND_CHECK=1",
    "-DBUILD_TARGET_AARCH64=1",
    "-DBUILD_TARGET=\\\"AARCH64\\\"",
    "-w",
] + select({
    "@platforms//os:linux": ["-DBH_PLATFORM_LINUX", "-Ithird-party/wamr/core/shared/platform/linux"],
    "//conditions:default": ["-DBH_PLATFORM_DARWIN", "-Ithird-party/wamr/core/shared/platform/darwin"],
})

cc_library(
    name = "wamr",
    srcs = glob([
        "core/iwasm/common/*.c",
        "core/iwasm/libraries/libc-wasi/*.c",
        "core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/*.c",
        "core/shared/mem-alloc/*.c",
        "core/shared/mem-alloc/ems/*.c",
        "core/shared/utils/*.c",
        "core/shared/platform/common/posix/*.c",
    ]) + [
        "core/iwasm/interpreter/wasm_interp_fast.c",
        "core/iwasm/interpreter/wasm_loader.c",
        "core/iwasm/interpreter/wasm_runtime.c",
        "core/iwasm/common/arch/invokeNative_aarch64.s",
    ] + select({
        "@platforms//os:linux": ["core/shared/platform/linux/platform_init.c"],
        "//conditions:default": ["core/shared/platform/darwin/platform_init.c"],
    }),
    hdrs = glob(["core/**/*.h", "LICENSE"]),
    copts = wamr_copts,
    includes = ["core/iwasm/include"],
    visibility = ["//visibility:public"],
)
```

Friction rules (record each as a deviation): missing-symbol/undefined-macro errors are resolved by consulting the scratchpad copy's `*.cmake` files (`build-scripts/config_common.cmake`, `core/iwasm/iwasm.cmake`, `.../libc_wasi.cmake`) for the source or define the official build adds under this exact config — mirror that, never hand-patch vendored sources. Likely candidates: an extra define (`WASM_ENABLE_*=0` family is large; add `=0` defines as demanded), `core/shared/utils/uncommon/*` (only if an undefined `bh_read_file`-style symbol appears — we do not use it), or `wasm_c_api.c`'s internal headers.

- [ ] **Step 3: Compile it (macOS).**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //third-party/wamr:wamr 2>&1 | tail -5
```

Expected: `Build completed successfully`. Iterate via the friction rules until green.

- [ ] **Step 4: Commit (parent).**

```bash
git add third-party/wamr && \
git commit -m "build(third-party): vendor WAMR 2.4.5 interpreter-only subset

Apache-2.0; fast-interp + libc-wasi sandbox; JIT/AOT/threads off;
HW bound check disabled (no signal handlers — iOS-safe). Source tarball
sha256 1ab09d51099f276ca4a1d6629f6b589aab2bd0caa01445e05031a4bed22c199b.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Backend seam — `CallCoreBackend` + Native/WAMR backends + CLI flags

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreBackend.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/NativeCoreBackend.h/.cpp`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/WamrCoreBackend.h/.cpp`
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h` (swap `TgcallsCallCore *_core` → backend; drop trampoline decl)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp` (backend selection + create/onEvent/destroy paths)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tools/cli/main.cpp` (`--wasm-core`/`--wasm-core2`)
- Modify: `submodules/TgVoipWebrtc/BUILD` (two new .cpp in both lists; `wamr` dep on `tgcalls_core` AND `TgVoipWebrtc`)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tools/cli/BUILD` (`data = ["//submodules/TgVoipWebrtc:reference_core_wasm"]` on `tgcalls_cli`)

**Interfaces:**
- Consumes: `//third-party/wamr:wamr` (`wasm_export.h`), Task 1's `disableCoreWithFailure(reason)`, Task 2's module exports.
- Produces: `class CallCoreBackend { using EmitFn = std::function<void(const uint8_t *, size_t)>; virtual bool create(std::string const &configJson, EmitFn emit) = 0; virtual bool onEvent(const uint8_t *data, size_t len) = 0; }` (a `false` return = fatal core failure); CLI flags Task 5 uses.

- [ ] **Step 1: The interface.** Create `CallCoreBackend.h`:

```cpp
#ifndef TGCALLS_V2WASM_CALL_CORE_BACKEND_H
#define TGCALLS_V2WASM_CALL_CORE_BACKEND_H

#include <cstdint>
#include <functional>
#include <string>

namespace tgcalls {

// Backend abstraction over the ABI-v1 call core: native (linked) or WASM
// (runtime-loaded module). Emit semantics are the ABI's: the callback fires
// only from inside create()/onEvent() on the calling thread; the host queues
// emitted commands and executes them after the call returns. A false return
// from create()/onEvent() is a fatal core failure — the host disables the
// core and fails the call (no fallback in Phase 2).
class CallCoreBackend {
public:
    using EmitFn = std::function<void(const uint8_t *, size_t)>;

    virtual ~CallCoreBackend() = default;

    virtual bool create(std::string const &configJson, EmitFn emit) = 0;
    virtual bool onEvent(const uint8_t *data, size_t len) = 0;
};

} // namespace tgcalls

#endif
```

- [ ] **Step 2: Native backend.** `NativeCoreBackend.h`:

```cpp
#ifndef TGCALLS_V2WASM_NATIVE_CORE_BACKEND_H
#define TGCALLS_V2WASM_NATIVE_CORE_BACKEND_H

#include "v2wasm/CallCoreBackend.h"
#include "v2wasm/CallCoreABI.h"

namespace tgcalls {

// The linked-in ReferenceCallCore, via the C ABI. Phase-1 behavior.
class NativeCoreBackend final : public CallCoreBackend {
public:
    ~NativeCoreBackend() override;

    bool create(std::string const &configJson, EmitFn emit) override;
    bool onEvent(const uint8_t *data, size_t len) override;

private:
    static void emitTrampoline(void *userData, const uint8_t *data, size_t len);

    TgcallsCallCore *_core = nullptr;
    EmitFn _emit;
};

} // namespace tgcalls

#endif
```

`NativeCoreBackend.cpp`:

```cpp
#include "v2wasm/NativeCoreBackend.h"

namespace tgcalls {

NativeCoreBackend::~NativeCoreBackend() {
    if (_core) {
        tgcalls_core_destroy(_core);
        _core = nullptr;
    }
}

void NativeCoreBackend::emitTrampoline(void *userData, const uint8_t *data, size_t len) {
    auto backend = static_cast<NativeCoreBackend *>(userData);
    if (backend->_emit) {
        backend->_emit(data, len);
    }
}

bool NativeCoreBackend::create(std::string const &configJson, EmitFn emit) {
    _emit = std::move(emit);
    _core = tgcalls_core_create(configJson.c_str(), &NativeCoreBackend::emitTrampoline, this);
    return _core != nullptr;
}

bool NativeCoreBackend::onEvent(const uint8_t *data, size_t len) {
    if (!_core) {
        return false;
    }
    tgcalls_core_on_event(_core, data, len);
    return true;
}

} // namespace tgcalls
```

- [ ] **Step 3: WAMR backend.** `WamrCoreBackend.h`:

```cpp
#ifndef TGCALLS_V2WASM_WAMR_CORE_BACKEND_H
#define TGCALLS_V2WASM_WAMR_CORE_BACKEND_H

#include "v2wasm/CallCoreBackend.h"

#include <vector>

#include "wasm_export.h"

namespace tgcalls {

// Runs the ABI-v1 module form (reference-core-abi1.wasm) in the WAMR fast
// interpreter. One module instance per call; all calls on the media thread.
// Trust boundary: host_emit buffers are range-validated by WAMR ("(*~)"
// native signature) before we copy them out; a trap or missing export is a
// fatal core failure (create/onEvent return false).
class WamrCoreBackend final : public CallCoreBackend {
public:
    explicit WamrCoreBackend(std::string modulePath);
    ~WamrCoreBackend() override;

    bool create(std::string const &configJson, EmitFn emit) override;
    bool onEvent(const uint8_t *data, size_t len) override;

private:
    static void hostEmitNative(wasm_exec_env_t execEnv, uint8_t *data, uint32_t len);
    bool callCoreFunction(wasm_function_inst_t function, const uint8_t *data, size_t len);

    std::string _modulePath;
    EmitFn _emit;

    std::vector<uint8_t> _moduleBytes;
    wasm_module_t _module = nullptr;
    wasm_module_inst_t _instance = nullptr;
    wasm_exec_env_t _execEnv = nullptr;
    wasm_function_inst_t _coreInit = nullptr;
    wasm_function_inst_t _coreOnEvent = nullptr;
    wasm_function_inst_t _rtAlloc = nullptr;
    wasm_function_inst_t _rtFree = nullptr;
};

} // namespace tgcalls

#endif
```

`WamrCoreBackend.cpp`:

```cpp
#include "v2wasm/WamrCoreBackend.h"

#include <cstdio>
#include <cstring>

#include "rtc_base/logging.h"

namespace tgcalls {

namespace {

bool ensureWamrRuntime() {
    static bool initialized = []() {
        RuntimeInitArgs initArgs;
        memset(&initArgs, 0, sizeof(initArgs));
        initArgs.mem_alloc_type = Alloc_With_System_Allocator;

        // "(*~)": WAMR validates the (ptr, len) buffer range inside module
        // memory and passes a native pointer — the trust-boundary check.
        static NativeSymbol nativeSymbols[] = {
            { "host_emit", (void *)WamrCoreBackend_hostEmitThunk, "(*~)", nullptr },
        };
        initArgs.native_module_name = "env";
        initArgs.native_symbols = nativeSymbols;
        initArgs.n_native_symbols = 1;

        return wasm_runtime_full_init(&initArgs);
    }();
    return initialized;
}

} // namespace

extern "C" void WamrCoreBackend_hostEmitThunk(wasm_exec_env_t execEnv, uint8_t *data, uint32_t len);

void WamrCoreBackend::hostEmitNative(wasm_exec_env_t execEnv, uint8_t *data, uint32_t len) {
    auto instance = wasm_runtime_get_module_inst(execEnv);
    auto backend = static_cast<WamrCoreBackend *>(wasm_runtime_get_custom_data(instance));
    if (backend && backend->_emit) {
        backend->_emit(data, len);
    }
}

extern "C" void WamrCoreBackend_hostEmitThunk(wasm_exec_env_t execEnv, uint8_t *data, uint32_t len) {
    tgcalls::WamrCoreBackend::hostEmitNative(execEnv, data, len);
}

WamrCoreBackend::WamrCoreBackend(std::string modulePath) :
_modulePath(std::move(modulePath)) {
}

WamrCoreBackend::~WamrCoreBackend() {
    if (_execEnv) {
        wasm_runtime_destroy_exec_env(_execEnv);
    }
    if (_instance) {
        wasm_runtime_deinstantiate(_instance);
    }
    if (_module) {
        wasm_runtime_unload(_module);
    }
    // The process-wide runtime stays initialized (shared across calls).
}

bool WamrCoreBackend::create(std::string const &configJson, EmitFn emit) {
    _emit = std::move(emit);

    if (!ensureWamrRuntime()) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: runtime init failed";
        return false;
    }

    FILE *file = fopen(_modulePath.c_str(), "rb");
    if (!file) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: cannot open module: " << _modulePath;
        return false;
    }
    fseek(file, 0, SEEK_END);
    const long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    _moduleBytes.resize((size_t)size);
    const size_t read = fread(_moduleBytes.data(), 1, (size_t)size, file);
    fclose(file);
    if (read != (size_t)size || size <= 0) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: short read of module";
        return false;
    }

    char error[128] = {0};
    _module = wasm_runtime_load(_moduleBytes.data(), (uint32_t)_moduleBytes.size(), error, sizeof(error));
    if (!_module) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: load failed: " << error;
        return false;
    }
    _instance = wasm_runtime_instantiate(_module, 512 * 1024, 0, error, sizeof(error));
    if (!_instance) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: instantiate failed: " << error;
        return false;
    }
    wasm_runtime_set_custom_data(_instance, this);
    _execEnv = wasm_runtime_create_exec_env(_instance, 512 * 1024);
    if (!_execEnv) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: exec env failed";
        return false;
    }

    // WASI reactor protocol: run C++ static constructors if the export exists.
    if (auto initialize = wasm_runtime_lookup_function(_instance, "_initialize")) {
        if (!wasm_runtime_call_wasm(_execEnv, initialize, 0, nullptr)) {
            RTC_LOG(LS_ERROR) << "WamrCoreBackend: _initialize trapped: " << wasm_runtime_get_exception(_instance);
            return false;
        }
    }

    _coreInit = wasm_runtime_lookup_function(_instance, "core_init");
    _coreOnEvent = wasm_runtime_lookup_function(_instance, "core_on_event");
    _rtAlloc = wasm_runtime_lookup_function(_instance, "rt_alloc");
    _rtFree = wasm_runtime_lookup_function(_instance, "rt_free");
    if (!_coreInit || !_coreOnEvent || !_rtAlloc || !_rtFree) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: missing required export";
        return false;
    }

    return callCoreFunction(_coreInit, (const uint8_t *)configJson.data(), configJson.size());
}

bool WamrCoreBackend::onEvent(const uint8_t *data, size_t len) {
    if (!_instance) {
        return false;
    }
    return callCoreFunction(_coreOnEvent, data, len);
}

bool WamrCoreBackend::callCoreFunction(wasm_function_inst_t function, const uint8_t *data, size_t len) {
    // rt_alloc -> copy in -> call -> rt_free (ABI module-form buffer contract).
    uint32_t args[2] = { (uint32_t)len, 0 };
    if (!wasm_runtime_call_wasm(_execEnv, _rtAlloc, 1, args)) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: rt_alloc trapped: " << wasm_runtime_get_exception(_instance);
        return false;
    }
    const uint32_t appOffset = args[0];
    if (appOffset == 0) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: rt_alloc returned null";
        return false;
    }
    if (!wasm_runtime_validate_app_addr(_instance, (uint64_t)appOffset, (uint64_t)len)) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: rt_alloc returned invalid range";
        return false;
    }
    void *native = wasm_runtime_addr_app_to_native(_instance, (uint64_t)appOffset);
    memcpy(native, data, len);

    uint32_t callArgs[2] = { appOffset, (uint32_t)len };
    const bool ok = wasm_runtime_call_wasm(_execEnv, function, 2, callArgs);
    if (!ok) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: core call trapped: " << wasm_runtime_get_exception(_instance);
    }

    uint32_t freeArgs[1] = { appOffset };
    if (!wasm_runtime_call_wasm(_execEnv, _rtFree, 1, freeArgs)) {
        RTC_LOG(LS_ERROR) << "WamrCoreBackend: rt_free trapped: " << wasm_runtime_get_exception(_instance);
        return false;
    }
    return ok;
}

} // namespace tgcalls
```

API-friction rule: if a `wasm_runtime_*` signature differs in the vendored 2.4.5 headers (e.g. `validate_app_addr`/`addr_app_to_native` taking `uint32`, or the `NativeSymbol`/static-initializer ordering needing the symbols array registered via `wasm_runtime_register_natives("env", ...)` after `init` instead of through `RuntimeInitArgs`), adjust to match `third-party/wamr/core/iwasm/include/wasm_export.h` exactly, preserving semantics (registration still happens once, before any load). Record deviations.

- [ ] **Step 4: CallCoreHost swaps to the backend.** In `CallCoreHost.h`: replace `#include "v2wasm/CallCoreABI.h"` usage for the handle — change member `TgcallsCallCore *_core = nullptr;` to `std::unique_ptr<CallCoreBackend> _core;` (add `#include "v2wasm/CallCoreBackend.h"`, keep the ABI include), and delete the `static void coreEmitTrampoline(...)` declaration.

In `CallCoreHost.cpp`:
- add includes `"v2wasm/NativeCoreBackend.h"` and `"v2wasm/WamrCoreBackend.h"`;
- delete `CallCoreHost::coreEmitTrampoline` entirely;
- in the destructor, replace the `if (_core) { tgcalls_core_destroy(_core); _core = nullptr; }` block with `_core.reset();`;
- in `start()`, replace the `_core = tgcalls_core_create(...); processPendingCommands();` tail with:

```cpp
    std::string wasmCorePath;
    {
        std::string parsingError;
        const auto custom = json11::Json::parse(_customParameters, parsingError);
        if (custom.is_object() && custom["wasm_core_path"].is_string()) {
            wasmCorePath = custom["wasm_core_path"].string_value();
        }
    }
    if (!wasmCorePath.empty()) {
        RTC_LOG(LS_INFO) << "CallCoreHost: using WAMR core backend: " << wasmCorePath;
        _core = std::make_unique<WamrCoreBackend>(wasmCorePath);
    } else {
        _core = std::make_unique<NativeCoreBackend>();
    }

    const auto emitToQueue = [this](const uint8_t *data, size_t len) {
        std::string parsingError;
        auto command = json11::Json::parse(std::string((const char *)data, len), parsingError);
        if (!command.is_object()) {
            RTC_LOG(LS_ERROR) << "CallCoreHost: core emitted non-object command";
            return;
        }
        _pendingCommands.push_back(std::move(command));
    };
    if (!_core->create(configJson, emitToQueue)) {
        disableCoreWithFailure("core backend create failed");
        return;
    }
    processPendingCommands();
```

- in `deliverEventNow`, replace the `tgcalls_core_on_event(...)` call:

```cpp
    _isDeliveringEvent = true;
    const bool ok = _core->onEvent((const uint8_t *)serialized.data(), serialized.size());
    _isDeliveringEvent = false;
    if (!ok) {
        disableCoreWithFailure("core backend event dispatch failed");
        return;
    }
```

(The raw-pointer capture `[this]` in `emitToQueue` is safe: the backend cannot outlive the host — it is a member — and emit only fires inside `create`/`onEvent` calls made by the host itself.)

- [ ] **Step 5: CLI flags.** In `submodules/TgVoipWebrtc/tgcalls/tools/cli/main.cpp`: near `std::string version2;` add:

```cpp
    std::string wasmCore;
    std::string wasmCore2;
```

in the argument loop after the `--version2` branch add:

```cpp
        } else if (std::string(argv[i]) == "--wasm-core" && i + 1 < argc) {
            wasmCore = argv[++i];
        } else if (std::string(argv[i]) == "--wasm-core2" && i + 1 < argc) {
            wasmCore2 = argv[++i];
```

after the `if (version2.empty()) { version2 = version; }` block add:

```cpp
    if (wasmCore2.empty()) {
        wasmCore2 = wasmCore;
    }
```

and in the two descriptor literals, extend the `.config` blocks: caller gets

```cpp
            .customParameters = wasmCore.empty() ? std::string() : json11::Json(json11::Json::object{{"wasm_core_path", wasmCore}}).dump(),
```

callee the same with `wasmCore2`. Add `#include "third-party/json11.hpp"` next to the tgcalls includes. (Designated-initializer order: `customParameters` is the LAST field of `Config` — placing it after `.statsLogPath` keeps declaration order.)

`--wasm-core2` defaults to `--wasm-core`, so symmetric wasm↔wasm runs need one flag. Asymmetric runs where the CALLEE must stay native use the explicit sentinel `--wasm-core2 NONE` (matrix rows W1/W4/W5/W7). Support it by adding, AFTER the defaulting block:

```cpp
    if (wasmCore2 == "NONE") {
        wasmCore2 = "";
    }
```


- [ ] **Step 6: BUILD wiring (parent).** In `submodules/TgVoipWebrtc/BUILD`: add to BOTH source lists, after each `"tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp",` line (matching indent):

```python
    "tgcalls/tgcalls/v2wasm/NativeCoreBackend.cpp",
    "tgcalls/tgcalls/v2wasm/WamrCoreBackend.cpp",
```

Add `"//third-party/wamr:wamr",` to the `deps` of BOTH `tgcalls_core` and the `TgVoipWebrtc` objc_library. In `submodules/TgVoipWebrtc/tgcalls/tools/cli/BUILD` (submodule), add to the `tgcalls_cli` target:

```python
    data = ["//submodules/TgVoipWebrtc:reference_core_wasm"],
```

- [ ] **Step 7: Build.**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | tail -3
```

Expected: success (also builds the module via the `data` dep).

- [ ] **Step 8: Smoke run (native path unchanged + wasm loads).**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo exit=$?
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet --wasm-core bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm --wasm-core2 NONE; echo exit=$?
```

Expected: both `exit=0`. The second run is the first live WASM call — if it fails, debug via the `[core]`/`CallCoreHost` logs exactly as in Phase 1 (compare against the first run's logs; the cores are the same source, so any divergence is in the module build or the WAMR marshaling, not the protocol).

- [ ] **Step 9: Commit (both repos).**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreBackend.h tgcalls/v2wasm/NativeCoreBackend.h tgcalls/v2wasm/NativeCoreBackend.cpp tgcalls/v2wasm/WamrCoreBackend.h tgcalls/v2wasm/WamrCoreBackend.cpp tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp tools/cli/main.cpp tools/cli/BUILD && \
git commit -m "feat(v2wasm): pluggable core backend — native or runtime-loaded WAMR module

CallCoreBackend seam; NativeCoreBackend wraps the linked C ABI;
WamrCoreBackend runs reference-core-abi1.wasm in the WAMR fast interpreter
(per-call instance, media-thread only, (*~)-validated host_emit, traps are
fatal). Selection via customParameters.wasm_core_path; CLI --wasm-core/
--wasm-core2 (NONE sentinel for asymmetric runs).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): wire WAMR backend — wamr dep on tgcalls_core + TgVoipWebrtc

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: WASM interop matrix + iOS build-proof + finalize

**Files:**
- Modify: `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-phase2-design.md` (append `## Validation results (Phase 2)`)
- Modify (final): parent gitlink pin for the submodule.

**Interfaces:**
- Consumes: built `tgcalls_cli` + `bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm`, `--wasm-core`/`--wasm-core2`/`NONE` from Task 4.
- Produces: recorded W1–W8 results, native regression, iOS build result; final commits.

- [ ] **Step 1: The matrix.** `WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm`; run in order, each `; echo exit=$?`, Bash timeout ≥ 120s (row W4/W8: ≥ 180s):

```bash
W1: --mode p2p --version 11.0.0-pump --version2 11.0.0      --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE
W2: --mode p2p --version 11.0.0      --version2 11.0.0-pump --duration 10 --quiet --wasm-core2 $WASM
W3: --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM
W4: --mode p2p --version 11.0.0-pump --version2 11.0.0      --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM --wasm-core2 NONE
W5: --mode p2p --version 10.0.0-pump --version2 10.0.0      --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE
W6 (stretch): ./submodules/TgVoipWebrtc/tgcalls/tools/cli/run-local-test.sh -n 50 -j 25 --version 11.0.0-pump  # only if the script forwards unknown extra args (--wasm-core) to the binary; otherwise SKIP and note
W7: --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE   # wasm caller vs NATIVE pump callee
W8: --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM
```

Expected: all `exit=0` with `Call established: yes` + `BWE non-zero: yes`. On any failure: systematic debugging, minimal fix (wire keys frozen; core discipline intact; WAMR sources read-only), then rebuild and re-run ALL rows run so far.

- [ ] **Step 2: Native regression.** Re-run Phase-1 rows 1–3 (no `--wasm-core`): pump↔stock, stock↔pump, pump↔pump — all `exit=0`.

- [ ] **Step 3: iOS build-proof.**

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64 2>&1 | tail -5
```

Expected: `Build completed successfully` (WAMR + WamrCoreBackend now compile for the iOS configuration; this is the phase's headline risk-retirement). Run in background; needs ≥ 10 min.

- [ ] **Step 4: Record results.** Append `## Validation results (Phase 2)` to the Phase-2 spec: one table row per W-run (command, exit code, established), native-regression line, iOS build line, dated 2026-07-02 (or actual date), any deviations/skips honestly noted (esp. W6).

- [ ] **Step 5: Final commits.**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git status --porcelain && git add -A tgcalls/v2wasm tools/cli && git diff --cached --quiet || \
git commit -m "fix(v2wasm): fixes from Phase-2 WASM validation matrix

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"; cd ../../..
git add submodules/TgVoipWebrtc/tgcalls docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-phase2-design.md && \
git commit -m "docs(tgcalls): Phase-2 validation results; pin submodule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Plan self-review notes

- **Spec coverage:** §1 toolchain/genrule → Task 2; §2 module ABI → Tasks 1 (doc) + 2 (entry); §3 WAMR vendor → Task 3; §4 backend seam/CLI → Task 4; §5 hardening → Task 1 (ordered first per spec); §6 iOS build-proof → Task 5 Step 3 (deps wired in Task 4); §7 matrix → Task 5. Spec pin corrections (33.0/2.4.5) folded into Task 2 Step 1.
- **Known risk concentrations:** Task 3 (WAMR define/source-list friction — mitigated by the scratchpad cmake reference + recorded deviations) and Task 4 Step 8's first live WASM call. Both have explicit resolution rules.
- **Type consistency:** `CallCoreBackend::EmitFn(const uint8_t *, size_t)` matches both backends and `emitToQueue`; `disableCoreWithFailure(std::string const &)` defined in Task 1, used in Task 4; W-matrix flags match Task 4 Step 5's parser (incl. the `NONE` sentinel and `--wasm-core2`-only form used by W2).
- **Honesty notes baked in:** Linux genrule branch is compile-best-effort this phase; W6 may be skipped if the mass-test script can't forward flags; both must be recorded in the results section, not silently dropped.
