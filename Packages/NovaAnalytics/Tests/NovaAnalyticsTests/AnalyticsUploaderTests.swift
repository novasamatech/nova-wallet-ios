import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS
import NovaAppAttest

final class AnalyticsUploaderTests: XCTestCase {
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
        let attestation: BackendAttestationProviderSpy
        let uploadFactory: AnalyticsUploadOperationFactorySpy
        let settings: InMemorySettingsManager
        let identity: AnalyticsIdentity
        let sentBodies: BodyRecorder
    }

    private func makeFixture(
        uploadResults: [Result<Void, Error>],
        optOutDuringAttestation: Bool = false,
        timeProvider: @escaping () -> Date = { Date(timeIntervalSince1970: 1_772_445_600) }
    ) -> Fixture {
        let facade = AnalyticsStorageTestFacade()

        let queue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(facade.createEventRepository()),
            maxCount: 500
        )

        let settings = InMemorySettingsManager()
        let identity = AnalyticsIdentity(settingsManager: settings)
        let sentBodies = BodyRecorder()

        let attestation = BackendAttestationProviderSpy()

        if optOutDuringAttestation {
            attestation.onSigning = { identity.forgetInstallId() }
        }

        let uploadFactory = AnalyticsUploadOperationFactorySpy()
        uploadFactory.uploadResults = uploadResults
        uploadFactory.onBody = { sentBodies.record($0) }

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
        var tick: TimeInterval = 0
        let fixture = makeFixture(uploadResults: [.success(())], timeProvider: {
            tick += 1
            return Date(timeIntervalSince1970: 1_772_445_600 + tick)
        })
        try seed(fixture, count: 1)
        try flush(fixture)

        XCTAssertEqual(fixture.attestation.signingCallCount, 1)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)

        let signedBytes = try XCTUnwrap(fixture.attestation.signedBodyClosures.last)()
        let sentBytes = try XCTUnwrap(fixture.uploadFactory.bodyClosures.last)()

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

        XCTAssertEqual(try queueCount(fixture), 100)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testRejectionClearsTheQueueAndMarksUnattested() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(AnalyticsTransportError.rejected(statusCode: 403))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
        XCTAssertEqual(fixture.attestation.markUnattestedCallCount, 1)
    }

    func testServerErrorKeepsEverythingAndStops() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(AnalyticsTransportError.serverError(statusCode: 500))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 60)
        XCTAssertEqual(fixture.attestation.markUnattestedCallCount, 0)
        XCTAssertEqual(fixture.uploadFactory.callCount, 1)
    }

    func testAttestationRejectionClearsTheQueueWithoutReattesting() throws {
        let fixture = makeFixture(
            uploadResults: [.failure(BackendAttestationError.rejected(statusCode: 403))]
        )
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
        XCTAssertEqual(fixture.attestation.markUnattestedCallCount, 0)
    }

    func testClientErrorDropsOnlyThatBatchAndContinues() throws {
        let fixture = makeFixture(uploadResults: [
            .failure(AnalyticsTransportError.clientError(statusCode: 422)),
            .success(())
        ])
        try seed(fixture, count: 60)

        try flush(fixture)

        XCTAssertEqual(try queueCount(fixture), 0)
        XCTAssertEqual(fixture.uploadFactory.callCount, 2)
    }

    func testEmptyQueueUploadsNothing() throws {
        let fixture = makeFixture(uploadResults: [.success(())])

        try flush(fixture)

        XCTAssertEqual(fixture.uploadFactory.callCount, 0)
        XCTAssertEqual(fixture.attestation.signingCallCount, 0)
    }

    func testEnvelopeCarriesTheInstallAndSessionIds() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        try flush(fixture)

        XCTAssertEqual(fixture.uploadFactory.callCount, 1)

        let json = String(
            data: try XCTUnwrap(fixture.uploadFactory.bodyClosures.last)(),
            encoding: .utf8
        )!

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
        XCTAssertEqual(fixture.uploadFactory.callCount, 0)
    }

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

        XCTAssertEqual(try queueCount(fixture), 3)
    }

    func testReconsentDuringAnInFlightBatchStillAbortsIt() throws {
        let fixture = makeFixture(uploadResults: [.success(())])
        try seed(fixture, count: 1)

        fixture.attestation.onSigning = {
            fixture.identity.forgetInstallId()
            fixture.identity.allowCreation()
        }

        try flush(fixture)

        XCTAssertTrue(
            fixture.sentBodies.recorded.isEmpty,
            "a batch built for the previous consent cycle was sent under the new identity"
        )
    }
}
