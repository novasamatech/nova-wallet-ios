import XCTest
@testable import NovaAuth

final class NovaAuthPendingEvidenceTests: LifecycleTestCase {
    func testInconclusiveChallengeFailuresAcrossRestartsNeverExhaustUnknownBudget() throws {
        let failures: [NovaAuthError] = [
            .transport(.notConnectedToInternet),
            .bootstrap(NovaAuthServerError(statusCode: 503, code: "attestation_unavailable", requestID: nil, retryAfter: nil)),
            .bootstrap(NovaAuthServerError(statusCode: 429, code: nil, requestID: nil, retryAfter: 60)),
            .bootstrap(NovaAuthServerError(statusCode: 400, code: "invalid_request", requestID: nil, retryAfter: nil)),
            .bootstrap(NovaAuthServerError(statusCode: 403, code: nil, requestID: nil, retryAfter: nil)),
            .bootstrap(NovaAuthServerError(statusCode: 404, code: "unknown_client", requestID: nil, retryAfter: nil))
        ]
        for failure in failures {
            let harness = try LifecycleHarness()
            let context = try preparePending(harness)
            let original = try XCTUnwrap(harness.identity.state?.identity)
            harness.bootstrap.tokenChallengeResult = .failure(failure)
            for _ in 0 ..< 8 {
                let auth = harness.makeAuth()
                _ = try auth.activate(origin: harness.origin)
                assertError(failure, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
                XCTAssertEqual(try pendingState(harness).unknownResponseCount, 0)
                XCTAssertEqual(harness.identity.state?.identity?.clientID, original.clientID)
                XCTAssertEqual(harness.identity.state?.identity?.keyID, original.keyID)
                harness.clock.advance(61)
            }
            XCTAssertEqual(harness.apple.keys, 0)
            XCTAssertEqual(harness.apple.attestations.count, 0)
            XCTAssertEqual(harness.bootstrap.tokenChallenges, 8)
        }
    }

    func testKnownBindingClearsUnknownCountButStaysPendingAcrossTokenFailures() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let context = try preparePending(harness, unknownCount: 7)
        let original = try XCTUnwrap(harness.identity.state?.identity)
        let failure = NovaAuthError.bootstrap(NovaAuthServerError(
            statusCode: 401, code: "invalid_proof", requestID: nil, retryAfter: nil
        ))
        harness.bootstrap.onToken = { $0(.failure(failure)) }
        for delay in [60.0, 600, 3600, 3600, 3600, 3600, 3600, 3600] {
            let auth = harness.makeAuth()
            _ = try auth.activate(origin: harness.origin)
            assertError(failure, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            XCTAssertEqual(try pendingState(harness).unknownResponseCount, 0)
            XCTAssertEqual(harness.identity.state?.identity?.clientID, original.clientID)
            harness.clock.advance(delay)
        }
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.apple.attestations.count, 0)
        XCTAssertEqual(harness.bootstrap.tokens.count, 8)
    }

    private func preparePending(_ harness: LifecycleHarness, unknownCount: Int = 0) throws -> NovaAuthContext {
        let (_, context) = try harness.registered()
        let original = try XCTUnwrap(harness.identity.state?.identity)
        harness.identity.state = NovaAuthInstallationState(
            version: 1, context: context, requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: original.clientID, keyID: original.keyID,
                registration: .registrationPending(NovaAuthPendingRegistration(
                    startedAt: try harness.clock.now(), unknownResponseCount: unknownCount
                ))
            )
        )
        return context
    }

    private func pendingState(_ harness: LifecycleHarness) throws -> NovaAuthPendingRegistration {
        guard case let .registrationPending(pending) = harness.identity.state?.identity?.registration else {
            throw NovaAuthError.invalidResponse
        }
        return pending
    }
}
