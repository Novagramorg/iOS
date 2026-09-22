import Foundation
import XCTest
import Intents
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// Where a Siri "reply" (`INSendMessageIntent`) goes.
///
/// Once Siri reads group messages, its reply arrives with the group's `conversationIdentifier`
/// and the author as recipient. Sending to the recipient would put a group reply into the
/// author's private chat, so the conversation wins; and a broadcast channel is never a target,
/// even though Siri can read its posts.
final class SiriSendMessageTargetTests: XCTestCase {
    private func peerId(_ namespace: PeerId.Namespace, _ id: Int64) -> PeerId {
        return PeerId(namespace: namespace, id: PeerId.Id._internalFromInt64Value(id))
    }

    func testConversationIdentifierWinsOverTheRecipient() {
        let group = peerId(Namespaces.Peer.CloudGroup, 2001)
        let author = peerId(Namespaces.Peer.CloudUser, 1001)

        let target = siriSendMessageTarget(conversationIdentifier: "\(group.toInt64())", recipientCustomIdentifier: "tg\(author.toInt64())")

        XCTAssertEqual(target, group)
    }

    func testRecipientIsUsedWithoutAConversation() {
        let author = peerId(Namespaces.Peer.CloudUser, 1001)

        XCTAssertEqual(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: "tg\(author.toInt64())"), author)
    }

    func testUnparsableIdentifiersNameNoTarget() {
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: "not-a-peer", recipientCustomIdentifier: nil))
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: "device-contact-42"))
        XCTAssertNil(siriSendMessageTarget(conversationIdentifier: nil, recipientCustomIdentifier: nil))
    }

    /// The standalone send swallows the server's refusal, so a peer the user cannot write to
    /// must be refused up front or Siri reports the reply as sent.
    func testChatsTheUserCannotWriteToAreRefused() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2001, title: "Left", membership: .Left)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2002, title: "Removed", membership: .Removed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.group(2003, title: "Read-only", defaultBannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3001, title: "Left", participationStatus: .left)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3002, title: "Kicked", participationStatus: .kicked)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3003, title: "Restricted", bannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3004, title: "Read-only", defaultBannedRights: IntentMessageFixtures.noTextAllowed)))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3005, title: "Paid", sendPaidMessageStars: StarsAmount(value: 10, nanos: 0))))
    }

    /// `INMessage.conversationIdentifier` names the chat only, so a reply into a forum would
    /// land in the wrong topic; until the topic travels with it, forums are not a target.
    func testForumsAndMonoforumsAreNotATarget() {
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3006, title: "Forum", flags: [.isForum])))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3007, title: "Monoforum", flags: [.isMonoforum])))
    }

    func testUsersAndGroupsAcceptSiriMessagesButBroadcastChannelsDoNot() {
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.user(1001, firstName: "Alice")))
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.group(2001, title: "Group")))
        XCTAssertTrue(peerAcceptsSiriMessages(IntentMessageFixtures.supergroup(3001, title: "Supergroup")))
        XCTAssertFalse(peerAcceptsSiriMessages(IntentMessageFixtures.broadcastChannel(4001, title: "Channel")))
    }
}
