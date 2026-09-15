import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsUploaderTests: XCTestCase {
    private let queue = AnalyticsEventQueueStub()
    private let attestation = BackendAttestationProviderSpy()
    private let uploadFactory = AnalyticsUploadOperationFactorySpy()

    private func flush(maxBatches: Int = 10) throws {
        let uploader = AnalyticsUploader(
            queue: queue,
            identity: AnalyticsIdentityStub(),
            attestation: attestation,
            uploadFactory: uploadFactory,
            operationQueue: OperationQueue(),
            appVersion: "10.9.0",
            logger: SilentLogger()
        )
        let wrapper = uploader.flushWrapper(maxBatches: maxBatches)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func seed(count: Int) {
        queue.events = (0 ..< count).map { index in
            AnalyticsPendingEvent(
                identifier: "row-\(index)",
                eventId: UUID().uuidString.lowercased(),
                sequence: Int64(index),
                name: "nova_card_opened",
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                payload: Data("{}".utf8),
                consentEpoch: 0
            )
        }
    }

    func testSendsSignedBody() throws {
        seed(count: 1)

        try flush()

        XCTAssertEqual(attestation.signedBodies.count, 1)
        XCTAssertEqual(attestation.signedBodies, uploadFactory.sentBodies)
    }

    func testSuccessfulUploadDropsBatch() throws {
        seed(count: 2)
        let identifiers = queue.events.map(\.identifier)

        try flush()

        XCTAssertEqual(queue.droppedIds, identifiers)
        XCTAssertTrue(queue.events.isEmpty)
    }

    func testRespectsBatchLimit() throws {
        seed(count: 60)

        try flush(maxBatches: 1)

        XCTAssertEqual(queue.events.count, 10)
        XCTAssertEqual(uploadFactory.sentBodies.count, 1)
    }

    func testRejectedUploadRetainsBatch() {
        seed(count: 1)
        let events = queue.events
        uploadFactory.uploadResult = .failure(AnalyticsTransportError.rejected(statusCode: 403))

        XCTAssertThrowsError(try flush()) { error in
            XCTAssertEqual(error as? AnalyticsTransportError, .rejected(statusCode: 403))
        }

        XCTAssertEqual(queue.events, events)
        XCTAssertEqual(attestation.markedUnattestedClientIds, ["cid"])
    }
}
