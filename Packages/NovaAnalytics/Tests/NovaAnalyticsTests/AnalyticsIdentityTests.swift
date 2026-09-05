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

        // The key must be absent, not replaced: an opted-out install has no id at all,
        // so it is indistinguishable on the wire from a brand-new install.
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

        // An upload chain still executing during opt-out reaches installId() after the
        // wipe. Minting there would leave an opted-out install holding an identifier.
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

        // A shared session id would let the gateway link the pre-opt-out install id to the
        // post-re-consent one, undoing the point of minting a new one.
        XCTAssertNotEqual(identity.sessionId, beforeSession)
    }

    /// Came from `BackendAttestationIdentityTests` when that file moved into `NovaAppAttest`.
    /// It spans both identities, and `AnalyticsIdentity` is still an app type, so the
    /// package's test target cannot hold it.
    func testClientIdIsIndependentOfInstallId() {
        let settings = InMemorySettingsManager()
        let identity = BackendAttestationIdentity(settingsManager: settings)
        let analytics = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNotEqual(identity.clientId(), analytics.installId())
    }
}
