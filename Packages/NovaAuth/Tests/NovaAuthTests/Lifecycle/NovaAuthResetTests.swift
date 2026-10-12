import XCTest
@testable import NovaAuth

final class NovaAuthResetTests: LifecycleTestCase {
    func testResetBeforeActivationFencesPersistedIdentityAndDeniesReaderAndBackgroundRecreation() throws {
        let harness = try LifecycleHarness()
        let (_, original) = try harness.registered(withToken: true)
        let reader = harness.makeReader()
        XCTAssertEqual(try execute(reader.createContextWrapper(), on: harness.callers), original)
        let restarted = harness.makeAuth()
        XCTAssertNil(restarted.currentContext)
        try restarted.reset()
        let next = try XCTUnwrap(restarted.currentContext)
        XCTAssertEqual(next.generation, original.generation + 1)
        XCTAssertEqual(next.origin, original.origin)
        XCTAssertEqual(harness.identity.state?.requiresUserAction, true)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertNil(try harness.tokens.load())
        assertError(.credentialUnavailable, reader.createContextWrapper(), on: harness.callers)
        assertError(.credentialUnavailable, reader.createResponseWrapper(for: try harness.request(context: original), beforeSend: {}), on: harness.callers)
        assertError(.generationChanged, restarted.createAdmissionWrapper(in: original, intent: .userInitiated), on: harness.callers)
        for owner in [restarted, harness.makeAuth()] {
            XCTAssertEqual(try owner.activate(origin: harness.origin), next)
            assertError(.userActionRequired, owner.createAdmissionWrapper(in: next, intent: .background), on: harness.callers)
        }
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.http.requests.count, 0)
    }

    func testResetBeforeActivationReportsIdentityLoadFailure() throws {
        let harness = try LifecycleHarness()
        let (_, original) = try harness.registered(withToken: true)
        let restarted = harness.makeAuth()
        harness.identity.failLoad = true
        XCTAssertThrowsError(try restarted.reset()) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
        XCTAssertEqual(harness.identity.state?.context, original)
        XCTAssertNotNil(try harness.tokens.load())
        harness.identity.failLoad = false
        XCTAssertEqual(try restarted.activate(origin: harness.origin), original)
        XCTAssertNotNil(try harness.tokens.load())
        try restarted.reset()
        XCTAssertNil(try harness.tokens.load())
    }

    func testResetBeforeActivationReportsSaveAndDeletionFailuresAndKeepsMemoryFence() throws {
        for failSave in [true, false] {
            let harness = try LifecycleHarness()
            let (_, original) = try harness.registered(withToken: true)
            let restarted = harness.makeAuth()
            harness.identity.failSave = failSave
            harness.tokens.failRemove = !failSave
            XCTAssertThrowsError(try restarted.reset()) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
            let fenced = try XCTUnwrap(restarted.currentContext)
            XCTAssertEqual(fenced.generation, original.generation + 1)
            assertError(.storageUnavailable, restarted.createAdmissionWrapper(in: fenced, intent: .background), on: harness.callers)
            XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
            XCTAssertEqual(harness.apple.keys, 0)
            harness.identity.failSave = false
            harness.tokens.failRemove = false
            try restarted.reset()
            XCTAssertNil(try harness.tokens.load())
            XCTAssertNil(harness.identity.state?.identity)
        }
    }

    func testResetWithoutSavedInstallationRemovesOrphanBearerAndReportsDeletionFailure() throws {
        let harness = try LifecycleHarness()
        _ = try harness.registered(withToken: true)
        harness.identity.state = nil
        let restarted = harness.makeAuth()
        harness.tokens.failRemove = true
        XCTAssertThrowsError(try restarted.reset()) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertThrowsError(try restarted.activate(origin: harness.origin)) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
        let fenced = try XCTUnwrap(restarted.currentContext)
        XCTAssertEqual(harness.identity.state?.tokenRemovalOwed, true)
        harness.tokens.failRemove = false
        try restarted.reset()
        XCTAssertNil(try harness.tokens.load())
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertEqual(harness.identity.state?.requiresUserAction, true)
        XCTAssertNil(harness.identity.state?.tokenRemovalOwed)
        XCTAssertEqual(restarted.currentContext, fenced)
        let context = try restarted.activate(origin: harness.origin)
        XCTAssertEqual(context, fenced)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertEqual(harness.bootstrap.tokenChallenges, 0)
    }
}
