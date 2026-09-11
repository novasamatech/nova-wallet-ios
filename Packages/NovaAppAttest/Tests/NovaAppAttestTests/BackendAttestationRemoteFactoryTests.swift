import XCTest
@testable import NovaAppAttest

final class BackendAttestationRemoteFactoryTests: XCTestCase {
    private func grade(
        _ statusCode: Int,
        _ code: BackendAttestationErrorCode? = nil,
        isClientAuthenticated: Bool = true
    ) -> String {
        switch BackendAttestationRemoteFactory.statusError(
            for: statusCode,
            code: code,
            isClientAuthenticated: isClientAuthenticated
        ) {
        case .unauthorized: "retire"
        case .rejected: "stop"
        case .clientError: "clientError"
        case .serverError: "serverError"
        case .retryLater: "retryLater"
        case .unsupported: "unsupported"
        case .invalidResponse: "invalidResponse"
        case nil: "accepted"
        }
    }

    /// Only a verdict that finishes the binding may cost an App Attest key. Under a 60-second
    /// single-use challenge an expiry is routine, and treating it as a verdict would mint a new key
    /// and a new installation on every late flush.
    func testOnlyAFinishedBindingRetiresTheInstallation() {
        XCTAssertEqual(grade(401, .unknownClient), "retire")
        XCTAssertEqual(grade(401, .attestationFailed), "retire")
        XCTAssertEqual(grade(409, .clientAlreadyRegistered), "retire")

        XCTAssertEqual(grade(401, .invalidChallenge), "clientError")
        XCTAssertEqual(grade(401, .invalidProof), "clientError")
    }

    func testAPolicyDenialStopsRetrying() {
        XCTAssertEqual(grade(403, .appNotAllowed), "stop")
        XCTAssertEqual(grade(403, .bindingNotAllowed), "stop")
    }

    /// A proxy can answer instead of the gateway, and the challenge POST carries no identity at all,
    /// so neither may be read as a verdict on the installation.
    func testNothingWithoutAnIdentityBearingCodeIsAVerdict() {
        XCTAssertEqual(grade(401, nil), "clientError")
        XCTAssertEqual(grade(403, nil), "clientError")
        XCTAssertEqual(grade(401, .unknownClient, isClientAuthenticated: false), "clientError")
        XCTAssertEqual(grade(403, .appNotAllowed, isClientAuthenticated: false), "clientError")
    }

    func testTheRemainingStatusesGradeByRange() {
        XCTAssertEqual(grade(429, .attestationUnavailable), "clientError")
        XCTAssertEqual(grade(503, .attestationUnavailable), "serverError")
        XCTAssertEqual(grade(204), "accepted")
    }
}
