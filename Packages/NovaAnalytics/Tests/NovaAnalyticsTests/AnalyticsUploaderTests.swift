import XCTest
@testable import NovaAnalytics
import NovaAuth
import Operation_iOS

final class AnalyticsUploaderTests: XCTestCase {
    private let queue = AnalyticsEventQueueStub()
    private let uploadFactory = AnalyticsUploadOperationFactorySpy()

    private func flush(
        maxBatches: Int = 10,
        factory: AnalyticsUploadOperationFactoryProtocol? = nil,
        isConsentEnabled: @escaping () -> Bool = { true }
    ) throws {
        let uploader = AnalyticsUploader(
            queue: queue,
            identity: AnalyticsIdentityStub(),
            isConsentEnabled: isConsentEnabled,
            gatewayResolver: AnalyticsGatewayResolverStub(uploadFactory: factory ?? uploadFactory),
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

    func testSendsOneImmutableBody() throws {
        seed(count: 1)

        try flush()

        XCTAssertEqual(uploadFactory.sentBodies.count, 1)
        XCTAssertFalse(uploadFactory.sentBodies[0].isEmpty)
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
    }

    func testConsentWithdrawalBeforeSendRetainsBatchWithoutSending() throws {
        seed(count: 1)
        let events = queue.events
        let enabled = Locked(true)
        uploadFactory.onBeforeSend = { enabled.update { $0 = false } }
        try flush(isConsentEnabled: { enabled.value })
        XCTAssertTrue(uploadFactory.sentBodies.isEmpty)
        XCTAssertEqual(queue.events, events)
    }

    func testStructuredPayloadRejectionDropsBadBatchAndDrainsFollowingBatch() throws {
        for code in ["invalid_envelope", "unsupported_schema_version", "batch_too_large"] {
            seed(count: 51)
            let client = AnalyticsAuthClientSpy()
            client.onBeforeSend = {
                client.responseStatus = client.requests.isEmpty ? 400 : 204
                client.responseBody = Data(#"{"error":{"code":"\#(code)","message":"rejected"}}"#.utf8)
            }
            let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))

            try flush(factory: factory)

            XCTAssertEqual(client.requests.count, 2)
            XCTAssertTrue(queue.events.isEmpty)
        }
    }

    func testStructuredAuthAndTransientRejectionsRetainBatch() throws {
        for (status, code) in [(400, "invalid_target"), (401, "invalid_token"), (429, "rate_limited")] {
            seed(count: 51)
            let events = queue.events
            let client = AnalyticsAuthClientSpy()
            client.responseStatus = status
            client.responseBody = Data(#"{"error":{"code":"\#(code)"}}"#.utf8)
            let factory = AnalyticsUploadOperationFactory(auth: analyticsTestAuth(client))

            XCTAssertThrowsError(try flush(factory: factory))

            XCTAssertEqual(client.requests.count, 1)
            XCTAssertEqual(queue.events, events)
        }
    }
}
