import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS
import NovaOperationSupport

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

        XCTAssertEqual(try fixture.peekNames(), ["feature_opened", "nova_card_opened"])
    }

    func testFirstConsentedEventOfAProcessFlushes() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        XCTAssertTrue(fixture.uploader.maxBatchesCalls.contains(10))
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

    func testTheThresholdDoesNotRefireWithinFifteenSecondsOfTheLastFlush() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = AnalyticsTestFixture.makeConsented(now: { now })

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        now = now.addingTimeInterval(16)
        fixture.track(49, .novaCardOpened())
        fixture.drain()
        fixture.uploader.reset()

        now = now.addingTimeInterval(14)
        fixture.track(5, .novaCardOpened())
        fixture.drain()
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
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

    func testCancelFlushReleasesTheSingleFlightSlot() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        let firstStarted = XCTestExpectation(description: "first flush started")
        let secondStarted = XCTestExpectation(description: "second flush started")

        var wrappers: [CompoundOperationWrapper<Void>] = []

        fixture.uploader.flushStub = { _ in
            let expectation = wrappers.isEmpty ? firstStarted : secondStarted
            let wrapper = CompoundOperationWrapper(
                targetOperation: AsyncClosureOperation<Void> { _ in expectation.fulfill() }
            )

            wrappers.append(wrapper)

            return wrapper
        }

        fixture.service.flush(reason: .manual)
        wait(for: [firstStarted], timeout: 5)

        fixture.service.flush(reason: .manual)
        XCTAssertEqual(wrappers.count, 1)

        fixture.service.cancelFlush()
        XCTAssertTrue(wrappers[0].targetOperation.isCancelled)

        fixture.service.flush(reason: .manual)
        wait(for: [secondStarted], timeout: 5)
        XCTAssertEqual(wrappers.count, 2)
    }

    func testEventPersistsWhileUploadInFlight() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let uploadStarted = XCTestExpectation(description: "upload started")
        let release = XCTestExpectation(description: "released")

        fixture.uploader.flushStub = { _ in
            CompoundOperationWrapper(targetOperation: ClosureOperation<Void> {
                uploadStarted.fulfill()
                _ = XCTWaiter.wait(for: [release], timeout: 5)
            })
        }

        fixture.service.flush(reason: .manual)
        wait(for: [uploadStarted], timeout: 5)

        fixture.service.track(.novaCardOpened())
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        release.fulfill()
        fixture.uploadOperationQueue.waitUntilAllOperationsAreFinished()
    }

    func testAFlushCompletionStillRunsWhenTheFlushIsCancelled() {
        let fixture = AnalyticsTestFixture.makeConsented()
        let gate = DispatchSemaphore(value: 0)
        holdFlush(fixture, until: gate)

        let completions = CompletionCounter()
        let ranTwice = expectation(description: "completion ran a second time")
        ranTwice.isInverted = true

        fixture.service.flush(reason: .background) {
            if completions.increment() > 1 {
                ranTwice.fulfill()
            }
        }

        fixture.service.cancelFlush()
        fixture.drainCompletions()

        XCTAssertEqual(completions.value, 1, "the cancelled flush stranded its completion")

        gate.signal()
        fixture.drainUploads()

        wait(for: [ranTwice], timeout: 1)
    }

    func testAFlushCompletionWaitsForTheFlushThatIsAlreadyRunning() {
        let fixture = AnalyticsTestFixture.makeConsented()
        let gate = DispatchSemaphore(value: 0)
        holdFlush(fixture, until: gate)

        fixture.service.flush(reason: .launch, completion: {})

        let completions = CompletionCounter()
        let released = expectation(description: "completion after the in-flight flush settles")

        fixture.service.flush(reason: .background) {
            completions.increment()
            released.fulfill()
        }

        fixture.drainCompletions()

        XCTAssertEqual(
            completions.value,
            0,
            "the completion fired while the in-flight upload was still running"
        )

        gate.signal()
        wait(for: [released], timeout: 5)

        XCTAssertEqual(completions.value, 1)
    }

    func testAFlushCompletionRunsWhenThereIsNothingToFlush() {
        let fixture = AnalyticsTestFixture.make(isAvailable: false)

        let completions = CompletionCounter()
        fixture.service.flush(reason: .background) { completions.increment() }
        fixture.drainCompletions()

        XCTAssertEqual(completions.value, 1)
    }

    func testAnOptOutReleasesTheCompletionOfTheFlushItCancels() {
        let fixture = AnalyticsTestFixture.makeConsented()
        let gate = DispatchSemaphore(value: 0)
        holdFlush(fixture, until: gate)

        let completions = CompletionCounter()
        let ranTwice = expectation(description: "completion ran a second time")
        ranTwice.isInverted = true

        fixture.service.flush(reason: .background) {
            if completions.increment() > 1 {
                ranTwice.fulfill()
            }
        }

        fixture.consent.setEnabled(false)
        fixture.drain()
        fixture.drainCompletions()

        XCTAssertEqual(completions.value, 1)

        gate.signal()
        fixture.drainUploads()

        wait(for: [ranTwice], timeout: 1)
    }

    func testTheEnqueueIsSubmittedWhileTheConsentWipeIsLockedOut() {
        let settings = InMemorySettingsManager()
        let availability = AnalyticsAvailabilityProvider(attestationMode: .appAttest)
        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: availability
        )
        consent.setEnabled(true)

        let wipeReachedConsentChange = DispatchSemaphore(value: 0)
        let wipeProbe = DispatchSemaphore(value: 0)
        let wipeCompleted = expectation(description: "the consent change eventually completes")
        let wipeWasBlocked = CompletionCounter()

        let queue = AnalyticsEventQueueSpy()
        queue.onEnqueueComposition = { _, _, _ in
            DispatchQueue.global().async {
                wipeReachedConsentChange.signal()
                consent.setEnabled(false)
                wipeProbe.signal()
                wipeCompleted.fulfill()
            }

            wipeReachedConsentChange.wait()

            if wipeProbe.wait(timeout: .now() + 0.5) == .timedOut {
                wipeWasBlocked.increment()
            }
        }

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: queue,
            identity: AnalyticsIdentity(settingsManager: settings),
            uploader: AnalyticsUploadingSpy(),
            operationQueue: operationQueue,
            uploadOperationQueue: OperationQueue(),
            logger: SilentLogger()
        )

        service.track(.novaCardOpened())

        wait(for: [wipeCompleted], timeout: 5)
        operationQueue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(
            wipeWasBlocked.value,
            1,
            "the opt-out wipe could run while the enqueue was still being submitted"
        )
    }

    func testAFailedFlushHoldsOffTheNextIntervalFlushForAMinute() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFailingFixture(now: { now })

        flushAndSettle(fixture, reason: .manual)
        fixture.uploader.reset()

        now = now.addingTimeInterval(59)
        fixture.service.flush(reason: .interval)
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
        fixture.service.flush(reason: .interval)
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testASecondConsecutiveFailureDoublesTheHoldOff() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFailingFixture(now: { now })

        flushAndSettle(fixture, reason: .manual)

        now = now.addingTimeInterval(60)
        flushAndSettle(fixture, reason: .interval)
        fixture.uploader.reset()

        now = now.addingTimeInterval(119)
        fixture.service.flush(reason: .interval)
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
        fixture.service.flush(reason: .interval)
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testASuccessfulFlushClearsTheHoldOff() {
        let now = Date(timeIntervalSince1970: 0)
        let fixture = makeFailingFixture(now: { now })

        flushAndSettle(fixture, reason: .manual)

        fixture.uploader.flushStub = { _ in .createWithResult(()) }
        flushAndSettle(fixture, reason: .manual)
        fixture.uploader.reset()

        fixture.service.flush(reason: .interval)
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testARetryAfterLongerThanTheEscalatedWindowSetsTheHoldOff() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFailingFixture(
            now: { now },
            error: AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 120)
        )

        flushAndSettle(fixture, reason: .manual)
        fixture.uploader.reset()

        now = now.addingTimeInterval(119)
        fixture.service.flush(reason: .interval)
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)

        now = now.addingTimeInterval(2)
        fixture.service.flush(reason: .interval)
        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testAFailingGatewayStopsEveryTrackedEventFromStartingAFlush() {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeFailingFixture(now: { now })

        fixture.track(50, .novaCardOpened())
        fixture.drain()

        flushAndSettle(fixture, reason: .manual)
        fixture.uploader.reset()

        now = now.addingTimeInterval(16)
        fixture.track(5, .novaCardOpened())
        fixture.drain()

        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)
    }

    func testAGatewayRejectionKeepsEscalatingTheHoldOff() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeGatewayFixture(
            uploadResults: [
                .failure(AnalyticsTransportError.serverError(statusCode: 500)),
                .failure(AnalyticsTransportError.serverError(statusCode: 500)),
                .failure(AnalyticsTransportError.rejected(statusCode: 403))
            ],
            now: { now }
        )

        try seed(fixture)
        flushAndSettle(fixture, reason: .manual)

        now = now.addingTimeInterval(60)
        flushAndSettle(fixture, reason: .interval)

        now = now.addingTimeInterval(120)
        flushAndSettle(fixture, reason: .interval)

        try seed(fixture)
        XCTAssertEqual(fixture.uploadFactory.callCount, 3)

        now = now.addingTimeInterval(239)
        flushAndSettle(fixture, reason: .interval)
        XCTAssertEqual(
            fixture.uploadFactory.callCount,
            3,
            "the rejection was graded as a delivered flush and released the hold off"
        )

        now = now.addingTimeInterval(2)
        flushAndSettle(fixture, reason: .interval)
        XCTAssertEqual(fixture.uploadFactory.callCount, 4)
    }

    func testARetryAfterShorterThanTheEscalatedWindowDoesNotShortenTheHoldOff() throws {
        var now = Date(timeIntervalSince1970: 0)
        let fixture = makeGatewayFixture(
            uploadResults: [
                .failure(AnalyticsTransportError.serverError(statusCode: 500)),
                .failure(AnalyticsTransportError.serverError(statusCode: 500)),
                .failure(AnalyticsTransportError.retryLater(statusCode: 429, retryAfter: 30))
            ],
            now: { now }
        )

        try seed(fixture)
        flushAndSettle(fixture, reason: .manual)

        now = now.addingTimeInterval(60)
        flushAndSettle(fixture, reason: .interval)

        now = now.addingTimeInterval(120)
        flushAndSettle(fixture, reason: .interval)

        XCTAssertEqual(fixture.uploadFactory.callCount, 3)

        now = now.addingTimeInterval(239)
        flushAndSettle(fixture, reason: .interval)
        XCTAssertEqual(
            fixture.uploadFactory.callCount,
            3,
            "the gateway hint replaced the escalated window instead of flooring it"
        )

        now = now.addingTimeInterval(2)
        flushAndSettle(fixture, reason: .interval)
        XCTAssertEqual(fixture.uploadFactory.callCount, 4)
    }

    private func makeGatewayFixture(
        uploadResults: [Result<Void, Error>],
        now: @escaping () -> Date
    ) -> GatewayFixture {
        let facade = AnalyticsStorageTestFacade()

        let eventQueue = CoreDataAnalyticsEventQueue(
            repository: AnyDataProviderRepository(facade.createEventRepository()),
            maxCount: 500
        )

        let settings = SerialisedSettingsManager()
        let availability = AnalyticsAvailabilityProvider(attestationMode: .appAttest)
        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: availability
        )

        let identity = AnalyticsIdentity(settingsManager: settings)

        let uploadFactory = AnalyticsUploadOperationFactorySpy()
        uploadFactory.uploadResults = uploadResults

        let uploader = AnalyticsUploader(
            queue: eventQueue,
            identity: identity,
            attestation: BackendAttestationProviderSpy(),
            uploadFactory: uploadFactory,
            operationQueue: OperationQueue(),
            appVersion: "10.9.0",
            timeProvider: now,
            logger: SilentLogger()
        )

        let service = AnalyticsService(
            consent: consent,
            availability: availability,
            queue: eventQueue,
            identity: identity,
            uploader: uploader,
            operationQueue: OperationQueue(),
            uploadOperationQueue: OperationQueue(),
            timeProvider: now,
            logger: SilentLogger()
        )

        consent.setEnabled(true)

        return GatewayFixture(
            service: service,
            queue: eventQueue,
            identity: identity,
            uploadFactory: uploadFactory
        )
    }

    private func seed(_ fixture: GatewayFixture) throws {
        let wrapper = fixture.queue.enqueueWrapper(
            name: "nova_card_opened",
            timestamp: Date(timeIntervalSince1970: 0),
            payload: Data("{}".utf8),
            consentEpoch: fixture.identity.consentEpoch
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        _ = try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func flushAndSettle(_ fixture: GatewayFixture, reason: AnalyticsFlushReason) {
        let settled = expectation(description: "flush settled")
        fixture.service.flush(reason: reason) { settled.fulfill() }

        wait(for: [settled], timeout: 5)
    }

    private func makeFailingFixture(
        now: @escaping () -> Date,
        error: Error = AnalyticsTransportError.serverError(statusCode: 500)
    ) -> AnalyticsTestFixture {
        let fixture = AnalyticsTestFixture.makeConsented(now: now)
        fixture.uploader.flushStub = { _ in .createWithError(error) }

        return fixture
    }

    private func flushAndSettle(_ fixture: AnalyticsTestFixture, reason: AnalyticsFlushReason) {
        let settled = expectation(description: "flush settled")
        fixture.service.flush(reason: reason) { settled.fulfill() }

        wait(for: [settled], timeout: 5)
    }

    private func holdFlush(_ fixture: AnalyticsTestFixture, until gate: DispatchSemaphore) {
        fixture.uploader.flushStub = { _ in
            CompoundOperationWrapper(targetOperation: ClosureOperation<Void> {
                gate.wait()
            })
        }
    }
}

private struct GatewayFixture {
    let service: AnalyticsService
    let queue: CoreDataAnalyticsEventQueue
    let identity: AnalyticsIdentity
    let uploadFactory: AnalyticsUploadOperationFactorySpy
}

private final class CompletionCounter {
    private let mutex = NSLock()
    private var count = 0

    @discardableResult
    func increment() -> Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        count += 1

        return count
    }

    var value: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return count
    }
}
