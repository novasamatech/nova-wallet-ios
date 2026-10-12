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
        XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
        XCTAssertEqual(settings.data(for: NovaAuthSettingsIdentityStore.storageKey), data)
    }

    func testMissingOrInvalidPersistedProbeMetadataFailsClosed() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0.removeValue(forKey: "probeCount") },
            { $0.removeValue(forKey: "cooldown") },
            { $0["probeCount"] = -1 },
            { $0["probeCount"] = 9 },
            { $0["probeCount"] = "1" },
            { $0["startedAt"] = ["bootID": "", "continuousSeconds": 50] },
            { $0["cooldown"] = ["failures": -1] },
            { $0["cooldown"] = ["failures": 7] },
            { $0["cooldown"] = ["failures": 0] },
            { $0["cooldown"] = ["failures": 1] },
            { $0["cooldown"] = ["deadline": ["bootID": "boot-a", "continuousSeconds": 51]] },
            { $0["cooldown"] = ["failures": 1, "deadline": ["bootID": "boot-a", "continuousSeconds": -1]] },
            { $0["cooldown"] = ["failures": 1, "deadline": ["bootID": "boot-a", "continuousSeconds": 49]] }
        ]
        for mutation in mutations {
            let settings = InMemorySettingsManager()
            let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
            settings.set(value: try encodedPending(mutation), for: NovaAuthSettingsIdentityStore.storageKey)
            XCTAssertThrowsError(try store.load()) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
        }
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
                    startedAt: started, probeCount: 1, cooldown: cooldown
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
