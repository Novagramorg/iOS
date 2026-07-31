import XCTest
import Postbox
import FlatBuffers
import FlatSerialization
import TelegramCore

/// `InstantPageBlock.buttonRow` (Postbox tag 31) and `.document` (tag 32).
final class InstantPageBlockNewCasesTests: XCTestCase {
    private func postboxRoundTrip(_ block: InstantPageBlock) -> InstantPageBlock {
        let encoder = PostboxEncoder()
        encoder.encodeObject(block, forKey: "b")
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData()))
        return decoder.decodeObjectForKey("b", decoder: { InstantPageBlock(decoder: $0) }) as! InstantPageBlock
    }

    private func flatBuffersRoundTrip(_ block: InstantPageBlock) throws -> InstantPageBlock {
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = block.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        var byteBuffer = ByteBuffer(data: builder.data)
        let object: TelegramCore_InstantPageBlock = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        return try InstantPageBlock(flatBuffersObject: object)
    }

    private func button(_ label: String, _ color: ReplyMarkupButton.Style.Color? = nil) -> InstantPageButton {
        return InstantPageButton(text: .plain(label), action: .url("https://t.me/\(label)"), color: color)
    }

    private func caption(_ text: String) -> InstantPageCaption {
        return InstantPageCaption(text: .plain(text), credit: .empty)
    }

    // MARK: - buttonRow

    func test_buttonRow_roundTripsBothCodecs() throws {
        let block = InstantPageBlock.buttonRow(buttons: [
            self.button("one"),
            self.button("two", .danger),
            self.button("three", .success)
        ])
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    /// The schema permits up to 8 per row; the model must not clamp or reorder.
    func test_buttonRow_eightButtonsKeepOrder() throws {
        let block = InstantPageBlock.buttonRow(buttons: (1 ... 8).map { self.button("b\($0)") })
        XCTAssertEqual(self.postboxRoundTrip(block), block)

        let decoded = try self.flatBuffersRoundTrip(block)
        XCTAssertEqual(decoded, block)
        guard case let .buttonRow(buttons) = decoded else {
            return XCTFail("expected buttonRow")
        }
        XCTAssertEqual(buttons.map { $0.text.plainText }, (1 ... 8).map { "b\($0)" })
    }

    func test_buttonRow_emptyRoundTrips() throws {
        let block = InstantPageBlock.buttonRow(buttons: [])
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    /// A row whose buttons carry varied actions — the vector must not collapse them to one type.
    func test_buttonRow_heterogeneousActions() throws {
        let block = InstantPageBlock.buttonRow(buttons: [
            InstantPageButton(text: .plain("url"), action: .url("https://a"), color: nil),
            InstantPageButton(text: .plain("copy"), action: .copyText(payload: "p"), color: nil),
            InstantPageButton(text: .plain("off"), action: .disabled, color: nil)
        ])
        let decoded = try self.flatBuffersRoundTrip(block)
        XCTAssertEqual(decoded, block)
        guard case let .buttonRow(buttons) = decoded else {
            return XCTFail("expected buttonRow")
        }
        XCTAssertEqual(buttons[0].action, .url("https://a"))
        XCTAssertEqual(buttons[1].action, .copyText(payload: "p"))
        XCTAssertEqual(buttons[2].action, .disabled)
    }

    // MARK: - document

    func test_document_roundTripsBothCodecs() throws {
        let block = InstantPageBlock.document(
            id: MediaId(namespace: Namespaces.Media.CloudFile, id: 99),
            caption: self.caption("A file")
        )
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    /// The media id must survive exactly — the renderer resolves the file through it, and a negative
    /// id is a real wire case.
    func test_document_preservesMediaIdIncludingNegative() throws {
        for rawId in [Int64(0), 1, -7, Int64.max] {
            let id = MediaId(namespace: Namespaces.Media.CloudFile, id: rawId)
            let block = InstantPageBlock.document(id: id, caption: self.caption(""))
            guard case let .document(postboxId, _) = self.postboxRoundTrip(block),
                  case let .document(fbsId, _) = try self.flatBuffersRoundTrip(block) else {
                return XCTFail("expected document for id \(rawId)")
            }
            XCTAssertEqual(postboxId, id)
            XCTAssertEqual(fbsId, id)
        }
    }

    /// .document must stay distinct from .audio — it is a separate case precisely because .audio
    /// renders a music player.
    func test_document_isDistinctFromAudio() {
        let id = MediaId(namespace: Namespaces.Media.CloudFile, id: 5)
        let document = InstantPageBlock.document(id: id, caption: self.caption("c"))
        let audio = InstantPageBlock.audio(id: id, caption: self.caption("c"))
        XCTAssertNotEqual(document, audio)
        XCTAssertEqual(self.postboxRoundTrip(document), document)
        XCTAssertNotEqual(self.postboxRoundTrip(document), audio)
    }

    func test_document_captionWithCreditRoundTrips() throws {
        let block = InstantPageBlock.document(
            id: MediaId(namespace: Namespaces.Media.CloudFile, id: 1),
            caption: InstantPageCaption(text: .bold(.plain("Title")), credit: .italic(.plain("Credit")))
        )
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    // MARK: - discriminator neighbours

    /// Tags 31/32 must not disturb tag 30 (.thinking) or the .audio arm they were modelled on.
    func test_neighbouringDiscriminatorsUnaffected() {
        let thinking = InstantPageBlock.thinking(.plain("hmm"))
        XCTAssertEqual(self.postboxRoundTrip(thinking), thinking)

        let audio = InstantPageBlock.audio(
            id: MediaId(namespace: Namespaces.Media.CloudFile, id: 3),
            caption: self.caption("song")
        )
        XCTAssertEqual(self.postboxRoundTrip(audio), audio)
    }

    /// Both new cases must survive nesting inside a container block, since a button row or document
    /// can appear inside a details/blockquote body.
    func test_newCasesNestInsideContainerBlocks() throws {
        let nested = InstantPageBlock.blockQuote(
            blocks: [
                .buttonRow(buttons: [self.button("go")]),
                .document(id: MediaId(namespace: Namespaces.Media.CloudFile, id: 2), caption: self.caption("f"))
            ],
            caption: .empty,
            collapsed: nil
        )
        XCTAssertEqual(self.postboxRoundTrip(nested), nested)
        XCTAssertEqual(try self.flatBuffersRoundTrip(nested), nested)
    }

    // MARK: - blockQuote collapsed

    private func quote(_ collapsed: Bool?) -> InstantPageBlock {
        return .blockQuote(
            blocks: [.paragraph(.plain("body"))],
            caption: .plain("author"),
            collapsed: collapsed
        )
    }

    /// Guards every other `collapsed` assertion in this file. The round-trip tests below are
    /// `XCTAssertEqual(roundTrip(block), block)`, so if `==` ignored `collapsed` they would pass
    /// whether or not the codecs carried the field.
    func test_collapsed_discriminatesEquality() {
        XCTAssertNotEqual(self.quote(true), self.quote(false))
        XCTAssertNotEqual(self.quote(true), self.quote(nil))
        XCTAssertNotEqual(self.quote(false), self.quote(nil))
        XCTAssertEqual(self.quote(true), self.quote(true))
        XCTAssertEqual(self.quote(false), self.quote(false))
        XCTAssertEqual(self.quote(nil), self.quote(nil))
    }

    func test_collapsedTrue_roundTripsBothCodecs() throws {
        let block = self.quote(true)
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    func test_collapsedFalse_roundTripsBothCodecs() throws {
        let block = self.quote(false)
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }

    /// Blocks written before the field existed decode as `nil`. Neither codec may normalize that to
    /// `false` — the model keeps the tri-state, and only the API layer collapses it.
    func test_collapsedNil_roundTripsBothCodecs() throws {
        let block = self.quote(nil)
        XCTAssertEqual(self.postboxRoundTrip(block), block)
        XCTAssertEqual(try self.flatBuffersRoundTrip(block), block)
    }
}
