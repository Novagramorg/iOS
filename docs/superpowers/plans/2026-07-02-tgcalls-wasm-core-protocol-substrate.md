# tgcalls WASM-core Phase 2.6: protocol substrate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move signaling framing/reliability into the swappable call core (raw packet boundary, crypto+replay stay native), generalize the data-channel surface to N named channels with binary payloads, and expose audio-processing/ICE session-config knobs — per the approved spec `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-protocol-substrate-design.md`.

**Architecture:** The ABI's signaling unit changes from "plaintext JSON message" to "full plaintext packet (`seq(4, network order) || body`) that feeds the AEAD". A new core-side `SignalingFraming` component ports `EncryptedConnection`'s V1 reliability layer (seq flag bits, packing, acks, resends, service packets) and the V2 gzip framing (vendored miniz); the host's signaling role collapses to validate + seal + send / open + replay-check + deliver. Data channels become a host-side `label → channel` registry. APM `ApplyConfig` and `PeerConnection::SetConfiguration` are exposed as commands. Variant demos prove each surface ships as wasm only.

**Tech Stack:** C++17, json11, miniz 3.0.2 (vendored), WebRTC (host side only), Bazel genrules + wasi-sdk 33.0, WAMR (unchanged), CLI testbench.

## Global Constraints

- **Two repos.** The tgcalls submodule lives at `submodules/TgVoipWebrtc/tgcalls` (branch `tgcalls-wasm-core-sketch`); the parent worktree branch is `worktree-tgcalls-wasm-core-sketch`. All `tgcalls/…` file paths below are relative to the submodule root; `submodules/TgVoipWebrtc/BUILD`, `docs/…` are parent-repo files. **Commit order per task: submodule first, then parent (pin + parent files):**
  ```bash
  cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
  git -C submodules/TgVoipWebrtc/tgcalls add <files> && git -C submodules/TgVoipWebrtc/tgcalls commit -m "<msg>"
  git add submodules/TgVoipWebrtc/tgcalls <parent files> && git commit -m "<msg>; pin submodule"
  ```
- **ABI v1, broken in place.** `tgcalls/tgcalls/v2wasm/CallCoreABI.h` stays the normative contract at `abiVersion: 1`; no compatibility shims, no dual paths. `signaling_send`/`signaling_message` are **removed**, not deprecated.
- **Wire parity is frozen — now including framing bytes.** Signaling JSON keys are copied verbatim from stock (`v2/InstanceV2ReferenceImpl.cpp`, `v2/Signaling.cpp`); the V1 framing constants and byte layout are copied verbatim from `tgcalls/tgcalls/EncryptedConnection.cpp` (`kSingleMessagePacketSeqBit = 1u<<31`, `kMessageRequiresAckSeqBit = 1u<<30`, `kAckId = 0xFF`, `kEmptyId = 0xFE`, `kCustomId = 127`, `kMaxSignalingPacketSize = 16*1024`, ack entry = seq(4)+id(1), delays 3000/5000/5000 ms, not-acked limit `64*1024`, incoming-counter window 64). Never change any of them. json11 is std::map-backed (key-sorted dump), so identical keys ⇒ identical bytes.
- **Core include discipline (amended this phase):** `ReferenceCallCore.*`, `VariantCallCore.*`, `SignalingFraming.*`, `CoreGzip.*`, `CoreBase64.h`, `CoreFactory.h`, `*_core_factory.cpp`, `wasm_module_entry.cpp` may include only `CallCoreABI.h`/core headers, `third-party/json11.hpp`, `third-party/miniz/miniz.h`, and C++17 std. No webrtc, no absl, no other tgcalls headers, no exceptions.
- **WASM-only files** (`VariantCallCore.*`, `*_core_factory.cpp`, `wasm_module_entry.cpp`) never join native source lists.
- **Stock sources are read-only** (`v2/InstanceV2ReferenceImpl.*`, `v2/Signaling.*`). `tgcalls/tgcalls/EncryptedConnection.{h,cpp}` is shared with stock impls: **additive methods only**, no changes to existing behavior.
- **Load-bearing log strings** (P1/P2 diffs key on them; freeze exactly): stock `sendSignalingMessage: ` (exists today); core `[core] signaling out: ` / `[core] signaling in: ` (added Task 4); framing lines `(signaling) Add SEND:type…`, `Got ACK:type…`, `Add ACK#…`, `Got RECV:…`, `SEND:empty#…` matching stock `EncryptedConnection.cpp` text.
- **Red window:** after Task 3 commits, the CLI compiles but pump signaling is runtime-broken until Task 4 lands (host speaks the new ABI, core still the old). Do not run CLI validation between Tasks 3 and 4.
- **Build commands** (from parent worktree root):
  - CLI + modules: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
  - iOS app (Task 8 only): `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64`
- **Validation shell setup** (any task running the CLI):
  ```bash
  cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
  CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
  WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
  VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
  SCRATCH=$(mktemp -d)
  ```
- **The pump never re-enters the core**; events raised mid-drain are deferred. All new host code must use `deliverEvent`/`emitErrorEvent`, never call the core directly.
- Scratch test binaries compile with the host toolchain: `clang++ -std=c++17 -I submodules/TgVoipWebrtc/tgcalls/tgcalls …` from the parent root. They are throwaway (live in `$SCRATCH`), never committed.

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `tgcalls/tgcalls/third-party/miniz/miniz.{h,c}` | create (vendor) | deflate/inflate for core-side gzip (wasm + native) |
| `tgcalls/tgcalls/v2wasm/CoreBase64.h` | create | header-only base64 (core + host shared) |
| `tgcalls/tgcalls/v2wasm/CoreGzip.{h,cpp}` | create | gzip-format wrapper over miniz, mirrors `utils/gzip` semantics |
| `tgcalls/tgcalls/v2wasm/SignalingFraming.{h,cpp}` | create | V1 reliability port + V2 gzip framing (core-side) |
| `tgcalls/tgcalls/EncryptedConnection.{h,cpp}` | modify (additive) | `encryptFullPlaintextPacket` / `decryptFullPlaintextPacket` |
| `tgcalls/tgcalls/v2wasm/CallCoreHost.{h,cpp}` | modify | signaling cut-over (T3); dc registry (T5); APM/SetConfiguration (T6) |
| `tgcalls/tgcalls/v2wasm/ReferenceCallCore.{h,cpp}` | modify | framing integration + hooks (T4); dc label guards + hook (T5) |
| `tgcalls/tgcalls/v2wasm/VariantCallCore.{h,cpp}` | modify | demos: padding, keepalive, exp0 ping/pong, APM/config (T7) |
| `tgcalls/tgcalls/v2wasm/CallCoreABI.h` | modify | contract doc: signaling (T3), dc (T5), knobs (T6) |
| `submodules/TgVoipWebrtc/BUILD` | modify (parent) | new sources in wasm cmd/srcs + native glob-exclude + srcs list (T4) |
| `tgcalls/tgcalls/v2wasm/CLAUDE.md`, `tgcalls/CLAUDE.md`, root `CLAUDE.md`, spec | modify | docs + validation record (T8) |

---

### Task 1: Vendor miniz; CoreBase64; CoreGzip

**Files:**
- Create: `tgcalls/tgcalls/third-party/miniz/miniz.h`, `tgcalls/tgcalls/third-party/miniz/miniz.c` (vendored, unmodified)
- Create: `tgcalls/tgcalls/v2wasm/CoreBase64.h`
- Create: `tgcalls/tgcalls/v2wasm/CoreGzip.h`, `tgcalls/tgcalls/v2wasm/CoreGzip.cpp`

**Interfaces:**
- Consumes: nothing (leaf task).
- Produces (Tasks 2/3/4/5 rely on these exact signatures, all in `namespace tgcalls::v2wasm`):
  - `std::string base64Encode(const uint8_t *data, size_t len)`; `std::string base64Encode(std::vector<uint8_t> const &data)`; `std::optional<std::vector<uint8_t>> base64Decode(std::string const &text)`
  - `bool coreIsGzip(std::vector<uint8_t> const &data)`; `std::optional<std::vector<uint8_t>> coreGzipData(std::vector<uint8_t> const &data)`; `std::optional<std::vector<uint8_t>> coreGunzipData(std::vector<uint8_t> const &data, size_t sizeLimit)`

- [ ] **Step 1: Vendor miniz 3.0.2**

```bash
SCRATCH=$(mktemp -d)
cd $SCRATCH
curl -fL -o miniz.zip https://github.com/richgel999/miniz/releases/download/3.0.2/miniz-3.0.2.zip
shasum -a 256 miniz.zip   # record this hash for the commit message
unzip -o miniz.zip
ls   # find the amalgamated miniz.c + miniz.h (top level of the release zip)
SUB=/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch/submodules/TgVoipWebrtc/tgcalls
mkdir -p $SUB/tgcalls/third-party/miniz
cp miniz.h miniz.c $SUB/tgcalls/third-party/miniz/
```

If the zip layout differs (files in a subdirectory), copy the amalgamated pair from wherever they are. Do not edit them — the MIT license header inside `miniz.h` must stay intact. If the download fails (no network), report BLOCKED; do not substitute a different compression library.

- [ ] **Step 2: Write CoreBase64.h**

Full content of `tgcalls/tgcalls/v2wasm/CoreBase64.h`:

```cpp
#ifndef TGCALLS_V2WASM_CORE_BASE64_H
#define TGCALLS_V2WASM_CORE_BASE64_H

// Header-only base64 (RFC 4648, with padding). WASM discipline: std only.
// Shared by the core (packet / binary dc payload encoding) and CallCoreHost.

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace tgcalls {
namespace v2wasm {

inline std::string base64Encode(const uint8_t *data, size_t len) {
    static const char kAlphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string result;
    result.reserve(((len + 2) / 3) * 4);
    size_t i = 0;
    while (i + 3 <= len) {
        const uint32_t v = (uint32_t(data[i]) << 16) | (uint32_t(data[i + 1]) << 8) | uint32_t(data[i + 2]);
        result.push_back(kAlphabet[(v >> 18) & 63]);
        result.push_back(kAlphabet[(v >> 12) & 63]);
        result.push_back(kAlphabet[(v >> 6) & 63]);
        result.push_back(kAlphabet[v & 63]);
        i += 3;
    }
    if (i + 1 == len) {
        const uint32_t v = uint32_t(data[i]) << 16;
        result.push_back(kAlphabet[(v >> 18) & 63]);
        result.push_back(kAlphabet[(v >> 12) & 63]);
        result.push_back('=');
        result.push_back('=');
    } else if (i + 2 == len) {
        const uint32_t v = (uint32_t(data[i]) << 16) | (uint32_t(data[i + 1]) << 8);
        result.push_back(kAlphabet[(v >> 18) & 63]);
        result.push_back(kAlphabet[(v >> 12) & 63]);
        result.push_back(kAlphabet[(v >> 6) & 63]);
        result.push_back('=');
    }
    return result;
}

inline std::string base64Encode(std::vector<uint8_t> const &data) {
    return base64Encode(data.data(), data.size());
}

inline std::optional<std::vector<uint8_t>> base64Decode(std::string const &text) {
    const auto valueOf = [](char c) -> int {
        if (c >= 'A' && c <= 'Z') return c - 'A';
        if (c >= 'a' && c <= 'z') return c - 'a' + 26;
        if (c >= '0' && c <= '9') return c - '0' + 52;
        if (c == '+') return 62;
        if (c == '/') return 63;
        return -1;
    };
    if (text.size() % 4 != 0) {
        return std::nullopt;
    }
    std::vector<uint8_t> result;
    result.reserve((text.size() / 4) * 3);
    for (size_t i = 0; i < text.size(); i += 4) {
        int values[4] = {0, 0, 0, 0};
        int padding = 0;
        for (int j = 0; j < 4; j++) {
            const char c = text[i + j];
            if (c == '=') {
                // '=' allowed only at positions 2/3 of the final group.
                if (i + 4 != text.size() || j < 2) {
                    return std::nullopt;
                }
                padding++;
            } else {
                if (padding > 0) {
                    return std::nullopt;
                }
                values[j] = valueOf(c);
                if (values[j] < 0) {
                    return std::nullopt;
                }
            }
        }
        const uint32_t v = (uint32_t(values[0]) << 18) | (uint32_t(values[1]) << 12) | (uint32_t(values[2]) << 6) | uint32_t(values[3]);
        result.push_back(uint8_t((v >> 16) & 0xff));
        if (padding < 2) {
            result.push_back(uint8_t((v >> 8) & 0xff));
        }
        if (padding < 1) {
            result.push_back(uint8_t(v & 0xff));
        }
    }
    return result;
}

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 3: Write CoreGzip.h**

Full content of `tgcalls/tgcalls/v2wasm/CoreGzip.h`:

```cpp
#ifndef TGCALLS_V2WASM_CORE_GZIP_H
#define TGCALLS_V2WASM_CORE_GZIP_H

// gzip-format compress/decompress for signaling V2 bodies, backed by the
// vendored miniz. Mirrors utils/gzip.{h,cpp} (zlib) semantics:
//  - coreGzipData: gzip-wrapped deflate (magic 1f 8b), max compression
//  - coreGunzipData: accepts gzip (1f 8b) and zlib (78 9c) framing, enforces
//    sizeLimit (zip-bomb bound), verifies the gzip CRC, nullopt on failure
//  - coreIsGzip: same magic check as utils/gzip.h isGzip
// WASM discipline: std + miniz only.

#include <cstdint>
#include <optional>
#include <vector>

namespace tgcalls {
namespace v2wasm {

bool coreIsGzip(std::vector<uint8_t> const &data);
std::optional<std::vector<uint8_t>> coreGzipData(std::vector<uint8_t> const &data);
std::optional<std::vector<uint8_t>> coreGunzipData(std::vector<uint8_t> const &data, size_t sizeLimit);

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 4: Write CoreGzip.cpp**

Full content of `tgcalls/tgcalls/v2wasm/CoreGzip.cpp`:

```cpp
#include "v2wasm/CoreGzip.h"

#include "third-party/miniz/miniz.h"

namespace tgcalls {
namespace v2wasm {

namespace {

std::optional<std::vector<uint8_t>> inflateBounded(const uint8_t *data, size_t size, size_t sizeLimit, int flags) {
    // Bounded inflate: decompress into a limit-sized buffer so a zip bomb
    // fails instead of allocating unboundedly.
    std::vector<uint8_t> output(sizeLimit);
    const size_t written = tinfl_decompress_mem_to_mem(output.data(), output.size(), data, size, flags);
    if (written == TINFL_DECOMPRESS_MEM_TO_MEM_FAILED) {
        return std::nullopt;
    }
    output.resize(written);
    output.shrink_to_fit();
    return output;
}

} // namespace

bool coreIsGzip(std::vector<uint8_t> const &data) {
    if (data.size() < 2) {
        return false;
    }
    return (data[0] == 0x1f && data[1] == 0x8b) || (data[0] == 0x78 && data[1] == 0x9c);
}

std::optional<std::vector<uint8_t>> coreGzipData(std::vector<uint8_t> const &data) {
    size_t compressedSize = 0;
    void *compressed = tdefl_compress_mem_to_heap(
        data.data(), data.size(), &compressedSize,
        tdefl_create_comp_flags_from_zip_params(MZ_BEST_COMPRESSION, -MZ_DEFAULT_WINDOW_BITS, MZ_DEFAULT_STRATEGY));
    if (!compressed) {
        return std::nullopt;
    }
    // 10-byte gzip header (deflate, no flags, XFL=2, OS=unix) + raw deflate
    // stream + CRC32 and ISIZE trailers (little-endian).
    std::vector<uint8_t> result;
    result.reserve(10 + compressedSize + 8);
    const uint8_t header[10] = { 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x03 };
    result.insert(result.end(), header, header + 10);
    result.insert(result.end(), (const uint8_t *)compressed, (const uint8_t *)compressed + compressedSize);
    mz_free(compressed);
    const uint32_t crc = (uint32_t)mz_crc32(MZ_CRC32_INIT, data.data(), data.size());
    const uint32_t isize = (uint32_t)data.size();
    for (int i = 0; i < 4; i++) {
        result.push_back(uint8_t((crc >> (8 * i)) & 0xff));
    }
    for (int i = 0; i < 4; i++) {
        result.push_back(uint8_t((isize >> (8 * i)) & 0xff));
    }
    return result;
}

std::optional<std::vector<uint8_t>> coreGunzipData(std::vector<uint8_t> const &data, size_t sizeLimit) {
    if (data.size() >= 2 && data[0] == 0x78 && data[1] == 0x9c) {
        return inflateBounded(data.data(), data.size(), sizeLimit, TINFL_FLAG_PARSE_ZLIB_HEADER);
    }
    if (data.size() < 18 || data[0] != 0x1f || data[1] != 0x8b || data[2] != 0x08) {
        return std::nullopt;
    }
    const uint8_t flg = data[3];
    size_t pos = 10;
    if (flg & 0x04) { // FEXTRA
        if (pos + 2 > data.size()) {
            return std::nullopt;
        }
        const size_t xlen = size_t(data[pos]) | (size_t(data[pos + 1]) << 8);
        pos += 2 + xlen;
    }
    if (flg & 0x08) { // FNAME
        while (pos < data.size() && data[pos] != 0) pos++;
        pos++;
    }
    if (flg & 0x10) { // FCOMMENT
        while (pos < data.size() && data[pos] != 0) pos++;
        pos++;
    }
    if (flg & 0x02) { // FHCRC
        pos += 2;
    }
    if (pos + 8 > data.size()) {
        return std::nullopt;
    }
    auto output = inflateBounded(data.data() + pos, data.size() - pos - 8, sizeLimit, 0);
    if (!output) {
        return std::nullopt;
    }
    const size_t t = data.size() - 8;
    const uint32_t expectedCrc = uint32_t(data[t]) | (uint32_t(data[t + 1]) << 8) | (uint32_t(data[t + 2]) << 16) | (uint32_t(data[t + 3]) << 24);
    const uint32_t actualCrc = (uint32_t)mz_crc32(MZ_CRC32_INIT, output->data(), output->size());
    if (expectedCrc != actualCrc) {
        return std::nullopt;
    }
    return output;
}

} // namespace v2wasm
} // namespace tgcalls
```

- [ ] **Step 5: Write the scratch tests (base64 + gzip cross-check vs python zlib)**

`$SCRATCH/base64_test.cpp`:

```cpp
#include <cassert>
#include <cstdio>
#include <string>
#include <vector>
#include "v2wasm/CoreBase64.h"
using namespace tgcalls::v2wasm;
int main() {
    assert(base64Encode(std::vector<uint8_t>{}) == "");
    assert(base64Encode(std::vector<uint8_t>{'f'}) == "Zg==");
    assert(base64Encode(std::vector<uint8_t>{'f','o'}) == "Zm8=");
    assert(base64Encode(std::vector<uint8_t>{'f','o','o'}) == "Zm9v");
    for (int len = 0; len < 100; len++) {
        std::vector<uint8_t> data;
        for (int i = 0; i < len; i++) data.push_back(uint8_t(i * 37 + len));
        auto decoded = base64Decode(base64Encode(data));
        assert(decoded && *decoded == data);
    }
    assert(!base64Decode("a"));
    assert(!base64Decode("=AAA"));
    assert(!base64Decode("Zg=x"));
    printf("OK\n");
    return 0;
}
```

`$SCRATCH/gzip_test.cpp`:

```cpp
#include <cstdio>
#include <string>
#include <vector>
#include "v2wasm/CoreGzip.h"
using namespace tgcalls::v2wasm;
int main(int argc, char **argv) {
    const std::string payload(argv[1]);
    const std::string mode(argv[2]);
    if (mode == "compress") {
        auto out = coreGzipData(std::vector<uint8_t>(payload.begin(), payload.end()));
        if (!out) return 2;
        fwrite(out->data(), 1, out->size(), stdout);
        return 0;
    }
    std::vector<uint8_t> input;
    uint8_t buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), stdin)) > 0) input.insert(input.end(), buf, buf + n);
    auto out = coreGunzipData(input, 2 * 1024 * 1024);
    if (!out) return 2;
    if (std::string(out->begin(), out->end()) != payload) return 3;
    printf("OK\n");
    return 0;
}
```

- [ ] **Step 6: Compile and run — expect failures first is not applicable (no framework); run all checks**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
INC=submodules/TgVoipWebrtc/tgcalls/tgcalls
clang++ -std=c++17 -I $INC $SCRATCH/base64_test.cpp -o $SCRATCH/base64_test && $SCRATCH/base64_test
clang++ -std=c++17 -I $INC $SCRATCH/gzip_test.cpp $INC/v2wasm/CoreGzip.cpp $INC/third-party/miniz/miniz.c -o $SCRATCH/gzip_test
P="hello gzip round trip 12345 hello gzip round trip 12345"
$SCRATCH/gzip_test "$P" compress | python3 -c "import sys,gzip; assert gzip.decompress(sys.stdin.buffer.read())==b'$P'; print('OK py-gunzip')"
python3 -c "import sys,gzip; sys.stdout.buffer.write(gzip.compress(b'$P'))" | $SCRATCH/gzip_test "$P" decompress
python3 -c "import sys,zlib; sys.stdout.buffer.write(zlib.compress(b'$P',6))" | $SCRATCH/gzip_test "$P" decompress
```

Expected: `OK` from base64_test; `OK py-gunzip`; `OK` twice (gzip-framed and zlib-framed inputs both accepted). If `tinfl_decompress_mem_to_mem`/`tdefl_*` symbols are missing, check the miniz amalgamation copied correctly (both .c and .h).

- [ ] **Step 7: Commit (submodule + parent pin)**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/third-party/miniz tgcalls/v2wasm/CoreBase64.h tgcalls/v2wasm/CoreGzip.h tgcalls/v2wasm/CoreGzip.cpp
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: vendor miniz 3.0.2 + CoreBase64 + CoreGzip (Phase 2.6 groundwork)

miniz-3.0.2.zip sha256: <hash from Step 1>"
git add submodules/TgVoipWebrtc/tgcalls
git commit -m "build(tgcalls): pin submodule — miniz + core base64/gzip groundwork"
```

---

### Task 2: SignalingFraming component

**Files:**
- Create: `tgcalls/tgcalls/v2wasm/SignalingFraming.h`, `tgcalls/tgcalls/v2wasm/SignalingFraming.cpp`

**Interfaces:**
- Consumes: `CoreGzip.h` (`coreIsGzip`/`coreGzipData`/`coreGunzipData`) from Task 1.
- Produces (Task 4 relies on these exactly, `namespace tgcalls::v2wasm`):
  - `SignalingFraming(bool isV2, Delegate delegate)` with `Delegate { sendPacket(std::vector<uint8_t>&&), deliverMessage(std::string&&), requestService(int cause, int delayMs), log(std::string const&), nowMs() -> int64_t }`
  - `void sendMessage(std::string const &message)`; `void receivePacket(std::vector<uint8_t> const &packet)`; `void onServiceTimer(int cause)`; `void sendKeepalive()`
  - `static constexpr int kServiceCauseNow = 0; kServiceCauseAcks = 1; kServiceCauseResend = 2;`

Reference for the port: `tgcalls/tgcalls/EncryptedConnection.cpp` (read it side-by-side). The port covers the **reliability half only** — crypto, packet-level replay check and counter-monotonicity stay in the host. Two deliberate structural mappings: (a) stock's synchronous `prepareForSendingService(0)` inside the enqueue path stays synchronous (`sendServicePacket()`), while stock's `_requestSendService(delay, cause)` PostTask maps to `Delegate::requestService` (the core turns it into a `set_timer` round-trip); (b) stock registers every incoming packet-level counter into `_largestIncomingCounters` — the port shadow-registers it too (return value ignored; the host already replay-checked) so the shared-list state matches stock exactly.

- [ ] **Step 1: Write SignalingFraming.h**

```cpp
#ifndef TGCALLS_V2WASM_SIGNALING_FRAMING_H
#define TGCALLS_V2WASM_SIGNALING_FRAMING_H

// Core-side signaling framing: everything between JSON messages and the
// plaintext packets (seq(4, network order) || body) that the host seals.
// V1 (wire 10.0.0): faithful port of EncryptedConnection's reliability layer
// (seq flag bits, message packing, ack bookkeeping, resend policy, service
// packets). V2 (wire 11.0.0): gzip'd JSON bodies.
// Constants, byte layout and log strings are copied verbatim from
// EncryptedConnection.cpp — never change them (wire + log parity).
// WASM discipline: std + CoreGzip (miniz) only.

#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace tgcalls {
namespace v2wasm {

class SignalingFraming {
public:
    // Service causes, verbatim from EncryptedConnection.cpp.
    static constexpr int kServiceCauseNow = 0;
    static constexpr int kServiceCauseAcks = 1;
    static constexpr int kServiceCauseResend = 2;

    struct Delegate {
        std::function<void(std::vector<uint8_t> &&packet)> sendPacket; // full plaintext packet incl. seq
        std::function<void(std::string &&message)> deliverMessage;     // decoded JSON message
        std::function<void(int cause, int delayMs)> requestService;    // schedule onServiceTimer(cause)
        std::function<void(std::string const &line)> log;              // stock-format framing log lines
        std::function<int64_t()> nowMs;                                // core clock (event nowMs)
    };

    SignalingFraming(bool isV2, Delegate delegate);

    void sendMessage(std::string const &message);
    void receivePacket(std::vector<uint8_t> const &packet);
    void onServiceTimer(int cause);
    // Bare empty V1 packet (plus any pending acks/resends) even when idle;
    // variant keepalive seam. No-op on V2.
    void sendKeepalive();

private:
    struct MessageForResend {
        std::vector<uint8_t> data;
        int64_t lastSent = 0;
    };

    std::optional<uint32_t> computeNextSeq(bool messageRequiresAck, bool singleMessagePacket);
    bool enoughSpaceInPacket(std::vector<uint8_t> const &buffer, size_t amount) const;
    void appendAcksToSend(std::vector<uint8_t> &buffer);
    void appendAdditionalMessages(std::vector<uint8_t> &buffer);
    bool registerIncomingCounter(uint32_t incomingCounter);
    bool registerSentAck(uint32_t counter, bool firstInPacket);
    void sendAckPostponed(uint32_t incomingSeq);
    void ackMyMessage(uint32_t seq);
    bool haveAdditionalMessages() const;
    void sendServicePacket();

    bool _isV2 = false;
    Delegate _delegate;
    uint32_t _counter = 0;
    std::vector<uint32_t> _largestIncomingCounters;
    std::vector<uint32_t> _acksToSendSeqs;
    std::vector<uint32_t> _acksSentCounters;
    std::vector<MessageForResend> _myNotYetAckedMessages;
    bool _resendTimerActive = false;
    bool _sendAcksTimerActive = false;
};

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 2: Write SignalingFraming.cpp**

```cpp
#include "v2wasm/SignalingFraming.h"

#include <algorithm>

#include "v2wasm/CoreGzip.h"

namespace tgcalls {
namespace v2wasm {

namespace {

// All constants verbatim from EncryptedConnection.cpp (Type::Signaling).
constexpr uint32_t kSingleMessagePacketSeqBit = (uint32_t(1) << 31);
constexpr uint32_t kMessageRequiresAckSeqBit = (uint32_t(1) << 30);
constexpr uint32_t kMaxAllowedCounter = 0xFFFFFFFFu & ~kSingleMessagePacketSeqBit & ~kMessageRequiresAckSeqBit;
constexpr size_t kAckSerializedSize = sizeof(uint32_t) + sizeof(uint8_t);
constexpr size_t kNotAckedMessagesLimit = 64 * 1024;
constexpr size_t kKeepIncomingCountersCount = 64;
constexpr size_t kMaxSignalingPacketSize = 16 * 1024;
constexpr int kMinDelayBeforeMessageResend = 3000;
constexpr int kMaxDelayBeforeMessageResend = 5000;
constexpr int kMaxDelayBeforeAckResend = 5000;
constexpr size_t kV2DecompressSizeLimit = 2 * 1024 * 1024;

constexpr uint8_t kAckId = uint8_t(-1);
constexpr uint8_t kEmptyId = uint8_t(-2);
constexpr uint8_t kCustomId = uint8_t(127);

void appendSeq(std::vector<uint8_t> &buffer, uint32_t seq) {
    buffer.push_back(uint8_t((seq >> 24) & 0xff));
    buffer.push_back(uint8_t((seq >> 16) & 0xff));
    buffer.push_back(uint8_t((seq >> 8) & 0xff));
    buffer.push_back(uint8_t(seq & 0xff));
}

uint32_t readSeqAt(const uint8_t *bytes) {
    return (uint32_t(bytes[0]) << 24) | (uint32_t(bytes[1]) << 16) | (uint32_t(bytes[2]) << 8) | uint32_t(bytes[3]);
}

uint32_t counterFromSeq(uint32_t seq) {
    return seq & ~kSingleMessagePacketSeqBit & ~kMessageRequiresAckSeqBit;
}

} // namespace

SignalingFraming::SignalingFraming(bool isV2, Delegate delegate) :
_isV2(isV2),
_delegate(std::move(delegate)) {
}

std::optional<uint32_t> SignalingFraming::computeNextSeq(bool messageRequiresAck, bool singleMessagePacket) {
    if (messageRequiresAck && _myNotYetAckedMessages.size() >= kNotAckedMessagesLimit) {
        _delegate.log("ERROR! Too many not ACKed messages.");
        return std::nullopt;
    } else if (_counter == kMaxAllowedCounter) {
        _delegate.log("ERROR! Outgoing packet limit reached.");
        return std::nullopt;
    }
    return (++_counter)
        | (singleMessagePacket ? kSingleMessagePacketSeqBit : 0)
        | (messageRequiresAck ? kMessageRequiresAckSeqBit : 0);
}

bool SignalingFraming::enoughSpaceInPacket(std::vector<uint8_t> const &buffer, size_t amount) const {
    return (amount < kMaxSignalingPacketSize)
        && (16 + buffer.size() + amount <= kMaxSignalingPacketSize);
}

bool SignalingFraming::haveAdditionalMessages() const {
    return !_myNotYetAckedMessages.empty() || !_acksToSendSeqs.empty();
}

void SignalingFraming::appendAcksToSend(std::vector<uint8_t> &buffer) {
    auto i = _acksToSendSeqs.begin();
    while (i != _acksToSendSeqs.end() && enoughSpaceInPacket(buffer, kAckSerializedSize)) {
        _delegate.log("(signaling) Add ACK#" + std::to_string(counterFromSeq(*i)));
        appendSeq(buffer, *i);
        buffer.push_back(kAckId);
        ++i;
    }
    _acksToSendSeqs.erase(_acksToSendSeqs.begin(), i);
    for (const auto seq : _acksToSendSeqs) {
        _delegate.log("(signaling) Skip ACK#" + std::to_string(counterFromSeq(seq))
            + " (no space, length: " + std::to_string(kAckSerializedSize)
            + ", already: " + std::to_string(buffer.size()) + ")");
    }
}

void SignalingFraming::appendAdditionalMessages(std::vector<uint8_t> &buffer) {
    appendAcksToSend(buffer);

    if (_myNotYetAckedMessages.empty()) {
        return;
    }

    const int64_t now = _delegate.nowMs();
    for (auto &resending : _myNotYetAckedMessages) {
        const auto sent = resending.lastSent;
        const int64_t when = sent ? (sent + kMinDelayBeforeMessageResend) : 0;

        const auto counter = counterFromSeq(readSeqAt(resending.data.data()));
        const auto type = resending.data[4];
        if (when > now) {
            _delegate.log("(signaling) Skip RESEND:type" + std::to_string((int)type) + "#" + std::to_string(counter)
                + " (wait " + std::to_string(when - now) + "ms).");
            break;
        } else if (enoughSpaceInPacket(buffer, resending.data.size())) {
            _delegate.log("(signaling) Add RESEND:type" + std::to_string((int)type) + "#" + std::to_string(counter));
            buffer.insert(buffer.end(), resending.data.begin(), resending.data.end());
            resending.lastSent = now;
        } else {
            _delegate.log("(signaling) Skip RESEND:type" + std::to_string((int)type) + "#" + std::to_string(counter)
                + " (no space, length: " + std::to_string(resending.data.size())
                + ", already: " + std::to_string(buffer.size()) + ")");
            break;
        }
    }
    if (!_resendTimerActive) {
        _resendTimerActive = true;
        _delegate.requestService(kServiceCauseResend, kMaxDelayBeforeMessageResend);
    }
}

void SignalingFraming::sendMessage(std::string const &message) {
    if (_isV2) {
        // Stock V2 path: encryptRawPacket(gzip(json)) — seq has no flag bits
        // and no limit checks (EncryptedConnection::encryptRawPacket).
        std::vector<uint8_t> body(message.begin(), message.end());
        auto compressed = coreGzipData(body);
        if (!compressed) {
            _delegate.log("ERROR! Could not gzip signaling message");
            return;
        }
        const uint32_t seq = ++_counter;
        std::vector<uint8_t> packet;
        packet.reserve(4 + compressed->size());
        appendSeq(packet, seq);
        packet.insert(packet.end(), compressed->begin(), compressed->end());
        _delegate.sendPacket(std::move(packet));
        return;
    }

    // V1: port of prepareForSendingRawMessage(message, true) +
    // prepareForSendingMessageInternal — the pump profile always requires
    // acks, matching stock InstanceV2ReferenceImpl.
    const bool messageRequiresAck = true;
    const bool singleMessagePacket = !haveAdditionalMessages() && !messageRequiresAck; // always false
    const auto maybeSeq = computeNextSeq(messageRequiresAck, singleMessagePacket);
    if (!maybeSeq) {
        return;
    }
    const auto seq = *maybeSeq;

    // SerializeRawMessageWithSeq: seq(4) || kCustomId(1) || length(4) || bytes
    std::vector<uint8_t> serialized;
    serialized.reserve(4 + 1 + 4 + message.size());
    appendSeq(serialized, seq);
    serialized.push_back(kCustomId);
    appendSeq(serialized, (uint32_t)message.size()); // same big-endian u32 encoding
    serialized.insert(serialized.end(), message.begin(), message.end());

    if (!enoughSpaceInPacket(serialized, 0)) {
        _delegate.log("ERROR! Too large packet: " + std::to_string(serialized.size()));
        return;
    }
    const auto notYetAckedCopy = serialized;
    const bool sendEnqueued = !_myNotYetAckedMessages.empty();
    if (sendEnqueued) {
        // All requiring-ack messages are sent in order within one packet,
        // starting with the least not-yet-acked one (stock comment).
        _delegate.log("(signaling) Enqueue SEND:type" + std::to_string((int)kCustomId) + "#" + std::to_string(counterFromSeq(seq)));
    } else {
        _delegate.log("(signaling) Add SEND:type" + std::to_string((int)kCustomId) + "#" + std::to_string(counterFromSeq(seq)));
        appendAdditionalMessages(serialized);
    }
    _myNotYetAckedMessages.push_back({ notYetAckedCopy, _delegate.nowMs() });
    if (!sendEnqueued) {
        _delegate.sendPacket(std::move(serialized));
        return;
    }
    for (auto &queued : _myNotYetAckedMessages) {
        queued.lastSent = 0;
    }
    sendServicePacket(); // stock: return prepareForSendingService(0) — synchronous
}

void SignalingFraming::sendServicePacket() {
    const auto maybeSeq = computeNextSeq(false, false);
    if (!maybeSeq) {
        return;
    }
    // SerializeEmptyMessageWithSeq: seq(4) || kEmptyId(1)
    std::vector<uint8_t> serialized;
    serialized.reserve(5);
    appendSeq(serialized, *maybeSeq);
    serialized.push_back(kEmptyId);
    _delegate.log("(signaling) SEND:empty#" + std::to_string(counterFromSeq(*maybeSeq)));
    appendAdditionalMessages(serialized);
    _delegate.sendPacket(std::move(serialized));
}

void SignalingFraming::onServiceTimer(int cause) {
    if (_isV2) {
        return;
    }
    if (cause == kServiceCauseAcks) {
        _sendAcksTimerActive = false;
    } else if (cause == kServiceCauseResend) {
        _resendTimerActive = false;
    }
    if (!haveAdditionalMessages()) {
        return;
    }
    sendServicePacket();
}

void SignalingFraming::sendKeepalive() {
    if (_isV2) {
        return;
    }
    sendServicePacket();
}

bool SignalingFraming::registerIncomingCounter(uint32_t incomingCounter) {
    auto &list = _largestIncomingCounters;

    const auto position = std::lower_bound(list.begin(), list.end(), incomingCounter);
    const auto largest = list.empty() ? 0 : list.back();
    if (position != list.end() && *position == incomingCounter) {
        return false;
    } else if (incomingCounter + kKeepIncomingCountersCount <= largest) {
        return false;
    }
    const auto eraseTill = std::find_if(list.begin(), list.end(), [&](uint32_t counter) {
        return (counter + kKeepIncomingCountersCount > incomingCounter);
    });
    const auto eraseCount = eraseTill - list.begin();
    const auto positionIndex = (position - list.begin()) - eraseCount;
    list.erase(list.begin(), eraseTill);
    list.insert(list.begin() + positionIndex, incomingCounter);
    return true;
}

bool SignalingFraming::registerSentAck(uint32_t counter, bool firstInPacket) {
    auto &list = _acksSentCounters;

    const auto position = std::lower_bound(list.begin(), list.end(), counter);
    const auto already = (position != list.end()) && (*position == counter);

    if (firstInPacket) {
        list.erase(list.begin(), position);
        if (!already) {
            list.insert(list.begin(), counter);
        }
    } else if (!already) {
        list.insert(position, counter);
    }
    return !already;
}

void SignalingFraming::sendAckPostponed(uint32_t incomingSeq) {
    auto &list = _acksToSendSeqs;
    const auto already = std::find(list.begin(), list.end(), incomingSeq);
    if (already == list.end()) {
        list.push_back(incomingSeq);
    }
}

void SignalingFraming::ackMyMessage(uint32_t seq) {
    uint8_t type = 0;
    auto &list = _myNotYetAckedMessages;
    for (auto i = list.begin(), e = list.end(); i != e; ++i) {
        if (readSeqAt(i->data.data()) == seq) {
            type = i->data[4];
            list.erase(i);
            break;
        }
    }
    _delegate.log("(signaling) " + (type
        ? "Got ACK:type" + std::to_string((int)type) + "#"
        : std::string("Repeated ACK#")) + std::to_string(counterFromSeq(seq)));
}

void SignalingFraming::receivePacket(std::vector<uint8_t> const &packet) {
    if (packet.size() < 5) {
        return;
    }
    const uint32_t packetSeq = readSeqAt(packet.data());

    if (_isV2) {
        std::vector<uint8_t> body(packet.begin() + 4, packet.end());
        if (coreIsGzip(body)) {
            auto decompressed = coreGunzipData(body, kV2DecompressSizeLimit);
            if (!decompressed) {
                _delegate.log("ERROR! Could not decompress signaling data");
                return;
            }
            body = std::move(*decompressed);
        }
        _delegate.deliverMessage(std::string(body.begin(), body.end()));
        return;
    }

    // Shadow stock's shared counter list: handleIncomingRawPacket registers
    // the packet-level counter into the same list the additional-message
    // dedup reads. The host already replay-checked the packet, so the return
    // value is ignored — this keeps the list state identical to stock.
    registerIncomingCounter(counterFromSeq(packetSeq));

    // Port of processRawPacket.
    bool additionalMessage = false;
    bool firstMessageRequiringAck = true;
    bool newRequiringAckReceived = false;
    uint32_t currentSeq = packetSeq;
    uint32_t currentCounter = counterFromSeq(currentSeq);
    size_t pos = 4;
    std::vector<std::string> received;

    while (true) {
        const uint8_t type = packet[pos];
        const bool singleMessagePacket = (currentSeq & kSingleMessagePacketSeqBit) != 0;
        if (singleMessagePacket && additionalMessage) {
            _delegate.log("ERROR! Single message packet bit in not first message.");
            return;
        }

        if (type == kEmptyId) {
            if (additionalMessage) {
                _delegate.log("ERROR! Empty message should be only the first one in the packet.");
                return;
            }
            _delegate.log("(signaling) Got RECV:empty#" + std::to_string(currentCounter));
            pos += 1;
        } else if (type == kAckId) {
            if (!additionalMessage) {
                _delegate.log("ERROR! Ack message must not be the first one in the packet.");
                return;
            }
            ackMyMessage(currentSeq);
            pos += 1;
        } else if (type == kCustomId) {
            pos += 1;
            // DeserializeRawMessage: length(4) || bytes, capped at 1 MiB.
            if (packet.size() - pos < 4) {
                _delegate.log("ERROR! Could not parse message from packet, type: " + std::to_string((int)type));
                return;
            }
            const uint32_t length = readSeqAt(packet.data() + pos);
            pos += 4;
            if (length > 1024 * 1024 || packet.size() - pos < length) {
                _delegate.log("ERROR! Could not parse message from packet, type: " + std::to_string((int)type));
                return;
            }
            std::string message((const char *)packet.data() + pos, length);
            pos += length;

            const bool messageRequiresAck = (currentSeq & kMessageRequiresAckSeqBit) != 0;
            const bool skipMessage = messageRequiresAck
                ? !registerSentAck(currentCounter, firstMessageRequiringAck)
                : (additionalMessage && !registerIncomingCounter(currentCounter));
            if (messageRequiresAck) {
                firstMessageRequiringAck = false;
                if (!skipMessage) {
                    newRequiringAckReceived = true;
                }
                sendAckPostponed(currentSeq);
                _delegate.log(std::string("(signaling) ") + (skipMessage ? "Repeated RECV:type" : "Got RECV:type")
                    + std::to_string((int)type) + "#" + std::to_string(currentCounter));
            }
            if (!skipMessage) {
                received.push_back(std::move(message));
            }
        } else {
            _delegate.log("ERROR! Could not parse message from packet, type: " + std::to_string((int)type));
            return;
        }

        if (pos == packet.size()) {
            break;
        } else if (singleMessagePacket) {
            _delegate.log("ERROR! Single message didn't fill the entire packet.");
            return;
        } else if (packet.size() - pos < 5) {
            _delegate.log("ERROR! Bad remaining data size: " + std::to_string(packet.size() - pos));
            return;
        }
        currentSeq = readSeqAt(packet.data() + pos);
        pos += 4;
        currentCounter = counterFromSeq(currentSeq);
        additionalMessage = true;
    }

    if (!_acksToSendSeqs.empty()) {
        if (newRequiringAckReceived) {
            // Stock: _requestSendService(0, 0) — a deferred immediate send.
            _delegate.requestService(kServiceCauseNow, 0);
        } else if (!_sendAcksTimerActive) {
            _sendAcksTimerActive = true;
            _delegate.requestService(kServiceCauseAcks, kMaxDelayBeforeAckResend);
        }
    }

    // Stock processes decrypted messages after the full packet parse.
    for (auto &message : received) {
        _delegate.deliverMessage(std::move(message));
    }
}

} // namespace v2wasm
} // namespace tgcalls
```

- [ ] **Step 3: Write the scratch behavior test**

`$SCRATCH/framing_test.cpp`:

```cpp
#include <cassert>
#include <cstdio>
#include <memory>
#include <string>
#include <utility>
#include <vector>
#include "v2wasm/SignalingFraming.h"
using namespace tgcalls::v2wasm;

struct Endpoint {
    std::unique_ptr<SignalingFraming> framing;
    std::vector<std::vector<uint8_t>> outbox;
    std::vector<std::string> delivered;
    std::vector<std::pair<int, int>> serviceRequests;
    int64_t now = 1000;
};

static void wire(Endpoint &e, bool isV2) {
    SignalingFraming::Delegate d;
    d.sendPacket = [&e](std::vector<uint8_t> &&p) { e.outbox.push_back(std::move(p)); };
    d.deliverMessage = [&e](std::string &&m) { e.delivered.push_back(std::move(m)); };
    d.requestService = [&e](int cause, int delayMs) { e.serviceRequests.push_back({cause, delayMs}); };
    d.log = [](std::string const &) {};
    d.nowMs = [&e]() { return e.now; };
    e.framing = std::make_unique<SignalingFraming>(isV2, std::move(d));
}

int main() {
    // --- V1 basic round trip + ack clears pending ---
    Endpoint a, b;
    wire(a, false);
    wire(b, false);

    a.framing->sendMessage("{\"m\":1}");
    assert(a.outbox.size() == 1);
    b.framing->receivePacket(a.outbox[0]);
    assert(b.delivered.size() == 1 && b.delivered[0] == "{\"m\":1}");
    // B owes an ack for a requiring-ack message -> immediate service request.
    assert(!b.serviceRequests.empty() && b.serviceRequests.back().first == SignalingFraming::kServiceCauseNow);
    b.framing->onServiceTimer(SignalingFraming::kServiceCauseNow);
    assert(b.outbox.size() == 1); // empty head + ACK
    a.framing->receivePacket(b.outbox[0]);

    // m1 is acked: A's next message packet is exactly seq+id+len+payload.
    const std::string m2 = "{\"m\":2}";
    a.framing->sendMessage(m2);
    assert(a.outbox.size() == 2);
    assert(a.outbox[1].size() == 4 + 1 + 4 + m2.size());

    // --- duplicate custom message is deduped (registerSentAck) ---
    const size_t deliveredBefore = b.delivered.size();
    b.framing->receivePacket(a.outbox[0]); // replay of m1's packet
    assert(b.delivered.size() == deliveredBefore); // "Repeated RECV" -> skipped

    // --- lost packet -> enqueue path piggybacks the pending message ---
    Endpoint c, d2;
    wire(c, false);
    wire(d2, false);
    c.framing->sendMessage("{\"m\":3}"); // packet dropped (never delivered)
    assert(c.outbox.size() == 1);
    c.framing->sendMessage("{\"m\":4}"); // enqueue path -> service packet with m3+m4
    assert(c.outbox.size() == 2);
    d2.framing->receivePacket(c.outbox[1]);
    assert(d2.delivered.size() == 2);
    assert(d2.delivered[0] == "{\"m\":3}" && d2.delivered[1] == "{\"m\":4}");

    // --- V2 gzip round trip + plaintext fallback ---
    Endpoint e, f;
    wire(e, true);
    wire(f, true);
    const std::string big = "{\"@type\":\"offer\",\"sdp\":\"" + std::string(2000, 'x') + "\"}";
    e.framing->sendMessage(big);
    assert(e.outbox.size() == 1);
    assert(e.outbox[0].size() < big.size()); // actually compressed
    f.framing->receivePacket(e.outbox[0]);
    assert(f.delivered.size() == 1 && f.delivered[0] == big);
    // plaintext body (stock tolerates uncompressed): seq || raw json
    std::vector<uint8_t> plain = { 0, 0, 0, 9 };
    const std::string raw = "{\"m\":5}";
    plain.insert(plain.end(), raw.begin(), raw.end());
    f.framing->receivePacket(plain);
    assert(f.delivered.size() == 2 && f.delivered[1] == raw);

    printf("OK\n");
    return 0;
}
```

- [ ] **Step 4: Compile the test — expect failure before the .cpp exists, then pass**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
INC=submodules/TgVoipWebrtc/tgcalls/tgcalls
clang++ -std=c++17 -I $INC $SCRATCH/framing_test.cpp \
    $INC/v2wasm/SignalingFraming.cpp $INC/v2wasm/CoreGzip.cpp $INC/third-party/miniz/miniz.c \
    -o $SCRATCH/framing_test && $SCRATCH/framing_test
```

Expected: `OK`. (If you wrote the test first per TDD, the compile fails with missing `SignalingFraming.h` — that is the red step; then add Steps 1–2 and re-run.)

- [ ] **Step 5: Commit**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/SignalingFraming.h tgcalls/v2wasm/SignalingFraming.cpp
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: SignalingFraming — core-side port of EncryptedConnection reliability (V1) + gzip framing (V2)"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls && git commit -m "build(tgcalls): pin submodule — SignalingFraming component"
```

---

### Task 3: Host cut-over — raw signaling packet boundary

**Files:**
- Modify: `tgcalls/tgcalls/EncryptedConnection.h` (~line 45, next to `encryptRawPacket`), `tgcalls/tgcalls/EncryptedConnection.cpp` (append after `decryptRawPacket`)
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreHost.h`, `tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreABI.h` (signaling contract)

**Interfaces:**
- Consumes: `base64Encode`/`base64Decode` from `v2wasm/CoreBase64.h` (Task 1).
- Produces: host executes `signaling_send_packet {packetB64}` and emits `signaling_packet {packetB64}`; `EncryptedConnection::encryptFullPlaintextPacket` / `decryptFullPlaintextPacket` (Task 4's core will speak this).

**This task opens the red window** (see Global Constraints): compile green, runtime pump signaling broken until Task 4.

- [ ] **Step 1: Additive `EncryptedConnection` methods**

In `EncryptedConnection.h`, after the `encryptRawPacket`/`decryptRawPacket` declarations add:

```cpp
    // Pump-host seam (v2wasm): seal/open a full plaintext packet whose first
    // 4 bytes are the seq chosen by the caller. Additive only — existing
    // methods and their counter handling are untouched.
    absl::optional<rtc::CopyOnWriteBuffer> encryptFullPlaintextPacket(rtc::CopyOnWriteBuffer const &packet);
    // Decrypt + verify + replay-check; returns the full plaintext INCLUDING
    // the 4-byte seq (decryptRawPacket strips it).
    absl::optional<rtc::CopyOnWriteBuffer> decryptFullPlaintextPacket(rtc::CopyOnWriteBuffer const &buffer);
```

In `EncryptedConnection.cpp`, after the `decryptRawPacket` definition add:

```cpp
absl::optional<rtc::CopyOnWriteBuffer> EncryptedConnection::encryptFullPlaintextPacket(rtc::CopyOnWriteBuffer const &packet) {
    if (packet.size() < 5) {
        return absl::nullopt;
    }
    auto encryptedPacket = encryptPrepared(packet);
    rtc::CopyOnWriteBuffer encryptedBuffer;
    encryptedBuffer.AppendData(encryptedPacket.bytes.data(), encryptedPacket.bytes.size());
    return encryptedBuffer;
}

absl::optional<rtc::CopyOnWriteBuffer> EncryptedConnection::decryptFullPlaintextPacket(rtc::CopyOnWriteBuffer const &buffer) {
    if (buffer.size() < 21 || buffer.size() > kMaxIncomingPacketSize) {
        return absl::nullopt;
    }

    const auto x = (_key.isOutgoing ? 8 : 0) + (_type == Type::Signaling ? 128 : 0);
    const auto key = _key.value->data();
    const auto msgKey = reinterpret_cast<const uint8_t*>(buffer.data());
    const auto encryptedData = msgKey + 16;
    const auto dataSize = buffer.size() - 16;

    auto aesKeyIv = PrepareAesKeyIv(key, msgKey, x);

    auto decryptionBuffer = rtc::Buffer(dataSize);
    AesProcessCtr(
        MemorySpan{ encryptedData, dataSize },
        decryptionBuffer.data(),
        std::move(aesKeyIv));

    const auto msgKeyLarge = ConcatSHA256(
        MemorySpan{ key + 88 + x, 32 },
        MemorySpan{ decryptionBuffer.data(), decryptionBuffer.size() });
    if (ConstTimeIsDifferent(msgKeyLarge.data() + 8, msgKey, 16)) {
        return absl::nullopt;
    }

    const auto incomingSeq = ReadSeq(decryptionBuffer.data());
    const auto incomingCounter = CounterFromSeq(incomingSeq);
    if (!registerIncomingCounter(incomingCounter)) {
        // We've received that packet already.
        return absl::nullopt;
    }

    rtc::CopyOnWriteBuffer resultBuffer;
    resultBuffer.AppendData(decryptionBuffer.data(), decryptionBuffer.size());
    return resultBuffer;
}
```

- [ ] **Step 2: CallCoreHost.h — swap the signaling surface**

Remove these declarations/members:

```cpp
    void executeSignalingSend(json11::Json const &command);
    void processIncomingSignalingMessage(std::vector<uint8_t> const &decrypted);
    void sendPendingSignalingServiceData(int cause);
    bool _isSignalingV2 = false;
```

Add in their places:

```cpp
    void executeSignalingSendPacket(json11::Json const &command);
```

```cpp
    // Signaling transport routing only — the framing (gzip, acks, resends,
    // service packets) is core-owned since Phase 2.6.
    bool _useSctpSignalingTransport = false;
    // Host-enforced strict monotonicity of the core-chosen packet counter
    // (low 30 bits of the seq) — preserves AEAD IV freshness.
    uint32_t _lastSentSignalingCounter = 0;
```

- [ ] **Step 3: CallCoreHost.cpp — replace the pipeline**

3a. Add `#include "v2wasm/CoreBase64.h"` next to the other v2wasm includes.

3b. In the constructor replace `_isSignalingV2 = (_wireVersion != "10.0.0");` with `_useSctpSignalingTransport = (_wireVersion != "10.0.0");` and in `start()` change `if (_isSignalingV2) {` (the `SignalingSctpConnection` selection) to `if (_useSctpSignalingTransport) {`.

3c. In `start()`, the `EncryptedConnection` construction: replace the whole `requestSendService` lambda (the `[weak, threads = _threads](int delayMs, int cause) {…}` block) with a no-op, and delete the now-unused capture:

```cpp
    _signalingEncryptedConnection = std::make_unique<EncryptedConnection>(
        EncryptedConnection::Type::Signaling,
        _encryptionKey,
        [](int, int) {
            // Service sends are core policy since Phase 2.6; the raw seal/open
            // methods used by the pump never invoke this callback.
        }
    );
```

3d. In `executeCommand`, replace the dispatch entry:

```cpp
    } else if (type == "signaling_send_packet") {
        executeSignalingSendPacket(command);
```

3e. Replace `executeSignalingSend` with:

```cpp
void CallCoreHost::executeSignalingSendPacket(json11::Json const &command) {
    const auto packet = v2wasm::base64Decode(coreStringField(command, "packetB64"));
    if (!packet || packet->size() < 5) {
        emitErrorEvent("bad packetB64", "signaling_send_packet");
        return;
    }
    if (!_signalingConnection || !_signalingEncryptedConnection) {
        emitErrorEvent("signaling not available", "signaling_send_packet");
        return;
    }
    // seq = first 4 bytes (network order); low 30 bits are the AEAD counter
    // (top two bits are the core's framing flags — see CallCoreABI.h).
    const uint32_t seq = (uint32_t((*packet)[0]) << 24) | (uint32_t((*packet)[1]) << 16)
        | (uint32_t((*packet)[2]) << 8) | uint32_t((*packet)[3]);
    const uint32_t counter = seq & 0x3FFFFFFFu;
    if (counter <= _lastSentSignalingCounter) {
        emitErrorEvent("non-monotonic signaling counter", "signaling_send_packet");
        return;
    }
    const auto sealed = _signalingEncryptedConnection->encryptFullPlaintextPacket(
        rtc::CopyOnWriteBuffer(packet->data(), packet->size()));
    if (!sealed) {
        emitErrorEvent("could not encrypt signaling packet", "signaling_send_packet");
        return;
    }
    _lastSentSignalingCounter = counter;
    RTC_LOG(LS_INFO) << "CallCoreHost signaling_send_packet: counter " << counter << ", " << packet->size() << " plaintext bytes";
    _signalingConnection->send(std::vector<uint8_t>(sealed->data(), sealed->data() + sealed->size()));
}
```

3f. Replace `onSignalingData` with:

```cpp
void CallCoreHost::onSignalingData(const std::vector<uint8_t> &data) {
    if (!_signalingEncryptedConnection) {
        RTC_LOG(LS_ERROR) << "CallCoreHost: receiveSignalingData encryption not available";
        return;
    }
    const auto plaintext = _signalingEncryptedConnection->decryptFullPlaintextPacket(
        rtc::CopyOnWriteBuffer(data.data(), data.size()));
    if (!plaintext) {
        RTC_LOG(LS_ERROR) << "CallCoreHost: could not decrypt signaling packet";
        return;
    }
    deliverEvent({
        {"@type", "signaling_packet"},
        {"packetB64", v2wasm::base64Encode(plaintext->data(), plaintext->size())},
    });
}
```

3g. Delete the `processIncomingSignalingMessage` and `sendPendingSignalingServiceData` definitions entirely, and delete `#include "utils/gzip.h"` if present (verify: `grep -n "gzip" tgcalls/v2wasm/CallCoreHost.cpp` must return nothing afterwards).

- [ ] **Step 4: CallCoreABI.h — rewrite the signaling contract**

In the doc block, replace the `signaling_message` event line with:

```
//   signaling_packet    { packetB64: s }        full plaintext signaling
//                       packet, base64: seq(4 bytes, network order) || body.
//                       The host has already opened the AEAD and replay-
//                       checked the counter (low 30 bits of seq). The body
//                       layout is core policy: V1 (wire 10.0.0) message
//                       packing incl. acks/resends; V2 gzip'd JSON.
```

Replace the `signaling_send` command line with:

```
//   signaling_send_packet { packetB64: s }      full plaintext packet,
//                       base64: seq(4, network order) || body, built by the
//                       core. seq layout: bit31 = single-message-packet,
//                       bit30 = requires-ack (V1 framing flags), low 30 bits
//                       = counter. The host enforces a strictly increasing
//                       counter (AEAD IV freshness), seals with the native
//                       key, and sends via the native transport routing.
//                       Framing (gzip, acks, resend timers via set_timer,
//                       service packets) is entirely core-owned; the
//                       reference core reproduces stock EncryptedConnection
//                       framing byte-for-byte.
```

- [ ] **Step 5: Build (compile-only gate)**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
```

Expected: green. Do NOT run the CLI (red window).

- [ ] **Step 6: Commit**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/EncryptedConnection.h tgcalls/EncryptedConnection.cpp tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp tgcalls/v2wasm/CallCoreABI.h
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: host raw signaling packet boundary (seal/open only; framing moves to core) [red window until core cut-over]"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls && git commit -m "build(tgcalls): pin submodule — host signaling cut-over (red window)"
```

---

### Task 4: Core cut-over — framing integration + BUILD wiring

**Files:**
- Modify: `tgcalls/tgcalls/v2wasm/ReferenceCallCore.h`, `tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (parent repo)

**Interfaces:**
- Consumes: `SignalingFraming` (Task 2), `CoreBase64.h` (Task 1), host `signaling_send_packet`/`signaling_packet` (Task 3).
- Produces (Task 7 relies on): `protected virtual void mungeOutgoingSignalingMessage(json11::Json::object &message)` (default no-op, called on every outgoing signaling message before framing); `protected void sendSignalingKeepalive()`; timer tokens 2/3/4 reserved for framing.

- [ ] **Step 1: ReferenceCallCore.h**

Add `#include <memory>` to the includes, and `#include "v2wasm/SignalingFraming.h"` after the json11 include. In the `protected:` section, after the three existing hooks add:

```cpp
    // Called on every outgoing signaling message before framing; variants
    // may mutate/extend the JSON (unknown keys are ignored by stock peers).
    virtual void mungeOutgoingSignalingMessage(json11::Json::object &message);
```

After `void handleStop();` add:

```cpp
    void sendSignalingMessage(json11::Json::object &&message);
    // Bare V1 keepalive packet (empty message + pending acks/resends);
    // no-op on V2 wires. Variant seam.
    void sendSignalingKeepalive();
```

After the `_emit` member add:

```cpp
    std::unique_ptr<SignalingFraming> _framing;
```

- [ ] **Step 2: ReferenceCallCore.cpp — constants, construction, send/receive paths**

2a. Add `#include "v2wasm/CoreBase64.h"` after the CallCoreABI include.

2b. In the anonymous namespace, after `kStatsTimerToken`:

```cpp
// Timer tokens 2-4 are reserved for the signaling framing (resend / ack /
// deferred-service causes). kStatsTimerToken stays 1.
constexpr int kFramingResendTimerToken = 2;
constexpr int kFramingAcksTimerToken = 3;
constexpr int kFramingServiceNowTimerToken = 4;
```

2c. In the constructor, right after the `for (const auto &server : config["rtcServers"]…)` loop (before the `core_ready` emit), add:

```cpp
    SignalingFraming::Delegate framingDelegate;
    framingDelegate.sendPacket = [this](std::vector<uint8_t> &&packet) {
        this->emit({ {"@type", "signaling_send_packet"}, {"packetB64", base64Encode(packet)} });
    };
    framingDelegate.deliverMessage = [this](std::string &&message) {
        // Load-bearing log line (P1/P2 wire diffs); stock counterpart logs
        // outbound only, this one aids debugging.
        emitLog("signaling in: " + message);
        handleSignalingData(message);
    };
    framingDelegate.requestService = [this](int cause, int delayMs) {
        int token = kFramingServiceNowTimerToken;
        if (cause == SignalingFraming::kServiceCauseAcks) {
            token = kFramingAcksTimerToken;
        } else if (cause == SignalingFraming::kServiceCauseResend) {
            token = kFramingResendTimerToken;
        }
        this->emit({ {"@type", "set_timer"}, {"token", token}, {"delayMs", delayMs} });
    };
    framingDelegate.log = [this](std::string const &line) {
        emitLog(line);
    };
    framingDelegate.nowMs = [this]() {
        return _nowMs;
    };
    _framing = std::make_unique<SignalingFraming>(_wireVersion != "10.0.0", std::move(framingDelegate));
```

2d. Add the new methods (place after `requestSetLocalDescription`):

```cpp
void ReferenceCallCore::sendSignalingMessage(json11::Json::object &&message) {
    mungeOutgoingSignalingMessage(message);
    const std::string data = json11::Json(std::move(message)).dump();
    // Load-bearing log line: the P1/P2 wire diffs key on it (the stock
    // counterpart is InstanceV2ReferenceImpl's "sendSignalingMessage: ").
    emitLog("signaling out: " + data);
    _framing->sendMessage(data);
}

void ReferenceCallCore::mungeOutgoingSignalingMessage(json11::Json::object &message) {
    (void)message;
}

void ReferenceCallCore::sendSignalingKeepalive() {
    _framing->sendKeepalive();
}
```

2e. In `onEvent`, replace the `signaling_message` branch:

```cpp
    if (type == "signaling_packet") {
        const auto packet = base64Decode(stringField(event, "packetB64"));
        if (packet) {
            _framing->receivePacket(*packet);
        }
    }
```

2f. Replace the `pc_ice_candidate` branch's send (keep the candidate object construction unchanged):

```cpp
        emit({ {"@type", "signaling_send"}, … });  // DELETE this line
        sendSignalingMessage(std::move(candidate)); // ADD
```

2g. Same in the `pc_set_local_done` branch: replace the `emit({ {"@type", "signaling_send"}, {"data", …} });` line with `sendSignalingMessage(std::move(description));`.

2h. Replace the `timer` branch:

```cpp
    } else if (type == "timer") {
        const int token = (int)event["token"].number_value();
        if (token == kStatsTimerToken) {
            emit({ {"@type", "pc_get_stats"} });
            emit({ {"@type", "set_timer"}, {"token", kStatsTimerToken}, {"delayMs", 1000} });
        } else if (token == kFramingResendTimerToken) {
            _framing->onServiceTimer(SignalingFraming::kServiceCauseResend);
        } else if (token == kFramingAcksTimerToken) {
            _framing->onServiceTimer(SignalingFraming::kServiceCauseAcks);
        } else if (token == kFramingServiceNowTimerToken) {
            _framing->onServiceTimer(SignalingFraming::kServiceCauseNow);
        }
    }
```

Verify no `signaling_send` or `signaling_message` string remains: `grep -n "signaling_send\"\|signaling_message" tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp` → only `signaling_send_packet` hits.

- [ ] **Step 3: BUILD wiring (parent repo `submodules/TgVoipWebrtc/BUILD`)**

3a. `_WASM_CORE_COMMON_SRCS` (line ~21): add after the `CoreFactory.h` entry:

```python
    "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
    "tgcalls/tgcalls/v2wasm/SignalingFraming.h",
    "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
    "tgcalls/tgcalls/v2wasm/CoreGzip.h",
    "tgcalls/tgcalls/v2wasm/CoreBase64.h",
    "tgcalls/tgcalls/third-party/miniz/miniz.c",
    "tgcalls/tgcalls/third-party/miniz/miniz.h",
```

3b. `_WASM_CORE_CMD` (line ~33): add after the `json11.cpp \\` line:

```
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/SignalingFraming.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CoreGzip.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/third-party/miniz/miniz.c \\
```

(clang++ compiles miniz.c as C++; miniz supports this.)

3c. Native lists — run `grep -n "v2wasm/ReferenceCallCore.cpp" submodules/TgVoipWebrtc/BUILD`; expect hits at ~22 (wasm srcs, done above), ~41 (wasm cmd, done above), ~202 (the `sources = glob(...)` **exclude** list), ~341 (a target's explicit srcs list). Mirror:
- At the exclude-list hit (~202), add adjacent (same 4-space indent):

```python
    "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
    "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
```

  (miniz.c is NOT matched by the glob — no `*.c` pattern — so it needs no exclusion.)
- At the explicit srcs hit (~341), add adjacent (same 8-space indent):

```python
        "tgcalls/tgcalls/v2wasm/SignalingFraming.cpp",
        "tgcalls/tgcalls/v2wasm/CoreGzip.cpp",
        "tgcalls/tgcalls/third-party/miniz/miniz.c",
```

Headers ride the existing `**/*.h` glob.

- [ ] **Step 4: Build + red-window close validation**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
SCRATCH=$(mktemp -d)

# native smoke (NR-style)
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo "NR1 exit $?"
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet; echo "NR-V1 exit $?"
# V1 under 30% signaling loss vs stock — exercises the ported ack/resend layer
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --quiet; echo "NR-V1-loss exit $?"
# wasm smoke
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE --quiet; echo "W1 exit $?"
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE --quiet; echo "W5 exit $?"
# log sanity: the new core-side signaling logs exist
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 8 --log-file $SCRATCH/t4.log --quiet
grep -c "\[core\] signaling out: " $SCRATCH/t4.log   # expect >= 2 (offer + candidates)
grep -c "\[core\] signaling in: " $SCRATCH/t4.log    # expect >= 1
```

Expected: all exits 0, both grep counts nonzero. If a WAMR row fails to instantiate after the module grew (miniz), double the heap/stack constants in `tgcalls/tgcalls/v2wasm/WamrCoreBackend.cpp` and rebuild; record the change.

- [ ] **Step 5: Commit (submodule, then parent incl. BUILD)**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/ReferenceCallCore.h tgcalls/v2wasm/ReferenceCallCore.cpp
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: reference core owns signaling framing (raw packet ABI); munge hook + keepalive seam [red window closed]"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls submodules/TgVoipWebrtc/BUILD
git commit -m "build(tgcalls): wire SignalingFraming/CoreGzip/miniz into wasm modules + native lib; pin submodule"
```

---

### Task 5: Data-channel substrate — N named channels, binary payloads

**Files:**
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreHost.h`, `tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`
- Modify: `tgcalls/tgcalls/v2wasm/ReferenceCallCore.h`, `tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp`
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreABI.h`

**Interfaces:**
- Consumes: `base64Encode`/`base64Decode` (Task 1).
- Produces (Task 7 relies on): events `dc_state {label, open}`, `dc_message {label, data|dataB64}`, `dc_buffered {label, bufferedAmount}`, `dc_channel {label, id}`; command `dc_send {label?, data|dataB64}`; `protected virtual void onDataChannelEvent(json11::Json const &event)` on `ReferenceCallCore` (default no-op, called for every dc_* event after the reference core's own handling).

- [ ] **Step 1: CallCoreHost.h — registry**

Replace:

```cpp
    void attachDataChannel(webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel);
    void onDataChannelStateUpdated();
```

with:

```cpp
    void attachDataChannel(std::string const &label, webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel);
    void onDataChannelStateUpdated(std::string const &label);
    void onDataChannelBufferedAmountChanged(std::string const &label);
    void executeDcSend(json11::Json const &command);
```

Replace the members:

```cpp
    std::unique_ptr<v2wasm_detail::DataChannelObserverImpl> _dataChannelObserver;
    webrtc::scoped_refptr<webrtc::DataChannelInterface> _dataChannel;
    bool _isDataChannelOpen = false;
```

with:

```cpp
    struct HostDataChannel {
        webrtc::scoped_refptr<webrtc::DataChannelInterface> channel;
        std::unique_ptr<v2wasm_detail::DataChannelObserverImpl> observer;
        bool isOpen = false;
        uint64_t lastBufferedAmount = 0;
    };
    std::map<std::string, HostDataChannel> _dataChannels;
```

- [ ] **Step 2: CallCoreHost.cpp — observer, registry, events**

2a. `DataChannelObserverImpl` (~line 95): add to `Parameters`:

```cpp
        std::function<void(uint64_t)> onBufferedAmountChange;
```

and add the override after `OnMessage`:

```cpp
    void OnBufferedAmountChange(uint64_t sentDataSize) override {
        if (_parameters.onBufferedAmountChange) {
            _parameters.onBufferedAmountChange(sentDataSize);
        }
    }
```

2b. Add a constant near the top of the file's anonymous namespace: `constexpr size_t kMaxDcMessageBytes = 256 * 1024;`

2c. Replace `executeCreateDataChannel`'s tail (after building `dataChannelInit` and `label`, which stay as-is):

```cpp
    if (_dataChannels.count(label)) {
        emitErrorEvent("duplicate data channel label", "pc_create_data_channel");
        return;
    }
    auto dataChannelOrError = _peerConnection->CreateDataChannelOrError(label, &dataChannelInit);
    if (dataChannelOrError.ok()) {
        attachDataChannel(label, dataChannelOrError.value());
    } else {
        emitErrorEvent("CreateDataChannelOrError failed", "pc_create_data_channel");
    }
```

2d. Replace `attachDataChannel` and `onDataChannelStateUpdated`:

```cpp
void CallCoreHost::attachDataChannel(std::string const &label, webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel) {
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());

    v2wasm_detail::DataChannelObserverImpl::Parameters dataChannelObserverParams;
    dataChannelObserverParams.onStateChange = [threads = _threads, weak, label]() {
        threads->getMediaThread()->PostTask([weak, label]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->onDataChannelStateUpdated(label);
        });
    };
    dataChannelObserverParams.onMessage = [threads = _threads, weak, label](webrtc::DataBuffer const &buffer) {
        const auto strong = weak.lock();
        if (!strong) {
            return;
        }
        if (!buffer.binary) {
            std::string message(buffer.data.data(), buffer.data.data() + buffer.data.size());
            strong->deliverEvent({ {"@type", "dc_message"}, {"label", label}, {"data", message} });
        } else {
            strong->deliverEvent({
                {"@type", "dc_message"},
                {"label", label},
                {"dataB64", v2wasm::base64Encode((const uint8_t *)buffer.data.data(), buffer.data.size())},
            });
        }
    };
    dataChannelObserverParams.onBufferedAmountChange = [threads = _threads, weak, label](uint64_t) {
        threads->getMediaThread()->PostTask([weak, label]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->onDataChannelBufferedAmountChanged(label);
        });
    };

    auto &entry = _dataChannels[label];
    entry.observer = std::make_unique<v2wasm_detail::DataChannelObserverImpl>(std::move(dataChannelObserverParams));
    entry.channel = dataChannel;
    onDataChannelStateUpdated(label);
    entry.channel->RegisterObserver(entry.observer.get());
}

void CallCoreHost::onDataChannelStateUpdated(std::string const &label) {
    const auto it = _dataChannels.find(label);
    if (it == _dataChannels.end() || !it->second.channel) {
        return;
    }
    const bool open = (it->second.channel->state() == webrtc::DataChannelInterface::DataState::kOpen);
    if (open != it->second.isOpen) {
        it->second.isOpen = open;
        deliverEvent({ {"@type", "dc_state"}, {"label", label}, {"open", open} });
    }
}

void CallCoreHost::onDataChannelBufferedAmountChanged(std::string const &label) {
    const auto it = _dataChannels.find(label);
    if (it == _dataChannels.end() || !it->second.channel) {
        return;
    }
    const uint64_t amount = it->second.channel->buffered_amount();
    if (amount == 0 && it->second.lastBufferedAmount != 0) {
        deliverEvent({ {"@type", "dc_buffered"}, {"label", label}, {"bufferedAmount", 0} });
    }
    it->second.lastBufferedAmount = amount;
}
```

2e. Replace the inline `dc_send` dispatch branch with `executeDcSend(command);` and add:

```cpp
void CallCoreHost::executeDcSend(json11::Json const &command) {
    std::string label = coreStringField(command, "label");
    if (label.empty()) {
        label = "data";
    }
    const auto it = _dataChannels.find(label);
    if (it == _dataChannels.end()) {
        emitErrorEvent("unknown data channel label", "dc_send");
        return;
    }
    if (!it->second.isOpen) {
        emitErrorEvent("data channel not open", "dc_send");
        return;
    }
    if (command["dataB64"].is_string()) {
        const auto bytes = v2wasm::base64Decode(command["dataB64"].string_value());
        if (!bytes || bytes->size() > kMaxDcMessageBytes) {
            emitErrorEvent("bad dc payload", "dc_send");
            return;
        }
        RTC_LOG(LS_INFO) << "CallCoreHost dc_send: [" << label << "] " << bytes->size() << " binary bytes";
        it->second.channel->Send(webrtc::DataBuffer(rtc::CopyOnWriteBuffer(bytes->data(), bytes->size()), true));
    } else {
        const auto data = coreStringField(command, "data");
        if (data.size() > kMaxDcMessageBytes) {
            emitErrorEvent("bad dc payload", "dc_send");
            return;
        }
        RTC_LOG(LS_INFO) << "CallCoreHost dc_send: [" << label << "] " << data;
        it->second.channel->Send(webrtc::DataBuffer(data));
    }
    it->second.lastBufferedAmount = it->second.channel->buffered_amount();
}
```

2f. `PeerConnectionDelegateAdapter::OnDataChannel` (~line 196):

```cpp
    void OnDataChannel(webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel) override {
        if (const auto strong = _host.lock()) {
            const std::string label = dataChannel->label();
            if (strong->_dataChannels.count(label)) {
                strong->emitErrorEvent("duplicate remote data channel label", "dc_channel");
                return;
            }
            strong->deliverEvent({ {"@type", "dc_channel"}, {"label", label}, {"id", dataChannel->id()} });
            strong->attachDataChannel(label, dataChannel);
        }
    }
```

2g. Destructor: replace the `_dataChannel`/`_dataChannelObserver` cleanup block with:

```cpp
    for (auto &it : _dataChannels) {
        if (it.second.channel) {
            it.second.channel->UnregisterObserver();
            it.second.channel = nullptr;
        }
        it.second.observer.reset();
    }
    _dataChannels.clear();
```

Verify nothing else references the old members: `grep -n "_dataChannel\b\|_dataChannelObserver\|_isDataChannelOpen" tgcalls/tgcalls/v2wasm/CallCoreHost.cpp tgcalls/tgcalls/v2wasm/CallCoreHost.h` → no hits.

- [ ] **Step 3: ReferenceCallCore — label guards + hook**

3a. Header, after `mungeOutgoingSignalingMessage`:

```cpp
    // Called for every dc_state/dc_message/dc_buffered/dc_channel event,
    // after the reference core's own (label "data") handling.
    virtual void onDataChannelEvent(json11::Json const &event);
```

3b. cpp — replace the `dc_state`/`dc_message` branches and add the two new types:

```cpp
    } else if (type == "dc_state") {
        if (stringField(event, "label") == "data") {
            const bool open = event["open"].bool_value();
            if (open && !_isDataChannelOpen) {
                _isDataChannelOpen = true;
                sendMediaState();
            } else if (!open) {
                _isDataChannelOpen = false;
            }
        }
        onDataChannelEvent(event);
    } else if (type == "dc_message") {
        if (stringField(event, "label") == "data") {
            // stock feeds non-binary data-channel messages into processSignalingData
            handleSignalingData(stringField(event, "data"));
        }
        onDataChannelEvent(event);
    } else if (type == "dc_buffered" || type == "dc_channel") {
        onDataChannelEvent(event);
    }
```

3c. Add the default hook body (next to `mungeOutgoingSignalingMessage`):

```cpp
void ReferenceCallCore::onDataChannelEvent(json11::Json const &event) {
    (void)event;
}
```

- [ ] **Step 4: CallCoreABI.h — dc contract**

Replace the `dc_state`/`dc_message` event lines and `dc_send` command line; add the new entries:

```
//   dc_state            { label: s, open: bool }
//   dc_message          { label: s, data?: s, dataB64?: s }  text arrives as
//                       data, binary as dataB64 (base64)
//   dc_buffered         { label: s, bufferedAmount: n }  emitted when a
//                       channel's send buffer drains to 0 (backpressure:
//                       send a batch, wait for drain)
//   dc_channel          { label: s, id: n }   remote-announced channel
//                       (OnDataChannel); registered under its label,
//                       dc_send/dc_state/dc_message work on it thereafter
```

```
//   dc_send             { label?: s (default "data"), data?: s, dataB64?: s }
//                       exactly one of data/dataB64; max 256 KiB; unknown
//                       label or closed channel -> "error" event
```

And extend the `pc_create_data_channel` line's comment: `callable N times; labels unique among core-created channels (duplicate -> "error" event)`. Add one budget line to the Rules block: `- BUDGET: data channels are control-plane; modules should stay in the ≲10 Hz / KB-scale envelope (enforcement: Phase-4 metering).`

- [ ] **Step 5: Build + validate**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
SCRATCH=$(mktemp -d)
# native + wasm smoke; the callee side receives the "data" channel via
# OnDataChannel -> exercises dc_channel + remote registration + MediaState
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet; echo "exit $?"
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE --log-file $SCRATCH/t5.log --quiet; echo "exit $?"
grep -c "dc_channel" $SCRATCH/t5.log     # expect >= 1 when pump is callee… may be 0 with pump as caller — run reverse too:
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --wasm-core2 $WASM --log-file $SCRATCH/t5b.log --quiet; echo "exit $?"
grep -c "dc_channel" $SCRATCH/t5b.log    # expect >= 1 (pump callee receives stock's "data" channel)
grep -c "\"error\"" $SCRATCH/t5b.log     # expect 0 dc-related error events (inspect any hits)
```

Expected: exits 0; `dc_channel` present in the reverse run; no dc error events.

- [ ] **Step 6: Commit**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp tgcalls/v2wasm/ReferenceCallCore.h tgcalls/v2wasm/ReferenceCallCore.cpp tgcalls/v2wasm/CallCoreABI.h
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: N-labeled data channels with binary payloads + dc_channel/dc_buffered events; onDataChannelEvent hook"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls && git commit -m "build(tgcalls): pin submodule — dc substrate"
```

---

### Task 6: Session-config knobs — APM + SetConfiguration

**Files:**
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreHost.h`, `tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`
- Modify: `tgcalls/tgcalls/v2wasm/CallCoreABI.h`

**Interfaces:**
- Consumes: nothing new.
- Produces (Task 7 relies on): commands `set_audio_processing {echoCancellation?, noiseSuppression?, autoGainControl?, highPassFilter?}` (also accepted as `pc_create.audioProcessing {…}`) and `pc_set_configuration {iceServers?, iceTransportsType?, candidatePoolSize?}`.

- [ ] **Step 1: CallCoreHost.h**

Add declarations (next to `executePcCreate`):

```cpp
    void applyAudioProcessingConfig(json11::Json const &config, std::string const &commandName);
    void executeSetConfiguration(json11::Json const &command);
```

Add member (next to `_audioDeviceModule`):

```cpp
    webrtc::scoped_refptr<webrtc::AudioProcessing> _audioProcessing;
```

- [ ] **Step 2: CallCoreHost.cpp**

2a. In `start()` replace:

```cpp
    webrtc::AudioProcessingBuilder builder;
    peerConnectionFactoryDependencies.audio_processing = builder.Create();
```

with:

```cpp
    webrtc::AudioProcessingBuilder builder;
    _audioProcessing = builder.Create();
    peerConnectionFactoryDependencies.audio_processing = _audioProcessing;
```

2b. Add the two methods (after `executePcCreate`):

```cpp
void CallCoreHost::applyAudioProcessingConfig(json11::Json const &config, std::string const &commandName) {
    if (!_audioProcessing) {
        emitErrorEvent("no audio processing", commandName);
        return;
    }
    auto apmConfig = _audioProcessing->GetConfig();
    if (config["echoCancellation"].is_bool()) {
        apmConfig.echo_canceller.enabled = config["echoCancellation"].bool_value();
    }
    if (config["noiseSuppression"].is_bool()) {
        apmConfig.noise_suppression.enabled = config["noiseSuppression"].bool_value();
    }
    if (config["autoGainControl"].is_bool()) {
        // Maps to the classic AGC only (gain_controller1); AGC2 is untouched.
        apmConfig.gain_controller1.enabled = config["autoGainControl"].bool_value();
    }
    if (config["highPassFilter"].is_bool()) {
        apmConfig.high_pass_filter.enabled = config["highPassFilter"].bool_value();
    }
    RTC_LOG(LS_INFO) << "CallCoreHost: ApplyConfig audio processing (" << commandName << ")";
    _audioProcessing->ApplyConfig(apmConfig);
}

void CallCoreHost::executeSetConfiguration(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_set_configuration");
        return;
    }
    // Merge ONLY the exposed keys into the live configuration so fields the
    // host chose at pc_create (sdp semantics, bundle policy, ...) survive.
    auto configuration = _peerConnection->GetConfiguration();
    if (command["iceTransportsType"].is_string()) {
        configuration.type = (coreStringField(command, "iceTransportsType") == "all")
            ? webrtc::PeerConnectionInterface::IceTransportsType::kAll
            : webrtc::PeerConnectionInterface::IceTransportsType::kRelay;
    }
    if (command["candidatePoolSize"].is_number()) {
        configuration.ice_candidate_pool_size = (int)command["candidatePoolSize"].number_value();
    }
    if (command["iceServers"].is_array()) {
        configuration.servers.clear();
        for (const auto &server : command["iceServers"].array_items()) {
            webrtc::PeerConnectionInterface::IceServer mappedServer;
            for (const auto &url : server["urls"].array_items()) {
                mappedServer.urls.push_back(url.string_value());
            }
            mappedServer.username = coreStringField(server, "username");
            mappedServer.password = coreStringField(server, "password");
            configuration.servers.push_back(mappedServer);
        }
    }
    const auto result = _peerConnection->SetConfiguration(configuration);
    if (!result.ok()) {
        emitErrorEvent(std::string("SetConfiguration failed: ") + result.message(), "pc_set_configuration");
    }
}
```

2c. In `executeCommand`, add dispatch entries (after `pc_create_data_channel`):

```cpp
    } else if (type == "set_audio_processing") {
        applyAudioProcessingConfig(command, "set_audio_processing");
    } else if (type == "pc_set_configuration") {
        executeSetConfiguration(command);
```

2d. At the end of `executePcCreate` (after the `CreatePeerConnectionOrError` block):

```cpp
    if (command["audioProcessing"].is_object()) {
        applyAudioProcessingConfig(command["audioProcessing"], "pc_create");
    }
```

If `webrtc::AudioProcessing`'s full type is not visible, add `#include "modules/audio_processing/include/audio_processing.h"` next to the other webrtc includes.

- [ ] **Step 3: CallCoreABI.h — knob contract**

Add to the commands block (after `pc_create_data_channel`):

```
//   set_audio_processing { echoCancellation?: bool, noiseSuppression?: bool,
//                          autoGainControl?: bool, highPassFilter?: bool }
//                       host ApplyConfig on its retained APM; only supplied
//                       keys change; autoGainControl maps to the classic AGC
//                       (gain_controller1). Also accepted at creation as
//                       pc_create.audioProcessing { same keys }.
//   pc_set_configuration { iceServers?: [ { urls: [s], username: s,
//                            password: s } ],
//                          iceTransportsType?: "all"|"relay",
//                          candidatePoolSize?: n }
//                       host merges ONLY these keys into GetConfiguration()
//                       then SetConfiguration; webrtc rejections surface as
//                       "error" events
```

And extend the `pc_create` command doc with `audioProcessing?: { … }  (optional APM overrides, defaults = stock)`.

- [ ] **Step 4: Build + smoke**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo "exit $?"
```

Expected: green build, exit 0 (the reference core never calls the new commands — behavior identical; real exercise comes from the Task-7 variant).

- [ ] **Step 5: Commit**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp tgcalls/v2wasm/CallCoreABI.h
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: session-config knobs — set_audio_processing (ApplyConfig) + pc_set_configuration (SetConfiguration merge)"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls && git commit -m "build(tgcalls): pin submodule — session-config knobs"
```

---

### Task 7: Variant demos — padding, keepalive, exp0 ping/pong, APM/config

**Files:**
- Modify: `tgcalls/tgcalls/v2wasm/VariantCallCore.h`, `tgcalls/tgcalls/v2wasm/VariantCallCore.cpp`

**Interfaces:**
- Consumes: `mungeOutgoingSignalingMessage` + `sendSignalingKeepalive` (Task 4), `onDataChannelEvent` + dc events/commands (Task 5), `set_audio_processing`/`pc_set_configuration` (Task 6). Protected state from `ReferenceCallCore`: `_isOutgoing`, `_wireVersion`, `_isConnected`, `_hasVideoTrack`, `_nowMs`; variant-local `_statsTicks`.
- Produces: marker log lines `variant: pad N`, `variant: keepalive N`, `variant: dc pong N`, `variant: apm applied`, `variant: config applied` (V-matrix asserts grep on `[core] variant: …`).

- [ ] **Step 1: VariantCallCore.h**

Update the doc comment to list the new behaviors (5–8) and add to the class:

```cpp
    void mungeOutgoingSignalingMessage(json11::Json::object &message) override;
    void onDataChannelEvent(json11::Json const &event) override;
```

and private members:

```cpp
    int _padCount = 0;
    int _keepaliveCount = 0;
    bool _apmApplied = false;
    bool _configApplied = false;
```

- [ ] **Step 2: VariantCallCore.cpp — constructor + hooks**

2a. Constructor body, after the `variant: core active` log:

```cpp
    // Experiment channel: negotiated (both sides create id 5 locally; no
    // in-band announcement, so a stock peer simply never opens it — the
    // strongest form of non-interference).
    emit({ {"@type", "pc_create_data_channel"}, {"label", "exp0"}, {"negotiated", true}, {"id", 5} });
```

2b. New hook implementations (place before `onStats`):

```cpp
void VariantCallCore::mungeOutgoingSignalingMessage(json11::Json::object &message) {
    const auto typeIt = message.find("@type");
    if (typeIt == message.end() || !typeIt->second.is_string() || typeIt->second.string_value() != "candidate") {
        return;
    }
    // Traffic-shape padding demo via an unknown JSON key (stock signaling
    // parsers ignore unknown fields inside known message types). The core has
    // no entropy source, so an LCG stands in — the point is the seam + stock
    // tolerance, not cryptographic-quality cover traffic.
    _padCount += 1;
    uint32_t state = 2654435761u * (uint32_t)_padCount;
    static const char kChars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    std::string pad;
    pad.reserve(256);
    for (int i = 0; i < 256; i++) {
        state = state * 1664525u + 1013904223u;
        pad.push_back(kChars[(state >> 24) % 62]);
    }
    message["_pad"] = pad;
    emitLog("variant: pad " + std::to_string(_padCount));
}

void VariantCallCore::onDataChannelEvent(json11::Json const &event) {
    const auto type = event["@type"].string_value();
    if (event["label"].string_value() != "exp0") {
        return;
    }
    if (type == "dc_state" && event["open"].bool_value() && _isOutgoing) {
        emit({ {"@type", "dc_send"}, {"label", "exp0"}, {"data", "ping 1"} });
    } else if (type == "dc_message") {
        const auto data = event["data"].string_value();
        if (data.rfind("ping ", 0) == 0) {
            const int n = std::atoi(data.c_str() + 5);
            emit({ {"@type", "dc_send"}, {"label", "exp0"}, {"data", "pong " + std::to_string(n)} });
            emitLog("variant: dc pong " + std::to_string(n));
        } else if (data.rfind("pong ", 0) == 0) {
            const int n = std::atoi(data.c_str() + 5);
            emitLog("variant: dc pong " + std::to_string(n));
            if (n < 5) {
                emit({ {"@type", "dc_send"}, {"label", "exp0"}, {"data", "ping " + std::to_string(n + 1)} });
            }
        }
    }
}
```

2c. In `onStats`, at the very end (after the ICE-restart block):

```cpp
    // V1 keepalive demo: a bare empty framing packet every 5 stats ticks on
    // the 10.0.0 wire — stock peers parse and discard empty messages.
    if (_wireVersion == "10.0.0" && _statsTicks % 5 == 0) {
        sendSignalingKeepalive();
        _keepaliveCount += 1;
        emitLog("variant: keepalive " + std::to_string(_keepaliveCount));
    }
    // Session-config demos: one-shot APM toggle and a benign SetConfiguration.
    if (!_apmApplied && _statsTicks >= 10) {
        _apmApplied = true;
        emit({ {"@type", "set_audio_processing"}, {"noiseSuppression", false}, {"autoGainControl", false} });
        emitLog("variant: apm applied");
    }
    if (!_configApplied && _statsTicks >= 12) {
        _configApplied = true;
        emit({ {"@type", "pc_set_configuration"}, {"candidatePoolSize", 2} });
        emitLog("variant: config applied");
    }
```

- [ ] **Step 3: Build + new V-matrix rows**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
SCRATCH=$(mktemp -d)

# V-A: variant<->variant dc ping/pong
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --wasm-core $VARIANT --duration 20 --log-file $SCRATCH/va.log --quiet; echo "V-A exit $?"
grep -c "variant: dc pong" $SCRATCH/va.log          # expect >= 6 (both sides, n up to 5)

# V-B + V-C1 + stock non-interference: variant caller vs stock callee
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --wasm-core $VARIANT --wasm-core2 NONE --duration 16 --log-file $SCRATCH/vbc.log --quiet; echo "V-B/C1 exit $?"
grep -c "variant: pad " $SCRATCH/vbc.log            # expect >= 1 (candidates padded, stock still parses)
grep -c "variant: apm applied" $SCRATCH/vbc.log     # expect 1
grep -c "variant: config applied" $SCRATCH/vbc.log  # expect 1
grep -c "SetConfiguration failed" $SCRATCH/vbc.log  # expect 0
grep -c "variant: dc pong" $SCRATCH/vbc.log         # expect 0 (exp0 never opens vs stock)

# V-C2: 10.0.0 keepalive vs stock
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --wasm-core $VARIANT --wasm-core2 NONE --duration 18 --log-file $SCRATCH/vc2.log --quiet; echo "V-C2 exit $?"
grep -c "variant: keepalive" $SCRATCH/vc2.log       # expect >= 2
grep -c "Bad incoming data hash" $SCRATCH/vc2.log   # expect 0 (stock decrypts everything)
grep -c "Could not parse message" $SCRATCH/vc2.log  # expect 0
```

Expected: all exits 0 and grep thresholds met. If `variant: dc pong` is 0 in V-A, check that `dc_state` for exp0 reaches the variant (host `dc_state` now carries `label`) and that both sides created the negotiated channel.

- [ ] **Step 4: Commit**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/VariantCallCore.h tgcalls/v2wasm/VariantCallCore.cpp
git -C submodules/TgVoipWebrtc/tgcalls commit -m "v2wasm: variant demos — signaling padding, V1 keepalive, exp0 dc ping/pong, APM/config knobs (wasm-only)"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls && git commit -m "build(tgcalls): pin submodule — Phase-2.6 variant demos"
```

---

### Task 8: Full validation sweep + iOS build + docs + spec record

**Files:**
- Modify: `tgcalls/tgcalls/v2wasm/CLAUDE.md`, `tgcalls/CLAUDE.md` (submodule)
- Modify: root `CLAUDE.md` (testbench bullet), `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-protocol-substrate-design.md` (append results) (parent)

**Interfaces:** consumes everything; produces the validation record.

- [ ] **Step 1: Write the diff scripts**

`$SCRATCH/p1_diff.py` (JSON-layer offer/answer parity; works for both wire versions):

```python
#!/usr/bin/env python3
"""p1_diff.py RUN_A.log RUN_B.log — compare offer/answer SDP at the JSON layer.
Extracts outbound signaling JSON from stock ('sendSignalingMessage: ') and
pump ('[core] signaling out: ') log lines; normalizes per-run-random SDP
lines; MATCH required for offer and answer."""
import json, re, sys

PATTERNS = [re.compile(r"sendSignalingMessage: (\{.*)$"),
            re.compile(r"\[core\] signaling out: (\{.*)$")]
STRIP = re.compile(r"^(o=|a=ice-ufrag|a=ice-pwd|a=fingerprint|a=ssrc|a=msid-semantic|a=candidate)")

def extract(path):
    out = {}
    for line in open(path, errors="replace"):
        for pat in PATTERNS:
            m = pat.search(line)
            if not m:
                continue
            try:
                msg = json.loads(m.group(1))
            except ValueError:
                continue
            t = msg.get("@type")
            if t in ("offer", "answer") and t not in out:
                sdp = msg.get("sdp", "")
                out[t] = "\n".join(l for l in sdp.split("\r\n") if l and not STRIP.match(l))
    return out

a, b = extract(sys.argv[1]), extract(sys.argv[2])
ok = True
for t in ("offer", "answer"):
    if a.get(t) and a.get(t) == b.get(t):
        print(f"{t}: MATCH")
    else:
        ok = False
        print(f"{t}: MISMATCH")
        for name, d in (("A", a), ("B", b)):
            print(f"--- {name} ---")
            print(d.get(t, "<missing>")[:2000])
sys.exit(0 if ok else 1)
```

`$SCRATCH/p2_framing.py` (V1 framing behavior invariants on a 10.0.0 run log):

```python
#!/usr/bin/env python3
"""p2_framing.py LOG — V1 framing invariants (applies to stock AND pump logs):
every sent requiring-ack message is eventually acked, at least one ACK was
appended, and no framing/decrypt errors occurred."""
import re, sys

log = open(sys.argv[1], errors="replace").read()
sends = set(re.findall(r"(?:Add|Enqueue) SEND:type127#(\d+)", log))
acks = set(re.findall(r"Got ACK:type127#(\d+)", log))
missing = sends - acks
errors = [l for l in log.splitlines()
          if "ERROR!" in l or "Bad incoming data hash" in l or "could not decrypt signaling" in l]
print(f"sends={len(sends)} acked={len(acks & sends)} missing={sorted(missing)} "
      f"added_acks={'Add ACK#' in log} errors={len(errors)}")
for l in errors[:10]:
    print("ERR:", l.strip())
ok = sends and not missing and "Add ACK#" in log and not errors
sys.exit(0 if ok else 1)
```

- [ ] **Step 2: Full W/NR matrix re-run**

```bash
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
SCRATCH=$(mktemp -d)
run() { echo "== $1"; shift; $CLI --mode p2p --quiet "$@"; echo "exit $?"; }

run W1  --version 11.0.0-pump --version2 11.0.0      --duration 10 --wasm-core $WASM --wasm-core2 NONE
run W2  --version 11.0.0      --version2 11.0.0-pump --duration 10 --wasm-core2 $WASM
run W3  --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM
run W4  --version 11.0.0-pump --version2 11.0.0      --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM --wasm-core2 NONE
run W5  --version 10.0.0-pump --version2 10.0.0      --duration 10 --wasm-core $WASM --wasm-core2 NONE
run W5b --version 10.0.0      --version2 10.0.0-pump --duration 10 --wasm-core2 $WASM
run W5c --version 10.0.0-pump --version2 10.0.0      --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM --wasm-core2 NONE
run W7  --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM --wasm-core2 NONE
run W8  --version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM
run NR1 --version 11.0.0-pump --version2 11.0.0      --duration 10
run NR2 --version 11.0.0      --version2 11.0.0-pump --duration 10
run NR3 --version 11.0.0-pump --version2 11.0.0-pump --duration 10
run NR4 --version 10.0.0-pump --version2 10.0.0-pump --duration 10
run BL1 --version 10.0.0      --version2 10.0.0      --duration 30 --drop-rate 0.3 --delay 50-200   # stock baseline for the loss row
```

Expected: every row exit 0. W5c is the new row proving the **ported V1 resend layer recovers signaling under 30% loss against a stock peer** (BL1 is its stock-stock baseline). W6 remains an honest skip (`run-local-test.sh` cannot forward `--wasm-core`).

- [ ] **Step 3: P1 + P2**

```bash
# P1 (11.0.0): pump-caller vs stock-caller
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --wasm-core $WASM --wasm-core2 NONE --duration 8 --log-file $SCRATCH/p1_pump.log --quiet
$CLI --mode p2p --version 11.0.0      --version2 11.0.0 --duration 8 --log-file $SCRATCH/p1_stock.log --quiet
python3 $SCRATCH/p1_diff.py $SCRATCH/p1_pump.log $SCRATCH/p1_stock.log

# P2 (10.0.0): JSON-layer parity + framing invariants on both runs
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --wasm-core $WASM --wasm-core2 NONE --duration 10 --log-file $SCRATCH/p2_pump.log --quiet
$CLI --mode p2p --version 10.0.0      --version2 10.0.0 --duration 10 --log-file $SCRATCH/p2_stock.log --quiet
python3 $SCRATCH/p1_diff.py $SCRATCH/p2_pump.log $SCRATCH/p2_stock.log
python3 $SCRATCH/p2_framing.py $SCRATCH/p2_pump.log
python3 $SCRATCH/p2_framing.py $SCRATCH/p2_stock.log
```

Expected: `offer: MATCH` + `answer: MATCH` twice; both `p2_framing.py` runs exit 0 (all sends acked, ACKs appended, zero errors). If P2 MISMATCHes on SDP content, that is a genuine parity regression — do not extend the STRIP list without root-causing (the 2.5 baseline needed no extensions). Known limitation of `p2_framing.py` (acceptable, do not "fix"): both call sides log into one file and counters are per-side, so the send/ack sets union across sides — a missed ack masked by the other side's identical counter would slip through; systematic failures (no acks at all, parse/decrypt errors) are still caught, and the interop rows (W5/W5b/W5c) cover the rest.

- [ ] **Step 4: V-matrix re-run (2.5 rows + 2.6 rows)**

Re-run the four Task-7 commands (V-A, V-B/C1, V-C2) and the 2.5 rows V1–V4 exactly as recorded in the "Variant matrix (V1–V4)" section of `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md` (same flags; markers `variant: core active` / `munge applied` / `cap` / `ice_restart` still asserted at the same thresholds). The variant now additionally emits pad/apm/config markers during those runs — expected, not a failure. Record all counts.

- [ ] **Step 5: Module size + iOS build**

```bash
wc -c bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm  # record (miniz+framing growth)
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Expected: iOS build green (the native lib now compiles SignalingFraming/CoreGzip/miniz for iOS).

- [ ] **Step 6: Docs**

- `tgcalls/tgcalls/v2wasm/CLAUDE.md`: status line → Phase 2.6 complete; files table: add `SignalingFraming.{h,cpp}`, `CoreGzip.{h,cpp}`, `CoreBase64.h`, note miniz vendoring and the amended include discipline (`+ miniz`); `CallCoreABI.h` row: mention raw signaling packet boundary, N-channel dc surface, config knobs; variant recipe: list the five hooks (`mungeLocalDescription`, `mungeOutgoingSignalingMessage`, `onStats`, `onIceState`, `onDataChannelEvent`) + `sendSignalingKeepalive`; invariants: add "the signaling framing constants/byte layout in SignalingFraming.cpp are wire-frozen (copied from EncryptedConnection.cpp)" and "the `[core] signaling out:`/`sendSignalingMessage:` log strings are load-bearing (P1/P2)".
- `tgcalls/CLAUDE.md`: update the v2wasm project-structure line if it names the ABI shape.
- Root `CLAUDE.md` (parent): extend the v2wasm bullet's parenthetical with "…rich stats, and since Phase 2.6 core-owned signaling framing, N named data channels, and audio/ICE config knobs".
- Spec: append a `## Validation results (Phase 2.6)` section mirroring the 2.5 format — W/NR/P/V tables with exits and marker counts, module sizes, iOS build proof, plus a **Deviations** subsection recording at minimum: (a) `exp0` uses `negotiated:true, id:5` rather than in-band announcement (stronger non-interference; `dc_channel` coverage comes from the standard `"data"` channel on the callee side), and (b) the spec's "loss-path resend behavior is untestable in the lossless CLI" risk note is **retired** — the CLI's `--drop-rate` applies to the signaling bridge, and W5c proves resend recovery under 30% loss.

- [ ] **Step 7: Commit (submodule docs, then parent docs + pin)**

```bash
git -C submodules/TgVoipWebrtc/tgcalls add tgcalls/v2wasm/CLAUDE.md CLAUDE.md
git -C submodules/TgVoipWebrtc/tgcalls commit -m "docs(v2wasm): Phase 2.6 — framing/dc/knobs surfaces, hooks, load-bearing log lines"
cd /Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch
git add submodules/TgVoipWebrtc/tgcalls CLAUDE.md docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-protocol-substrate-design.md
git commit -m "docs(tgcalls): Phase-2.6 validation results + root doc update; pin submodule"
```

---

## Self-Review (performed at plan-writing time)

- **Spec coverage:** raw packet boundary → T2/T3/T4; host sheds framing (`_isSignalingV2` removed, transport routing renamed) → T3; miniz + include-discipline amendment → T1/T4; logging point moves into core → T4 (2d); hook additions (`mungeOutgoingSignalingMessage`, `onDataChannelEvent`, keepalive seam) → T4/T5; dc substrate (N labels, binary, dc_buffered/dc_channel, budget note) → T5; APM + SetConfiguration → T6; variant demos V-A/V-B/V-C1/V-C2 → T7; P1 re-run + new P2 + W/NR + loss rows + module size + iOS build + spec record → T8. Supersession note (reference core rewritten once, freeze re-applies) is encoded in the T4 commit and the T8 doc updates.
- **Type consistency:** `SignalingFraming::Delegate` signatures match between T2 (definition) and T4 (wiring); `base64Encode(std::vector<uint8_t> const&)` overload used in T4 core / `base64Encode(const uint8_t*, size_t)` in T5 host — both defined in T1; `encryptFullPlaintextPacket`/`decryptFullPlaintextPacket` names match T3 header/impl/callers; timer tokens 2/3/4 defined and dispatched only in T4; `onDataChannelEvent` declared T5 and overridden T7.
- **Known deliberate deviations from stock:** none on the wire. Internal: the immediate-ack service send goes through a 0 ms `set_timer` round-trip instead of a PostTask (same deferral semantics); the framing keeps its own `_largestIncomingCounters` shadow (state matches stock exactly because packet-level counters are registered too).
