import XCTest
@testable import novawallet
import Operation_iOS
import Keystore_iOS
import Cuckoo

final class AnalyticsUploaderTests: XCTestCase {
    /// Counts the batches whose body the transport actually obtained. A consent gate that
    /// throws inside `bodyClosure` leaves this at zero even though the upload *operation*
    /// was constructed, which is the distinction the abort path turns on.
    private final class BodyRecorder {
        private let mutex = NSLock()
        private var bodies: [Data] = []

        func record(_ body: Data) {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            bodies.append(body)
        }

        var recorded: [Data] {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            return bodies
        }
    }

    private struct Fixture {
        let uploader: AnalyticsUploader
        let queue: CoreDataAnalyticsEventQueue
        let attestation: MockBackendAttestationProviderProtocol
        let uploadFactory: MockAnalyticsUploadOperationFactoryProtocol
        let settings: InMemorySettingsManager
        let identity: AnalyticsIdentity
        let sentBodies: BodyRecorder
    }

    /// `uploadResults` are consumed one per batch, so a test can script a 2xx then a 500.
    /// Real queue over UserDataStorageTestFacade, real InMemorySettingsManager and
    /// AnalyticsIdentity; only the attestation provider and the upload factory are mocked.
    private func makeFixture(
        uploadResults: [Result<Void, Error>],
        optOutDuringAttestation: Bool = false,
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
            maxCount: 500
        )

        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)
        let sentBodies = BodyRecorder()

        let attestation = MockBackendAttestationProviderProtocol()
        stub(attestation) { stub in
            when(stub.createSignedHeadersWrapper(bodyClosure: any())).then { bodyClosure in
                // A fresh wrapper per call: one instance cannot run twice.
                CompoundOperationWrapper(
                    targetOperation: ClosureOperation<[AttestationHeaderKey: String]?> {
                        if optOutDuringAttestation {
                            // Stands in for the gateway challenge POST: the user opens
                            // Settings while the request is on the wire.
                            identity.forgetInstallId()
                        }

                        _ = try bodyClosure()

                        return [.clientId: "cid", .challenge: "chal", .signature: "sig"]
                    }
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
                    // Forces the body closure, so a consent gate inside it is exercised
                    // exactly as `NetworkOperation.main()` would exercise it.
                    sentBodies.record(try body())
                    try next.get()
                }
            }
        }

        let uploader = AnalyticsUploader(
            queue: queue,
            identity: identity,
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
            settings: settings,
            identity: identity,
            sentBodies: sentBodies
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

    func testOptOutBeforeTheBatchIsBuiltSendsNothingAndMintsNothing() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        fixture.identity.forgetInstallId()

        try flush(fixture)

        XCTAssertTrue(fixture.sentBodies.recorded.isEmpty)
        XCTAssertNil(
            fixture.settings.analyticsInstallId,
            "the abort path minted a replacement install id"
        )
        verify(fixture.uploadFactory, never()).createUploadOperation(
            bodyClosure: any(),
            headersClosure: any()
        )
    }

    /// The envelope — install id, session id and every queued event — is built *before* the
    /// attestation round trip, which takes up to a minute on a stalled connection. Nothing
    /// downstream can cancel a chain that is already executing, so the last gate before the
    /// request is the only thing standing between an opt-out and a real POST.
    func testOptOutDuringTheAttestationRoundTripNeverPostsTheBatch() throws {
        let fixture = makeFixture(
            uploadResults: [.success(())],
            optOutDuringAttestation: true
        )
        try seed(fixture, count: 1)

        try flush(fixture)

        XCTAssertTrue(
            fixture.sentBodies.recorded.isEmpty,
            "a batch reached the transport after the user opted out mid-flight"
        )
    }

    func testABatchAbortedByAnOptOutIsNotTreatedAsDelivered() throws {
        let fixture = makeFixture(
            uploadResults: [.success(())],
            optOutDuringAttestation: true
        )
        try seed(fixture, count: 3)

        try flush(fixture)

        // Dropping them here would be indistinguishable from a 2xx. The rows are the
        // service's to wipe, and it wipes them for a different reason.
        XCTAssertEqual(try queueCount(fixture), 3)
    }

    func testReconsentDuringAnInFlightBatchStillAbortsIt() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        // A pure "is there an id?" check would pass here: re-consent re-arms minting, so
        // the accessor happily produces a *new* id while the batch still carries the old.
        stub(fixture.attestation) { stub in
            when(stub.createSignedHeadersWrapper(bodyClosure: any())).then { bodyClosure in
                CompoundOperationWrapper(
                    targetOperation: ClosureOperation<[AttestationHeaderKey: String]?> {
                        fixture.identity.forgetInstallId()
                        fixture.identity.allowCreation()

                        _ = try bodyClosure()

                        return [.clientId: "cid", .challenge: "chal", .signature: "sig"]
                    }
                )
            }
        }

        try flush(fixture)

        XCTAssertTrue(
            fixture.sentBodies.recorded.isEmpty,
            "a batch built for the previous consent cycle was sent under the new identity"
        )
    }
}
