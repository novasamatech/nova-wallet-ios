import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class AnalyticsConsentGateTests: XCTestCase {
    private func fireFiftyEvents(_ service: AnalyticsService) {
        for index in 0 ..< 50 {
            service.track(.featureOpened(index.isMultiple(of: 2) ? .staking : .governance))
        }
    }

    private func assertNothingRecorded(
        _ fixture: AnalyticsTestFixture,
        _ message: String,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(try fixture.queueCount(), 0, message, line: line)
        XCTAssertNil(fixture.persistedInstallId(), message, line: line)
        verify(fixture.uploader, never()).flushWrapper(maxBatches: any())
    }

    func testNothingPersistedOrSentBeforeConsent() throws {
        let fixture = AnalyticsTestFixture.make()

        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)
        fixture.service.flush(reason: .background)

        try assertNothingRecorded(fixture, "recorded something before opt-in")
    }

    func testNothingPersistedOrSentAfterOptOut() throws {
        let fixture = AnalyticsTestFixture.make()

        fixture.consent.setEnabled(true)
        fireFiftyEvents(fixture.service)
        fixture.consent.setEnabled(false)

        // The wipe must have emptied the queue and deleted the id, and 50 more
        // events must land nowhere.
        clearInvocations(fixture.uploader)
        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)
        fixture.service.flush(reason: .background)

        try assertNothingRecorded(fixture, "recorded something after opt-out")
    }

    func testNothingRecordedWhenUnavailableEvenWithConsent() throws {
        let fixture = AnalyticsTestFixture.make(isAvailable: false)

        fixture.consent.setEnabled(true)
        fireFiftyEvents(fixture.service)
        fixture.service.flush(reason: .launch)

        try assertNothingRecorded(fixture, "recorded something on an unavailable build")
    }

    func testEventsAreRecordedOnceConsented() throws {
        let fixture = AnalyticsTestFixture.make()

        fixture.consent.setEnabled(true)
        fixture.service.track(.featureOpened(.staking))

        XCTAssertEqual(try fixture.queueCount(), 1)
    }
}
