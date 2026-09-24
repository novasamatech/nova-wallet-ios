import XCTest
@testable import NovaAnalytics

final class AnalyticsUploadResponseTests: XCTestCase {
    private func deliveryError(
        _ statusCode: Int,
        code: String? = nil,
        retryAfter: String? = nil
    ) throws -> AnalyticsTransportError? {
        let url = try XCTUnwrap(URL(string: "https://gateway.example/v1/analytics/events"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: retryAfter.map { ["Retry-After": $0] }
        ))
        let body = code.map { Data(#"{"error":{"code":"\#($0)","message":"x"}}"#.utf8) }

        return AnalyticsUploadOperationFactory.deliveryError(
            for: response,
            data: body,
            now: Date(timeIntervalSince1970: 0)
        )
    }

    func testSuccessfulResponse() throws {
        XCTAssertNil(try deliveryError(204))
    }

    func testErrorCodeDeterminesRejection() throws {
        XCTAssertEqual(try deliveryError(401, code: "unknown_client"), .rejected(statusCode: 401))
        XCTAssertEqual(try deliveryError(401, code: "invalid_challenge"), .proofRefused(statusCode: 401))
        XCTAssertEqual(try deliveryError(400, code: "invalid_target"), .proofRefused(statusCode: 400))
        XCTAssertEqual(try deliveryError(400), .clientError(statusCode: 400))
    }

    func testRetryAfterDelay() throws {
        XCTAssertEqual(try deliveryError(429, retryAfter: "120"), .retryLater(statusCode: 429, retryAfter: 120))
    }
}
