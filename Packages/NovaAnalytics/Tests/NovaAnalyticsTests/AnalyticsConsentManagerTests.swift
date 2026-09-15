import XCTest
@testable import NovaAnalytics
import Keystore_iOS

final class AnalyticsConsentManagerTests: XCTestCase {
    private func makeManager(settings: SettingsManagerProtocol = InMemorySettingsManager()) -> AnalyticsConsentManager {
        AnalyticsConsentManager(settingsManager: settings, availabilityProvider: AnalyticsAvailabilityStub())
    }

    func testDefaultsToDisabledAndUnprompted() {
        let manager = makeManager()

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isPromptSeen)
    }

    func testSetEnabledPersistsAndNotifies() {
        let settings = InMemorySettingsManager()
        let manager = makeManager(settings: settings)

        let owner = NSObject()
        var observed: [Bool] = []
        manager.addObserver(with: owner, queue: nil) { _, new in observed.append(new) }

        manager.setEnabled(true)
        manager.setEnabled(false)

        XCTAssertEqual(observed, [true, false])
        XCTAssertFalse(settings.bool(for: "analyticsEnabled") ?? true)
    }
}
