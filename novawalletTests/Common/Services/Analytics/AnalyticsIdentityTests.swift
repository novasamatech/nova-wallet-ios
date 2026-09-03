import XCTest
@testable import novawallet
import Keystore_iOS

final class AnalyticsIdentityTests: XCTestCase {
    func testInstallIdIsNotCreatedUntilItIsAsked() {
        let settings = InMemorySettingsManager()
        _ = AnalyticsIdentity(settingsManager: settings)

        XCTAssertNil(settings.string(for: SettingsKey.analyticsInstallId.rawValue))
    }

    func testInstallIdIsStableOnceCreated() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let first = identity.installId()
        XCTAssertEqual(identity.installId(), first)
        XCTAssertEqual(settings.string(for: SettingsKey.analyticsInstallId.rawValue), first)
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
        XCTAssertNil(settings.string(for: SettingsKey.analyticsInstallId.rawValue))
    }

    func testNewInstallIdAfterForgetIsDifferent() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let first = identity.installId()
        identity.forgetInstallId()

        XCTAssertNotEqual(identity.installId(), first)
    }

    func testSessionIdIsPerInstanceAndStable() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        XCTAssertEqual(identity.sessionId, identity.sessionId)
        XCTAssertNotEqual(AnalyticsIdentity(settingsManager: settings).sessionId, identity.sessionId)
    }
}
