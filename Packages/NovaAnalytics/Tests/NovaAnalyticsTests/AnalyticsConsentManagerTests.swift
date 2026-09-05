import XCTest
@testable import NovaAnalytics
import Keystore_iOS

private final class StubAvailability: AnalyticsAvailabilityProviderProtocol {
    var isAvailable: Bool

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }
}

final class AnalyticsConsentManagerTests: XCTestCase {
    func testDefaultsToDisabledAndUnprompted() {
        let manager = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isPromptSeen)
    }

    func testSetEnabledPersistsAndNotifies() {
        let settings = InMemorySettingsManager()
        let manager = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        let owner = NSObject()
        var observed: [Bool] = []
        manager.addObserver(with: owner, queue: nil) { _, new in observed.append(new) }

        manager.setEnabled(true)
        manager.setEnabled(false)

        XCTAssertEqual(observed, [true, false])
        XCTAssertFalse(settings.bool(for: "analyticsEnabled") ?? true)
    }

    func testMarkPromptSeenIsPersistedAndNeverCleared() {
        let settings = InMemorySettingsManager()
        let manager = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        manager.markPromptSeen()
        manager.setEnabled(true)
        manager.setEnabled(false)

        XCTAssertTrue(manager.isPromptSeen)
    }

    func testAvailabilityIsForwarded() {
        let availability = StubAvailability(isAvailable: false)
        let manager = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: availability
        )

        XCTAssertFalse(manager.isAvailable)
        availability.isAvailable = true
        XCTAssertTrue(manager.isAvailable)
    }
}
