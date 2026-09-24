import XCTest
@testable import NovaAnalytics

final class AnalyticsEnvelopeTests: XCTestCase {
    func testEncodesWireKeys() throws {
        let envelope = AnalyticsEnvelope(
            schemaVersion: 1,
            platform: "ios",
            appVersion: "10.9.0",
            installId: "install-id",
            sessionId: "session-id",
            sentAt: "2026-09-02T10:00:00.123Z",
            events: [
                AnalyticsEventRemote(
                    id: "event-id",
                    name: "session_started",
                    timestamp: "2026-09-02T09:59:00.000Z",
                    props: [:]
                )
            ]
        )

        let json = String(data: try AnalyticsCoding.encoder.encode(envelope), encoding: .utf8)

        XCTAssertEqual(
            json,
            #"{"app_version":"10.9.0","events":[{"id":"event-id","name":"session_started","props":{},"ts":"2026-09-02T09:59:00.000Z"}],"install_id":"install-id","platform":"ios","sent_at":"2026-09-02T10:00:00.123Z","session_id":"session-id","v":1}"#
        )
    }
}
