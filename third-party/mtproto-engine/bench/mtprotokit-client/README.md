# MtProtoKit benchmark client

`mtprotokit-bench` drives Telegram's Objective-C MtProtoKit the way TelegramCore does and implements the
benchmark contract in [`docs/bench/client-spec.md`](../../docs/bench/client-spec.md), so the orchestrator
(`mtproto-bench run --mtprotokit <path>`) can run it head to head with the Rust engine's client
(`mtproto-bench client`). Both are separate processes measured the same way (`wait4`).

Nothing in MtProtoKit, EncryptionProvider, OpenSSLEncryptionProvider or TelegramCore is modified; the
package links them from `submodules/` as SwiftPM path dependencies.

## Build

```sh
cd third-party/mtproto-engine/bench/mtprotokit-client
swift build -c release
# binary: .build/release/mtprotokit-bench
```

OpenSSL's `libcrypto.a` (needed by `OpenSSLEncryptionProvider`) is taken from the macOS app checkout,
`<telegrammacos>/core-xprojects/openssl/build/openssl/lib/libcrypto.a` (a universal arm64/x86_64 static
library), located relative to `Package.swift`. Point `MTPROTOKIT_BENCH_LIBCRYPTO` at another `libcrypto.a`
when building elsewhere.

SwiftPM's release configuration compiles the Objective-C sources with `-O2` and `NSAssert` enabled.
The app's Xcode Release build uses `-Os` and `ENABLE_NS_ASSERTIONS = NO`. To match that more
closely, build with

```sh
swift build -c release -Xcc -Os -Xcc -DNS_BLOCK_ASSERTIONS=1
```

In our runs the difference was within run-to-run noise. Both variants are valid; use one variant
consistently in a comparison.

## Run

Fake mode, against the test server:

```sh
cd third-party/mtproto-engine
cargo build --release -p mtproto-testserver
./target/release/mtproto-testserver            # prints {"address","key_hex","salt"}; `stats`, `quit` on stdin
bench/mtprotokit-client/.build/release/mtprotokit-bench \
    --engine-label mtprotokit --mode fake --address 127.0.0.1:PORT --dc 2 \
    --key-hex KEY --salt SALT --workload small --requests 3000 --concurrency 128 --deadline 60
```

Add `--secret HEX` (and start the server with the same `--secret`) to go through MTProxy (`dd…`
padded intermediate or `ee…` fake TLS).

Real mode (the client runs MtProtoKit's own DH handshake with its built-in production RSA key):

```sh
mtprotokit-bench --mode real --address 149.154.167.51:443 --dc 2 \
    --workload real-config --requests 5 --concurrency 1 --deadline 60
```

Through the orchestrator:

```sh
cargo run --release -p mtproto-bench -- run --mtprotokit bench/mtprotokit-client/.build/release/mtprotokit-bench --suite quick
```

Arguments, workloads, call encoding and the output line are exactly those of the contract. One extra,
optional argument exists: `--temp-keys 0|1` (real mode only, default `0`, see below). Environment:

| Variable | Effect |
|---|---|
| `MTPROTOKIT_BENCH_LOG=1` | MtProtoKit logging enabled and written to stderr, plus session state changes |
| `MTPROTOKIT_BENCH_NO_LOG_SINK=1` | do not register MtProtoKit logging functions at all (not production-like, see below) |

stdout carries exactly one line, the JSON report. File descriptor 1 is redirected to stderr at
startup, so nothing a library prints can end up on stdout. A one-line summary goes to stderr, along with
the first five request failures (all of them with `MTPROTOKIT_BENCH_LOG`). The exit code is 0 whenever a
report is printed, including when requests failed.

## How MtProtoKit is set up, and the production code it mirrors

TelegramCore references are under `submodules/TelegramCore/Sources/Network/`.

| Piece | Bench | Production |
|---|---|---|
| `MTContext` | `MTContext(serialization:encryptionProvider:apiEnvironment:isTestingEnvironment: false, useTempAuthKeys:)` with `OpenSSLEncryptionProvider` | `initializedNetwork` in `Network.swift` |
| `MTSerialization` | `currentLayer` = 230. `parseMessage` boxes the raw body (nil only for <4 bytes). `exportAuthorization`/`importAuthorization`/`requestNoop` encode the real TL; `requestDatacenterAddress` encodes `help.getConfig` and its parser returns nil (the fake server has no config) | `State/Serialization.swift` (`Api.parse`) |
| `MTApiEnvironment` | `MTApiEnvironment(deviceModelName:)`, `apiId` 9, `appVersion` "1.0", `langPack` "macos", `layer` 230, `disableUpdates` false, `withUpdatedLangPackCode("en")`, `withUpdatedNetworkSettings(reducedBackupDiscoveryTimeout: false)` | same calls in `initializedNetwork` |
| MTProxy | `withUpdatedSocksProxySettings(MTSocksProxySettings(ip: host, port: port, username: nil, password: nil, secret: secretBytes))`; the DC 2 address is then `149.154.167.51:443`, as in the Rust client | `ProxyServerSettings.mtProxySettings` (`Settings/ProxySettings.swift`) |
| Addresses | `setSeedAddressSetForDatacenterWithId(2, [--address])` | seed list, port 443 |
| Keychain | in-memory `MTKeychain` that archives with `NSKeyedArchiver` and reads with `MTDeprecated.unarchiveDeprecated`, like TelegramCore's `Keychain` | `Keychain` class in `Network.swift`, backed by Postbox |
| Fake-mode key | `updateAuthInfoForDatacenterWithId(2, selector: .persistent)`: the `--key-hex` key, `authKeyId` = last 8 bytes of `MTSha1(key)` read little-endian (exactly what `MTDatacenterAuthMessageService` stores), `validUntilTimestamp` = `INT32_MAX`, one `MTDatacenterSaltInfo` with `--salt` valid from now−1 day to now+1 day (`seconds << 32`), no attributes, so the first request carries `initConnection` | key created by the handshake |
| Main session | `MTProto(context, 2, usage, requiredAuthToken: nil, master: 0)`, `useTempAuthKeys = context.useTempAuthKeys`, `checkForProxyConnectionIssues = true`, an `MTProtoDelegate` connection-status delegate, `MTRequestMessageService` with delegate and `didReceiveSoftAuthResetError`, an update-sink `MTMessageService`, then `resume()` | `MtProtoKitSession` role `.main` (`MtProtoKitEngine.swift`), resumed by `shouldKeepConnection` |
| Worker sessions (`media`/`mixed`) | one `MTProto` per worker (its own session and TCP connection): `media = true`, `cdn = false`, `useTempAuthKeys = context.useTempAuthKeys`, `getLogPrefix`, no required auth token (DC 2 is the master DC), `MTRequestMessageService.forceBackgroundRequests = true` (`invokeWithoutUpdates`), request-service delegate, then `resume()` | `MtProtoKitSession` role `.worker(masterDatacenterId:isMedia: true, isCdn: false)` created by `Download` / `Network.download(datacenterId:isMedia:)` |
| Small calls | `dependsOnPasswordEntry = false`, `needsTimeoutTimer = false`, `expectedResponseSize = 0`, `shouldContinueExecutionWithErrorContext` = `networkRequestErrorPolicy(automaticFloodWait: true, failOnServerErrors: false)` (always true, so FLOOD_WAIT and 500 are retried inside MtProtoKit), no quick-ack, progress or dependency callbacks | `Network.request` (`NetworkEngineRequestOptions()`) → `MtProtoKitRequestService.add` |
| Media parts | same, plus `expectedResponseSize = --part-size` and `needsTimeoutTimer = true` | `Download.part` / `Download.rawRequest` via `MultiplexedRequestManager` (`expectedResponseSize: limit`, `needsTimeoutTimer: useRequestTimeoutTimers`, which `Account.swift` sets to true unless `ios_killswitch_disable_request_timeout`) |
| Logging | MtProtoKit logging functions registered, `MTLogSetEnabled(false)` | `NetworkRegisterLoggingFunction()`; logs off unless the user enables them. Registering the functions matters: `MTShortLog` formats strings for every outgoing message whenever a function is registered |
| Usage accounting | `MTNetworkUsageCalculationInfo` per session with a `network-stats` file in a temp directory, same key layout (generic category for main, video for workers) | `usageCalculationInfo(basePath:category:)` |

MtProtoKit's defaults are left alone: containers, acks, padding, transport choice (obfuscated abridged,
padded intermediate for `dd`/`ee`), GCDAsyncSocket socket interface, actualization pings, resend and
salt handling. All `MTProto` instances share MtProtoKit's process-wide `managerQueue` and `tcpQueue`,
as in the app.

Each response is checked as the contract requires (tag; tag 1012 and payload length for sized calls;
any non-error body of at least 4 bytes in real mode). The parser copies the payload out of the response,
as both TelegramCore's TL parser and the Rust client do. A failed check, an `MTRpcError`, or a request
still pending at `--deadline` counts as failed.

The workload loops follow the Rust client (`crates/mtproto-bench/src/client.rs`): same tags
(`1 + index % 900`), same 8-byte request-index payload, same issue order and outstanding limits, and the
same `getConfig`/`getNearestDc` alternation. Waits are capped at 100 ms (`latency`, `small`,
`real-config`), 10 ms (`media`, `mixed`) and 5 ms (`steady`), as in the Rust client. The driver also wakes
up for the next scheduled probe or `steady` request, so issue times are on schedule rather than up to one
wait late. The driver runs on its own thread and waits on a condition variable that request completions
signal. Completions run on MtProtoKit's `managerQueue`, as in the app. The main thread runs
`dispatchMain()` so main-queue work behaves as in an application. Timestamps come from the monotonic
uptime clock.

## Differences from production that cannot be avoided or were chosen on purpose

1. **No TelegramCore above MtProtoKit.** There are no Signals, no `MultiplexedRequestManager` and no
   `retryRequest`. TelegramCore's `Download.part` retries a failed part forever at the Signal level. The
   contract wants failures counted, so the bench does not retry. Retries that MtProtoKit does internally
   (flood wait, 500, resend after reconnect, request timeout reset) do happen.
2. **No temporary keys by default.** Production sets `useTempAuthKeys = true` (a temp key per
   connection, bound with `auth.bindTempAuthKey`). The fake server cannot bind temp keys, so fake mode
   uses the persistent key. In real mode the default is also persistent-only, because the Rust reference
   client does not create temp keys (`temporary_expires_in: None`) and the handshake work should be
   equal. `--temp-keys 1` turns on the production behaviour: one more DH handshake plus a bind before the
   first request.
3. **Real-mode handshake shape.** MtProtoKit runs the DH exchange on a separate throwaway `MTProto`
   with its own TCP connection. The main session then reconnects and sends a time-fix ping, which the
   server answers with `bad_server_salt`. Only after that does it send the first request. That is
   three TCP connections and an extra round trip before the first answer (about 1.6 s to DC 2 in our run).
   This is MtProtoKit's real behaviour, but count it when comparing first-request latency.
4. **No `initConnection` params.** Production sends `systemCode` (app config JSON, `initConnection`
   flag 1) once it has app configuration. The fake server cannot parse JSON params, so the bench sends
   none, and the Rust client sends none either. `systemLangCode` and `systemVersion` come from the host
   (`en-GB`, `26.4`) because `MTApiEnvironment` reads them itself. They are a few bytes in the first
   request only.
5. **Not wired up:** backup address discovery (DoH), APNS and reCAPTCHA verification, the
   `NetworkHelper` context listener (`isContextNetworkAccessAllowed` therefore defaults to allowed, and no
   CDN keys), the Network.framework socket interface (beta builds on macOS 14+ only), the WEB proxy carrier,
   and Postbox-backed keychain I/O. Except for keychain I/O, these only act on connection problems or in
   other configurations. Under long fake outages production would also start backup discovery, and the
   bench does not.
6. **Compiler flags.** See the build section above.
7. **Process startup is part of the measurement.** Swift runtime, Foundation, OpenSSL and MtProtoKit
   start-up count toward CPU time and RSS. The cost is small (about 10 MB RSS, a few ms of CPU).

## Notes from validation (2026-10-01)

- Every workload passed in fake mode, both direct and through an `ee` fake-TLS secret. Real mode
  passed against `149.154.167.51:443`.
- **Fake TLS needs a server fix.** MtProtoKit's current ClientHello template (Chrome-like, with an
  X25519MLKEM768 key share) is about 1.5 KB; we saw 1520 and 1534 bytes. `mtproto-testserver` reads
  exactly `CLIENT_HELLO_LEN` (517) bytes and checks the HMAC over those, so it closes every MtProtoKit
  fake-TLS connection: `connections` keeps growing, `executions` stays 0, and every request fails at the
  deadline. Real MTProxy servers read the record length. The fix is to read the 5-byte record header, then
  the record's length, and compute the HMAC over the whole record with bytes 11..43 zeroed. The validation
  runs used a scratch copy of the server with that change.
- MtProtoKit's fake-TLS path is CPU-heavy: about 2.4 s of CPU for 128 MiB, against 0.36 s without TLS.
  Throughput through the fake server drops from about 730 MB/s to about 240 MB/s. This is MtProtoKit's
  own cost.
- At high throughput, peak RSS grows with the amount downloaded: about 106 MB at 32 MiB, 200 MB at
  128 MiB and 373 MB at 512 MiB on fake `media`. Most of MtProtoKit's `managerQueue`/`tcpQueue` code
  runs without its own `@autoreleasepool`, so autoreleased buffers stay alive until GCD drains the worker
  thread's pool. The bench's own allocations do not account for this growth.
