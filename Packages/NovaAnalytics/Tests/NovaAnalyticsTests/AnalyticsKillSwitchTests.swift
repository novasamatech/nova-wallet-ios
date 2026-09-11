import XCTest
@testable import NovaAnalytics
import Keystore_iOS
import NovaAppAttest

final class AnalyticsKillSwitchTests: XCTestCase {
    private typealias Keys = AnalyticsTestFixture.Keys

    private func makeProvider(
        attestationMode: BackendAttestationMode = .appAttest,
        settings: InMemorySettingsManager = InMemorySettingsManager()
    ) -> AnalyticsAvailabilityProvider {
        AnalyticsAvailabilityProvider(attestationMode: attestationMode, settingsManager: settings)
    }

    func testAnUnresolvedRemoteStateIsUnavailable() {
        XCTAssertFalse(makeProvider().isAvailable)
    }

    func testARemoteOffOrAnUnavailableAttestationMakesTheSubsystemUnavailable() {
        let availability = makeProvider()

        availability.setRemoteEnabled(true)
        XCTAssertTrue(availability.isAvailable)

        availability.setRemoteEnabled(false)
        XCTAssertFalse(availability.isAvailable)

        let unattestable = makeProvider(attestationMode: .unavailable)

        unattestable.setRemoteEnabled(true)
        XCTAssertFalse(unattestable.isAvailable)
    }

    func testAPersistedOffSeedsTheProviderOff() {
        let settings = InMemorySettingsManager()
        settings.set(value: false, for: Keys.remoteEnabled)

        let availability = makeProvider(settings: settings)

        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.remoteState, .disabled)
    }

    func testKillSwitchWipesOnceOnTheEnabledToDisabledEdge() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.service.handleRemoteResolved(isEnabled: true)
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.service.handleRemoteResolved(isEnabled: false)
        XCTAssertEqual(try fixture.queueCount(), 0)

        try fixture.enqueueBypassingTheGuard(name: "leftover")
        fixture.service.handleRemoteResolved(isEnabled: false)
        XCTAssertEqual(try fixture.queueCount(), 1)
    }
}
