# `ListViewItem` Neighbor Descriptors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `previousItem: ListViewItem?` / `nextItem: ListViewItem?` throughout the list system with a small `Equatable` descriptor each item publishes about itself, so a backend can relayout a row exactly when its neighbors changed — unblocking neighbor awareness in `CoreListChatHistoryBackend`.

**Architecture:** Items publish `neighborDescriptor: AnyEquatable`; layout methods receive `neighbors: ListViewItemNeighbors` (two optional descriptors). Consumers read descriptors through *facet protocols* (`ItemListNeighborFacet`, `HeaderNeighborFacet`, bespoke ones) rather than casting to concrete neighbor types. The asymmetric pairwise `messagesShouldBeMerged` is factored into a per-message `ChatMessageMergeFingerprint` plus a pure comparison, verified by a differential test against the current implementation. `ListViewImpl` switches from "relayout neighbors of every insert/delete" to "relayout iff the descriptor pair changed".

**Tech Stack:** Swift, Bazel (via `build-system/Make/Make.py`), `ios_unit_test` + `ios_test_runner`, XCTest.

**Design spec:** [`docs/superpowers/specs/2026-07-27-listviewitem-neighbor-descriptors-design.md`](../specs/2026-07-27-listviewitem-neighbor-descriptors-design.md)

## Global Constraints

- **Full-app build is the only build.** There is no selective per-module build. Every "run the build" step means:
  ```sh
  source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
    --cacheDir ~/telegram-bazel-cache build \
    --configurationPath build-system/appstore-configuration.json \
    --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
    --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 \
    --configuration=debug_sim_arm64 --continueOnError
  ```
  `--continueOnError` forwards to bazel's `--keep_going`; it is **mandatory** for the sweep tasks so all errors land in one pass. `source ~/.zshrc` is required — it supplies `TELEGRAM_CODESIGNING_GIT_PASSWORD`, which the bash tool does not otherwise pick up.
- **Unit tests** run with:
  ```sh
  source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
    --cacheDir ~/telegram-bazel-cache test \
    --configurationPath build-system/appstore-configuration.json \
    --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
    --gitCodesigningType development --gitCodesigningUseCurrent \
    --target //submodules/TelegramUI/Components/Chat/ChatMessageItemCommon:ChatMessageItemCommonTests
  ```
  Always pass `--target`. Never run the default `Tests/AllTests` suite — it references a dangling `//submodules/TgVoipWebrtc:TgCallsTests` and will fail to build.
- Every `ios_unit_test` needs an `ios_test_runner` pinned to `device_type = "iPhone 17"`, `os_version = "26.5"`. The default runner picks an invalid device and the test process exits 15.
- All `swift_library` targets in this repo use `copts = ["-warnings-as-errors"]`. New code must be warning-clean. Test-only `swift_library` targets omit that copt (see `submodules/TextFormat/BUILD` for the canonical shape).
- **`TelegramCore` never imports UIKit or Display.** No task here touches `TelegramCore`; keep it that way.
- Manual verification runs on the **`iPhone 17 Pro K1`** simulator, not the shared default.
- Commit messages end with:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  ```
- Work on a branch, not `master`.

## File Structure

**New files**

| Path | Responsibility |
|---|---|
| `submodules/Display/Source/AnyEquatable.swift` | Type-erased `Equatable` box + `noNeighborInfluence` constant |
| `submodules/Display/Source/ListViewItemNeighbors.swift` | `ListViewItemNeighbors`, `HeaderNeighborFacet` |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMerge.swift` | `ChatMessageMerge` (moved down from `ChatMessageItem`) |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMergeFingerprint.swift` | `ChatMessageMergeFingerprint` + `chatMessageMerge(upper:lower:)` |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatHistoryItemNeighbors.swift` | `ChatHistoryItemNeighbor`, `ChatHistoryItemNeighbors`, `chatItemsHaveCommonDateHeader` |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/AnyEquatableTests.swift` | `AnyEquatable` semantics |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MessageBuilder.swift` | Test-only `Message`/peer builders |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MergeReferenceImplementation.swift` | Verbatim copy of today's `messagesShouldBeMerged` — the oracle |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatMessageMergeFingerprintTests.swift` | Differential test |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatHistoryItemNeighborsTests.swift` | Decoding + date-header helper |
| `submodules/ItemListUI/Sources/ItemListNeighborFacet.swift` | `ItemListNeighborFacet`, its payload, the `ItemListItem` extension, facet-based `itemListNeighbors` |

**Heavily modified**

| Path | Change |
|---|---|
| `submodules/Display/Source/ListViewItem.swift` | `neighborDescriptor` requirement; method signatures |
| `submodules/Display/Source/ListViewItemNode.swift` | `layoutForParams` signature; `appliedNeighbors` storage |
| `submodules/Display/Source/ListView.swift` | `neighbors(at:)`; descriptor-diff invalidation |
| `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift` | `merged(with:isRotated:)`; fingerprint publication; deletes `messagesShouldBeMerged` |
| `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift` | Neighbor computation, `isEqual`, layout call |

---

### Task 1: `AnyEquatable` and the test target

**Files:**
- Create: `submodules/Display/Source/AnyEquatable.swift`
- Create: `submodules/Display/Source/ListViewItemNeighbors.swift`
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/AnyEquatableTests.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/BUILD`

**Interfaces:**
- Produces: `AnyEquatable` with `init<T: Equatable>(_:)`, `base<T>(_ type: T.Type) -> T?`, `static let noNeighborInfluence`; `ListViewItemNeighbors` with `previous`/`next: AnyEquatable?` and `static let none`; `HeaderNeighborFacet` with `var headerId: ListViewItemNode.HeaderId? { get }`. Every later task uses these.

- [ ] **Step 1: Write the failing test**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/AnyEquatableTests.swift`:

```swift
import XCTest
import Display

private struct FacetedPayload: Equatable, SizeFacet {
    let size: Int
    let name: String
}

private protocol SizeFacet {
    var size: Int { get }
}

private struct OtherPayload: Equatable {
    let size: Int
}

final class AnyEquatableTests: XCTestCase {
    func testEqualWhenSameTypeAndValue() {
        XCTAssertEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                       AnyEquatable(FacetedPayload(size: 1, name: "a")))
    }

    func testNotEqualWhenSameTypeDifferentValue() {
        XCTAssertNotEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                          AnyEquatable(FacetedPayload(size: 2, name: "a")))
    }

    func testNotEqualAcrossTypesEvenWithMatchingFields() {
        XCTAssertNotEqual(AnyEquatable(FacetedPayload(size: 1, name: "a")),
                          AnyEquatable(OtherPayload(size: 1)))
    }

    func testEqualityIsSymmetricAcrossTypes() {
        let a = AnyEquatable(FacetedPayload(size: 1, name: "a"))
        let b = AnyEquatable(OtherPayload(size: 1))
        XCTAssertEqual(a == b, b == a)
    }

    func testBaseRecoversConcreteType() {
        let boxed = AnyEquatable(FacetedPayload(size: 3, name: "x"))
        XCTAssertEqual(boxed.base(FacetedPayload.self)?.name, "x")
        XCTAssertNil(boxed.base(OtherPayload.self))
    }

    func testBaseRecoversProtocolFacet() {
        let boxed = AnyEquatable(FacetedPayload(size: 3, name: "x"))
        XCTAssertEqual(boxed.base(SizeFacet.self)?.size, 3)
        XCTAssertNil(AnyEquatable(OtherPayload(size: 3)).base(SizeFacet.self))
    }

    func testNoNeighborInfluenceIsEqualToItself() {
        XCTAssertEqual(AnyEquatable.noNeighborInfluence, AnyEquatable.noNeighborInfluence)
        XCTAssertNil(AnyEquatable.noNeighborInfluence.base(SizeFacet.self))
    }

    func testNeighborsEquality() {
        let a = ListViewItemNeighbors(previous: AnyEquatable(OtherPayload(size: 1)), next: nil)
        let b = ListViewItemNeighbors(previous: AnyEquatable(OtherPayload(size: 1)), next: nil)
        let c = ListViewItemNeighbors(previous: nil, next: AnyEquatable(OtherPayload(size: 1)))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(ListViewItemNeighbors.none, ListViewItemNeighbors(previous: nil, next: nil))
    }
}
```

`testBaseRecoversProtocolFacet` is the load-bearing one — the whole facet mechanism in Task 5 depends on `as?` to an existential working through the box.

- [ ] **Step 2: Add the test target to the BUILD file**

Append to `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/BUILD`, and add the two `load` statements at the top of the file:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
```

```python
swift_library(
    name = "ChatMessageItemCommonTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMessageItemCommon",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
    ],
)

ios_test_runner(
    name = "ChatMessageItemCommonTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMessageItemCommonTests",
    minimum_os_version = "13.0",
    runner = ":ChatMessageItemCommonTestRunner",
    deps = [
        ":ChatMessageItemCommonTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
```

- [ ] **Step 3: Run the test to verify it fails**

Run the unit-test command from Global Constraints.
Expected: build failure, `cannot find 'AnyEquatable' in scope`.

- [ ] **Step 4: Implement `AnyEquatable`**

Create `submodules/Display/Source/AnyEquatable.swift`:

```swift
import Foundation

private struct NoNeighborInfluence: Equatable {
}

/// A type-erased `Equatable` value.
///
/// Unlike `AnyHashable` this imposes no `Hashable` requirement on payloads — nothing hashes a
/// neighbor descriptor, and `Equatable` is the weaker constraint.
public struct AnyEquatable: Equatable {
    private let value: Any
    private let isEqualTo: (Any) -> Bool

    public init<T: Equatable>(_ value: T) {
        self.value = value
        self.isEqualTo = { other in
            guard let other = other as? T else {
                return false
            }
            return other == value
        }
    }

    public static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.isEqualTo(rhs.value)
    }

    /// Recovers the payload as `T`. `T` may be a concrete type or a protocol (facet).
    public func base<T>(_ type: T.Type) -> T? {
        return self.value as? T
    }

    /// Payload for items whose neighbors read nothing about them. A single shared constant, so it
    /// compares equal to itself and never causes a neighbor relayout.
    public static let noNeighborInfluence = AnyEquatable(NoNeighborInfluence())
}
```

- [ ] **Step 5: Implement `ListViewItemNeighbors` and `HeaderNeighborFacet`**

Create `submodules/Display/Source/ListViewItemNeighbors.swift`:

```swift
import Foundation

/// The descriptors published by the items immediately before and after some item.
///
/// `nil` on a side means *there is no neighbor on that side*. A non-nil descriptor from which a
/// consumer cannot recover its facet means *there is a neighbor, and it publishes nothing relevant*.
/// Those two cases are distinguishable on purpose — `ContactsPeerItem`, among others, depends on it.
public struct ListViewItemNeighbors: Equatable {
    public var previous: AnyEquatable?
    public var next: AnyEquatable?

    public init(previous: AnyEquatable?, next: AnyEquatable?) {
        self.previous = previous
        self.next = next
    }

    public static let none = ListViewItemNeighbors(previous: nil, next: nil)
}

/// Facet for items that participate in header-run detection (first/last in a header group).
public protocol HeaderNeighborFacet {
    var headerId: ListViewItemNode.HeaderId? { get }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run the unit-test command.
Expected: PASS, 8 tests.

- [ ] **Step 7: Run the full build**

Run the build command. Nothing consumes the new types yet, so this only proves the new Display sources compile within the module.
Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add submodules/Display/Source/AnyEquatable.swift \
        submodules/Display/Source/ListViewItemNeighbors.swift \
        submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/BUILD \
        submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/AnyEquatableTests.swift
git commit -m "$(cat <<'EOF'
feat(display): add AnyEquatable and ListViewItemNeighbors

Type-erased Equatable box plus the neighbor-descriptor pair that will replace
previousItem/nextItem. Adds the ChatMessageItemCommonTests target.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Move `ChatMessageMerge` into `ChatMessageItemCommon`

`ChatMessageMergeFingerprint` (Task 3) returns a `ChatMessageMerge` and must live in a module light enough to unit-test. `ChatMessageItem` pulls in `AccountContext`; `ChatMessageItemCommon` depends only on `Display`, `TelegramCore`, `Emoji`.

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMerge.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItem/Sources/ChatMessageItem.swift:92-104` (delete the enum)
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift` (add one import)

**Interfaces:**
- Produces: `ChatMessageMerge` in module `ChatMessageItemCommon`.

- [ ] **Step 1: Create the new home**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMerge.swift` with the enum moved verbatim:

```swift
import Foundation

public enum ChatMessageMerge: Int32 {
    case none = 0
    case fullyMerged = 1
    case semanticallyMerged = 2

    public var merged: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}
```

- [ ] **Step 2: Delete the original**

Remove lines 92-104 of `submodules/TelegramUI/Components/Chat/ChatMessageItem/Sources/ChatMessageItem.swift` (the `public enum ChatMessageMerge` block). Leave `ChatMessageHeaderSpec` immediately below it in place — only the `ChatMessageItem` protocol returns it, so it stays.

- [ ] **Step 3: Fix the one file that lacks the import**

Exactly seven files reference `ChatMessageMerge`; six already `import ChatMessageItemCommon`. Add that import to the seventh:

`submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift` — add `import ChatMessageItemCommon` to the import block (it already imports `ChatMessageItem`).

Verify the set is unchanged before and after:

```bash
grep -rl "ChatMessageMerge" --include='*.swift' submodules/
```
Expected: the same 7 paths as before the move.

- [ ] **Step 4: Run the full build**

Expected: build succeeds. If a file reports `cannot find type 'ChatMessageMerge' in scope`, add `import ChatMessageItemCommon` to it.

- [ ] **Step 5: Commit**

```bash
git add -A submodules/TelegramUI/Components/Chat/ChatMessageItemCommon \
           submodules/TelegramUI/Components/Chat/ChatMessageItem \
           submodules/TelegramUI/Components/Chat/ChatMessageItemImpl
git commit -m "$(cat <<'EOF'
refactor(chat): move ChatMessageMerge down into ChatMessageItemCommon

Puts the merge enum in a module light enough to host a unit test target.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `ChatMessageMergeFingerprint` and the differential test

This is the highest-risk task in the plan. `messagesShouldBeMerged` is asymmetric — its first argument is the *upper* message — and three of its branches read only the upper message and apply the result to both sides. The fingerprint therefore stores raw **ingredients**, not resolved values.

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMergeFingerprint.swift`
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MessageBuilder.swift`
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MergeReferenceImplementation.swift`
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatMessageMergeFingerprintTests.swift`
- Reference (read, do not yet modify): `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift:20-204`

**Interfaces:**
- Consumes: `ChatMessageMerge` (Task 2).
- Produces:
  ```swift
  public struct ChatMessageMergeFingerprint: Equatable {
      public init(message: EngineRawMessage, accountPeerId: EnginePeer.Id)
  }
  public func chatMessageMerge(upper: ChatMessageMergeFingerprint,
                               lower: ChatMessageMergeFingerprint) -> ChatMessageMerge
  ```
  `chatMessageMerge(upper:lower:)` is the exact replacement for `messagesShouldBeMerged(accountPeerId:upperMessage,lowerMessage)`.

- [ ] **Step 1: Copy the oracle into the test target**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MergeReferenceImplementation.swift`. Copy **verbatim** from `ChatMessageItemImpl.swift`:

- `mediaMergeableStyle(_:)` (lines 20-46)
- `anonymousGroupAdminSignature(message:effectiveAuthor:)` (lines 48-60)
- `messagesShouldBeMerged(accountPeerId:_:_:)` (lines 62-204)

Rename only the last one, to `referenceMessagesShouldBeMerged`, and change all three from `private` to `internal`. Do not restructure the bodies — the value of this file is that it is a byte-for-byte oracle. Add the imports the originals need:

```swift
import Foundation
import Postbox
import TelegramCore
import ChatMessageItemCommon
```

- [ ] **Step 2: Write the test-only message builder**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/MessageBuilder.swift`:

```swift
import Foundation
import Postbox
import TelegramCore

let accountPeerIdForTests = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))

func makeUser(id: Int64) -> TelegramUser {
    return TelegramUser(
        id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)),
        accessHash: nil,
        firstName: "U\(id)",
        lastName: nil,
        username: nil,
        phone: nil,
        photo: [],
        botInfo: nil,
        restrictionInfo: nil,
        flags: UserInfoFlags(),
        emojiStatus: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        subscriberCount: nil,
        verificationIconFileId: nil
    )
}

func makeChannel(id: Int64, info: TelegramChannelInfo, flags: TelegramChannelFlags = TelegramChannelFlags()) -> TelegramChannel {
    return TelegramChannel(
        id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)),
        accessHash: nil,
        title: "C\(id)",
        username: nil,
        photo: [],
        creationDate: 0,
        version: 0,
        participationStatus: .member,
        info: info,
        flags: flags,
        restrictionInfo: nil,
        adminRights: nil,
        bannedRights: nil,
        defaultBannedRights: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        emojiStatus: nil,
        approximateBoostLevel: nil,
        subscriptionUntilDate: nil,
        verificationIconFileId: nil,
        sendPaidMessageStars: nil,
        linkedMonoforumId: nil
    )
}

func makeGroupChannel(id: Int64, isMonoforum: Bool = false) -> TelegramChannel {
    var flags = TelegramChannelFlags()
    if isMonoforum {
        flags.insert(.isMonoforum)
    }
    return makeChannel(id: id, info: .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags())), flags: flags)
}

func makeBroadcastChannel(id: Int64, messagesShouldHaveProfiles: Bool) -> TelegramChannel {
    var broadcastFlags = TelegramChannelBroadcastFlags()
    if messagesShouldHaveProfiles {
        broadcastFlags.insert(.messagesShouldHaveProfiles)
    }
    return makeChannel(id: id, info: .broadcast(TelegramChannelBroadcastInfo(flags: broadcastFlags)))
}

/// Minimal message factory. Only the fields `messagesShouldBeMerged` reads are parameterised;
/// everything else is a fixed, inert default.
func makeMessage(
    stableId: UInt32 = 1,
    peer: Peer,
    author: Peer?,
    timestamp: Int32 = 1000,
    isOutgoing: Bool = false,
    attributes: [MessageAttribute] = [],
    media: [Media] = [],
    forwardInfo: MessageForwardInfo? = nil,
    extraPeers: [Peer] = []
) -> Message {
    // Message.effectivelyIncoming(_:) falls through to `flags.contains(.Incoming)` for any peer
    // that is not the account itself and any author that is not the account — which is every case
    // this builder produces. Note a broadcast channel forces `true` regardless, so broadcast cases
    // are always effectively incoming; that is real behavior, not a builder artifact.
    var flags = MessageFlags()
    if !isOutgoing {
        flags.insert(.Incoming)
    }

    var peers = SimpleDictionary<PeerId, Peer>()
    peers[peer.id] = peer
    if let author = author {
        peers[author.id] = author
    }
    for extra in extraPeers {
        peers[extra.id] = extra
    }

    return Message(
        stableId: stableId,
        stableVersion: 0,
        id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: Int32(stableId)),
        globallyUniqueId: nil,
        groupingKey: nil,
        groupInfo: nil,
        threadId: nil,
        timestamp: timestamp,
        flags: flags,
        tags: MessageTags(),
        globalTags: GlobalMessageTags(),
        localTags: LocalMessageTags(),
        customTags: [],
        forwardInfo: forwardInfo,
        author: author,
        text: "",
        attributes: attributes,
        media: media,
        peers: peers,
        associatedMessages: SimpleDictionary<MessageId, Message>(),
        associatedMessageIds: [],
        associatedMedia: [:],
        associatedThreadInfo: nil,
        associatedStories: [:]
    )
}
```

All the constructors used above are verified against the tree: `AuthorSignatureMessageAttribute(signature:)`, `PaidStarsMessageAttribute(stars:postponeSending:)`, `TelegramChannelGroupInfo(flags:)`, `TelegramChannelBroadcastInfo(flags:)`, `TelegramChannelFlags.isMonoforum`.

- [ ] **Step 3: Write the failing differential test**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatMessageMergeFingerprintTests.swift`:

```swift
import XCTest
import Postbox
import TelegramCore
import ChatMessageItemCommon

final class ChatMessageMergeFingerprintTests: XCTestCase {
    /// Every case is asserted in both orders, since the function is asymmetric.
    private func assertMatchesReference(_ a: Message, _ b: Message, _ label: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let fa = ChatMessageMergeFingerprint(message: a, accountPeerId: accountPeerIdForTests)
        let fb = ChatMessageMergeFingerprint(message: b, accountPeerId: accountPeerIdForTests)
        XCTAssertEqual(chatMessageMerge(upper: fa, lower: fb),
                       referenceMessagesShouldBeMerged(accountPeerId: accountPeerIdForTests, a, b),
                       "\(label) [a upper]", file: file, line: line)
        XCTAssertEqual(chatMessageMerge(upper: fb, lower: fa),
                       referenceMessagesShouldBeMerged(accountPeerId: accountPeerIdForTests, b, a),
                       "\(label) [b upper]", file: file, line: line)
    }

    func testMatrixMatchesReference() {
        var cases: [(String, Message)] = []

        let user1 = makeUser(id: 10)
        let user2 = makeUser(id: 11)
        let group = makeGroupChannel(id: 100)
        let monoforum = makeGroupChannel(id: 101, isMonoforum: true)
        let plainBroadcast = makeBroadcastChannel(id: 102, messagesShouldHaveProfiles: false)
        let profileBroadcast = makeBroadcastChannel(id: 103, messagesShouldHaveProfiles: true)

        // peer and author variation
        cases.append(("group/user1", makeMessage(peer: group, author: user1)))
        cases.append(("group/user2", makeMessage(peer: group, author: user2)))
        cases.append(("group/nil-author", makeMessage(peer: group, author: nil)))
        cases.append(("otherGroup/user1", makeMessage(peer: makeGroupChannel(id: 200), author: user1)))
        cases.append(("monoforum/user1", makeMessage(peer: monoforum, author: user1)))
        cases.append(("broadcast/user1", makeMessage(peer: plainBroadcast, author: user1)))
        cases.append(("profileBroadcast/user1", makeMessage(peer: profileBroadcast, author: user1)))

        // incoming vs outgoing
        cases.append(("group/user1/outgoing", makeMessage(peer: group, author: user1, isOutgoing: true)))

        // author is the group channel itself, with and without an anonymous admin signature
        cases.append(("group/self-authored", makeMessage(peer: group, author: group)))
        cases.append(("group/self-authored/signed", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "Admin")])))
        cases.append(("group/self-authored/signed-other", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "Other")])))
        cases.append(("group/self-authored/signed-empty", makeMessage(
            peer: group, author: group,
            attributes: [AuthorSignatureMessageAttribute(signature: "")])))

        // sourceAuthorInfo overrides
        cases.append(("group/sourceAuthor-user2", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: user2.id, originalAuthorName: nil, orignalDate: nil, originalOutgoing: false)],
            extraPeers: [user2])))
        cases.append(("group/sourceAuthor-name", makeMessage(
            peer: group, author: user1,
            attributes: [SourceAuthorInfoMessageAttribute(
                originalAuthor: nil, originalAuthorName: "Ghost", orignalDate: nil, originalOutgoing: false)])))

        // timestamps straddling the 10-minute merge window
        cases.append(("group/user1/t+599", makeMessage(peer: group, author: user1, timestamp: 1599)))
        cases.append(("group/user1/t+601", makeMessage(peer: group, author: user1, timestamp: 1601)))

        // paid messages
        cases.append(("group/user1/paid", makeMessage(
            peer: group, author: user1,
            attributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)])))
        cases.append(("monoforum/user1/paid", makeMessage(
            peer: monoforum, author: user1,
            attributes: [PaidStarsMessageAttribute(stars: StarsAmount(value: 5, nanos: 0), postponeSending: false)])))

        // inline reply markup
        cases.append(("group/user1/inlineMarkup", makeMessage(
            peer: group, author: user1,
            attributes: [ReplyMarkupMessageAttribute(
                rows: [ReplyMarkupRow(buttons: [ReplyMarkupButton(title: "b", titleWhenForwarded: nil, action: .text)])],
                flags: [.inline], placeholder: nil)])))

        // media merge styles
        cases.append(("group/user1/no-media", makeMessage(peer: group, author: user1)))
        cases.append(("group/user1/action", makeMessage(
            peer: group, author: user1, media: [TelegramMediaAction(action: .historyCleared)])))
        cases.append(("group/user1/expired", makeMessage(
            peer: group, author: user1, media: [TelegramMediaExpiredContent(data: .image)])))

        for (labelA, a) in cases {
            for (labelB, b) in cases {
                self.assertMatchesReference(a, b, "\(labelA) x \(labelB)")
            }
        }
    }
}
```

Three groups still need cases added in Step 4 below, because they need constructors this plan does not spell out: **imported forwards** (`MessageForwardInfo` with `flags: [.isImported]`, on one side and on both, varying `author` and `authorSignature`), **replies/saved-messages peers** (a message whose `peerId.isRepliesOrSavedMessages(accountPeerId:)` is true, with and without `forwardInfo.author`), and the remaining **media styles** (sticker file, instant round video, story mention, plain file). Read `MessageForwardInfo`'s init in `submodules/Postbox/Sources/Message.swift`, `Namespaces.Peer` / `isRepliesOrSavedMessages` in `submodules/TelegramCore/Sources/Utils/PeerUtils.swift`, and the `mediaMergeableStyle` branches you copied in Step 1, then add one case per branch in the same `cases.append` style.

- [ ] **Step 4: Complete the matrix**

Add the three groups named above. Every branch of `mediaMergeableStyle` and every `if` in `referenceMessagesShouldBeMerged` must be reachable by at least one case. Confirm by reading the reference implementation line by line and ticking off each condition against a case in the list.

- [ ] **Step 5: Run the test to verify it fails**

Run the unit-test command.
Expected: build failure — `cannot find 'ChatMessageMergeFingerprint' in scope`.

- [ ] **Step 6: Implement the fingerprint**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageMergeFingerprint.swift`:

```swift
import Foundation
import Postbox
import TelegramCore

public struct ChatMessageSourceAuthorKey: Equatable {
    public let originalAuthor: EnginePeer.Id?
    public let originalAuthorName: String?
}

/// A per-message projection sufficient to reproduce `messagesShouldBeMerged` against any other
/// message's projection.
///
/// Stores raw *ingredients* rather than resolved values: three branches of the original read only
/// the upper message and apply the answer to both sides, so resolution has to happen pairwise.
public struct ChatMessageMergeFingerprint: Equatable {
    let peerId: EnginePeer.Id
    let rawAuthorId: EnginePeer.Id?
    let overriddenAuthorId: EnginePeer.Id?
    let hasBroadcastProfiles: Bool
    let groupChannelId: EnginePeer.Id?
    let isMonoforumChannel: Bool
    let authorSignature: String?
    let isEffectivelyIncoming: Bool
    let isRepliesOrSavedMessages: Bool
    let sourceAuthorInfo: ChatMessageSourceAuthorKey?
    let hasForwardInfo: Bool
    let forwardAuthorId: EnginePeer.Id?
    let forwardAuthorSignature: String?
    let importedForwardDate: Int32?
    let timestamp: Int32
    let hasPaidStars: Bool
    let mediaMergeStyle: Int32
    let hasInlineReplyMarkup: Bool

    public init(message: EngineRawMessage, accountPeerId: EnginePeer.Id) {
        self.peerId = message.id.peerId
        self.rawAuthorId = message.author?.id
        self.timestamp = message.timestamp
        self.isEffectivelyIncoming = message.effectivelyIncoming(accountPeerId)
        self.isRepliesOrSavedMessages = message.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId)

        // Resolution order mirrors the original exactly: author, then
        // SourceReferenceMessageAttribute, then sourceAuthorInfo.originalAuthor. The
        // messagesShouldHaveProfiles override is NOT applied here — it is applied pairwise,
        // because the original gates it on the *upper* message's channel.
        var overriddenAuthorId = message.author?.id
        for attribute in message.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                overriddenAuthorId = message.peers[attribute.messageId.peerId]?.id
                break
            }
        }
        let sourceAuthorInfo = message.sourceAuthorInfo
        if let sourceAuthorInfo = sourceAuthorInfo, let originalAuthor = sourceAuthorInfo.originalAuthor {
            overriddenAuthorId = message.peers[originalAuthor]?.id
        }
        self.overriddenAuthorId = overriddenAuthorId
        self.sourceAuthorInfo = sourceAuthorInfo.flatMap { info in
            return ChatMessageSourceAuthorKey(originalAuthor: info.originalAuthor,
                                              originalAuthorName: info.originalAuthorName)
        }

        var hasBroadcastProfiles = false
        var groupChannelId: EnginePeer.Id?
        var isMonoforumChannel = false
        if let channel = message.peers[message.id.peerId] as? TelegramChannel {
            switch channel.info {
            case let .broadcast(info):
                hasBroadcastProfiles = info.flags.contains(.messagesShouldHaveProfiles)
            case .group:
                groupChannelId = channel.id
            }
            isMonoforumChannel = channel.flags.contains(.isMonoforum)
        }
        self.hasBroadcastProfiles = hasBroadcastProfiles
        self.groupChannelId = groupChannelId
        self.isMonoforumChannel = isMonoforumChannel

        if let signature = message.authorSignatureAttribute?.signature, !signature.isEmpty {
            self.authorSignature = signature
        } else {
            self.authorSignature = nil
        }

        self.hasForwardInfo = message.forwardInfo != nil
        self.forwardAuthorId = message.forwardInfo?.author?.id
        self.forwardAuthorSignature = message.forwardInfo?.authorSignature
        if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
            self.importedForwardDate = forwardInfo.date
        } else {
            self.importedForwardDate = nil
        }

        self.hasPaidStars = message.paidStarsAttribute != nil

        var mediaMergeStyle = ChatMessageMerge.fullyMerged.rawValue
        for media in message.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < mediaMergeStyle {
                mediaMergeStyle = style
            }
        }
        self.mediaMergeStyle = mediaMergeStyle

        var hasInlineReplyMarkup = false
        for attribute in message.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    hasInlineReplyMarkup = true
                }
                break
            }
        }
        self.hasInlineReplyMarkup = hasInlineReplyMarkup
    }
}

private func anonymousSignature(_ fingerprint: ChatMessageMergeFingerprint,
                                effectiveAuthorId: EnginePeer.Id?) -> String? {
    guard let groupChannelId = fingerprint.groupChannelId, effectiveAuthorId == groupChannelId else {
        return nil
    }
    return fingerprint.authorSignature
}

public func chatMessageMerge(upper: ChatMessageMergeFingerprint,
                             lower: ChatMessageMergeFingerprint) -> ChatMessageMerge {
    // Read from the upper message only, as the original reads it from lhs.
    let useRawAuthors = upper.hasBroadcastProfiles
    var upperEffectiveAuthorId = useRawAuthors ? upper.rawAuthorId : upper.overriddenAuthorId
    let lowerEffectiveAuthorId = useRawAuthors ? lower.rawAuthorId : lower.overriddenAuthorId

    var sameChat = true
    if upper.peerId != lower.peerId {
        sameChat = false
    }

    var isPaid = false
    if upper.hasPaidStars && lower.hasPaidStars {
        isPaid = true
    }

    // The original's real thread check is commented out and hard-coded true. Preserved.
    let sameThread = true

    var sameAuthor = false
    if upperEffectiveAuthorId == lowerEffectiveAuthorId
        && upper.isEffectivelyIncoming == lower.isEffectivelyIncoming {
        sameAuthor = true
    }

    if let upperSource = upper.sourceAuthorInfo, let lowerSource = lower.sourceAuthorInfo {
        if upperSource.originalAuthor != lowerSource.originalAuthor {
            sameAuthor = false
        } else if upperSource.originalAuthorName != lowerSource.originalAuthorName {
            sameAuthor = false
        }
    } else if (upper.sourceAuthorInfo == nil) != (lower.sourceAuthorInfo == nil) {
        sameAuthor = false
    }

    if sameAuthor {
        let upperSignature = anonymousSignature(upper, effectiveAuthorId: upperEffectiveAuthorId)
        let lowerSignature = anonymousSignature(lower, effectiveAuthorId: lowerEffectiveAuthorId)
        if upperSignature != lowerSignature && (upperSignature != nil || lowerSignature != nil) {
            sameAuthor = false
        }
    }

    var upperEffectiveTimestamp = upper.timestamp
    var lowerEffectiveTimestamp = lower.timestamp

    // Only when BOTH sides are imported forwards. This replaces sameAuthor wholesale, discarding
    // the anonymous-admin adjustment computed above — keep that ordering.
    if let upperImported = upper.importedForwardDate, let lowerImported = lower.importedForwardDate {
        upperEffectiveTimestamp = upperImported
        lowerEffectiveTimestamp = lowerImported

        if (upper.forwardAuthorId != nil) == (lower.forwardAuthorId != nil)
            && (upper.forwardAuthorSignature != nil) == (lower.forwardAuthorSignature != nil) {
            if let upperAuthorId = upper.forwardAuthorId, let lowerAuthorId = lower.forwardAuthorId {
                sameAuthor = upperAuthorId == lowerAuthorId
            } else if let upperSignature = upper.forwardAuthorSignature,
                      let lowerSignature = lower.forwardAuthorSignature {
                sameAuthor = upperSignature == lowerSignature
            }
        } else {
            sameAuthor = false
        }
    }

    // The original applies this swap to both sides, but only ever reads the upper effective author
    // afterwards, so the lower side's swap has no observable effect. nil when the forward has no
    // author — intentional, matching `lhsEffectiveAuthor = forwardInfo.author`.
    if upper.isRepliesOrSavedMessages, upper.hasForwardInfo {
        upperEffectiveAuthorId = upper.forwardAuthorId
    }

    var isNonMergeablePaid = isPaid
    if isNonMergeablePaid, upper.isMonoforumChannel {
        isNonMergeablePaid = false
    }

    if abs(upperEffectiveTimestamp - lowerEffectiveTimestamp) < Int32(10 * 60)
        && sameChat && sameAuthor && sameThread && !isNonMergeablePaid {
        if let groupChannelId = upper.groupChannelId,
           upperEffectiveAuthorId == groupChannelId,
           !upper.isEffectivelyIncoming {
            return .none
        }

        var upperStyle = upper.mediaMergeStyle
        let lowerStyle = lower.mediaMergeStyle
        if upper.hasInlineReplyMarkup {
            upperStyle = ChatMessageMerge.none.rawValue
        }
        return ChatMessageMerge(rawValue: min(upperStyle, lowerStyle))!
    }

    return .none
}
```

Also move `mediaMergeableStyle(_:)` into this file as a `private func` — the fingerprint calls it, and Task 9 deletes the copy in `ChatMessageItemImpl.swift`. `anonymousGroupAdminSignature` is *not* needed in production: `anonymousSignature` above replaces it.

The remaining risk is transcription. The differential test is what catches it — do not skip Step 7 or weaken the matrix to make it pass.

- [ ] **Step 7: Run the test to verify it passes**

Run the unit-test command.
Expected: PASS. With ~30 cases the matrix is ~900 pairs × 2 orders.

Any failure names the two cases and which order diverged — fix `chatMessageMerge`, never the oracle.

- [ ] **Step 8: Run the full build**

Expected: build succeeds.

- [ ] **Step 9: Commit**

```bash
git add submodules/TelegramUI/Components/Chat/ChatMessageItemCommon
git commit -m "$(cat <<'EOF'
feat(chat): factor messagesShouldBeMerged into an Equatable fingerprint

ChatMessageMergeFingerprint projects a message into the ingredients needed to
reproduce the pairwise merge decision, verified against a verbatim copy of the
current implementation over a matrix of synthesized message pairs.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `ChatHistoryItemNeighbor` and `ChatHistoryItemNeighbors`

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatHistoryItemNeighbors.swift`
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatHistoryItemNeighborsTests.swift`

**Interfaces:**
- Consumes: `AnyEquatable`, `ListViewItemNeighbors` (Task 1); `ChatMessageMergeFingerprint` (Task 3).
- Produces: `ChatHistoryItemNeighbor`, `ChatHistoryItemNeighbors`, `chatItemsHaveCommonDateHeader(_:_:)`.

- [ ] **Step 1: Write the failing test**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Tests/ChatHistoryItemNeighborsTests.swift`:

```swift
import XCTest
import Display
import ChatMessageItemCommon

private func headerId(_ value: Int64) -> ListViewItemNode.HeaderId {
    return ListViewItemNode.HeaderId(space: 0, id: value)
}

final class ChatHistoryItemNeighborsTests: XCTestCase {
    func testDecodesChatNeighbors() {
        let unread = ChatHistoryItemNeighbor.unread(dateHeaderId: headerId(7))
        let neighbors = ChatHistoryItemNeighbors(
            ListViewItemNeighbors(previous: AnyEquatable(unread), next: nil))
        XCTAssertEqual(neighbors.previous, unread)
        XCTAssertNil(neighbors.next)
    }

    func testForeignDescriptorDecodesToNil() {
        let neighbors = ChatHistoryItemNeighbors(
            ListViewItemNeighbors(previous: AnyEquatable.noNeighborInfluence, next: nil))
        XCTAssertNil(neighbors.previous)
    }

    func testDateHeaderIdIsAvailableForEveryCase() {
        XCTAssertEqual(ChatHistoryItemNeighbor.unread(dateHeaderId: headerId(1)).dateHeaderId, headerId(1))
        XCTAssertEqual(ChatHistoryItemNeighbor.replyCount(dateHeaderId: headerId(2)).dateHeaderId, headerId(2))
    }

    func testCommonDateHeader() {
        XCTAssertTrue(chatItemsHaveCommonDateHeader(headerId(1), .unread(dateHeaderId: headerId(1))))
        XCTAssertFalse(chatItemsHaveCommonDateHeader(headerId(1), .unread(dateHeaderId: headerId(2))))
        XCTAssertFalse(chatItemsHaveCommonDateHeader(headerId(1), nil))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the unit-test command.
Expected: build failure — `cannot find type 'ChatHistoryItemNeighbor' in scope`.

- [ ] **Step 3: Implement**

Create `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatHistoryItemNeighbors.swift`:

```swift
import Foundation
import Display

/// What a chat history item publishes about itself for its neighbors.
///
/// There is deliberately no `other` case. A neighbor that is none of these three types and *no
/// neighbor at all* produce identical results in both consumers, so foreign descriptors decode to
/// nil. `ChatBotInfoItem`, `ChatUserInfoItem` and `ChatNewThreadInfoItem` publish
/// `AnyEquatable.noNeighborInfluence`.
public enum ChatHistoryItemNeighbor: Equatable {
    case message(dateHeaderId: ListViewItemNode.HeaderId,
                 topicHeaderId: ListViewItemNode.HeaderId?,
                 merge: ChatMessageMergeFingerprint)
    case unread(dateHeaderId: ListViewItemNode.HeaderId)
    case replyCount(dateHeaderId: ListViewItemNode.HeaderId)

    public var dateHeaderId: ListViewItemNode.HeaderId {
        switch self {
        case let .message(dateHeaderId, _, _):
            return dateHeaderId
        case let .unread(dateHeaderId):
            return dateHeaderId
        case let .replyCount(dateHeaderId):
            return dateHeaderId
        }
    }
}

public struct ChatHistoryItemNeighbors: Equatable {
    public var previous: ChatHistoryItemNeighbor?
    public var next: ChatHistoryItemNeighbor?

    public init(_ neighbors: ListViewItemNeighbors) {
        self.previous = neighbors.previous?.base(ChatHistoryItemNeighbor.self)
        self.next = neighbors.next?.base(ChatHistoryItemNeighbor.self)
    }
}

/// Replaces `chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)`.
///
/// The original's `lhs` was always `self` — a `ChatUnreadItem` or `ChatReplyCountItem`, both of
/// which always carry a header — and it returned false whenever the right-hand header was absent.
public func chatItemsHaveCommonDateHeader(_ dateHeaderId: ListViewItemNode.HeaderId,
                                          _ neighbor: ChatHistoryItemNeighbor?) -> Bool {
    guard let neighbor = neighbor else {
        return false
    }
    return neighbor.dateHeaderId == dateHeaderId
}
```

`ChatMessageMergeFingerprint`'s stored properties are `internal`, so `ChatHistoryItemNeighbor.message`'s synthesized `==` reaches them from the same module. Keep both types in `ChatMessageItemCommon`.

- [ ] **Step 4: Run the test to verify it passes**

Expected: PASS, 4 tests (plus the earlier suites).

- [ ] **Step 5: Run the full build, then commit**

```bash
git add submodules/TelegramUI/Components/Chat/ChatMessageItemCommon
git commit -m "$(cat <<'EOF'
feat(chat): add ChatHistoryItemNeighbor descriptors

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `neighborDescriptor` requirement and the `ItemListItem` facet

Adding a protocol requirement to `ListViewItem` breaks all 164 conformers unless it has a default. This task adds it **with a temporary default**, so the tree keeps building while descriptors are filled in over Tasks 6-7. Task 12 removes the default.

**Files:**
- Modify: `submodules/Display/Source/ListViewItem.swift`
- Create: `submodules/ItemListUI/Sources/ItemListNeighborFacet.swift`

**Interfaces:**
- Consumes: `AnyEquatable` (Task 1).
- Produces: `ListViewItem.neighborDescriptor`; `ItemListNeighborFacet` with `sectionId: ItemListSectionId`, `isAlwaysPlain: Bool`, `requestsNoInset: Bool`, `isTextItem: Bool`; `ItemListItemNeighborDescriptor` payload struct; `itemListNeighbors(item:topFacet:bottomFacet:)`.

- [ ] **Step 1: Add the requirement with a temporary default**

In `submodules/Display/Source/ListViewItem.swift`, add to the `ListViewItem` protocol:

```swift
    /// Everything a *neighbor* is permitted to know about this item.
    ///
    /// Load-bearing: a descriptor must encode everything a neighbor reads. Backends relayout a row
    /// exactly when this value changes on either side, so a fact omitted here goes stale.
    var neighborDescriptor: AnyEquatable { get }
```

and to the `public extension ListViewItem` block:

```swift
    // TEMPORARY: removed in the task that deletes previousItem/nextItem. Conservative — an
    // ObjectIdentifier never compares equal across instances, so an un-migrated item always
    // invalidates its neighbors.
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ObjectIdentifier(self))
    }
```

- [ ] **Step 2: Add the ItemList facet**

Create `submodules/ItemListUI/Sources/ItemListNeighborFacet.swift`:

```swift
import Foundation
import Display

/// What `itemListNeighbors` needs to know about a neighboring item.
public protocol ItemListNeighborFacet {
    var sectionId: ItemListSectionId { get }
    var isAlwaysPlain: Bool { get }
    var requestsNoInset: Bool { get }
    /// Drives the `.reduced` top inset; was `topItem is ItemListTextItem`.
    var isTextItem: Bool { get }
    /// Was `(topItem as? ItemListRevealOptionsStatefulItem)?.hasActiveRevealOptions ?? false`.
    var hasActiveRevealOptions: Bool { get }
}

public struct ItemListItemNeighborDescriptor: Equatable, ItemListNeighborFacet {
    public let sectionId: ItemListSectionId
    public let isAlwaysPlain: Bool
    public let requestsNoInset: Bool
    public let isTextItem: Bool
    public let hasActiveRevealOptions: Bool

    public init(sectionId: ItemListSectionId, isAlwaysPlain: Bool, requestsNoInset: Bool, isTextItem: Bool, hasActiveRevealOptions: Bool) {
        self.sectionId = sectionId
        self.isAlwaysPlain = isAlwaysPlain
        self.requestsNoInset = requestsNoInset
        self.isTextItem = isTextItem
        self.hasActiveRevealOptions = hasActiveRevealOptions
    }
}

public extension ItemListItem where Self: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ItemListItemNeighborDescriptor(
            sectionId: self.sectionId,
            isAlwaysPlain: self.isAlwaysPlain,
            requestsNoInset: self.requestsNoInset,
            isTextItem: self is ItemListTextItem,
            hasActiveRevealOptions: (self as? ItemListRevealOptionsStatefulItem)?.hasActiveRevealOptions ?? false
        ))
    }
}

/// Facet-based replacement for `itemListNeighbors(item:topItem:bottomItem:)`.
public func itemListNeighbors(item: ItemListItem,
                              topFacet: ItemListNeighborFacet?,
                              bottomFacet: ItemListNeighborFacet?) -> ItemListNeighbors {
    let topNeighbor: ItemListNeighbor
    if let topFacet = topFacet {
        if topFacet.sectionId != item.sectionId {
            let topInset: ItemListInsetWithOtherSection
            if topFacet.requestsNoInset {
                topInset = .none
            } else {
                if topFacet.isTextItem {
                    topInset = .reduced
                } else {
                    topInset = .full
                }
            }
            topNeighbor = .otherSection(topInset)
        } else {
            topNeighbor = .sameSection(alwaysPlain: topFacet.isAlwaysPlain)
        }
    } else {
        topNeighbor = .none
    }

    let bottomNeighbor: ItemListNeighbor
    if let bottomFacet = bottomFacet {
        if bottomFacet.sectionId != item.sectionId {
            let bottomInset: ItemListInsetWithOtherSection
            if bottomFacet.requestsNoInset {
                bottomInset = .none
            } else {
                bottomInset = .full
            }
            bottomNeighbor = .otherSection(bottomInset)
        } else {
            bottomNeighbor = .sameSection(alwaysPlain: bottomFacet.isAlwaysPlain)
        }
    } else {
        bottomNeighbor = .none
    }

    return ItemListNeighbors(
        top: topNeighbor,
        bottom: bottomNeighbor,
        topHasActiveRevealOptions: topFacet?.hasActiveRevealOptions ?? false,
        bottomHasActiveRevealOptions: bottomFacet?.hasActiveRevealOptions ?? false
    )
}
```

This is `submodules/ItemListUI/Sources/ItemListItem.swift:80-124` with `topItem`/`bottomItem` replaced by facets. Note the asymmetry in the original, preserved here: the `.reduced` inset is computed for the **top** neighbor only — the bottom branch has no `isTextItem` check. Do not "fix" that.

Keep the old `itemListNeighbors(item:topItem:bottomItem:)` in place for now — Task 10 deletes it once all callers move.

- [ ] **Step 3: Run the full build**

Expected: build succeeds. The extension supplies `neighborDescriptor` for all ~110 `ItemListItem` conformers, shadowing the temporary default.

Confirm the extension is actually winning for at least one item by adding a temporary `print` — or simpler, trust Task 10's behavior check and move on.

- [ ] **Step 4: Commit**

```bash
git add submodules/Display/Source/ListViewItem.swift \
        submodules/ItemListUI/Sources/ItemListNeighborFacet.swift
git commit -m "$(cat <<'EOF'
feat(display): add neighborDescriptor requirement and the ItemList facet

Temporary ObjectIdentifier default keeps un-migrated items compiling; removed
once previousItem/nextItem are deleted.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Chat item descriptors

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatUnreadItem.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatReplyCountItem.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatBotInfoItem/Sources/ChatBotInfoItem.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatUserInfoItem/Sources/ChatUserInfoItem.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatNewThreadInfoItem/Sources/ChatNewThreadInfoItem.swift`

**Interfaces:**
- Consumes: `ChatHistoryItemNeighbor` (Task 4), `ChatMessageMergeFingerprint` (Task 3).
- Produces: `neighborDescriptor` on all six chat history items.

- [ ] **Step 1: `ChatMessageItemImpl`**

Add to the class:

```swift
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ChatHistoryItemNeighbor.message(
            dateHeaderId: self.dateHeader.id,
            topicHeaderId: self.topicHeader?.id,
            merge: ChatMessageMergeFingerprint(message: self.message,
                                               accountPeerId: self.context.account.peerId)
        ))
    }
```

Computed, not stored: it is evaluated only when an adjacent item is laid out or diffed, and it costs the same media/attribute walk `messagesShouldBeMerged` already does per layout. Items are created for every entry in the filtered view, most of which never reach layout — storing it would pay that cost for all of them.

- [ ] **Step 2: `ChatUnreadItem` and `ChatReplyCountItem`**

```swift
    // ChatUnreadItem
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ChatHistoryItemNeighbor.unread(dateHeaderId: self.header.id))
    }

    // ChatReplyCountItem
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ChatHistoryItemNeighbor.replyCount(dateHeaderId: self.header.id))
    }
```

- [ ] **Step 3: The three info items**

To each of `ChatBotInfoItem`, `ChatUserInfoItem`, `ChatNewThreadInfoItem`:

```swift
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }
```

Correct because they decode to `nil`, which is the same branch a missing neighbor takes; and because it is one shared constant, replacing one info item with another triggers no neighbor relayout.

- [ ] **Step 4: Run the full build**

Expected: build succeeds. Each module needs `import ChatMessageItemCommon` if it does not already have it.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/Chat
git commit -m "$(cat <<'EOF'
feat(chat): publish neighbor descriptors from chat history items

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Header and bespoke descriptors

**Files:**
- Modify: the 4 `ListViewItemWithHeader` conformers and the 11 types listed below.

Find them:
```bash
grep -rn ": ListViewItemWithHeader\|, ListViewItemWithHeader" --include='*.swift' submodules/ Telegram/ | grep -v protocol
grep -rn "previousItem as? \|nextItem as? " --include='*.swift' submodules/ Telegram/ | grep -v "as? ItemListItem\|as? ListViewItemWithHeader"
```

**Interfaces:**
- Consumes: `AnyEquatable`, `HeaderNeighborFacet` (Task 1), `ItemListNeighborFacet` (Task 5).
- Produces: one descriptor payload per bespoke type, each conforming to the facets its neighbors read.

- [ ] **Step 1: Enumerate what each neighbor is actually read for**

For each of the 11 types below, find the sites that cast to it and write down the exact fields read. Do this first, in one pass, before writing any payload — the payload's field list is exactly this list.

`SettingsSearchRecentItem`, `ItemListVenueItem`, `ContactsPeerItem`, `ContactsAddItem`, `ContactListActionItem`, `ChatListItem`, `CallListGroupCallItem`, `CallListCallItem`, `ChatListAdditionalCategoryItem`, `BotCheckoutPriceItem`, `BotCheckoutHeaderItem`.

Several are pure type-presence checks — e.g. `BotCheckoutPriceItem` only asks whether the item above is a `BotCheckoutHeaderItem`, and `ContactListActionItem` only asks whether its neighbor is a `ContactsPeerItem` or another `ContactListActionItem`. For those the payload needs no fields beyond its own distinct type; declare a facet like:

```swift
public protocol BotCheckoutNeighborFacet {
    var isHeaderItem: Bool { get }
    var isPriceItem: Bool { get }
}
```

and have both items' payloads conform. Prefer a boolean facet over "recover the payload type and check which one it is" — the latter reintroduces concrete-type coupling.

- [ ] **Step 2: Write the payloads and `neighborDescriptor` implementations**

For the 4 header items, the payload conforms to `HeaderNeighborFacet`:

```swift
private struct ContactsPeerItemNeighborDescriptor: Equatable, ItemListNeighborFacet, HeaderNeighborFacet {
    let sectionId: ItemListSectionId
    let isAlwaysPlain: Bool
    let requestsNoInset: Bool
    let isTextItem: Bool
    let headerId: ListViewItemNode.HeaderId?
    let isContactsPeerItem: Bool
}

extension ContactsPeerItem {
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ContactsPeerItemNeighborDescriptor(
            sectionId: self.sectionId,
            isAlwaysPlain: self.isAlwaysPlain,
            requestsNoInset: self.requestsNoInset,
            isTextItem: false,
            headerId: self.header?.id,
            isContactsPeerItem: true
        ))
    }
}
```

Items that need more than the `ItemListItem` extension provides declare the property on the concrete type, which shadows the extension. Items that need *only* the ItemList facet need no change — Task 5 already covers them.

- [ ] **Step 3: Run the full build**

Expected: build succeeds. Nothing consumes these yet.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat(lists): publish neighbor descriptors for header and bespoke items

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Thread `neighbors:` through the protocol alongside the old parameters

Mechanical sweep #1. The signature gains `neighbors:` while keeping `previousItem:`/`nextItem:`, so every consumer body stays valid and behavior is unchanged. Tasks 9-11 then migrate bodies in small, independently revertable groups; Task 12 deletes the old parameters.

Doing it in two sweeps rather than one big-bang means every *semantic* change lands in a commit small enough to bisect.

**Files:**
- Modify: `submodules/Display/Source/ListViewItem.swift`, `ListViewItemNode.swift`, `ListView.swift`
- Modify: all 164 `ListViewItem` conformers, all 41 `layoutForParams` overrides, ~70 external call sites

**Interfaces:**
- Produces: `ListView.neighbors(at index: Int) -> ListViewItemNeighbors`; the dual-parameter signatures.

- [ ] **Step 1: Change the protocol**

In `ListViewItem`:

```swift
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void)
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void)
```

In `ListViewItemNode`:

```swift
    open func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?, neighbors: ListViewItemNeighbors) {
```

- [ ] **Step 2: Add the `ListView` helper**

In `submodules/Display/Source/ListView.swift`:

```swift
    private func neighbors(at index: Int) -> ListViewItemNeighbors {
        return ListViewItemNeighbors(
            previous: index == 0 ? nil : self.items[index - 1].neighborDescriptor,
            next: index == self.items.count - 1 ? nil : self.items[index + 1].neighborDescriptor
        )
    }
```

Then pass `neighbors: self.neighbors(at: index)` at each of the call sites that currently build `previousItem:`/`nextItem:` inline — `ListView.swift:2289`, `:2363`, `:2400`, and inside `nodeForItem` (`:1805`, `:1843`, where the values arrive as parameters, so thread a `neighbors` parameter into `nodeForItem` too).

Note the index bases: `neighbors(at:)` uses the same `self.items` array and the same `index == 0` / `index == count - 1` guards the inline expressions use today, so the values are identical.

- [ ] **Step 3: Sweep the conformers**

Enumerate:
```bash
grep -rn "func nodeConfiguredForParams" --include='*.swift' submodules/ Telegram/ | wc -l   # expect 164
grep -rn "func updateNode(async" --include='*.swift' submodules/ Telegram/ | wc -l          # expect 164
grep -rn "func layoutForParams" --include='*.swift' submodules/ Telegram/ | wc -l           # expect 41
```

Add `neighbors: ListViewItemNeighbors` after `nextItem:` in every declaration, and `neighbors: neighbors` (or `neighbors: .none`) at every call site. Bodies are untouched.

The 3 `layoutForParams` call sites are all item-internal, in `CallListHoleItem.swift:24`, `ChatListHoleItem.swift:24`, `ChatReplyCountItem.swift:36` — forward the `neighbors` they received.

Standalone preview renderers that currently pass `previousItem: nil, nextItem: nil` pass `neighbors: .none`.

- [ ] **Step 4: Run the full build with `--continueOnError`**

Expected: a long list of "missing argument for parameter 'neighbors'" errors on the first pass. Fix, repeat until clean. Because `--continueOnError` is set, each pass enumerates everything remaining rather than stopping at the first failure.

- [ ] **Step 5: Verify behavior is unchanged**

Launch on the K1 sim and confirm chat, a settings screen, and the contacts list render exactly as before. No consumer reads `neighbors` yet, so any visible difference means a call site was mis-threaded.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(lists): thread ListViewItemNeighbors alongside previousItem/nextItem

Mechanical: adds the parameter everywhere and computes it in ListView. No
consumer reads it yet, so behavior is unchanged.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Migrate chat consumers to descriptors

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItem/Sources/ChatMessageItem.swift:144`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift:698-701`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatUnreadItem.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatReplyCountItem.swift`

**Interfaces:**
- Consumes: `ChatHistoryItemNeighbors`, `chatMessageMerge(upper:lower:)`, `chatItemsHaveCommonDateHeader(_:_:)`.
- Produces: `ChatMessageItem.merged(with:isRotated:)`, replacing `mergedWithItems(top:bottom:isRotated:)`.

- [ ] **Step 1: Change the protocol method**

In `ChatMessageItem.swift`, replace the `mergedWithItems` requirement with:

```swift
    func merged(with neighbors: ChatHistoryItemNeighbors, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec)
```

- [ ] **Step 2: Rewrite the implementation**

Replace `ChatMessageItemImpl.mergedWithItems` (lines 611-665) with:

```swift
    public func merged(with neighbors: ChatHistoryItemNeighbors, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec) {
        var top = neighbors.previous
        var bottom = neighbors.next
        if !isRotated {
            let previousTop = top
            top = bottom
            bottom = previousTop
        }

        let selfFingerprint = ChatMessageMergeFingerprint(message: self.message,
                                                          accountPeerId: self.context.account.peerId)

        var mergedTop: ChatMessageMerge = .none
        var mergedBottom: ChatMessageMerge = .none
        var dateAtBottom = ChatMessageHeaderSpec(hasDate: false, hasTopic: false)

        if case let .message(topDateHeaderId, _, topMerge) = top {
            if topDateHeaderId != self.dateHeader.id {
                mergedBottom = .none
            } else {
                mergedBottom = chatMessageMerge(upper: selfFingerprint, lower: topMerge)
            }
        }

        switch bottom {
        case let .message(bottomDateHeaderId, bottomTopicHeaderId, bottomMerge):
            if bottomDateHeaderId != self.dateHeader.id {
                mergedTop = .none
                dateAtBottom.hasDate = true
            }
            if let topicHeader = self.topicHeader, bottomTopicHeaderId != topicHeader.id {
                mergedTop = .none
                dateAtBottom.hasTopic = true
            }
            if !(dateAtBottom.hasDate || dateAtBottom.hasTopic) {
                mergedTop = chatMessageMerge(upper: bottomMerge, lower: selfFingerprint)
            }
        case let .unread(bottomDateHeaderId), let .replyCount(bottomDateHeaderId):
            if bottomDateHeaderId != self.dateHeader.id {
                dateAtBottom.hasDate = true
            }
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        case nil:
            dateAtBottom.hasDate = true
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        }

        return (mergedTop, mergedBottom, dateAtBottom)
    }
```

Check this against the original line by line. The argument order matters: the original calls `messagesShouldBeMerged(accountPeerId, self.message, top.message)` for `mergedBottom` — `self` is the upper — and `messagesShouldBeMerged(accountPeerId, bottom.message, self.message)` for `mergedTop`.

- [ ] **Step 3: Delete the dead originals**

Delete `messagesShouldBeMerged`, `mediaMergeableStyle`, `anonymousGroupAdminSignature` and the old `chatItemsHaveCommonDateHeader` from `ChatMessageItemImpl.swift` (lines 20-204). The oracle copy in the test target keeps the original behavior pinned.

- [ ] **Step 4: Update the three call sites**

In `ChatMessageItemImpl.nodeConfiguredForParams` and `.updateNode`, and in `ChatMessageItemView.layoutForParams`:

```swift
let (top, bottom, dateAtBottom) = self.merged(with: ChatHistoryItemNeighbors(neighbors), isRotated: self.controllerInteraction.chatIsRotated)
```

In `ChatUnreadItem` and `ChatReplyCountItem`, replace each `!chatItemsHaveCommonDateHeader(self, nextItem)` with:

```swift
let chatNeighbors = ChatHistoryItemNeighbors(neighbors)
let dateAtBottom = !chatItemsHaveCommonDateHeader(self.header.id, chatNeighbors.next)
```

- [ ] **Step 5: Run the tests and the full build**

Expected: unit tests still PASS; build succeeds.

- [ ] **Step 6: Verify on the K1 sim**

Open a chat with: consecutive messages from one author (merged bubbles), messages spanning a date boundary (date header + unmerged), an unread bar, a forum topic with a topic header, and a message with an inline keyboard directly above another (must not merge). Compare against `git stash`-ed master if anything looks off.

- [ ] **Step 7: Commit**

```bash
git add -A submodules/TelegramUI/Components/Chat
git commit -m "$(cat <<'EOF'
refactor(chat): compute merge state from neighbor descriptors

Replaces mergedWithItems(top:bottom:) with merged(with:isRotated:) and deletes
messagesShouldBeMerged from production code.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Migrate `ItemListItem` consumers

**Files:**
- Modify: `submodules/ItemListUI/Sources/ItemListItem.swift:80-125` (delete the old helper)
- Modify: every caller of `itemListNeighbors(item:topItem:bottomItem:)` and every `previousItem as? ItemListItem` site

Find them:
```bash
grep -rn "itemListNeighbors(item:" --include='*.swift' submodules/ Telegram/
grep -rn "previousItem as? ItemListItem\|nextItem as? ItemListItem" --include='*.swift' submodules/ Telegram/
```

- [ ] **Step 1: Rewrite the call sites**

```swift
// before
itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem)
// after
itemListNeighbors(item: self,
                  topFacet: neighbors.previous?.base(ItemListNeighborFacet.self),
                  bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self))
```

and the inline idiom:

```swift
// before
if let previousItem = previousItem as? ItemListItem, previousItem.sectionId == self.sectionId && !previousItem.isAlwaysPlain {
// after
if let previous = neighbors.previous?.base(ItemListNeighborFacet.self), previous.sectionId == self.sectionId && !previous.isAlwaysPlain {
```

- [ ] **Step 2: Delete the old helper**

Remove `itemListNeighbors(item:topItem:bottomItem:)` from `ItemListItem.swift`. Any remaining caller becomes a compile error, which is the point.

- [ ] **Step 3: Run the full build with `--continueOnError`**

Expected: errors only at sites not yet converted. Repeat until clean.

- [ ] **Step 4: Verify on the K1 sim**

Open Settings and a peer info screen. Check: section top/bottom insets, the reduced inset under a text/footer item, separator inset on the first and last row of each section, and a plain (`isAlwaysPlain`) row inside a grouped section.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(itemlist): read section neighbors through ItemListNeighborFacet

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Migrate header and bespoke consumers

**Files:**
- Modify: the sites found by the two greps in Task 7.

- [ ] **Step 1: Rewrite header-run detection**

```swift
// before
if let previousItem = previousItem as? ListViewItemWithHeader {
    firstWithHeader = header.id != previousItem.header?.id
} else {
    firstWithHeader = true
}
// after
if let previous = neighbors.previous?.base(HeaderNeighborFacet.self) {
    firstWithHeader = header.id != previous.headerId
} else {
    firstWithHeader = true
}
```

The outer `if let previousItem = previousItem` that distinguishes "no neighbor" from "neighbor without a header" becomes `if neighbors.previous != nil`. Keep that distinction — `first` and `firstWithHeader` mean different things and drive different separators.

- [ ] **Step 2: Rewrite the bespoke sites**

Replace each concrete-type cast with the facet query defined in Task 7:

```swift
// before
if let _ = previousItem as? BotCheckoutHeaderItem {
// after
if neighbors.previous?.base(BotCheckoutNeighborFacet.self)?.isHeaderItem == true {
```

- [ ] **Step 3: Run the full build with `--continueOnError`**

- [ ] **Step 4: Verify on the K1 sim**

Contacts list (section letter headers: first/last row rounding per header run), call list (grouped calls), bot checkout (price rows under the header), chat list additional categories, and the venue picker.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(lists): read header and sibling-type neighbors through facets

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Delete `previousItem`/`nextItem` and the temporary default

Mechanical sweep #2, and the point of the whole exercise: after this, an item physically cannot read anything about a neighbor that the neighbor did not publish.

**Files:**
- Modify: `submodules/Display/Source/ListViewItem.swift`, `ListViewItemNode.swift`, `ListView.swift`, plus every conformer and call site from Task 8.

- [ ] **Step 1: Delete the parameters**

Remove `previousItem: ListViewItem?, nextItem: ListViewItem?` from `ListViewItem.nodeConfiguredForParams`, `ListViewItem.updateNode`, and `ListViewItemNode.layoutForParams`, and from every conformer and call site.

- [ ] **Step 2: Delete the temporary default**

Remove the `neighborDescriptor` default implementation from the `public extension ListViewItem` block added in Task 5.

- [ ] **Step 3: Run the full build with `--continueOnError`**

Expected, in order:
1. "missing argument"/"extra argument" errors at call sites — fix.
2. `type 'X' does not conform to protocol 'ListViewItem'` for every item with no explicit descriptor. Add `public var neighborDescriptor: AnyEquatable { return AnyEquatable.noNeighborInfluence }` to each — expect roughly 35.
3. Any surviving `previousItem`/`nextItem` reference in a body — this is the important category. It means a neighbor fact was being read that no descriptor publishes. Do **not** paper over it: add the fact to that neighbor's payload and read it through a facet.

- [ ] **Step 4: Confirm the parameters are gone**

```bash
grep -rn "previousItem: ListViewItem?\|nextItem: ListViewItem?" --include='*.swift' submodules/ Telegram/
```
Expected: no output.

- [ ] **Step 5: Run the tests and verify on the K1 sim**

Re-run the full manual sweep from Tasks 9-11: chat, settings, contacts, call list, bot checkout.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(lists): remove previousItem/nextItem from the ListViewItem API

Items now see only what their neighbors publish. neighborDescriptor loses its
temporary default and becomes a required member.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Precise invalidation in `ListViewImpl`

**Files:**
- Modify: `submodules/Display/Source/ListViewItemNode.swift` (add `appliedNeighbors`)
- Modify: `submodules/Display/Source/ListView.swift:2015-2160` (the adjacency computation), `:1766-1850` (`nodeForItem`), `:2238-2325` (`updateAdjacent`)

- [ ] **Step 1: Store the applied value**

In `ListViewItemNode`:

```swift
    /// The neighbors value the current layout was computed with. Drives descriptor-diff
    /// invalidation in ListView.
    public internal(set) final var appliedNeighbors: ListViewItemNeighbors = .none
```

Assign it wherever a layout computed with a given `neighbors` is committed: both branches of `nodeForItem` and the inline `updateNode` call in `updateAdjacent`.

- [ ] **Step 2: Replace the adjacency computation**

In `deleteAndInsertItemsTransaction`, delete:
- the `updateAdjacentItemsIndices.insert(updatedIndex)` in the delete pass (`ListView.swift:2042`),
- the `remappedUpdateAdjacentItemsIndices` block (`:2101-2108`),
- the insert-pass loop that adds neighbors of inserted indices (`:2115-2120`),
- the `var updateAdjacentItemsIndices = Set<Int>()` declaration (`:2015`).

Replace the `var updateIndices = updateAdjacentItemsIndices` at `:2141` with:

```swift
                var updateIndices = Set<Int>()
                for case let .Node(index, _, referenceNode, _) in updatedState.nodes {
                    guard let node = referenceNode?.syncWith({ $0 }) else {
                        continue
                    }
                    if node.appliedNeighbors != self.neighbors(at: index) {
                        updateIndices.insert(index)
                    }
                }
```

Leave the `if widthUpdated` block and `updateIndices.subtract(explicitelyUpdateIndices)` exactly as they are — explicitly updated items relayout via `updateNodes` and set their own `appliedNeighbors`.

The remap dance disappears because the diff now runs after remapping, against final indices.

- [ ] **Step 3: Run the full build**

- [ ] **Step 4: Verify the behavior delta on the K1 sim**

Three checks, in a chat:
1. **Send a message** into a run from the same author — the bubble above must lose its rounded bottom corner (insert adjacency still fires).
2. **Delete a message** from the middle of a mixed run — neighbors must re-merge correctly.
3. **Edit a message** so its media merge style changes (send a text message under a sticker from the same author, then edit the sticker message's content) — the neighbor must now update. This case was previously broken; it is the bug fix.

Also scroll a long chat and a settings screen and watch for layout thrash — an item relayouting on every transaction means some descriptor is unstable (most likely one still carrying an `ObjectIdentifier` or a freshly-allocated value).

- [ ] **Step 5: Commit**

```bash
git add submodules/Display/Source/ListView.swift submodules/Display/Source/ListViewItemNode.swift
git commit -m "$(cat <<'EOF'
perf(listview): invalidate neighbors by descriptor diff

Relayout a row iff its neighbors value changed, replacing the unconditional
insert/delete adjacency sweep. Also fixes neighbors of *updated* items, which
were never relaid out.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Wire CoreList

**Files:**
- Modify: `submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift:490-600`

- [ ] **Step 1: Carry neighbors on the wrapper**

```swift
private final class CoreListEntryItem: CoreListItem {
    let stableId: UInt64
    let stableVersion: Int
    let listItem: ListViewItem
    let neighbors: ListViewItemNeighbors

    var identity: AnyHashable { AnyHashable(self.stableId) }

    init(stableId: UInt64, stableVersion: Int, listItem: ListViewItem, neighbors: ListViewItemNeighbors) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.listItem = listItem
        self.neighbors = neighbors
    }

    func view() -> UIView & CoreListItemView {
        return CoreListNodeHostView(listItem: self.listItem, neighbors: self.neighbors)
    }

    // Content equality: the engine matches rows by `identity` (= stableId); this additionally
    // compares `stableVersion` so a same-stableId entry whose content was swapped reconfigures its
    // reused view, and `neighbors` so a row re-applies when an adjacent item changed.
    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? CoreListEntryItem else { return false }
        if other.stableId != self.stableId { return false }
        if other.stableVersion != self.stableVersion { return false }
        if other.neighbors != self.neighbors { return false }
        return true
    }

    func apply(to view: UIView & CoreListItemView) {
        (view as? CoreListNodeHostView)?.setListItem(self.listItem, neighbors: self.neighbors)
    }
}
```

- [ ] **Step 2: Compute neighbors when the array is built**

After the insert/update handling around `:248` and `:257` produces the final item array, walk it once and rebuild each `CoreListEntryItem` with

```swift
ListViewItemNeighbors(
    previous: index == 0 ? nil : items[index - 1].listItem.neighborDescriptor,
    next: index == items.count - 1 ? nil : items[index + 1].listItem.neighborDescriptor
)
```

The backend feeds items in `ListView` index order, so this matches `ListView.neighbors(at:)` exactly and the `isRotated` flip inside `merged(with:isRotated:)` is untouched.

- [ ] **Step 3: Pass them into layout**

In `CoreListNodeHostView`, store the neighbors alongside the item (`setListItem(_:neighbors:)`, setting `contentDirty` when either changes) and replace both `previousItem: nil, nextItem: nil` arguments in `rebuild(width:)` with `neighbors: self.neighbors`.

- [ ] **Step 4: Run the full build**

- [ ] **Step 5: Verify on the K1 sim**

Enable the CoreList backend (`makeListView(rotated:useCoreListBackend:)`) and open a chat. Consecutive messages from one author must now merge, and date headers must appear only at day boundaries — today the backend renders every message unmerged with its own date header. Send, delete, and edit messages and confirm neighbors update.

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift
git commit -m "$(cat <<'EOF'
feat(corelist): neighbor-aware layout in the chat history backend

Rows carry their neighbors value, compare it in isEqual, and pass it into
layout — so bubbles merge and date headers collapse as they do on ListViewImpl.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/chat/corelist-chat-history-backend.md`

- [ ] **Step 1: Document the invariant in `CLAUDE.md`**

Add a section near "View frame ownership":

```markdown
## Neighbor descriptors

A `ListViewItem` does not see its neighbors. It sees `ListViewItemNeighbors` — two `AnyEquatable`
descriptors that the adjacent items published via `neighborDescriptor`, read through facet protocols
(`ItemListNeighborFacet`, `HeaderNeighborFacet`, and bespoke ones).

**A descriptor must encode everything a neighbor reads.** Backends relayout a row exactly when its
neighbors value changes, so a fact omitted from a descriptor goes stale on screen. When adding a
neighbor-dependent behavior, add the fact to the neighbor's payload — never widen the API back to
passing items.

`neighborDescriptor` has no default implementation, on purpose: a conservative default would make
un-migrated items force a relayout on every transaction. `AnyEquatable.noNeighborInfluence` is the
answer for items nothing reads.

`nil` on a side means *no neighbor*; a non-nil descriptor whose facet does not resolve means *a
neighbor that publishes nothing relevant*. Several items depend on that distinction.
```

- [ ] **Step 2: Update the CoreList doc**

In `docs/chat/corelist-chat-history-backend.md`, remove neighbor awareness from the deferred-items list and describe the implemented behavior: neighbors computed in index order, compared in `CoreListEntryItem.isEqual`, passed into `updateNode`/`nodeConfiguredForParams`.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md docs/chat/corelist-chat-history-backend.md
git commit -m "$(cat <<'EOF'
docs: record the neighbor-descriptor invariant

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```
