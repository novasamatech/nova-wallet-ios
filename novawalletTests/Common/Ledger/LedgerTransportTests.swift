import XCTest
@testable import novawallet

class LedgerTransportTests: XCTestCase {

    func testSingleChunk() {
        // given

        let transport = LedgerTransport()
        let messageSize = transport.mtu - 5
        let message = Data.random(of: messageSize)!

        do {
            // when

            let chunks = transport.prepareRequest(from: message)

            XCTAssertEqual(chunks.count, 1)

            guard let receivedMessage = try transport.receive(partialResponseData: chunks[0]) else {
                XCTFail("Message expected")
                return
            }

            // then

            XCTAssertEqual(message, receivedMessage)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testSeveralChunks() {
        // given

        let transport = LedgerTransport()
        let packetSize = transport.mtu - 5
        let packetsCount = 5
        let message = Data.random(of: packetsCount * packetSize)!

        do {
            // when

            let chunks = transport.prepareRequest(from: message)

            XCTAssertEqual(chunks.count, packetsCount)

            let optReceivedMessage: Data? = try chunks.reduce(nil) { result, chunk in
                try transport.receive(partialResponseData: chunk)
            }

            guard let receivedMessage = optReceivedMessage else {
                XCTFail("Message expected")
                return
            }

            // then

            XCTAssertEqual(message, receivedMessage)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
