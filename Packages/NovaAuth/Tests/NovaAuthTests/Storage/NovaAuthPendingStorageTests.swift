import XCTest
import Keystore_iOS
@testable import NovaAuth

final class NovaAuthPendingStorageTests: XCTestCase {
    func testPendingRecoveryStateRoundTripsAllBudgetAndCooldownFields() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        let state = try pendingState()
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
        XCTAssertEqual(try NovaAuthSettingsIdentityStore(settingsManager: settings).load(), state)
        XCTAssertTrue(Mirror(reflecting: try XCTUnwrap(state.identity)).children.isEmpty)
        if case let .registrationPending(pending) = state.identity?.registration {
            XCTAssertTrue(Mirror(reflecting: pending).children.isEmpty)
        } else { XCTFail("Expected pending registration") }
    }

    func testLegacyTimestampOnlyPendingStateFailsClosedWithoutFreshBudget() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        let data = try encodedPending { pending in
            pending = ["bootID": "boot-a", "continuousSeconds": 50]
        }
        settings.set(value: data, for: NovaAuthSettingsIdentityStore.storageKey)
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? NovaAuthIdentityStoreError, .corrupt) }
        XCTAssertEqual(settings.data(for: NovaAuthSettingsIdentityStore.storageKey), data)
    }

    func testMissingOrInvalidPersistedProbeMetadataFailsClosed() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0.removeValue(forKey: "unknownResponseCount") },
            { $0.removeValue(forKey: "cooldown") },
            { $0["unknownResponseCount"] = -1 },
            { $0["unknownResponseCount"] = 9 },
            { $0["unknownResponseCount"] = "1" },
            { $0["startedAt"] = ["bootID": "", "continuousSeconds": 50] },
            { $0["cooldown"] = ["failures": -1] },
            { $0["cooldown"] = ["failures": 7] },
            { $0["cooldown"] = ["failures": 1] },
            { $0["cooldown"] = ["deadline": ["bootID": "boot-a", "continuousSeconds": 51]] },
            { $0["cooldown"] = ["failures": 1, "deadline": ["bootID": "boot-a", "continuousSeconds": -1]] },
            { $0["cooldown"] = ["failures": 1, "deadline": ["bootID": "boot-a", "continuousSeconds": 49]] }
        ]
        for mutation in mutations {
            let settings = InMemorySettingsManager()
            let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
            settings.set(value: try encodedPending(mutation), for: NovaAuthSettingsIdentityStore.storageKey)
            XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? NovaAuthIdentityStoreError, .corrupt) }
        }
    }

    func testLegacyReservedProbeCountMigratesWithoutBecomingUnknownEvidence() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        let data = try encodedPending { pending in
            pending.removeValue(forKey: "unknownResponseCount")
            pending["probeCount"] = 8
        }
        settings.set(value: data, for: NovaAuthSettingsIdentityStore.storageKey)
        let migrated = try XCTUnwrap(store.load())
        guard case let .registrationPending(pending) = migrated.identity?.registration,
              case let .registrationPending(original) = try pendingState().identity?.registration else {
            return XCTFail("Expected migrated pending state")
        }
        XCTAssertEqual(pending.unknownResponseCount, 0)
        XCTAssertEqual(pending.startedAt, original.startedAt)
        XCTAssertEqual(pending.cooldown, original.cooldown)
        try store.save(migrated)
        XCTAssertEqual(try store.load(), migrated)
    }

    func testVersionOneWithoutRecoveryMetadataPreservesIdentityAndContext() throws {
        var state = try pendingState()
        var cooldown = NovaAuthCooldown()
        cooldown.fail(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 50), random: 0, retryAfter: 60)
        state.recoveryCooldown = cooldown
        state.tokenRemovalOwed = true
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "recoveryCooldown")
        json.removeValue(forKey: "tokenRemovalOwed")
        let settings = InMemorySettingsManager()
        settings.set(value: try JSONSerialization.data(withJSONObject: json), for: NovaAuthSettingsIdentityStore.storageKey)
        let decoded = try XCTUnwrap(NovaAuthSettingsIdentityStore(settingsManager: settings).load())
        XCTAssertEqual(decoded.context, state.context)
        XCTAssertEqual(decoded.identity, state.identity)
        XCTAssertNil(decoded.recoveryCooldown)
        XCTAssertNil(decoded.tokenRemovalOwed)
    }

    private func pendingState() throws -> NovaAuthInstallationState {
        let started = NovaAuthTime(bootID: "boot-a", continuousSeconds: 50)
        var cooldown = NovaAuthCooldown()
        cooldown.fail(now: started, random: 0.5)
        return NovaAuthInstallationState(
            version: 1,
            context: try FoundationFixture.context(),
            requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: FoundationFixture.clientID,
                keyID: FoundationFixture.keyID,
                registration: .registrationPending(NovaAuthPendingRegistration(
                    startedAt: started, unknownResponseCount: 1, cooldown: cooldown
                ))
            )
        )
    }

    private func encodedPending(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
        let data = try JSONEncoder().encode(pendingState())
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var identity = try XCTUnwrap(root["identity"] as? [String: Any])
        var registration = try XCTUnwrap(identity["registration"] as? [String: Any])
        var pendingCase = try XCTUnwrap(registration["registrationPending"] as? [String: Any])
        var pending = try XCTUnwrap(pendingCase["_0"] as? [String: Any])
        mutate(&pending)
        pendingCase["_0"] = pending
        registration["registrationPending"] = pendingCase
        identity["registration"] = registration
        root["identity"] = identity
        return try JSONSerialization.data(withJSONObject: root)
    }
}
