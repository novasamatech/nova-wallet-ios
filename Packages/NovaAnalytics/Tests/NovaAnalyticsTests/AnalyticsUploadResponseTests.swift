import XCTest
@testable import NovaAnalytics

final class AnalyticsUploadResponseTests: XCTestCase {
    private struct Row {
        let statusCode: Int
        let expected: AnalyticsTransportError?
        let line: UInt
    }

    private let now = Date(timeIntervalSince1970: 1_772_445_600)

    private func makeResponse(_ statusCode: Int, retryAfter: String? = nil) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/analytics/events")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: retryAfter.map { ["Retry-After": $0] }
        ))
    }

    private func deliveryError(_ statusCode: Int, retryAfter: String? = nil) throws -> AnalyticsTransportError? {
        AnalyticsUploadOperationFactory.deliveryError(
            for: try makeResponse(statusCode, retryAfter: retryAfter),
            now: now
        )
    }

    private var catalog: [Row] {
        [
            Row(statusCode: 200, expected: nil, line: #line),
            Row(statusCode: 204, expected: nil, line: #line),
            Row(statusCode: 301, expected: .serverError(statusCode: 301), line: #line),
            Row(statusCode: 400, expected: .clientError(statusCode: 400), line: #line),
            Row(statusCode: 401, expected: .rejected(statusCode: 401), line: #line),
            Row(statusCode: 403, expected: .rejected(statusCode: 403), line: #line),
            Row(statusCode: 404, expected: .serverError(statusCode: 404), line: #line),
            Row(
                statusCode: 408,
                expected: .retryLater(statusCode: 408, retryAfter: nil),
                line: #line
            ),
            Row(statusCode: 413, expected: .clientError(statusCode: 413), line: #line),
            Row(statusCode: 422, expected: .clientError(statusCode: 422), line: #line),
            Row(
                statusCode: 425,
                expected: .retryLater(statusCode: 425, retryAfter: nil),
                line: #line
            ),
            Row(
                statusCode: 429,
                expected: .retryLater(statusCode: 429, retryAfter: nil),
                line: #line
            ),
            Row(statusCode: 500, expected: .serverError(statusCode: 500), line: #line),
            Row(
                statusCode: 503,
                expected: .retryLater(statusCode: 503, retryAfter: nil),
                line: #line
            )
        ]
    }

    func testEveryStatusMapsToItsDeliveryVerdict() throws {
        for row in catalog {
            XCTAssertEqual(
                try deliveryError(row.statusCode),
                row.expected,
                "status \(row.statusCode)",
                line: row.line
            )
        }
    }

    func testAResponseWithoutAnHTTPStatusIsRetained() {
        XCTAssertEqual(
            AnalyticsUploadOperationFactory.deliveryError(
                for: URLResponse(
                    url: URL(string: "https://gateway.example/v1/analytics/events")!,
                    mimeType: nil,
                    expectedContentLength: 0,
                    textEncodingName: nil
                ),
                now: now
            ),
            .serverError(statusCode: 0)
        )
    }

    func testRetryAfterSecondsAreTakenAsTheDelay() throws {
        XCTAssertEqual(
            try deliveryError(429, retryAfter: "120"),
            .retryLater(statusCode: 429, retryAfter: 120)
        )
    }

    func testRetryAfterHTTPDateBecomesTheDelayFromNow() throws {
        XCTAssertEqual(
            try deliveryError(503, retryAfter: "Mon, 02 Mar 2026 10:03:00 GMT"),
            .retryLater(statusCode: 503, retryAfter: 180)
        )
    }

    func testUnparseableRetryAfterLeavesNoDelay() throws {
        XCTAssertEqual(
            try deliveryError(429, retryAfter: "soon"),
            .retryLater(statusCode: 429, retryAfter: nil)
        )
    }

    func testRetryAfterIsClampedToADay() throws {
        XCTAssertEqual(
            try deliveryError(429, retryAfter: "999999"),
            .retryLater(statusCode: 429, retryAfter: 86400)
        )
    }

    func testARetryAfterInThePastBecomesNoDelay() throws {
        XCTAssertEqual(
            try deliveryError(503, retryAfter: "Mon, 02 Mar 2026 09:00:00 GMT"),
            .retryLater(statusCode: 503, retryAfter: 0)
        )
    }
}
