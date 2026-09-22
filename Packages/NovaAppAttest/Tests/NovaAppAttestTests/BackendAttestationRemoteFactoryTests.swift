import XCTest
@testable import NovaAppAttest

final class BackendAttestationRemoteFactoryTests: XCTestCase {
    private func statusError(
        _ statusCode: Int,
        code: BackendAttestationErrorCode? = nil,
        isClientAuthenticated: Bool = true
    ) -> BackendAttestationError? {
        BackendAttestationRemoteFactory.statusError(
            for: statusCode,
            expecting: 204,
            code: code,
            isClientAuthenticated: isClientAuthenticated
        )
    }

    func testClassifiesAuthenticatedErrors() {
        guard case .unauthorized(statusCode: 401)? = statusError(401, code: .unknownClient) else {
            return XCTFail("Expected unauthorized")
        }
        guard case .rejected(statusCode: 403)? = statusError(403, code: .appNotAllowed) else {
            return XCTFail("Expected rejected")
        }
        guard case .clientError(statusCode: 401)? = statusError(401, code: .invalidChallenge) else {
            return XCTFail("Expected clientError")
        }
    }

    func testClassifiesUnauthenticatedErrors() {
        guard case .clientError(statusCode: 401)? = statusError(401, code: .unknownClient, isClientAuthenticated: false) else {
            return XCTFail("Expected clientError")
        }
        guard case .serverError(statusCode: 503)? = statusError(503, isClientAuthenticated: false) else {
            return XCTFail("Expected serverError")
        }
    }

    func testRequiresExpectedSuccessStatus() {
        XCTAssertNil(statusError(204))
        guard case .invalidResponse? = statusError(200) else {
            return XCTFail("Expected invalidResponse")
        }
    }
}
