import XCTest
import TONTestVectors
import TONCore
import TONCrypto
@testable import TONContracts

/// Shared fixtures matching the vector generator's `sendMsgAction(i)`.
enum Fixtures {
    static let dest = try! Address.parseRaw(
        "0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8"
    )
    static let dest2 = try! Address.parseRaw(
        "0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc"
    )

    /// Alternates destinations and increments value, exactly as the generator does.
    static func sendAction(_ index: Int) -> WalletV5Action {
        .sendMessage(
            mode: [.payGasSeparately, .ignoreErrors],
            message: MessageRelaxed.makeInternal(
                to: index % 2 == 0 ? dest : dest2,
                value: BigUInt(1000 + index),
                bounce: true
            )
        )
    }

    /// The generator signs with seed 0 (all zero bytes).
    static var signingKey: Data {
        get throws { try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).secretKey }
    }
}

/// Verifies action-list packing against golden vectors.
///
/// The packing rules are asymmetric — out-actions reverse and chain outward, extended
/// actions chain inward — so a plausible-looking implementation can execute transfers in
/// the wrong order.
final class ActionListTests: XCTestCase {
    struct ActionVectors: Decodable {
        let packed: [Packed]
        let individual: [Individual]
        let opcodes: Opcodes

        struct Packed: Decodable {
            let label: String
            let actionCount: Int
            let boc: String
            let hash: String
        }

        struct Individual: Decodable {
            let label: String
            let boc: String
            let hash: String
        }

        struct Opcodes: Decodable {
            let action_send_msg: UInt64
            let action_extended_add_extension: UInt64
            let action_extended_remove_extension: UInt64
            let action_extended_set_signature_auth_allowed: UInt64
            let auth_signed: UInt64
            let auth_signed_internal: UInt64
        }
    }

    private func vectors() throws -> ActionVectors {
        let loaded: ActionVectors = try Vectors.load("actions.json")
        XCTAssertGreaterThanOrEqual(loaded.packed.count, 15, "actions.json lost packed cases")
        XCTAssertGreaterThanOrEqual(loaded.individual.count, 5, "actions.json lost individual cases")
        return loaded
    }

    /// Opcodes come from the contract spec; a wrong one is silently rejected on-chain.
    func testOpcodesMatchReference() throws {
        let o = try vectors().opcodes
        XCTAssertEqual(WalletV5Action.sendMessageTag, o.action_send_msg)
        XCTAssertEqual(WalletV5Action.addExtensionTag, o.action_extended_add_extension)
        XCTAssertEqual(WalletV5Action.removeExtensionTag, o.action_extended_remove_extension)
        XCTAssertEqual(
            WalletV5Action.setSignatureAuthAllowedTag,
            o.action_extended_set_signature_auth_allowed
        )
        XCTAssertEqual(WalletV5R1.AuthKind.external.opcode, o.auth_signed)
        XCTAssertEqual(WalletV5R1.AuthKind.internalMessage.opcode, o.auth_signed_internal)
    }

    /// Each action's own serialization, so a packing bug can be told apart from an
    /// action-encoding bug.
    func testIndividualActionSerializationMatchesReference() throws {
        let byLabel = Dictionary(uniqueKeysWithValues: try vectors().individual.map { ($0.label, $0) })

        let cases: [(String, WalletV5Action)] = [
            ("send-msg", Fixtures.sendAction(0)),
            ("add-extension", .addExtension(Fixtures.dest)),
            ("remove-extension", .removeExtension(Fixtures.dest)),
            ("set-sig-auth-true", .setSignatureAuthAllowed(true)),
            ("set-sig-auth-false", .setSignatureAuthAllowed(false)),
        ]

        for (label, action) in cases {
            let expected = try XCTUnwrap(byLabel[label], "missing individual vector \(label)")
            let cell = try action.serialize()
            XCTAssertEqual(cell.toBoc().base64EncodedString(), expected.boc, "serialization of \(label)")
            XCTAssertEqual(try cell.hash().hexString, expected.hash, "hash of \(label)")
        }
    }

    func testPackedActionListsMatchReference() throws {
        let byLabel = Dictionary(uniqueKeysWithValues: try vectors().packed.map { ($0.label, $0) })

        let cases: [(String, [WalletV5Action])] = [
            ("empty", []),
            ("one-send", [Fixtures.sendAction(0)]),
            ("two-sends", [Fixtures.sendAction(0), Fixtures.sendAction(1)]),
            ("four-sends", (0..<4).map(Fixtures.sendAction)),
            ("254-sends", (0..<254).map(Fixtures.sendAction)),
            ("255-sends", (0..<255).map(Fixtures.sendAction)),
            ("add-extension-only", [.addExtension(Fixtures.dest)]),
            ("remove-extension-only", [.removeExtension(Fixtures.dest)]),
            ("set-sig-auth-allowed-true", [.setSignatureAuthAllowed(true)]),
            ("set-sig-auth-allowed-false", [.setSignatureAuthAllowed(false)]),
            ("two-extended", [.addExtension(Fixtures.dest), .removeExtension(Fixtures.dest2)]),
            (
                "three-extended",
                [
                    .addExtension(Fixtures.dest),
                    .removeExtension(Fixtures.dest2),
                    .setSignatureAuthAllowed(true),
                ]
            ),
            ("mixed-send-then-extended", [Fixtures.sendAction(0), .addExtension(Fixtures.dest)]),
            ("mixed-extended-then-send", [.addExtension(Fixtures.dest), Fixtures.sendAction(0)]),
            (
                "mixed-many",
                [
                    Fixtures.sendAction(0),
                    .addExtension(Fixtures.dest),
                    Fixtures.sendAction(1),
                    .setSignatureAuthAllowed(false),
                    Fixtures.sendAction(2),
                ]
            ),
        ]

        for (label, actions) in cases {
            let expected = try XCTUnwrap(byLabel[label], "missing packed vector \(label)")
            let cell = try ActionList.pack(actions)
            XCTAssertEqual(cell.toBoc().base64EncodedString(), expected.boc, "packing of \(label)")
            XCTAssertEqual(try cell.hash().hexString, expected.hash, "hash of \(label)")
            XCTAssertEqual(actions.count, expected.actionCount, "action count for \(label)")
        }
    }

    /// Supplying extended actions before or after out-actions must produce the same
    /// cell, because packing partitions rather than preserving order.
    func testExtendedActionOrderDoesNotAffectPacking() throws {
        let a = try ActionList.pack([Fixtures.sendAction(0), .addExtension(Fixtures.dest)])
        let b = try ActionList.pack([.addExtension(Fixtures.dest), Fixtures.sendAction(0)])
        XCTAssertEqual(try a.hash(), try b.hash())
    }

    /// Out-action order *does* matter — reversing the inputs must change the cell.
    func testOutActionOrderAffectsPacking() throws {
        let forward = try ActionList.pack([Fixtures.sendAction(0), Fixtures.sendAction(1)])
        let backward = try ActionList.pack([Fixtures.sendAction(1), Fixtures.sendAction(0)])
        XCTAssertNotEqual(try forward.hash(), try backward.hash())
    }

    func testRejectsTooManyActions() {
        XCTAssertThrowsError(try ActionList.pack((0..<256).map(Fixtures.sendAction))) { error in
            guard case ActionList.ActionListError.tooManyActions(256) = error else {
                return XCTFail("expected tooManyActions(256), got \(error)")
            }
        }
    }

    /// IGNORE_ERRORS is forced on regardless of what the caller passes.
    func testIgnoreErrorsIsForced() throws {
        let withoutFlag = WalletV5Action.sendMessage(
            mode: .payGasSeparately,
            message: MessageRelaxed.makeInternal(to: Fixtures.dest, value: 1000, bounce: true)
        )
        let withFlag = Fixtures.sendAction(0)
        XCTAssertEqual(try withoutFlag.serialize().hash(), try withFlag.serialize().hash())
    }
}

/// Verifies `createBodyV5` — the payload that authorizes every V5R1 transaction.
final class BodyV5Tests: XCTestCase {
    struct BodyVector: Decodable {
        let label: String
        let authType: String
        let opcode: UInt64?
        let walletId: UInt32?
        let seqno: UInt32?
        let validUntil: UInt32
        let actionCount: Int?
        let actionsListBoc: String
        let payloadBoc: String?
        let payloadHash: String?
        let fakeSignature: Bool?
        let signedBodyBoc: String
        let signedBodyHash: String
        let signatureDomain: DomainVector?

        struct DomainVector: Decodable {
            let type: String
            let globalId: Int32?
        }
    }

    private func vectors() throws -> [BodyVector] {
        let loaded: [BodyVector] = try Vectors.load("bodyv5.json")
        XCTAssertGreaterThanOrEqual(loaded.count, 21, "bodyv5.json lost cases")
        return loaded
    }

    private func wallet(walletID: UInt32) throws -> WalletV5R1 {
        let publicKey = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).publicKey
        return WalletV5R1(publicKey: publicKey, walletID: walletID)
    }

    /// The unsigned payload, independent of any signing concern.
    func testUnsignedPayloadMatchesReference() throws {
        var checked = 0
        for v in try vectors() {
            guard let payloadBoc = v.payloadBoc,
                  let seqno = v.seqno,
                  let walletId = v.walletId,
                  let actionCount = v.actionCount
            else { continue }

            let actions = try ActionList.pack((0..<actionCount).map(Fixtures.sendAction))
            XCTAssertEqual(
                actions.toBoc().base64EncodedString(),
                v.actionsListBoc,
                "action list for \(v.label)"
            )

            let auth: WalletV5R1.AuthKind = v.authType == "internal" ? .internalMessage : .external
            let payload = try wallet(walletID: walletId).unsignedBody(
                seqno: seqno,
                walletID: walletId,
                actions: actions,
                validUntil: v.validUntil,
                auth: auth
            )
            XCTAssertEqual(
                payload.toBoc().base64EncodedString(),
                payloadBoc,
                "payload for \(v.label)"
            )
            XCTAssertEqual(try payload.hash().hexString, v.payloadHash, "payload hash for \(v.label)")
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 18, "too few payload cases exercised")
    }

    /// The fully signed body, byte for byte — only possible because the default signing
    /// provider is deterministic.
    func testSignedBodyMatchesReference() throws {
        var checked = 0
        for v in try vectors() {
            guard let seqno = v.seqno,
                  let walletId = v.walletId,
                  let actionCount = v.actionCount,
                  let fake = v.fakeSignature
            else { continue }

            let actions = try ActionList.pack((0..<actionCount).map(Fixtures.sendAction))
            let auth: WalletV5R1.AuthKind = v.authType == "internal" ? .internalMessage : .external
            let w = try wallet(walletID: walletId)

            let body: Cell = fake
                ? try w.createFakeSignedBody(
                    seqno: seqno,
                    actions: actions,
                    validUntil: v.validUntil,
                    auth: auth
                )
                : try w.createSignedBody(
                    seqno: seqno,
                    actions: actions,
                    validUntil: v.validUntil,
                    auth: auth,
                    secretKey: try Fixtures.signingKey
                )

            XCTAssertEqual(
                body.toBoc().base64EncodedString(),
                v.signedBodyBoc,
                "signed body for \(v.label)"
            )
            XCTAssertEqual(try body.hash().hexString, v.signedBodyHash, "signed body hash for \(v.label)")
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 18, "too few signed-body cases exercised")
    }

    /// Signature domains prefix the payload hash before signing, so a signature made for
    /// one chain cannot be replayed on another.
    func testSignatureDomainVariantsMatchReference() throws {
        var checked = 0
        for v in try vectors() {
            guard let domainVector = v.signatureDomain else { continue }

            let domain: SignatureDomain
            switch domainVector.type {
            case "empty": domain = .empty
            case "l2": domain = .l2(globalId: try XCTUnwrap(domainVector.globalId))
            default: return XCTFail("unknown domain type \(domainVector.type)")
            }

            let actions = try ActionList.pack([Fixtures.sendAction(0)])
            XCTAssertEqual(actions.toBoc().base64EncodedString(), v.actionsListBoc)

            let body = try wallet(walletID: WalletV5R1.defaultWalletID).createSignedBody(
                seqno: 0,
                actions: actions,
                validUntil: v.validUntil,
                auth: .external,
                secretKey: try Fixtures.signingKey,
                domain: domain
            )
            XCTAssertEqual(
                body.toBoc().base64EncodedString(),
                v.signedBodyBoc,
                "signed body for \(v.label)"
            )
            checked += 1
        }
        XCTAssertEqual(checked, 3, "expected three signature-domain cases")
    }

    /// The empty domain must contribute no prefix, keeping signatures compatible with
    /// implementations predating domain separation.
    func testEmptyDomainSignsIdenticallyToNoDomain() throws {
        let actions = try ActionList.pack([Fixtures.sendAction(0)])
        let w = try wallet(walletID: WalletV5R1.defaultWalletID)

        let none = try w.createSignedBody(
            seqno: 0, actions: actions, validUntil: 1_700_000_000,
            auth: .external, secretKey: try Fixtures.signingKey, domain: nil
        )
        let empty = try w.createSignedBody(
            seqno: 0, actions: actions, validUntil: 1_700_000_000,
            auth: .external, secretKey: try Fixtures.signingKey, domain: .empty
        )
        XCTAssertEqual(try none.hash(), try empty.hash())

        // An L2 domain must differ.
        let l2 = try w.createSignedBody(
            seqno: 0, actions: actions, validUntil: 1_700_000_000,
            auth: .external, secretKey: try Fixtures.signingKey, domain: .l2(globalId: 1)
        )
        XCTAssertNotEqual(try none.hash(), try l2.hash())
    }

    /// The two auth opcodes must produce different bodies: external for a direct send,
    /// internal for a relayer-delivered gasless send.
    func testAuthKindAffectsBody() throws {
        let actions = try ActionList.pack([Fixtures.sendAction(0)])
        let w = try wallet(walletID: WalletV5R1.defaultWalletID)

        let external = try w.unsignedBody(
            seqno: 0, walletID: WalletV5R1.defaultWalletID, actions: actions,
            validUntil: 1_700_000_000, auth: .external
        )
        let internalMsg = try w.unsignedBody(
            seqno: 0, walletID: WalletV5R1.defaultWalletID, actions: actions,
            validUntil: 1_700_000_000, auth: .internalMessage
        )
        XCTAssertNotEqual(try external.hash(), try internalMsg.hash())
    }

    /// Signing is deterministic, so building the same body twice must be identical.
    func testSignedBodyIsReproducible() throws {
        let actions = try ActionList.pack([Fixtures.sendAction(0)])
        let w = try wallet(walletID: WalletV5R1.defaultWalletID)
        let a = try w.createSignedBody(
            seqno: 5, actions: actions, validUntil: 1_700_000_000,
            auth: .external, secretKey: try Fixtures.signingKey
        )
        let b = try w.createSignedBody(
            seqno: 5, actions: actions, validUntil: 1_700_000_000,
            auth: .external, secretKey: try Fixtures.signingKey
        )
        XCTAssertEqual(try a.hash(), try b.hash())
    }
}

/// Verifies V4R2 transfer bodies.
final class V4R2TransferTests: XCTestCase {
    struct TransferVector: Decodable {
        let label: String
        let subwalletId: UInt32
        let seqno: UInt32
        let timeout: UInt32
        let sendMode: UInt8
        let messageCount: Int
        let boc: String
        let hash: String
    }

    func testTransferBodiesMatchReference() throws {
        let vectors: [TransferVector] = try Vectors.load("v4r2-transfer.json")
        XCTAssertGreaterThanOrEqual(vectors.count, 4, "v4r2-transfer.json lost cases")

        let publicKey = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).publicKey

        for v in vectors {
            let wallet = WalletV4R2(publicKey: publicKey, walletID: v.subwalletId)
            let messages = (0..<v.messageCount).map { i in
                MessageRelaxed.makeInternal(
                    to: i % 2 == 0 ? Fixtures.dest : Fixtures.dest2,
                    value: BigUInt(1000 + i),
                    bounce: true
                )
            }

            let body = try wallet.unsignedTransfer(
                seqno: v.seqno,
                validUntil: v.timeout,
                sendMode: SendMode(rawValue: v.sendMode),
                messages: messages
            )
            XCTAssertEqual(body.toBoc().base64EncodedString(), v.boc, "transfer body for \(v.label)")
            XCTAssertEqual(try body.hash().hexString, v.hash, "transfer hash for \(v.label)")
        }
    }

    /// V4R2 stores each message as a ref, so 4 is the hard ceiling — unlike V5R1's 255.
    func testRejectsMoreThanFourMessages() throws {
        let publicKey = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).publicKey
        let wallet = WalletV4R2(publicKey: publicKey)
        let messages = (0..<5).map { _ in
            MessageRelaxed.makeInternal(to: Fixtures.dest, value: 1000, bounce: true)
        }
        XCTAssertThrowsError(
            try wallet.unsignedTransfer(seqno: 0, validUntil: 0, sendMode: .walletDefault, messages: messages)
        )
    }

    /// V4R2 puts the signature first; V5R1 puts it last. Confusing the two produces a
    /// body the contract silently rejects.
    func testSignaturePrecedesPayload() throws {
        let publicKey = try Ed25519.keyPair(fromSeed: Data(repeating: 0, count: 32)).publicKey
        let wallet = WalletV4R2(publicKey: publicKey)
        let payload = try wallet.unsignedTransfer(
            seqno: 0, validUntil: 1_700_000_000, sendMode: .walletDefault,
            messages: [MessageRelaxed.makeInternal(to: Fixtures.dest, value: 1000, bounce: true)]
        )
        let signed = try wallet.createSignedTransfer(
            seqno: 0, validUntil: 1_700_000_000,
            messages: [MessageRelaxed.makeInternal(to: Fixtures.dest, value: 1000, bounce: true)],
            secretKey: try Fixtures.signingKey
        )

        var slice = signed.beginParse()
        let signature = try slice.loadBytes(64)
        XCTAssertTrue(
            try Ed25519.verify(
                signature: signature,
                data: try payload.hash(),
                publicKey: publicKey
            ),
            "the leading 64 bytes must be a signature over the payload hash"
        )
    }
}

/// Verifies TEP-467 normalized hashing, which TON Connect transaction lookup depends on.
final class NormalizedHashTests: XCTestCase {
    struct HashVectors: Decodable {
        let valid: [Valid]
        let invalid: [Invalid]

        struct Valid: Decodable {
            let label: String
            let inputBoc: String
            let normalizedHash: String
            let normalizedBoc: String
            let hasStateInit: Bool?
            let bodyAsRef: Bool?
        }

        struct Invalid: Decodable {
            let label: String
            let message: String
        }
    }

    private func vectors() throws -> HashVectors {
        let loaded: HashVectors = try Vectors.load("normalized-hash.json")
        XCTAssertGreaterThanOrEqual(loaded.valid.count, 13, "normalized-hash.json lost valid cases")
        XCTAssertGreaterThanOrEqual(loaded.invalid.count, 2, "normalized-hash.json lost invalid cases")
        return loaded
    }

    func testNormalizedHashesMatchReference() throws {
        for v in try vectors().valid {
            let normalized = try NormalizedMessage.normalize(base64: v.inputBoc)
            XCTAssertEqual(normalized.hash, v.normalizedHash, "hash for \(v.label)")
            XCTAssertEqual(normalized.boc, v.normalizedBoc, "normalized boc for \(v.label)")
        }
    }

    /// A message with a state init and the same message without one must normalize to the
    /// *same* hash — that is what makes lookup work across deploy and post-deploy sends.
    func testStateInitIsStripped() throws {
        let all = try vectors().valid
        let withInit = all.filter { $0.hasStateInit == true }
        let withoutInit = all.filter { $0.hasStateInit == false }
        XCTAssertFalse(withInit.isEmpty, "no state-init cases")
        XCTAssertFalse(withoutInit.isEmpty, "no stripped cases")

        // Pair them by label: "…-no-init" is the same message minus the state init.
        for v in withInit {
            guard let pair = withoutInit.first(where: { $0.label == "\(v.label)-no-init" }) else { continue }
            XCTAssertEqual(
                try NormalizedMessage.normalize(base64: v.inputBoc).hash,
                try NormalizedMessage.normalize(base64: pair.inputBoc).hash,
                "normalizing \(v.label) must ignore the state init"
            )
        }
    }

    /// A body inlined and the same body behind a ref must normalize identically —
    /// `forceRef` is what guarantees it.
    func testInlineAndRefBodiesNormalizeIdentically() throws {
        let all = try vectors().valid
        let inline = try XCTUnwrap(all.first { $0.label == "external-small-body-inline" })
        let asRef = try XCTUnwrap(all.first { $0.label == "external-small-body-as-ref" })
        XCTAssertEqual(
            try NormalizedMessage.normalize(base64: inline.inputBoc).hash,
            try NormalizedMessage.normalize(base64: asRef.inputBoc).hash,
            "body placement must not affect the normalized hash"
        )
    }

    func testRejectsNonExternalInMessages() throws {
        // An internal message must be refused.
        let internalMessage = MessageRelaxed.makeInternal(to: Fixtures.dest, value: 1000, bounce: true)
        let boc = try internalMessage.toCell().toBoc()
        XCTAssertThrowsError(try NormalizedMessage.normalize(boc: boc))
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try NormalizedMessage.normalize(base64: "not-base64-at-all!!!"))
    }
}

/// Verifies `validUntil` clamping.
final class ValidUntilTests: XCTestCase {
    func testRejectsPastDeadlines() {
        XCTAssertThrowsError(try ValidUntil.resolve(999, now: 1000))
    }

    func testCapsFarFutureDeadlines() throws {
        let now: UInt32 = 1_700_000_000
        XCTAssertEqual(try ValidUntil.resolve(now + 10_000, now: now), now + 600)
    }

    func testPassesThroughNearDeadlines() throws {
        let now: UInt32 = 1_700_000_000
        XCTAssertEqual(try ValidUntil.resolve(now + 60, now: now), now + 60)
        XCTAssertEqual(try ValidUntil.resolve(now + 600, now: now), now + 600)
        XCTAssertEqual(try ValidUntil.resolve(now, now: now), now, "exactly now is allowed")
    }

    func testNilAndZeroMeanNoDeadline() throws {
        XCTAssertNil(try ValidUntil.resolve(nil, now: 1000))
        XCTAssertNil(try ValidUntil.resolve(0, now: 1000))
    }

    func testDefaultDeadlineIsFiveMinutes() {
        XCTAssertEqual(ValidUntil.defaultDeadline(now: 1_700_000_000), 1_700_000_300)
    }
}
