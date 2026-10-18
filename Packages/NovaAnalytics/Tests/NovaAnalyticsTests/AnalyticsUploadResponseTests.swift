import NovaAuth
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
        let body = code.map { Data(#"{"error":{"code":"\#($0)","message":"x"}}"#.utf8) } ?? Data()

        return AnalyticsUploadOperationFactory.deliveryError(for: NovaAuthResponse(response: response, body: body))
    }

    func testSuccessfulResponse() throws {
        XCTAssertNil(try deliveryError(204))
    }

    func testStatusDeterminesRejection() throws {
        XCTAssertEqual(try deliveryError(401, code: "unknown_client"), .proofRefused(statusCode: 401))
        XCTAssertEqual(try deliveryError(403), .proofRefused(statusCode: 403))
        XCTAssertEqual(try deliveryError(400, code: "invalid_target"), .clientError(statusCode: 400))
        XCTAssertEqual(try deliveryError(500), .serverError(statusCode: 500))
    }

    func testRetryAfterDelay() throws {
        XCTAssertEqual(try deliveryError(429, retryAfter: "120"), .retryLater(statusCode: 429, retryAfter: 120))
    }
}
