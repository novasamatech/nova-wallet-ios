import XCTest
import Operation_iOS
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthCancellationTests: LifecycleTestCase {
    func testCancellingQueuedDemandCreatesNoIdentity() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.isSuspended = true
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wrapper.cancel()
        harness.callers.isSuspended = false
        drain(harness.ownerQueue)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testCancellingOneWaiterLeavesOtherWaiterAndIssuerAlive() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthChallenge>()
        let began = expectation(description: "challenge pending")
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onTokenChallenge = pending.start
        let first = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        let second = auth.createAdmissionWrapper(in: context, intent: .background)
        let done = expectation(description: "remaining waiter completed")
        second.targetOperation.completionBlock = { done.fulfill() }
        harness.callers.addOperations(first.allOperations + second.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        drain(harness.ownerQueue)
        first.cancel()
        pending.resolve(.success(LifecycleBootstrap.challenge))
        wait(for: [done], timeout: 5)
        XCTAssertNoThrow(try second.targetOperation.extractNoCancellableResultData())
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testLastWaiterBeforeAssertionCancelsUnusedFlightAndLateChallengeCannotReviveIt() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthChallenge>()
        let began = expectation(description: "challenge pending")
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onTokenChallenge = pending.start
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        wrapper.cancel()
        pending.resolve(.success(LifecycleBootstrap.challenge))
        drain(harness.ownerQueue)
        XCTAssertNil(auth.gate.novaAuthLocked { auth.flight })
        XCTAssertEqual(harness.apple.assertions.count, 0)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testLastWaiterDuringAppleAssertionKeepsAttemptOwnedThroughTokenPost() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let assertion = LifecyclePending<Data>()
        let began = expectation(description: "Apple assertion running")
        assertion.onStart = { began.fulfill() }
        harness.apple.assert = assertion.wrapper
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        wrapper.cancel()
        XCTAssertNotNil(auth.gate.novaAuthLocked { auth.flight })
        let installed = expectation(description: "bounded abandoned attempt finishes securely")
        harness.tokens.onReplace = { installed.fulfill() }
        assertion.resolve(.success(Data([1])))
        wait(for: [installed], timeout: 5)
        drain(harness.ownerQueue)
        XCTAssertNil(auth.gate.novaAuthLocked { auth.flight })
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testLastWaiterAfterTokenSendDoesNotReleaseGateUntilResponse() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let began = expectation(description: "token sent")
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onToken = pending.start
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        wrapper.cancel()
        XCTAssertNotNil(auth.gate.novaAuthLocked { auth.flight })
        let done = expectation(description: "new waiter joins owned post")
        let next = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        next.targetOperation.completionBlock = { done.fulfill() }
        harness.callers.addOperations(next.allOperations, waitUntilFinished: false)
        drain(harness.ownerQueue)
        XCTAssertEqual(harness.apple.assertions.count, 1)
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [done], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokens.count, 1)
    }

    func testResetDuringUncancellableAppleResultCannotRegisterOrIssue() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        let pending = LifecyclePending<Data>()
        let began = expectation(description: "Apple attestation in flight")
        pending.onStart = { began.fulfill() }
        harness.apple.attest = pending.wrapper
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        let done = expectation(description: "old waiter failed by reset")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        try auth.reset()
        wait(for: [done], timeout: 5)
        let finished = observeFlight(auth)
        pending.resolve(.success(Data([1])))
        wait(for: [finished], timeout: 5)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertNil(try harness.tokens.load())
        XCTAssertEqual(harness.bootstrap.registrations.count, 0)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testResetDuringTokenPostDiscardsLateTokenWithoutResurrectingIdentity() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<NovaAuthTokenResponse>()
        let began = expectation(description: "token pending")
        pending.onStart = { began.fulfill() }
        harness.bootstrap.onToken = pending.start
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [began], timeout: 5)
        try auth.reset()
        let finished = observeFlight(auth)
        pending.resolve(.success(harness.bootstrap.tokenResult))
        wait(for: [finished], timeout: 5)
        XCTAssertNil(try harness.tokens.load())
        XCTAssertNil(harness.identity.state?.identity)
    }

    func testAmbiguousAppleTimeoutRetiresKeyAndNeverSendsToken() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.timedOut) }
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.lostKey))
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
    }

    func testResetAfterProofButBeforeQueuedTokenResumePreventsSend() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered()
        let pending = LifecyclePending<Data>()
        let asserting = expectation(description: "assertion pending")
        pending.onStart = { asserting.fulfill() }
        harness.apple.assert = pending.wrapper
        let queued = expectation(description: "token wrapper constructed")
        harness.bootstrap.onTokenCreated = { queued.fulfill() }
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [asserting], timeout: 5)
        harness.bootstrapQueue.isSuspended = true
        pending.resolve(.success(Data([1])))
        wait(for: [queued], timeout: 5)
        try auth.reset()
        let finished = observeFlight(auth)
        harness.bootstrapQueue.isSuspended = false
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokens.count, 0)
        XCTAssertNil(try harness.tokens.load())
    }

    func testResetDuringPendingRegistrationCannotIssueAfterLate204() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        let pending = LifecyclePending<Void>()
        let registering = expectation(description: "registration pending")
        pending.onStart = { registering.fulfill() }
        harness.bootstrap.onRegister = pending.start
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .userInitiated)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [registering], timeout: 5)
        try auth.reset()
        let finished = observeFlight(auth)
        pending.resolve(.success(()))
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertNil(harness.identity.state?.identity)
    }

    func testResetInsideFinalConsentGateIsRecheckedBeforeBusinessResume() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try harness.registered(withToken: true)
        assertError(
            .generationChanged,
            auth.createResponseWrapper(for: try harness.request(context: context), beforeSend: { try auth.reset() }),
            on: harness.callers
        )
        XCTAssertEqual(harness.http.requests.count, 0)
    }
}
