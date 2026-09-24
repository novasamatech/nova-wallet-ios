import XCTest
@testable import NovaAnalytics

final class AnalyticsServiceTests: XCTestCase {
    private let queue = AnalyticsEventQueueStub()
    private let uploader = AnalyticsUploadingSpy()
    private let operationQueue = OperationQueue()

    private func makeService(isEnabled: Bool = true) -> AnalyticsService {
        AnalyticsService(
            consent: AnalyticsConsentStub(isEnabled: isEnabled),
            availability: AnalyticsAvailabilityStub(),
            queue: queue,
            identity: AnalyticsIdentityStub(),
            uploader: uploader,
            operationQueue: operationQueue,
            uploadOperationQueue: OperationQueue(),
            logger: SilentLogger()
        )
    }

    func testDeduplicatesConsecutiveFeatures() {
        let service = makeService()

        service.track(.featureOpened(.staking))
        service.track(.featureOpened(.staking))
        service.track(.featureOpened(.governance))
        service.track(.featureOpened(.staking))
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(queue.events.count, 3)
    }

    func testDisabledConsentSkipsTracking() {
        let service = makeService(isEnabled: false)

        service.track(.novaCardOpened())
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertTrue(queue.events.isEmpty)
        XCTAssertTrue(uploader.maxBatchesCalls.isEmpty)
    }

    func testBackgroundFlushUsesOneBatch() {
        let service = makeService()
        let completion = expectation(description: "flush completed")

        service.flush(reason: .background) { completion.fulfill() }
        wait(for: [completion], timeout: 5)

        XCTAssertEqual(uploader.maxBatchesCalls, [1])
    }
}
