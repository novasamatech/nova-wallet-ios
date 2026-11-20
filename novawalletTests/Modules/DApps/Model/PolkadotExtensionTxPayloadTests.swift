import XCTest
@testable import novawallet
import SubstrateSdk

final class PolkadotExtensionTxPayloadTests: XCTestCase {
    func testDecodesFullPayload() throws {
        // given

        let json = """
        {
            "version": 1,
            "signer": "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
            "callData": "0x0503001234",
            "extensions": [
                { "id": "CheckNonce", "extra": "0x04", "additionalSigned": "0x" },
                { "id": "AsScarcity", "extra": "0x00", "additionalSigned": "0x0102" }
            ],
            "txExtVersion": 0,
            "context": {
                "token": { "symbol": "PAS", "decimals": 10 },
                "bestBlockHeight": 7485234,
                "bestBlockHash": "0x2fad67977d3e2235f745f88f8c4149182f9ee717f871dd5aa66a336049417221",
                "genesisHash": "0x0bd72c1c305172e1275278aaeb3f161e02eccb7a819e63f62d47bd53a28189f8"
            }
        }
        """

        // when

        let payload = try decodePayload(from: json)

        // then

        XCTAssertEqual(payload.version, 1)
        XCTAssertEqual(payload.signer, "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY")
        XCTAssertEqual(payload.callData, "0x0503001234")
        XCTAssertEqual(payload.extensions.map(\.id), ["CheckNonce", "AsScarcity"])
        XCTAssertEqual(payload.extensions.map(\.extra), ["0x04", "0x00"])
        XCTAssertEqual(payload.extensions.map(\.additionalSigned), ["0x", "0x0102"])
        XCTAssertEqual(payload.txExtVersion, 0)
        XCTAssertEqual(payload.context.token?.symbol, "PAS")
        XCTAssertEqual(payload.context.token?.decimals, 10)
        XCTAssertEqual(payload.context.bestBlockHeight, 7_485_234)
        XCTAssertEqual(
            payload.context.bestBlockHash,
            "0x2fad67977d3e2235f745f88f8c4149182f9ee717f871dd5aa66a336049417221"
        )
        XCTAssertEqual(
            payload.context.genesisHash,
            "0x0bd72c1c305172e1275278aaeb3f161e02eccb7a819e63f62d47bd53a28189f8"
        )
    }

    func testDecodesNullOptionalFields() throws {
        // given

        let json = """
        {
            "version": 1,
            "signer": null,
            "callData": "0x00",
            "extensions": [],
            "txExtVersion": null,
            "context": {
                "token": null,
                "bestBlockHeight": 1,
                "bestBlockHash": "0x01",
                "genesisHash": "0x02"
            }
        }
        """

        // when

        let payload = try decodePayload(from: json)

        // then

        XCTAssertNil(payload.signer)
        XCTAssertNil(payload.txExtVersion)
        XCTAssertNil(payload.context.token)
        XCTAssertTrue(payload.extensions.isEmpty)
    }

    func testDecodesAbsentOptionalFields() throws {
        // given

        let json = """
        {
            "version": 1,
            "callData": "0x00",
            "extensions": [],
            "context": {
                "bestBlockHeight": 1,
                "bestBlockHash": "0x01",
                "genesisHash": "0x02"
            }
        }
        """

        // when

        let payload = try decodePayload(from: json)

        // then

        XCTAssertNil(payload.signer)
        XCTAssertNil(payload.txExtVersion)
        XCTAssertNil(payload.context.token)
    }

    func testDecodesContextWithGenesisHashOnly() throws {
        // given

        let json = """
        {
            "version": 1,
            "callData": "0x00",
            "extensions": [],
            "context": { "genesisHash": "0x02" }
        }
        """

        // when

        let payload = try decodePayload(from: json)

        // then

        XCTAssertEqual(payload.context.genesisHash, "0x02")
        XCTAssertNil(payload.context.bestBlockHeight)
        XCTAssertNil(payload.context.bestBlockHash)
    }

    func testIgnoresUnknownKeys() throws {
        // given

        let json = """
        {
            "version": 1,
            "signer": null,
            "callData": "0x00",
            "extensions": [
                { "id": "CheckNonce", "extra": "0x04", "additionalSigned": "0x", "future": true }
            ],
            "txExtVersion": 1,
            "future": { "nested": [1, 2, 3] },
            "context": {
                "metadata": "0x6d657461",
                "token": { "symbol": "DOT", "decimals": 10, "future": "value" },
                "bestBlockHeight": 1,
                "bestBlockHash": "0x01",
                "genesisHash": "0x02"
            }
        }
        """

        // when

        let payload = try decodePayload(from: json)

        // then

        XCTAssertEqual(payload.extensions.map(\.id), ["CheckNonce"])
        XCTAssertEqual(payload.txExtVersion, 1)
        XCTAssertEqual(payload.context.token?.symbol, "DOT")
        XCTAssertEqual(payload.context.genesisHash, "0x02")
    }

    func testFailsOnMalformedPayload() {
        let missingCallData = """
        {
            "version": 1,
            "extensions": [],
            "context": { "bestBlockHeight": 1, "bestBlockHash": "0x01", "genesisHash": "0x02" }
        }
        """

        let missingContext = """
        { "version": 1, "callData": "0x00", "extensions": [] }
        """

        let missingGenesisHash = """
        {
            "version": 1,
            "callData": "0x00",
            "extensions": [],
            "context": { "bestBlockHeight": 1, "bestBlockHash": "0x01" }
        }
        """

        let extensionWithoutExtra = """
        {
            "version": 1,
            "callData": "0x00",
            "extensions": [{ "id": "CheckNonce", "additionalSigned": "0x" }],
            "context": { "bestBlockHeight": 1, "bestBlockHash": "0x01", "genesisHash": "0x02" }
        }
        """

        let wrongVersionType = """
        {
            "version": "one",
            "callData": "0x00",
            "extensions": [],
            "context": { "bestBlockHeight": 1, "bestBlockHash": "0x01", "genesisHash": "0x02" }
        }
        """

        let notAnObject = #""0x00""#

        let malformedPayloads = [
            missingCallData,
            missingContext,
            missingGenesisHash,
            extensionWithoutExtra,
            wrongVersionType,
            notAnObject
        ]

        for json in malformedPayloads {
            XCTAssertThrowsError(try decodePayload(from: json), json)
        }
    }

    // The app receives the payload as the request of a bridge message, so decode it the same way
    private func decodePayload(from string: String) throws -> PolkadotExtensionTxPayload {
        let json = try JSONDecoder().decode(JSON.self, from: Data(string.utf8))

        return try json.map(to: PolkadotExtensionTxPayload.self)
    }
}
