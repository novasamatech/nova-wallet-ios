import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo
import NovaAppAttest

final class AnalyticsConsentGateTests: XCTestCase {
    private func makeDeviceCheck() -> MockDeviceCheckAttesting {
        let device = MockDeviceCheckAttesting()
        stub(device) { stub in
            when(stub.isSupported.get).thenReturn(true)
            when(stub.generateKey(completionHandler: any())).then { completion in
                completion(UUID().uuidString, nil)
            }
            when(stub.attestKey(any(), clientDataHash: any(), completionHandler: any()))
                .then { _, _, completion in completion(Data("attestation".utf8), nil) }
            when(stub.generateAssertion(any(), clientDataHash: any(), completionHandler: any()))
                .then { _, _, completion in completion(Data("assertion".utf8), nil) }
        }
        return device
    }

    private func fireFiftyEvents(_ service: AnalyticsService) {
        for index in 0 ..< 50 {
            service.track(.featureOpened(index.isMultiple(of: 2) ? .staking : .governance))
        }
    }

    private func assertNothingRecorded(
        _ fixture: AnalyticsTestFixture,
        _ device: MockDeviceCheckAttesting,
        _ message: String,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try fixture.queueCount(), 0, message, line: line)
        XCTAssertNil(fixture.persistedInstallId(), message, line: line)
        verify(fixture.uploader, never()).flushWrapper(maxBatches: any())

        // No cryptographic key either: nothing exists before the user opts in.
        verify(device, never()).generateKey(completionHandler: any())
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
        XCTAssertNil(fixture.settings.gatewayAttestationClientId, "opt-out kept the gateway client id")

        clearInvocations(fixture.uploader)
        clearInvocations(device)
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

        verify(device, atLeastOnce()).generateKey(completionHandler: any())
    }
}
