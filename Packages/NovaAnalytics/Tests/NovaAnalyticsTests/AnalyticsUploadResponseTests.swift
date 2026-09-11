import XCTest
@testable import NovaAnalytics

final class AnalyticsUploadResponseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_772_445_600)

    private let verdicts: [(status: Int, verdict: AnalyticsTransportError?, line: UInt)] = [
        (200, nil, #line),
        (204, nil, #line),
        (301, .serverError(statusCode: 301), #line),
        (400, .clientError(statusCode: 400), #line),
        (401, .proofRefused(statusCode: 401), #line),
        (403, .proofRefused(statusCode: 403), #line),
        (404, .serverError(statusCode: 404), #line),
        (408, .retryLater(statusCode: 408, retryAfter: nil), #line),
        (413, .clientError(statusCode: 413), #line),
        (422, .clientError(statusCode: 422), #line),
        (425, .retryLater(statusCode: 425, retryAfter: nil), #line),
        (429, .retryLater(statusCode: 429, retryAfter: nil), #line),
        (500, .serverError(statusCode: 500), #line),
        (503, .retryLater(statusCode: 503, retryAfter: nil), #line)
    ]

    /// Without an error envelope nothing may be read as a verdict on the installation, so a
    /// bodyless 401 from a proxy costs neither the key nor the identity.
    private func deliveryError(
        _ statusCode: Int,
        code: String? = nil,
        retryAfter: String? = nil
    ) throws -> AnalyticsTransportError? {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/analytics/events")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: retryAfter.map { ["Retry-After": $0] }
        ))

        let body = code.map { Data(#"{"error":{"code":"\#($0)","message":"x"}}"#.utf8) }

        return AnalyticsUploadOperationFactory.deliveryError(for: response, data: body, now: now)
    }

    func testEveryStatusMapsToItsDeliveryVerdict() throws {
        for row in verdicts {
            XCTAssertEqual(try deliveryError(row.status), row.verdict, "status \(row.status)", line: row.line)
        }
    }

    /// The events route crosses the gateway, so a 4xx can be a verdict on the installation, a refused
    /// proof, or a rejected payload. Only a code that finishes the binding may cost an App Attest
    /// key — an expired 60-second challenge is routine and must not.
    func testOnlyAFinishedBindingCostsTheKey() throws {
        XCTAssertEqual(try deliveryError(401, code: "unknown_client"), .rejected(statusCode: 401))
        XCTAssertEqual(try deliveryError(401, code: "attestation_failed"), .rejected(statusCode: 401))
        XCTAssertEqual(
            try deliveryError(409, code: "client_already_registered"),
            .rejected(statusCode: 409)
        )

        XCTAssertEqual(try deliveryError(401, code: "invalid_challenge"), .proofRefused(statusCode: 401))
        XCTAssertEqual(try deliveryError(401, code: "invalid_proof"), .proofRefused(statusCode: 401))
        XCTAssertEqual(try deliveryError(403, code: "binding_not_allowed"), .proofRefused(statusCode: 403))
        XCTAssertEqual(try deliveryError(401, code: "a_code_added_later"), .proofRefused(statusCode: 401))
    }

    /// A 400 the gateway raised describes the proof and is worth proving again; a 400 telemetry
    /// raised about the payload never will be, and dropping it is what keeps the queue from wedging.
    func testOnlyAPayloadRejectionDropsTheBatch() throws {
        XCTAssertEqual(try deliveryError(400, code: "invalid_target"), .proofRefused(statusCode: 400))
        XCTAssertEqual(try deliveryError(400), .clientError(statusCode: 400))
        XCTAssertEqual(try deliveryError(415), .clientError(statusCode: 415))
    }

    func testRetryAfterSecondsAreTakenAsTheDelay() throws {
        XCTAssertEqual(try deliveryError(429, retryAfter: "120"), .retryLater(statusCode: 429, retryAfter: 120))
    }
}
