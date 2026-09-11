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

    func testRepeatingTheCurrentValueNotifiesNobody() {
        let manager = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        let owner = NSObject()
        var observed: [Bool] = []
        manager.addObserver(with: owner, queue: nil) { _, new in observed.append(new) }

        manager.setEnabled(false)
        manager.setEnabled(true)
        manager.setEnabled(true)

        XCTAssertEqual(observed, [true])
    }

    func testRemoveObserverStopsNotifications() {
        let manager = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        let owner = NSObject()
        var observed: [Bool] = []
        manager.addObserver(with: owner, queue: nil) { _, new in observed.append(new) }

        manager.setEnabled(true)
        manager.removeObserver(by: owner)
        manager.setEnabled(false)

        XCTAssertEqual(observed, [true])
    }

    func testDeallocatedOwnerIsPrunedRatherThanNotified() {
        let manager = AnalyticsConsentManager(
            settingsManager: InMemorySettingsManager(),
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        let survivor = NSObject()
        var observed: [Bool] = []
        var transient: NSObject? = NSObject()

        manager.addObserver(with: transient!, queue: nil) { _, _ in
            XCTFail("a deallocated owner's closure ran")
        }

        manager.addObserver(with: survivor, queue: nil) { _, new in observed.append(new) }

        transient = nil

        manager.setEnabled(true)

        XCTAssertEqual(observed, [true])
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

    func testAWithdrawalIsWrittenOnlyAfterTheErasureObligation() {
        let settings = RecordingSettingsManager()
        let manager = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        manager.setEnabled(true)
        manager.setEnabled(false)

        XCTAssertEqual(
            settings.boolWrites,
            [
                .init(key: "analyticsEnabled", value: true),
                .init(key: "analyticsErasureOwed", value: true),
                .init(key: "analyticsEnabled", value: false)
            ]
        )
    }

    func testDecliningWithoutPriorConsentOwesNoErasure() {
        let settings = RecordingSettingsManager()
        let manager = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        manager.setEnabled(false)

        XCTAssertEqual(settings.boolWrites, [.init(key: "analyticsEnabled", value: false)])
    }

    func testTheErasureObligationOutlivesTheManagerThatRecordedIt() {
        let settings = InMemorySettingsManager()
        let manager = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: StubAvailability(isAvailable: true)
        )

        XCTAssertFalse(manager.isErasureOwed)

        manager.setErasureOwed(true)

        XCTAssertEqual(settings.bool(for: "analyticsErasureOwed"), true)
        XCTAssertTrue(
            AnalyticsConsentManager(
                settingsManager: settings,
                availabilityProvider: StubAvailability(isAvailable: true)
            ).isErasureOwed
        )
    }
}
