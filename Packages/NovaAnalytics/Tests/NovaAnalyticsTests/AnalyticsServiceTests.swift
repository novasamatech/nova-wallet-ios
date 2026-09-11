import XCTest
@testable import NovaAnalytics
import Operation_iOS

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

    func testThresholdFlushAtFiftyEvents() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = AnalyticsTestFixture.makeConsented(now: { now })

        fixture.service.track(.novaCardOpened())
        fixture.drain()
        fixture.uploader.reset()

        fixture.track(48, .novaCardOpened())
        fixture.drain()
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(16)
        fixture.service.track(.novaCardOpened())
        fixture.drain()
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testIntervalFlushAfterFiveMinutes() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = AnalyticsTestFixture.makeConsented(now: { now })

        fixture.service.track(.novaCardOpened())
        fixture.drain()
        fixture.uploader.reset()

        now = now.addingTimeInterval(299)
        fixture.service.track(.novaCardOpened())
        fixture.drain()
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
        fixture.service.track(.novaCardOpened())
        fixture.drain()
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testBackgroundFlushIsCappedAtOneBatch() {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.flush(reason: .background)
        fixture.drain()

        XCTAssertTrue(fixture.uploader.maxBatchesCalls.contains(1))
    }

    func testOptOutCancelsTheFlushCallStoreAndWipesTheQueue() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let started = XCTestExpectation(description: "flush started")
        let neverFinishes = CompoundOperationWrapper(
            targetOperation: AsyncClosureOperation<Void> { _ in started.fulfill() }
        )

        fixture.uploader.flushStub = { _ in neverFinishes }

        fixture.service.flush(reason: .manual)
        wait(for: [started], timeout: 5)

        fixture.consent.setEnabled(false)

        XCTAssertTrue(neverFinishes.targetOperation.isCancelled)
        XCTAssertEqual(try fixture.queueCount(), 0)
    }

    func testAFailedFlushHoldsOffTheNextIntervalFlushForAMinute() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = AnalyticsTestFixture.makeConsented(now: { now })
        fixture.uploader.flushStub = { _ in .createWithError(AnalyticsTransportError.serverError(statusCode: 500)) }

        let settled = expectation(description: "flush settled")
        fixture.service.flush(reason: .manual) { settled.fulfill() }
        wait(for: [settled], timeout: 5)
        fixture.uploader.reset()

        now = now.addingTimeInterval(59)
        fixture.service.flush(reason: .interval)
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
        fixture.service.flush(reason: .interval)
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }
}
