# Apple entitlement request — `com.apple.developer.usernotifications.filtering`

**Where to submit:** https://developer.apple.com/contact/request/notification-service
(sign in with the **Vipads MCHJ** Apple ID — `vipadsllc@gmail.com` — the Account Holder must submit it)

**Identifying info to fill in:**

| Field | Value |
|---|---|
| App name | Novagram |
| Bundle ID | `uz.fenixuz.app` (app), `uz.fenixuz.app.NotificationService` (the notification service extension that needs the entitlement) |
| Team ID | `ZDBP5RSRZF` (Vipads MCHJ) |
| App Store ID | `6768202244` |
| Current version | 12.9.7 |
| Approx. active users | ~260,000 |
| Platform | iOS / iPadOS |

---

## Short version (use if the form limits the text)

Novagram (App Store ID 6768202244) is an end-to-end encrypted messaging app with voice and video calls.
All remote notifications — messages and incoming calls alike — arrive as regular `alert` pushes whose
payload is encrypted with a key that exists only on the device, so only our Notification Service
Extension (`uz.fenixuz.app.NotificationService`) can tell whether a push is a message or a call.
This is exactly the architecture in your article "Sending End-to-End Encrypted VoIP Calls": after
decrypting a call, the extension calls `CXProvider.reportNewIncomingVoIPPushPayload(_:completion:)`.
Without `com.apple.developer.usernotifications.filtering` iOS rejects that call
(`CXErrorDomainNotificationServiceExtension` code 2), so an incoming call never reaches CallKit while
the app is not in the foreground: the callee's phone does not ring and the call is missed. This is the
most serious problem reported by our ~260,000 users. We also need the entitlement to silence service
pushes (read receipts, deletions) that carry no user-visible content. We will never use it to hide
real messages, and we do not send notification content to any server.

---

## Request text (full version — paste into the "describe your use case" field)

Novagram is an end-to-end encrypted messaging app for iOS with text messaging and voice/video calls.
The messaging service delivers every notification to the app, incoming calls included, as a regular
`alert` push whose payload is end-to-end encrypted with a key that exists only on the user's device. The
push type is chosen by the sending service and cannot be changed from the app, so only our Notification
Service Extension can decrypt a push and learn whether it is a message or a call.

**1. Incoming voice and video calls (primary reason).** This is precisely the architecture described in
your article "Sending End-to-End Encrypted VoIP Calls". An incoming call arrives as an encrypted alert
push; our extension (`uz.fenixuz.app.NotificationService`) decrypts it and, when it is a call, passes it
to CallKit with `CXProvider.reportNewIncomingVoIPPushPayload(_:completion:)`. The system then launches the
app, which reports the call with `reportNewIncomingCall(with:update:completion:)`. The article states that
the extension needs `com.apple.developer.usernotifications.filtering` for this. Without it, iOS rejects
the hand-off with `CXErrorDomainNotificationServiceExtension` code 2
(`MissingNotificationFilteringEntitlement`), so while the app is in the background or closed an incoming
call never reaches CallKit: the callee's iPhone does not ring, the caller waits, and the call is missed.
This is currently the most serious problem our ~260,000 users report. Our interim fallback is a
communication notification with `UNNotificationSound.defaultRingtone`, but users expect the native call
screen, and CallKit is the correct way to present calls.

**2. Service events with no user-visible content (secondary).** The same encrypted pushes also carry
read receipts, message deletions, reaction reads and story reads. Our extension uses them only to update
local state and to remove notifications the device already displayed. After decryption there is nothing
to show, and we need the entitlement to silence them as your documentation describes (empty content).

We will use the entitlement only for these two cases: to hand decrypted calls to CallKit and to silence
service events that have no content. Every notification that represents a real incoming message is still
presented. We do not filter, rank or withhold real content, and we never send notification content to
any server.

**The concrete problem.** Because the transport requires an `alert` in the
outer payload for the extension to be invoked at all, iOS commits to
displaying a banner before our extension runs. For a service event we have
nothing to display, so the extension returns an empty
`UNMutableNotificationContent`. Per your documentation, without this
entitlement "the system always displays the notification banner to the user" —
and an entirely empty content is not rendered, so the system falls back to the
original payload instead.

The user-visible result: **every time a user reads a conversation on another
device signed in to the same account, their iPhone displays a spurious
notification.** A user with a phone, an iPad and a Mac sees one bogus banner
per conversation they read elsewhere. This is our single most-reported issue.

**What we have already tried, and why each fails.**

- Returning an empty `UNNotificationContent()` — the documented suppression
  API, but it requires this entitlement; without it the system substitutes the
  original payload.
- Returning content with a blank title and `interruptionLevel = .passive` —
  our current shipping mitigation. It removes the wrong text and stops the
  screen lighting up, but still leaves an empty row in the notification list.
- Deleting the notification from the extension that produced it — impossible:
  it only becomes a delivered notification after `contentHandler` returns, at
  which point the extension is suspended.
- Deleting it from the next extension invocation — works, but leaves the empty
  row on screen for several seconds.
- `apns-collapse-id` — a sender-side header applied before delivery; it cannot
  affect a notification the device has already displayed.
- `threadIdentifier`, `hiddenPreviewsBodyPlaceholder`, `relevanceScore` — these
  change grouping, hidden-preview text and summary ranking. None of them
  prevents presentation.
- `content-available` silent pushes — these do not invoke a notification
  service extension at all, and are throttled and undelivered when the app has
  been force-quit, so they cannot carry read-state reliably.

**Scope of use, and what we will not do.** We will call the suppression path
only when the decrypted payload identifies a service event (a read, delete or
reaction-read marker). Every notification representing an actual incoming
message continues to be presented to the user. We are not requesting this in
order to filter, rank, withhold or selectively hide real content, and we do not
send the notification payload to any server.

We are happy to provide a build, a screen recording of the behaviour, or a
sysdiagnose on request.

---

## Notes for us

- This is **not self-serve.** Apple grants it case by case and it is bound to
  the provisioning profile — adding the key to an entitlements file without
  approval does nothing.
- **The entitlement must reach the extension, not only the app** (corrected
  2026-09-18). The NotificationService target in `Telegram/BUILD` (~line 1557)
  has no `entitlements` attribute, so its entitlements come from its own
  provisioning profile; `TelegramEntitlements` (where the filtering fragment is
  gated to `ph.telegra.Telegraph`) is the main app's file only. Once Apple
  approves it:
  1. enable the capability on the **`uz.fenixuz.app.NotificationService`** App ID
     (and on `uz.fenixuz.app` if the portal asks for it there too),
  2. regenerate `Fenixuz_AppStore_NotificationService.mobileprovision` (and the
     dev `Fenixuz NotificationService` profile) into
     `~/Documents/Apple/{Development,Distribution}/`,
  3. widen the gate in `Telegram/BUILD` (same shape as the Communication
     Notifications fragment just above it, which already lists `uz.fenixuz.app`),
  4. verify with `codesign -d --entitlements :-` on the built **extension**
     (`Telegram.app/PlugIns/NotificationServiceExtension*.appex`), not just the `.app`,
  5. then the extension can return a truly empty content and the blank row
     disappears entirely — the mitigations in `HOOKS.md` section A1/A2 can stay
     as a fallback for users on older builds.
- Incoming calls already fall back to a visible "… is calling you" banner when
  the hand-off fails (`fenixuzIncomingCallFallbackContent`, HOOKS.md "Incoming
  calls", 2026-09-18). Once the entitlement is in the profile the hand-off
  succeeds and that fallback simply stops running — no code change needed.
- Evidence backing every claim above is in
  `_push-audit-2026-08-07/RESEARCH-2-suppression.json` and the device logs.
