# Rust MTProto engine on iOS, part 2: host transport

Date: 2026-10-02. Status: design approved in conversation, spec awaiting review.
Builds on part 1, `2026-10-02-ios-rust-mtproto-bringup-design.md` (goal, decisions, dogfood gate).

## Goal

Let the Rust engine carry a connection over an `MTTcpConnectionInterface` supplied by the app,
exactly where MtProtoKit does, so that on iOS the engine works over Network.framework
(`NetworkFrameworkTcpConnectionInterface`, the default for beta builds) and over the WEB proxy
carrier (`WebProxyConnectionInterface`). Today the engine always opens its own sockets, ignores
the Network.framework setting, and the factory declines a WEB proxy (integration gap 3, risk 4).

Success: on an iOS beta build with the switch on, every main-app connection that MtProtoKit would
route through an injected interface is routed through the same interface by the Rust engine, the
WEB proxy works on Rust (including switching it on and off while running), and cellular bytes are
still counted under Mobile.

## Decision: mirror MtProtoKit's transport selection (option B)

The engine uses its own `mio` sockets when `context.makeTcpConnectionInterface` is nil and the
injected interface when it is set. Rejected alternative (A): every iOS connection through the
host interface, wrapping `MTGcdAsyncSocketTcpConnectionInterface` when nil. Reasons for B:

- It is MtProtoKit's own rule, so the existing `Network X [Restart App]` switch means the same
  thing under both engines and engine comparisons stay like-for-like.
- The iOS default stays the engine's most-exercised path: own sockets are every macOS user's
  default and what the fuzz, soak and bench suites drive. A would make iOS's only path one that
  exists nowhere else, and would lose the `SO_NWRITE` outbound backlog and the `local_addr`
  cellular detection on iOS.
- Both paths still see real-world use: iOS beta dogfooders exercise the host path
  (Network.framework is their default); macOS and non-beta iOS builds exercise own sockets.
- Cellular accounting is not a reason for A: it already works on own sockets (`72d7e51f95`).

## Measured facts this design rests on

- The engine reads in push style: `Connection::read_chunk` reads whatever is available into a
  256 KiB (64 KiB when shrunk) reactor scratch buffer (`worker.rs:113`, `:205-207`) and feeds the
  incremental parsers; download progress comes from the partially buffered frame
  (`pending_frame_head`, `session_runtime.rs:1106-1130`). `MTTcpConnectionInterface` only offers
  exact-length reads (`readDataToLength:withTimeout:tag:`).
- `NetworkFrameworkTcpConnectionInterface` already reads with
  `receive(minimumIncompleteLength: 1, maximumLength:)` internally
  (`NetworkFrameworkTcpConnectionInterface.swift:331`).
- Interfaces count bytes themselves when given `usageCalculationInfo`
  (`NetworkFrameworkTcpConnectionInterface.swift:101-105, 263, 354`); the engine also emits
  `NetworkUsage` events that the wrapper books. Using both would double-count.
- `Network.updateProxySettings` swaps `context.makeTcpConnectionInterface` **before** it calls
  `context.updateApiEnvironment` (`Network.swift:977-990`), so a listener of
  `contextApiEnvironmentUpdated` already sees the new factory.
- `MTTcpConnection` pairs the carrier with the WEB proxy setting and fails closed otherwise
  (`MTTcpConnection.m:1001-1035`), and resolves nothing for a WEB proxy, because any lookup of the
  relay hostname would leak it off the proxy (`MTTcpConnection.m:1046-1056`). The engine resolves
  proxy hostnames with `getaddrinfo` (`resolver.rs`, called from `worker.rs:66`).
- Sessions are owned by one worker thread each, and commands are routed to the owning worker by
  `SessionHandle` through a channel plus `mio::Waker` (`lib.rs`, `worker.rs`).

## Design

### 1. Engine: a host-stream socket

- `Connection` (`mtproto-engine/src/connection.rs`) gets `enum Socket { Os(mio::net::TcpStream),
  Host(HostStream) }`. Everything above it is unchanged: `TransportStream` (abridged,
  intermediate, padded intermediate, obfuscated2, fake-TLS), the SOCKS5 handshake, connection
  racing, address failover, progress, timers. SOCKS5 and MTProxy work over a host stream as
  MtProtoKit does them over an injected interface: the engine dials the proxy's host and port
  through the host stream and runs the protocol itself.
- A session's transport mode is set with `mt_session_set_host_transport(engine, session, enabled)`.
  It applies to the next connection attempt; setting it closes the current connection, as
  `mt_session_set_proxy` does.
- **No name resolution on the host path.** A host-mode session never calls `resolve_blocking`;
  `open` receives the address string as configured, an IP literal as is and a hostname
  unresolved, and resolution (if any) is the interface's business.
- `HostStream` state: `conn_id`, phase (opening / connected / closed), a queue of received chunks,
  whether a read is outstanding, and the `cellular` flag of the latest chunk.
- Mapping onto the existing state machine: `connected` ≙ writable-after-connect; `received` ≙
  readable + read (the chunk is fed through the same code path as a socket read); `closed` ≙ EOF
  or I/O error. Writes are handed to the host immediately and never would-block.
  `outbound_backlog()` returns `None` for a host connection, which the session already handles
  (non-Apple builds return `None`). Connect timeouts stay on the engine's own timers.

### 2. C ABI (version 1 → 2)

Engine → host. A callback table installed once per engine with
`mt_engine_set_host_transport(engine, context, const MTHostTransportCallbacks *)`, called on the
session's reactor thread; implementations must not block. Re-entrant calls into the engine are
allowed (they only enqueue commands).

| Callback | Meaning |
|---|---|
| `open(context, session, conn_id, host, port)` | create a connection to `host:port` |
| `write(context, session, conn_id, bytes, length)` | send; the host copies the bytes |
| `read(context, session, conn_id, max_length)` | deliver at most `max_length` bytes once; at most one outstanding read per connection |
| `close(context, session, conn_id)` | tear down; no further host → engine calls for this id are needed |

Host → engine. Callable from any thread, queued to the owning worker by `session`:

| Function | Meaning |
|---|---|
| `mt_host_connected(engine, session, conn_id)` | the stream is connected |
| `mt_host_received(engine, session, conn_id, bytes, length, cellular)` | data for the outstanding read; the engine copies the bytes |
| `mt_host_closed(engine, session, conn_id, error)` | the stream ended (0 = clean EOF) |

Rules:

- `conn_id` is a `u64` from a per-engine counter and is never reused. Host → engine calls for a
  closed or unknown `conn_id` are ignored, which makes late NWConnection callbacks harmless.
- The one-outstanding-read rule is the back-pressure: a slow worker stops asking instead of
  buffering without bound.
- A host-mode session on an engine without an installed table fails its connection attempts and
  logs; it never falls back to a socket.
- `mt_engine_abi_version()` returns 2; the wrapper requires 2. The macOS xcframework is built from
  the same tree.
- The safe-Rust engine crate defines a `HostTransport` trait; the C function pointers and the
  `unsafe` stay in `mtproto-ffi`, as for the existing callbacks.

### 3. Swift: transport policy

A pure helper in `MTProtoRustEngineMapping` decides the path:

| apiEnvironment proxy | `context.makeTcpConnectionInterface` | Engine path |
|---|---|---|
| not WEB | nil | own sockets |
| not WEB | set, not the carrier (Network.framework) | host |
| WEB | set and `isWebProxyCarrier` | host, through the carrier |
| WEB | anything else | fail closed: held paused, reported as connecting with proxy issues |
| not WEB | the carrier | own sockets; the carrier never carries a real address |

- **iOS only.** On macOS the helper always answers own sockets, and the WEB proxy decline stays.
  Rust is the macOS default engine; adopting the host path there is a separate decision.
- Evaluated at session creation and in `contextApiEnvironmentUpdated` (which follows the factory
  swap, see measured facts; this ordering is load-bearing and is commented at both sites).
  Re-checked at every `open`: a mismatch fails that attempt and updates the session's mode, so the
  engine reconnects on the right path.
- `RustNetworkEngineFactory` stops declining a WEB proxy on iOS, and the wrapper's
  `holdForUnsupportedProxy` becomes "route through the carrier" on iOS. That removes
  integration risk 4 (Rust sessions disconnected until restart after choosing a WEB proxy).

### 4. Swift: the adapter

`RustHostTransport.swift` (new, in `MTProtoRustEngine`), installed when `RustEngineRuntime` starts.

- `open(session, conn_id, host, port)`: look up the session's `MTContext` through the runtime's
  session table; create the interface with `context.makeTcpConnectionInterface(delegate, queue)`
  on a **per-connection** serial queue (MtProtoKit uses one shared `tcpQueue`; a per-connection
  queue keeps a large download from delaying the main session); apply the pairing check from §3;
  `setUsageCalculationInfo(nil)`; `connectToHost(host, onPort: port, viaInterface: nil, ...)`.
- `read` → `readAvailableData(maxLength:)`. `connectionInterfaceDidReadData(_:withTag:networkType:)`
  → `mt_host_received(..., cellular: networkType != 0)`. The partial-read callback is ignored.
- `write` → `writeData`. `close` → `disconnect()` then `resetDelegate()`, and the entry is
  removed. `connectionInterfaceDidConnect` → `mt_host_connected`.
  `connectionInterfaceDidDisconnectWithError` → `mt_host_closed`.
- **One byte counter:** interfaces get no `usageCalculationInfo`; the engine's `NetworkUsage`
  events, with `cellular` taken from the host's `networkType`, are the only accounting.

### 5. MtProtoKit and the interfaces

- `MTTcpConnectionInterface` (`MtProtoKit/PublicHeaders/MtProtoKit/MTContext.h`) gains
  `@optional - (void)readAvailableDataWithMaxLength:(NSUInteger)maxLength timeout:(NSTimeInterval)timeout tag:(long)tag;`,
  answered through the existing `connectionInterfaceDidReadData:withTag:networkType:` with 1 to
  `maxLength` bytes.
- Implemented by `NetworkFrameworkTcpConnectionInterface` (`receive(minimumIncompleteLength: 1,
  maximumLength:)`) and `WebProxyConnectionInterface` (whatever the carrier has buffered, else the
  next arrival). Under option B these are the only interfaces the engine is ever handed.
  `MTGcdAsyncSocketTcpConnectionInterface` does not need it.
- `MTTcpConnection` keeps using `readDataToLength`; MtProtoKit's behaviour is unchanged.
- An interface that does not implement the method fails the connection (and asserts in debug).

## Testing

Rust (cargo):

- A test host transport in `mtproto-engine/tests` implementing the callback table over real TCP
  to `mtproto-testserver`. The existing scenarios run under both own sockets and host:
  exactly-once delivery after dropped connections; SOCKS5, MTProxy and fake-TLS; pause/resume;
  connection racing; idle disconnect; progress events.
- Host-specific faults: 1-byte and maximum-size chunks; `received`/`closed` after `close`;
  duplicate `connected`; `closed` before `connected`; `close` with a read outstanding; `open` never
  answered (connect timeout); host calls from several threads.
- No-resolution: a hostname proxy on the host path reaches `open` verbatim and the resolver is not
  called.
- `mtproto-fuzz`: a `host_stream` target driving random chunking and event order, under the
  existing invariants (no panic, no forged packet accepted, exactly-once).
- `mtproto-ffi/tests/ffi.rs`: the clang-compiled layout check covers the new structs; ABI 2.

Swift:

- Host `swift_test`: the policy table (all five rows, plus macOS always own sockets).
- `instancesRespond(to:)` pins of `readAvailableDataWithMaxLength:timeout:tag:` on both
  interfaces (a misspelled Swift name for an optional ObjC method compiles and is never called).
- `WebProxyConnectionInterface.readAvailableData` in `WebProxyTransport`'s tests.

Bench:

- The TelegramCore bench client gains `--transport host`, which installs
  `NetworkFrameworkTcpConnectionInterface` (macOS 14+) and lets the bench bypass the iOS-only gate.
  The quick, hostile and torture suites run on the host path, compared against MtProtoKit over the
  same interface.

Manual (iOS beta build, the user installs and drives):

- `Engine: rust`; normal use.
- WEB proxy on Rust, including switching it on and off while running; the log shows no lookup of
  the relay hostname.
- SOCKS5 over Network.framework.
- On a device on cellular, Settings ▸ Data Usage counts under Mobile.

Done: all of the above pass; then the dogfood gate in part 1 applies.

## Docs

- `swift-integration.md`: the host path, the policy table, ABI 2, and gap 3 / risk 4 closed on iOS.
- CLAUDE.md (the part 1 section): host-path pairing, no resolution on the host path, one byte
  counter, factory swap before `updateApiEnvironment`.

## Out of scope

- The host path on macOS.
- Reporting an outbound backlog from host interfaces.
- MtProtoKit's DNS-over-HTTPS for proxy hostnames.
