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

    func testOptOutCancelsTheFlushCallStoreAndWipesTheQueue() throws {
        // Scope: the call-store plumbing only. The stub returns a single flat operation, so
        // this cannot show that a real in-flight upload is abandoned — against the production
        // uploader the inner wrappers keep running, because
        // `OperationCombiningService.cancel()` is a no-op (it never sets `.running` and never
        // retains its wrappers). Spec 6.5 step 2 is therefore NOT covered by this test. What
        // makes opt-out safe today is the identity latch, covered in AnalyticsIdentityTests
        // and BackendAttestationProviderTests.
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

    func testCancelFlushReleasesTheSingleFlightSlot() throws {
        // The facade's throttle() is symmetric (spec §3.2): it must abandon the in-flight
        // flush, not just detach the handler, or the call store stays occupied for the
        // rest of the process and every later flush is silently swallowed.
        let fixture = AnalyticsTestFixture.makeConsented()

        let firstStarted = XCTestExpectation(description: "first flush started")
        let secondStarted = XCTestExpectation(description: "second flush started")

        var wrappers: [CompoundOperationWrapper<Void>] = []

        stub(fixture.uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).then { _ in
                let expectation = wrappers.isEmpty ? firstStarted : secondStarted
                let wrapper = CompoundOperationWrapper(
                    targetOperation: AsyncClosureOperation<Void> { _ in expectation.fulfill() }
                )

                wrappers.append(wrapper)

                return wrapper
            }
        }

        fixture.service.flush(reason: .manual)
        wait(for: [firstStarted], timeout: 5)

        // Single flight: the second call finds the store occupied and never reaches the
        // uploader, so the store has to be released explicitly.
        fixture.service.flush(reason: .manual)
        XCTAssertEqual(wrappers.count, 1)

        fixture.service.cancelFlush()
        XCTAssertTrue(wrappers[0].targetOperation.isCancelled)

        fixture.service.flush(reason: .manual)
        wait(for: [secondStarted], timeout: 5)
        XCTAssertEqual(wrappers.count, 2)
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
