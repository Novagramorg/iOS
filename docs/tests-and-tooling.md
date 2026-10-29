# Tests, simulator updates and CI

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Running tests

**Running tests.** `Make.py test` runs Bazel test targets (same config + codesigning as `build`, forced `debug_sim_arm64`). It accepts `--target <label>` (added 2026-06-19; default `Tests/AllTests`) so a single `ios_unit_test` can run in isolation, e.g.:

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
 test --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/TextFormat:TextFormatTests
```

The first app-side `ios_unit_test` is `//submodules/TextFormat:TextFormatTests` (the mention/date link codecs). An `ios_unit_test` here needs an `ios_test_runner` pinned to a real device/OS (e.g. `iPhone 17` / `26.5`) — the default runner picks an invalid device and the test process exits 15. **Run new targets via `--target`, not the default suite:** `Tests/AllTests` currently references a dangling `//submodules/TgVoipWebrtc:TgCallsTests`, so the default would fail to build until that suite is repaired.

Pure C++ units have host `cc_test`s that bypass Make.py entirely (macOS build, no codesigning):
`./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TgVoipWebrtc:streaming_audio_renderer_test --test_output=all`
(likewise `:mtproto_ice_transport_test`). `//third-party/libprisma:SyntaxHighlighterTests` (added
2026-09-25) is the same kind of target outside tgcalls: it compiles only libprisma's pure-C++ core
(not `Syntaxer.mm`, which needs UIKit) plus header-only `boost_regex`, loads the real shipped
`grammars.dat` (passed via the target's `args = ["$(location Resources/grammars.dat)"]`), and pins the
**code-block highlighter recursion bound** — highlighting a `brightscript` block whose grammar has a
token cycle used to recurse `tokenize()`/`matchGrammar()` without limit and kill the process with a
stack overflow (a remote DoS: the block is highlighted on receipt). `SyntaxHighlighter::kMaxTokenizeDepth`
(128; ~1.1 KiB of stack per level, measured) caps it and degrades gracefully to plain text at the cap.
Upstream `TelegramMessenger/libprisma` does **not** fix this (checked at HEAD 07ff1fcc, 2026-09-21):
the recursion has no bound there and the regenerated `grammars.dat` still ships the cycle, so pulling
upstream is not a substitute for the cap. They follow a plain `CHECK_TRUE` + `main()` pattern, are listed
explicitly in `submodules/TgVoipWebrtc/BUILD` (group sources are not globbed), and must be added to the
`exclude:` list in `tgcalls/Package.swift` so SwiftPM does not compile their `main()`. The first run compiles
WebRTC for the host (~2.5 min); later runs take seconds. Note the binary is version-stamped and
arch-suffixed (`bazel-9.2.0-darwin-arm64` since 2026-09-14, was `bazel-8.4.2-darwin-arm64`), not the
bare `bazel-8.4.2` the tgcalls CLAUDE.md names; `versions.json` is the single pin.

`//submodules/MetalEngine:MetalPipelineCacheTests` (added 2026-10-01) is the first host `swift_test`, run
the same way (`… bazel-9.2.0-darwin-arm64 test //submodules/MetalEngine:MetalPipelineCacheTests`; one test
via `--test_filter=MetalPipelineCacheTests/<name>`, comma lists are not supported). It compiles only
`MetalPipelineCache.swift` + `MetalBinaryArchiveSerialization.swift` and runs on the Mac's GPU, because
the simulator has no binary archives (serializing fails an assertion there). It pins an **Apple bug**: a
`MTLBinaryArchive.serialize(to:)` whose final file move fails does not throw — Metal frees the error on
the compiler's reply thread and the caller crashes retaining it (device crash on iOS 26.3, reproduced on
macOS 27). `MetalBinaryArchiveSerialization` hooks that one `NSFileManager` call to keep the error alive;
the target sets `NSZombieEnabled` so a regression fails deterministically.

`//submodules/UrlWhitelist:UrlWhitelistTests` (added 2026-10-06) is a host `swift_test` like
`MTProtoRustEngineMappingTests`, run the same way. It pins `externalUrlWithLoginPart`, the check that
makes opening a link with a login part in front of its host ask first: in
`https://telegram.org∕test∕@evil.org` the `∕` (U+2215) is not a slash, so `telegram.org∕test∕` is a user
name and the link opens evil.org. The check runs in the external-URL opener (`openExternalUrlImpl`),
which every external link leaves through, including the openers that never ask about anything (admin
log, Instant View), and its parse is the opener's own (`canonicalExternalUrl`, now in `UrlWhitelist`).
The prompts in `openUserGeneratedUrl` and `TextLinkHandling` also flag such links. Every prompt, and
the title of every long-press link menu (`displayUrlRevealingLoginPart`; Copy still copies the link as
written), shows the address without the login part, and accepting a prompt records the address
(`noteLoginPartConfirmed`) so the opener does not ask a second time. The check stays out of `parseUrl`,
whose `concealed` flag also makes the shared-links list title a link with its whole address instead of
its host.

### Updating the running simulator after a rebuild (whole-`.app` copy)

`simctl install` will NOT replace an already-installed app when the build number is unchanged (installd keeps a hard-link cache), so a rebuilt binary silently doesn't take effect. **Preferred fix: copy the whole freshly-built `.app` over the installed bundle in place.** This is more robust than swapping only the `Frameworks/TelegramUIFramework` binary (no risk of app↔framework version skew), and it preserves the account/login because the **data container is a separate path** (`.../data/Containers/Data/Application/<uuid>/`, keyed by bundle id) — only the **bundle** container is replaced, and the install-DB entry stays valid since the path + bundle id are unchanged.

```sh
K3=4483DD69-685A-4FE1-89BE-65F992C271F2   # iPhone 18 Pro K3 (use the dedicated K-sims, not the shared default)
# The K-sims were RECREATED by the Xcode 27 update (2026-09-15), which removed every simulator:
# they are iPhone 18 Pro now, on new UDIDs. K1=03A7DA9C-1832-49B8-9858-2F54F2FB5A04, K2=E643A78E-DB62-4DA4-9F54-BD0836F434AF.
BUNDLE=ph.telegra.Telegraph
# Fresh build output. Go through `bazel-bin`, which bazel repoints at
# the LAST BUILD's configuration. Do NOT `find` under `bazel-out`: it keeps one directory per
# configuration you have ever built, so `… | head -1` can hand you a stale *device* archive. That copies
# fine and then refuses to launch ("request was denied by service delegate (SBMainWorkspace)"), which
# reads like a crash rather than an arch mismatch — and `lipo -archs` does not disambiguate, since device
# and simulator arm64 slices both report plain `arm64`.
# SOURCE THE .ipa, NOT `Telegram_archive-root/`. The archive-root directory is only rewritten when
# the packaging step actually re-runs; on a cache-hit incremental build it is left behind holding a
# PREVIOUS build's binaries, and nothing about it looks stale (see the note below). The .ipa is
# rewritten every build and carries a real mtime.
STAGE=$(mktemp -d)
unzip -q -o bazel-bin/Telegram/Telegram.ipa -d "$STAGE"
SRC="$STAGE/Payload/Telegram.app"
DEST="$(xcrun simctl get_app_container "$K3" "$BUNDLE" app)"   # installed bundle path
# GUARD before the destructive rm: never rm the installed app unless SRC actually resolved,
# or a failed cp leaves the sim with NO app installed (relaunch then fails).
[ -x "$SRC/Telegram" ] || { echo "no fresh bundle at SRC=$SRC — aborting"; exit 1; }
xcrun simctl terminate "$K3" "$BUNDLE" 2>/dev/null            # terminate before replacing the running binary
rm -rf "$DEST" && cp -Rp "$SRC" "$DEST"                        # replace bundle in place; data container untouched
xcrun simctl launch "$K3" "$BUNDLE"
```

The sim ignores code signing, so the unsigned bundle runs fine.

**`Telegram_archive-root/` goes stale silently — do not install from it.** It is written by the
Make.py wrapper's post-build packaging, which only re-runs when the packaging action itself is not a
cache hit. After an incremental build (`Build completed successfully, 21 total actions`, ~30s) the
directory is simply left as it was, still holding a PREVIOUS build's binaries, while
`bazel-bin/Telegram/Telegram.ipa` *is* rewritten. Demonstrated 2026-08-20: one build produced an
archive-root framework and an .ipa framework with different md5s, the archive-root one still
containing symbols from source that had already been reverted.

There is no cheap way to eyeball the staleness, which is what makes it dangerous:
- **mtime cannot detect it.** Bazel stamps a reproducible `Jan 1 1980` on everything under
  archive-root, so the stale copy and a fresh one look identical.
- The stale bundle launches and behaves normally — it is simply *older code*. The failure mode is
  "I am debugging behaviour that is not in the source I am reading", which can burn an entire
  investigation before anyone suspects the bundle. It did exactly that once already.

So the recipe above unzips the `.ipa` instead. If you ever do copy from archive-root, verify first:
`md5 -q .../Telegram_archive-root/Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework`
against the same path unzipped out of the `.ipa`, and treat a mismatch as stale.

(The older framework-only `cp` of `TelegramUIFramework` still works and is faster, but prefer the
whole-`.app` copy to avoid version skew.)

### CI builds in tart VMs (and why every download needs a checksum)

GitLab CI (`.gitlab-ci.yml`) builds, uploads to TestFlight and verifies in tart VMs on the runner host:
`Make.py vm-build` / `vm-deploy-testflight` / `vm-ipa-diff` (`build-system/Make/TartBuild.py`), each in an ephemeral
clone of `macos-<macos>-xcode-<xcode>` from `versions.json` (uploads use `deploy_xcode`). One VM runs per host
(an flock at `~/.telegram-build/vm-build.lock`); CI passes `--waitForLock` so a second job queues instead of failing.
gitlab-runner runs as a launchd service whose PATH has no Homebrew, so `tart` is resolved via `TART_PATH`, PATH, then
the Homebrew locations. The bazel cache is bazel-remote on the runner host (`TELEGRAM_BAZEL_CACHE_HOST`); the guest
reaches it through tart's NAT at the host's LAN address or the gateway (`grpc://@auto:9092`).

**Every external download must carry a checksum.** Make.py points both `--remote_cache` and
`--experimental_remote_downloader` at bazel-remote, so bazel asks bazel-remote to fetch each archive and waits for the
whole download under the 60s `--remote_timeout`. bazel-remote serves an archive from its store only when the request
names its sha256; without one it re-downloads it from the internet on every build (the repository cache needs the
checksum too, and each ephemeral VM starts with an empty one). On the runner's link (~300-400 KB/s from
static.rust-lang.org) a large archive misses the deadline: the build log fills with
`Remote Cache: DEADLINE_EXCEEDED … remote_addr=…:9092`, the guest sits idle, and after the retries
`--experimental_remote_downloader_local_fallback` (`.bazelrc`) downloads it again inside the VM. It reads like the VM
cannot reach the cache; it can (`curl http://<cache>:8080/status` from the guest answers in milliseconds), and the
tell is bazel-remote holding an outbound connection to the archive's host. This happened with the Rust toolchain:
rules_rust 0.74.0 knows checksums only up to Rust 1.98.0, so `MODULE.bazel` supplies 1.98.1's in
`rust.toolchain(sha256s = …)`. **Bumping the Rust version means updating that dict** (each archive's checksum is at
`static.rust-lang.org/dist/<archive>.sha256`), or dropping it once rules_rust's `known_shas.bzl` covers the version.

## App-side unit test catalog

From the root `CLAUDE.md`, "Project Structure":

- App-side unit tests are minimal: the first `ios_unit_test` (`//submodules/TextFormat:TextFormatTests`) was added 2026-06-19 (run via `Make.py test --target` — see Build). `//submodules/Postbox:PostboxTests` (added 2026-09-18) covers `SqliteValueBox` and individual Postbox tables directly against an in-memory value box, using `@testable import Postbox`; add new Postbox regression tests under `submodules/Postbox/Tests/`. `//submodules/TelegramCallsUI:TelegramCallsUITests` (added 2026-09-18) drives `SharedCallAudioContext` through a fake `ManagedAudioSession` (the protocol is implementable from outside since `ManagedAudioSessionControl` gained a public closure initializer); creating the context builds a real tgcalls audio device, which is fine in the simulator test process. `//submodules/TelegramAudio:TelegramAudioTests` (added 2026-09-22) covers pure `ManagedAudioSessionType` helpers such as `voiceMessageRecording(beginWithTone:pauseMusicOnRecording:)`, the mapping the voice recorder uses for the Data & Storage "Pause Music While Recording" toggle, and the **holder-precedence policy of the real `ManagedAudioSessionImpl`** (it is constructible in the test process; push with `manualActivate` and never touch the control, so the process's `AVAudioSession` is left alone). The load-bearing rule pinned there: a `.voiceCall` holder is never displaced, not even temporarily, by a recording that mixes with other audio, because deactivating it makes `PresentationCall` drop its audio-session control. The recorder itself (`ManagedAudioRecorder`) needs a live `MediaManager` and real audio units, so keep session-policy decisions in testable helpers rather than in it. `//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:ChatTextInputPanelNodeTests` (added 2026-09-22) covers the legacy composer's Text Size metrics (`ChatTextInputFontMetrics.swift`) against a real `ChatInputTextView` measurement; linking the panel into a test bundle needed `MediaPlayer` declared on `LegacyComponents`. `//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode:PeerInfoPaneNodeTests` (added 2026-09-24) covers `peerInfoMessageChatDestination`, the chat that shared-media "View in Chat" opens. It is the chat the media tab *lists* — neither the peer the profile describes (a secret chat's profile describes the user, so use `data.chatPeer`) nor the chat the message is stored in (a supergroup's tab lists its pre-migration basic group's messages, which open in the supergroup). A user's profile opened from a channel's direct messages lists that channel's thread, which is opened directly: `navigateToForumThread` addresses a topic by an Int32 message id and cannot reach a monoforum thread keyed by a user id. `//Telegram/NotificationService:NotificationServiceTests` (added 2026-09-24) covers the notification service extension's naming of the recipient account when several are signed in (`NotificationRecipientAccount.swift`). On iOS 15+ the system draws a communication notification's title from the sender `INPerson`'s `displayName` and hides `content.subtitle` (measured on 18.6 and 27), so anything the title must show goes into the sender's name. `NotificationContent` is private, so keep such decisions in testable helpers. `//submodules/TelegramUI/Components/Chat/EditableTokenListNode:EditableTokenListNodeTests` (added 2026-09-24) covers `EditableTokenListPeerAlias`, the one decision a chat picker's token (e.g. Add Chats for a folder) uses for both its title and its avatar, so a Saved Messages token draws the Saved Messages icon rather than the account's photo; `PresentationStrings` cannot be built in a test process (it asserts without the app bundle's `PresentationStrings.data`), so the alias is strings-free and the title stays in `ContactMultiselectionController`. `//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUITests` (added 2026-09-25) covers `avatarGalleryUserEntries`, the one builder both user-gallery paths use: slot 0 is drawn from the peer record's current photo, but `photos.getUserPhotos` keeps its order when an older photo is made the main one again (the server swaps a copy under a **new photo id** into that photo's place), so the current photo is looked up in the list and moved to the front (a personal photo moves the contact's current public photo instead, and a current photo the list does not contain gets its own slot) rather than drawn over whatever the list starts with, which showed it twice and hid that photo. Because of the new id, `_internal_updatePeerPhotoExisting` copies the chosen photo's downloaded sizes to the returned photo's files; the returned photo's sizes and its `photo_small`/`photo_big` ("a"/"c") are byte-identical to the chosen photo's (measured in the sim media cache). The result's user list does not carry the new photo for the account itself, so the same transaction also sets `TelegramUser.photo` from the returned photo; without that the record changed only in a later transaction and every avatar downloaded the photo again. `//submodules/MediaPlayer:UniversalMediaPlayerTests` (added 2026-09-26) drives a real `ChunkMediaPlayerV2` (wait for `MediaPlayerNode.videoLayer`, which the node creates asynchronously, before constructing it) from an `.externalParts` promise. With no parts the player stays buffering, so the clock only moves on a seek; a part backed by an empty `TempBox` file lets it run, because buffering is decided from part times alone. It pins the end of playback: the player keeps a 0.1 s end tolerance for HLS chunks that do not line up with the declared duration (`ChunkMediaPlayerV2.endTolerance`; do not remove it), so a video no longer than that is at its end from position 0 and is not played — its clock never moves, even on a later `play()`. Looping one would seek to where the clock already is, and that no-op `seek` re-runs the end check synchronously until the stack overflows. The RichTextEditor SwiftPM package keeps its own suite (`swift test` / `Scripts/iostest.sh`). MtProtoKit's suite (`//submodules/MtProtoKit:MtProtoKitTests`) also runs on macOS: `swift test` in `submodules/MtProtoKit` (the package's test target puts the module's private headers on its search path). Most modules still have no tests.
