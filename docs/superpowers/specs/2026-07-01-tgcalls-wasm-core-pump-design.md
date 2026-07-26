# tgcalls WASM-core Phase 1: pump-boundary sketch (design)

Date: 2026-07-01
Status: approved (design review in session), Phase 1 of 4
Scope: `submodules/TgVoipWebrtc/tgcalls` (+ one parent-repo `BUILD` edit)

## Context

Long-term goal: refactor `InstanceV2ReferenceImpl` into a runtime-injectable WASM
"call core" driven by a fixed native harness that owns audio, PeerConnection, and
signaling crypto — so call-control logic variants can be A/B-tested on a live
audience. `InstanceV2ReferenceImpl` is the right candidate because it is the only
1:1 impl that talks to WebRTC exclusively through `PeerConnectionInterface` (the
W3C seam browsers already use to separate hot-swappable logic from the media
engine). `InstanceV2Impl` reaches into `cricket::*` internals and is not bindable
this way.

Phase 1 (this sketch) proves the boundary **without any WASM**: the control logic
is rebuilt as a message-pump "core" compiled natively under WASM discipline, and
validated by real calls in `tgcalls_cli` against the stock impl.

Later phases (out of scope here): compile the core to WASM (WASI SDK) + embed
WAMR; iOS integration behind a flag with embedded modules; signed remote module
delivery for beta/Android.

## Goal / success criteria

A new `InstanceV2PumpImpl`, wire-compatible with stock `InstanceV2ReferenceImpl`
versions `10.0.0`/`11.0.0`, whose control logic lives behind a C ABI and
communicates only via JSON byte buffers. Done when:

1. `tgcalls_cli --mode p2p --version 11.0.0-pump --version2 11.0.0` passes
   (call established, stats non-empty, BWE non-zero both sides) — plus the
   reversed direction and pump↔pump.
2. Same passes with `--drop-rate 0.3 --delay 50-200`.
3. `10.0.0-pump` (V1 signaling / `ExternalSignalingConnection` path) passes p2p.
4. Stretch: `run-local-test.sh -n 50` with pump caller version.

## Non-goals (Phase 1)

- No WASM runtime, no WAMR, no module loading.
- No video-call codepath validation beyond compiling (CLI p2p mode is audio; the
  video command surface is specified and implemented but exercised only by
  audio-call negotiation).
- No changes to stock `InstanceV2ReferenceImpl`, no iOS app integration.
- No group calls, no `InstanceV2CompatImpl` port.

## Architecture

New directory `tgcalls/tgcalls/v2wasm/` (will later also hold the WASM host):

```
┌────────────────────────── InstanceV2PumpImpl ────────────────────────────┐
│  Instance subclass, ThreadLocalObject wrapper (mirrors stock)            │
│  versions: "10.0.0-pump", "11.0.0-pump"  (wire = 10.0.0 / 11.0.0)        │
│                                                                          │
│  ┌── CallCoreHost (fixed harness) ──┐      ┌── ReferenceCallCore ──┐     │
│  │ PeerConnectionFactory/PC, ADM,   │ ───► │ control logic under   │     │
│  │ EncryptedConnection, SCTP/Ext    │events│ WASM discipline: only │     │
│  │ signaling, gzip, ReflectorRelay- │      │ CallCoreABI.h + json11│     │
│  │ PortFactory, video sink wiring,  │ ◄─── │ + std. No webrtc/     │     │
│  │ timers, GetStats                 │ cmds │ tgcalls includes.     │     │
│  └──────────────────────────────────┘      └───────────────────────┘     │
└──────────────────────── CallCoreABI.h (the frozen seam) ─────────────────┘
```

### Files

| File | Role |
|---|---|
| `v2wasm/CallCoreABI.h` | `extern "C"` seam + full JSON schema doc comments |
| `v2wasm/ReferenceCallCore.h/.cpp` | ported control logic (core side) |
| `v2wasm/CallCoreHost.h/.cpp` | harness: executes commands, forwards events |
| `v2wasm/InstanceV2PumpImpl.h/.cpp` | `Instance` impl wiring host+core, registration |

## The ABI (`CallCoreABI.h`)

Mirrors future WASM exports/imports exactly:

```c
typedef void (*TgcallsCoreEmitFn)(void *userData, const uint8_t *data, size_t len);

typedef struct TgcallsCallCore TgcallsCallCore;   // opaque

TgcallsCallCore *tgcalls_core_create(const char *configJson,
                                     TgcallsCoreEmitFn emit, void *userData);
void tgcalls_core_on_event(TgcallsCallCore *core, const uint8_t *data, size_t len);
void tgcalls_core_destroy(TgcallsCallCore *core);
```

- All payloads are JSON objects with a `"@type"` tag (matches the signaling
  protocol's own convention).
- **Extensibility rules (documented in the header):** the core MUST ignore
  unknown event types; the host MUST answer unknown/malformed commands with an
  `error` event and MUST NOT crash. ABI versioned by `abiVersion` int in config;
  core echoes it in a `core_ready` command so the host can refuse a mismatch.
- **Reentrancy rule:** `emit` may be called only from within
  `tgcalls_core_create`/`tgcalls_core_on_event` on the same thread. The host
  queues emitted commands and executes them **after** the core call returns;
  async results are delivered as later events. The core never blocks.
- **Memory rule:** buffers passed to the core are valid only for the duration of
  the call; buffers passed to `emit` are valid only for the duration of the
  callback (each side copies). This is exactly the WASM linear-memory contract.
- **Clock rule:** every event carries "nowMs" (host monotonic ms) — the core has no clock; it timestamps its stats-log records from the latest event.

### Core config (`tgcalls_core_create`)

```json
{
  "abiVersion": 1,
  "wireVersion": "11.0.0",          // "-pump" suffix stripped by host
  "isOutgoing": true,
  "enableP2P": true,
  "rtcServers": [ {"host":"…","port":1,"login":"…","password":"…","isTurn":true,"isTcp":false} ],
  "customParameters": "{...}"        // Descriptor.config.customParameters, verbatim
}
```

No key material, ever. The host owns `EncryptionKey`/`EncryptedConnection`;
DTLS/SRTP stay inside PeerConnection.

### Events (host → core), `"@type"` values

| Event | Payload | Source in host |
|---|---|---|
| `signaling_message` | `data` (string; plaintext JSON, already decrypted + gunzipped) | SCTP/External signaling → EncryptedConnection |
| `pc_renegotiation_needed` | — | `PeerConnectionObserver::OnRenegotiationNeeded` |
| `pc_ice_candidate` | `mid`, `mline`, `sdp` | `OnIceCandidate` |
| `pc_ice_state` | `state`: `connected`\|`completed`\|`failed`\|`disconnected`\|`new`\|`checking`\|`closed` | `OnIceConnectionChange` |
| `pc_candidate_pair_changed` | `local{type,protocol,address}`, `remote{…}` | `OnIceSelectedCandidatePairChanged` |
| `pc_signaling_state` | `state`: `stable`\|`have-local-offer`\|`have-remote-offer`\|`have-local-pranswer`\|`have-remote-pranswer`\|`closed` | `OnSignalingChange` (core needs it for the perfect-negotiation `isReadyForOffer` check, which stock reads synchronously from `signaling_state()`) |
| `pc_set_local_done` | `ok`, `type`, `sdp` (local description after SLD) | SLD observer |
| `pc_set_remote_done` | `ok`, `sdpType` (the remote type just applied) | SRD observer |
| `dc_state` | `open` (bool) | DataChannelObserver state change |
| `dc_message` | `data` (string; text messages only) | DataChannelObserver message |
| `timer` | `token` (int) | fired `set_timer` |
| `stats` | `sendBitrateKbps` | async `GetStats` completion |
| `mute` | `muted` (bool) | `Instance::setMuteMicrophone` |
| `battery_low` | `low` (bool) | `Instance::setIsLowBatteryLevel` |
| `video_capture` | `active` (bool), `screencast` (bool) | `Instance::setVideoCapture` |
| `stop` | — | `Instance::stop` (core replies with final `stats_log` + `close`) |
| `error` | `message`, `command` (echo) | host command validation |

### Commands (core → host), `"@type"` values

| Command | Payload | Host action |
|---|---|---|
| `core_ready` | `abiVersion` | version check |
| `pc_create` | `iceTransportsType`: `all`\|`relay`; `iceServers` (mapped STUN/TURN url list) | create PC with stock RTCConfiguration constants (bundle/rtcp-mux/renomination etc. fixed host-side in Phase 1) |
| `pc_set_local_description` | — | modern no-arg SLD; completion → `pc_set_local_done` |
| `pc_set_remote_description` | `sdpType`, `sdp` | SRD; completion → `pc_set_remote_done` |
| `pc_add_ice_candidate` | `mid`, `mline`, `sdp` | `AddIceCandidate` |
| `pc_add_audio_track` | `maxBitrateBps` | CreateAudioSource/Track + AddTransceiver + SetParameters |
| `pc_add_video_track` | `codecPreferences` (ordered names), `maxBitrateBps` | video track from current capture + capability merge + SetCodecPreferences + SetParameters |
| `pc_remove_video_track` | — | RemoveTrackOrError + drop track refs |
| `pc_set_audio_track_enabled` | `enabled` | `AudioTrack::set_enabled` (mute) |
| `pc_create_data_channel` | — | CreateDataChannelOrError("data") + observer |
| `dc_send` | `data` (string) | `DataChannel::Send` (text) |
| `signaling_send` | `data` (string; plaintext JSON) | gzip (V2 only) → encrypt → signaling connection |
| `set_timer` | `token`, `delayMs` | `PostDelayedTask` → `timer` event |
| `request_stats` | — | async `GetStats` → `stats` event |
| `emit_state` | `state`: `established`\|`failed`\|`reconnecting` | `Descriptor.stateUpdated` |
| `emit_signal_bars` | `bars` (0–4) | `Descriptor.signalBarsUpdated` |
| `emit_remote_media_state` | `audio`: `active`\|`muted`; `video`: `inactive`\|`paused`\|`active` | `Descriptor.remoteMediaStateUpdated` |
| `emit_remote_battery_low` | `low` (bool) | `Descriptor.remoteBatteryLevelIsLowUpdated` |
| `log` | `message` | `RTC_LOG(LS_INFO)` |
| `stats_log` | `json` (string) | buffered; written to `statsLogPath` at stop |
| `close` | — | `PeerConnection::Close`; after `stop` event this completes `Instance::stop` |

Granularity rationale: commands are **intent-level** where the WebRTC call needs
factory access (track creation, capability merge), **SDP-level** where the
experimentation value lives (descriptions, candidates, timing, policy). Incoming
video **sink wiring is host-only** (policy-free plumbing; `OnTrack` bookkeeping
stays native); no track events cross the boundary in Phase 1.

## Component specs

### ReferenceCallCore (the port)

State machine ported 1:1 from `InstanceV2ReferenceImplInternal`:
perfect negotiation (`_isMakingOffer`, `_isSettingRemoteAnswerPending`, polite =
`!isOutgoing`, offer-collision ignore), pending-ICE buffering until both
descriptions set, `{"@type": offer|answer|candidate}` messages, MediaState
handling, mute/battery propagation, signal-bars heuristic
(`sendBitrateKbps / (video ? 600 : 16)`, clamped, ×4), 1 s stats cadence via
`set_timer`/`request_stats`, network/bitrate log records serialized into the
final `stats_log` JSON (same shape as stock, `"v": 3`).

Wire-format duty: byte-identical signaling to stock. The `MediaStateMessage` /
`CandidatesMessage` JSON serialization is ported into the core (the core cannot
include `v2/Signaling.h`); parity is asserted by the interop tests (stock side
must parse everything the core sends and vice versa).

Allowed includes: `CallCoreABI.h`, vendored `third-party/json11.hpp`, C++17 std.
Nothing else — this is the WASM-compilability guarantee, enforced by review in
Phase 1 and by the WASI build in Phase 2.

### CallCoreHost

Owns everything platform/webrtc: PeerConnectionFactory deps (ADM via
`Descriptor.createAudioDeviceModule` fallback chain, platform video
encoder/decoder factories, network monitor), `BasicPortAllocator` +
`ReflectorRelayPortFactory(rtcServers)`, `EncryptedConnection(Signaling, key)`,
`SignalingSctpConnection` (V2) / `ExternalSignalingConnection` (V1), gzip
normalization, data-channel plumbing, incoming-video transceiver map + sink
wiring, timer service, async `GetStats` (standard API — deliberately replacing
stock's `PeerConnectionProxy…::call_ptr()` reach-in, which had a documented
use-after-free), stats-log file write at stop.

Runs entirely on the media thread (observer callbacks `PostTask`'d, mirroring
stock). Field-trial init stays host-side (process-wide).

### InstanceV2PumpImpl

Mirrors stock's shell: `ThreadLocalObject<…Internal>` on the media thread,
`LogSinkImpl`, `GetVersions() = {"10.0.0-pump", "11.0.0-pump"}`,
`GetConnectionMaxLayer() = 92`. `Instance` setters forward as events; `stop()`
sends `stop`, awaits `close` + `stats_log`, fills `FinalState.debugLog` from the
log sink. Video-capture object handles (`VideoCaptureInterface`) are held
host-side; the core only learns `active`/`screencast` booleans.

## Data flow (outgoing call, V2 signaling)

1. `tgcalls_core_create(config)` → core emits `core_ready`, `pc_create`,
   `pc_create_data_channel` (outgoing only), `pc_add_audio_track{32768}`,
   `set_timer{statsToken, 1000}`.
2. Host builds PC → `OnRenegotiationNeeded` → event → core (negotiation begun,
   isOutgoing) emits `pc_set_local_description`.
3. SLD completes → `pc_set_local_done{type:"offer", sdp}` → core emits
   `signaling_send{{"@type":"offer","sdp":…}}` → host gzip+encrypt → SCTP.
4. Remote answer arrives → decrypt+gunzip → `signaling_message` → core validates
   against negotiation state → `pc_set_remote_description{answer}` →
   `pc_set_remote_done` → core flushes buffered `pc_add_ice_candidate`s.
5. ICE candidates flow both ways (`pc_ice_candidate` → `signaling_send`;
   `signaling_message{candidate}` → buffer or `pc_add_ice_candidate`).
6. `pc_ice_state{connected}` → core emits `emit_state{established}`; data channel
   opens → core sends MediaState over `dc_send`.
7. `timer{statsToken}` → `request_stats` → `stats` → `emit_signal_bars` + bitrate
   log record → re-arm timer.
8. `stop` → core emits final `stats_log{json}` + `close` → host writes file,
   closes PC, completes with `FinalState`.

Incoming call mirrors 2–4 with polite-peer collision rules identical to stock.

## Error handling

- Core: unparseable JSON / unknown `"@type"` → `log` command + drop (stock
  behavior is RTC_LOG + return). Never trap/abort on input.
- Host: malformed/unknown command → `error` event (echoing the command) + drop.
  Command execution failures (e.g. `CreatePeerConnectionOrError` fails) →
  `error` event; core maps fatal ones to `emit_state{failed}`.
- Ordering: single-threaded media-thread delivery; queued-command rule (above)
  makes the event/command interleaving deterministic and replayable.

## Build & registration changes

- `submodules/TgVoipWebrtc/BUILD` (parent repo): add the three new `.cpp` files
  to both source lists that currently contain `InstanceV2ReferenceImpl.cpp`
  (`tgcalls_core` C++ target and the iOS objc target).
- `tgcalls/tools/cli/main.cpp` (submodule): add
  `tgcalls::Register<tgcalls::InstanceV2PumpImpl>();` next to the existing
  registrations. `--version`/`--version2` already pass arbitrary strings to
  `Meta::Create`, so `11.0.0-pump` needs no further CLI change.

## Testing

Build: `./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
from the worktree root (cold build is expensive; done once, then incremental).

Matrix (all `--mode p2p --duration 10 --quiet`, exit code 0 = pass):

| # | caller | callee | extra |
|---|---|---|---|
| 1 | 11.0.0-pump | 11.0.0 | — |
| 2 | 11.0.0 | 11.0.0-pump | — |
| 3 | 11.0.0-pump | 11.0.0-pump | — |
| 4 | 11.0.0-pump | 11.0.0 | `--drop-rate 0.3 --delay 50-200 --duration 30` |
| 5 | 10.0.0-pump | 10.0.0 | — |
| 6 | stretch | | `run-local-test.sh -n 50 --version 11.0.0-pump` |

## Risks / open items

- **Wire parity of ported serializers** — covered by the interop matrix (stock
  parses core output and vice versa); any drift fails the call.
- **CLI `Descriptor` differences** (e.g. CLI supplies `FakeAudioDeviceModule`
  via `createAudioDeviceModule`) — host honors the same fallback chain as stock.
- **`10.0.0` V1 signaling** uses `EncryptedConnection::prepareForSendingRawMessage`
  service-packet machinery (delayed resend closure) — stays host-side; verify the
  V1 path with test #5 rather than assuming.
- **Video path untestable in CLI p2p** (audio-only): commands implemented but
  runtime-unverified until a video-capable rig exists; flagged for Phase 2.
- Duplicated host plumbing (~1k lines vs stock) is accepted Phase-1 debt; stock
  is replaced (not deduped) in a later phase.

## Phasing recap

1. **This sketch:** native pump boundary, CLI-validated.
2. Compile core with WASI SDK → `.wasm`; embed WAMR (iOS-compatible interpreter);
   wasmtime in CI; identical test matrix.
3. iOS app integration behind experimental flag; embedded modules;
   server-flag selection (App Store 2.5.2-compliant A/B).
4. Signed remote module delivery (TestFlight/Android); dynamic `Meta::versions()`
   from module registry; kill-switch + native fallback.

## Validation results

Run 2026-07-02, binary built via
`./build-input/bazel-8.4.2-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
(tgcalls submodule commit `bdfa8c9`, tasks 1–4 tip). All 6 matrix rows passed
on the first attempt — no core/harness fixes were required; the interop
matrix confirms wire parity with stock `InstanceV2ReferenceImpl` for both the
V1 (10.0.0) and V2 (11.0.0) signaling paths.

| # | command | exit | established | notes |
|---|---|---|---|---|
| 1 | `--mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 10 --quiet` | 0 | yes (0.020s) | caller Established / callee Reconnecting — matches stock↔stock 11.0.0/11.0.0 baseline pattern (also Reconnecting/Reconnecting), not a pump regression |
| 2 | `--mode p2p --version 11.0.0 --version2 11.0.0-pump --duration 10 --quiet` | 0 | yes (0.012s) | caller Reconnecting / callee Established (polite-peer/answerer path) |
| 3 | `--mode p2p --version 11.0.0-pump --version2 11.0.0-pump --duration 10 --quiet` | 0 | yes (0.014s) | both sides Established |
| 4 | `--mode p2p --version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --quiet` | 0 | yes (1.183s) | caller Established / callee Reconnecting; BWE non-zero under 30% loss |
| 5 | `--mode p2p --version 10.0.0-pump --version2 10.0.0 --duration 10 --quiet` | 0 | yes (0.010s) | V1 signaling path (ExternalSignalingConnection, no gzip) |
| 6 | `run-local-test.sh -n 50 -j 25 --version 11.0.0-pump` | 0 | 50/50 (100%) | symmetric pump↔pump mass test, default 30% drop / 50-200ms delay / 15s duration, 31s wall time; script has no `--version2` flag so asymmetric mass-testing wasn't attempted — the 5 single-run rows above cover asymmetric interop |

All runs additionally reported `Stats log: ... bitrate records`, `BWE non-zero: yes`,
and `Errors: none`. The stock↔stock 11.0.0/11.0.0 baseline run used for
row-1/row-4 comparison also showed both sides settle to "Reconnecting" by the
end of a short loopback run, confirming that label is a CLI/ICE-loopback
artifact rather than a pump-vs-stock divergence.
A second contributor: stock's `stop()` → `Close()` synchronously fires a final
`OnIceConnectionChange(kClosed)` → `stateUpdated(Reconnecting)` during teardown,
while the pump host defers that event mid-drain and drops it via `_isStopped` —
so pump sides can end the run still labeled "Established" where stock sides
flip to "Reconnecting"; neither label affects the pass criteria.

Fixes applied: **0**. No wire-format, ABI, or harness changes were needed;
the submodule working tree was clean before and after the matrix run. The
parent repo's gitlink pin for `submodules/TgVoipWebrtc/tgcalls` (previously
at `2caf643`, the pre-Task-1 tip) was updated to `bdfa8c9` and committed.

## Phase 2 backlog (from final branch review, 2026-07-02)

- ABI truthfulness: host only logs an `abiVersion` mismatch; header says "refuse" —
  implement refusal (stop pumping, `emit_state failed`) or soften the header text
  before the ABI freezes.
- ICE URL building in the core: add IPv6 bracketing + host validation (stock uses
  `SocketAddress::IsComplete()` + `HostAsURIString()`); required before production
  rtcServers use.
- `stop()` hardening: assert the media-thread invariant
  (`RTC_DCHECK(!_isDeliveringEvent && !_isProcessingCommands)`) and guard double-stop
  (second completion currently dropped).
- Comment the intentional error-path deviations from stock (SLD send-on-failure,
  SRD flush-on-failure) and the deferred-delivery ordering invariant on
  `deliverEvent`; consider stock's `PostTask` wrap for `OnRenegotiationNeeded` as
  defense-in-depth.
- Add a `v2wasm/` entry to the tgcalls testbench CLAUDE.md project-structure list.
