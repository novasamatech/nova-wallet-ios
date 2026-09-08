import XCTest
@testable import NovaAnalytics
import Operation_iOS
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

    func testRemoteDisabledMakesTheSubsystemUnavailable() {
        let availability = makeProvider()

        availability.setRemoteEnabled(true)
        XCTAssertTrue(availability.isAvailable)

        availability.setRemoteEnabled(false)
        XCTAssertFalse(availability.isAvailable)
    }

    func testUnavailableAttestationBeatsAnEnabledRemoteConfig() {
        let availability = makeProvider(attestationMode: .unavailable)

        availability.setRemoteEnabled(true)

        XCTAssertFalse(availability.isAvailable)
    }

    func testAPersistedOffSeedsTheProviderOff() {
        let settings = InMemorySettingsManager()
        settings.set(value: false, for: Keys.remoteEnabled)

        XCTAssertFalse(makeProvider(settings: settings).isAvailable)
    }

    func testAPersistedOnSeedsTheProviderOn() {
        let settings = InMemorySettingsManager()
        settings.set(value: true, for: Keys.remoteEnabled)

        XCTAssertTrue(makeProvider(settings: settings).isAvailable)
    }

    func testAResolutionPersistsTheRemoteState() {
        let settings = InMemorySettingsManager()
        let availability = makeProvider(settings: settings)

        availability.setRemoteEnabled(true)
        XCTAssertEqual(settings.bool(for: Keys.remoteEnabled), true)

        availability.setRemoteEnabled(false)
        XCTAssertEqual(settings.bool(for: Keys.remoteEnabled), false)
    }

    func testObserversFireOnlyWhenTheEffectiveAvailabilityChanges() {
        let availability = makeProvider()

        let owner = NSObject()
        var observed: [Bool] = []
        availability.addObserver(with: owner, queue: nil) { observed.append($0) }

        availability.setRemoteEnabled(true)
        availability.setRemoteEnabled(true)
        availability.setRemoteEnabled(false)
        availability.setRemoteEnabled(false)

        XCTAssertEqual(observed, [true, false])
    }

    func testObserversStaySilentWhileAttestationIsUnavailable() {
        let availability = makeProvider(attestationMode: .unavailable)

        let owner = NSObject()
        var observed: [Bool] = []
        availability.addObserver(with: owner, queue: nil) { observed.append($0) }

        availability.setRemoteEnabled(true)
        availability.setRemoteEnabled(false)

        XCTAssertEqual(observed, [])
    }

    func testRemoveObserverStopsAvailabilityNotifications() {
        let availability = makeProvider()

        let owner = NSObject()
        var observed: [Bool] = []
        availability.addObserver(with: owner, queue: nil) { observed.append($0) }

        availability.setRemoteEnabled(true)
        availability.removeObserver(by: owner)
        availability.setRemoteEnabled(false)

        XCTAssertEqual(observed, [true])
    }

    func testDeallocatedObserverOwnerIsPrunedRatherThanNotified() {
        let availability = makeProvider()

        let survivor = NSObject()
        var observed: [Bool] = []
        var transient: NSObject? = NSObject()

        availability.addObserver(with: transient!, queue: nil) { _ in
            XCTFail("a deallocated owner's closure ran")
        }

        availability.addObserver(with: survivor, queue: nil) { observed.append($0) }

        transient = nil

        availability.setRemoteEnabled(true)

        XCTAssertEqual(observed, [true])
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

    func testAnUnresolvedSeedNeverWipesOnItsFirstResolution() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(settings: settings, storage: storage)
        previousLaunch.service.track(.novaCardOpened())
        XCTAssertEqual(try previousLaunch.queueCount(), 1)

        settings.removeValue(for: Keys.remoteEnabled)

        let relaunch = AnalyticsTestFixture.makeUnresolved(settings: settings, storage: storage)
        XCTAssertFalse(relaunch.availability.isAvailable)

        relaunch.availability.setRemoteEnabled(true)
        relaunch.service.handleAvailabilityChanged()
        XCTAssertEqual(try relaunch.queueCount(), 1)

        relaunch.availability.setRemoteEnabled(false)
        relaunch.service.handleAvailabilityChanged()
        XCTAssertEqual(try relaunch.queueCount(), 0)
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
