import XCTest
@testable import NovaAnalytics
import Keystore_iOS

final class AnalyticsIdentityTests: XCTestCase {
    func testInstallIdIsStableOnceCreated() throws {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let first = try XCTUnwrap(identity.installId())
        XCTAssertEqual(identity.installId(), first)
        XCTAssertEqual(settings.string(for: "analyticsInstallId"), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testForgetDeletesTheInstallIdAndReConsentMintsAFreshOne() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let original = identity.installId()
        identity.forgetInstallId()

        XCTAssertNil(settings.string(for: "analyticsInstallId"))

        identity.allowCreation()
        let recreated = identity.installId()

        XCTAssertNotNil(recreated)
        XCTAssertNotEqual(recreated, original)
    }

    func testTheConsentEpochSurvivesAFreshIdentityOverTheSameSettings() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        XCTAssertEqual(identity.consentEpoch, 0)

        identity.forgetInstallId()
        identity.allowCreation()

        XCTAssertEqual(identity.consentEpoch, 2)
        XCTAssertEqual(settings.integer(for: "analyticsConsentEpoch"), 2)
        XCTAssertEqual(AnalyticsIdentity(settingsManager: settings).consentEpoch, 2)
    }
}
