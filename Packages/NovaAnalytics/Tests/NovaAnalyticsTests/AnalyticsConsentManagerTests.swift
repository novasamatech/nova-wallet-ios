import XCTest
@testable import NovaAnalytics
import Keystore_iOS

private final class StubAvailability: AnalyticsAvailabilityProviderProtocol {
    let isAvailable = true
    let remoteState = AnalyticsRemoteState.enabled

    func setRemoteEnabled(_: Bool) {}

    func addObserver(with _: AnyObject, queue _: DispatchQueue?, closure _: @escaping (Bool) -> Void) {}

    func removeObserver(by _: AnyObject) {}
}

final class AnalyticsConsentManagerTests: XCTestCase {
    private func makeManager(settings: SettingsManagerProtocol = InMemorySettingsManager()) -> AnalyticsConsentManager {
        AnalyticsConsentManager(settingsManager: settings, availabilityProvider: StubAvailability())
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

    func testAWithdrawalIsWrittenOnlyAfterTheErasureObligation() {
        let settings = SerialisedSettingsManager()
        let manager = makeManager(settings: settings)

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
}
