import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class AnalyticsUploaderTests: XCTestCase {
    private struct Fixture {
        let uploader: AnalyticsUploader
        let queue: CoreDataAnalyticsEventQueue
        let attestation: MockBackendAttestationProviderProtocol
        let uploadFactory: MockAnalyticsUploadOperationFactoryProtocol
        let settings: InMemorySettingsManager
    }

    /// `uploadResults` are consumed one per batch, so a test can script a 2xx then a 500.
    /// Real queue over UserDataStorageTestFacade, real InMemorySettingsManager and
    /// AnalyticsIdentity; only the attestation provider and the upload factory are mocked.
    private func makeFixture(
        uploadResults: [Result<Void, Error>],
        timeProvider: @escaping () -> Date = { Date(timeIntervalSince1970: 1_772_445_600) }
    ) -> Fixture {
        let facade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AnalyticsPendingEvent, CDAnalyticsEvent> =
            facade.createRepository(
                filter: nil,
                sortDescriptors: [.analyticsEventsBySequence],
                mapper: AnyCoreDataMapper(AnalyticsPendingEventMapper())
            )

        let queue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            maxCount: 500
        )

        let attestation = MockBackendAttestationProviderProtocol()
        stub(attestation) { stub in
            when(stub.createSignedHeadersWrapper(bodyClosure: any())).then { _ in
                // A fresh wrapper per call: one instance cannot run twice.
                CompoundOperationWrapper.createWithResult(
                    [.clientId: "cid", .challenge: "chal", .signature: "sig"]
                )
            }
            when(stub.markUnattested()).thenDoNothing()
            when(stub.forgetClient()).thenDoNothing()
        }

        var remaining = uploadResults
        let uploadFactory = MockAnalyticsUploadOperationFactoryProtocol()
        stub(uploadFactory) { stub in
            when(stub.createUploadOperation(bodyClosure: any(), headersClosure: any())).then { body, _ in
                let next = remaining.isEmpty ? Result<Void, Error>.success(()) : remaining.removeFirst()

                return ClosureOperation<Void> {
                    _ = try body() // force the body closure so captors see it
                    try next.get()
                }
            }
        }

        let settings = InMemorySettingsManager()

        let uploader = AnalyticsUploader(
            queue: queue,
            identity: AnalyticsIdentity(settingsManager: settings),
            attestation: attestation,
            uploadFactory: uploadFactory,
            operationQueue: OperationQueue(),
            appVersion: "10.9.0",
            timeProvider: timeProvider,
            logger: Logger.shared
        )

        return Fixture(
            uploader: uploader,
            queue: queue,
            attestation: attestation,
            uploadFactory: uploadFactory,
            settings: settings
        )
    }

    private func flush(_ fixture: Fixture, maxBatches: Int = 10) throws {
        let wrapper = fixture.uploader.flushWrapper(maxBatches: maxBatches)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        _ = try? wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func seed(_ fixture: Fixture, count: Int) throws {
        for index in 0 ..< count {
            try enqueue(
                fixture,
                timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                payload: Data("{}".utf8)
            )
        }
    }

    /// A payload the uploader cannot decode into properties. The row itself is perfectly
    /// well-formed storage, which is exactly why it would wedge the queue forever.
    private func seedCorruptRow(_ fixture: Fixture) throws {
        try enqueue(
            fixture,
            timestamp: Date(timeIntervalSince1970: 0),
            payload: Data("not-json".utf8)
        )
    }

    private func enqueue(_ fixture: Fixture, timestamp: Date, payload: Data) throws {
        let wrapper = fixture.queue.enqueueWrapper(
            name: "nova_card_opened",
            timestamp: timestamp,
            payload: payload
        )
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        _ = try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func queueCount(_ fixture: Fixture) throws -> Int {
        let operation = fixture.queue.countOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }

    func testSignedBytesAreTheSentBytes() throws {
        // The failure this catches — a re-encode inside the request closure racing the
        // signature against JSONEncoder's key order — breaks every request in
        // production and is invisible in review. The clock advances on every read, so
        // any second encode of the envelope produces a different `sent_at`.
        var tick: TimeInterval = 0
        let fixture = makeFixture(uploadResults: [.success(())], timeProvider: {
            tick += 1
            return Date(timeIntervalSince1970: 1_772_445_600 + tick)
        })
        try seed(fixture, count: 1)
        try flush(fixture)

        let signedCaptor = ArgumentCaptor<() throws -> Data>()
        verify(fixture.attestation).createSignedHeadersWrapper(bodyClosure: signedCaptor.capture())

        let sentCaptor = ArgumentCaptor<() throws -> Data>()
        verify(fixture.uploadFactory).createUploadOperation(
            bodyClosure: sentCaptor.capture(),
            headersClosure: any()
        )

        let signedBytes = try XCTUnwrap(signedCaptor.value)()
        let sentBytes = try XCTUnwrap(sentCaptor.value)()

        XCTAssertEqual(signedBytes, sentBytes)
    }

    func testSuccessfulBatchDropsExactlyThePeekedRows() throws {
        let fixture = makeFixture(uploadResults: [.success(()), .success(())])
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
    }

    func testMaxBatchesCapsTheLoop() throws {
        let fixture = makeFixture(uploadResults: Array(repeating: .success(()), count: 10))
        try seed(fixture, count: 150)

        try flush(fixture, maxBatches: 1)

        // One batch of 50 uploaded, 100 rows remain for the next flush.
        XCTAssertEqual(try queueCount(fixture), 100)
        verify(fixture.uploadFactory, times(1)).createUploadOperation(
            bodyClosure: any(),
            headersClosure: any()
        )
    }

    func testRejectionClearsTheQueueAndMarksUnattested() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(AnalyticsTransportError.rejected(statusCode: 403))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
        verify(fixture.attestation, times(1)).markUnattested()
    }

    func testServerErrorKeepsEverythingAndStops() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(AnalyticsTransportError.serverError(statusCode: 500))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 60)
        verify(fixture.attestation, never()).markUnattested()
        verify(fixture.uploadFactory, times(1)).createUploadOperation(
            bodyClosure: any(),
            headersClosure: any()
        )
    }

    func testAttestationRejectionClearsTheQueueWithoutReattesting() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(BackendAttestationError.rejected(statusCode: 403))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        // A register rejection is permanent for the process: nothing to re-attest.
        XCTAssertEqual(try queueCount(fixture), 0)
        verify(fixture.attestation, never()).markUnattested()
    }

    func testClientErrorDropsOnlyThatBatchAndContinues() throws {
        let fixture = makeFixture(uploadResults: [
            .failure(AnalyticsTransportError.clientError(statusCode: 422)),
            .success(())
        ])
        try seed(fixture, count: 60)

        try flush(fixture)

        // The poisoned batch is discarded, the rest still goes.
        XCTAssertEqual(try queueCount(fixture), 0)
        verify(fixture.uploadFactory, times(2)).createUploadOperation(
            bodyClosure: any(),
            headersClosure: any()
        )
    }

    func testEmptyQueueUploadsNothing() throws {
        let fixture = makeFixture(uploadResults: [.success(())])

        try flush(fixture)

        verify(fixture.uploadFactory, never()).createUploadOperation(
            bodyClosure: any(),
            headersClosure: any()
        )
        verify(fixture.attestation, never()).createSignedHeadersWrapper(bodyClosure: any())
    }

    func testEnvelopeCarriesTheInstallAndSessionIds() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        try flush(fixture)

        let captor = ArgumentCaptor<() throws -> Data>()
        verify(fixture.uploadFactory).createUploadOperation(
            bodyClosure: captor.capture(),
            headersClosure: any()
        )
        let json = String(data: try XCTUnwrap(captor.value)(), encoding: .utf8)!

        XCTAssertTrue(json.contains(#""platform":"ios""#))
        XCTAssertTrue(json.contains(#""v":1"#))
        XCTAssertTrue(json.contains(fixture.settings.analyticsInstallId!))
    }

    func testInstallIdIsMintedOnlyAtTheFirstFlush() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        XCTAssertNil(fixture.settings.analyticsInstallId)

        try seed(fixture, count: 1)
        XCTAssertNil(fixture.settings.analyticsInstallId, "enqueue must not mint an identity")

        try flush(fixture)
        XCTAssertNotNil(fixture.settings.analyticsInstallId)
    }

    func testPoisonRowIsDroppedRatherThanWedgingTheQueue() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seedCorruptRow(fixture)
        try seed(fixture, count: 1)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
    }
}
