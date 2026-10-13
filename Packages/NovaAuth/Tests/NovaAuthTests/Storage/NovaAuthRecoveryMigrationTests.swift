import XCTest
import Keystore_iOS
@testable import NovaAuth

final class NovaAuthRecoveryMigrationTests: XCTestCase {
    func testAllRecoveryFieldsRoundTripThroughSettingsStorage() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        var state = try emptyState()
        var delay = NovaAuthCooldown()
        delay.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 100), random: 0, caps: 86400)
        state.recovery = NovaAuthRecoveryState(
            recreationDelay: delay, policyRetryDelay: delay, proofRetryDelay: delay, backgroundRecreations: 2
        )
        try store.save(state)
        XCTAssertEqual(try NovaAuthSettingsIdentityStore(settingsManager: settings).load(), state)
    }

    func testLegacyDeadlineMigratesWithoutTierAndSurvivesSaveAndReload() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        settings.set(value: try legacyData(failures: 6), for: NovaAuthSettingsIdentityStore.storageKey)
        let state = try XCTUnwrap(store.load())
        let delay = try XCTUnwrap(state.recovery?.recreationDelay)
        XCTAssertEqual(delay.failures, 0)
        XCTAssertEqual(delay.deadline, NovaAuthTime(bootID: "boot-a", continuousSeconds: 160))
        XCTAssertEqual(state.recovery?.backgroundRecreations, 0)
        XCTAssertThrowsError(try delay.check(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 100))) {
            XCTAssertEqual($0 as? NovaAuthError, .cooldown(retryAfter: 60))
        }
        try store.save(state)
        XCTAssertEqual(try NovaAuthSettingsIdentityStore(settingsManager: settings).load(), state)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        XCTAssertNil(encoded["recoveryCooldown"])
    }

    func testFirstRetirementAfterLegacyMigrationUsesFirstLadderTier() throws {
        let state = try JSONDecoder().decode(NovaAuthInstallationState.self, from: legacyData(failures: 6))
        var delay = try XCTUnwrap(state.recovery?.recreationDelay)
        delay.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 200), random: 0, caps: 86400)
        XCTAssertEqual(delay.failures, 1)
        XCTAssertEqual(delay.deadline?.continuousSeconds, 260)
    }

    func testMalformedLegacyCounterIsRejectedBeforeNormalization() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(NovaAuthInstallationState.self, from: legacyData(failures: 7)))
    }

    func testLegacyDeadlineWithZeroCountIsRejectedBeforeNormalization() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(NovaAuthInstallationState.self, from: legacyData(failures: 0)))
    }

    func testMalformedLegacyDeadlineIsRejectedBeforeNormalization() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(NovaAuthInstallationState.self, from: legacyData(failures: 1, seconds: -1)))
    }

    func testExplicitNullRecoveryTakesPrecedenceOverLegacyRecord() throws {
        var json = try legacyJSON(failures: 6)
        json["recovery"] = NSNull()
        let state = try JSONDecoder().decode(NovaAuthInstallationState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(state.recovery)
    }

    func testNewRecoveryTakesPrecedenceOverMalformedLegacyRecord() throws {
        var state = try emptyState()
        state.recovery = NovaAuthRecoveryState(backgroundRecreations: 2)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["recoveryCooldown"] = ["failures": -1]
        let decoded = try JSONDecoder().decode(NovaAuthInstallationState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.recovery, state.recovery)
        XCTAssertNoThrow(try NovaAuthStoredValidation.identity(decoded))
    }

    func testPolicyDeadlineWithZeroFailuresIsRejected() throws {
        var state = try emptyState()
        state.recovery = NovaAuthRecoveryState(policyRetryDelay: try zeroCountDelay())
        XCTAssertThrowsError(try NovaAuthStoredValidation.identity(state))
    }

    func testProofDeadlineWithZeroFailuresIsRejected() throws {
        var state = try emptyState()
        state.recovery = NovaAuthRecoveryState(proofRetryDelay: try zeroCountDelay())
        XCTAssertThrowsError(try NovaAuthStoredValidation.identity(state))
    }

    func testPendingProbeDeadlineWithZeroFailuresIsRejected() throws {
        let pending = NovaAuthPendingRegistration(
            startedAt: NovaAuthTime(bootID: "boot-a", continuousSeconds: 100),
            cooldown: try zeroCountDelay()
        )
        XCTAssertThrowsError(try NovaAuthStoredValidation.pendingRegistration(pending))
    }

    func testNegativeBackgroundRecreationCountIsRejected() throws {
        var state = try emptyState()
        state.recovery = NovaAuthRecoveryState(backgroundRecreations: -1)
        XCTAssertThrowsError(try NovaAuthStoredValidation.identity(state))
    }

    func testBackgroundRecreationCountAboveBudgetIsRejected() throws {
        var state = try emptyState()
        state.recovery = NovaAuthRecoveryState(backgroundRecreations: 3)
        XCTAssertThrowsError(try NovaAuthStoredValidation.identity(state))
    }

    private func emptyState() throws -> NovaAuthInstallationState {
        NovaAuthInstallationState(version: 1, context: try FoundationFixture.context(), requiresUserAction: false, identity: nil)
    }

    private func zeroCountDelay() throws -> NovaAuthCooldown {
        let data = try JSONSerialization.data(withJSONObject: [
            "failures": 0, "deadline": ["bootID": "boot-a", "continuousSeconds": 160]
        ])
        return try JSONDecoder().decode(NovaAuthCooldown.self, from: data)
    }

    private func legacyData(failures: Int, seconds: Double = 160) throws -> Data {
        try JSONSerialization.data(withJSONObject: legacyJSON(failures: failures, seconds: seconds))
    }

    private func legacyJSON(failures: Int, seconds: Double = 160) throws -> [String: Any] {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(emptyState())) as? [String: Any])
        json.removeValue(forKey: "recovery")
        json["recoveryCooldown"] = [
            "failures": failures, "deadline": ["bootID": "boot-a", "continuousSeconds": seconds]
        ]
        return json
    }
}
