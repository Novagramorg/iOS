# tgcalls WASM-core Phase 2.5: PC-projection ABI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite call-core ABI v1 in place as a PeerConnection projection (two-step SLD with SDP munge point, transceiver/parameter/ICE-restart commands, rich stats), keep `ReferenceCallCore` stock-parity, and ship a second `variant-core-abi1.wasm` module that visibly changes call behavior with no harness rebuild.

**Architecture:** The fixed harness (`CallCoreHost`) stays a policy-free executor of JSON commands mirroring the WebRTC PeerConnection API; all policy lives in the core (`ReferenceCallCore`, compiled both natively and to WASM). A new `VariantCallCore` derives from the reference core via protected virtual hooks and is packaged as a separate WASM module through a per-module factory translation unit. Spec: `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md`.

**Tech Stack:** C++17, json11, WebRTC (vendored), Bazel 8.4.2, wasi-sdk 33.0 genrules, WAMR interpreter backend (untouched).

## Global Constraints

- **Repo layout:** tgcalls is a git submodule at `submodules/TgVoipWebrtc/tgcalls/` (branch `tgcalls-wasm-core-sketch`). Files under `tgcalls/tgcalls/...` are committed in the **submodule**; `submodules/TgVoipWebrtc/BUILD`, `docs/...` are committed in the **parent** worktree (`/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/tgcalls-wasm-core-sketch`). Parent commits that follow submodule commits must `git add submodules/TgVoipWebrtc/tgcalls` to pin the new submodule SHA.
- **Build command (CLI + both wasm modules):** from the worktree root: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`. Exit 0 = pass. Do not use system bazel (v9 incompatible).
- **Core include discipline:** `ReferenceCallCore.*`, `VariantCallCore.*`, `CoreFactory.h`, `*_core_factory.cpp`, `wasm_module_entry.cpp` may include ONLY `v2wasm/CallCoreABI.h`, `v2wasm/ReferenceCallCore.h`, `v2wasm/VariantCallCore.h`, `v2wasm/CoreFactory.h`, `third-party/json11.hpp`, and the C++17 standard library. No webrtc, no absl, no other tgcalls headers, no exceptions.
- **Wire parity is frozen:** never rename a signaling JSON key (`@type`, `sdp`, `mid`, `mline`, `muted`, `lowBattery`, `videoState`, `videoRotation`, `screencastState`). SDP track/stream ids stay `"0"` (stream), `"0"` (audio track), `"1"` (video track) — they appear in `a=msid` lines on the wire.
- **abiVersion stays 1.** This rewrite is the true v1; no compatibility path for the old command set.
- **Pump rules unchanged:** commands queued, never re-entering the core; events carry `nowMs`; unknown event types ignored by the core; unknown commands answered with an `error` event.
- **WASM-only sources:** `wasm_module_entry.cpp`, `reference_core_factory.cpp`, `variant_core_factory.cpp`, `VariantCallCore.cpp` must NEVER be added to the native source lists in `submodules/TgVoipWebrtc/BUILD` (`tgcalls_core` list at ~line 167 and the `objc_library` list at ~line 306). The BUILD globs only compile `.cpp` under `platform/darwin`, `third-party`, `utils` — new `v2wasm/*.cpp` files are inert unless explicitly listed, which is the intended safety.
- **No unit-test framework exists.** Test cycles are: Bazel build (compile gate) + `tgcalls_cli` runs (behavior gate). CLI exit 0 = pass.
- **Environment note:** builds do not need codesigning env vars; the full iOS app build (Task 8) needs `source ~/.zshrc 2>/dev/null;` prefix for `TELEGRAM_CODESIGNING_GIT_PASSWORD`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `tgcalls/tgcalls/v2wasm/CallCoreABI.h` (submodule) | rewrite doc block | The frozen contract (true v1, PC projection) |
| `tgcalls/tgcalls/v2wasm/CallCoreHost.{h,cpp}` (submodule) | modify | New executors (create-offer/answer, SLD-with-SDP, restart-ice, transceiver registry, set-parameters, sink binding, DC options), observer events, rich stats reducer |
| `tgcalls/tgcalls/v2wasm/ReferenceCallCore.{h,cpp}` (submodule) | modify | Two-step SLD flow, transceiver-based tracks, protected virtual hooks |
| `tgcalls/tgcalls/v2wasm/CoreFactory.h` (submodule) | create | `createModuleCore()` seam selecting the core class per WASM module |
| `tgcalls/tgcalls/v2wasm/reference_core_factory.cpp` (submodule) | create | Reference module factory TU (wasm-only) |
| `tgcalls/tgcalls/v2wasm/VariantCallCore.{h,cpp}` (submodule) | create | Demo variant core (wasm-only .cpp) |
| `tgcalls/tgcalls/v2wasm/variant_core_factory.cpp` (submodule) | create | Variant module factory TU (wasm-only) |
| `tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp` (submodule) | modify | Generic entry: instantiate via `createModuleCore` |
| `submodules/TgVoipWebrtc/BUILD` (parent) | modify | Factory srcs in reference genrule; new `variant_core_wasm` genrule |
| `tgcalls/tools/cli/BUILD` (submodule) | modify | `variant_core_wasm` data dep |
| `tgcalls/tgcalls/v2wasm/CLAUDE.md`, `tgcalls/CLAUDE.md` (submodule) | modify | Docs |
| `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md` (parent) | modify | Append validation results |

Shell variables used by all validation steps (run from the worktree root):

```bash
BAZEL=./build-input/bazel-8.4.2-darwin-arm64
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
```

---

### Task 1: Rewrite the ABI contract (`CallCoreABI.h`)

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreABI.h`

**Interfaces:**
- Produces: the normative event/command schema every later task implements. Later tasks copy names/fields from here verbatim.

- [ ] **Step 1: Replace the doc block (lines 35–104, between the "Rules (normative)" section and the `#ifdef __cplusplus`)**

Keep the file header, the Rules section (THREADING/REENTRANCY/MEMORY/EXTENSIBILITY/CLOCK — unchanged), the C declarations, and the include guards. Replace the Config/Events/Commands/Module-form sections with:

```
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
//   pc_connection_state { state: "new"|"connecting"|"connected"|
//                                "disconnected"|"failed"|"closed" }
//   pc_gathering_state  { state: "new"|"gathering"|"complete" }
//   pc_signaling_state  { state: "stable"|"have-local-offer"|
//                                "have-remote-offer"|"have-local-pranswer"|
//                                "have-remote-pranswer"|"closed" }
//   pc_candidate_pair_changed { local: {type,protocol,address},
//                               remote: {type,protocol,address} }
//   pc_description_created { ok: bool, type: "offer"|"answer", sdp: s,
//                            error: s }         completes pc_create_offer/
//                                               pc_create_answer
//   pc_set_local_done   { ok: bool, type: "offer"|"answer", sdp: s }
//                                               sdp read back after apply
//   pc_set_remote_done  { ok: bool, sdpType: "offer"|"answer" }
//   pc_track            { mid: s, kind: "audio"|"video" }  remote track (OnTrack)
//   dc_state            { open: bool }
//   dc_message          { data: string }        text messages only
//   timer               { token: n }
//   stats               { sendBitrateKbps: n,   curated GetStats reduction;
//                         transport: { rttMs?, availableOutgoingKbps?,
//                           availableIncomingKbps?, bytesSent, bytesReceived,
//                           localCandidateType?, remoteCandidateType? },
//                         audio: { send?: { bitrateKbps, packetsSent,
//                             remoteLossFraction?, remoteRttMs?,
//                             remoteJitterMs? },
//                           recv?: { bitrateKbps, packetsReceived,
//                             packetsLost, jitterMs?, audioLevel? } },
//                         video: { send?: { bitrateKbps, packetsSent,
//                             frameRate?, frameWidth?, frameHeight?,
//                             qualityLimitationReason?, remoteLossFraction?,
//                             remoteRttMs?, remoteJitterMs? },
//                           recv?: { bitrateKbps, packetsReceived,
//                             packetsLost, framesDecoded, frameRate?,
//                             frameWidth?, frameHeight? } } }
//                       absent measurements omit their keys; bitrates are
//                       host-computed deltas between polls, EXCEPT the
//                       top-level sendBitrateKbps which is the max BWE
//                       (available_outgoing_bitrate / 1024, kept for
//                       stats-log parity with stock)
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
//   pc_create_offer     {}                      -> pc_description_created
//   pc_create_answer    {}                      -> pc_description_created
//   pc_set_local_description  { type: s, sdp: s }  the SDP to apply (the
//                                               core may munge what it got
//                                               from pc_description_created)
//   pc_set_remote_description { sdpType: s, sdp: s }
//   pc_add_ice_candidate      { mid: s, mline: n, sdp: s }
//   pc_restart_ice      {}                      flows back through
//                                               pc_renegotiation_needed
//   pc_add_transceiver  { id: s (core-chosen), kind: "audio"|"video",
//                         direction: "sendrecv"|"sendonly"|"recvonly"|
//                                    "inactive",
//                         codecPreferences: [s] (optional),
//                         sendEncodings: [ { active?: bool,
//                           maxBitrateBps?: n, minBitrateBps?: n,
//                           scaleResolutionDownBy?: n, rid?: s } ] (optional),
//                         trackSource: "microphone"|"camera"|"none" }
//   pc_set_parameters   { id: s, degradationPreference?: "disabled"|
//                           "maintain-framerate"|"maintain-resolution"|
//                           "balanced",
//                         encodings: [ same fields as sendEncodings ] }
//                       host merges into GetParameters() then SetParameters
//   pc_set_track_enabled { id: s, enabled: bool }
//   pc_remove_track     { id: s }
//   pc_set_incoming_sink { mid: s }             bind the app video sink to
//                                               this incoming transceiver
//   pc_create_data_channel { label?: s (default "data"), ordered?: bool,
//                            negotiated?: bool, id?: n }
//   dc_send             { data: string }
//   signaling_send      { data: string }        plaintext; host gzips (V2)
//                                               and encrypts
//   set_timer           { token: n, delayMs: n }
//   pc_get_stats        {}                      -> stats event
//   emit_state          { state: "established"|"failed"|"reconnecting" }
//   emit_signal_bars    { bars: 0..4 }
//   emit_remote_media_state { audio: "active"|"muted",
//                             video: "inactive"|"paused"|"active" }
//   emit_remote_battery_low { low: bool }
//   log                 { message: s }
//   stats_log           { json: s }             host writes at stop
//   close               {}                      host closes PC, completes stop
```

Keep the existing "Module form (WASM)" section verbatim (exports/imports are unchanged). Update the file's opening comment sentence from "the three functions below are the module exports" wording only if it became inaccurate — it did not; leave it.

- [ ] **Step 2: Compile gate**

Run from worktree root: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
Expected: `Build completed successfully` (doc-only change).

- [ ] **Step 3: Commit (submodule)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreABI.h && \
git commit -m "abi(v2wasm): rewrite ABI v1 in place as a PeerConnection projection

Two-step SLD (pc_create_offer/answer -> pc_description_created ->
pc_set_local_description{type,sdp}), pc_add_transceiver/pc_set_parameters/
pc_set_track_enabled/pc_remove_track, pc_restart_ice, pc_set_incoming_sink,
pc_track/pc_connection_state/pc_gathering_state events, rich stats event,
data-channel options, request_stats -> pc_get_stats. Nothing shipped on the
old shape; abiVersion stays 1."
```

---

### Task 2: Host — PC-projection executors and observer events

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h`
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`

**Interfaces:**
- Consumes: the Task-1 schema.
- Produces: host-side execution of `pc_create_offer`, `pc_create_answer`, `pc_set_local_description {type,sdp}`, `pc_restart_ice`, `pc_add_transceiver`, `pc_set_parameters`, `pc_set_track_enabled`, `pc_remove_track`, `pc_set_incoming_sink`, `pc_create_data_channel {label,ordered,negotiated,id}`; events `pc_description_created`, `pc_track`, `pc_connection_state`, `pc_gathering_state`. Removes `pc_add_audio_track`, `pc_add_video_track`, `pc_remove_video_track`, `pc_set_audio_track_enabled`, no-arg SLD.
- **NOTE:** after this task the reference core still emits the OLD commands, so `tgcalls_cli` pump runs will fail at runtime until Task 4 lands. The gate for this task is compile-only; this is intentional (break-in-place rewrite mid-branch).

- [ ] **Step 1: Header — replace executor declarations and track members**

In `CallCoreHost.h`, replace the private executor declarations

```cpp
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
```

with

```cpp
    void executePcCreate(json11::Json const &command);
    void executeCreateDescription(bool isOffer);
    void executeSetLocalDescription(json11::Json const &command);
    void executeSetRemoteDescription(json11::Json const &command);
    void executeAddIceCandidate(json11::Json const &command);
    void executeAddTransceiver(json11::Json const &command);
    void executeSetParameters(json11::Json const &command);
    void executeSetTrackEnabled(json11::Json const &command);
    void executeRemoveTrack(json11::Json const &command);
    void executeSetIncomingSink(json11::Json const &command);
    void executeCreateDataChannel(json11::Json const &command);
    void executeSignalingSend(json11::Json const &command);
    void executeGetStats();
    void executeClose();
```

and replace the outgoing-track members

```cpp
    webrtc::scoped_refptr<webrtc::AudioTrackInterface> _outgoingAudioTrack;
    webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> _outgoingAudioTransceiver;
    webrtc::scoped_refptr<webrtc::VideoTrackInterface> _outgoingVideoTrack;
    webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> _outgoingVideoTransceiver;
```

with

```cpp
    // Core-managed transceivers/tracks, keyed by the core-chosen id from
    // pc_add_transceiver. Incoming (remote) transceivers stay keyed by mid in
    // _incomingVideoTransceivers.
    std::map<std::string, webrtc::scoped_refptr<webrtc::RtpTransceiverInterface>> _coreTransceivers;
    std::map<std::string, webrtc::scoped_refptr<webrtc::MediaStreamTrackInterface>> _coreTracks;
    // Incoming mids the core asked to bind the app video sink to.
    std::set<std::string> _requestedSinkMids;
```

Add `#include <set>` to the header includes.

- [ ] **Step 2: Add the CreateSessionDescription observer adapter**

In `CallCoreHost.cpp`, inside `namespace v2wasm_detail` after `SetSessionDescriptionObserver`, add:

```cpp
class CreateSessionDescriptionObserverAdapter : public webrtc::CreateSessionDescriptionObserver {
public:
    // completion(type, sdp, error): success -> error empty; failure -> type/sdp empty.
    CreateSessionDescriptionObserverAdapter(std::function<void(std::string, std::string, std::string)> &&completion) :
    _completion(std::move(completion)) {
    }

    void OnSuccess(webrtc::SessionDescriptionInterface *desc) override {
        std::unique_ptr<webrtc::SessionDescriptionInterface> description(desc); // ownership transferred
        std::string sdp;
        description->ToString(&sdp);
        _completion(description->type(), sdp, std::string());
    }

    void OnFailure(webrtc::RTCError error) override {
        _completion(std::string(), std::string(), error.message());
    }

private:
    std::function<void(std::string, std::string, std::string)> _completion;
};
```

- [ ] **Step 3: Observer — new events, remove sink auto-bind**

In `PeerConnectionDelegateAdapter`:

Replace the empty `OnIceGatheringChange` override with:

```cpp
    void OnIceGatheringChange(webrtc::PeerConnectionInterface::IceGatheringState newState) override {
        std::string state;
        switch (newState) {
            case webrtc::PeerConnectionInterface::kIceGatheringNew: state = "new"; break;
            case webrtc::PeerConnectionInterface::kIceGatheringGathering: state = "gathering"; break;
            case webrtc::PeerConnectionInterface::kIceGatheringComplete: state = "complete"; break;
            default: state = "new"; break;
        }
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({ {"@type", "pc_gathering_state"}, {"state", state} });
        }
    }
```

Replace the empty `OnConnectionChange` override with:

```cpp
    void OnConnectionChange(webrtc::PeerConnectionInterface::PeerConnectionState newState) override {
        std::string state;
        switch (newState) {
            case webrtc::PeerConnectionInterface::PeerConnectionState::kNew: state = "new"; break;
            case webrtc::PeerConnectionInterface::PeerConnectionState::kConnecting: state = "connecting"; break;
            case webrtc::PeerConnectionInterface::PeerConnectionState::kConnected: state = "connected"; break;
            case webrtc::PeerConnectionInterface::PeerConnectionState::kDisconnected: state = "disconnected"; break;
            case webrtc::PeerConnectionInterface::PeerConnectionState::kFailed: state = "failed"; break;
            case webrtc::PeerConnectionInterface::PeerConnectionState::kClosed: state = "closed"; break;
            default: state = "new"; break;
        }
        if (const auto strong = _host.lock()) {
            strong->deliverEvent({ {"@type", "pc_connection_state"}, {"state", state} });
        }
    }
```

Replace the body of `OnTrack` with (sink binding now waits for the core's `pc_set_incoming_sink`; connect immediately only if the command already arrived):

```cpp
    void OnTrack(webrtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver) override {
        const auto strong = _host.lock();
        if (!strong) {
            return;
        }
        if (!transceiver->mid()) {
            return;
        }
        std::string mid = transceiver->mid().value();
        std::string kind = "audio";
        if (transceiver->media_type() == cricket::MediaType::MEDIA_TYPE_VIDEO) {
            kind = "video";
            if (strong->_incomingVideoTransceivers.find(mid) == strong->_incomingVideoTransceivers.end()) {
                strong->_incomingVideoTransceivers.insert(std::make_pair(mid, transceiver));
                if (strong->_requestedSinkMids.find(mid) != strong->_requestedSinkMids.end()) {
                    strong->connectIncomingVideoSink(transceiver);
                }
            }
        }
        strong->deliverEvent({ {"@type", "pc_track"}, {"mid", mid}, {"kind", kind} });
    }
```

- [ ] **Step 4: Rewrite the command dispatch table**

In `executeCommand`, replace the dispatch chain between the `core_ready` branch and the `dc_send` branch with:

```cpp
    } else if (type == "pc_create") {
        executePcCreate(command);
    } else if (type == "pc_create_offer") {
        executeCreateDescription(true);
    } else if (type == "pc_create_answer") {
        executeCreateDescription(false);
    } else if (type == "pc_set_local_description") {
        executeSetLocalDescription(command);
    } else if (type == "pc_set_remote_description") {
        executeSetRemoteDescription(command);
    } else if (type == "pc_add_ice_candidate") {
        executeAddIceCandidate(command);
    } else if (type == "pc_restart_ice") {
        if (_peerConnection) {
            RTC_LOG(LS_INFO) << "CallCoreHost: RestartIce";
            _peerConnection->RestartIce();
        } else {
            emitErrorEvent("no peer connection", "pc_restart_ice");
        }
    } else if (type == "pc_add_transceiver") {
        executeAddTransceiver(command);
    } else if (type == "pc_set_parameters") {
        executeSetParameters(command);
    } else if (type == "pc_set_track_enabled") {
        executeSetTrackEnabled(command);
    } else if (type == "pc_remove_track") {
        executeRemoveTrack(command);
    } else if (type == "pc_set_incoming_sink") {
        executeSetIncomingSink(command);
    } else if (type == "pc_create_data_channel") {
        executeCreateDataChannel(command);
```

and replace the `request_stats` branch with:

```cpp
    } else if (type == "pc_get_stats") {
        executeGetStats();
```

(The removed branches: `pc_add_audio_track`, `pc_add_video_track`, `pc_remove_video_track`, `pc_set_audio_track_enabled`, `request_stats`. Everything else — `dc_send`, `signaling_send`, `set_timer`, `emit_*`, `log`, `stats_log`, `close`, unknown-command error — stays.)

- [ ] **Step 5: New executors — descriptions and ICE**

Replace `executeSetLocalDescription()` (the whole function) with these two functions:

```cpp
void CallCoreHost::executeCreateDescription(bool isOffer) {
    const std::string commandName = isOffer ? "pc_create_offer" : "pc_create_answer";
    const std::string descType = isOffer ? "offer" : "answer";
    if (!_peerConnection) {
        deliverEvent({ {"@type", "pc_description_created"}, {"ok", false}, {"type", descType}, {"sdp", ""}, {"error", "no peer connection"} });
        emitErrorEvent("no peer connection", commandName);
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<v2wasm_detail::CreateSessionDescriptionObserverAdapter> observer(new rtc::RefCountedObject<v2wasm_detail::CreateSessionDescriptionObserverAdapter>([weak, threads = _threads, descType](std::string type, std::string sdp, std::string error) {
        threads->getMediaThread()->PostTask([weak, descType, type, sdp, error]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            strong->deliverEvent({
                {"@type", "pc_description_created"},
                {"ok", error.empty() && !sdp.empty()},
                {"type", type.empty() ? descType : type},
                {"sdp", sdp},
                {"error", error},
            });
        });
    }));
    RTC_LOG(LS_INFO) << "CallCoreHost: " << (isOffer ? "CreateOffer" : "CreateAnswer");
    webrtc::PeerConnectionInterface::RTCOfferAnswerOptions options;
    if (isOffer) {
        _peerConnection->CreateOffer(observer.get(), options);
    } else {
        _peerConnection->CreateAnswer(observer.get(), options);
    }
}

void CallCoreHost::executeSetLocalDescription(json11::Json const &command) {
    const auto type = coreStringField(command, "type");
    if (!_peerConnection) {
        deliverEvent({ {"@type", "pc_set_local_done"}, {"ok", false}, {"type", type}, {"sdp", ""} });
        emitErrorEvent("no peer connection", "pc_set_local_description");
        return;
    }
    webrtc::SdpParseError sdpParseError;
    std::unique_ptr<webrtc::SessionDescriptionInterface> localDescription(webrtc::CreateSessionDescription(type, coreStringField(command, "sdp"), &sdpParseError));
    if (!localDescription) {
        deliverEvent({ {"@type", "pc_set_local_done"}, {"ok", false}, {"type", type}, {"sdp", ""} });
        emitErrorEvent("failed to parse local SDP", "pc_set_local_description");
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<webrtc::SetLocalDescriptionObserverInterface> observer(new rtc::RefCountedObject<v2wasm_detail::SetSessionDescriptionObserver>([weak, threads = _threads](webrtc::RTCError error) {
        threads->getMediaThread()->PostTask([weak, ok = error.ok()]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            // Read back the applied description (parity with the Phase-1 host:
            // the core sends what was actually applied, post-munge).
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
    _peerConnection->SetLocalDescription(std::move(localDescription), observer);
}
```

- [ ] **Step 6: New executors — transceivers, parameters, tracks, sink**

Replace `executeAddAudioTrack`, `executeAddVideoTrack`, and `executeRemoveVideoTrack` (all three functions) with:

```cpp
void CallCoreHost::executeAddTransceiver(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_add_transceiver");
        return;
    }
    const auto id = coreStringField(command, "id");
    if (id.empty() || _coreTransceivers.find(id) != _coreTransceivers.end()) {
        emitErrorEvent("missing or duplicate transceiver id", "pc_add_transceiver");
        return;
    }
    const bool isVideo = (coreStringField(command, "kind") == "video");

    webrtc::RtpTransceiverInit transceiverInit;
    transceiverInit.stream_ids = { "0" };
    const auto direction = coreStringField(command, "direction");
    if (direction == "sendonly") {
        transceiverInit.direction = webrtc::RtpTransceiverDirection::kSendOnly;
    } else if (direction == "recvonly") {
        transceiverInit.direction = webrtc::RtpTransceiverDirection::kRecvOnly;
    } else if (direction == "inactive") {
        transceiverInit.direction = webrtc::RtpTransceiverDirection::kInactive;
    } else {
        transceiverInit.direction = webrtc::RtpTransceiverDirection::kSendRecv;
    }
    for (const auto &encoding : command["sendEncodings"].array_items()) {
        webrtc::RtpEncodingParameters encodingParameters;
        if (encoding["active"].is_bool()) {
            encodingParameters.active = encoding["active"].bool_value();
        }
        if (encoding["maxBitrateBps"].is_number()) {
            encodingParameters.max_bitrate_bps = (int)encoding["maxBitrateBps"].number_value();
        }
        if (encoding["minBitrateBps"].is_number()) {
            encodingParameters.min_bitrate_bps = (int)encoding["minBitrateBps"].number_value();
        }
        if (encoding["scaleResolutionDownBy"].is_number()) {
            encodingParameters.scale_resolution_down_by = encoding["scaleResolutionDownBy"].number_value();
        }
        if (encoding["rid"].is_string()) {
            encodingParameters.rid = encoding["rid"].string_value();
        }
        transceiverInit.send_encodings.push_back(encodingParameters);
    }

    // trackSource binds host-owned devices; track ids "0"/"1" are stock's and
    // appear in a=msid on the wire — do not change them.
    webrtc::scoped_refptr<webrtc::MediaStreamTrackInterface> track;
    const auto trackSource = coreStringField(command, "trackSource");
    if (trackSource == "microphone") {
        cricket::AudioOptions audioSourceOptions;
        webrtc::scoped_refptr<webrtc::AudioSourceInterface> audioSource = _peerConnectionFactory->CreateAudioSource(audioSourceOptions);
        track = _peerConnectionFactory->CreateAudioTrack("0", audioSource.get());
    } else if (trackSource == "camera") {
        auto videoCaptureImpl = GetVideoCaptureAssumingSameThread(_videoCapture.get());
        if (!videoCaptureImpl || videoCaptureImpl->isScreenCapture()) {
            emitErrorEvent("no usable video capture", "pc_add_transceiver");
            return;
        }
        track = _peerConnectionFactory->CreateVideoTrack(videoCaptureImpl->source(), "1");
        if (!track) {
            emitErrorEvent("CreateVideoTrack failed", "pc_add_transceiver");
            return;
        }
    }

    auto transceiverOrError = track
        ? _peerConnection->AddTransceiver(track, transceiverInit)
        : _peerConnection->AddTransceiver(isVideo ? cricket::MediaType::MEDIA_TYPE_VIDEO : cricket::MediaType::MEDIA_TYPE_AUDIO, transceiverInit);
    if (!transceiverOrError.ok()) {
        emitErrorEvent("AddTransceiver failed", "pc_add_transceiver");
        return;
    }
    const auto transceiver = transceiverOrError.value();
    _coreTransceivers.insert(std::make_pair(id, transceiver));
    if (track) {
        _coreTracks.insert(std::make_pair(id, track));
        track->set_enabled(true);
    }

    if (command["codecPreferences"].is_array()) {
        // Stock preference merge: requested names first, remaining
        // capabilities after, mapped back to capability entries.
        auto currentCapabilities = _peerConnectionFactory->GetRtpSenderCapabilities(isVideo ? cricket::MediaType::MEDIA_TYPE_VIDEO : cricket::MediaType::MEDIA_TYPE_AUDIO);
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
        transceiver->SetCodecPreferences(codecCapabilities);
    }
}

void CallCoreHost::executeSetParameters(json11::Json const &command) {
    const auto it = _coreTransceivers.find(coreStringField(command, "id"));
    if (it == _coreTransceivers.end()) {
        emitErrorEvent("unknown transceiver id", "pc_set_parameters");
        return;
    }
    webrtc::RtpParameters parameters = it->second->sender()->GetParameters();
    const auto degradation = coreStringField(command, "degradationPreference");
    if (degradation == "disabled") {
        parameters.degradation_preference = webrtc::DegradationPreference::DISABLED;
    } else if (degradation == "maintain-framerate") {
        parameters.degradation_preference = webrtc::DegradationPreference::MAINTAIN_FRAMERATE;
    } else if (degradation == "maintain-resolution") {
        parameters.degradation_preference = webrtc::DegradationPreference::MAINTAIN_RESOLUTION;
    } else if (degradation == "balanced") {
        parameters.degradation_preference = webrtc::DegradationPreference::BALANCED;
    }
    const auto &encodings = command["encodings"].array_items();
    for (size_t i = 0; i < encodings.size() && i < parameters.encodings.size(); i++) {
        const auto &encoding = encodings[i];
        if (encoding["active"].is_bool()) {
            parameters.encodings[i].active = encoding["active"].bool_value();
        }
        if (encoding["maxBitrateBps"].is_number()) {
            parameters.encodings[i].max_bitrate_bps = (int)encoding["maxBitrateBps"].number_value();
        }
        if (encoding["minBitrateBps"].is_number()) {
            parameters.encodings[i].min_bitrate_bps = (int)encoding["minBitrateBps"].number_value();
        }
        if (encoding["scaleResolutionDownBy"].is_number()) {
            parameters.encodings[i].scale_resolution_down_by = encoding["scaleResolutionDownBy"].number_value();
        }
    }
    const auto result = it->second->sender()->SetParameters(parameters);
    if (!result.ok()) {
        emitErrorEvent("SetParameters failed", "pc_set_parameters");
    }
}

void CallCoreHost::executeSetTrackEnabled(json11::Json const &command) {
    const auto it = _coreTracks.find(coreStringField(command, "id"));
    if (it == _coreTracks.end()) {
        emitErrorEvent("unknown track id", "pc_set_track_enabled");
        return;
    }
    it->second->set_enabled(command["enabled"].bool_value());
}

void CallCoreHost::executeRemoveTrack(json11::Json const &command) {
    const auto id = coreStringField(command, "id");
    const auto it = _coreTransceivers.find(id);
    if (it == _coreTransceivers.end()) {
        emitErrorEvent("unknown transceiver id", "pc_remove_track");
        return;
    }
    if (_peerConnection) {
        _peerConnection->RemoveTrackOrError(it->second->sender());
    }
    _coreTransceivers.erase(it);
    _coreTracks.erase(id);
}

void CallCoreHost::executeSetIncomingSink(json11::Json const &command) {
    const auto mid = coreStringField(command, "mid");
    if (mid.empty()) {
        emitErrorEvent("missing mid", "pc_set_incoming_sink");
        return;
    }
    _requestedSinkMids.insert(mid);
    const auto it = _incomingVideoTransceivers.find(mid);
    if (it != _incomingVideoTransceivers.end()) {
        connectIncomingVideoSink(it->second);
    }
}
```

- [ ] **Step 7: Data-channel options; sink re-wiring; destructor**

Replace `executeCreateDataChannel()` (whole function) with:

```cpp
void CallCoreHost::executeCreateDataChannel(json11::Json const &command) {
    if (!_peerConnection) {
        emitErrorEvent("no peer connection", "pc_create_data_channel");
        return;
    }
    webrtc::DataChannelInit dataChannelInit;
    if (command["ordered"].is_bool()) {
        dataChannelInit.ordered = command["ordered"].bool_value();
    }
    if (command["negotiated"].is_bool()) {
        dataChannelInit.negotiated = command["negotiated"].bool_value();
    }
    if (command["id"].is_number()) {
        dataChannelInit.id = (int)command["id"].number_value();
    }
    std::string label = coreStringField(command, "label");
    if (label.empty()) {
        label = "data";
    }
    auto dataChannelOrError = _peerConnection->CreateDataChannelOrError(label, &dataChannelInit);
    if (dataChannelOrError.ok()) {
        attachDataChannel(dataChannelOrError.value());
    } else {
        emitErrorEvent("CreateDataChannelOrError failed", "pc_create_data_channel");
    }
}
```

Replace the body of `setIncomingVideoOutput` with (bind only core-requested mids):

```cpp
void CallCoreHost::setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentStrongSink = sink.lock();
    if (!_currentStrongSink) {
        return;
    }
    for (const auto &mid : _requestedSinkMids) {
        const auto it = _incomingVideoTransceivers.find(mid);
        if (it != _incomingVideoTransceivers.end()) {
            connectIncomingVideoSink(it->second);
        }
    }
}
```

In the destructor, replace the four `_outgoing*` usages: there are none by name (they are only reset implicitly); instead ensure the new maps release before the factory by adding, right before `_peerConnection = nullptr;`:

```cpp
    _coreTracks.clear();
    _coreTransceivers.clear();
```

- [ ] **Step 8: Compile gate**

Run: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
Expected: `Build completed successfully`. (Runtime pump calls are known-broken until Task 4 — do not run the CLI matrix here.)

- [ ] **Step 9: Commit (submodule)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp && \
git commit -m "host(v2wasm): PC-projection executors + observer events

CreateOffer/CreateAnswer with pc_description_created, explicit-SDP SLD
(munge point), RestartIce, core-id transceiver registry with
sendEncodings/codecPreferences/trackSource, SetParameters merge,
track-enabled/remove by id, core-driven incoming-sink binding, data-channel
options, pc_track/pc_connection_state/pc_gathering_state events. Removes
pc_add_audio_track/pc_add_video_track/pc_remove_video_track/
pc_set_audio_track_enabled/no-arg SLD. Reference core catches up in a
following commit (break-in-place rewrite; CLI pump rows red until then)."
```

---

### Task 3: Host — rich stats reducer

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.h`
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CallCoreHost.cpp`

**Interfaces:**
- Consumes: `executeGetStats()` declaration from Task 2.
- Produces: the `stats` event exactly as documented in Task 1 (top-level `sendBitrateKbps` = max `available_outgoing_bitrate` / 1024 — byte-parity with the old event; everything else new).

- [ ] **Step 1: Header — delta state**

In `CallCoreHost.h`, after the `// stop flow` member block, add:

```cpp
    // stats delta state (media thread only): cumulative byte counters from
    // the previous pc_get_stats, for host-computed bitrate deltas.
    int64_t _lastStatsTimestampMs = 0;
    uint64_t _lastAudioBytesSent = 0;
    uint64_t _lastVideoBytesSent = 0;
    uint64_t _lastAudioBytesReceived = 0;
    uint64_t _lastVideoBytesReceived = 0;
```

- [ ] **Step 2: Implement the reducer**

In `CallCoreHost.cpp`, add to the anonymous namespace (after `coreStringField`):

```cpp
// Plain-value snapshot of the RTCStatsReport, filled on the stats callback
// thread and shipped to the media thread where JSON building + delta
// computation happen. Sentinels: -1.0 = absent for doubles, empty = absent
// for strings, present=false = no stream of that kind.
struct ReducedStats {
    double availableOutgoingBitrateBps = 0.0; // max over pairs (stock parity)
    double availableIncomingBitrateBps = 0.0;
    double rttMs = -1.0;
    std::string localCandidateType;
    std::string remoteCandidateType;
    uint64_t transportBytesSent = 0;
    uint64_t transportBytesReceived = 0;
    struct Send {
        bool present = false;
        uint64_t bytesSent = 0;
        uint64_t packetsSent = 0;
        double remoteLossFraction = -1.0;
        double remoteRttMs = -1.0;
        double remoteJitterMs = -1.0;
        double frameRate = -1.0;
        int frameWidth = 0;
        int frameHeight = 0;
        std::string qualityLimitationReason;
    };
    struct Recv {
        bool present = false;
        uint64_t bytesReceived = 0;
        uint64_t packetsReceived = 0;
        int packetsLost = 0;
        double jitterMs = -1.0;
        double audioLevel = -1.0;
        uint64_t framesDecoded = 0;
        double frameRate = -1.0;
        int frameWidth = 0;
        int frameHeight = 0;
    };
    Send audioSend;
    Send videoSend;
    Recv audioRecv;
    Recv videoRecv;
};

ReducedStats reduceStatsReport(const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &report) {
    ReducedStats reduced;
    if (!report) {
        return reduced;
    }

    std::string selectedPairId;
    for (const auto *transportStats : report->GetStatsOfType<webrtc::RTCTransportStats>()) {
        if (transportStats->selected_candidate_pair_id.has_value()) {
            selectedPairId = *transportStats->selected_candidate_pair_id;
        }
        reduced.transportBytesSent += transportStats->bytes_sent.value_or(0);
        reduced.transportBytesReceived += transportStats->bytes_received.value_or(0);
    }

    const auto candidateTypeById = [&](const std::string &candidateId) -> std::string {
        for (const auto *candidate : report->GetStatsOfType<webrtc::RTCLocalIceCandidateStats>()) {
            if (candidate->id() == candidateId && candidate->candidate_type.has_value()) {
                return *candidate->candidate_type;
            }
        }
        for (const auto *candidate : report->GetStatsOfType<webrtc::RTCRemoteIceCandidateStats>()) {
            if (candidate->id() == candidateId && candidate->candidate_type.has_value()) {
                return *candidate->candidate_type;
            }
        }
        return std::string();
    };

    for (const auto *pairStats : report->GetStatsOfType<webrtc::RTCIceCandidatePairStats>()) {
        if (pairStats->available_outgoing_bitrate.has_value()) {
            reduced.availableOutgoingBitrateBps = std::max(reduced.availableOutgoingBitrateBps, *pairStats->available_outgoing_bitrate);
        }
        if (pairStats->available_incoming_bitrate.has_value()) {
            reduced.availableIncomingBitrateBps = std::max(reduced.availableIncomingBitrateBps, *pairStats->available_incoming_bitrate);
        }
        const bool isSelected = (!selectedPairId.empty() && pairStats->id() == selectedPairId)
            || (selectedPairId.empty() && pairStats->nominated.value_or(false));
        if (isSelected) {
            if (pairStats->current_round_trip_time.has_value()) {
                reduced.rttMs = *pairStats->current_round_trip_time * 1000.0;
            }
            if (pairStats->local_candidate_id.has_value()) {
                reduced.localCandidateType = candidateTypeById(*pairStats->local_candidate_id);
            }
            if (pairStats->remote_candidate_id.has_value()) {
                reduced.remoteCandidateType = candidateTypeById(*pairStats->remote_candidate_id);
            }
        }
    }

    for (const auto *outbound : report->GetStatsOfType<webrtc::RTCOutboundRtpStreamStats>()) {
        const bool isVideo = outbound->kind.value_or("") == "video";
        auto &send = isVideo ? reduced.videoSend : reduced.audioSend;
        send.present = true;
        send.bytesSent += outbound->bytes_sent.value_or(0);
        send.packetsSent += outbound->packets_sent.value_or(0);
        if (isVideo) {
            if (outbound->frames_per_second.has_value()) {
                send.frameRate = *outbound->frames_per_second;
            }
            send.frameWidth = (int)outbound->frame_width.value_or(0);
            send.frameHeight = (int)outbound->frame_height.value_or(0);
            if (outbound->quality_limitation_reason.has_value()) {
                send.qualityLimitationReason = *outbound->quality_limitation_reason;
            }
        }
    }

    for (const auto *remoteInbound : report->GetStatsOfType<webrtc::RTCRemoteInboundRtpStreamStats>()) {
        const bool isVideo = remoteInbound->kind.value_or("") == "video";
        auto &send = isVideo ? reduced.videoSend : reduced.audioSend;
        if (remoteInbound->fraction_lost.has_value()) {
            send.remoteLossFraction = *remoteInbound->fraction_lost;
        }
        if (remoteInbound->round_trip_time.has_value()) {
            send.remoteRttMs = *remoteInbound->round_trip_time * 1000.0;
        }
        if (remoteInbound->jitter.has_value()) {
            send.remoteJitterMs = *remoteInbound->jitter * 1000.0;
        }
    }

    for (const auto *inbound : report->GetStatsOfType<webrtc::RTCInboundRtpStreamStats>()) {
        const bool isVideo = inbound->kind.value_or("") == "video";
        auto &recv = isVideo ? reduced.videoRecv : reduced.audioRecv;
        recv.present = true;
        recv.bytesReceived += inbound->bytes_received.value_or(0);
        recv.packetsReceived += inbound->packets_received.value_or(0);
        recv.packetsLost += inbound->packets_lost.value_or(0);
        if (inbound->jitter.has_value()) {
            recv.jitterMs = *inbound->jitter * 1000.0;
        }
        if (isVideo) {
            recv.framesDecoded += inbound->frames_decoded.value_or(0);
            if (inbound->frames_per_second.has_value()) {
                recv.frameRate = *inbound->frames_per_second;
            }
            recv.frameWidth = (int)inbound->frame_width.value_or(0);
            recv.frameHeight = (int)inbound->frame_height.value_or(0);
        } else if (inbound->audio_level.has_value()) {
            recv.audioLevel = *inbound->audio_level;
        }
    }

    return reduced;
}
```

- [ ] **Step 3: Replace `executeRequestStats` with `executeGetStats`**

Replace the whole `executeRequestStats()` function with:

```cpp
void CallCoreHost::executeGetStats() {
    if (!_peerConnection) {
        return;
    }
    const auto weak = std::weak_ptr<CallCoreHost>(shared_from_this());
    webrtc::scoped_refptr<v2wasm_detail::StatsCollectorCallbackAdapter> callback(new rtc::RefCountedObject<v2wasm_detail::StatsCollectorCallbackAdapter>([weak, threads = _threads](const webrtc::scoped_refptr<const webrtc::RTCStatsReport> &report) {
        ReducedStats reduced = reduceStatsReport(report);
        threads->getMediaThread()->PostTask([weak, reduced]() {
            const auto strong = weak.lock();
            if (!strong) {
                return;
            }
            const int64_t nowMs = rtc::TimeMillis();
            const double elapsedSec = strong->_lastStatsTimestampMs > 0
                ? (double)(nowMs - strong->_lastStatsTimestampMs) / 1000.0
                : 0.0;
            strong->_lastStatsTimestampMs = nowMs;
            const auto deltaKbps = [elapsedSec](uint64_t current, uint64_t &last) {
                double kbps = 0.0;
                if (elapsedSec > 0.0 && current >= last) {
                    kbps = (double)(current - last) * 8.0 / 1024.0 / elapsedSec;
                }
                last = current;
                return kbps;
            };

            json11::Json::object transport;
            if (reduced.rttMs >= 0.0) {
                transport["rttMs"] = reduced.rttMs;
            }
            if (reduced.availableOutgoingBitrateBps > 0.0) {
                transport["availableOutgoingKbps"] = reduced.availableOutgoingBitrateBps / 1024.0;
            }
            if (reduced.availableIncomingBitrateBps > 0.0) {
                transport["availableIncomingKbps"] = reduced.availableIncomingBitrateBps / 1024.0;
            }
            transport["bytesSent"] = (double)reduced.transportBytesSent;
            transport["bytesReceived"] = (double)reduced.transportBytesReceived;
            if (!reduced.localCandidateType.empty()) {
                transport["localCandidateType"] = reduced.localCandidateType;
            }
            if (!reduced.remoteCandidateType.empty()) {
                transport["remoteCandidateType"] = reduced.remoteCandidateType;
            }

            const auto sendObject = [&deltaKbps](ReducedStats::Send const &send, uint64_t &lastBytes, bool isVideo) {
                json11::Json::object object;
                object["bitrateKbps"] = deltaKbps(send.bytesSent, lastBytes);
                object["packetsSent"] = (double)send.packetsSent;
                if (send.remoteLossFraction >= 0.0) {
                    object["remoteLossFraction"] = send.remoteLossFraction;
                }
                if (send.remoteRttMs >= 0.0) {
                    object["remoteRttMs"] = send.remoteRttMs;
                }
                if (send.remoteJitterMs >= 0.0) {
                    object["remoteJitterMs"] = send.remoteJitterMs;
                }
                if (isVideo) {
                    if (send.frameRate >= 0.0) {
                        object["frameRate"] = send.frameRate;
                    }
                    if (send.frameWidth > 0) {
                        object["frameWidth"] = send.frameWidth;
                        object["frameHeight"] = send.frameHeight;
                    }
                    if (!send.qualityLimitationReason.empty()) {
                        object["qualityLimitationReason"] = send.qualityLimitationReason;
                    }
                }
                return object;
            };
            const auto recvObject = [&deltaKbps](ReducedStats::Recv const &recv, uint64_t &lastBytes, bool isVideo) {
                json11::Json::object object;
                object["bitrateKbps"] = deltaKbps(recv.bytesReceived, lastBytes);
                object["packetsReceived"] = (double)recv.packetsReceived;
                object["packetsLost"] = recv.packetsLost;
                if (recv.jitterMs >= 0.0) {
                    object["jitterMs"] = recv.jitterMs;
                }
                if (isVideo) {
                    object["framesDecoded"] = (double)recv.framesDecoded;
                    if (recv.frameRate >= 0.0) {
                        object["frameRate"] = recv.frameRate;
                    }
                    if (recv.frameWidth > 0) {
                        object["frameWidth"] = recv.frameWidth;
                        object["frameHeight"] = recv.frameHeight;
                    }
                } else if (recv.audioLevel >= 0.0) {
                    object["audioLevel"] = recv.audioLevel;
                }
                return object;
            };

            json11::Json::object audio;
            if (reduced.audioSend.present) {
                audio["send"] = sendObject(reduced.audioSend, strong->_lastAudioBytesSent, false);
            }
            if (reduced.audioRecv.present) {
                audio["recv"] = recvObject(reduced.audioRecv, strong->_lastAudioBytesReceived, false);
            }
            json11::Json::object video;
            if (reduced.videoSend.present) {
                video["send"] = sendObject(reduced.videoSend, strong->_lastVideoBytesSent, true);
            }
            if (reduced.videoRecv.present) {
                video["recv"] = recvObject(reduced.videoRecv, strong->_lastVideoBytesReceived, true);
            }

            strong->deliverEvent({
                {"@type", "stats"},
                // Stock parity: identical computation to the Phase-1 event.
                {"sendBitrateKbps", reduced.availableOutgoingBitrateBps / 1024.0},
                {"transport", std::move(transport)},
                {"audio", std::move(audio)},
                {"video", std::move(video)},
            });
        });
    }));
    _peerConnection->GetStats(callback.get());
}
```

- [ ] **Step 4: Compile gate**

Run: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
Expected: `Build completed successfully`.

- [ ] **Step 5: Commit (submodule)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CallCoreHost.h tgcalls/v2wasm/CallCoreHost.cpp && \
git commit -m "host(v2wasm): curated rich stats event (pc_get_stats)

Reduces the RTCStatsReport to ~1-2KB: selected-pair RTT/BWE/candidate
types, per-kind send/recv bitrate deltas, remote loss/RTT/jitter, frame
stats. Top-level sendBitrateKbps keeps the exact Phase-1 computation
(max available_outgoing_bitrate / 1024) for stats-log parity."
```

---

### Task 4: Reference core — two-step SLD, transceiver flow, virtual hooks

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.h`
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp`

**Interfaces:**
- Consumes: the Task-2/3 host surface.
- Produces: `class ReferenceCallCore` with `virtual ~ReferenceCallCore()`, protected members, and protected virtual hooks with these exact signatures (Task 6/7 depend on them):
  - `virtual std::string mungeLocalDescription(std::string const &type, std::string const &sdp);` (default: returns `sdp` unchanged)
  - `virtual void onStats(json11::Json const &event);` (default: bitrate record + bitrate-based signal bars, as today)
  - `virtual void onIceState(std::string const &state);` (default: connected/failed mapping, as today)

- [ ] **Step 1: Header — hooks, virtual dtor, protected members**

In `ReferenceCallCore.h`, replace the class's `public:`/`private:` skeleton so it reads (member list identical to today, only visibility and additions change):

```cpp
class ReferenceCallCore {
public:
    ReferenceCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit);
    virtual ~ReferenceCallCore() = default;

    void onEvent(json11::Json const &event);

protected:
    // Variant hook points. Defaults reproduce stock behavior exactly;
    // VariantCallCore overrides these (and only these).
    virtual std::string mungeLocalDescription(std::string const &type, std::string const &sdp);
    virtual void onStats(json11::Json const &event);
    virtual void onIceState(std::string const &state);

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
    ... (every existing member from the current header, unchanged, now protected)
};
```

(Copy the member list verbatim from the current file — `_isOutgoing` through `_bitrateRecords`; do not retype from memory.)

- [ ] **Step 2: Core — constructor track add + two-step SLD**

In `ReferenceCallCore.cpp` constructor, replace

```cpp
    this->emit({ {"@type", "pc_add_audio_track"}, {"maxBitrateBps", kAudioMaxBitrateBps} });
```

with

```cpp
    this->emit({
        {"@type", "pc_add_transceiver"},
        {"id", "audio0"},
        {"kind", "audio"},
        {"direction", "sendrecv"},
        {"trackSource", "microphone"},
        {"sendEncodings", json11::Json::array{ json11::Json::object{ {"maxBitrateBps", kAudioMaxBitrateBps} } }},
    });
```

Replace `requestSetLocalDescription()` (whole function) with:

```cpp
void ReferenceCallCore::requestSetLocalDescription() {
    // Stock sendLocalDescription() sets _isMakingOffer before its no-arg SLD
    // (InstanceV2ReferenceImpl.cpp:886); the flag window now also covers the
    // create step, which is strictly safer for collision detection.
    _isMakingOffer = true;
    // Stock's no-arg SLD creates an answer in have-remote-offer and an offer
    // otherwise. _signalingState is current here: OnSignalingChange is posted
    // to the media thread during SRD execution, before the SRD observer's
    // posted completion, so pc_signaling_state always precedes
    // pc_set_remote_done (FIFO).
    const bool asAnswer = (_signalingState == "have-remote-offer" || _signalingState == "have-remote-pranswer");
    emit({ {"@type", asAnswer ? "pc_create_answer" : "pc_create_offer"} });
}
```

In `onEvent`, add a new branch after the `pc_signaling_state` branch:

```cpp
    } else if (type == "pc_description_created") {
        if (event["ok"].bool_value()) {
            const auto descType = stringField(event, "type");
            const auto sdp = mungeLocalDescription(descType, stringField(event, "sdp"));
            emit({ {"@type", "pc_set_local_description"}, {"type", descType}, {"sdp", sdp} });
        } else {
            _isMakingOffer = false;
            emitLog("CreateOffer/CreateAnswer failed: " + stringField(event, "error"));
        }
```

Add the default munge implementation near the other method definitions:

```cpp
std::string ReferenceCallCore::mungeLocalDescription(std::string const &type, std::string const &sdp) {
    (void)type;
    return sdp;
}
```

(`pc_set_local_done` handling stays byte-identical: it clears `_isMakingOffer`, sends the read-back SDP, flushes candidates.)

- [ ] **Step 3: Core — hook dispatch for ice state and stats**

Replace the `pc_ice_state` branch body with a hook dispatch:

```cpp
    } else if (type == "pc_ice_state") {
        onIceState(stringField(event, "state"));
```

and add the default implementation (current logic verbatim):

```cpp
void ReferenceCallCore::onIceState(std::string const &state) {
    bool isConnected = (state == "connected" || state == "completed");
    bool isFailed = (state == "failed");
    if (_isConnected != isConnected || _isFailed != isFailed) {
        updateNetworkState(isConnected, isFailed);
    }
}
```

Replace the `stats` branch body with:

```cpp
    } else if (type == "stats") {
        onStats(event);
```

and add the default implementation (current logic verbatim):

```cpp
void ReferenceCallCore::onStats(json11::Json const &event) {
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
}
```

- [ ] **Step 4: Core — mute/video/timer/track branches**

In the `mute` branch, replace the `pc_set_audio_track_enabled` emit with:

```cpp
            emit({ {"@type", "pc_set_track_enabled"}, {"id", "audio0"}, {"enabled", !muted} });
```

In the `video_capture` branch, replace the remove/add emits with:

```cpp
        if (_hasVideoTrack) {
            emit({ {"@type", "pc_remove_track"}, {"id", "video0"} });
            _hasVideoTrack = false;
        }
        _hasVideoCapture = event["active"].bool_value() && !event["screencast"].bool_value();
        if (_hasVideoCapture) {
            emit({
                {"@type", "pc_add_transceiver"},
                {"id", "video0"},
                {"kind", "video"},
                {"direction", "sendrecv"},
                {"trackSource", "camera"},
                {"codecPreferences", json11::Json::array{ "H265", "H264" }},
                {"sendEncodings", json11::Json::array{ json11::Json::object{ {"maxBitrateBps", kVideoMaxBitrateBps} } }},
            });
            _hasVideoTrack = true;
        }
```

In the `timer` branch, replace `request_stats` with:

```cpp
            emit({ {"@type", "pc_get_stats"} });
```

Add a `pc_track` branch (before the `stop` branch) — the reference policy is: bind the app sink to every incoming video transceiver, matching the old host auto-bind:

```cpp
    } else if (type == "pc_track") {
        if (stringField(event, "kind") == "video") {
            emit({ {"@type", "pc_set_incoming_sink"}, {"mid", stringField(event, "mid")} });
        }
```

(`pc_connection_state` and `pc_gathering_state` need no branches — the unknown-type rule ignores them.)

- [ ] **Step 5: Build + native/wasm validation subset**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo NR1=$?
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet; echo NR2=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet; echo NR3=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM; echo W3=$?
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE; echo W5=$?
```

Expected: all five print `...=0`. If a row fails, use the non-quiet log (the CLI dumps full tgcalls logs on failure) — the `[core]` log lines and `CallCoreHost signaling_send/in` lines show where the flow diverges.

- [ ] **Step 6: Commit (submodule)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/ReferenceCallCore.h tgcalls/v2wasm/ReferenceCallCore.cpp && \
git commit -m "core(v2wasm): adopt PC-projection flow, stock-parity, variant hooks

Two-step SLD (create_offer/answer -> munge point -> explicit SLD; offer vs
answer decided from _signalingState exactly like stock's no-arg SLD),
audio/video via pc_add_transceiver with core-chosen ids audio0/video0,
mute via pc_set_track_enabled, incoming sink bound per pc_track (matches
old host auto-bind), pc_get_stats. Adds protected virtual hooks
mungeLocalDescription/onStats/onIceState with stock-behavior defaults."
```

---

### Task 5: Wire-parity check (P1)

**Files:**
- Create (scratchpad, not committed): `<scratchpad>/p1_diff.py`

**Interfaces:**
- Consumes: the Task-4 CLI binary.
- Produces: a recorded MATCH/DIFF verdict quoted in Task 8's validation table. No repo changes.

The two-step SLD must produce the same offer/answer a stock peer produces. SDP contains per-run random material (session id, ice-ufrag/pwd, DTLS fingerprint, SSRCs), so the comparison strips those lines and diffs the rest (m-lines, codecs, fmtp, extmaps — the negotiation-relevant surface). The pump host logs both directions: `CallCoreHost signaling_send: ` (what the pump sends) and `CallCoreHost signaling in: ` (what the stock peer sent).

- [ ] **Step 1: Capture both directions**

```bash
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
SCRATCH=<scratchpad directory>
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 8 > $SCRATCH/p1_pump_caller.log 2>&1; echo runA=$?
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 8 > $SCRATCH/p1_stock_caller.log 2>&1; echo runB=$?
```

Expected: both `=0`.

- [ ] **Step 2: Write the normalizer/differ**

`$SCRATCH/p1_diff.py`:

```python
import difflib, json, re, sys

def extract(path, marker, wanted_type):
    for line in open(path, errors="replace"):
        idx = line.find(marker)
        if idx < 0:
            continue
        payload = line[idx + len(marker):].strip()
        try:
            message = json.loads(payload)
        except ValueError:
            continue
        if message.get("@type") == wanted_type:
            return message["sdp"]
    raise SystemExit(f"no {wanted_type} found in {path}")

STRIP = re.compile(r"^(o=|a=ice-ufrag|a=ice-pwd|a=fingerprint|a=ssrc|a=msid-semantic|a=candidate)")

def normalize(sdp):
    lines = sdp.replace("\r\n", "\n").split("\n")
    return "\n".join(l for l in lines if l and not STRIP.match(l))

kind = sys.argv[1]  # "offer" or "answer"
if kind == "offer":
    pump = extract(sys.argv[2], "CallCoreHost signaling_send: ", "offer")   # run A: pump is caller
    stock = extract(sys.argv[3], "CallCoreHost signaling in: ", "offer")    # run B: pump receives stock's offer
else:
    pump = extract(sys.argv[3], "CallCoreHost signaling_send: ", "answer")  # run B: pump is callee, answers
    stock = extract(sys.argv[2], "CallCoreHost signaling in: ", "answer")   # run A: stock callee answers
a, b = normalize(pump), normalize(stock)
if a == b:
    print(f"{kind}: MATCH")
else:
    print(f"{kind}: DIFF")
    sys.stdout.writelines(difflib.unified_diff(a.splitlines(True), b.splitlines(True), "pump", "stock"))
    sys.exit(1)
```

- [ ] **Step 3: Run both comparisons**

```bash
python3 $SCRATCH/p1_diff.py offer  $SCRATCH/p1_pump_caller.log $SCRATCH/p1_stock_caller.log
python3 $SCRATCH/p1_diff.py answer $SCRATCH/p1_pump_caller.log $SCRATCH/p1_stock_caller.log
```

Expected: `offer: MATCH` and `answer: MATCH`.

**If DIFF:** a diff confined to line ORDER of a=extmap/codec lines or to `a=msid` stream/track ids indicates a real two-step-SLD regression — fix before proceeding (do not rationalize). A diff in lines the normalizer should have stripped means the normalizer needs that pattern added (e.g. a trailing `a=ssrc-group` line); extend STRIP only for genuinely random material, record the extension in the Task 8 results table.

No commit for this task (nothing in the repo changes); the verdict is recorded in Task 8.

---

### Task 6: Module factory split (reference module)

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CoreFactory.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/reference_core_factory.cpp`
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (parent repo)

**Interfaces:**
- Consumes: `ReferenceCallCore` (virtual dtor from Task 4).
- Produces: `std::unique_ptr<ReferenceCallCore> tgcalls::v2wasm::createModuleCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit)` — one definition per module genrule. Task 7's variant module implements the same symbol.

- [ ] **Step 1: Create `CoreFactory.h`**

```cpp
#ifndef TGCALLS_V2WASM_CORE_FACTORY_H
#define TGCALLS_V2WASM_CORE_FACTORY_H

// Selects which core class a WASM module instantiates. Each module genrule
// compiles wasm_module_entry.cpp plus exactly ONE *_core_factory.cpp
// implementing createModuleCore. WASM discipline: include only core headers,
// json11 and std.

#include <functional>
#include <memory>

#include "third-party/json11.hpp"

#include "v2wasm/ReferenceCallCore.h"

namespace tgcalls {
namespace v2wasm {

std::unique_ptr<ReferenceCallCore> createModuleCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit);

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 2: Create `reference_core_factory.cpp`**

```cpp
// Factory TU for reference-core-abi1.wasm. Compiled ONLY by the
// reference_core_wasm genrule — never in native source lists.

#include "v2wasm/CoreFactory.h"

namespace tgcalls {
namespace v2wasm {

std::unique_ptr<ReferenceCallCore> createModuleCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit) {
    return std::make_unique<ReferenceCallCore>(config, std::move(emit));
}

} // namespace v2wasm
} // namespace tgcalls
```

- [ ] **Step 3: Make the entry generic**

In `wasm_module_entry.cpp`, replace the include of `ReferenceCallCore.h` with `CoreFactory.h`, and change `core_init`'s instantiation:

```cpp
#include "v2wasm/CoreFactory.h"
```

```cpp
namespace {

std::unique_ptr<tgcalls::v2wasm::ReferenceCallCore> globalCore;

} // namespace
```

(unchanged — base-class pointer; Task 4 gave the base a virtual dtor) and in `core_init`:

```cpp
    globalCore = tgcalls::v2wasm::createModuleCore(config, [](json11::Json::object &&command) {
        const std::string serialized = json11::Json(std::move(command)).dump();
        host_emit((const uint8_t *)serialized.data(), serialized.size());
    });
```

- [ ] **Step 4: BUILD — factory in the reference genrule, parametric cmd**

In `submodules/TgVoipWebrtc/BUILD`, replace the `_WASM_CORE_SRCS` list and `_WASM_CORE_CMD` template with:

```python
_WASM_CORE_COMMON_SRCS = [
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.cpp",
    "tgcalls/tgcalls/v2wasm/ReferenceCallCore.h",
    "tgcalls/tgcalls/v2wasm/CallCoreABI.h",
    "tgcalls/tgcalls/v2wasm/CoreFactory.h",
    "tgcalls/tgcalls/v2wasm/wasm_module_entry.cpp",
    "tgcalls/tgcalls/third-party/json11.cpp",
    "tgcalls/tgcalls/third-party/json11.hpp",
]

# {extra_srcs} = per-module factory (+ variant) TUs, one absolute-ish path
# per line ending in " \\".
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
{extra_srcs}    -o $@
"""

_WASM_REFERENCE_EXTRA_SRCS = """    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/reference_core_factory.cpp \\
"""
```

and update the `reference_core_wasm` genrule:

```python
genrule(
    name = "reference_core_wasm",
    srcs = _WASM_CORE_COMMON_SRCS + [
        "tgcalls/tgcalls/v2wasm/reference_core_factory.cpp",
    ] + select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:all_files"],
        "//conditions:default": ["@wasi_sdk_macos//:all_files"],
    }),
    outs = ["reference-core-abi1.wasm"],
    cmd_bash = select({
        "@platforms//os:linux": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_linux", extra_srcs = _WASM_REFERENCE_EXTRA_SRCS),
        "//conditions:default": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_macos", extra_srcs = _WASM_REFERENCE_EXTRA_SRCS),
    }),
    tools = select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:bin/clang++"],
        "//conditions:default": ["@wasi_sdk_macos//:bin/clang++"],
    }),
    visibility = ["//visibility:public"],
)
```

- [ ] **Step 5: Build + reference-module smoke row**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM; echo W3=$?
```

Expected: `W3=0`.

- [ ] **Step 6: Commit (submodule, then parent pin + BUILD)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CoreFactory.h tgcalls/v2wasm/reference_core_factory.cpp tgcalls/v2wasm/wasm_module_entry.cpp && \
git commit -m "wasm(v2wasm): per-module factory seam (createModuleCore)

wasm_module_entry.cpp becomes core-class-agnostic; each module genrule
compiles exactly one *_core_factory.cpp. Prepares the variant module."
cd ../../.. && git add submodules/TgVoipWebrtc/tgcalls submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): factory TU in reference wasm genrule; pin submodule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: VariantCallCore + variant module

**Files:**
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/VariantCallCore.h`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/VariantCallCore.cpp`
- Create: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/variant_core_factory.cpp`
- Modify: `submodules/TgVoipWebrtc/BUILD` (parent repo)
- Modify: `submodules/TgVoipWebrtc/tgcalls/tools/cli/BUILD` (submodule)

**Interfaces:**
- Consumes: Task-4 hooks (`mungeLocalDescription`, `onStats`), protected members (`_isOutgoing`, `_isConnected`, `_hasVideoTrack`, `_nowMs`, `_bitrateRecords`, `BitrateRecord`, `emit`, `emitLog`), Task-6 factory seam.
- Produces: `bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm`. Marker log lines (assertion anchors for Task 8): `variant: core active`, `variant: munge applied (offer|answer)`, `variant: cap <N> kbps`, `variant: ice_restart <N>`.

- [ ] **Step 1: Create `VariantCallCore.h`**

```cpp
#ifndef TGCALLS_V2WASM_VARIANT_CALL_CORE_H
#define TGCALLS_V2WASM_VARIANT_CALL_CORE_H

// Demo variant core: proves call behavior ships as a .wasm only. Deviations
// from the reference core (all interop-safe against stock peers):
//   1. Opus fmtp munge on local descriptions (useinbandfec/usedtx/
//      maxaveragebitrate).
//   2. BWE-driven sender bitrate cap via pc_set_parameters.
//   3. Periodic ICE restart (outgoing side, ~every 7 stats ticks ~= 7 s).
//   4. Signal bars from RTT/loss instead of the bitrate heuristic.
// WASM discipline: include only ReferenceCallCore.h, json11 and C++17 std.
// This .cpp is compiled ONLY by the variant_core_wasm genrule — never in
// native source lists.

#include "v2wasm/ReferenceCallCore.h"

namespace tgcalls {
namespace v2wasm {

class VariantCallCore : public ReferenceCallCore {
public:
    VariantCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit);

protected:
    std::string mungeLocalDescription(std::string const &type, std::string const &sdp) override;
    void onStats(json11::Json const &event) override;

private:
    int _statsTicks = 0;
    int _iceRestarts = 0;
    int _lastCapKbps = 0;
};

} // namespace v2wasm
} // namespace tgcalls

#endif
```

- [ ] **Step 2: Create `VariantCallCore.cpp`**

```cpp
#include "v2wasm/VariantCallCore.h"

#include <algorithm>
#include <cstdlib>
#include <string>

namespace tgcalls {
namespace v2wasm {

namespace {

constexpr int kIceRestartEveryStatsTicks = 7; // stats tick ~= 1 s
constexpr double kCapFractionOfBwe = 0.8;
constexpr int kMinCapKbps = 24;
constexpr int kMaxCapKbps = 1500;

// Append DTX/FEC/bitrate params to the opus fmtp line (CRLF line ends).
// Returns sdp unchanged if opus or its fmtp line is absent.
std::string mungeOpusFmtp(std::string const &sdp) {
    const std::string rtpmapKey = "a=rtpmap:";
    std::string opusPt;
    size_t pos = 0;
    while (pos < sdp.size()) {
        size_t end = sdp.find("\r\n", pos);
        if (end == std::string::npos) {
            end = sdp.size();
        }
        const std::string line = sdp.substr(pos, end - pos);
        if (line.rfind(rtpmapKey, 0) == 0 && line.find(" opus/") != std::string::npos) {
            const size_t space = line.find(' ');
            opusPt = line.substr(rtpmapKey.size(), space - rtpmapKey.size());
            break;
        }
        pos = end + 2;
    }
    if (opusPt.empty()) {
        return sdp;
    }
    const std::string fmtpKey = "a=fmtp:" + opusPt + " ";
    const size_t fmtpPos = sdp.find(fmtpKey);
    if (fmtpPos == std::string::npos) {
        return sdp;
    }
    size_t lineEnd = sdp.find("\r\n", fmtpPos);
    if (lineEnd == std::string::npos) {
        lineEnd = sdp.size();
    }
    const std::string line = sdp.substr(fmtpPos, lineEnd - fmtpPos);
    std::string addition;
    if (line.find("useinbandfec") == std::string::npos) {
        addition += ";useinbandfec=1";
    }
    if (line.find("usedtx") == std::string::npos) {
        addition += ";usedtx=1";
    }
    if (line.find("maxaveragebitrate") == std::string::npos) {
        addition += ";maxaveragebitrate=24000";
    }
    std::string munged = sdp;
    munged.insert(lineEnd, addition);
    return munged;
}

} // namespace

VariantCallCore::VariantCallCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit) :
ReferenceCallCore(config, std::move(emit)) {
    emitLog("variant: core active");
}

std::string VariantCallCore::mungeLocalDescription(std::string const &type, std::string const &sdp) {
    const std::string munged = mungeOpusFmtp(sdp);
    if (munged != sdp) {
        emitLog("variant: munge applied (" + type + ")");
    }
    return munged;
}

void VariantCallCore::onStats(json11::Json const &event) {
    // Keep the reference bitrate record so the stats log stays well-formed.
    BitrateRecord record;
    record.timestampMs = _nowMs;
    record.bitrateKbps = (int32_t)event["sendBitrateKbps"].number_value();
    _bitrateRecords.push_back(record);

    // Signal bars from RTT/loss instead of the bitrate heuristic.
    const auto &transport = event["transport"];
    const double rttMs = transport["rttMs"].is_number() ? transport["rttMs"].number_value() : -1.0;
    const auto &audioSend = event["audio"]["send"];
    const double lossFraction = audioSend["remoteLossFraction"].is_number() ? audioSend["remoteLossFraction"].number_value() : -1.0;
    int bars = 4;
    if (rttMs > 400.0) {
        bars -= 2;
    } else if (rttMs > 150.0) {
        bars -= 1;
    }
    if (lossFraction > 0.1) {
        bars -= 2;
    } else if (lossFraction > 0.02) {
        bars -= 1;
    }
    bars = std::max(0, std::min(4, bars));
    emit({ {"@type", "emit_signal_bars"}, {"bars", bars} });

    // BWE-driven sender cap: 80% of available outgoing bitrate, clamped;
    // re-emitted only on >10% change to avoid SetParameters spam.
    if (transport["availableOutgoingKbps"].is_number()) {
        int capKbps = (int)(transport["availableOutgoingKbps"].number_value() * kCapFractionOfBwe);
        capKbps = std::max(kMinCapKbps, std::min(kMaxCapKbps, capKbps));
        if (_lastCapKbps == 0 || std::abs(capKbps - _lastCapKbps) * 10 > _lastCapKbps) {
            _lastCapKbps = capKbps;
            const int audioCapBps = std::min(capKbps * 1024, 32 * 1024);
            emit({
                {"@type", "pc_set_parameters"},
                {"id", "audio0"},
                {"encodings", json11::Json::array{ json11::Json::object{ {"maxBitrateBps", audioCapBps} } }},
            });
            if (_hasVideoTrack) {
                emit({
                    {"@type", "pc_set_parameters"},
                    {"id", "video0"},
                    {"encodings", json11::Json::array{ json11::Json::object{ {"maxBitrateBps", capKbps * 1024} } }},
                });
            }
            emitLog("variant: cap " + std::to_string(capKbps) + " kbps");
        }
    }

    // Periodic ICE restart: outgoing side only (keeps variant-vs-variant runs
    // to one restarter), once connected. Recovery flows through the normal
    // perfect-negotiation offer path.
    _statsTicks += 1;
    if (_isOutgoing && _isConnected && _statsTicks % kIceRestartEveryStatsTicks == 0) {
        _iceRestarts += 1;
        emit({ {"@type", "pc_restart_ice"} });
        emitLog("variant: ice_restart " + std::to_string(_iceRestarts));
    }
}

} // namespace v2wasm
} // namespace tgcalls
```

- [ ] **Step 3: Create `variant_core_factory.cpp`**

```cpp
// Factory TU for variant-core-abi1.wasm. Compiled ONLY by the
// variant_core_wasm genrule — never in native source lists.

#include "v2wasm/CoreFactory.h"
#include "v2wasm/VariantCallCore.h"

namespace tgcalls {
namespace v2wasm {

std::unique_ptr<ReferenceCallCore> createModuleCore(json11::Json const &config, std::function<void(json11::Json::object &&)> emit) {
    return std::make_unique<VariantCallCore>(config, std::move(emit));
}

} // namespace v2wasm
} // namespace tgcalls
```

- [ ] **Step 4: BUILD — variant genrule + CLI data dep**

In `submodules/TgVoipWebrtc/BUILD`, after `_WASM_REFERENCE_EXTRA_SRCS`, add:

```python
_WASM_VARIANT_EXTRA_SRCS = """    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/VariantCallCore.cpp \\
    submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/variant_core_factory.cpp \\
"""
```

and after the `reference_core_wasm` genrule, add:

```python
genrule(
    name = "variant_core_wasm",
    srcs = _WASM_CORE_COMMON_SRCS + [
        "tgcalls/tgcalls/v2wasm/VariantCallCore.cpp",
        "tgcalls/tgcalls/v2wasm/VariantCallCore.h",
        "tgcalls/tgcalls/v2wasm/variant_core_factory.cpp",
    ] + select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:all_files"],
        "//conditions:default": ["@wasi_sdk_macos//:all_files"],
    }),
    outs = ["variant-core-abi1.wasm"],
    cmd_bash = select({
        "@platforms//os:linux": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_linux", extra_srcs = _WASM_VARIANT_EXTRA_SRCS),
        "//conditions:default": _WASM_CORE_CMD.format(sdk = "@wasi_sdk_macos", extra_srcs = _WASM_VARIANT_EXTRA_SRCS),
    }),
    tools = select({
        "@platforms//os:linux": ["@wasi_sdk_linux//:bin/clang++"],
        "//conditions:default": ["@wasi_sdk_macos//:bin/clang++"],
    }),
    visibility = ["//visibility:public"],
)
```

In `submodules/TgVoipWebrtc/tgcalls/tools/cli/BUILD`, change the `data` attribute:

```python
    data = [
        "//submodules/TgVoipWebrtc:reference_core_wasm",
        "//submodules/TgVoipWebrtc:variant_core_wasm",
    ],
```

Do NOT add any of the new `.cpp` files to `tgcalls_core` (~line 167) or the `objc_library` list (~line 306).

- [ ] **Step 5: Build + variant smoke row**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
ls -la bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
SCRATCH=<scratchpad directory>
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 20 --wasm-core $VARIANT --wasm-core2 NONE > $SCRATCH/v1_smoke.log 2>&1; echo V1=$?
grep -c "variant: core active" $SCRATCH/v1_smoke.log
grep -c "variant: munge applied" $SCRATCH/v1_smoke.log
grep -c "variant: cap" $SCRATCH/v1_smoke.log
grep -c "variant: ice_restart" $SCRATCH/v1_smoke.log
```

Expected: `V1=0`; `core active` ≥ 1; `munge applied` ≥ 1; `cap` ≥ 1; `ice_restart` ≥ 2 (20 s at ~7 s cadence).

- [ ] **Step 6: Commit (submodule, then parent)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/VariantCallCore.h tgcalls/v2wasm/VariantCallCore.cpp tgcalls/v2wasm/variant_core_factory.cpp tools/cli/BUILD && \
git commit -m "wasm(v2wasm): VariantCallCore demo module

Derives from ReferenceCallCore via the hook seam: Opus DTX/FEC/bitrate
fmtp munge, BWE-driven sender caps (pc_set_parameters), periodic ICE
restart (outgoing side), RTT/loss signal bars. Ships only as
variant-core-abi1.wasm — no native source list changes."
cd ../../.. && git add submodules/TgVoipWebrtc/tgcalls submodules/TgVoipWebrtc/BUILD && \
git commit -m "build(tgcalls): variant_core_wasm genrule; pin submodule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Full validation matrix, iOS build-proof, docs

**Files:**
- Modify: `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CLAUDE.md`
- Modify: `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` (project-structure line for `v2wasm/`)
- Modify: `docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md` (parent — append validation results)

**Interfaces:**
- Consumes: everything.
- Produces: the recorded pass/fail table; updated docs.

- [ ] **Step 1: Full parity matrix (W1–W8 + NR1–NR3)**

```bash
./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli
CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli
WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE; echo W1=$?
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet --wasm-core2 $WASM; echo W2=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM; echo W3=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM --wasm-core2 NONE; echo W4=$?
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE; echo W5=$?
# W6 remains an honest skip (run-local-test.sh cannot forward --wasm-core).
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet --wasm-core $WASM --wasm-core2 NONE; echo W7=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --quiet --wasm-core $WASM; echo W8=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet; echo NR1=$?
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet; echo NR2=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet; echo NR3=$?
```

Expected: every row `=0`.

- [ ] **Step 2: Variant matrix (V1–V4)**

```bash
VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm
SCRATCH=<scratchpad directory>
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 20 --wasm-core $VARIANT --wasm-core2 NONE > $SCRATCH/v1.log 2>&1; echo V1=$?
$CLI --mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 15 --wasm-core2 $VARIANT > $SCRATCH/v2.log 2>&1; echo V2=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 20 --wasm-core $VARIANT > $SCRATCH/v3.log 2>&1; echo V3=$?
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $VARIANT --wasm-core2 NONE > $SCRATCH/v4.log 2>&1; echo V4=$?
for f in v1 v3 v4; do echo "$f: restarts=$(grep -c 'variant: ice_restart' $SCRATCH/$f.log) munge=$(grep -c 'variant: munge applied' $SCRATCH/$f.log) cap=$(grep -c 'variant: cap' $SCRATCH/$f.log)"; done
echo "v2: munge=$(grep -c 'variant: munge applied' $SCRATCH/v2.log) cap=$(grep -c 'variant: cap' $SCRATCH/v2.log) restarts=$(grep -c 'variant: ice_restart' $SCRATCH/v2.log)"
```

Expected: all four exit 0. V1/V3/V4: restarts ≥ 2, munge ≥ 1, cap ≥ 1. V2 (variant is the callee = not outgoing): munge ≥ 1 (answer side), cap ≥ 1, restarts = 0 by design.

- [ ] **Step 3: iOS build-proof**

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache \
 build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Expected: `Build completed successfully`.

- [ ] **Step 4: Update docs**

`tgcalls/tgcalls/v2wasm/CLAUDE.md`:
- Files table: describe `CallCoreABI.h` as the PC-projection contract; add rows for `CoreFactory.h` + `reference_core_factory.cpp` / `variant_core_factory.cpp` ("per-module factory TUs, wasm-only") and `VariantCallCore.{h,cpp}` ("demo variant core, ships only as `variant-core-abi1.wasm`").
- Building section: add `variant-core-abi1.wasm` output path and one example run with `--wasm-core $VARIANT`.
- Invariants: extend the core-discipline bullet to name the new wasm-only files; add a bullet: "The reference core is the parity baseline — behavior experiments go in variant cores, never in `ReferenceCallCore`."
- Status line: Phase 2.5 (PC-projection ABI + variant module) complete and CLI-validated.

`tgcalls/CLAUDE.md` (testbench): in the project-structure `v2wasm/` line, mention the PC-projection ABI and the second `variant-core-abi1.wasm` module.

Spec (`docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md`): append a `## Validation results (Phase 2.5)` section with the W/NR/V/P1 tables (commands, exit codes, marker counts, P1 verdict incl. any STRIP extensions), the iOS build result, and fixes-applied count.

- [ ] **Step 5: Commit (submodule docs, then parent docs + pin)**

```bash
cd submodules/TgVoipWebrtc/tgcalls && git add tgcalls/v2wasm/CLAUDE.md CLAUDE.md && \
git commit -m "docs(v2wasm): PC-projection ABI + variant module docs"
cd ../../.. && git add submodules/TgVoipWebrtc/tgcalls docs/superpowers/specs/2026-07-02-tgcalls-wasm-core-pc-abi-design.md && \
git commit -m "docs(tgcalls): Phase-2.5 validation results; pin submodule

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** ABI rewrite → Task 1; host executors/events → Task 2; rich stats → Task 3; reference-core parity + hooks → Task 4; P1 wire diff → Task 5; factory/packaging → Task 6; variant module + V-rows → Tasks 7–8; W-matrix/NR re-run + iOS build + docs → Task 8. Spec's "three protected virtual hooks" = `mungeLocalDescription`/`onStats`/`onIceState` (Task 4) — the variant's ICE-restart cadence rides `onStats` ticks, so no fourth hook was needed.
- **Break-in-place window:** Tasks 2–3 compile but cannot pass CLI runs (core still speaks the old commands). This is deliberate; the Task-4 gate restores green. Do not run the matrix between Tasks 2 and 4.
- **Type consistency spot-checks:** `executeGetStats` (Task 2 decl = Task 3 impl); `createModuleCore` signature identical in Tasks 6 and 7; hook signatures identical in Tasks 4 and 7; marker strings identical in Tasks 7 and 8; `pc_get_stats`/`pc_set_incoming_sink`/`pc_track` names identical in Tasks 1, 2, and 4.
- **Known risk registers (watch during Tasks 4–5):** offer-vs-answer decision relies on `pc_signaling_state` preceding `pc_set_remote_done` (both PostTask'd FIFO from the same SRD execution — argued in code comment); P1 diff may need STRIP extensions for genuinely random SDP lines (record any); V-row ICE restarts against stock exercise perfect-negotiation under restart — if V3 flaps, reduce restart cadence in the VARIANT only (that's the point of the variant).
