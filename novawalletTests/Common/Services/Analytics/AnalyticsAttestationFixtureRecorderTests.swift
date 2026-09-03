import XCTest
@testable import novawallet

// No `#if F_DEV` guard here: the test target does not define F_DEV, so guarding this file
// would delete the whole suite and `-only-testing:` would silently report success. The app
// module is built with -DF_DEV in Debug, so these symbols exist and @testable can see them.
final class AnalyticsAttestationFixtureRecorderTests: XCTestCase {
    func testFixtureSerializesEveryFieldTheGatewayNeeds() throws {
        let fixture = AnalyticsAttestationFixture(
            challenge: "chal",
            clientId: "cid",
            keyId: "kid",
            attestationBase64: Data("attestation".utf8).base64EncodedString(),
            bodyBase64: Data("body".utf8).base64EncodedString(),
            assertionBase64: Data("assertion".utf8).base64EncodedString()
        )

        let json = String(data: try AnalyticsCoding.encoder.encode(fixture), encoding: .utf8)!

        for field in [
            "challenge",
            "clientId",
            "keyId",
            "attestationBase64",
            "bodyBase64",
            "assertionBase64"
        ] {
            XCTAssertTrue(json.contains(field), "fixture is missing \(field)")
        }
    }

    func testRecordedBodyMatchesTheAssertedBytes() throws {
        let body = Data(#"{"v":1}"#.utf8)
        let clientData = AttestationClientData.assertionClientData(
            challenge: "chal",
            clientId: "cid",
            body: body
        )

        XCTAssertTrue(
            String(data: clientData, encoding: .utf8)!
                .hasSuffix(AttestationClientData.bodyDigestHex(body))
        )
    }

    func testTheRecordedBodyIsTheBodyTheFixtureReports() throws {
        let reported = Data(
            base64Encoded: AnalyticsAttestationFixtureRecorder.sampleBody.base64EncodedString()
        )

        XCTAssertEqual(reported, AnalyticsAttestationFixtureRecorder.sampleBody)
    }
}

