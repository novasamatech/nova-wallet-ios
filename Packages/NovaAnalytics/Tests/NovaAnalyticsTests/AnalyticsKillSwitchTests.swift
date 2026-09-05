import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsKillSwitchTests: XCTestCase {
    func testRemoteDisabledMakesTheSubsystemUnavailable() {
        let availability = AnalyticsAvailabilityProvider(attestationMode: .appAttest, remoteEnabled: true)
        XCTAssertTrue(availability.isAvailable)

        availability.setRemoteEnabled(false)
        XCTAssertFalse(availability.isAvailable)
    }

    func testUnavailableAttestationBeatsAnEnabledRemoteConfig() {
        let availability = AnalyticsAvailabilityProvider(attestationMode: .unavailable, remoteEnabled: true)
        XCTAssertFalse(availability.isAvailable)
    }

    func testKillSwitchWipesOnceOnTheEnabledToDisabledEdge() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.service.handleAvailabilityChanged()
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.availability.setRemoteEnabled(false)
        fixture.service.handleAvailabilityChanged()
        XCTAssertEqual(try fixture.queueCount(), 0)

        try fixture.enqueueBypassingTheGuard(name: "leftover")
        fixture.service.handleAvailabilityChanged()
        XCTAssertEqual(try fixture.queueCount(), 1)
    }

    func testKillSwitchAbandonsAnInFlightFlush() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let started = XCTestExpectation(description: "flush started")
        let neverFinishes = CompoundOperationWrapper(
            targetOperation: AsyncClosureOperation<Void> { _ in started.fulfill() }
        )

        fixture.uploader.flushStub = { _ in neverFinishes }

        fixture.service.track(.novaCardOpened())
        wait(for: [started], timeout: 5)
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.availability.setRemoteEnabled(false)
        fixture.service.handleAvailabilityChanged()

        XCTAssertTrue(neverFinishes.targetOperation.isCancelled)
        XCTAssertEqual(try fixture.queueCount(), 0)
    }
}
