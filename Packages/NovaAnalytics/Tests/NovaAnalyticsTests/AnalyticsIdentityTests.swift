import XCTest
@testable import NovaAnalytics
import Keystore_iOS
import NovaAppAttest

final class AnalyticsIdentityTests: XCTestCase {
    func testInstallIdIsNotCreatedUntilItIsAsked() {
        let settings = InMemorySettingsManager()
        _ = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNil(settings.string(for: "analyticsInstallId"))
    }

    func testInstallIdIsStableOnceCreated() throws {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let first = try XCTUnwrap(identity.installId())
        XCTAssertEqual(identity.installId(), first)
        XCTAssertEqual(settings.string(for: "analyticsInstallId"), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testForgetDeletesRatherThanRotates() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        _ = identity.installId()
        identity.forgetInstallId()

        XCTAssertNil(settings.string(for: "analyticsInstallId"))
    }

    func testSessionIdIsPerInstanceAndStable() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        XCTAssertEqual(identity.sessionId, identity.sessionId)
        XCTAssertNotEqual(AnalyticsIdentity(settingsManager: settings).sessionId, identity.sessionId)
    }

    func testForgetBlocksRecreationUntilConsentIsGrantedAgain() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        _ = identity.installId()
        identity.forgetInstallId()

        XCTAssertNil(identity.installId())
        XCTAssertNil(settings.string(for: "analyticsInstallId"))
    }

    func testReConsentAllowsAFreshInstallId() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let original = identity.installId()
        identity.forgetInstallId()
        identity.allowCreation()

        let recreated = identity.installId()

        XCTAssertNotNil(recreated)
        XCTAssertNotEqual(recreated, original)
    }

    func testReConsentRotatesTheSessionIdSoTheTwoInstallsCannotBeJoined() {
        let identity = AnalyticsIdentity(settingsManager: InMemorySettingsManager())

        let beforeSession = identity.sessionId
        identity.forgetInstallId()
        identity.allowCreation()

        XCTAssertNotEqual(identity.sessionId, beforeSession)
    }

    func testClientIdIsIndependentOfInstallId() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let analytics = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNotEqual(identity.clientId(), analytics.installId())
    }
}
