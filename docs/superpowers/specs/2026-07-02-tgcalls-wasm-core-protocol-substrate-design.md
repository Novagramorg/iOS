# tgcalls WASM-core Phase 2.6: protocol substrate (design)

Date: 2026-07-02
Status: implemented + validated 2026-07-03 (see "Validation results (Phase 2.6)" below)
Predecessors: `2026-07-02-tgcalls-wasm-core-pc-abi-design.md` (Phase 2.5, complete),
`docs/superpowers/specs/2026-07-0*-tgcalls-wasm-core-*` (Phases 1–2)

## Context

Phase 2.5 rewrote the pump ABI as a PeerConnection-projection contract: the
core drives negotiation through two-step SLD (the SDP munge point),
transceiver/parameter/ICE-restart commands, and a curated `stats` event; a
second module (`variant-core-abi1.wasm`) proved behavior changes ship as wasm
only. The user asked what *else* can move into the core. Investigation
findings that shaped this phase:

- The signaling **content** (the `{"@type": offer/answer/candidate/…}` JSON)
  already lives in the core (Phase 1). What the harness still owns of
  signaling is the envelope pipeline: gzip (V2 versions), and
  `EncryptedConnection` — which is really two layers, AEAD crypto (key
  material; can never cross) and a reliability/framing protocol (seq flag
  bits, message packing, acks, resends, service packets — fully live for wire
  `10.0.0`, whose signaling is V1; `11.0.0` uses the simple
  gzip+`encryptRawPacket` V2 path).
- The plaintext packet fed to the AEAD has the **same shape on both paths**:
  `seq(4 bytes, network order) || body`. The seq's low 30 bits are the crypto
  counter / replay-window key (crypto state); its top two bits
  (`kSingleMessagePacketSeqBit`, `kMessageRequiresAckSeqBit`) are reliability
  **policy**. This gives a clean split line.
- The data-channel surface is a single hardwired text channel
  (`_dataChannel`, `dc_send {data: string}` with no label routing).
- The host builds `webrtc::AudioProcessing` explicitly
  (`CallCoreHost.cpp:557`) and can retain the ref — mid-call `ApplyConfig`
  is cheap to expose. Mid-call `PeerConnection::SetConfiguration` likewise.
- Stock tolerance facts (verified in source): unknown JSON **fields** inside
  known signaling message types are silently ignored (only an unknown
  `@type` is rejected, per message — `v2/Signaling.cpp`); an unexpected
  remote data channel just forwards to an optional callback
  (`v2/InstanceV2ReferenceImpl.cpp:172`) — benign.
- `SignalingSctpConnection` runs its **own** SCTP association over the
  external transport — it is not a PC data channel, so core-created channels
  cannot collide with it.

User decisions (2026-07-02): all three workstreams approved — **A**
data-channel substrate, **B** session-config knobs, **C** signaling framing
in core. For C, **replace outright** (no dual-mode): the raw packet boundary
replaces `signaling_send`, and `ReferenceCallCore` ports the framing. ABI
policy unchanged from 2.5: break in place, still `abiVersion: 1` — nothing
has shipped.

## Goal / success criteria

Deepen the pump boundary so that signaling framing/reliability policy,
arbitrary peer-to-peer sub-protocols, and session audio/ICE configuration are
all core-owned (i.e. customizable from a wasm module with zero harness
rebuild):

1. `CallCoreHost` becomes **version-blind on signaling**: no `_isSignalingV2`
   branches, no gzip, no ack/service logic — its signaling role collapses to
   validate + seal + send / open + replay-check + deliver.
2. `ReferenceCallCore` reproduces stock signaling behavior at the JSON layer
   for `11.0.0` (P1 diff, as in 2.5) **and** at the framing layer for
   `10.0.0` (new P2 diff + interop) — it becomes the parity baseline
   *including framing*.
3. A wasm module can open N named data channels (text or binary) and run its
   own in-call protocol against a peer module.
4. A wasm module can reconfigure audio processing and ICE mid-call.
5. Variant demos prove each new surface as wasm-only changes; full
   W/NR/P/V validation matrices green; iOS `debug_sim_arm64` build green.

## Non-goals

- Group/conference calls; wire versions beyond `10.0.0`/`11.0.0`.
- Key material, raw RTP/frames, or raw `RTCStatsReport` crossing the
  boundary (unchanged cut line from 2.5).
- Moving the signaling **transport** (SCTP-vs-external routing stays host).
- WebRTC field trials (process-global — one call's experiment would
  contaminate the next), codec factory internals, capture-device control.
- Backpressure/flood *enforcement* for data channels (documented budget
  guidance only; metering is the existing Phase-4 watchdog backlog item).

## Workstream C — signaling: raw packet boundary

The ABI's signaling boundary moves one layer down: from "plaintext JSON
message" to **the full plaintext packet (`seq(4) || body`) that feeds the
AEAD**. The host no longer knows what a signaling message is.

### ABI delta

Removed: command `signaling_send`, event `signaling_message`.

Added:

```
Command  signaling_send_packet { packetB64: s }
  packet = seq(4 bytes, network byte order) || body, built entirely by the
  core. Host validation before sealing:
    counter = seq & ~(kSingleMessagePacketSeqBit|kMessageRequiresAckSeqBit)
    - counter must be strictly greater than the last-sent counter
    - counter must be <= kMaxAllowedCounter
  Violations -> "error" event, packet dropped (preserves AEAD IV freshness
  against a buggy/hostile module). Host seals via EncryptedConnection crypto
  and sends over the existing transport routing (SCTP/external, unchanged).

Event    signaling_packet { packetB64: s }
  Host opens the AEAD, runs the native replay-window check on the counter
  (registerIncomingCounter semantics — stays host-side), and delivers the
  whole plaintext packet (seq included). Replay-rejected packets are dropped
  without an event, as today.
```

Binary convention (new, also used by workstream A): binary payloads cross
the JSON ABI as standard base64 in `*B64`-suffixed keys.

### Host changes

- `executeSignalingSend`, `sendPendingSignalingServiceData`,
  `processIncomingSignalingMessage`, the `_isSignalingV2` flag and both its
  branches, and the gzip calls are **deleted** from `CallCoreHost`
  (~100 lines). The `EncryptedConnection` constructor's
  `requestSendService` callback becomes a no-op for the pump host (service
  sends are now core policy).
- `EncryptedConnection` gains **additive** methods (no behavior change for
  stock/legacy users, which still use the existing API):
  - seal-with-embedded-seq: encrypt a full plaintext packet whose first 4
    bytes are the seq (the counter for key derivation is read from the
    buffer, not from internal `_counter`);
  - open-to-plaintext: decrypt + replay-window check, returning the full
    plaintext packet without message parsing.
  Exact names/signatures are plan detail; the constraint is additive-only.

### Core changes (`ReferenceCallCore` + new `SignalingFraming` component)

A new core-side component (same include discipline as the core) owns
everything between JSON messages and plaintext packets:

- **V1 framing** (wire `10.0.0`) — a faithful port of
  `EncryptedConnection`'s reliability layer, constants verbatim:
  - seq composition: 30-bit counter + `kSingleMessagePacketSeqBit`
    (1<<31) + `kMessageRequiresAckSeqBit` (1<<30); counter ownership is
    core-side (host only enforces monotonicity);
  - message serialization with embedded seq, additional-message
    piggybacking of not-yet-acked messages, ack lists appended to packets;
  - ack bookkeeping (`registerSentAck` first-in-packet rule, `ackMyMessage`,
    postponed acks) and empty/service packets;
  - resend policy via the existing `set_timer` command:
    `minDelayBeforeMessageResend` 3000 ms, `maxDelayBeforeMessageResend`
    5000 ms, `maxDelayBeforeAckResend` 5000 ms (Signaling values);
  - packet limit `kMaxSignalingPacketSize` = 16 KiB;
  - signaling messages request acks (`messageRequiresAck = true`), matching
    the host's current `prepareForSendingRawMessage(message, true)`.
- **V2 framing** (wire `11.0.0`) — body = gzip(JSON) on send; on receive,
  gzip-magic check + bounded inflate (2 MiB cap, as the host does today),
  else treat as plaintext JSON. Port of `processIncomingSignalingMessage`.
- **miniz vendored** for inflate/deflate: single-file, std-only, builds
  under wasi-sdk with `-fno-exceptions`. Vendored next to json11 inside the
  tgcalls repo; compiled into the native core library AND the wasm modules.
  The core include discipline amends to: **ABI header + json11 + miniz +
  C++17 std**.
- The JSON messages the reference core emits are unchanged — JSON-layer
  parity (P1) is untouched by design; V1 framing parity is newly proven by
  P2 + interop.

Deflate byte-streams from miniz may legally differ from platform zlib's.
This is invisible at the JSON layer and irrelevant to interop (peers inflate
any valid stream); the parity contract is and remains **JSON-layer equality
plus framing behavior**, not ciphertext bytes (which already differ per-call
by crypto).

**Logging point moves with the boundary.** The P1/P2 wire-log diffs keyed on
the host's `CallCoreHost signaling_send:` / `signaling in:` lines, which
workstream C deletes. The reference core takes over that responsibility: it
emits `log` commands with the outgoing message JSON before framing and the
incoming message JSON after parsing (same content the host logged), so the
diff methodology keeps working and stays comparable with stock's logs.

### Variant hook seam additions

Phase 2.5 established three `protected virtual` hooks on `ReferenceCallCore`
(`mungeLocalDescription`, `onStats`, `onIceState`). The demos in this phase
need two more, same pattern (default = no-op / stock behavior):

- `mungeOutgoingSignalingMessage(json11::Json::object &message)` — called on
  every outgoing signaling message before framing (the V-C1 padding seam;
  also the general "extend the wire protocol" seam).
- `onDataChannelEvent(json11::Json const &event)` — called for
  `dc_state` / `dc_message` / `dc_buffered` / `dc_channel` events after the
  reference core's own handling (the V-A ping/pong seam).

The V-C2 keepalive additionally needs the framing's service-packet emission
reachable from derived classes — `SignalingFraming` (or its owner methods on
`ReferenceCallCore`) exposes it as `protected`.

### Trust note

Key material and the replay window stay native. Counter monotonicity is
host-enforced, so a hostile module cannot force AEAD IV reuse. Beyond that,
a module that mis-frames can at worst corrupt its own call's signaling —
already within its blast radius today (it authors all signaling content).

### Supersession note

Phase 2.5 froze `ReferenceCallCore` as the untouchable parity baseline. This
phase **deliberately rewrites its signaling path once** (user decision:
replace outright). After 2.6 lands and parity is re-proven, the freeze
re-applies with framing included: behavior experiments go in variant cores,
never in `ReferenceCallCore`.

## Workstream A — data channels: N named channels, binary payloads

The single hardwired channel generalizes to a host-side `label → channel`
registry. This is the arbitrary in-call protocol substrate: modules get
E2E-encrypted (DTLS/SCTP) peer-to-peer messaging with zero new trust
surface.

### ABI delta

```
Command  pc_create_data_channel { label?: s (default "data"), ordered?: bool,
                                  negotiated?: bool, id?: n }
  Now callable N times. Labels must be unique among core-created channels;
  a duplicate label -> "error" event. (No collision with SCTP signaling —
  separate SCTP association, verified.)

Command  dc_send { label?: s (default "data"), data?: s, dataB64?: s }
  Exactly one of data/dataB64 (dataB64 sends a binary SCTP message).
  Unknown label or channel not open -> "error" event. Oversize message
  (> the WebRTC SCTP max, 256 KiB default) -> "error" event.

Event    dc_state    { label: s, open: bool }
Event    dc_message  { label: s, data?: s, dataB64?: s }
  Text messages arrive as data; binary as dataB64.
Event    dc_buffered { label: s, bufferedAmount: n }
  Emitted when a channel's buffered amount drains to 0 (the WebRTC
  OnBufferedAmountChange drain signal) — minimal backpressure: send a
  batch, wait for drain.
Event    dc_channel  { label: s, id: n }
  A remote-announced channel (OnDataChannel). The host registers it under
  its label (collision with an existing label: "error" event + the remote
  channel is ignored); thereafter dc_send/dc_message/dc_state work on it.
```

`dc_state`/`dc_message` keep their 2.5 shapes plus the `label` key; the
reference core continues to use only the default `"data"` channel
(unchanged behavior — this workstream is additive for parity purposes).

Budget guidance (documented in `CallCoreABI.h`, not enforced): data channels
are control-plane; modules should stay in the ≲10 Hz / KB-scale envelope.
Flood enforcement joins the existing Phase-4 watchdog/metering backlog.

## Workstream B — session-config knobs

### ABI delta

```
Command  pc_create gains:
  audioProcessing?: { echoCancellation?: bool, noiseSuppression?: bool,
                      autoGainControl?: bool, highPassFilter?: bool }
  Omitted keys keep WebRTC defaults (stock behavior). The host retains its
  webrtc::AudioProcessing ref and applies overrides at build time.

Command  set_audio_processing { echoCancellation?: bool,
                                noiseSuppression?: bool,
                                autoGainControl?: bool,
                                highPassFilter?: bool }
  Mid-call ApplyConfig on the retained APM (WebRTC supports runtime
  reconfiguration). Only the supplied keys change.

Command  pc_set_configuration { iceServers?: [ { urls: [s], username: s,
                                                 password: s } ],
                                iceTransportsType?: "all"|"relay",
                                candidatePoolSize?: n }
  Host maps to PeerConnection::SetConfiguration (fetching the current
  config and merging the supplied keys). WebRTC rejects changes to
  immutable fields -> "error" event with the webrtc error message.
```

The reference core uses none of these (stock sets no APM overrides and
never calls SetConfiguration) — additive for parity.

## Validation matrix

Parity is re-proven because C rewrites the reference core's signaling path
(supersession note above).

| ID | What | Pass criterion |
|---|---|---|
| W (re-run) | Full Phase-2 W-matrix (pump↔stock, pump↔pump, wasm↔native substrates) on `11.0.0` legs | exit 0, connected, media flows |
| W-V1 (new) | `10.0.0` pump(wasm)↔stock both directions | exit 0, connected; no decrypt/parse errors in either side's logs |
| NR (re-run) | Non-regression suite (NR1–NR3) | exit 0 |
| P1 (re-run) | `11.0.0` wire-log JSON diff, pump vs stock (offer + answer, normalized) | MATCH |
| P2 (new) | `10.0.0` wire-log diff, pump vs stock: logged plaintext signaling JSON sequence (send + recv) | MATCH (CLI transport is lossless, so resend timers stay quiet and logs are deterministic) |
| V-A | Variant opens `"exp0"` channel; variant↔variant ping/pong with `variant: dc pong N` markers; variant↔stock leg | ≥3 pongs each side; stock leg connects cleanly and ignores the channel |
| V-B | Variant applies `set_audio_processing` (NS+AGC off) and `pc_set_configuration {candidatePoolSize: 2}` mid-call, markers `variant: apm applied` / `variant: config applied` | markers present; call stays connected (relay-only stays a documented capability — the CLI testbench has no TURN server) |
| V-C1 | Variant pads V2 signaling: random-base64 `"_pad"` key (~256 B) injected into Candidates messages pre-gzip, marker `variant: pad N` | markers present; **stock peer** parses and connects (unknown-field tolerance) |
| V-C2 | Variant on `10.0.0` emits periodic V1 keepalive (empty/service packet every 5 s), marker `variant: keepalive N` | ≥2 markers; stock peer accepts (no decrypt/parse errors; call stays connected) |
| B1 | iOS `debug_sim_arm64` full build | green |

All V-legs run with `--log-file`; variant behaviors ship only in
`variant-core-abi1.wasm` (no harness/CLI rebuild beyond the module — the
standing wasm-only demonstration).

## Risks / open items

- **V1 port fidelity** is the big one: ack semantics are subtle
  (first-in-packet ack registration, additional-message seq echo, postponed
  acks). Mitigation: constants and serialization copied verbatim from
  `EncryptedConnection.cpp`; P2 diff + W-V1 interop + V-C2 keepalive
  tolerance as behavioral checks. Loss-path resend behavior is untestable in
  the lossless CLI — accepted gap, noted for a future lossy-transport
  testbench mode (backlog).
- **Module size growth** (miniz + framing + base64): measure and record;
  joins the existing module-size backlog item.
- **`ApplyConfig` runtime safety**: WebRTC documents runtime
  reconfiguration, but the plan must verify the call path (media thread)
  matches WebRTC's threading expectations.
- **`SetConfiguration` merge semantics**: fetching-and-merging the current
  `RTCConfiguration` must not accidentally reset fields the host set at
  `pc_create` (e.g. `sdpSemantics`, `enableDtlsSrtp`-era flags). Plan
  detail: merge only the three exposed keys.
- **dc event flood**: a module can flood itself with `dc_message` events;
  documented budget, enforcement deferred (Phase-4 metering).
- **Base64 helper** in the core must be dependency-free (std-only) — small,
  written in-tree, shared by A and C.

## Phasing recap (updated)

1. Phase 1 — native pump (done)
2. Phase 2 — WASM module + WAMR runtime (done)
3. Phase 2.5 — PeerConnection-projection ABI + variant demo module (done)
4. **Phase 2.6 — protocol substrate (this spec): signaling framing in core,
   N-channel data substrate, session-config knobs**
5. Phase 3 — iOS app integration behind an experimental flag; embedded
   modules; server-flag selection
6. Phase 4 — watchdog/metering, module provenance, size budget

## Validation results (Phase 2.6)

Re-run 2026-07-03 against submodule tip `bd2e125` (parent `61a51c142085`).
`CLI=./bazel-bin/submodules/TgVoipWebrtc/tgcalls/tools/cli/tgcalls_cli`,
`WASM=bazel-bin/submodules/TgVoipWebrtc/reference-core-abi1.wasm`,
`VARIANT=bazel-bin/submodules/TgVoipWebrtc/variant-core-abi1.wasm`.

### Parity matrix (W1–W8, NR1–NR4, BL1)

All rows `--quiet`; distinguishing flags shown; every row established the
call with non-empty stats logs and non-zero BWE both sides, zero errors.
`W-V1` in the "Validation matrix" table above is realized as the
`10.0.0-pump`↔`10.0.0` pair below (both directions, W5/W5b) plus its loss
variant (W5c, with BL1 as the stock-stock baseline for the same loss
parameters).

| # | distinguishing flags | exit |
|---|---|---|
| W1 | `--version 11.0.0-pump --version2 11.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W2 | `--version 11.0.0 --version2 11.0.0-pump --duration 10 --wasm-core2 $WASM` | 0 |
| W3 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM` | 0 |
| W4 | `--version 11.0.0-pump --version2 11.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W5 | `--version 10.0.0-pump --version2 10.0.0 --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W5b | `--version 10.0.0 --version2 10.0.0-pump --duration 10 --wasm-core2 $WASM` | 0 |
| W5c (new) | `--version 10.0.0-pump --version2 10.0.0 --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W6 | **honest skip** — `run-local-test.sh` cannot forward `--wasm-core` | n/a |
| W7 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10 --wasm-core $WASM --wasm-core2 NONE` | 0 |
| W8 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $WASM` | 0 |
| NR1 | `--version 11.0.0-pump --version2 11.0.0 --duration 10` (native) | 0 |
| NR2 | `--version 11.0.0 --version2 11.0.0-pump --duration 10` (native) | 0 |
| NR3 | `--version 11.0.0-pump --version2 11.0.0-pump --duration 10` (native) | 0 |
| NR4 (new) | `--version 10.0.0-pump --version2 10.0.0-pump --duration 10` (native) | 0 |
| BL1 (new) | `--version 10.0.0 --version2 10.0.0 --duration 30 --drop-rate 0.3 --delay 50-200` (stock-stock loss baseline) | 0 |

**W5c is the load-bearing new row**: it proves the ported V1 resend layer
(`SignalingFraming`, wire `10.0.0`) recovers signaling under 30% drop /
50–200 ms delay against an unmodified stock peer, both sides establishing
(caller `Established`, callee `Reconnecting` — the same asymmetric
end-state W4's `11.0.0` loss row shows) with non-zero BWE and a full
30/30-record stats log. BL1 is its stock-stock baseline under identical
loss parameters, confirming the loss itself (not the framing port) is what
drives the `Reconnecting` callee state.

### P1 — wire-log diff (11.0.0, pump vs stock, re-run)

Same methodology as the Phase-2.5 record: JSON-layer offer/answer extracted
from `sendSignalingMessage: `/`[core] signaling out: ` log lines, normalized
(strip `o=`, `a=ice-ufrag`, `a=ice-pwd`, `a=fingerprint`, `a=ssrc`,
`a=msid-semantic`, `a=candidate`), compared pump-as-caller vs stock-as-caller
(`--duration 8`, `--log-file`).

| verdict | result |
|---|---|
| offer | MATCH |
| answer | MATCH |

No STRIP-list extension needed. Confirms the Phase-2.6 rewrite (core now
owns signaling framing end-to-end; the host no longer touches signaling
JSON) produced no wire drift on the `11.0.0` (V2/gzip) leg.

### P2 — wire-log diff + framing invariants (10.0.0, pump vs stock, new)

New for this phase: `10.0.0` is the V1-framing leg (ported ack/resend/service
packets), so P2 checks both JSON-layer SDP parity **and** the framing
invariants (every ack-requiring send eventually acked, at least one ACK
appended, zero decrypt/parse errors) on both the pump and the stock run
(`--duration 10`, `--log-file`, `p1_diff.py` + `p2_framing.py`).

| check | pump run | stock run |
|---|---|---|
| offer/answer JSON diff | MATCH / MATCH | (same comparison, symmetric) |
| framing invariant (`p2_framing.py`) | `sends=5 acked=5 missing=[] added_acks=True errors=0`, exit 0 | `sends=6 acked=6 missing=[] added_acks=True errors=0`, exit 0 |

Both processes' framing counters are self-consistent (all sends acked,
resend/ack machinery engaged — `added_acks=True` — zero framing/decrypt
errors) even though the CLI's signaling transport is lossless here (P2 is a
correctness check, not a loss-recovery check; W5c covers loss recovery).

### Variant matrix — 2.5 rows re-run (V1–V4)

Same commands and thresholds as the "Variant matrix (V1–V4)" section above
(2.5 spec). All four rows re-pass at **exactly** the 2.5 baseline counts;
the Phase-2.6 variant additionally emits pad/apm/config markers on every
row (2.6 surfaces are unconditional in `onStats`/`mungeOutgoingSignalingMessage`,
not gated by version) — expected, not a failure. `dc_pong` is non-zero only
on V3 (both sides variant, so `exp0` negotiates and ping/pong runs); V1/V2/V4
pair a variant with a stock peer on at least one side reachable only via
`exp0`'s negotiated channel, so `dc_pong=0` there is correct.

| # | flags (beyond mode/version) | exit | active | munge | cap | ice_restart | pad | apm | config | dc_pong |
|---|---|---|---|---|---|---|---|---|---|---|
| V1 | `--duration 20 --wasm-core $VARIANT --wasm-core2 NONE` | 0 | 1 | 2 | 3 | 2 | 3 | 1 | 1 | 0 |
| V2 | `--duration 15 --wasm-core2 $VARIANT` | 0 | 1 | 2 | 2 | 0 | 1 | 1 | 1 | 0 |
| V3 | `--duration 20 --wasm-core $VARIANT` | 0 | 2 | 3 | 6 | 2 | 6 | 2 | 2 | 10 |
| V4 | `--duration 30 --drop-rate 0.3 --delay 50-200 --wasm-core $VARIANT --wasm-core2 NONE` | 0 | 1 | 2 | 2 | 4 | 5 | 1 | 1 | 0 |

`active`/`munge`/`cap`/`ice_restart` match the 2.5 baseline row-for-row
(see the earlier "Validation results (Phase 2.5)" table) — no regression
from adding the protocol-substrate surfaces. `SetConfiguration failed` = 0
on all four rows.

### Variant matrix — 2.6 rows (V-A, V-B/C1, V-C2, new)

Same commands as Task 7 (re-run for the permanent record).

**V-A** — variant↔variant `exp0` dc ping/pong:
```
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0-pump --wasm-core $VARIANT --duration 20 --log-file ... --quiet
```
Exit 0. `variant: dc pong` count = **10** (threshold ≥6, PASS). Binary-path
confirmation: `CallCoreHost dc_send:.*binary bytes` count = **5** (one per
pong reply, sent via `dc_send {dataB64:...}` — see Deviations #3).

**V-B/C1** — variant caller vs stock callee (padding, APM, config knob,
stock non-interference):
```
$CLI --mode p2p --version 11.0.0-pump --version2 11.0.0 --wasm-core $VARIANT --wasm-core2 NONE --duration 16 --log-file ... --quiet
```
Exit 0. `variant: pad ` = **3** (≥1, PASS). `variant: apm applied` = **1**
(expect 1, PASS). `variant: config applied` = **1** (expect 1, PASS,
asserting the `pc_set_configuration` command path — see Deviations #4).
`SetConfiguration failed` = **0** (expect 0, PASS). `variant: dc pong` =
**0** (expect 0, PASS — `exp0` never opens against a stock peer, which has
no negotiated channel id 5 to match).

**V-C2** — `10.0.0` keepalive vs stock:
```
$CLI --mode p2p --version 10.0.0-pump --version2 10.0.0 --wasm-core $VARIANT --wasm-core2 NONE --duration 18 --log-file ... --quiet
```
Exit 0. `variant: keepalive` = **3** (≥2, PASS). `Bad incoming data hash` =
**0**, `Could not parse message` = **0** — the stock `EncryptedConnection`
peer accepts the ported V1 keepalive/service packets cleanly.

### Module size

```
wc -c bazel-bin/submodules/TgVoipWebrtc/{reference-core-abi1,variant-core-abi1}.wasm
```

| module | size (bytes) |
|---|---|
| `reference-core-abi1.wasm` | 996,205 |
| `variant-core-abi1.wasm` | 1,017,117 |

Growth vs. the Phase-2 reference-core baseline (801,204 bytes, the last
recorded measurement, predating both the 2.5 ABI rewrite and this phase):
+195,001 bytes (+24.3%), attributable to the cumulative effect of the 2.5
ABI surface plus this phase's `SignalingFraming` (V1 port + V2 gzip framing)
+ vendored `miniz` + `CoreBase64`, all compiled into both modules.

**Post-review size optimization (2026-07-03):** measurement showed ~86% of
the module was the wasm *name section* (debug symbols), not code. The
genrule now links with `-Wl,--strip-all` (codegen unchanged: still `-O2`,
i.e. byte-identical code to what the matrix above validated):

| module | size (bytes) |
|---|---|
| `reference-core-abi1.wasm` | 171,677 (−83%) |
| `variant-core-abi1.wasm` | 189,000 (−81%) |

Re-validated with the stripped modules: W1/W2/W5/W5c-loss exit 0, V-A
pongs = 10, P1 offer/answer MATCH. Cost: WAMR trap backtraces show function
indices instead of names (drop the flag locally when debugging a trap).

**Second step (2026-07-03, same day): `-Oz -flto` landed too** (wasm-ld
default LTO level — `--lto-O3` measured 8 KB *bigger*):

| module | size (bytes) |
|---|---|
| `reference-core-abi1.wasm` | 129,154 (−87% vs pre-strip) |
| `variant-core-abi1.wasm` | 137,041 |

gzip −9 wire size: 48,518 B. Codegen differs from the original matrix run,
so the wasm-affected rows were re-validated on these exact modules:
W1/W2/W3/W5/W5c-loss/W8 exit 0, V-A pongs = 10 (5 binary), V-C2
keepalives ≥ 2 with 0 decrypt errors, P1 offer/answer MATCH, P2 framing
invariants clean. Native rows are unaffected by wasm flags. Link-map
attribution of the remaining 129 KB: ReferenceCallCore+templates 27%,
wasi-libc 20%, json11 18%, miniz 16%, SignalingFraming 11% (measured on the
`-O2` build; proportions shift slightly under `-Oz`).

### iOS build-proof

```
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
  build --configurationPath build-system/appstore-configuration.json \
  --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
  --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Result: `Build completed successfully, 3769 total actions` —
`bazel-bin/Telegram/Telegram.ipa` produced, exit 0. No errors. This is the
first iOS-toolchain compile of the `:miniz` `cc_library` wired into
`TgVoipWebrtc`'s `deps` back in Phase 2.6's core-implementation task (see
Deviations #5) — it built clean with no BUILD-wiring fix required.

### Deviations

Recorded here per the plan's Step 8 requirement, collecting every
execution-time amendment discovered across this phase's tasks (not just
this validation task):

1. **`exp0` non-interference via negotiated channel, not in-band
   announcement.** The variant core's demo data channel `exp0` is created
   with `negotiated: true, id: 5` on both peers rather than relying on
   in-band `OnDataChannel` announcement. This is a stronger non-interference
   guarantee against a stock peer than the spec's original phrasing implied:
   a stock `InstanceV2ReferenceImpl` peer has no id-5 negotiated channel to
   match, so `exp0` simply never opens (V-B/C1: `dc_pong=0`), with zero risk
   of an unsolicited-channel code path being exercised on the stock side.
   `dc_channel` (the remote-announced-channel event) coverage instead comes
   from the standard `"data"` channel opening on the callee side in the
   ordinary (non-`exp0`) path.
2. **The "loss-path resend behavior is untestable in the lossless CLI" risk
   note (Risks/open items, above) is retired.** The CLI's `--drop-rate`/
   `--delay` flags apply to the signaling bridge, not just media — W5c
   (`10.0.0-pump` vs `10.0.0` stock, 30% drop, 50–200 ms delay, 30 s) proves
   the ported `SignalingFraming` V1 resend layer recovers signaling and
   establishes the call under loss against an unmodified stock peer. BL1
   (stock-stock under the same loss parameters) is the baseline confirming
   the end-state shape (`Reconnecting` on one side) is inherent to the loss
   scenario, not a framing-port regression.
3. **`exp0` pong replies are sent binary.** A coverage-driven amendment
   (added so the binary data-channel payload path is exercised end-to-end,
   not just compiled): pongs are base64-encoded and sent via
   `dc_send {label:"exp0", dataB64:...}` instead of a plain-text `data`
   field; pings remain text. Verified traversed (not just reachable) via
   the V-A row's `CallCoreHost dc_send:.*binary bytes` count = 5, matching
   `[exp0] N binary bytes` on the receiving side.
4. **The variant's `pc_set_configuration` demo uses
   `{"iceTransportsType": "all"}`, not the spec's
   `{candidatePoolSize: 2}`.** WebRTC deterministically rejects any change
   to `ice_candidate_pool_size` once `SetLocalDescription` has run at least
   once (`third-party/webrtc/webrtc/pc/peer_connection.cc`,
   `ValidateIceCandidatePoolSize`) — and the demo only fires from `onStats`,
   well after SLD, so the spec's literal field would fail on every run, not
   flakily. Caveat recorded honestly: in this phase's p2p-only validation,
   `iceTransportsType: "all"` is a no-op re-assertion (the reference core
   already requests `"all"` for P2P at `pc_create`), so V-B/C1 proves the
   **command path** (merge current config → `SetConfiguration` succeeds,
   `SetConfiguration failed` = 0) rather than a real state transition. A
   relay-mode run (no TURN server in the current CLI testbench — see Risks)
   would exercise an actual transition; tracked as a follow-up.
5. **Build amendments for miniz.** `miniz.c` is valid C but ill-formed C++,
   so it cannot join the module genrules' single `clang++` compile line —
   the wasm build does a two-step compile-object-then-link instead. On the
   native side, a dedicated `cc_library(":miniz")` (isolated `-std=c99`
   `copts`, mirroring the existing BoringSSL pure-C `cc_library` pattern) is
   wired into both native tgcalls targets' `deps` rather than adding
   `miniz.c` directly to their C++-flagged `srcs` lists.
6. **Known-untested surface: `dc_buffered` drain-to-0.** The ABI's
   `dc_buffered {label, bufferedAmount}` event (emitted when the SCTP send
   buffer drains to 0 after being non-empty) is implemented in
   `CallCoreHost` but no validation row in this phase exercises it —
   deliberately filling the SCTP send buffer would contradict this phase's
   control-plane-sized payload budget (dc traffic here is small ping/pong/
   keepalive messages, never enough to buffer). Recorded as an honest gap,
   not silently dropped.

### Backlog (from final whole-branch review)

- (b) `coreGunzipData`/`coreIsGzip` DRY — de-duplicate shared logic.
- (c) gzip ISIZE trailer unvalidated + zlib-branch adler32 skipped
  (`CoreGzip.cpp`).
- (e) V2 gzip-failure path diverges from stock (practically unreachable).
- (f) invented gzip-failure log strings (not load-bearing).
- (h) incoming decrypt-failure silent to core + replay-drops logged as
  decrypt errors (log-taxonomy: distinguish before anyone greps "could not
  decrypt" on lossy runs).
- (j) dc label-default duplication.
- (k) dc registry never erases mid-call — add invariant comment if teardown
  ever added.
- (m) `executePcCreate` tail applies APM after failed PC creation.
- (n) `pc_set_configuration` demo is a p2p no-op re-assertion — real-mutation
  demo needs a relay/TURN testbench mode.
- (#2) `executeDcSend` doesn't enforce "exactly one of data/dataB64" (ABI
  says exactly one — add error branch or soften wording).
- (#5) `inflateBounded` allocates the full 2 MiB bound per inflate
  (incremental sizing possible).
- (#7) host's "counter <= kMaxAllowedCounter" check is definitionally
  vacuous post-mask — add a comment.

## Post-phase amendment (2026-07-03): compression as a host service

User-directed follow-up after the size work: the compression *codec* moved
from the module to the host, as two new ABI imports. Rationale: it is pure
mechanism (bytes in → bytes out, no policy content — WHETHER and WHAT to
compress stays core policy in the V2 framing), it was 16% of the module, and
serving it from the host's zlib makes the wasm core's compressed output
byte-identical to stock (the vendored-miniz build emitted valid-but-different
deflate streams).

**ABI delta (v1, broken in place):** the module form gains imports
`env.host_deflate(in, in_len, out, out_cap) -> i32` and `env.host_inflate`
(same shape); C form `tgcalls_host_deflate`/`tgcalls_host_inflate` declared
in `CallCoreABI.h` (bound to the imports under `__wasm__`, implemented
natively by the new harness-side `v2wasm/HostCompressionService.cpp` over
`utils/gzip`). Returns bytes written or −1; `out_cap` doubles as the
caller-chosen inflate size limit (zip-bomb bound). WAMR validates both
buffer ranges (`"(*~*~)i"`). `CoreGzip.{h,cpp}` keeps its API (so
`SignalingFraming` is untouched) but is now a thin shim; the vendored miniz
(`third-party/miniz/`) and its `:miniz` cc_library are removed.

**Sizes:** reference module 129,154 → **92,741 B**, variant 137,041 →
**100,814 B** (−28%); gzipped wire size 48,518 → **34,360 B**. Cumulative
vs. the Phase-2.6-as-landed modules: 996,205 → 92,741 (−91%).

**Validation (re-run on both substrates):** W1/W2/W3/W5/W5c-loss/W8-loss +
NR1 all exit 0; V-A pongs = 10 (5 binary), V-B/C1 pad = 3 / apm = 1 /
config = 1 / 0 failures, V-C2 keepalives = 2 with 0 decrypt errors; P1
offer/answer MATCH; P2 framing invariants clean. This retires backlog items
(c) (gzip ISIZE/adler32 gaps — that code no longer exists core-side; the
host zlib verifies both) and (#5) (the 2 MiB `inflateBounded` allocation —
the core now allocates the output buffer once and the host inflates into it
directly). Trade-off note: the host codec is fixed function — a variant
module can no longer swap the compression *algorithm* (it can still choose
not to compress, or wrap its own encoding inside the body); if a future
experiment needs a custom codec, it ships its own compressor in-module,
which is exactly what the removed miniz path demonstrated is possible.
