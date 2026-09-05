import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS
import NovaAppAttest

final class AnalyticsConsentGateTests: XCTestCase {
    private func makeDeviceCheck() -> DeviceCheckAttestingSpy {
        DeviceCheckAttestingSpy()
    }

    private func fireFiftyEvents(_ service: AnalyticsService) {
        for index in 0 ..< 50 {
            service.track(.featureOpened(index.isMultiple(of: 2) ? .staking : .governance))
        }
    }

    private func assertNothingRecorded(
        _ fixture: AnalyticsTestFixture,
        _ device: DeviceCheckAttestingSpy,
        _ message: String,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try fixture.queueCount(), 0, message, line: line)
        XCTAssertNil(fixture.persistedInstallId(), message, line: line)
        XCTAssertEqual(fixture.uploader.flushCallCount, 0, message, line: line)

        // No cryptographic key either: nothing exists before the user opts in.
        XCTAssertEqual(device.generateKeyCallCount, 0, message, line: line)
    }

    func testNothingPersistedOrSentBeforeConsent() throws {
        let device = makeDeviceCheck()
        let fixture = AnalyticsTestFixture.make(deviceCheck: device)

        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)
        fixture.service.flush(reason: .background)
        fixture.drainUploads()

        try assertNothingRecorded(fixture, device, "recorded something before opt-in")
    }

    func testNothingPersistedOrSentAfterOptOut() throws {
        let device = makeDeviceCheck()
        let fixture = AnalyticsTestFixture.make(deviceCheck: device)

        fixture.consent.setEnabled(true)
        fireFiftyEvents(fixture.service)
        fixture.drain()
        fixture.drainUploads()
        fixture.consent.setEnabled(false)

        // The wipe must have emptied the queue, deleted the id and dropped the gateway
        // client, and 50 more events must land nowhere.
        XCTAssertNil(
            fixture.settings.string(for: "gatewayAttestationClientId"),
            "opt-out kept the gateway client id"
        )

        fixture.uploader.reset()
        device.reset()
        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)
        fixture.service.flush(reason: .background)
        fixture.drainUploads()

        try assertNothingRecorded(fixture, device, "recorded something after opt-out")
    }

    func testNothingRecordedWhenUnavailableEvenWithConsent() throws {
        let device = makeDeviceCheck()
        let fixture = AnalyticsTestFixture.make(isAvailable: false, deviceCheck: device)

        fixture.consent.setEnabled(true)
        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)
        fixture.drainUploads()

        try assertNothingRecorded(fixture, device, "recorded something on an unavailable build")
    }

    func testEventsAreRecordedOnceConsented() throws {
        let fixture = AnalyticsTestFixture.make()

        fixture.consent.setEnabled(true)
        fixture.service.track(.featureOpened(.staking))

        XCTAssertEqual(try fixture.queueCount(), 1)
    }

    func testConsentedFlushReachesDeviceCheck() throws {
        // The positive control for every `generateKey` never-called assertion above: the
        // path from a consented flush to DeviceCheck is real, so those are not vacuous.
        let device = makeDeviceCheck()
        let fixture = AnalyticsTestFixture.make(deviceCheck: device)

        fixture.consent.setEnabled(true)
        fixture.service.track(.featureOpened(.staking))
        fixture.drain()
        fixture.drainUploads()

        XCTAssertGreaterThan(device.generateKeyCallCount, 0)
    }
}
