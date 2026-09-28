@testable import novawallet
import XCTest

final class BittensorApiErrorRecoveryTests: XCTestCase {
    func testUnsupportedRejectedBackedOffAndRefusedCallsAreDeviceBound() {
        let errors: [BittensorApiError] = [
            .unsupportedDevice,
            .configuration,
            .attestationRejected(requestId: "request-1"),
            .attestationBackoff(until: Date(timeIntervalSince1970: 1_790_086_400)),
            .attestationFailure(requestId: "request-2"),
            .invalidRequest(code: "invalid_request", requestId: "request-3")
        ]

        XCTAssertEqual(errors.map(\.isDeviceBound), Array(repeating: true, count: errors.count))
    }

    func testUnpublishedUnavailableAndTemporaryCallsAreNotDeviceBound() {
        let errors: [BittensorApiError] = [
            .routeNotPublished,
            .datasetUnavailable(requestId: "request-1"),
            .rateLimited(requestId: nil),
            .upstreamUnavailable(requestId: nil),
            .upstreamInvalidResponse(requestId: nil),
            .attestationUnavailable(requestId: nil),
            .server(statusCode: 500, code: "internal_error", requestId: nil),
            .contractViolation(detail: "GET /subnets/64/yields/alpha: invalid items", requestId: nil),
            .transport(URLError(.notConnectedToInternet))
        ]

        XCTAssertEqual(errors.map(\.isDeviceBound), Array(repeating: false, count: errors.count))
    }
}
