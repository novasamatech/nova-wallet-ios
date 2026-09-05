import XCTest
@testable import NovaAppAttest

final class AttestationClientDataTests: XCTestCase {
    private let challenge = "TEST_CHALLENGE_abc123"
    private let clientId = "6f2c1e4a-0000-4000-8000-000000000001"
    private let body = Data(#"{"v":1,"platform":"ios","app_version":"10.9.1"}"#.utf8)

    func testBodyDigestMatchesThePinnedVector() {
        XCTAssertEqual(
            AttestationClientData.bodyDigestHex(body),
            "8c163c54b038b652cd8d3b74e4aba48eea48adee34c980349c69a19ee612ddbd"
        )
    }

    func testEmptyBodyDigestIsTheKnownSha256OfNothing() {
        XCTAssertEqual(
            AttestationClientData.bodyDigestHex(Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testDigestHexIsLowercase() {
        let digest = AttestationClientData.bodyDigestHex(Data("A".utf8))
        XCTAssertEqual(digest, digest.lowercased())
        XCTAssertEqual(digest.count, 64)
    }

    func testAssertionClientDataIsChallengeThenClientIdThenBodyDigest() {
        let clientData = AttestationClientData.assertionClientData(
            challenge: "CHAL",
            clientId: "CID",
            body: Data()
        )

        XCTAssertEqual(
            String(data: clientData, encoding: .utf8),
            "CHALCID" + "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testAttestationClientDataIsChallengeThenClientIdThenKeyId() {
        let clientData = AttestationClientData.attestationClientData(
            challenge: "CHAL",
            clientId: "CID",
            keyId: "KEY"
        )

        XCTAssertEqual(String(data: clientData, encoding: .utf8), "CHALCIDKEY")
    }

    func testSigningPayloadMatchesThePinnedVector() {
        let clientData = AttestationClientData.assertionClientData(
            challenge: challenge,
            clientId: clientId,
            body: body
        )

        XCTAssertEqual(
            clientData.sha256().map { String(format: "%02x", $0) }.joined(),
            "00cf9f14e3bfb57e9d791b0322c00eeb9600a7bc4295dc66c3d3317ec29cc36c"
        )
    }

    func testAssertionClientDataIsThePayloadBeforeHashing() {
        let clientData = AttestationClientData.assertionClientData(
            challenge: challenge,
            clientId: clientId,
            body: body
        )

        XCTAssertEqual(
            String(data: clientData, encoding: .utf8),
            challenge + clientId + "8c163c54b038b652cd8d3b74e4aba48eea48adee34c980349c69a19ee612ddbd"
        )
    }
}
