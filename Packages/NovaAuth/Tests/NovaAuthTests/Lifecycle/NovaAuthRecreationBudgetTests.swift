import XCTest
import NovaOperationSupport
@testable import NovaAuth

final class NovaAuthRecreationBudgetTests: LifecycleTestCase {
    func testInterruptedAppleWorkAllowsBackgroundReplacementAfterRetirementDelay() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        let attempt = NovaAuthRegistrationAttempt(
            challenge: LifecycleBootstrap.challenge.challenge,
            contentType: "application/json",
            clientDataHash: Data(repeating: 2, count: 32),
            startedAt: try harness.clock.now()
        )
        try auth.gate.novaAuthLocked {
            try auth.setRegistration(.appleInFlight(attempt), flight: NovaAuthIssuanceFlight(context: context, sponsored: false, intent: .background))
        }
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.interrupted))
        harness.clock.advance(60)
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
    }

    func testLostKeyAllowsExactlyTwoBackgroundReplacementsWithEscalatingRetirements() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        var (auth, context) = try harness.registered()
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        for (attempt, delay) in [60.0, 600, 3600].enumerated() {
            assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            XCTAssertEqual(harness.apple.keys, attempt)
            XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, attempt)
            let deadline = try XCTUnwrap(harness.identity.state?.recovery?.recreationDelay?.deadline)
            XCTAssertEqual(deadline.continuousSeconds - (try harness.clock.now()).continuousSeconds, delay)
            harness.clock.advance(delay)
            auth = harness.makeAuth()
            _ = try auth.activate(origin: harness.origin)
        }
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 2)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 2)
    }

    func testUserReplacementDoesNotConsumeExhaustedBackgroundBudget() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try retired(harness, count: 2)
        harness.apple.assert = { .createWithError(NovaAuthAppAttestError.invalidKey) }
        assertError(.keyUnavailable, auth.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 2)
    }

    func testFailedKeyGenerationReservesEachBackgroundAttemptAcrossRelaunch() throws {
        let harness = try LifecycleHarness()
        var (auth, context) = try retired(harness)
        let original = harness.identity.state?.identity
        harness.apple.keyResult = .failure(NovaAuthAppAttestError.failure)
        for count in 1 ... 2 {
            assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
            XCTAssertEqual(harness.identity.state?.identity, original)
            XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, count)
            harness.clock.advance(10)
            auth = harness.makeAuth()
            _ = try auth.activate(origin: harness.origin)
        }
        assertError(.userActionRequired, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 2)
    }

    func testFailedReservationSavePreventsAppleAndRepairPreservesCharge() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try retired(harness)
        let original = harness.identity.state?.identity
        harness.identity.failSave = true
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
        harness.identity.failSave = false
        _ = try auth.activate(origin: harness.origin)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
    }

    func testFailedReplacementIdentitySaveRequiresAnotherReservationAfterRelaunch() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try retired(harness)
        let original = harness.identity.state?.identity
        harness.apple.key = {
            harness.identity.failSave = true
            return .createWithResult(Data(repeating: 2, count: 32).base64EncodedString())
        }
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
        harness.identity.failSave = false
        harness.apple.key = nil
        harness.apple.keyResult = .failure(NovaAuthAppAttestError.failure)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.platformUnavailable, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 2)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 2)
    }

    func testCancelledReservedReplacementKeepsChargeAndReasonForRelaunch() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try retired(harness)
        let original = harness.identity.state?.identity
        let queued = expectation(description: "key wrapper created after reservation")
        harness.apple.key = {
            queued.fulfill()
            return .createWithResult(Data(repeating: 2, count: 32).base64EncodedString())
        }
        harness.bootstrapQueue.isSuspended = true
        let wrapper = auth.createAdmissionWrapper(in: context, intent: .background)
        harness.callers.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [queued], timeout: 5)
        XCTAssertEqual(harness.identity.state?.identity, original)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
        wrapper.cancel()
        drain(harness.ownerQueue)
        harness.bootstrapQueue.isSuspended = false
        harness.bootstrapQueue.waitUntilAllOperationsAreFinished()
        drain(harness.ownerQueue)
        harness.apple.key = nil
        harness.apple.keyResult = .failure(NovaAuthAppAttestError.failure)
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.platformUnavailable, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 2)
        XCTAssertEqual(harness.identity.state?.identity, original)
    }

    func testRebootEndsRetirementDelayButKeepsExhaustedBudget() throws {
        let harness = try LifecycleHarness()
        let (auth, context) = try retired(harness, count: 2)
        try auth.gate.novaAuthLocked {
            try auth.retire(.lostKey, flight: NovaAuthIssuanceFlight(context: context, sponsored: false, intent: .background))
        }
        let recovery = harness.identity.state?.recovery
        harness.clock.reboot()
        let restarted = harness.makeAuth()
        _ = try restarted.activate(origin: harness.origin)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.recovery, recovery)
        XCTAssertEqual(harness.apple.keys, 0)
    }

    func testInitialInstallationDoesNotConsumeRecreationBudget() throws {
        let harness = try LifecycleHarness()
        harness.apple.attest = { .createWithError(NovaAuthAppAttestError.failure) }
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        assertError(.platformUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 0)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testRetirementSaveFailureRepairsReasonAndDelayWithoutChargingAgain() throws {
        let harness = try LifecycleHarness()
        harness.random.value = 0
        let (auth, context) = try harness.registered()
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = NovaAuthRecoveryState(backgroundRecreations: 1)
            try auth.persist(state)
        }
        harness.apple.assert = {
            harness.identity.failSave = true
            return .createWithError(NovaAuthAppAttestError.invalidKey)
        }
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .registered)
        harness.identity.failSave = false
        _ = try auth.activate(origin: harness.origin)
        XCTAssertEqual(harness.identity.state?.identity?.registration, .retired(.lostKey))
        XCTAssertEqual(harness.identity.state?.recovery?.backgroundRecreations, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.failures, 1)
        XCTAssertEqual(harness.identity.state?.recovery?.recreationDelay?.deadline?.continuousSeconds, 160)
    }

    private func retired(_ harness: LifecycleHarness, count: Int = 0) throws -> (NovaAuth, NovaAuthContext) {
        let (auth, context) = try harness.registered()
        try auth.gate.novaAuthLocked {
            var state = try XCTUnwrap(auth.state)
            state.recovery = NovaAuthRecoveryState(backgroundRecreations: count)
            try auth.persist(state)
            try auth.setRegistration(.retired(.lostKey), flight: NovaAuthIssuanceFlight(context: context, sponsored: false, intent: .background))
        }
        return (auth, context)
    }
}
