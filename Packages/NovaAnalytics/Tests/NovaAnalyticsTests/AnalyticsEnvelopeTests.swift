import XCTest
@testable import NovaAnalytics

final class AnalyticsEnvelopeTests: XCTestCase {
    func testEnvelopeEncodesToTheAgreedWireKeys() throws {
        let envelope = AnalyticsEnvelope(
            schemaVersion: 1,
            platform: "ios",
            appVersion: "10.9.0",
            installId: "11111111-2222-3333-4444-555555555555",
            sessionId: "66666666-7777-8888-9999-000000000000",
            sentAt: "2026-09-02T10:00:00.123Z",
            events: [
                AnalyticsEventRemote(
                    id: "0000000000000000042-99999999-8888-7777-6666-555555555555",
                    name: "session_started",
                    timestamp: "2026-09-02T09:59:00.000Z",
                    props: [:]
                )
            ]
        )

        let json = String(data: try AnalyticsCoding.encoder.encode(envelope), encoding: .utf8)!

        XCTAssertEqual(
            json,
            #"{"app_version":"10.9.0","events":[{"id":"0000000000000000042-99999999-8888-7777-6666-555555555555","name":"session_started","props":{},"ts":"2026-09-02T09:59:00.000Z"}],"install_id":"11111111-2222-3333-4444-555555555555","platform":"ios","sent_at":"2026-09-02T10:00:00.123Z","session_id":"66666666-7777-8888-9999-000000000000","v":1}"#
        )
    }
}
