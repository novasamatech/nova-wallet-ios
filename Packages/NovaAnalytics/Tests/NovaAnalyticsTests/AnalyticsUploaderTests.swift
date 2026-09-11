import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS
import NovaAppAttest

final class AnalyticsUploaderTests: XCTestCase {
    private struct Fixture {
        let uploader: AnalyticsUploader
        let queue: CoreDataAnalyticsEventQueue
        let attestation: BackendAttestationProviderSpy
        let uploadFactory: AnalyticsUploadOperationFactorySpy
        let identity: AnalyticsIdentity
    }

    private func makeFixture(
        uploadResults: [Result<Void, Error>],
        timeProvider: @escaping () -> Date = { Date(timeIntervalSince1970: 1_772_445_600) }
    ) -> Fixture {
        let queue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(AnalyticsStorageTestFacade().createEventRepository()),
            maxCount: 500
        )

        let identity = AnalyticsIdentity(settingsManager: InMemorySettingsManager())
        let attestation = BackendAttestationProviderSpy()
        let uploadFactory = AnalyticsUploadOperationFactorySpy()
        uploadFactory.uploadResults = uploadResults

        let uploader = AnalyticsUploader(
            queue: queue,
            identity: identity,
            attestation: attestation,
            uploadFactory: uploadFactory,
            operationQueue: OperationQueue(),
            appVersion: "10.9.0",
            timeProvider: timeProvider,
            logger: SilentLogger()
        )

        return Fixture(
            uploader: uploader,
            queue: queue,
            attestation: attestation,
            uploadFactory: uploadFactory,
            identity: identity
        )
    }

    private func flush(_ fixture: Fixture, maxBatches: Int = 10) -> Error? {
        let wrapper = fixture.uploader.flushWrapper(maxBatches: maxBatches)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        do {
            try wrapper.targetOperation.extractNoCancellableResultData()

            return nil
        } catch {
            return error
        }
    }

    private func seed(_ fixture: Fixture, count: Int) throws {
        for index in 0 ..< count {
            try enqueue(fixture, timestamp: Date(timeIntervalSince1970: TimeInterval(index)), payload: "{}")
        }
    }

    private func enqueue(_ fixture: Fixture, timestamp: Date, payload: String) throws {
        let wrapper = fixture.queue.enqueueWrapper(
            name: "nova_card_opened",
            timestamp: timestamp,
            payload: Data(payload.utf8),
            consentEpoch: fixture.identity.consentEpoch
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        _ = try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func queueCount(_ fixture: Fixture) throws -> Int {
        let operation = fixture.queue.countOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    private func queuedIdentifiers(_ fixture: Fixture) throws -> [String] {
        let wrapper = fixture.queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map(\.identifier)
    }

    private func sentEventIds(_ fixture: Fixture) throws -> [String] {
        struct SentEnvelope: Decodable {
            let events: [AnalyticsEventRemote]
        }

        let body = try XCTUnwrap(fixture.uploadFactory.sentBodies.first)

        return try JSONDecoder().decode(SentEnvelope.self, from: body).events.map(\.id)
    }

    private func sentJSON(_ fixture: Fixture) throws -> String {
        try XCTUnwrap(String(data: try XCTUnwrap(fixture.uploadFactory.sentBodies.first), encoding: .utf8))
    }

    func testSignedBytesAreTheSentBytes() throws {
        var tick: TimeInterval = 0
        let fixture = makeFixture(uploadResults: [.success(())], timeProvider: {
            tick += 1
            return Date(timeIntervalSince1970: 1_772_445_600 + tick)
        })
        try seed(fixture, count: 1)

        XCTAssertNil(flush(fixture))

        XCTAssertEqual(fixture.attestation.signedBodies.count, 1)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
        XCTAssertEqual(fixture.attestation.signedBodies, fixture.uploadFactory.sentBodies)
    }

    func testSuccessfulBatchDropsExactlyThePeekedRows() throws {
        let fixture = makeFixture(uploadResults: [.success(()), .success(())])
        try seed(fixture, count: 60)

        XCTAssertNil(flush(fixture))

        XCTAssertEqual(try queueCount(fixture), 0)
    }

    func testMaxBatchesCapsTheLoop() throws {
        let fixture = makeFixture(uploadResults: Array(repeating: .success(()), count: 10))
        try seed(fixture, count: 150)

        XCTAssertNil(flush(fixture, maxBatches: 1))

        XCTAssertEqual(try queueCount(fixture), 100)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testRejectionRetainsTheBatchMarksUnattestedOnceAndSurfacesTheFailure() throws {
        let fixture = makeFixture(uploadResults: [.failure(AnalyticsTransportError.rejected(statusCode: 403))])
        try seed(fixture, count: 60)
        let identifiers = try queuedIdentifiers(fixture)

        let error = flush(fixture)

        XCTAssertEqual(error as? AnalyticsTransportError, .rejected(statusCode: 403))
        XCTAssertEqual(try queueCount(fixture), 60)
        XCTAssertEqual(try queuedIdentifiers(fixture), identifiers)
        XCTAssertEqual(fixture.attestation.markUnattestedCallCount, 1)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testServerErrorKeepsEverythingAndSurfacesTheFailure() throws {
        let fixture = makeFixture(uploadResults: [.failure(AnalyticsTransportError.serverError(statusCode: 500))])
        try seed(fixture, count: 60)

        let error = flush(fixture)

        XCTAssertEqual(error as? AnalyticsTransportError, .serverError(statusCode: 500))
        XCTAssertEqual(try queueCount(fixture), 60)
        XCTAssertEqual(fixture.attestation.markUnattestedCallCount, 0)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testRetryLaterKeepsEverythingAndSurfacesTheFailure() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 120))]
        )
        try seed(fixture, count: 60)

        let error = flush(fixture)

        XCTAssertEqual(error as? AnalyticsTransportError, .retryLater(statusCode: 429, retryAfter: 120))
        XCTAssertEqual(try queueCount(fixture), 60)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testEnvelopeCarriesTheInstallAndSessionIds() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        XCTAssertNil(flush(fixture))

        let json = try sentJSON(fixture)

        XCTAssertTrue(json.contains(#""platform":"ios""#))
        XCTAssertTrue(json.contains(#""v":1"#))
        XCTAssertTrue(json.contains(try XCTUnwrap(fixture.identity.existingInstallId())))
        XCTAssertTrue(json.contains(fixture.identity.sessionId))
    }

    func testTheWireIdIsTheStoredRowIdentifier() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)
        let identifier = try XCTUnwrap(queuedIdentifiers(fixture).first)

        XCTAssertNil(flush(fixture))

        XCTAssertTrue(try sentJSON(fixture).contains(#""id":"\#(identifier)""#))
    }

    func testRowsFromAnEarlierConsentEpochAreDroppedWithoutBeingSent() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 2)

        fixture.identity.forgetInstallId()
        fixture.identity.allowCreation()
        try seed(fixture, count: 1)
        let freshId = try XCTUnwrap(queuedIdentifiers(fixture).last)

        XCTAssertNil(flush(fixture))

        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
        XCTAssertEqual(try sentEventIds(fixture), [freshId])
        XCTAssertEqual(try queueCount(fixture), 0)
    }

    func testTamperedRowTextNeverReachesTheTransport() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try enqueue(fixture, timestamp: Date(timeIntervalSince1970: 0), payload: #"{"asset":"alice's savings wallet!"}"#)
        try seed(fixture, count: 1)

        XCTAssertNil(flush(fixture))

        XCTAssertEqual(fixture.uploadFactory.sentBodies.count, 1)
        XCTAssertFalse(try sentJSON(fixture).contains("savings"))
        XCTAssertEqual(try sentEventIds(fixture).count, 1)
        XCTAssertEqual(try queueCount(fixture), 0)
    }
}
