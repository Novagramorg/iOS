# tgcalls WASM-core Phase 1 (pump boundary) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `InstanceV2ReferenceImpl`'s control logic as a message-pump "core" behind a C ABI (`v2wasm/`), wire-compatible with stock versions `10.0.0`/`11.0.0`, validated by real interop calls in `tgcalls_cli`.

**Architecture:** Three-layer split per the approved spec (`docs/superpowers/specs/2026-07-01-tgcalls-wasm-core-pump-design.md`): `ReferenceCallCore` (pure logic, JSON events in / JSON commands out, compiled under WASM discipline), `CallCoreHost` (harness owning PeerConnection/ADM/EncryptedConnection/SCTP/timers/stats), `InstanceV2PumpImpl` (Instance shell registered as `10.0.0-pump`/`11.0.0-pump`). Stock impl untouched.

**Tech Stack:** C++17, json11 (vendored in tgcalls), WebRTC (`third-party/webrtc`), Bazel 8.4.2, `tgcalls_cli` test rig.

## Global Constraints

- Working directory: the worktree root `/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch` (all paths below relative to it).
- **Two repos:** `v2wasm/*` and `tools/cli/main.cpp` live in the **tgcalls submodule** (`submodules/TgVoipWebrtc/tgcalls`); `submodules/TgVoipWebrtc/BUILD` and docs live in the **parent repo**. Commit in the right repo; the submodule works on branch `tgcalls-wasm-core-sketch`.
- **Core discipline (spec):** `ReferenceCallCore.*` may include ONLY `v2wasm/CallCoreABI.h`, `third-party/json11.hpp`, and C++17 std headers. No webrtc, no absl, no other tgcalls headers. No key material in the core config.
- **Wire parity:** signaling bytes must be byte-identical to stock. Both sides use json11 (`Json::object` = `std::map`, key-sorted output), so identical keys ⇒ identical bytes. Key names are copied verbatim from stock in the code below — do not "improve" them.
- Stock files are read-only: `tgcalls/tgcalls/v2/InstanceV2ReferenceImpl.{h,cpp}` must not change.
- Build: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc:tgcalls_core` (compile check) and `.../tools/cli:tgcalls_cli` (link + run). A cold baseline build was started in the session background — wait for it before the first bazel step.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- No unit-test infra exists in this C++ tree (project CLAUDE.md); the test cycle is: clang syntax-check per file → bazel compile → CLI interop matrix.

---

### Task 1: Submodule branch + `CallCoreABI.h` + spec amendment

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h`
- Modify: `docs/superpowers/specs/2026-07-01-tgcalls-wasm-core-pump-design.md` (events table: add `pc_signaling_state`; note `nowMs`)

**Interfaces:**
- Consumes: nothing.
- Produces: `TgcallsCallCore` (opaque), `TgcallsCoreEmitFn`, `tgcalls_core_create(const char*, TgcallsCoreEmitFn, void*) -> TgcallsCallCore*`, `tgcalls_core_on_event(TgcallsCallCore*, const uint8_t*, size_t)`, `tgcalls_core_destroy(TgcallsCallCore*)`. Tasks 2–4 depend on these exact names.

- [ ] **Step 1: Create the submodule branch**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git checkout -b tgcalls-wasm-core-sketch && cd ../../..
```

Expected: `Switched to a new branch 'tgcalls-wasm-core-sketch'` (from the detached submodule HEAD).

- [ ] **Step 2: Write the ABI header**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h`:

```c
#ifndef TGCALLS_V2WASM_CALL_CORE_ABI_H
#define TGCALLS_V2WASM_CALL_CORE_ABI_H

#include <stddef.h>
#include <stdint.h>

// ============================================================================
// tgcalls call-core ABI, version 1.
//
// This is the frozen seam between the fixed native harness ("host") and the
// swappable call-control logic ("core"). It is shaped exactly like the future
// WASM boundary: the three functions below are the module exports, and the
// single emit callback is the module import. All payloads are UTF-8 JSON
// objects tagged with "@type".
//
// Rules (normative):
// - THREADING: all calls into the core happen on one thread (the tgcalls
//   media thread). The core never blocks and owns no threads/timers; it asks
//   the host for time via the "set_timer" command.
// - REENTRANCY: the emit callback may be invoked only from inside
//   tgcalls_core_create / tgcalls_core_on_event, on the same thread. The host
//   queues emitted commands and executes them AFTER the core call returns.
//   Results of asynchronous commands are delivered as later events.
// - MEMORY: buffers passed to the core are valid only for the duration of the
//   call; buffers passed to emit are valid only for the duration of the
//   callback. Each side copies what it keeps (WASM linear-memory contract).
// - EXTENSIBILITY: the core MUST ignore events with an unknown "@type". The
//   host MUST reply to an unknown or malformed command with an "error" event
//   and MUST NOT crash. The config carries "abiVersion"; the core echoes it
//   in "core_ready" and the host refuses a mismatch.
// - CLOCK: the core has no clock. Every event carries "nowMs" (int64 as JSON
//   number, host monotonic milliseconds); the core uses the latest value.
//
// Config (tgcalls_core_create):
//   { "abiVersion": 1, "wireVersion": "11.0.0", "isOutgoing": bool,
//     "enableP2P": bool, "customParameters": string,
//     "rtcServers": [ { "host": s, "port": n, "login": s, "password": s,
//                       "isTurn": bool, "isTcp": bool } ] }
//   No key material, ever.
//
// Events (host -> core): "@type" plus fields, all carry "nowMs":
//   signaling_message   { data: string }        plaintext, un-gzipped JSON
//   pc_renegotiation_needed {}
//   pc_ice_candidate    { mid: s, mline: n, sdp: s }
//   pc_ice_state        { state: "new"|"checking"|"connected"|"completed"|
//                                "failed"|"disconnected"|"closed" }
//   pc_signaling_state  { state: "stable"|"have-local-offer"|
//                                "have-remote-offer"|"have-local-pranswer"|
//                                "have-remote-pranswer"|"closed" }
//   pc_candidate_pair_changed { local: {type,protocol,address},
//                               remote: {type,protocol,address} }
//   pc_set_local_done   { ok: bool, type: "offer"|"answer", sdp: s }
//   pc_set_remote_done  { ok: bool, sdpType: "offer"|"answer" }
//   dc_state            { open: bool }
//   dc_message          { data: string }        text messages only
//   timer               { token: n }
//   stats               { sendBitrateKbps: n }
//   mute                { muted: bool }
//   battery_low         { low: bool }
//   video_capture       { active: bool, screencast: bool }
//   stop                {}                      core replies stats_log + close
//   error               { message: s, command: s }
//
// Commands (core -> host): "@type" plus fields:
//   core_ready          { abiVersion: n }
//   pc_create           { iceTransportsType: "all"|"relay",
//                         iceServers: [ { urls: [s], username: s,
//                                         password: s } ] }
//   pc_set_local_description  {}                modern no-arg SLD
//   pc_set_remote_description { sdpType: s, sdp: s }
//   pc_add_ice_candidate      { mid: s, mline: n, sdp: s }
//   pc_add_audio_track        { maxBitrateBps: n }
//   pc_add_video_track        { codecPreferences: [s], maxBitrateBps: n }
//   pc_remove_video_track     {}
//   pc_set_audio_track_enabled { enabled: bool }
//   pc_create_data_channel    {}
//   dc_send             { data: string }
//   signaling_send      { data: string }        plaintext; host gzips (V2)
//                                               and encrypts
//   set_timer           { token: n, delayMs: n }
//   request_stats       {}
//   emit_state          { state: "established"|"failed"|"reconnecting" }
//   emit_signal_bars    { bars: 0..4 }
//   emit_remote_media_state { audio: "active"|"muted",
//                             video: "inactive"|"paused"|"active" }
//   emit_remote_battery_low { low: bool }
//   log                 { message: s }
//   stats_log           { json: s }             host writes at stop
//   close               {}                      host closes PC, completes stop
// ============================================================================

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TgcallsCallCore TgcallsCallCore;

typedef void (*TgcallsCoreEmitFn)(void *userData, const uint8_t *data, size_t len);

TgcallsCallCore *tgcalls_core_create(const char *configJson, TgcallsCoreEmitFn emit, void *userData);
void tgcalls_core_on_event(TgcallsCallCore *core, const uint8_t *data, size_t len);
void tgcalls_core_destroy(TgcallsCallCore *core);

#ifdef __cplusplus
}
#endif

#endif
```

- [ ] **Step 3: Syntax-check the header**

```bash
clang -std=c11 -fsyntax-only submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h && \
clang++ -std=c++17 -fsyntax-only -x c++ submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Amend the spec** — in `docs/superpowers/specs/2026-07-01-tgcalls-wasm-core-pump-design.md`, add to the events table (after the `pc_candidate_pair_changed` row):

```markdown
| `pc_signaling_state` | `state`: `stable`\|`have-local-offer`\|`have-remote-offer`\|`have-local-pranswer`\|`have-remote-pranswer`\|`closed` | `OnSignalingChange` (core needs it for the perfect-negotiation `isReadyForOffer` check, which stock reads synchronously from `signaling_state()`) |
```

and add one sentence to the ABI section: `Every event carries "nowMs" (host monotonic ms) — the core has no clock; it timestamps its stats-log records from the latest event.`

- [ ] **Step 5: Commit (both repos)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreABI.h && \
git commit -m "feat(v2wasm): call-core C ABI header (pump boundary, abi v1)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add docs/superpowers/specs/2026-07-01-tgcalls-wasm-core-pump-design.md && \
git commit -m "docs(tgcalls): spec amendment: pc_signaling_state event + nowMs clock rule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `ReferenceCallCore` (the ported control logic)

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (parent repo: add `ReferenceCallCore.cpp` to both source lists)

**Interfaces:**
- Consumes: `CallCoreABI.h` symbols from Task 1.
- Produces: the ABI functions' implementation. Also class `tgcalls::v2wasm::ReferenceCallCore` with `ReferenceCallCore(json11::Json config, std::function<void(json11::Json::object &&)> emit)` and `void onEvent(json11::Json const &event)` (used only by the extern "C" wrappers; hosts use the C ABI).
- Port source of truth: `tgcalls/tgcalls/v2/InstanceV2ReferenceImpl.cpp` (read-only) — negotiation lines 883–944, 1121–1174; signaling parse 1000–1119; media state 1273–1293; signal bars 856–879; stats log 1458–1537.

- [ ] **Step 1: Write the header**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.h`:

```cpp
#ifndef TGCALLS_V2WASM_REFERENCE_CALL_CORE_H
#define TGCALLS_V2WASM_REFERENCE_CALL_CORE_H

// Control-logic core for the pump-based reference call implementation.
// WASM discipline: this unit may include only CallCoreABI.h, json11 and the
// C++17 standard library. It has no clock, no threads, and never blocks.

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "third-party/json11.hpp"

namespace tgcalls {
namespace v2wasm {

class ReferenceCallCore {
public:
    ReferenceCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit);

    void onEvent(json11::Json const &event);

private:
    struct NetworkStateRecord {
        int64_t timestampMs = 0;
        bool isConnected = false;
        bool isFailed = false;
        json11::Json connection; // object {local:{...},remote:{...}} or null
    };
    struct BitrateRecord {
        int64_t timestampMs = 0;
        int32_t bitrateKbps = 0;
    };

    void emit(json11::Json::object &&command);
    void emitLog(std::string const &message);
    void requestSetLocalDescription();
    void handleSignalingData(std::string const &data);
    void handleRemoteSdp(std::string const &type, std::string const &sdp);
    void handleMediaStateMessage(json11::Json const &message);
    void flushPendingRemoteCandidates();
    void sendMediaState();
    void updateNetworkState(bool isConnected, bool isFailed);
    void emitMappedState();
    void handleStop();

    std::function<void(json11::Json::object &&)> _emit;

    // config
    bool _isOutgoing = false;
    bool _enableP2P = false;
    std::string _wireVersion;
    std::vector<json11::Json> _rtcServers;

    // clock (from event nowMs)
    int64_t _nowMs = 0;

    // negotiation state (ported 1:1 from InstanceV2ReferenceImplInternal)
    bool _didBeginNegotiation = false;
    bool _isMakingOffer = false;
    bool _isSettingRemoteAnswerPending = false;
    bool _haveLocalDescription = false;
    bool _haveRemoteDescription = false;
    std::string _signalingState = "stable";
    std::vector<json11::Json> _pendingRemoteCandidates;

    // media state
    bool _isMicrophoneMuted = false;
    bool _isBatteryLow = false;
    bool _hasVideoCapture = false;
    bool _hasVideoTrack = false;
    bool _isDataChannelOpen = false;

    // network state + logs
    bool _isConnected = false;
    bool _isFailed = false;
    json11::Json _currentConnection; // null until first candidate pair
    std::vector<NetworkStateRecord> _networkStateRecords;
    std::vector<BitrateRecord> _bitrateRecords;
};

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 2: Write the implementation**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp`:

```cpp
#include "v2wasm/ReferenceCallCore.h"
#include "v2wasm/CallCoreABI.h"

#include <algorithm>
#include <memory>

namespace tgcalls {
namespace v2wasm {

namespace {

constexpr int kAbiVersion = 1;
constexpr int kStatsTimerToken = 1;
constexpr int kAudioMaxBitrateBps = 32 * 1024;      // stock: 32 * 1024
constexpr int kVideoMaxBitrateBps = 1200 * 1024;    // stock: 1200 * 1024

std::string stringField(json11::Json const &object, std::string const &key) {
    const auto &value = object[key];
    return value.is_string() ? value.string_value() : std::string();
}

} // namespace

ReferenceCallCore::ReferenceCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit) :
_emit(std::move(emit)) {
    _isOutgoing = config["isOutgoing"].bool_value();
    _enableP2P = config["enableP2P"].bool_value();
    _wireVersion = stringField(config, "wireVersion");
    for (const auto &server : config["rtcServers"].array_items()) {
        _rtcServers.push_back(server);
    }

    this->emit({ {"@type", "core_ready"}, {"abiVersion", kAbiVersion} });

    // Policy: map RtcServers to ICE servers (stock start() lines 641–685).
    json11::Json::array iceServers;
    for (const auto &server : _rtcServers) {
        if (server["isTcp"].bool_value()) {
            continue;
        }
        const auto host = stringField(server, "host");
        const auto port = std::to_string((int)server["port"].number_value());
        if (server["isTurn"].bool_value()) {
            iceServers.push_back(json11::Json::object{
                {"urls", json11::Json::array{ "turn:" + host + ":" + port }},
                {"username", stringField(server, "login")},
                {"password", stringField(server, "password")},
            });
        } else {
            iceServers.push_back(json11::Json::object{
                {"urls", json11::Json::array{ "stun:" + host + ":" + port }},
                {"username", ""},
                {"password", ""},
            });
        }
    }
    this->emit({
        {"@type", "pc_create"},
        {"iceTransportsType", _enableP2P ? "all" : "relay"},
        {"iceServers", std::move(iceServers)},
    });

    if (_isOutgoing) {
        this->emit({ {"@type", "pc_create_data_channel"} });
    }
    this->emit({ {"@type", "pc_add_audio_track"}, {"maxBitrateBps", kAudioMaxBitrateBps} });

    // stock beginSignaling()
    _didBeginNegotiation = true;
    if (_isOutgoing) {
        requestSetLocalDescription();
    }

    // stock beginLogTimer(0)
    this->emit({ {"@type", "set_timer"}, {"token", kStatsTimerToken}, {"delayMs", 0} });
}

void ReferenceCallCore::emit(json11::Json::object &&command) {
    _emit(std::move(command));
}

void ReferenceCallCore::emitLog(std::string const &message) {
    emit({ {"@type", "log"}, {"message", message} });
}

void ReferenceCallCore::onEvent(json11::Json const &event) {
    if (event["nowMs"].is_number()) {
        _nowMs = (int64_t)event["nowMs"].number_value();
    }
    const auto type = stringField(event, "@type");

    if (type == "signaling_message") {
        handleSignalingData(stringField(event, "data"));
    } else if (type == "pc_renegotiation_needed") {
        // stock onRenegotiationNeeded delegate
        if (_didBeginNegotiation) {
            if (_isOutgoing || _haveRemoteDescription) {
                requestSetLocalDescription();
            }
        } else {
            emitLog("onRenegotiationNeeded: not sending local description");
        }
    } else if (type == "pc_ice_candidate") {
        // stock sendIceCandidate: exact wire keys @type/sdp/mid/mline
        json11::Json::object candidate{
            {"@type", "candidate"},
            {"sdp", stringField(event, "sdp")},
            {"mid", stringField(event, "mid")},
            {"mline", (int)event["mline"].number_value()},
        };
        emit({ {"@type", "signaling_send"}, {"data", json11::Json(std::move(candidate)).dump()} });
    } else if (type == "pc_ice_state") {
        const auto state = stringField(event, "state");
        bool isConnected = (state == "connected" || state == "completed");
        bool isFailed = (state == "failed");
        if (_isConnected != isConnected || _isFailed != isFailed) {
            updateNetworkState(isConnected, isFailed);
        }
    } else if (type == "pc_signaling_state") {
        _signalingState = stringField(event, "state");
    } else if (type == "pc_candidate_pair_changed") {
        json11::Json::object connection{
            {"local", event["local"]},
            {"remote", event["remote"]},
        };
        json11::Json connectionJson(std::move(connection));
        if (_currentConnection != connectionJson) {
            _currentConnection = std::move(connectionJson);
            updateNetworkState(_isConnected, _isFailed);
        }
    } else if (type == "pc_set_local_done") {
        _isMakingOffer = false;
        if (event["ok"].bool_value()) {
            _haveLocalDescription = true;
            // stock doSendLocalDescription: exact wire keys @type/sdp
            json11::Json::object description{
                {"@type", stringField(event, "type")},
                {"sdp", stringField(event, "sdp")},
            };
            emit({ {"@type", "signaling_send"}, {"data", json11::Json(std::move(description)).dump()} });
        } else {
            emitLog("SetLocalDescription failed");
        }
        flushPendingRemoteCandidates();
    } else if (type == "pc_set_remote_done") {
        _isSettingRemoteAnswerPending = false;
        if (event["ok"].bool_value()) {
            _haveRemoteDescription = true;
            flushPendingRemoteCandidates();
            if (stringField(event, "sdpType") == "offer") {
                requestSetLocalDescription();
            }
        } else {
            emitLog("SetRemoteDescription failed");
        }
    } else if (type == "dc_state") {
        const bool open = event["open"].bool_value();
        if (open && !_isDataChannelOpen) {
            _isDataChannelOpen = true;
            sendMediaState();
        } else if (!open) {
            _isDataChannelOpen = false;
        }
    } else if (type == "dc_message") {
        // stock feeds non-binary data-channel messages into processSignalingData
        handleSignalingData(stringField(event, "data"));
    } else if (type == "timer") {
        if ((int)event["token"].number_value() == kStatsTimerToken) {
            emit({ {"@type", "request_stats"} });
            emit({ {"@type", "set_timer"}, {"token", kStatsTimerToken}, {"delayMs", 1000} });
        }
    } else if (type == "stats") {
        // stock writeStateLogRecords signal-bars heuristic
        const double sendBitrateKbps = event["sendBitrateKbps"].number_value();
        double bitrateNorm = _hasVideoTrack ? 600.0 : 16.0;
        double adjustedQuality = sendBitrateKbps / bitrateNorm;
        adjustedQuality = std::max(0.0, std::min(1.0, adjustedQuality));
        emit({ {"@type", "emit_signal_bars"}, {"bars", (int)(adjustedQuality * 4.0)} });

        BitrateRecord record;
        record.timestampMs = _nowMs;
        record.bitrateKbps = (int32_t)sendBitrateKbps;
        _bitrateRecords.push_back(record);
    } else if (type == "mute") {
        const bool muted = event["muted"].bool_value();
        if (_isMicrophoneMuted != muted) {
            _isMicrophoneMuted = muted;
            emit({ {"@type", "pc_set_audio_track_enabled"}, {"enabled", !muted} });
            sendMediaState();
        }
    } else if (type == "battery_low") {
        const bool low = event["low"].bool_value();
        if (_isBatteryLow != low) {
            _isBatteryLow = low;
            sendMediaState();
        }
    } else if (type == "video_capture") {
        // stock setVideoCapture: always remove, re-add for non-screencast capture
        if (_hasVideoTrack) {
            emit({ {"@type", "pc_remove_video_track"} });
            _hasVideoTrack = false;
        }
        _hasVideoCapture = event["active"].bool_value() && !event["screencast"].bool_value();
        if (_hasVideoCapture) {
            emit({
                {"@type", "pc_add_video_track"},
                {"codecPreferences", json11::Json::array{ "H265", "H264" }},
                {"maxBitrateBps", kVideoMaxBitrateBps},
            });
            _hasVideoTrack = true;
        }
        if (_didBeginNegotiation) {
            sendMediaState();
            requestSetLocalDescription();
        }
    } else if (type == "stop") {
        handleStop();
    } else if (type == "error") {
        emitLog("host error: " + stringField(event, "message") + " (command: " + stringField(event, "command") + ")");
        if (stringField(event, "command") == "pc_create") {
            updateNetworkState(false, true);
        }
    } else {
        // Unknown event: ignore (ABI rule).
    }
}

void ReferenceCallCore::requestSetLocalDescription() {
    _isMakingOffer = true;
    emit({ {"@type", "pc_set_local_description"} });
}

void ReferenceCallCore::handleSignalingData(std::string const &data) {
    std::string parsingError;
    const auto json = json11::Json::parse(data, parsingError);
    if (!json.is_object()) {
        emitLog("Signaling: message must be an object");
        return;
    }
    const auto type = stringField(json, "@type");
    if (type.empty()) {
        emitLog("Signaling: @type is missing");
        return;
    }

    if (type == "offer" || type == "answer") {
        const auto sdp = stringField(json, "sdp");
        if (sdp.empty()) {
            emitLog("Signaling: sdp is missing");
            return;
        }
        handleRemoteSdp(type, sdp);
    } else if (type == "candidate") {
        if (!json["mid"].is_string() || !json["mline"].is_number() || !json["sdp"].is_string()) {
            return;
        }
        json11::Json::object candidate{
            {"@type", "pc_add_ice_candidate"},
            {"mid", json["mid"]},
            {"mline", json["mline"]},
            {"sdp", json["sdp"]},
        };
        if (_haveLocalDescription && _haveRemoteDescription) {
            emit(std::move(candidate));
        } else {
            _pendingRemoteCandidates.push_back(json11::Json(std::move(candidate)));
        }
    } else if (type == "MediaState") {
        handleMediaStateMessage(json);
    } else {
        // Other signaling::Message kinds are not used by the reference protocol.
    }
}

void ReferenceCallCore::handleRemoteSdp(std::string const &type, std::string const &sdp) {
    // stock handleRemoteSdp perfect-negotiation gate, verbatim semantics
    bool isReadyForOffer = !_isMakingOffer && (_signalingState == "stable" || _isSettingRemoteAnswerPending);
    bool isOfferCollision = (type == "offer") && !isReadyForOffer;
    bool ignoreOffer = !_isOutgoing && isOfferCollision;
    if (ignoreOffer) {
        emitLog("Ignoring remote sdp");
        return;
    }

    _isSettingRemoteAnswerPending = (type == "answer");
    emit({ {"@type", "pc_set_remote_description"}, {"sdpType", type}, {"sdp", sdp} });
}

void ReferenceCallCore::handleMediaStateMessage(json11::Json const &message) {
    // wire keys from stock MediaStateMessage_serialize:
    // muted / lowBattery / videoState / screencastState (values inactive|suspended|active)
    const auto audio = message["muted"].bool_value() ? "muted" : "active";

    const auto mapVideo = [](std::string const &value) -> std::string {
        if (value == "suspended") {
            return "paused";
        } else if (value == "active") {
            return "active";
        }
        return "inactive";
    };
    const auto videoState = mapVideo(stringField(message, "videoState"));
    const auto screencastState = mapVideo(stringField(message, "screencastState"));
    // stock: screencast overrides video when active or paused
    const auto effectiveVideo = (screencastState == "active" || screencastState == "paused") ? screencastState : videoState;

    emit({ {"@type", "emit_remote_media_state"}, {"audio", audio}, {"video", effectiveVideo} });
    emit({ {"@type", "emit_remote_battery_low"}, {"low", message["lowBattery"].bool_value()} });
}

void ReferenceCallCore::flushPendingRemoteCandidates() {
    if (_pendingRemoteCandidates.empty()) {
        return;
    }
    if (!_haveLocalDescription || !_haveRemoteDescription) {
        return;
    }
    for (auto &candidate : _pendingRemoteCandidates) {
        json11::Json::object command = candidate.object_items();
        emit(std::move(command));
    }
    _pendingRemoteCandidates.clear();
}

void ReferenceCallCore::sendMediaState() {
    if (!_isDataChannelOpen) {
        return;
    }
    // wire format from stock MediaStateMessage_serialize (Signaling.cpp):
    // keys @type/muted/lowBattery/videoState/videoRotation/screencastState
    json11::Json::object message{
        {"@type", "MediaState"},
        {"muted", _isMicrophoneMuted},
        {"lowBattery", _isBatteryLow},
        {"videoState", (_hasVideoTrack && _hasVideoCapture) ? "active" : "inactive"},
        {"videoRotation", 0},
        {"screencastState", "inactive"},
    };
    emit({ {"@type", "dc_send"}, {"data", json11::Json(std::move(message)).dump()} });
}

void ReferenceCallCore::updateNetworkState(bool isConnected, bool isFailed) {
    _isConnected = isConnected;
    _isFailed = isFailed;

    NetworkStateRecord record;
    record.timestampMs = _nowMs;
    record.isConnected = _isConnected;
    record.isFailed = _isFailed;
    record.connection = _currentConnection;
    if (_networkStateRecords.empty()
        || _networkStateRecords.back().isConnected != record.isConnected
        || _networkStateRecords.back().isFailed != record.isFailed
        || !(_networkStateRecords.back().connection == record.connection)) {
        _networkStateRecords.push_back(record);
    }

    emitMappedState();
}

void ReferenceCallCore::emitMappedState() {
    std::string mappedState;
    if (_isFailed) {
        mappedState = "failed";
    } else if (_isConnected) {
        mappedState = "established";
    } else {
        mappedState = "reconnecting";
    }
    emit({ {"@type", "emit_state"}, {"state", mappedState} });
}

void ReferenceCallCore::handleStop() {
    // stock stop(): coalesce events within 5ms, then serialize "v":3 stats log
    for (int i = (int)_networkStateRecords.size() - 1; i >= 1; i--) {
        if (_networkStateRecords[i].timestampMs - _networkStateRecords[i - 1].timestampMs < 5) {
            _networkStateRecords.erase(_networkStateRecords.begin() + i - 1);
        }
    }

    json11::Json::array networkRecords;
    int64_t baseTimestamp = 0;
    for (const auto &record : _networkStateRecords) {
        json11::Json::object jsonRecord;
        if (baseTimestamp == 0) {
            baseTimestamp = record.timestampMs;
        }
        jsonRecord.insert(std::make_pair("t", json11::Json(std::to_string(record.timestampMs - baseTimestamp))));
        jsonRecord.insert(std::make_pair("c", json11::Json(record.isConnected ? 1 : 0)));
        if (record.connection.is_object()) {
            jsonRecord.insert(std::make_pair("network", record.connection));
        }
        if (record.isFailed) {
            jsonRecord.insert(std::make_pair("failed", json11::Json(1)));
        }
        networkRecords.push_back(json11::Json(std::move(jsonRecord)));
    }

    json11::Json::array bitrateRecords;
    for (const auto &record : _bitrateRecords) {
        bitrateRecords.push_back(json11::Json(json11::Json::object{ {"b", record.bitrateKbps} }));
    }

    json11::Json::object statsLog{
        {"v", 3},
        {"network", std::move(networkRecords)},
        {"bitrate", std::move(bitrateRecords)},
    };
    emit({ {"@type", "stats_log"}, {"json", json11::Json(std::move(statsLog)).dump()} });
    emit({ {"@type", "close"} });
}

} // namespace v2wasm
} // namespace tgcalls

// ============================================================================
// C ABI wrappers
// ============================================================================

struct TgcallsCallCore {
    std::unique_ptr<tgcalls::v2wasm::ReferenceCallCore> impl;
};

extern "C" {

TgcallsCallCore *tgcalls_core_create(const char *configJson, TgcallsCoreEmitFn emitFn, void *userData) {
    if (!emitFn) {
        return nullptr;
    }
    std::string parsingError;
    const auto config = json11::Json::parse(configJson ? configJson : "", parsingError);

    auto core = new TgcallsCallCore();
    core->impl = std::make_unique<tgcalls::v2wasm::ReferenceCallCore>(config, [emitFn, userData](json11::Json::object &&command) {
        const std::string serialized = json11::Json(std::move(command)).dump();
        emitFn(userData, (const uint8_t *)serialized.data(), serialized.size());
    });
    return core;
}

void tgcalls_core_on_event(TgcallsCallCore *core, const uint8_t *data, size_t len) {
    if (!core || !core->impl || !data) {
        return;
    }
    std::string parsingError;
    const auto event = json11::Json::parse(std::string((const char *)data, len), parsingError);
    if (!event.is_object()) {
        return;
    }
    core->impl->onEvent(event);
}

void tgcalls_core_destroy(TgcallsCallCore *core) {
    delete core;
}

} // extern "C"
```

- [ ] **Step 3: Syntax-check (this is the WASM-discipline gate)**

```bash
clang++ -std=c++17 -fsyntax-only \
  -I submodules/TgVoipWebrtc/tgcalls/tgcalls \
  submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp && echo OK
```

Expected: `OK`. Note the include path proves the discipline: only the tgcalls root (for `third-party/json11.hpp` and `v2wasm/…`) is needed — no webrtc/absl paths.

- [ ] **Step 4: Add to BUILD (parent repo)** — in `submodules/TgVoipWebrtc/BUILD`, add after **each** of the two `"tgcalls/tgcalls/v2/InstanceV2ReferenceImpl.cpp",` lines (the `sources` list ~line 126 and the `tgcalls_core` srcs ~line 259):

```python
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
```

(Match the indentation of the surrounding list — 4 spaces in `sources`, 8 in `tgcalls_core`.)

- [ ] **Step 5: Bazel compile check** (wait for the background baseline build to finish first; then this is incremental)

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc:tgcalls_core 2>&1 | tail -5
```

Expected: `Build completed successfully`.

- [ ] **Step 6: Commit (both repos)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/ReferenceCallCore.h tgcalls/v2wasm/ReferenceCallCore.cpp && \
git commit -m "feat(v2wasm): ReferenceCallCore — control logic ported behind the pump ABI

Perfect negotiation, signaling wire protocol, MediaState, signal bars,
stats-log shaping. Includes only CallCoreABI.h + json11 + std (WASM
discipline). Wire keys copied verbatim from InstanceV2ReferenceImpl /
Signaling.cpp for byte parity.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): compile v2wasm/ReferenceCallCore.cpp into tgcalls targets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `CallCoreHost` (the fixed harness)

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (add `CallCoreHost.cpp` to both lists, same spots as Task 2)

**Interfaces:**
- Consumes: C ABI from Task 1 (`tgcalls_core_create`/`tgcalls_core_on_event`/`tgcalls_core_destroy`).
- Produces: `class tgcalls::CallCoreHost : public std::enable_shared_from_this<CallCoreHost>` with:
  - `CallCoreHost(Descriptor &&descriptor, std::shared_ptr<Threads> threads)`
  - `void start()` — must be called on the media thread
  - `void receiveSignalingData(const std::vector<uint8_t> &data)`
  - `void setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture)`
  - `void setMuteMicrophone(bool mute)`, `void setIsLowBatteryLevel(bool low)`
  - `void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink)`
  - `void setAudioInputDevice(std::string id)`, `void setAudioOutputDevice(std::string id)`
  - `void stop(std::function<void(FinalState)> completion)`
  Task 4's `InstanceV2PumpImpl` calls exactly these.

This file is mostly a re-plumbing of stock `InstanceV2ReferenceImplInternal` (helper classes `PeerConnectionDelegateAdapter`, `SetSessionDescriptionObserver`, `StatsCollectorCallbackAdapter`, `DataChannelObserverImpl` are duplicated from the stock cpp's anonymous namespace — they are file-private there). Where the stock file consults negotiation state, the host instead forwards an event / executes a command.

- [ ] **Step 1: Write the header**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h`:

```cpp
#ifndef TGCALLS_V2WASM_CALL_CORE_HOST_H
#define TGCALLS_V2WASM_CALL_CORE_HOST_H

#include <deque>
#include <memory>

#include "Instance.h"
#include "StaticThreads.h"

#include "third-party/json11.hpp"

#include "api/peer_connection_interface.h"
#include "rtc_base/network_monitor_factory.h"
#include "p2p/base/basic_packet_socket_factory.h"
#include "p2p/base/relay_port_factory_interface.h"

#include "v2wasm/CallCoreABI.h"

namespace tgcalls {

class EncryptedConnection;
class SignalingConnection;
class VideoCaptureInterface;

namespace v2wasm_detail {
class PeerConnectionDelegateAdapter;
class DataChannelObserverImpl;
} // namespace v2wasm_detail

// Fixed harness for the pump boundary: owns PeerConnection, ADM, signaling
// crypto/transport, timers and stats; executes core commands and forwards
// platform callbacks to the core as events. Lives on the media thread.
class CallCoreHost final : public std::enable_shared_from_this<CallCoreHost> {
public:
    CallCoreHost(Descriptor &&descriptor, std::shared_ptr<Threads> threads);
    ~CallCoreHost();

    void start();

    void receiveSignalingData(const std::vector<uint8_t> &data);
    void setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture);
    void setMuteMicrophone(bool mute);
    void setIsLowBatteryLevel(bool low);
    void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    void setAudioInputDevice(std::string id);
    void setAudioOutputDevice(std::string id);
    void stop(std::function<void(FinalState)> completion);

private:
    friend class v2wasm_detail::PeerConnectionDelegateAdapter;

    static void coreEmitTrampoline(void *userData, const uint8_t *data, size_t len);

    void deliverEvent(json11::Json::object &&event);
    void deliverEventNow(json11::Json::object &&event);
    void processPendingCommands();
    void executeCommand(json11::Json const &command);
    void emitErrorEvent(std::string const &message, std::string const &commandType);

    void executePcCreate(json11::Json const &command);
    void executeSetLocalDescription();
    void executeSetRemoteDescription(json11::Json const &command);
    void executeAddIceCandidate(json11::Json const &command);
    void executeAddAudioTrack(json11::Json const &command);
    void executeAddVideoTrack(json11::Json const &command);
    void executeRemoveVideoTrack();
    void executeCreateDataChannel();
    void executeSignalingSend(json11::Json const &command);
    void executeRequestStats();
    void executeClose();

    void attachDataChannel(webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel);
    void onDataChannelStateUpdated();
    void onSignalingData(const std::vector<uint8_t> &data);
    void processIncomingSignalingMessage(std::vector<uint8_t> const &decrypted);
    void sendPendingSignalingServiceData(int cause);
    void connectIncomingVideoSink(webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver);
    webrtc::scoped_refptr<webrtc::AudioDeviceModule> createAudioDeviceModule();

    std::shared_ptr<Threads> _threads;

    // descriptor
    std::string _wireVersion;
    bool _isSignalingV2 = false;
    std::vector<RtcServer> _rtcServers;
    bool _enableP2P = false;
    EncryptionKey _encryptionKey;
    std::string _customParameters;
    std::function<void(State)> _stateUpdated;
    std::function<void(int)> _signalBarsUpdated;
    std::function<void(bool)> _remoteBatteryLevelIsLowUpdated;
    std::function<void(AudioState, VideoState)> _remoteMediaStateUpdated;
    std::function<void(const std::vector<uint8_t> &)> _signalingDataEmitted;
    std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory *)> _createAudioDeviceModule;
    std::function<webrtc::scoped_refptr<WrappedAudioDeviceModule>(webrtc::TaskQueueFactory *)> _createWrappedAudioDeviceModule;
    FilePath _statsLogPath;

    // core + pump
    TgcallsCallCore *_core = nullptr;
    std::deque<json11::Json> _pendingCommands;
    bool _isProcessingCommands = false;
    bool _isDeliveringEvent = false;

    // signaling
    std::unique_ptr<SignalingConnection> _signalingConnection;
    std::unique_ptr<EncryptedConnection> _signalingEncryptedConnection;

    // webrtc
    std::unique_ptr<webrtc::TaskQueueFactory> _taskQueueFactory;
    std::unique_ptr<rtc::NetworkMonitorFactory> _networkMonitorFactory;
    std::unique_ptr<rtc::BasicPacketSocketFactory> _socketFactory;
    std::unique_ptr<rtc::BasicNetworkManager> _networkManager;
    std::unique_ptr<cricket::RelayPortFactoryInterface> _relayPortFactory;
    webrtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> _peerConnectionFactory;
    std::unique_ptr<webrtc::PeerConnectionObserver> _peerConnectionObserver;
    webrtc::scoped_refptr<webrtc::PeerConnectionInterface> _peerConnection;
    webrtc::scoped_refptr<webrtc::AudioDeviceModule> _audioDeviceModule;

    webrtc::scoped_refptr<webrtc::AudioTrackInterface> _outgoingAudioTrack;
    webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> _outgoingAudioTransceiver;
    webrtc::scoped_refptr<webrtc::VideoTrackInterface> _outgoingVideoTrack;
    webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> _outgoingVideoTransceiver;
    std::map<std::string, webrtc::scoped_refptr<webrtc::RtpTransceiverInterface>> _incomingVideoTransceivers;
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _currentStrongSink;
    std::shared_ptr<VideoCaptureInterface> _videoCapture;

    std::unique_ptr<v2wasm_detail::DataChannelObserverImpl> _dataChannelObserver;
    webrtc::scoped_refptr<webrtc::DataChannelInterface> _dataChannel;
    bool _isDataChannelOpen = false;

    // stop flow
    std::function<void(FinalState)> _stopCompletion;
    std::string _pendingStatsLogJson;
    std::atomic<bool> _isStopped{false};
};

} // namespace tgcalls

#endif
```

- [ ] **Step 2: Write the implementation**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`. The observer helper classes are duplicated from `v2/InstanceV2ReferenceImpl.cpp` (anonymous namespace there); the rest is the command/event plumbing:

```cpp
#include "v2wasm/CallCoreHost.h"

#include <fstream>
#include <sstream>

#include "api/audio_codecs/audio_decoder_factory_template.h"
#include "api/audio_codecs/audio_encoder_factory_template.h"
#include "api/audio_codecs/opus/audio_decoder_opus.h"
#include "api/audio_codecs/opus/audio_encoder_opus.h"
#include "api/task_queue/default_task_queue_factory.h"
#include "api/enable_media.h"
#include "api/jsep_ice_candidate.h"
#include "api/rtc_event_log/rtc_event_log_factory.h"
#include "api/stats/rtc_stats_report.h"
#include "api/stats/rtcstats_objects.h"
#include "p2p/client/basic_port_allocator.h"
#include "rtc_base/network.h"
#include "rtc_base/time_utils.h"
#include "system_wrappers/include/field_trial.h"

#include "AudioDeviceHelper.h"
#include "EncryptedConnection.h"
#include "VideoCaptureInterfaceImpl.h"
#include "platform/PlatformInterface.h"
#include "v2/InstanceNetworking.h"
#include "v2/ReflectorRelayPortFactory.h"
#include "v2/SignalingConnection.h"
#include "v2/ExternalSignalingConnection.h"
#include "v2/SignalingSctpConnection.h"
#include "utils/gzip.h"

#ifdef WEBRTC_IOS
#include "platform/darwin/iOS/tgcalls_audio_device_module_ios.h"
#endif

namespace tgcalls {

namespace v2wasm_detail {

class SetSessionDescriptionObserver : public webrtc::SetLocalDescriptionObserverInterface, public webrtc::SetRemoteDescriptionObserverInterface {
public:
    SetSessionDescriptionObserver(std::function<void(webrtc::RTCError)> &&completion) :
    _completion(std::move(completion)) {
    }

    void OnSetLocalDescriptionComplete(webrtc::RTCError error) override {
        _completion(error);
    }

    void OnSetRemoteDescriptionComplete(webrtc::RTCError error) override {
        _completion(error);
    }

private:
    std::function<void(webrtc::RTCError)> _completion;
};

class StatsCollectorCallbackAdapter : public webrtc::RTCStatsCollectorCallback {
public:
    StatsCollectorCallbackAdapter(std::function<void(const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &)> &&completion_) :
    completion(std::move(completion_)) {
    }

    void OnStatsDelivered(const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &report) override {
        completion(report);
    }

private:
    std::function<void(const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &)> completion;
};

class DataChannelObserverImpl : public webrtc::DataChannelObserver {
public:
    struct Parameters {
        std::function<void()> onStateChange;
        std::function<void(webrtc::DataBuffer const &)> onMessage;
    };

    DataChannelObserverImpl(Parameters &&parameters) :
    _parameters(std::move(parameters)) {
    }

    void OnStateChange() override {
        if (_parameters.onStateChange) {
            _parameters.onStateChange();
        }
    }

    void OnMessage(webrtc::DataBuffer const &buffer) override {
        if (_parameters.onMessage) {
            _parameters.onMessage(buffer);
        }
    }

private:
    Parameters _parameters;
};

class PeerConnectionDelegateAdapter : public webrtc::PeerConnectionObserver {
public:
    PeerConnectionDelegateAdapter(std::weak_ptr<CallCoreHost> host, std::shared_ptr<Threads> threads) :
    _host(host), _threads(threads) {
    }

    void OnSignalingChange(webrtc::PeerConnectionInterface::SignalingState newState) override {
        std::string state;
        switch (newState) {
            case webrtc::PeerConnectionInterface::SignalingState::kStable: state = "stable"; break;
            case webrtc::PeerConnectionInterface::SignalingState::kHaveLocalOffer: state = "have-local-offer"; break;
            case webrtc::PeerConnectionInterface::SignalingState::kHaveLocalPrAnswer: state = "have-local-pranswer"; break;
            case webrtc::PeerConnectionInterface::SignalingState::kHaveRemoteOffer: state = "have-remote-offer"; break;
            case webrtc::PeerConnectionInterface::SignalingState::kHaveRemotePrAnswer: state = "have-remote-pranswer"; break;
            case webrtc::PeerConnectionInterface::SignalingState::kClosed: state = "closed"; break;
            default: state = "stable"; break;
        }
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({ {"@type", "pc_signaling_state"}, {"state", state} });
        }
    }

    void OnRenegotiationNeeded() override {
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({ {"@type", "pc_renegotiation_needed"} });
        }
    }

    void OnIceCandidate(const webrtc::IceCandidateInterface *candidate) override {
        std::string sdp;
        candidate->ToString(&sdp);
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({
                {"@type", "pc_ice_candidate"},
                {"mid", candidate->sdp_mid()},
                {"mline", candidate->sdp_mline_index()},
                {"sdp", sdp},
            });
        }
    }

    void OnIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState newState) override {
        std::string state;
        switch (newState) {
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionNew: state = "new"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionChecking: state = "checking"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionConnected: state = "connected"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionCompleted: state = "completed"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionFailed: state = "failed"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionDisconnected: state = "disconnected"; break;
            case webrtc::PeerConnectionInterface::IceConnectionState::kIceConnectionClosed: state = "closed"; break;
            default: state = "new"; break;
        }
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({ {"@type", "pc_ice_state"}, {"state", state} });
        }
    }

    void OnIceSelectedCandidatePairChanged(const cricket::CandidatePairChangeEvent &event) override {
        const auto local = InstanceNetworking::connectionDescriptionFromCandidate(event.selected_candidate_pair.local);
        const auto remote = InstanceNetworking::connectionDescriptionFromCandidate(event.selected_candidate_pair.remote);
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({
                {"@type", "pc_candidate_pair_changed"},
                {"local", json11::Json::object{ {"type", local.type}, {"protocol", local.protocol}, {"address", local.address} }},
                {"remote", json11::Json::object{ {"type", remote.type}, {"protocol", remote.protocol}, {"address", remote.address} }},
            });
        }
    }

    void OnDataChannel(webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel) override {
        if (const auto strong = _host.lock()) {
            if (!strong->_dataChannel) {
                strong->attachDataChannel(dataChannel);
            }
        }
    }

    void OnTrack(webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver) override {
        const auto strong = _host.lock();
        if (!strong) {
            return;
        }
        if (!transceiver->mid()) {
            return;
        }
        std::string mid = transceiver->mid().value();
        if (transceiver->media_type() == cricket::MediaType::MEDIA_TYPE_VIDEO) {
            if (strong->_incomingVideoTransceivers.find(mid) == strong->_incomingVideoTransceivers.end()) {
                strong->_incomingVideoTransceivers.insert(std::make_pair(mid, transceiver));
                strong->connectIncomingVideoSink(transceiver);
            }
        }
    }

    void OnRemoveTrack(webrtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver) override {
        const auto strong = _host.lock();
        if (!strong) {
            return;
        }
        std::string mid = receiver->track()->id();
        if (mid.empty()) {
            return;
        }
        const auto transceiver = strong->_incomingVideoTransceivers.find(mid);
        if (transceiver != strong->_incomingVideoTransceivers.end()) {
            strong->_incomingVideoTransceivers.erase(transceiver);
        }
    }

    void OnAddStream(webrtc::scoped_refptr<webrtc::MediaStreamInterface>) override {}
    void OnRemoveStream(webrtc::scoped_refptr<webrtc::MediaStreamInterface>) override {}
    void OnIceGatheringChange(webrtc::PeerConnectionInterface::IceGatheringState) override {}
    void OnIceCandidatesRemoved(const std::vector<cricket::Candidate> &) override {}
    void OnStandardizedIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState) override {}
    void OnConnectionChange(webrtc::PeerConnectionInterface::PeerConnectionState) override {}
    void OnAddTrack(webrtc::scoped_refptr<webrtc::RtpReceiverInterface>, const std::vector<webrtc::scoped_refptr<webrtc::MediaStreamInterface>> &) override {}

private:
    std::weak_ptr<CallCoreHost> _host;
    std::shared_ptr<Threads> _threads;
};

} // namespace v2wasm_detail

namespace {

VideoCaptureInterfaceObject *GetVideoCaptureAssumingSameThread(VideoCaptureInterface *videoCapture) {
    return videoCapture
        ? static_cast<VideoCaptureInterfaceImpl *>(videoCapture)->object()->getSyncAssumingSameThread()
        : nullptr;
}

std::string stripPumpSuffix(std::string const &version) {
    const std::string suffix = "-pump";
    if (version.size() > suffix.size() && version.compare(version.size() - suffix.size(), suffix.size(), suffix) == 0) {
        return version.substr(0, version.size() - suffix.size());
    }
    return version;
}

std::string coreStringField(json11::Json const &object, std::string const &key) {
    const auto &value = object[key];
    return value.is_string() ? value.string_value() : std::string();
}

} // namespace

CallCoreHost::CallCoreHost(Descriptor &&descriptor, std::shared_ptr<Threads> threads) :
_threads(threads),
_wireVersion(stripPumpSuffix(descriptor.version)),
_rtcServers(descriptor.rtcServers),
_enableP2P(descriptor.config.enableP2P),
_encryptionKey(std::move(descriptor.encryptionKey)),
_customParameters(descriptor.config.customParameters),
_stateUpdated(descriptor.stateUpdated),
_signalBarsUpdated(descriptor.signalBarsUpdated),
_remoteBatteryLevelIsLowUpdated(descriptor.remoteBatteryLevelIsLowUpdated),
_remoteMediaStateUpdated(descriptor.remoteMediaStateUpdated),
_signalingDataEmitted(descriptor.signalingDataEmitted),
_createAudioDeviceModule(descriptor.createAudioDeviceModule),
_createWrappedAudioDeviceModule(descriptor.createWrappedAudioDeviceModule),
_statsLogPath(descriptor.config.statsLogPath),
_videoCapture(descriptor.videoCapture) {
    _isSignalingV2 = (_wireVersion != "10.0.0");
    webrtc::field_trial::InitFieldTrialsFromString(
        "WebRTC-DataChannel-Dcsctp/Enabled/"
        "WebRTC-Audio-iOS-Holding/Enabled/"
    );
}

CallCoreHost::~CallCoreHost() {
    _currentStrongSink.reset();
    _threads->getWorkerThread()->BlockingCall([&]() {
        _audioDeviceModule = nullptr;
    });
    if (_dataChannel) {
        _dataChannel->UnregisterObserver();
        _dataChannel = nullptr;
    }
    _dataChannelObserver.reset();
    _peerConnection = nullptr;
    _peerConnectionObserver.reset();
    _peerConnectionFactory = nullptr;
    if (_core) {
        tgcalls_core_destroy(_core);
        _core = nullptr;
    }
}

void CallCoreHost::start() {
    RTC_DCHECK(_threads->getMediaThread()->IsCurrent());
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());

    PlatformInterface::SharedInstance()->configurePlatformAudio();

    if (_isSignalingV2) {
        _signalingConnection = std::make_unique<SignalingSctpConnection>(
            _threads,
            [threads = _threads, weak](const std::vector<uint8_t> &data) {
                threads->getMediaThread()->PostTask([weak, data] {
                    const auto strong = weak.lock();
                    if (!strong) {
                        return;
                    }
                    strong->onSignalingData(data);
                });
            },
            [signalingDataEmitted = _signalingDataEmitted](const std::vector<uint8_t> &data) {
                signalingDataEmitted(data);
            },
            _encryptionKey.isOutgoing
        );
    } else {
        _signalingConnection = std::make_unique<ExternalSignalingConnection>(
            [threads = _threads, weak](const std::vector<uint8_t> &data) {
                threads->getMediaThread()->PostTask([weak, data] {
                    const auto strong = weak.lock();
                    if (!strong) {
                        return;
                    }
                    strong->onSignalingData(data);
                });
            },
            [signalingDataEmitted = _signalingDataEmitted](const std::vector<uint8_t> &data) {
                signalingDataEmitted(data);
            }
        );
    }
    _signalingConnection->start();

    _taskQueueFactory = webrtc::CreateDefaultTaskQueueFactory();
    _threads->getWorkerThread()->BlockingCall([&]() {
        _audioDeviceModule = createAudioDeviceModule();
    });

    webrtc::PeerConnectionFactoryDependencies peerConnectionFactoryDependencies;
    peerConnectionFactoryDependencies.network_thread = _threads->getNetworkThread();
    peerConnectionFactoryDependencies.signaling_thread = _threads->getMediaThread();
    peerConnectionFactoryDependencies.worker_thread = _threads->getWorkerThread();
    peerConnectionFactoryDependencies.task_queue_factory = webrtc::CreateDefaultTaskQueueFactory();
    peerConnectionFactoryDependencies.network_monitor_factory = PlatformInterface::SharedInstance()->createNetworkMonitorFactory();
    peerConnectionFactoryDependencies.adm = _audioDeviceModule;

    webrtc::AudioProcessingBuilder builder;
    peerConnectionFactoryDependencies.audio_processing = builder.Create();
    peerConnectionFactoryDependencies.audio_encoder_factory = webrtc::CreateAudioEncoderFactory<webrtc::AudioEncoderOpus>();
    peerConnectionFactoryDependencies.audio_decoder_factory = webrtc::CreateAudioDecoderFactory<webrtc::AudioDecoderOpus>();
    peerConnectionFactoryDependencies.video_encoder_factory = PlatformInterface::SharedInstance()->makeVideoEncoderFactory(true);
    peerConnectionFactoryDependencies.video_decoder_factory = PlatformInterface::SharedInstance()->makeVideoDecoderFactory();
    webrtc::EnableMedia(peerConnectionFactoryDependencies);
    peerConnectionFactoryDependencies.event_log_factory = std::make_unique<webrtc::RtcEventLogFactory>(peerConnectionFactoryDependencies.task_queue_factory.get());

    _peerConnectionFactory = webrtc::CreateModularPeerConnectionFactory(std::move(peerConnectionFactoryDependencies));

    _signalingEncryptedConnection = std::make_unique<EncryptedConnection>(
        EncryptedConnection::Type::Signaling,
        _encryptionKey,
        [weak, threads = _threads](int delayMs, int cause) {
            if (delayMs == 0) {
                threads->getMediaThread()->PostTask([weak, cause]() {
                    const auto strong = weak.lock();
                    if (!strong) {
                        return;
                    }
                    strong->sendPendingSignalingServiceData(cause);
                });
            } else {
                threads->getMediaThread()->PostDelayedTask([weak, cause]() {
                    const auto strong = weak.lock();
                    if (!strong) {
                        return;
                    }
                    strong->sendPendingSignalingServiceData(cause);
                }, webrtc::TimeDelta::Millis(delayMs));
            }
        }
    );

    // Build the core config and create the core. The core emits its initial
    // command burst synchronously; drain it after create returns.
    json11::Json::array rtcServers;
    for (const auto &server : _rtcServers) {
        rtcServers.push_back(json11::Json::object{
            {"host", server.host},
            {"port", (int)server.port},
            {"login", server.login},
            {"password", server.password},
            {"isTurn", server.isTurn},
            {"isTcp", server.isTcp},
        });
    }
    const std::string configJson = json11::Json(json11::Json::object{
        {"abiVersion", 1},
        {"wireVersion", _wireVersion},
        {"isOutgoing", _encryptionKey.isOutgoing},
        {"enableP2P", _enableP2P},
        {"customParameters", _customParameters},
        {"rtcServers", std::move(rtcServers)},
    }).dump();

    _core = tgcalls_core_create(configJson.c_str(), &CallCoreHost::coreEmitTrampoline, this);
    processPendingCommands();
}

void CallCoreHost::coreEmitTrampoline(void *userData, const uint8_t *data, size_t len) {
    auto host = static_cast<CallCoreHost *>(userData);
    std::string parsingError;
    auto command = json11::Json::parse(std::string((const char *)data, len), parsingError);
    if (!command.is_object()) {
        RTC_LOG(LS_ERROR) << "CallCoreHost: core emitted non-object command";
        return;
    }
    host->_pendingCommands.push_back(std::move(command));
}

void CallCoreHost::deliverEvent(json11::Json::object &&event) {
    if (_isDeliveringEvent || _isProcessingCommands) {
        // Never re-enter the core: defer to a fresh media-thread task.
        const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
        _threads->getMediaThread()->PostTask([weak, event = std::move(event)]() mutable {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->deliverEventNow(std::move(event));
        });
        return;
    }
    deliverEventNow(std::move(event));
}

void CallCoreHost::deliverEventNow(json11::Json::object &&event) {
    if (!_core || _isStopped.load()) {
        return;
    }
    event.insert(std::make_pair("nowMs", json11::Json((double)rtc::TimeMillis())));
    const std::string serialized = json11::Json(std::move(event)).dump();

    _isDeliveringEvent = true;
    tgcalls_core_on_event(_core, (const uint8_t *)serialized.data(), serialized.size());
    _isDeliveringEvent = false;

    processPendingCommands();
}

void CallCoreHost::processPendingCommands() {
    if (_isProcessingCommands) {
        return;
    }
    _isProcessingCommands = true;
    while (!_pendingCommands.empty()) {
        const auto command = std::move(_pendingCommands.front());
        _pendingCommands.pop_front();
        executeCommand(command);
    }
    _isProcessingCommands = false;
}

void CallCoreHost::executeCommand(json11::Json const &command) {
    const auto type = coreStringField(command, "@type");

    if (type == "core_ready") {
        if ((int)command["abiVersion"].number_value() != 1) {
            RTC_LOG(LS_ERROR) << "CallCoreHost: core ABI version mismatch";
        }
    } else if (type == "pc_create") {
        executePcCreate(command);
    } else if (type == "pc_set_local_description") {
        executeSetLocalDescription();
    } else if (type == "pc_set_remote_description") {
        executeSetRemoteDescription(command);
    } else if (type == "pc_add_ice_candidate") {
        executeAddIceCandidate(command);
    } else if (type == "pc_add_audio_track") {
        executeAddAudioTrack(command);
    } else if (type == "pc_add_video_track") {
        executeAddVideoTrack(command);
    } else if (type == "pc_remove_video_track") {
        executeRemoveVideoTrack();
    } else if (type == "pc_set_audio_track_enabled") {
        if (_outgoingAudioTrack) {
            _outgoingAudioTrack->set_enabled(command["enabled"].bool_value());
        }
    } else if (type == "pc_create_data_channel") {
        executeCreateDataChannel();
    } else if (type == "dc_send") {
        const auto data = coreStringField(command, "data");
        RTC_LOG(LS_INFO) << "CallCoreHost dc_send: " << data;
        if (_dataChannel) {
            _dataChannel->Send(webrtc::DataBuffer(data));
        }
    } else if (type == "signaling_send") {
        executeSignalingSend(command);
    } else if (type == "set_timer") {
        const int token = (int)command["token"].number_value();
        const int delayMs = (int)command["delayMs"].number_value();
        const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
        _threads->getMediaThread()->PostDelayedTask([weak, token]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->deliverEvent({ {"@type", "timer"}, {"token", token} });
        }, webrtc::TimeDelta::Millis(delayMs));
    } else if (type == "request_stats") {
        executeRequestStats();
    } else if (type == "emit_state") {
        const auto state = coreStringField(command, "state");
        State mappedState = State::Reconnecting;
        if (state == "established") {
            mappedState = State::Established;
        } else if (state == "failed") {
            mappedState = State::Failed;
        }
        if (_stateUpdated) {
            _stateUpdated(mappedState);
        }
    } else if (type == "emit_signal_bars") {
        if (_signalBarsUpdated) {
            _signalBarsUpdated((int)command["bars"].number_value());
        }
    } else if (type == "emit_remote_media_state") {
        if (_remoteMediaStateUpdated) {
            const auto audio = coreStringField(command, "audio") == "muted" ? AudioState::Muted : AudioState::Active;
            const auto videoValue = coreStringField(command, "video");
            VideoState video = VideoState::Inactive;
            if (videoValue == "paused") {
                video = VideoState::Paused;
            } else if (videoValue == "active") {
                video = VideoState::Active;
            }
            _remoteMediaStateUpdated(audio, video);
        }
    } else if (type == "emit_remote_battery_low") {
        if (_remoteBatteryLevelIsLowUpdated) {
            _remoteBatteryLevelIsLowUpdated(command["low"].bool_value());
        }
    } else if (type == "log") {
        RTC_LOG(LS_INFO) << "[core] " << coreStringField(command, "message");
    } else if (type == "stats_log") {
        _pendingStatsLogJson = coreStringField(command, "json");
    } else if (type == "close") {
        executeClose();
    } else {
        emitErrorEvent("unknown command", type);
    }
}

void CallCoreHost::emitErrorEvent(std::string const &message, std::string const &commandType) {
    RTC_LOG(LS_ERROR) << "CallCoreHost error: " << message << " (command: " << commandType << ")";
    deliverEvent({ {"@type", "error"}, {"message", message}, {"command", commandType} });
}

void CallCoreHost::executePcCreate(json11::Json const &command) {
    if (_peerConnection) {
        emitErrorEvent("peer connection already exists", "pc_create");
        return;
    }

    _networkMonitorFactory = PlatformInterface::SharedInstance()->createNetworkMonitorFactory();
    _socketFactory = std::make_unique<rtc::BasicPacketSocketFactory>(_threads->getNetworkThread()->socketserver());
    _networkManager = std::make_unique<rtc::BasicNetworkManager>(_networkMonitorFactory.get(), _threads->getNetworkThread()->socketserver());
    _relayPortFactory = std::make_unique<ReflectorRelayPortFactory>(_rtcServers, false, 0, _threads->getNetworkThread()->socketserver());

    webrtc::PeerConnectionDependencies peerConnectionDependencies(nullptr);
    _peerConnectionObserver = std::make_unique<v2wasm_detail::PeerConnectionDelegateAdapter>(std::weak_ptr<CallCoreHost>(shared_from_this()), _threads);
    peerConnectionDependencies.observer = _peerConnectionObserver.get();

    auto portAllocator = std::make_unique<cricket::BasicPortAllocator>(_networkManager.get(), _socketFactory.get(), nullptr, _relayPortFactory.get());
    peerConnectionDependencies.allocator = std::move(portAllocator);

    webrtc::PeerConnectionInterface::RTCConfiguration peerConnectionConfiguration;
    if (coreStringField(command, "iceTransportsType") == "all") {
        peerConnectionConfiguration.type = webrtc::PeerConnectionInterface::IceTransportsType::kAll;
    } else {
        peerConnectionConfiguration.type = webrtc::PeerConnectionInterface::IceTransportsType::kRelay;
    }
    peerConnectionConfiguration.tcp_candidate_policy = webrtc::PeerConnectionInterface::TcpCandidatePolicy::kTcpCandidatePolicyDisabled;
    peerConnectionConfiguration.enable_ice_renomination = true;
    peerConnectionConfiguration.sdp_semantics = webrtc::SdpSemantics::kUnifiedPlan;
    peerConnectionConfiguration.bundle_policy = webrtc::PeerConnectionInterface::kBundlePolicyMaxBundle;
    peerConnectionConfiguration.rtcp_mux_policy = webrtc::PeerConnectionInterface::RtcpMuxPolicy::kRtcpMuxPolicyRequire;
    peerConnectionConfiguration.enable_implicit_rollback = true;
    peerConnectionConfiguration.continual_gathering_policy = webrtc::PeerConnectionInterface::ContinualGatheringPolicy::GATHER_CONTINUALLY;
    peerConnectionConfiguration.audio_jitter_buffer_fast_accelerate = true;
    peerConnectionConfiguration.prioritize_most_likely_ice_candidate_pairs = true;

    for (const auto &server : command["iceServers"].array_items()) {
        webrtc::PeerConnectionInterface::IceServer mappedServer;
        for (const auto &url : server["urls"].array_items()) {
            mappedServer.urls.push_back(url.string_value());
        }
        mappedServer.username = coreStringField(server, "username");
        mappedServer.password = coreStringField(server, "password");
        peerConnectionConfiguration.servers.push_back(mappedServer);
    }

    auto peerConnectionOrError = _peerConnectionFactory->CreatePeerConnectionOrError(peerConnectionConfiguration, std::move(peerConnectionDependencies));
    if (peerConnectionOrError.ok()) {
        _peerConnection = peerConnectionOrError.value();
    } else {
        emitErrorEvent("CreatePeerConnectionOrError failed", "pc_create");
    }
}

void CallCoreHost::executeSetLocalDescription() {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_set_local_description");
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<webrtc::SetLocalDescriptionObserverInterface> observer(new rtc::RefCountedObject<v2wasm_detail::SetSessionDescriptionObserver>([weak, threads = _threads](webrtc::RTCError error) {
        threads->getMediaThread()->PostTask([weak, ok = error.ok()]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            std::string type;
            std::string sdp;
            if (ok && strong->_peerConnection && strong->_peerConnection->local_description()) {
                strong->_peerConnection->local_description()->ToString(&sdp);
                type = strong->_peerConnection->local_description()->type();
            }
            strong->deliverEvent({ {"@type", "pc_set_local_done"}, {"ok", ok && !sdp.empty()}, {"type", type}, {"sdp", sdp} });
        });
    }));
    RTC_LOG(LS_INFO) << "CallCoreHost: SetLocalDescription";
    _peerConnection->SetLocalDescription(observer);
}

void CallCoreHost::executeSetRemoteDescription(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_set_remote_description");
        return;
    }
    const auto sdpType = coreStringField(command, "sdpType");
    webrtc::SdpParseError sdpParseError;
    std::unique_ptr<webrtc::SessionDescriptionInterface> remoteDescription(webrtc::CreateSessionDescription(sdpType, coreStringField(command, "sdp"), &sdpParseError));
    if (!remoteDescription) {
        emitErrorEvent("failed to parse remote SDP", "pc_set_remote_description");
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<webrtc::SetRemoteDescriptionObserverInterface> observer(new rtc::RefCountedObject<v2wasm_detail::SetSessionDescriptionObserver>([weak, threads = _threads, sdpType](webrtc::RTCError error) {
        threads->getMediaThread()->PostTask([weak, ok = error.ok(), sdpType]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->deliverEvent({ {"@type", "pc_set_remote_done"}, {"ok", ok}, {"sdpType", sdpType} });
        });
    }));
    RTC_LOG(LS_INFO) << "CallCoreHost: SetRemoteDescription";
    _peerConnection->SetRemoteDescription(std::move(remoteDescription), observer);
}

void CallCoreHost::executeAddIceCandidate(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_add_ice_candidate");
        return;
    }
    webrtc::SdpParseError parseError;
    webrtc::IceCandidateInterface *iceCandidate = webrtc::CreateIceCandidate(coreStringField(command, "mid"), (int)command["mline"].number_value(), coreStringField(command, "sdp"), &parseError);
    if (iceCandidate) {
        std::unique_ptr<webrtc::IceCandidateInterface> candidatePtr;
        candidatePtr.reset(iceCandidate);
        _peerConnection->AddIceCandidate(candidatePtr.get());
    } else {
        emitErrorEvent("failed to parse ICE candidate", "pc_add_ice_candidate");
    }
}

void CallCoreHost::executeAddAudioTrack(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_add_audio_track");
        return;
    }
    webrtc::RtpTransceiverInit transceiverInit;
    transceiverInit.stream_ids = { "0" };

    cricket::AudioOptions audioSourceOptions;
    webrtc::scoped_refptr<webrtc::AudioSourceInterface> audioSource = _peerConnectionFactory->CreateAudioSource(audioSourceOptions);
    webrtc::scoped_refptr<webrtc::AudioTrackInterface> audioTrack = _peerConnectionFactory->CreateAudioTrack("0", audioSource.get());
    auto audioTransceiverOrError = _peerConnection->AddTransceiver(audioTrack, transceiverInit);
    if (audioTransceiverOrError.ok()) {
        _outgoingAudioTrack = audioTrack;
        _outgoingAudioTransceiver = audioTransceiverOrError.value();

        webrtc::RtpParameters parameters = _outgoingAudioTransceiver->sender()->GetParameters();
        if (parameters.encodings.empty()) {
            parameters.encodings.push_back(webrtc::RtpEncodingParameters());
        }
        parameters.encodings[0].max_bitrate_bps = (int)command["maxBitrateBps"].number_value();
        _outgoingAudioTransceiver->sender()->SetParameters(parameters);

        _outgoingAudioTrack->set_enabled(true);
    } else {
        emitErrorEvent("AddTransceiver(audio) failed", "pc_add_audio_track");
    }
}

void CallCoreHost::executeAddVideoTrack(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_add_video_track");
        return;
    }
    auto videoCaptureImpl = GetVideoCaptureAssumingSameThread(_videoCapture.get());
    if (!videoCaptureImpl || videoCaptureImpl->isScreenCapture()) {
        emitErrorEvent("no usable video capture", "pc_add_video_track");
        return;
    }

    auto videoTrack = _peerConnectionFactory->CreateVideoTrack(videoCaptureImpl->source(), "1");
    if (!videoTrack) {
        emitErrorEvent("CreateVideoTrack failed", "pc_add_video_track");
        return;
    }
    webrtc::RtpTransceiverInit transceiverInit;
    transceiverInit.stream_ids = { "0" };
    auto videoTransceiverOrError = _peerConnection->AddTransceiver(videoTrack, transceiverInit);
    if (!videoTransceiverOrError.ok()) {
        emitErrorEvent("AddTransceiver(video) failed", "pc_add_video_track");
        return;
    }
    _outgoingVideoTrack = videoTrack;
    _outgoingVideoTransceiver = videoTransceiverOrError.value();

    auto currentCapabilities = _peerConnectionFactory->GetRtpSenderCapabilities(cricket::MediaType::MEDIA_TYPE_VIDEO);
    std::vector<std::string> codecPreferences;
    for (const auto &name : command["codecPreferences"].array_items()) {
        codecPreferences.push_back(name.string_value());
    }
    for (const auto &codecCapability : currentCapabilities.codecs) {
        if (std::find_if(codecPreferences.begin(), codecPreferences.end(), [&](std::string const &value) {
            return value == codecCapability.name;
        }) != codecPreferences.end()) {
            continue;
        }
        codecPreferences.push_back(codecCapability.name);
    }
    std::vector<webrtc::RtpCodecCapability> codecCapabilities;
    for (const auto &name : codecPreferences) {
        for (const auto &codecCapability : currentCapabilities.codecs) {
            if (codecCapability.name == name) {
                codecCapabilities.push_back(codecCapability);
                break;
            }
        }
    }
    _outgoingVideoTransceiver->SetCodecPreferences(codecCapabilities);

    webrtc::RtpParameters parameters = _outgoingVideoTransceiver->sender()->GetParameters();
    if (parameters.encodings.empty()) {
        parameters.encodings.push_back(webrtc::RtpEncodingParameters());
    }
    parameters.encodings[0].max_bitrate_bps = (int)command["maxBitrateBps"].number_value();
    _outgoingVideoTransceiver->sender()->SetParameters(parameters);

    _outgoingVideoTrack->set_enabled(true);
}

void CallCoreHost::executeRemoveVideoTrack() {
    if (_outgoingVideoTransceiver && _peerConnection) {
        _peerConnection->RemoveTrackOrError(_outgoingVideoTransceiver->sender());
    }
    _outgoingVideoTrack = nullptr;
    _outgoingVideoTransceiver = nullptr;
}

void CallCoreHost::executeCreateDataChannel() {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_create_data_channel");
        return;
    }
    webrtc::DataChannelInit dataChannelInit;
    auto dataChannelOrError = _peerConnection->CreateDataChannelOrError("data", &dataChannelInit);
    if (dataChannelOrError.ok()) {
        attachDataChannel(dataChannelOrError.value());
    } else {
        emitErrorEvent("CreateDataChannelOrError failed", "pc_create_data_channel");
    }
}

void CallCoreHost::attachDataChannel(webrtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel) {
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());

    v2wasm_detail::DataChannelObserverImpl::Parameters dataChannelObserverParams;
    dataChannelObserverParams.onStateChange = [threads = _threads, weak]() {
        threads->getMediaThread()->PostTask([weak]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->onDataChannelStateUpdated();
        });
    };
    dataChannelObserverParams.onMessage = [threads = _threads, weak](webrtc::DataBuffer const &buffer) {
        const auto strong = weak.lock();
        if (!strong) {
            return;
        }
        if (!buffer.binary) {
            std::string message(buffer.data.data(), buffer.data.data() + buffer.data.size());
            strong->deliverEvent({ {"@type", "dc_message"}, {"data", message} });
        } else {
            RTC_LOG(LS_INFO) << "CallCoreHost: rejecting binary dc message";
        }
    };
    _dataChannelObserver = std::make_unique<v2wasm_detail::DataChannelObserverImpl>(std::move(dataChannelObserverParams));
    _dataChannel = dataChannel;
    onDataChannelStateUpdated();
    _dataChannel->RegisterObserver(_dataChannelObserver.get());
}

void CallCoreHost::onDataChannelStateUpdated() {
    if (!_dataChannel) {
        return;
    }
    const bool open = (_dataChannel->state() == webrtc::DataChannelInterface::DataState::kOpen);
    if (open != _isDataChannelOpen) {
        _isDataChannelOpen = open;
        deliverEvent({ {"@type", "dc_state"}, {"open", open} });
    }
}

void CallCoreHost::executeSignalingSend(json11::Json const &command) {
    const auto dataString = coreStringField(command, "data");
    RTC_LOG(LS_INFO) << "CallCoreHost signaling_send: " << dataString;
    std::vector<uint8_t> data(dataString.begin(), dataString.end());

    if (!_signalingConnection || !_signalingEncryptedConnection) {
        emitErrorEvent("signaling not available", "signaling_send");
        return;
    }

    if (!_isSignalingV2) {
        rtc::CopyOnWriteBuffer message;
        message.AppendData(data.data(), data.size());
        const auto packet = _signalingEncryptedConnection->prepareForSendingRawMessage(message, true);
        if (packet) {
            _signalingConnection->send(packet.value().bytes);
        }
        return;
    }

    std::vector<uint8_t> packetData;
    if (const auto compressedData = gzipData(data)) {
        packetData = std::move(compressedData.value());
    } else {
        RTC_LOG(LS_ERROR) << "CallCoreHost: could not gzip signaling message";
        return;
    }
    if (const auto message = _signalingEncryptedConnection->encryptRawPacket(rtc::CopyOnWriteBuffer(packetData.data(), packetData.size()))) {
        _signalingConnection->send(std::vector<uint8_t>(message.value().data(), message.value().data() + message.value().size()));
    } else {
        RTC_LOG(LS_ERROR) << "CallCoreHost: could not encrypt signaling message";
    }
}

void CallCoreHost::sendPendingSignalingServiceData(int cause) {
    if (!_signalingConnection || !_signalingEncryptedConnection) {
        return;
    }
    const auto packet = _signalingEncryptedConnection->prepareForSendingService(cause);
    if (packet) {
        _signalingConnection->send(packet.value().bytes);
    }
}

void CallCoreHost::receiveSignalingData(const std::vector<uint8_t> &data) {
    if (_signalingConnection) {
        _signalingConnection->receiveExternal(data);
    }
}

void CallCoreHost::onSignalingData(const std::vector<uint8_t> &data) {
    if (!_signalingEncryptedConnection) {
        RTC_LOG(LS_ERROR) << "CallCoreHost: receiveSignalingData encryption not available";
        return;
    }
    if (!_isSignalingV2) {
        if (const auto packet = _signalingEncryptedConnection->handleIncomingRawPacket((const char *)data.data(), data.size())) {
            processIncomingSignalingMessage(std::vector<uint8_t>(packet.value().main.message.data(), packet.value().main.message.data() + packet.value().main.message.size()));
            for (const auto &additional : packet.value().additional) {
                processIncomingSignalingMessage(std::vector<uint8_t>(additional.message.data(), additional.message.data() + additional.message.size()));
            }
        }
        return;
    }
    if (const auto message = _signalingEncryptedConnection->decryptRawPacket(rtc::CopyOnWriteBuffer(data.data(), data.size()))) {
        processIncomingSignalingMessage(std::vector<uint8_t>(message.value().data(), message.value().data() + message.value().size()));
    } else {
        RTC_LOG(LS_ERROR) << "CallCoreHost: could not decrypt signaling data";
    }
}

void CallCoreHost::processIncomingSignalingMessage(std::vector<uint8_t> const &decrypted) {
    std::vector<uint8_t> plain = decrypted;
    if (isGzip(plain)) {
        if (const auto decompressed = gunzipData(plain, 2 * 1024 * 1024)) {
            plain = decompressed.value();
        } else {
            RTC_LOG(LS_ERROR) << "CallCoreHost: could not decompress signaling data";
            return;
        }
    }
    RTC_LOG(LS_INFO) << "CallCoreHost signaling in: " << std::string(plain.begin(), plain.end());
    deliverEvent({ {"@type", "signaling_message"}, {"data", std::string(plain.begin(), plain.end())} });
}

void CallCoreHost::executeRequestStats() {
    if (!_peerConnection) {
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<v2wasm_detail::StatsCollectorCallbackAdapter> callback(new rtc::RefCountedObject<v2wasm_detail::StatsCollectorCallbackAdapter>([weak, threads = _threads](const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &report) {
        double maxOutgoingBitrateBps = 0.0;
        if (report) {
            for (const auto *pairStats : report->GetStatsOfType<webrtc::RTCIceCandidatePairStats>()) {
                if (pairStats->available_outgoing_bitrate.has_value()) {
                    maxOutgoingBitrateBps = std::max(maxOutgoingBitrateBps, *pairStats->available_outgoing_bitrate);
                }
            }
        }
        threads->getMediaThread()->PostTask([weak, maxOutgoingBitrateBps]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->deliverEvent({ {"@type", "stats"}, {"sendBitrateKbps", maxOutgoingBitrateBps / 1024.0} });
        });
    }));
    _peerConnection->GetStats(callback.get());
}

void CallCoreHost::executeClose() {
    if (_peerConnection) {
        _peerConnection->Close();
    }
    if (!_pendingStatsLogJson.empty() && !_statsLogPath.data.empty()) {
        std::ofstream file;
        file.open(_statsLogPath.data);
        file << _pendingStatsLogJson;
        file.close();
    }
    if (_stopCompletion) {
        FinalState finalState;
        auto completion = std::move(_stopCompletion);
        _stopCompletion = nullptr;
        completion(finalState);
    }
}

void CallCoreHost::setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture) {
    _videoCapture = videoCapture;
    bool screencast = false;
    if (const auto captureImpl = GetVideoCaptureAssumingSameThread(videoCapture.get())) {
        screencast = captureImpl->isScreenCapture();
    }
    deliverEvent({ {"@type", "video_capture"}, {"active", videoCapture != nullptr}, {"screencast", screencast} });
}

void CallCoreHost::setMuteMicrophone(bool mute) {
    deliverEvent({ {"@type", "mute"}, {"muted", mute} });
}

void CallCoreHost::setIsLowBatteryLevel(bool low) {
    deliverEvent({ {"@type", "battery_low"}, {"low", low} });
}

void CallCoreHost::setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentStrongSink = sink.lock();
    if (_currentStrongSink && !_incomingVideoTransceivers.empty()) {
        connectIncomingVideoSink(_incomingVideoTransceivers.begin()->second);
    }
}

void CallCoreHost::connectIncomingVideoSink(webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver) {
    if (_currentStrongSink) {
        webrtc::VideoTrackInterface *videoTrack = (webrtc::VideoTrackInterface *)transceiver->receiver()->track().get();
        videoTrack->AddOrUpdateSink(_currentStrongSink.get(), rtc::VideoSinkWants());
    }
}

void CallCoreHost::setAudioInputDevice(std::string id) {
    SetAudioInputDeviceById(_audioDeviceModule.get(), id);
}

void CallCoreHost::setAudioOutputDevice(std::string id) {
    SetAudioOutputDeviceById(_audioDeviceModule.get(), id);
}

void CallCoreHost::stop(std::function<void(FinalState)> completion) {
    _stopCompletion = std::move(completion);
    deliverEventNow({ {"@type", "stop"} });
    _isStopped = true;
}

webrtc::scoped_refptr<webrtc::AudioDeviceModule> CallCoreHost::createAudioDeviceModule() {
    const auto create = [&](webrtc::AudioDeviceModule::AudioLayer layer) {
#ifdef WEBRTC_IOS
        return rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, false, false, 1);
#else
        return webrtc::AudioDeviceModule::Create(layer, _taskQueueFactory.get());
#endif
    };
    const auto check = [&](const webrtc::scoped_refptr<webrtc::AudioDeviceModule> &result) {
        return (result && result->Init() == 0) ? result : nullptr;
    };
    if (_createWrappedAudioDeviceModule) {
        auto result = _createWrappedAudioDeviceModule(_taskQueueFactory.get());
        if (result) {
            return result;
        }
    }
    if (_createAudioDeviceModule) {
        if (const auto result = check(_createAudioDeviceModule(_taskQueueFactory.get()))) {
            return result;
        }
    }
    return check(create(webrtc::AudioDeviceModule::kPlatformDefaultAudio));
}

} // namespace tgcalls
```

Note on `stop()`: `deliverEventNow` is used so the stop event reaches the core (and its `stats_log` + `close` replies are queued) before `_isStopped` blocks further event delivery; the queued commands still execute after.

- [ ] **Step 3: Check `InstanceNetworking.h` exists with `connectionDescriptionFromCandidate`**

```bash
grep -n "connectionDescriptionFromCandidate" submodules/TgVoipWebrtc/tgcalls/tgcalls/v2/InstanceNetworking.h
```

Expected: a static/free declaration. If the header has a different name (stock cpp includes it transitively), locate it with `grep -rn "connectionDescriptionFromCandidate" submodules/TgVoipWebrtc/tgcalls/tgcalls/v2/*.h` and fix the include in `CallCoreHost.cpp`.

- [ ] **Step 4: Add to BUILD (parent repo)** — same two spots as Task 2, add:

```python
    "tgcalls/tgcalls/v2wasm/CallCoreHost.cpp",
```

- [ ] **Step 5: Bazel compile check**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc:tgcalls_core 2>&1 | tail -5
```

Expected: `Build completed successfully`. Iterate on compile errors here — WebRTC API drift (e.g. `scoped_refptr` vs `rtc::scoped_refptr`, `AudioProcessingBuilder` location) is resolved by matching whatever `v2/InstanceV2ReferenceImpl.cpp` does, since it compiles against the same tree.

- [ ] **Step 6: Commit (both repos)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp && \
git commit -m "feat(v2wasm): CallCoreHost — fixed harness executing core commands

Owns PeerConnection, ADM, EncryptedConnection, SCTP/external signaling,
gzip, timers, GetStats (standard async API instead of stock's call_ptr()
proxy reach-in), incoming-video sink wiring. Queued-command pump: core is
never re-entered; async results return as events.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): compile v2wasm/CallCoreHost.cpp into tgcalls targets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `InstanceV2PumpImpl` + registration + full build

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (add `InstanceV2PumpImpl.cpp`, same two spots)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tools/cli/main.cpp` (include + `Register<>`)

**Interfaces:**
- Consumes: `CallCoreHost` public API from Task 3 (exact signatures listed there).
- Produces: `tgcalls::InstanceV2PumpImpl` (final `Instance`), `GetVersions() = {"10.0.0-pump", "11.0.0-pump"}`, `GetConnectionMaxLayer() = 92`, `template <> bool tgcalls::Register<InstanceV2PumpImpl>()`.

- [ ] **Step 1: Write the header**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.h`:

```cpp
#ifndef TGCALLS_V2WASM_INSTANCE_V2_PUMP_IMPL_H
#define TGCALLS_V2WASM_INSTANCE_V2_PUMP_IMPL_H

#include <cstdint>
#include "Instance.h"
#include "StaticThreads.h"

namespace tgcalls {

class LogSinkImpl;
class CallCoreHost;
template <typename T>
class ThreadLocalObject;

// Pump-based reference implementation: control logic behind the v2wasm C ABI
// (ReferenceCallCore), platform work in CallCoreHost. Wire-compatible with
// InstanceV2ReferenceImpl versions 10.0.0 / 11.0.0.
class InstanceV2PumpImpl final : public Instance {
public:
    explicit InstanceV2PumpImpl(Descriptor &&descriptor);
    ~InstanceV2PumpImpl() override;

    void receiveSignalingData(const std::vector<uint8_t> &data) override;
    void setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture) override;
    void setRequestedVideoAspect(float aspect) override;
    void setNetworkType(NetworkType networkType) override;
    void setMuteMicrophone(bool muteMicrophone) override;
    bool supportsVideo() override {
        return true;
    }
    void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override;
    void setAudioOutputGainControlEnabled(bool enabled) override;
    void setEchoCancellationStrength(int strength) override;
    void setAudioInputDevice(std::string id) override;
    void setAudioOutputDevice(std::string id) override;
    void setInputVolume(float level) override;
    void setOutputVolume(float level) override;
    void setAudioOutputDuckingEnabled(bool enabled) override;
    void setIsLowBatteryLevel(bool isLowBatteryLevel) override;
    static std::vector<std::string> GetVersions();
    static int GetConnectionMaxLayer();
    std::string getLastError() override;
    std::string getDebugInfo() override;
    int64_t getPreferredRelayId() override;
    TrafficStats getTrafficStats() override;
    PersistentState getPersistentState() override;
    void stop(std::function<void(FinalState)> completion) override;
    void sendVideoDeviceUpdated() override {
    }

private:
    std::shared_ptr<Threads> _threads;
    std::unique_ptr<ThreadLocalObject<CallCoreHost>> _internal;
    std::unique_ptr<LogSinkImpl> _logSink;
};

} // namespace tgcalls

#endif
```

- [ ] **Step 2: Write the implementation**

Create `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp`:

```cpp
#include "v2wasm/InstanceV2PumpImpl.h"

#include "LogSinkImpl.h"
#include "ThreadLocalObject.h"
#include "v2wasm/CallCoreHost.h"

namespace tgcalls {

InstanceV2PumpImpl::InstanceV2PumpImpl(Descriptor &&descriptor) {
    if (descriptor.config.logPath.data.size() != 0) {
        _logSink = std::make_unique<LogSinkImpl>(descriptor.config.logPath);
    }
    rtc::LogMessage::LogToDebug(rtc::LS_INFO);
    rtc::LogMessage::SetLogToStderr(false);
    if (_logSink) {
        rtc::LogMessage::AddLogToStream(_logSink.get(), rtc::LS_INFO);
    }

    _threads = StaticThreads::getThreads();
    _internal.reset(new ThreadLocalObject<CallCoreHost>(_threads->getMediaThread(), [descriptor = std::move(descriptor), threads = _threads]() mutable {
        return std::make_shared<CallCoreHost>(std::move(descriptor), threads);
    }));
    _internal->perform([](CallCoreHost *internal) {
        internal->start();
    });
}

InstanceV2PumpImpl::~InstanceV2PumpImpl() {
    rtc::LogMessage::RemoveLogToStream(_logSink.get());
}

void InstanceV2PumpImpl::receiveSignalingData(const std::vector<uint8_t> &data) {
    _internal->perform([data](CallCoreHost *internal) {
        internal->receiveSignalingData(data);
    });
}

void InstanceV2PumpImpl::setVideoCapture(std::shared_ptr<VideoCaptureInterface> videoCapture) {
    _internal->perform([videoCapture](CallCoreHost *internal) {
        internal->setVideoCapture(videoCapture);
    });
}

void InstanceV2PumpImpl::setRequestedVideoAspect(float aspect) {
}

void InstanceV2PumpImpl::setNetworkType(NetworkType networkType) {
}

void InstanceV2PumpImpl::setMuteMicrophone(bool muteMicrophone) {
    _internal->perform([muteMicrophone](CallCoreHost *internal) {
        internal->setMuteMicrophone(muteMicrophone);
    });
}

void InstanceV2PumpImpl::setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _internal->perform([sink](CallCoreHost *internal) {
        internal->setIncomingVideoOutput(sink);
    });
}

void InstanceV2PumpImpl::setAudioInputDevice(std::string id) {
    _internal->perform([id](CallCoreHost *internal) {
        internal->setAudioInputDevice(id);
    });
}

void InstanceV2PumpImpl::setAudioOutputDevice(std::string id) {
    _internal->perform([id](CallCoreHost *internal) {
        internal->setAudioOutputDevice(id);
    });
}

void InstanceV2PumpImpl::setIsLowBatteryLevel(bool isLowBatteryLevel) {
    _internal->perform([isLowBatteryLevel](CallCoreHost *internal) {
        internal->setIsLowBatteryLevel(isLowBatteryLevel);
    });
}

void InstanceV2PumpImpl::setInputVolume(float level) {
}

void InstanceV2PumpImpl::setOutputVolume(float level) {
}

void InstanceV2PumpImpl::setAudioOutputDuckingEnabled(bool enabled) {
}

void InstanceV2PumpImpl::setAudioOutputGainControlEnabled(bool enabled) {
}

void InstanceV2PumpImpl::setEchoCancellationStrength(int strength) {
}

std::vector<std::string> InstanceV2PumpImpl::GetVersions() {
    std::vector<std::string> result;
    result.push_back("10.0.0-pump");
    result.push_back("11.0.0-pump");
    return result;
}

int InstanceV2PumpImpl::GetConnectionMaxLayer() {
    return 92;
}

std::string InstanceV2PumpImpl::getLastError() {
    return "";
}

std::string InstanceV2PumpImpl::getDebugInfo() {
    return "";
}

int64_t InstanceV2PumpImpl::getPreferredRelayId() {
    return 0;
}

TrafficStats InstanceV2PumpImpl::getTrafficStats() {
    return {};
}

PersistentState InstanceV2PumpImpl::getPersistentState() {
    return {};
}

void InstanceV2PumpImpl::stop(std::function<void(FinalState)> completion) {
    std::string debugLog;
    if (_logSink) {
        debugLog = _logSink->result();
    }
    _internal->perform([completion, debugLog = std::move(debugLog)](CallCoreHost *internal) mutable {
        internal->stop([completion, debugLog = std::move(debugLog)](FinalState finalState) mutable {
            finalState.debugLog = debugLog;
            completion(finalState);
        });
    });
}

template <>
bool Register<InstanceV2PumpImpl>() {
    return Meta::RegisterOne<InstanceV2PumpImpl>();
}

} // namespace tgcalls
```

- [ ] **Step 3: Add to BUILD (parent repo)** — same two spots, add:

```python
    "tgcalls/tgcalls/v2wasm/InstanceV2PumpImpl.cpp",
```

- [ ] **Step 4: Register in the CLI** — in `submodules/TgVoipWebrtc/tgcalls/tools/cli/main.cpp`:

After line `#include "v2/InstanceV2ReferenceImpl.h"` add:

```cpp
#include "v2wasm/InstanceV2PumpImpl.h"
```

After line `tgcalls::Register<tgcalls::InstanceV2ReferenceImpl>();` add:

```cpp
    tgcalls::Register<tgcalls::InstanceV2PumpImpl>();
```

- [ ] **Step 5: Full CLI build**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli 2>&1 | tail -5
```

Expected: `Build completed successfully`.

- [ ] **Step 6: Commit (both repos)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/InstanceV2PumpImpl.h tgcalls/v2wasm/InstanceV2PumpImpl.cpp tools/cli/main.cpp && \
git commit -m "feat(v2wasm): InstanceV2PumpImpl — pump instance registered as 10.0.0-pump/11.0.0-pump

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" && cd ../../..
git add submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): compile v2wasm/InstanceV2PumpImpl.cpp into tgcalls targets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Interop matrix validation + final commits

**Files:**
- No new files; fixes land in the files from Tasks 2–4 as needed.
- Modify (final): parent repo gitlink for `submodules/TgVoipWebrtc/tgcalls`.

**Interfaces:**
- Consumes: the built `tgcalls_cli` with pump registration.
- Produces: passing interop matrix (the spec's success criteria), final committed state.

- [ ] **Step 1: Pump caller ↔ stock callee (V2 signaling)**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo "exit=$?"
```

Expected: `exit=0`. On failure, run without `--quiet`; compare the pump side's logged signaling messages (`CallCoreHost signaling in/signaling_send`) against a stock↔stock run (`--version 11.0.0`) — the JSON must match field-for-field. Debug with the systematic-debugging skill; the likely failure classes are: SLD completion ordering (check `pc_set_local_done` fires before `signaling_send`), candidate buffering (candidates must be held until both descriptions are set), and dc_state not reaching the core (MediaState never sent — benign for call setup but check logs).

- [ ] **Step 2: Stock caller ↔ pump callee**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet; echo "exit=$?"
```

Expected: `exit=0`. This exercises the polite-peer/answerer path (`pc_set_remote_done{offer}` → SLD → answer).

- [ ] **Step 3: Pump ↔ pump**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet; echo "exit=$?"
```

Expected: `exit=0`.

- [ ] **Step 4: Lossy signaling**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --quiet; echo "exit=$?"
```

Expected: `exit=0` (SCTP retransmission is host-side and unchanged; this validates the core's tolerance of delayed/reordered events).

- [ ] **Step 5: V1 signaling path (10.0.0)**

```bash
./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet; echo "exit=$?"
```

Expected: `exit=0` (ExternalSignalingConnection + `prepareForSendingRawMessage`/`handleIncomingRawPacket`, no gzip).

- [ ] **Step 6 (stretch): small mass test**

```bash
./submodules/TgVoipWebrtc/tgcalls/tools/cli/run-local-test.sh -n 50 -j 25 --version 11.0.0-pump
```

Expected: 100% success (50/50). Skip if the script does not accept `--version2` asymmetry; the single runs above are the acceptance gate.

- [ ] **Step 7: Commit any fixes + finalize**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git status --porcelain && \
git add -A tgcalls/v2wasm tools/cli/main.cpp && git diff --cached --quiet || \
git commit -m "fix(v2wasm): interop fixes from CLI validation matrix

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"; cd ../../..
git add submodules/TgVoipWebrtc/tgcalls && \
git commit -m "chore(tgcalls): pin tgcalls submodule to pump-boundary sketch branch

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Record results** — append a `## Validation results` section to the spec doc with the actual exit codes/dates for the 5+1 matrix rows, and commit:

```bash
git add docs/superpowers/specs/2026-07-01-tgcalls-wasm-core-pump-design.md && \
git commit -m "docs(tgcalls): record pump-boundary validation matrix results

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Plan self-review notes

- **Spec coverage:** ABI header (Task 1) ⇔ spec "The ABI"; core port (Task 2) ⇔ "ReferenceCallCore"; harness (Task 3) ⇔ "CallCoreHost"; shell + registration (Task 4) ⇔ "InstanceV2PumpImpl" + "Build & registration changes"; matrix (Task 5) ⇔ "Testing". Spec deltas introduced: `pc_signaling_state` event and `nowMs` clock rule — amended into the spec in Task 1 Step 4.
- **Known simplifications vs stock (accepted, non-wire-affecting):** stock re-checks `signalingProtocolVersion()` per message; the host fixes it at construction (same value — version never changes mid-call). Stock's `_isPerformingConfiguration` flag is dead (never read) — not ported. Stock's unused `sendCandidate(cricket::Candidate)`/`CandidatesMessage` sender is dead code in the reference impl — not ported (the parser side isn't needed either; stock peers never send it on this protocol).
- **Type consistency:** `deliverEvent(json11::Json::object &&)` is used by the observer classes via `friend`; `CallCoreHost` exposes exactly the eight methods `InstanceV2PumpImpl` calls.
- **Risk watch:** exact WebRTC API names in Task 3 may drift from this tree's snapshot (e.g. `GetRtpSenderCapabilities` arg type, `CreateVideoTrack` overloads). Resolution rule: mirror `v2/InstanceV2ReferenceImpl.cpp`, which compiles in the same build.
