# WEB proxy carrier

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## WEB proxy carrier (`tg://webproxy`)

A third proxy kind beside SOCKS5 and MTProxy. MtProtoKit's obfuscated2 transform runs
unchanged; what changes is only where the transformed TCP stream goes — each MTProto
connection becomes a logical stream multiplexed over a hidden `WKWebView` that speaks
HTTPS/WSS to a `tproxy-server` relay, which converts each stream back into one TCP
connection to a stock MTProxy. The relay therefore cannot pick a destination or decrypt
anything. The wire contract is upstream and client-neutral
([`PROTOCOL.md`](https://github.com/telegramdesktop/tproxy-server/blob/master/PROTOCOL.md),
with `IOS.md`, `BASE_PATH.md` and `HARDENING.md` beside it); the client half is
`submodules/WebProxyTransport` plus the `ProxySettings`/`SettingsUI`/`UrlHandling` wiring.

The non-obvious parts:

- **The loopback address never leaves MtProtoKit.** `MTSocksProxySettings.webProxy` is the
  whole hook: `MTTcpConnection` substitutes `127.0.0.1:443` at dial time while `ip` keeps
  the **public** hostname. So proxy identity, sponsored-channel attribution, and
  `ProxyServerPreviewScreen`'s "wait until the account reports online through this address"
  check all keep working, and the loopback endpoint is never displayed or shared.
- **One process-wide carrier**, `WebProxyTransport.shared`. It runs exactly while a
  configuration is present *and* someone holds demand (`setCarrierDemand(_:wanted:)`,
  idempotent per token). Demand rides `shouldKeepConnection`, i.e. the app's existing
  foreground/background/service-task machinery — that is how IOS.md's foreground-only
  lifecycle is met without a background mode or a timer of our own. `Network.swift` also
  refuses the carrier outright when the main bundle ends in `.appex`.
- **The web view must be in a real view hierarchy** or WebKit throttles off-screen work and
  the long poll stalls with no error. The transport cannot reach the hierarchy itself —
  TelegramCore depends on it and is shared with Telegram-Mac, so nothing in the module may
  import UIKit — hence `WebProxyCarrierViewHost`, implemented by
  `TelegramUI/Sources/WebProxyCarrierWindowHost.swift` as a 1pt, noninteractive,
  `alpha = 0.01` view at the bottom of the root container. Zero alpha is *not* equivalent.
- **Base-path relays.** `.web(secret:path:)` encodes as `_t = 3` only when the path is
  non-empty; `_t = 2` stays byte-identical for existing root records. The bridge capability
  binds the path: context `…-v1\nH` at the root, `…-v2\nH\nP` under a prefix, so one
  capability authenticates nothing at another prefix. The path is **case-sensitive** and
  never folded, unlike the host. The editor has one "server" field holding the whole
  `host/base-path` address (`canonicalWebProxyAddress`), and the list row drops the port
  for a WEB entry because 443 is implied.
- **The `0x70` marked secret.** A link that carries a base path *must* encode its secret as
  unpadded base64url of `0x70 || secret`; an unmarked secret there is **rejected**, so no
  link exists that a client without base-path support would silently accept as a pathless
  proxy on an empty host. Never `0xDD` — an older parser reads that as an ordinary padded
  secret. Enforced in `parseWebProxyLinkComponents`, which every link entry point (QR,
  pasteboard, `tg://`/`t.me` handling) goes through; hand entry in the editor stays lenient
  on purpose, because the hazard is specific to a shared link.
- **The carrier's `WKWebView` is hardened on its own and must never share anything** with
  Mini Apps, payments, 3-D Secure, Instant View embeds or the location picker: its own
  configuration, nonpersistent store and user-content controller per carrier lifetime.
  `WebProxyWebViewHardening` installs **two** document-start scripts in order — the
  execution profile, then the bridge shim. The profile goes into **every frame**; the shim
  stays main-frame-only because it is the half that reaches native. That split is measured,
  not assumed (`WebProxyFrameIsolationTests`): under the profile's own CSP a page can still
  append a src-less `about:blank` iframe — `frame-src 'none'` does not stop it, the initial
  about:blank being no fetch — and with a main-frame-only profile that child's
  `navigator.geolocation`, `Worker` and `BroadcastChannel` all came back pristine. The
  shim refuses to expose
  `TelegramWebProxy` unless the profile's flag says it is in place; construction itself
  fails closed if the scripts did not install, so a carrier without the policy never
  navigates. A different operator controls the proxy document, which is why the client
  imposes an independent meta CSP rather than trusting the response's own.
- **The meta CSP creates `document.head` when the parser has not reached it yet.** WebKit
  honours a `<meta>` policy only inside `document.head`, defined as the *first* head child
  of `<html>`, so the injected head becoming that first head is load-bearing — the parser's
  own head then lands after it as a second head element.
- **Geolocation has no public refusal below iOS 27.** `WebPageProxy::requestGeolocationPermissionForFrame`
  falls through `UIDelegate` (which returns with the handler intact when the app implements
  no geolocation method) to `PageClientImpl`, which on iOS *always* consumes it — so the
  `completionHandler(false)` at the end of that function is unreachable there. It lands in
  `WKWebGeolocationPolicyDecider`, which presents a `UIAlertController` on the view's
  **full-screen presentation context**, needs no user gesture, and auto-allows an origin
  after `kGeolocationChallengeThreshold` (2) grants recorded in `GeolocationSitesV2.plist`.
  The public `requestGeolocationPermissionFor` delegate (iOS 27+) denies it; below that the
  all-frames `navigator.geolocation` shim is the block, and the private SPI is deliberately
  not used. Do not describe the shims as the boundary anywhere else — here they are it.
- Calls stay SOCKS5-only (a WEB entry is never offered), and `ProxyServersStatuses` never
  pings an inactive WEB row: it would read "checking…" forever, so the row shows
  "not tested" and only the active one follows the real account connection state.
