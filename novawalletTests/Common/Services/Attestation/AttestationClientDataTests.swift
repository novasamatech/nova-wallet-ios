import XCTest
@testable import novawallet

final class AttestationClientDataTests: XCTestCase {
    // Verbatim from infrastructure/src/test/java/io/novafoundation/nova/infrastructure/
    // attestation/AttestationSigningTest.kt at PR 2324's head (108899870). These are the
    // cross-platform contract: the gateway recomputes the same digest for both platforms.
    private let challenge = "TEST_CHALLENGE_abc123"
    private let clientId = "6f2c1e4a-0000-4000-8000-000000000001"
    private let body = Data(#"{"v":1,"platform":"android","app_version":"10.9.1"}"#.utf8)

    func testBodyDigestMatchesTheAndroidVector() {
        XCTAssertEqual(
            AttestationClientData.bodyDigestHex(body),
            "2c3d64eac83fc3f8bc8fe383d202bf4cc4b5b3c88328c87cc6695f8ecb49f4e7"
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

    func testSigningPayloadMatchesTheAndroidVector() {
        // Android's `signingPayload` returns sha256(utf8(challenge ‖ clientId ‖ bodyDigestHex)).
        // On iOS the client data is that same *unhashed* string and AppAttestService applies
        // the SHA-256, so the digest below is what DeviceCheck receives as clientDataHash.
        let clientData = AttestationClientData.assertionClientData(
            challenge: challenge,
            clientId: clientId,
            body: body
        )

        XCTAssertEqual(
            clientData.sha256().map { String(format: "%02x", $0) }.joined(),
            "4469fb60ce2ad38af216bc5ac89188071392af288cfaa99eb62532843d9c5c92"
        )
    }

    func testAssertionClientDataIsTheAndroidPayloadBeforeHashing() {
        let clientData = AttestationClientData.assertionClientData(
            challenge: challenge,
            clientId: clientId,
            body: body
        )

        XCTAssertEqual(
            String(data: clientData, encoding: .utf8),
            challenge + clientId + "2c3d64eac83fc3f8bc8fe383d202bf4cc4b5b3c88328c87cc6695f8ecb49f4e7"
        )
    }
}
