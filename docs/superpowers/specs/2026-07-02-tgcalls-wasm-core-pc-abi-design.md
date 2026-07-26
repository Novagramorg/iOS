# tgcalls WASM-core Phase 2.5: PeerConnection-projection ABI (design)

Date: 2026-07-02
Status: approved (design review in session), interstitial phase between
Phase 2 (WASM module + WAMR) and Phase 3 (iOS integration).
Depends on: Phase 2 (`2026-07-02-tgcalls-wasm-core-phase2-design.md`),
complete and validated on this branch.

## Context

Phases 1–2 proved the pump boundary: `ReferenceCallCore` drives `CallCoreHost`
through a C/WASM ABI and interoperates wire-compatibly with stock
`InstanceV2ReferenceImpl`, natively and as a WAMR-loaded module. But the ABI
surface was shaped by "port stock behavior 1:1", so several genuinely
policy-shaped decisions are still hard-coded in the host:

- **SDP content** — the core triggers a no-arg SetLocalDescription but never
  sees the offer before it is applied. Codec ordering, Opus fmtp
  (DTX/FEC/bitrate), extension stripping are unreachable from a core.
- **Encoding parameters** — track bitrate caps are one-shot numbers at
  track-add; no way to run an adaptive-quality loop.
- **Stats** — the `stats` event carries only `sendBitrateKbps`; no RTT, loss,
  jitter or BWE, so a core cannot sense network quality.
- **Recovery policy** — no ICE-restart command; reconnection is whatever
  PeerConnection does on its own.
- **Incoming media routing** — the host auto-binds the app's video sink to
  the first incoming video transceiver.

Decision (session, 2026-07-02): rewrite ABI v1 **in place** — nothing has
shipped beyond this branch, so no compatibility path is carried. `abiVersion`
stays `1`; this contract becomes the true v1. The Phase-2 validation records
remain as history; the full matrix re-runs against the new surface.

## Goal / success criteria

Reshape the ABI as a **PeerConnection projection**: the core drives the
host's PeerConnection through JSON commands that mirror the WebRTC-native PC
API, cut at the depth where performance says stop. A wasm core can then own
SDP policy, codec/fmtp choices, encoding parameters, adaptive quality, and
reconnection strategy — shipped as a `.wasm` file only. Done when:

1. `CallCoreABI.h` documents the new contract; host + reference core + module
   build from clean via the existing targets.
2. **Parity:** the Phase-2 W-matrix (W1–W8) and native regression (NR1–3)
   re-pass unchanged, and a wire-log diff row confirms the two-step SLD flow
   did not change signaling bytes against stock.
3. **Customization proof:** a second module, `variant-core-abi1.wasm`, built
   from a derived core class, visibly changes call behavior against stock
   peers (fmtp munge, bitrate-cap loop, periodic ICE restart, stats-driven
   signal bars) with **zero harness/CLI rebuild** beyond the module itself.
4. Full iOS app build (`debug_sim_arm64`) stays green.

## Non-goals

- No media-plane crossing: frames, encoded-frame transforms, audio
  processing, raw RTP/RTCP never cross the boundary.
- No raw `RTCStatsReport` passthrough (tens of KB/s of mostly-noise through
  an interpreter); the host ships a curated reduction.
- No key material or signaling-crypto changes (trust boundary unchanged).
- No device policy crossing: ADM, capture devices stay host-owned and are
  referenced symbolically (`trackSource`).
- No `getParameters` round-trip (host merges parameter diffs), no mid-call
  `setConfiguration`, no binary data-channel payloads, no RID-simulcast
  negotiation beyond `sendEncodings` passthrough.
- No new backends, no WAMR changes, no module-form changes
  (`core_init`/`core_on_event`/`rt_alloc`/`rt_free`/`env.host_emit` as-is).
- Phase 3 (iOS app integration) still not started.

## The cut line (performance boundary)

Everything **control-plane** crosses: it runs at ≲10 Hz with KB-scale JSON
payloads, so interpreter cost is irrelevant (Phase-2 measurements: SDP < 8 KB,
a few events/sec). Everything **per-frame / per-packet** stays native.
The `stats` reduction is ~1–2 KB at the core-driven cadence (1 s reference).

## ABI surface (v1, rewritten)

Config, module form, pump rules are unchanged: same
`{abiVersion, wireVersion, isOutgoing, enableP2P, customParameters,
rtcServers}` config; same queue/no-reentrancy/`nowMs`/one-thread discipline;
same unknown-type tolerance; same abiVersion-mismatch refusal.

### Commands (core → host) — PC projection

| Command | Mirrors | Notes |
|---|---|---|
| `pc_create {iceTransportsType, iceServers}` | constructor | unchanged |
| `pc_create_offer {}` / `pc_create_answer {}` | createOffer/Answer | result arrives as `pc_description_created` |
| `pc_set_local_description {type, sdp}` | SLD(desc) | **replaces no-arg SLD**; the core sees and may rewrite every SDP before apply (munge point). Host parses the SDP; parse failure → `pc_set_local_done {ok:false}` |
| `pc_set_remote_description {sdpType, sdp}` | SRD | unchanged |
| `pc_add_ice_candidate {mid, mline, sdp}` | addIceCandidate | unchanged |
| `pc_restart_ice {}` | restartIce | flows back through normal `pc_renegotiation_needed` |
| `pc_add_transceiver {id, kind, direction, codecPreferences?, sendEncodings?, trackSource?}` | addTransceiver | **replaces** `pc_add_audio_track` / `pc_add_video_track`. `id` is core-chosen (string); host keeps id→transceiver registry. `kind`: `"audio"|"video"`. `direction`: `"sendrecv"|"sendonly"|"recvonly"|"inactive"`. `sendEncodings[]`: `{active?, maxBitrateBps?, minBitrateBps?, scaleResolutionDownBy?, rid?}`. `trackSource`: `"microphone"|"camera"|"none"` binds host-owned devices |
| `pc_set_parameters {id, degradationPreference?, encodings: [...]}` | sender.setParameters | host does GetParameters → merge fields present in the command → SetParameters; rejection → `error` event |
| `pc_set_track_enabled {id, enabled}` | track.enabled | replaces `pc_set_audio_track_enabled` |
| `pc_remove_track {id}` | removeTrack | replaces `pc_remove_video_track` (same host semantics as today, keyed by id) |
| `pc_set_incoming_sink {mid}` | (sink binding) | binds the app's incoming video sink to the transceiver with `mid`; replaces host auto-bind |
| `pc_create_data_channel {label?, ordered?, negotiated?, id?}` | createDataChannel | options exposed; defaults = stock behavior |
| `pc_get_stats {}` | getStats | renamed from `request_stats`; reply is the `stats` event |

Harness commands unchanged: `core_ready {abiVersion}`, `signaling_send`,
`dc_send`, `set_timer`, `emit_state`, `emit_signal_bars`,
`emit_remote_media_state`, `emit_remote_battery_low`, `log`, `stats_log`,
`close`.

### Events (host → core) — PC callbacks mirrored

Unchanged: `pc_renegotiation_needed`, `pc_ice_candidate`, `pc_ice_state`,
`pc_signaling_state`, `pc_candidate_pair_changed`, `pc_set_remote_done`,
`dc_state`, `dc_message`, and all harness events (`signaling_message`,
`timer`, `mute`, `battery_low`, `video_capture`, `stop`, `error`).

New / changed:

- `pc_description_created {ok, type: "offer"|"answer", sdp, error?}` —
  completion of `pc_create_offer`/`pc_create_answer`.
- `pc_set_local_done {ok, type, sdp}` — unchanged shape; now completes the
  explicit-SDP SLD.
- `pc_connection_state {state}` — PeerConnectionState (`"new"|"connecting"|
  "connected"|"disconnected"|"failed"|"closed"`); cores may ignore.
- `pc_gathering_state {state}` — `"new"|"gathering"|"complete"`; cores may
  ignore.
- `pc_track {mid, kind}` — remote track arrival (OnTrack); pairs
  with `pc_set_incoming_sink`.
- `stats {…}` — rewritten (below).

### The `stats` event (curated reduction)

```
stats { nowMs, sendBitrateKbps,                  // top-level kept for
                                                 // stats-log parity
  transport: { rttMs?, availableOutgoingKbps?, availableIncomingKbps?,
               bytesSent, bytesReceived,
               localCandidateType?, remoteCandidateType? },
  audio: { send: { bitrateKbps, packetsSent, remoteLossFraction?,
                   remoteRttMs?, remoteJitterMs? },
           recv: { bitrateKbps, packetsReceived, packetsLost, jitterMs,
                   audioLevel? } },
  video: { send: { bitrateKbps, frameRate?, frameWidth?, frameHeight?,
                   qualityLimitationReason? },
           recv: { bitrateKbps, framesDecoded, frameRate?, frameWidth?,
                   frameHeight?, packetsLost } } }
```

Sources: `candidate-pair` (selected pair), `outbound-rtp` +
`remote-inbound-rtp`, `inbound-rtp` stats objects. Absent stats omit their
keys (the core tolerates missing fields). Bitrates are host-computed deltas,
as today. Exact field extraction is pinned in the implementation plan.

## Host changes (`CallCoreHost`)

- New executors: CreateOffer/CreateAnswer (observer → `pc_description_created`),
  SLD-with-SDP (`CreateSessionDescription` parse → SetLocalDescription),
  RestartIce, transceiver registry (core id → `RtpTransceiverInterface`),
  AddTransceiver with `RtpTransceiverInit` (direction, send_encodings) +
  codec preferences + track binding by `trackSource`, SetParameters merge,
  track-enabled/remove by id, sink binding by mid, data-channel options,
  rich stats reducer.
- Removed executors: `pc_add_audio_track`, `pc_add_video_track`,
  `pc_set_audio_track_enabled`, `pc_remove_video_track`, no-arg SLD,
  auto-bind of the incoming video sink.
- `pc_track` event emission from OnTrack; `pc_connection_state` /
  `pc_gathering_state` from the corresponding observer callbacks.
- Everything else (signaling crypto/transport, gzip, timers, stop flow,
  backend seam, pump rules) unchanged.

## Reference core (parity) + variant core (demo)

**`ReferenceCallCore`** adopts the new flow with stock-identical behavior:
`pc_renegotiation_needed` → `pc_create_offer` → on `pc_description_created`
emit `pc_set_local_description` with the SDP **verbatim** → on
`pc_set_local_done` send the offer over signaling (answers symmetric via
`pc_create_answer` after SRD). Track management moves to
`pc_add_transceiver`/`pc_remove_track` mirroring stock's setup order.
Parity argument: WebRTC's no-arg SLD internally *is* CreateOffer/CreateAnswer
+ apply, so applying the created SDP verbatim produces identical
descriptions; the signaling JSON layer is untouched.

It gains three `protected virtual` hooks (default = stock behavior):

- `mungeLocalDescription(type, sdp) -> sdp` (default: identity)
- `onStats(const Json &stats)` (default: bitrate records, as today)
- `onIceState(const std::string &state)` (default: state mapping, as today)

**`VariantCallCore`** (`VariantCallCore.{h,cpp}`, same include discipline)
derives from `ReferenceCallCore` and demonstrates, all interop-safe against
stock peers:

1. **SDP munge:** Opus fmtp `usedtx=1;useinbandfec=1;maxaveragebitrate=24000`
   on local descriptions.
2. **Adaptive cap loop:** drives `pc_set_parameters` from
   `stats.transport.availableOutgoingKbps` (cap ≈ 80 % of BWE, clamped).
3. **Periodic ICE restart:** `pc_restart_ice` (~every 7 stats ticks ≈ 7 s —
   cadenced off the stats loop, no extra timer); the call must remain/
   re-become established.
4. **Signal bars from RTT/loss** instead of bitrate history.
5. Marker `log` lines (`variant: munge applied`, `variant: ice_restart N`,
   `variant: cap K kbps`) for validation grep.

**Module packaging:** `wasm_module_entry.cpp` becomes generic — it calls
`tgcalls::v2wasm::createModuleCore(config, emit)` — with the factory in a
per-module TU: `reference_core_factory.cpp` (instantiates the base) and
`variant_core_factory.cpp` (instantiates the variant). Two genrules:
`reference_core_wasm` (entry + reference factory + `ReferenceCallCore.cpp` +
json11) and `variant_core_wasm` (adds `VariantCallCore.cpp`, swaps the
factory), output `variant-core-abi1.wasm`. **`VariantCallCore.cpp` joins no
native source list** — the variant exists only as a module; that is the
demonstration. The native library keeps linking the reference core.

The CLI needs no new flags: `--wasm-core`/`--wasm-core2` already accept any
module path.

## Validation matrix

Parity (all must re-pass; commands as in the Phase-2 spec):

| # | row |
|---|---|
| W1–W8 | Phase-2 matrix re-run against the reworked surface |
| NR1–NR3 | native regression re-run |
| P1 | wire-log diff: pump-vs-stock signaling payloads compared against a stock-vs-stock baseline run — two-step SLD must not change wire bytes |

Variant (pass = exit 0 + marker greps in non-quiet output):

| # | caller | callee | asserts |
|---|---|---|---|
| V1 | 11.0.0-pump (variant wasm) | 11.0.0 stock | established; munge marker; ≥2 ice_restart markers survived; cap marker |
| V2 | 11.0.0 stock | 11.0.0-pump (variant wasm) | established; munge applies on the answer side |
| V3 | variant wasm | variant wasm | established; both sides' markers |
| V4 | variant wasm | 11.0.0 stock | `--drop-rate 0.3 --delay 50-200 --duration 30`; established |

Builds: CLI + both modules from clean; full iOS `debug_sim_arm64` app build.

## Risks / open items

- **Two-step SLD parity drift**: mitigated by P1 (wire diff) and the
  CreateOffer≡no-arg-SLD argument; if WebRTC inserts state between create and
  apply (e.g. a candidate arriving mid-queue), the pump's serialized queue
  bounds the window to one drain cycle.
- **Munged-SDP parse failures**: host-side `CreateSessionDescription` catches
  them → `ok:false` → core policy (reference never munges; variant munge is
  append-only fmtp edits).
- **ICE restart in loopback p2p**: RestartIce must round-trip through
  perfect negotiation (polite/impolite roles already in the core). If the
  restart storm interacts badly with the 7 s cadence under loss, the variant
  backs off (policy change in the module — which is the point).
- **Sink-binding race**: incoming frames before `pc_set_incoming_sink` lands
  are dropped for ~one queue drain — same class of race stock has with
  OnTrack; acceptable for the exploration surface.
- **SetParameters constraints** (e.g. min > max): surfaced as `error` events;
  the reference core never calls it.
- Phase-3 backlog from Phase 2 (module size, trap-during-stop note, WAMR
  pruning, watchdog design) is unchanged and untouched by this phase.

## Phasing recap (updated)

1. ~~Native pump boundary~~ (done).
2. ~~WASI module + WAMR runtime + iOS build-proof~~ (done).
2.5. **This spec:** PC-projection ABI rewrite + variant demo module.
3. iOS app integration behind an experimental flag; embedded modules;
   server-flag selection.
4. Signed remote delivery; dynamic `Meta::versions()`; kill-switch + native
   fallback; watchdog/metering.

## Validation results (Phase 2.5)

Re-run 2026-07-02 against submodule tip `b70a712` (parent `130629f1b2`).
`CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli`,
`WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm`,
`VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm`.

### Parity matrix (W1–W8, NR1–NR3)

All rows `--quiet`; distinguishing flags shown; every row established the
call with non-empty stats and non-zero BWE both sides.

| # | distinguishing flags | exit |
|---|---|---|
| W1 | `--version 11.0.0-pump --version2 11.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W2 | `--version 11.0.0 --version2 11.0.0-pump --duration 10 --wasm-core2 $WASM` | 0 |
| W3 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM` | 0 |
| W4 | `--version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W5 | `--version 10.0.0-pump --version2 10.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W6 | **honest skip** — `run-local-test.sh` cannot forward `--wasm-core` | n/a |
| W7 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W8 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM` | 0 |
| NR1 | `--version 11.0.0-pump --version2 11.0.0 --duration 10` (native) | 0 |
| NR2 | `--version 11.0.0 --version2 11.0.0-pump --duration 10` (native) | 0 |
| NR3 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10` (native) | 0 |

### P1 — wire-log diff (pump vs stock, offer + answer)

Signaling-payload SDP extracted from `CallCoreHost signaling_send`/
`signaling in` log lines, normalized (strip `o=`, `a=ice-ufrag`,
`a=ice-pwd`, `a=fingerprint`, `a=ssrc`, `a=msid-semantic`, `a=candidate` —
per-run-random lines), compared pump-as-caller vs stock-as-caller.

| verdict | result |
|---|---|
| offer | MATCH |
| answer | MATCH |

No additional STRIP regex extensions were needed beyond the baseline
random-line set above — the two-step `pc_create_offer`/`pc_create_answer` →
`pc_set_local_description` flow produces byte-identical signaling payloads
to stock's no-arg SLD, confirming the parity argument in "Reference core
(parity) + variant core (demo)".

Re-run 2026-07-02 (final-review pass) using the permanent `--log-file`
mechanism directly (`$CLI ... --log-file $SCRATCH/p1b_{pump,stock}_caller.log`,
8 s each) — no temporary edit this time, retiring the earlier "captured via
a since-reverted `logPath` edit" caveat. Same `p1_diff.py` normalize/diff
script, same verdicts: offer MATCH, answer MATCH.

### Munge wire-survival

`VariantCallCore`'s Opus fmtp munge (`usedtx=1;useinbandfec=1;
maxaveragebitrate=24000`) applied to local descriptions was checked against
the actual outbound signaling wire, not just the SDP the core produces
internally: `--wasm-core $VARIANT --wasm-core2 NONE`, `--duration 12`,
`--log-file`. Result: munge wire-survival: `usedtx=1` present in 3 outbound
`signaling_send` SDP payloads (exit 0).

### Variant matrix (V1–V4)

All rows exit 0. Marker counts from `[core] variant: …` log lines, captured
via `--log-file` (RTC log sinks are process-global — the sinks needed
`--log-file` to surface at all; see "Fixes/deviations" below) and grepped
from the log file, not stdout.

| # | flags (beyond mode/version) | exit | active | munge | cap | ice_restart |
|---|---|---|---|---|---|---|
| V1 | `--duration 20 --wasm-core $VARIANT --wasm-core2 NONE` (11.0.0-pump variant caller vs 11.0.0 stock) | 0 | 1 | 2 | 3 | 2 |
| V2 | `--duration 15 --wasm-core2 $VARIANT` (11.0.0 stock caller vs 11.0.0-pump variant callee) | 0 | 1 | 2 | 2 | 0 |
| V3 | `--duration 20 --wasm-core $VARIANT` (variant vs variant, wasm-core2 inherits) | 0 | 2 | 3 | 6 | 2 |
| V4 | `--duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $VARIANT --wasm-core2 NONE` | 0 | 1 | 2 | 2 | 4 |

`active` = `variant: core active` (one per variant-core instance —
2 for V3 since both sides are variant, 1 elsewhere). V1/V3/V4 restarts ≥ 2,
munge ≥ 1, cap ≥ 1, as expected for an outgoing variant side. V2 (variant is
the callee, not outgoing): munge ≥ 1 on the answer side, cap ≥ 1,
restarts = 0 by design (the variant's restart cadence is outgoing-only).
All four rows match the spec's asserts.

### iOS build-proof

```
python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
  build --configurationPath build-system/appstore-configuration.json \
  --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
  --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Result: `Build completed successfully, 3762 total actions` —
`bazel-bin/Telegram/Telegram.ipa` produced, exit 0. No errors.

### Fixes/deviations applied during execution

1. **Task-3 stats-contract fixes** (found by task review, applied before this
   re-run): BWE presence flags on `transport.availableOutgoingKbps`/
   `availableIncomingKbps` (omitted rather than zero when the underlying
   stat is absent), and `jitterMs` scoped correctly to `audio.recv` only
   (it does not exist on the send side in WebRTC's stats).
2. **CLI `--log-file PATH` option added** (submodule commit `b70a712`): p2p
   mode never set `config.logPath`, and both pump instances disable stderr
   RTC logging, so the `[core] variant: …` marker lines were unobservable
   from any existing CLI flag — the V-matrix marker greps were literally
   unrunnable without it. RTC log sinks are process-global, so one
   `--log-file` flag (set once, before either instance starts) captures
   both sides' logs into one file.
3. **P1 methodology note**: the offer/answer MATCH verdicts were originally
   captured (predating `--log-file`) via a temporary, since-reverted edit
   that wired `logPath` directly for a one-off P1 run, then re-verified
   against the retained logs. A further final-review re-run redid the P1
   capture from scratch using the permanent `--log-file` flag (no temp
   edits) — see "P1 — wire-log diff" above — reproducing identical
   MATCH/MATCH verdicts and retiring the temporary-edit caveat.
4. **Spec drift — `pc_track` event shape**: the "Events" section above
   listed `pc_track {mid, kind, direction}`; the implementation (and
   `CallCoreABI.h`) only ever emits `{mid, kind}` — no `direction` field.
   Corrected in this pass.
5. **Spec drift — periodic ICE restart cadence**: the variant-core section
   above described the restart as firing "every ~7 s via `set_timer`";
   `VariantCallCore` has no `set_timer` call for this — it counts stats
   ticks in `onStats` (`_statsTicks % kIceRestartEveryStatsTicks == 0`,
   `kIceRestartEveryStatsTicks = 7`, one tick ≈ 1 s) and never registers a
   timer. Corrected in this pass.

### Backlog (from final whole-phase review)

- dead shadowed `sources = glob(...)` assignment at
  `submodules/TgVoipWebrtc/BUILD` (~line 96) — deleting the WRONG duplicate
  would sweep wasm-only `.cpp` into the iOS target; remove the dead one.
- stats reducer sums across all `RTCTransportStats` (single-bundled-transport
  assumption).
- `frameWidth>0` gate couples width/height emission; the reducer collects
  video jitter it never emits.
- `mungeOpusFmtp` assumes a single audio m-line (demo-module scope).
- variant `_statsTicks` accumulates pre-connect (first restart lands 1–7
  ticks post-connect).
- `executeGetStats` with no `PeerConnection` silently drops the command (no
  `error` event).
- `ReferenceCallCore` exposes ALL state as `protected`; consider
  re-privatizing negotiation flags to protect the parity baseline.
