import XCTest
@testable import NovaAnalytics
import Keystore_iOS

final class AnalyticsIdentityTests: XCTestCase {
    func testPersistsInstallId() throws {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let first = try XCTUnwrap(identity.installId())
        XCTAssertEqual(identity.installId(), first)
        XCTAssertEqual(settings.string(for: "analyticsInstallId"), first)
        XCTAssertEqual(first, first.lowercased())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testForgetResetsInstallId() {
        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)

        let original = identity.installId()
        identity.forgetInstallId()

        XCTAssertNil(settings.string(for: "analyticsInstallId"))
        XCTAssertNil(identity.installId())

        identity.allowCreation()
        let recreated = identity.installId()

        XCTAssertNotNil(recreated)
        XCTAssertNotEqual(recreated, original)
    }
}
