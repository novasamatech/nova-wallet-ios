import XCTest
@testable import NovaAnalytics

final class AnalyticsUploadResponseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_772_445_600)

    private let verdicts: [(status: Int, verdict: AnalyticsTransportError?, line: UInt)] = [
        (200, nil, #line),
        (204, nil, #line),
        (301, .serverError(statusCode: 301), #line),
        (400, .clientError(statusCode: 400), #line),
        (401, .rejected(statusCode: 401), #line),
        (403, .rejected(statusCode: 403), #line),
        (404, .serverError(statusCode: 404), #line),
        (408, .retryLater(statusCode: 408, retryAfter: nil), #line),
        (413, .clientError(statusCode: 413), #line),
        (422, .clientError(statusCode: 422), #line),
        (425, .retryLater(statusCode: 425, retryAfter: nil), #line),
        (429, .retryLater(statusCode: 429, retryAfter: nil), #line),
        (500, .serverError(statusCode: 500), #line),
        (503, .retryLater(statusCode: 503, retryAfter: nil), #line)
    ]

    private func deliveryError(_ statusCode: Int, retryAfter: String? = nil) throws -> AnalyticsTransportError? {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/analytics/events")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: retryAfter.map { ["Retry-After": $0] }
        ))

        return AnalyticsUploadOperationFactory.deliveryError(for: response, now: now)
    }

    func testEveryStatusMapsToItsDeliveryVerdict() throws {
        for row in verdicts {
            XCTAssertEqual(try deliveryError(row.status), row.verdict, "status \(row.status)", line: row.line)
        }
    }

    func testRetryAfterSecondsAreTakenAsTheDelay() throws {
        XCTAssertEqual(try deliveryError(429, retryAfter: "120"), .retryLater(statusCode: 429, retryAfter: 120))
    }
}
