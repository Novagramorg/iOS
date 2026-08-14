import XCTest
@testable import WebProxyTransport

final class WebProxyTransportTests: XCTestCase {
    func testServerControlHandshakeSequence() throws {
        let nonce = String(repeating: "A", count: 43)
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"t":"status","state":"connecting"}"#),
            .status(.connecting)
        )
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"t":"tproxy-android-init","v":1,"nonce":"\#(nonce)"}"#),
            .initialize(nonce: nonce)
        )

        let hello = WebProxyFrame(type: .hello, streamId: 0, payload: Data([1]))
        XCTAssertEqual(try hello.validated(), hello)
        let welcome = WebProxyFrame(type: .welcome, streamId: 0)
        XCTAssertEqual(try WebProxyFrameDecoder().append(WebProxyFrameEncoder.encode(welcome)), [welcome])
    }

    func testAdvisoryControlMessages() throws {
        for status in WebProxyPageStatus.allCases {
            XCTAssertEqual(
                try WebProxyControlMessage.decode(#"{"state":"\#(status.rawValue)","t":"status"}"#),
                .status(status)
            )
        }
        XCTAssertEqual(
            try WebProxyControlMessage.decode(#"{"down":2097152,"t":"traffic","up":0}"#),
            .traffic(up: 0, down: 2 * 1024 * 1024)
        )
        XCTAssertEqual(try WebProxyControlMessage.decode(#"{"t":"close"}"#), .close)
    }

    func testMalformedControlMessagesAreRejected() {
        let nonce = String(repeating: "A", count: 43)
        let invalidMessages = [
            "not-json",
            #"{"t":"unknown"}"#,
            #"{"t":"status","state":"ready"}"#,
            #"{"t":"status","state":"connecting","extra":1}"#,
            #"{"t":"traffic","up":-1,"down":0}"#,
            #"{"t":"traffic","up":1.5,"down":0}"#,
            #"{"t":"traffic","up":true,"down":0}"#,
            #"{"t":"traffic","up":33554433,"down":0}"#,
            #"{"t":"close","reason":"provider-controlled"}"#,
            #"{"t":"tproxy-android-init","v":2,"nonce":"\#(nonce)"}"#,
            #"{"t":"tproxy-android-init","v":true,"nonce":"\#(nonce)"}"#,
            #"{"t":"tproxy-android-init","v":1,"nonce":"short"}"#
        ]
        for value in invalidMessages {
            XCTAssertThrowsError(try WebProxyControlMessage.decode(value), value)
        }
    }

    func testCapabilityVectors() throws {
        let plain = try XCTUnwrap(WebProxyConfiguration(
            host: "PROXY.EXAMPLE.COM",
            secret: try XCTUnwrap(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
        ))
        XCTAssertEqual(plain.host, "proxy.example.com")
        XCTAssertEqual(plain.bridgeCapability(), "MHLEY5PmW1GWqJkSrlmJpvJUiLhBH_QKy6yKg8a0JPk")

        let padded = try XCTUnwrap(WebProxyConfiguration(
            host: "proxy.example.com",
            secret: try XCTUnwrap(WebProxyConfiguration.parseSecret("dd000102030405060708090a0b0c0d0e0f"))
        ))
        XCTAssertEqual(padded.bridgeCapability(), "IpJrt3e7sKtzPyoXy6w-Zj6GGEvsvclN66JzQEfPYLA")
    }

    func testSecretAndHostValidation() {
        XCTAssertNotNil(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))
        XCTAssertNotNil(WebProxyConfiguration.parseSecret("dd000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(WebProxyConfiguration.parseSecret("ee000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(WebProxyConfiguration.parseSecret("00"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("user@example.com"))
        XCTAssertNil(WebProxyConfiguration.canonicalHost("example.com:8443"))
        XCTAssertEqual(WebProxyConfiguration.canonicalHost("Example.COM"), "example.com")
        XCTAssertEqual(WebProxyConfiguration.canonicalHost("BÜCHER.example"), "xn--bcher-kva.example")
        XCTAssertNil(WebProxyConfiguration.canonicalHost("127.0.0.1"))
    }

    func testFrameGoldenVectorAndFragmentation() throws {
        let frame = WebProxyFrame(type: .data, streamId: 0x010203, payload: Data([0xaa, 0xbb]))
        let encoded = try WebProxyFrameEncoder.encode(frame)
        XCTAssertEqual(encoded, Data([0x02, 0x01, 0x02, 0x03, 0, 0, 0, 2, 0xaa, 0xbb]))

        for split in 0 ..< encoded.count {
            let decoder = WebProxyFrameDecoder()
            XCTAssertEqual(try decoder.append(encoded.prefix(split)), [])
            XCTAssertEqual(try decoder.append(encoded.dropFirst(split)), [frame])
        }
    }

    func testEveryFrameType() throws {
        let frames: [WebProxyFrame] = [
            .init(type: .open, streamId: 1),
            .init(type: .data, streamId: 1, payload: Data([1])),
            .init(type: .close, streamId: 1),
            .window(streamId: 1, delta: 42),
            .init(type: .ping, streamId: 0, payload: Data([7])),
            .init(type: .pong, streamId: 0, payload: Data([7])),
            .init(type: .hello, streamId: 0, payload: Data([1])),
            .init(type: .welcome, streamId: 0),
            .init(type: .bye, streamId: 0, payload: Data("bye".utf8))
        ]
        let encoded = try frames.reduce(into: Data()) { result, frame in
            result.append(try WebProxyFrameEncoder.encode(frame))
        }
        XCTAssertEqual(try WebProxyFrameDecoder().append(encoded), frames)
    }

    func testMalformedFramesAreRejected() throws {
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.init(type: .open, streamId: 0)))
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.init(type: .data, streamId: 1)))
        XCTAssertThrowsError(try WebProxyFrameEncoder.encode(.window(streamId: 1, delta: 0)))

        var oversizedHeader = Data([0x02, 0, 0, 1, 0, 0x10, 0, 1])
        oversizedHeader.append(0)
        XCTAssertThrowsError(try WebProxyFrameDecoder().append(oversizedHeader))
    }

    func testLargeConcatenatedBatchIsDecoded() throws {
        let payload = Data(repeating: 0x5a, count: WebProxyProtocol.maximumDataPayload)
        let frames = (1 ... 20).map { WebProxyFrame(type: .data, streamId: UInt32($0), payload: payload) }
        let encoded = try frames.reduce(into: Data()) { result, frame in
            result.append(try WebProxyFrameEncoder.encode(frame))
        }
        XCTAssertGreaterThan(encoded.count, WebProxyProtocol.maximumPayload)
        XCTAssertEqual(try WebProxyFrameDecoder().append(encoded), frames)
    }

    func testBatchFrameLimitIsEnforced() throws {
        var encoded = Data()
        for streamId in 1 ... (WebProxyProtocol.maximumBatchFrames + 1) {
            encoded.append(try WebProxyFrameEncoder.encode(.init(type: .open, streamId: UInt32(streamId))))
        }
        XCTAssertThrowsError(try WebProxyFrameDecoder().append(encoded))
    }

    func testTruncatedAndRandomInputNeverEscapesDeclaredErrors() throws {
        var state: UInt64 = 0x1234_5678_9abc_def0
        func nextByte() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1
            return UInt8(truncatingIfNeeded: state >> 32)
        }

        for length in 0 ... 512 {
            let bytes = Data((0 ..< length).map { _ in nextByte() })
            do {
                _ = try WebProxyFrameDecoder().append(bytes)
            } catch let error as WebProxyFrameError {
                XCTAssertTrue([.invalidFrame, .unknownType, .bufferLimitExceeded].contains(error))
            }
        }
    }
}
