import XCTest
@testable import NovaAppAttest

final class BackendAttestationRemoteFactoryTests: XCTestCase {
    private func grade(_ statusCode: Int, isClientAuthenticated: Bool) -> String {
        switch BackendAttestationRemoteFactory.statusError(
            for: statusCode,
            isClientAuthenticated: isClientAuthenticated
        ) {
        case .unauthorized: "unauthorized"
        case .rejected: "rejected"
        case .clientError: "clientError"
        case .serverError: "serverError"
        case .retryLater: "retryLater"
        case .unsupported: "unsupported"
        case .invalidResponse: "invalidResponse"
        case nil: "accepted"
        }
    }

    func testOnlyAnIdentityBearingRequestCanBeGradedAsAVerdictOnTheIdentity() {
        // The challenge POST carries no client id and no key, so a 401 there is an edge artefact:
        // grading it as a verdict would retire a working identity and burn an attestKey call.
        XCTAssertEqual(grade(401, isClientAuthenticated: false), "clientError")
        XCTAssertEqual(grade(403, isClientAuthenticated: false), "clientError")

        XCTAssertEqual(grade(401, isClientAuthenticated: true), "unauthorized")
        XCTAssertEqual(grade(403, isClientAuthenticated: true), "rejected")

        XCTAssertEqual(grade(429, isClientAuthenticated: true), "clientError")
        XCTAssertEqual(grade(503, isClientAuthenticated: true), "serverError")
        XCTAssertEqual(grade(204, isClientAuthenticated: true), "accepted")
    }
}
