import XCTest
@testable import NovaAppAttest

final class AttestationClientDataTests: XCTestCase {
    func testSigningPayloadMatchesThePinnedVector() {
        let clientData = AttestationClientData.assertionClientData(
            challenge: "TEST_CHALLENGE_abc123",
            clientId: "6f2c1e4a-0000-4000-8000-000000000001",
            body: Data(#"{"v":1,"platform":"ios","app_version":"10.9.1"}"#.utf8)
        )

        XCTAssertEqual(
            clientData.sha256().map { String(format: "%02x", $0) }.joined(),
            "00cf9f14e3bfb57e9d791b0322c00eeb9600a7bc4295dc66c3d3317ec29cc36c"
        )
    }

    func testAttestationClientDataIsChallengeThenClientIdThenKeyId() {
        let clientData = AttestationClientData.attestationClientData(challenge: "CHAL", clientId: "CID", keyId: "KEY")

        XCTAssertEqual(String(data: clientData, encoding: .utf8), "CHALCIDKEY")
    }
}
