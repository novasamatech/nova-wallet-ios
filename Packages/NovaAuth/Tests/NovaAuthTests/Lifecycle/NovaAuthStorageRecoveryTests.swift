import XCTest
import Keystore_iOS
@testable import NovaAuth

final class NovaAuthStorageRecoveryTests: LifecycleTestCase {
    func testCorruptIdentityActivationRepairsOnlyAfterRemovingOldBearer() throws {
        for corrupt in [Data("not-json".utf8), Data(#"{"version":999}"#.utf8)] {
            let harness = try LifecycleHarness()
            let (_, previous) = try harness.registered(withToken: true)
            let settings = InMemorySettingsManager()
            settings.set(value: corrupt, for: NovaAuthSettingsIdentityStore.storageKey)
            let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
            let auth = harness.makeAuth(identityStore: store)
            harness.tokens.failRemove = true
            XCTAssertThrowsError(try auth.activate(origin: harness.origin)) {
                XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable)
            }
            let fenced = try XCTUnwrap(auth.state?.context)
            XCTAssertGreaterThan(fenced.generation, previous.generation)
            XCTAssertEqual(try store.load()?.tokenRemovalOwed, true)
            assertError(.storageUnavailable, auth.createAdmissionWrapper(in: fenced, intent: .background), on: harness.callers)
            harness.tokens.failRemove = false
            XCTAssertEqual(try auth.activate(origin: harness.origin), fenced)
            XCTAssertNil(try harness.tokens.load())
            XCTAssertNil(try store.load()?.tokenRemovalOwed)
            try execute(auth.createAdmissionWrapper(in: fenced, intent: .background), on: harness.callers)
            XCTAssertEqual(harness.apple.keys, 1)
        }
    }

    func testCorruptIdentityResetPersistsUserGateUntilAcceptedActivation() throws {
        let harness = try LifecycleHarness()
        _ = try harness.registered(withToken: true)
        let settings = InMemorySettingsManager()
        settings.set(value: Data("corrupt".utf8), for: NovaAuthSettingsIdentityStore.storageKey)
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        let auth = harness.makeAuth(identityStore: store)
        harness.tokens.failRemove = true
        XCTAssertThrowsError(try auth.reset())
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? NovaAuthIdentityStoreError, .resetPending) }
        harness.tokens.failRemove = false
        let restarted = harness.makeAuth(identityStore: store)
        let context = try restarted.activate(origin: harness.origin)
        XCTAssertNil(try harness.tokens.load())
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        try execute(restarted.createAdmissionWrapper(in: context, intent: .userInitiated), on: harness.callers)
        XCTAssertEqual(harness.apple.keys, 1)
    }

    func testFailedIdentitySaveRetriesExactIntendedIdentityBeforeStartingApple() throws {
        let harness = try LifecycleHarness()
        let auth = harness.makeAuth()
        let context = try auth.activate(origin: harness.origin)
        harness.identity.failSave = true
        assertError(.storageUnavailable, auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        let intended = auth.gate.novaAuthLocked { auth.state?.identity }
        XCTAssertNotNil(intended)
        XCTAssertNil(harness.identity.state?.identity)
        XCTAssertEqual(harness.apple.keys, 0)
        XCTAssertThrowsError(try auth.activate(origin: harness.origin))
        harness.identity.failSave = false
        XCTAssertEqual(try auth.activate(origin: harness.origin), context)
        XCTAssertEqual(harness.identity.state?.identity, intended)
        try execute(auth.createAdmissionWrapper(in: context, intent: .background), on: harness.callers)
        XCTAssertEqual(harness.identity.state?.identity?.clientID, intended?.clientID)
        XCTAssertEqual(harness.random.identifiers, 1)
    }

    func testResetDeletionOwedSurvivesRestartAndSameOriginActivationCompletesIt() throws {
        let harness = try LifecycleHarness()
        let (auth, original) = try harness.registered(withToken: true)
        harness.tokens.failRemove = true
        XCTAssertThrowsError(try auth.reset())
        let fenced = try XCTUnwrap(auth.state?.context)
        XCTAssertEqual(fenced.generation, original.generation + 1)
        XCTAssertEqual(harness.identity.state?.tokenRemovalOwed, true)
        XCTAssertThrowsError(try auth.activate(origin: harness.origin))
        let restarted = harness.makeAuth()
        XCTAssertThrowsError(try restarted.activate(origin: harness.origin))
        assertError(.storageUnavailable, restarted.createAdmissionWrapper(in: fenced, intent: .userInitiated), on: harness.callers)
        XCTAssertNotNil(try harness.tokens.load())
        harness.tokens.failRemove = false
        XCTAssertEqual(try restarted.activate(origin: harness.origin), fenced)
        XCTAssertNil(try harness.tokens.load())
        XCTAssertNil(harness.identity.state?.tokenRemovalOwed)
        assertError(.userActionRequired, restarted.createAdmissionWrapper(in: fenced, intent: .background), on: harness.callers)
    }

    func testTransientEmptyIdentityLoadRetryDoesNotDeleteAnOrphanBearer() throws {
        let harness = try LifecycleHarness()
        _ = try harness.registered(withToken: true)
        harness.identity.state = nil
        harness.identity.failLoad = true
        let auth = harness.makeAuth()
        XCTAssertThrowsError(try auth.activate(origin: harness.origin))
        harness.identity.failLoad = false
        _ = try auth.activate(origin: harness.origin)
        XCTAssertNotNil(try harness.tokens.load())
        XCTAssertNil(harness.identity.state?.identity)
    }
}
