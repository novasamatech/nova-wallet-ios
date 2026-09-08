import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS

final class AnalyticsErasureTests: XCTestCase {
    private struct ClearFailure: Error {}

    private typealias Keys = AnalyticsTestFixture.Keys

    private struct CoordinatorFixture {
        let coordinator: AnalyticsErasureCoordinator
        let consent: AnalyticsConsentManager
        let clearInterceptor: AnalyticsEventQueueClearInterceptor
        let operationQueue: OperationQueue

        func drain() {
            operationQueue.waitUntilAllOperationsAreFinished()
        }
    }

    func testAnOptOutPersistsTheObligationBeforeTheClearIsScheduled() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let owedWhenScheduled = RecordedValues<Bool>()
        let owedInsideTheClear = RecordedValues<Bool>()

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClearScheduled = {
            owedWhenScheduled.record(fixture.settings.bool(for: Keys.erasureOwed) ?? false)
        }

        fixture.clearInterceptor.onClear = {
            owedInsideTheClear.record(fixture.settings.bool(for: Keys.erasureOwed) ?? false)
        }

        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(owedWhenScheduled.values, [true])
        XCTAssertEqual(owedInsideTheClear.values, [true])
    }

    func testAKillSwitchPersistsTheObligationBeforeTheClearIsScheduled() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let owedWhenScheduled = RecordedValues<Bool>()

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClearScheduled = {
            owedWhenScheduled.record(fixture.settings.bool(for: Keys.erasureOwed) ?? false)
        }

        fixture.availability.setRemoteEnabled(false)
        fixture.service.handleAvailabilityChanged()
        fixture.drain()

        XCTAssertEqual(owedWhenScheduled.values, [true])
    }

    func testAFailedClearKeepsTheObligationAndTheRows() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        fixture.clearInterceptor.clearError = ClearFailure()

        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), true)
        XCTAssertEqual(try fixture.queueCount(), 1)
    }

    func testTheNextFlushRetriesTheWipeInsteadOfUploading() throws {
        let fixture = makeFixtureWithAFailedOptOut()

        fixture.consent.setEnabled(true)
        fixture.clearInterceptor.clearError = nil

        fixture.service.flush(reason: .manual)
        fixture.drain()

        XCTAssertTrue(
            fixture.uploader.maxBatchesCalls.isEmpty,
            "the flush uploaded over rows that were still owed an erasure"
        )
        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 2)
        XCTAssertEqual(try fixture.queueCount(), 0)
        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), false)
    }

    func testAFlushWhileConsentIsOffRetriesAFailedWipe() throws {
        let fixture = makeFixtureWithAFailedOptOut()
        fixture.clearInterceptor.clearError = nil

        fixture.service.flush(reason: .manual)
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 2)
        XCTAssertEqual(try fixture.queueCount(), 0)
        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), false)
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)
    }

    func testAConsentOffLaunchFlushDoesNotWarnAboutTheOwedWipe() {
        let logger = RecordingLogger()
        let fixture = AnalyticsTestFixture.make(clearError: ClearFailure(), logger: logger)
        fixture.drain()

        fixture.service.flush(reason: .launch)
        fixture.drain()

        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), true)
        XCTAssertEqual(logger.warnings, [])
    }

    func testAConsentedFlushRefusedByAnOwedWipeWarns() {
        let logger = RecordingLogger()
        let fixture = AnalyticsTestFixture.make(clearError: ClearFailure(), logger: logger)
        fixture.drain()

        fixture.consent.setEnabled(true)
        fixture.service.flush(reason: .manual)
        fixture.drain()

        XCTAssertEqual(logger.warnings, ["Analytics flush skipped, a wipe is still owed"])
        XCTAssertTrue(fixture.uploader.maxBatchesCalls.isEmpty)
    }

    func testAFlushUploadsAgainOnceTheRetriedWipeSucceeds() throws {
        let fixture = makeFixtureWithAFailedOptOut()

        fixture.consent.setEnabled(true)
        fixture.clearInterceptor.clearError = nil
        fixture.service.flush(reason: .manual)
        fixture.drain()

        fixture.service.flush(reason: .manual)

        XCTAssertEqual(fixture.uploader.maxBatchesCalls, [10])
    }

    func testASuccessfulClearReleasesTheObligation() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), false)
        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 1)
        XCTAssertEqual(try fixture.queueCount(), 0)
    }

    func testARetryAfterTheWipeHasSettledSchedulesNothing() {
        let fixture = makeCoordinatorFixture()

        fixture.coordinator.request()
        fixture.drain()

        XCTAssertFalse(fixture.coordinator.retryIfOwed())
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 1)
    }

    func testARetryWhileAWipeIsInFlightSchedulesNothing() {
        let fixture = makeCoordinatorFixture()
        let clearStarted = expectation(description: "clear started")
        clearStarted.assertForOverFulfill = false
        let gate = DispatchSemaphore(value: 0)

        fixture.clearInterceptor.onClear = {
            clearStarted.fulfill()
            XCTAssertEqual(gate.wait(timeout: .now() + 5), .success)
        }

        fixture.coordinator.request()
        wait(for: [clearStarted], timeout: 5)
        fixture.clearInterceptor.onClear = nil

        XCTAssertTrue(fixture.coordinator.retryIfOwed())

        gate.signal()
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 1)
        XCTAssertFalse(fixture.consent.isErasureOwed)
    }

    func testARetryAfterAFailedWipeSchedulesAnotherClear() {
        let fixture = makeCoordinatorFixture()
        fixture.clearInterceptor.clearError = ClearFailure()

        fixture.coordinator.request()
        fixture.drain()
        fixture.clearInterceptor.clearError = nil

        XCTAssertTrue(fixture.coordinator.retryIfOwed())
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 2)
        XCTAssertFalse(fixture.consent.isErasureOwed)
    }

    func testAnOwedErasureIsDrainedBeforeTheNextLaunchUploadsAnything() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(settings: settings, storage: storage)
        previousLaunch.clearInterceptor.clearError = ClearFailure()
        previousLaunch.track(3, .novaCardOpened())
        previousLaunch.consent.setEnabled(false)
        previousLaunch.consent.setEnabled(true)
        previousLaunch.drain()

        XCTAssertEqual(try previousLaunch.queueCount(), 3)

        let relaunch = AnalyticsTestFixture.make(settings: settings, storage: storage)
        let uploadedPages = RecordedValues<[String]>()

        relaunch.uploader.flushStub = { [queue = relaunch.queue] _ in
            uploadedPages.record(Self.queuedNames(in: queue))

            return .createWithResult(())
        }

        relaunch.service.track(.appOpened(isFirstLaunch: false))
        relaunch.drain()
        relaunch.drainUploads()

        XCTAssertEqual(uploadedPages.values, [["app_opened"]])
        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), false)
        XCTAssertEqual(try relaunch.queueCount(), 1)
    }

    func testTheKillSwitchWipeIsOwedUntilALaterLaunchCompletesIt() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(settings: settings, storage: storage)
        previousLaunch.clearInterceptor.clearError = ClearFailure()
        previousLaunch.service.track(.novaCardOpened())
        previousLaunch.availability.setRemoteEnabled(false)
        previousLaunch.service.handleAvailabilityChanged()
        previousLaunch.drain()

        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), true)
        XCTAssertEqual(try previousLaunch.queueCount(), 1)

        let relaunch = AnalyticsTestFixture.make(settings: settings, storage: storage)
        relaunch.drain()

        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), false)
        XCTAssertEqual(try relaunch.queueCount(), 0)
    }

    func testALaunchWithoutConsentRepairsTheRowsAndIdentityLeftBehind() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(settings: settings, storage: storage)
        previousLaunch.track(2, .novaCardOpened())
        previousLaunch.drain()

        XCTAssertNotNil(previousLaunch.identity.installId())
        XCTAssertEqual(try previousLaunch.queueCount(), 2)

        settings.set(value: false, for: Keys.analyticsEnabled)

        XCTAssertNil(settings.bool(for: Keys.erasureOwed))

        let relaunch = AnalyticsTestFixture.make(settings: settings, storage: storage)
        relaunch.drain()

        XCTAssertEqual(try relaunch.queueCount(), 0)
        XCTAssertNil(relaunch.persistedInstallId())
        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), false)
    }

    func testALaunchWithoutConsentRetiresTheGatewayClientLeftBehind() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(
            deviceCheck: DeviceCheckAttestingSpy(),
            settings: settings,
            storage: storage
        )
        previousLaunch.track(2, .novaCardOpened())
        previousLaunch.service.flush(reason: .manual)
        previousLaunch.drain()
        previousLaunch.drainUploads()

        XCTAssertNotNil(previousLaunch.identity.installId())
        XCTAssertNotNil(settings.string(for: Keys.gatewayClientId))
        XCTAssertNotNil(settings.data(for: Keys.appAttestKeys))
        XCTAssertEqual(try previousLaunch.queueCount(), 2)

        settings.set(value: false, for: Keys.analyticsEnabled)

        let relaunch = AnalyticsTestFixture.make(
            deviceCheck: DeviceCheckAttestingSpy(),
            settings: settings,
            storage: storage
        )
        relaunch.drain()
        relaunch.drainAttestation()

        XCTAssertNil(settings.string(for: Keys.gatewayClientId))
        XCTAssertNil(settings.data(for: Keys.appAttestKeys))
        XCTAssertNil(relaunch.persistedInstallId())
        XCTAssertEqual(try relaunch.queueCount(), 0)
    }

    func testALaunchWithoutConsentRetiresTheKeyRowOrphanedByAnInterruptedOptOut() throws {
        let settings = SerialisedSettingsManager()
        let storage = AnalyticsStorageTestFacade()

        let previousLaunch = AnalyticsTestFixture.makeConsented(
            deviceCheck: DeviceCheckAttestingSpy(),
            settings: settings,
            storage: storage
        )
        previousLaunch.service.flush(reason: .manual)
        previousLaunch.drain()
        previousLaunch.drainUploads()

        XCTAssertNotNil(settings.data(for: Keys.appAttestKeys))

        settings.set(value: false, for: Keys.analyticsEnabled)
        settings.removeValue(for: Keys.gatewayClientId)

        let relaunch = AnalyticsTestFixture.make(
            deviceCheck: DeviceCheckAttestingSpy(),
            settings: settings,
            storage: storage
        )
        relaunch.drain()
        relaunch.drainAttestation()

        XCTAssertNil(settings.data(for: Keys.appAttestKeys))
    }

    func testAnOptOutDuringAnInFlightWipeAlsoClearsTheRowsTrackedMeanwhile() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let firstClearStarted = expectation(description: "first clear started")
        firstClearStarted.assertForOverFulfill = false
        let secondClearRan = expectation(description: "second clear ran")
        let gate = DispatchSemaphore(value: 0)

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClear = {
            firstClearStarted.fulfill()
            XCTAssertEqual(gate.wait(timeout: .now() + 5), .success)
        }

        fixture.consent.setEnabled(false)
        wait(for: [firstClearStarted], timeout: 5)
        fixture.clearInterceptor.onClear = { secondClearRan.fulfill() }

        fixture.consent.setEnabled(true)
        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)

        gate.signal()

        wait(for: [secondClearRan], timeout: 5)
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 2)
        XCTAssertEqual(
            try fixture.queueCount(),
            0,
            "rows tracked between the two opt-outs survived the coalesced wipe"
        )
    }

    func testAWipeRequestedDuringAnInFlightWipeSparesTheRowsTrackedUnderTheLaterConsent() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let firstClearStarted = expectation(description: "first clear started")
        firstClearStarted.assertForOverFulfill = false
        let gate = DispatchSemaphore(value: 0)

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClear = {
            firstClearStarted.fulfill()
            XCTAssertEqual(gate.wait(timeout: .now() + 5), .success)
        }

        fixture.consent.setEnabled(false)
        wait(for: [firstClearStarted], timeout: 5)
        fixture.clearInterceptor.onClear = nil

        fixture.consent.setEnabled(true)
        fixture.service.track(.featureOpened(.staking))
        fixture.consent.setEnabled(false)
        fixture.consent.setEnabled(true)
        fixture.service.track(.sessionStarted())

        gate.signal()
        fixture.drain()

        XCTAssertEqual(fixture.clearInterceptor.clearCallCount, 2)
        XCTAssertEqual(
            try fixture.peekNames(),
            ["session_started"],
            "the follow-up wipe was ordered after rows recorded under the later consent"
        )
        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), false)
    }

    func testAQueuedRowCarriesTheConsentEpochOfItsEnqueue() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let epochAtStart = fixture.identity.consentEpoch

        fixture.service.track(.novaCardOpened())

        XCTAssertEqual(try fixture.peekEvents().map(\.consentEpoch), [epochAtStart])

        fixture.consent.setEnabled(false)
        fixture.consent.setEnabled(true)
        fixture.service.track(.novaCardOpened())

        XCTAssertEqual(try fixture.peekEvents().map(\.consentEpoch), [fixture.identity.consentEpoch])
        XCTAssertEqual(fixture.identity.consentEpoch, epochAtStart + 2)
    }

    private func makeFixtureWithAFailedOptOut() -> AnalyticsTestFixture {
        let fixture = AnalyticsTestFixture.makeConsented()
        fixture.clearInterceptor.clearError = ClearFailure()

        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)
        fixture.drain()
        fixture.uploader.reset()

        return fixture
    }

    private func makeCoordinatorFixture() -> CoordinatorFixture {
        let settings = SerialisedSettingsManager()
        let consent = AnalyticsConsentManager(
            settingsManager: settings,
            availabilityProvider: AnalyticsAvailabilityProvider(attestationMode: .appAttest, settingsManager: settings)
        )

        let clearInterceptor = AnalyticsEventQueueClearInterceptor(wrapping: AnalyticsEventQueueSpy())

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let coordinator = AnalyticsErasureCoordinator(
            consent: consent,
            queue: clearInterceptor,
            operationQueue: operationQueue,
            logger: SilentLogger()
        )

        return CoordinatorFixture(
            coordinator: coordinator,
            consent: consent,
            clearInterceptor: clearInterceptor,
            operationQueue: operationQueue
        )
    }

    private static func queuedNames(in queue: CoreDataAnalyticsEventQueue) -> [String] {
        let wrapper = queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return (try? wrapper.targetOperation.extractNoCancellableResultData().map(\.name)) ?? []
    }
}

private final class RecordedValues<Value> {
    private let mutex = NSLock()
    private var stored: [Value] = []

    func record(_ value: Value) {
        mutex.lock()
        stored.append(value)
        mutex.unlock()
    }

    var values: [Value] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stored
    }
}
