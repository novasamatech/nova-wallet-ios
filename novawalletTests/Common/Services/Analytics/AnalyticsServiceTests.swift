import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class AnalyticsServiceTests: XCTestCase {
    func testFeatureOpenedCollapsesConsecutiveDuplicates() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.featureOpened(.staking))
        fixture.service.track(.featureOpened(.staking))
        fixture.service.track(.featureOpened(.governance))
        fixture.service.track(.featureOpened(.governance))
        fixture.service.track(.featureOpened(.staking))

        XCTAssertEqual(try fixture.peekNames().count, 3)
    }

    func testUntrackedEventsDoNotResetTheCurrentFeature() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.featureOpened(.staking))
        fixture.service.track(.novaCardOpened())
        fixture.service.track(.featureOpened(.staking))

        // Returning from a detail screen must not re-fire feature_opened.
        XCTAssertEqual(try fixture.peekNames(), ["feature_opened", "nova_card_opened"])
    }

    func testFirstConsentedEventOfAProcessFlushes() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        verify(fixture.uploader, atLeastOnce()).flushWrapper(maxBatches: equal(to: 10))
    }

    func testThresholdFlushAtFiftyEvents() throws {
        let fixture = AnalyticsTestFixture.makeConsented(now: { Date(timeIntervalSince1970: 0) })

        fixture.service.track(.novaCardOpened()) // consumes the distantPast flush
        fixture.drain()
        clearInvocations(fixture.uploader)

        fixture.track(48, .novaCardOpened())
        fixture.drain()
        verify(fixture.uploader, never()).flushWrapper(maxBatches: any())

        fixture.service.track(.novaCardOpened())
        fixture.drain()
        verify(fixture.uploader, times(1)).flushWrapper(maxBatches: equal(to: 10))
    }

    func testIntervalFlushAfterFiveMinutes() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = AnalyticsTestFixture.makeConsented(now: { now })

        fixture.service.track(.novaCardOpened())
        fixture.drain()
        clearInvocations(fixture.uploader)

        now = now.addingTimeInterval(299)
        fixture.service.track(.novaCardOpened())
        fixture.drain()
        verify(fixture.uploader, never()).flushWrapper(maxBatches: any())

        now = now.addingTimeInterval(2)
        fixture.service.track(.novaCardOpened())
        fixture.drain()
        verify(fixture.uploader, times(1)).flushWrapper(maxBatches: equal(to: 10))
    }

    func testBackgroundFlushIsCappedAtOneBatch() {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.flush(reason: .background)
        fixture.drain()

        verify(fixture.uploader, atLeastOnce()).flushWrapper(maxBatches: equal(to: 1))
    }

    func testOptOutCancelsAnInFlightFlush() throws {
        // A POST already in the air must be abandoned so its batch is never dropped
        // from a queue that is about to be wiped.
        let fixture = AnalyticsTestFixture.makeConsented()
        let started = XCTestExpectation(description: "flush started")
        let neverFinishes = CompoundOperationWrapper(
            targetOperation: AsyncClosureOperation<Void> { _ in started.fulfill() }
        )

        stub(fixture.uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).thenReturn(neverFinishes)
        }

        fixture.service.flush(reason: .manual)
        wait(for: [started], timeout: 5)

        fixture.consent.setEnabled(false)

        XCTAssertTrue(neverFinishes.targetOperation.isCancelled)
        XCTAssertEqual(try fixture.queueCount(), 0)
    }

    func testEventPersistsWhileUploadInFlight() throws {
        // Persistence and networking are on different queues; a slow POST must not
        // block an enqueue.
        let fixture = AnalyticsTestFixture.makeConsented()
        let uploadStarted = XCTestExpectation(description: "upload started")
        let release = XCTestExpectation(description: "released")

        stub(fixture.uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).then { _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<Void> {
                    uploadStarted.fulfill()
                    _ = XCTWaiter.wait(for: [release], timeout: 5)
                })
            }
        }

        fixture.service.flush(reason: .manual)
        wait(for: [uploadStarted], timeout: 5)

        fixture.service.track(.novaCardOpened())
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        release.fulfill()
        fixture.uploadOperationQueue.waitUntilAllOperationsAreFinished()
    }
}
