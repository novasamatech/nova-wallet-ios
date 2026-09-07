import XCTest
@testable import NovaAnalytics
import Operation_iOS
import Keystore_iOS

final class AnalyticsErasureTests: XCTestCase {
    private struct ClearFailure: Error {}

    private enum Keys {
        static let erasureOwed = "analyticsErasureOwed"
    }

    func testAnOptOutPersistsTheObligationBeforeTheClearRuns() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let owedInsideTheClear = RecordedValues<Bool>()

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClear = {
            owedInsideTheClear.record(fixture.settings.bool(for: Keys.erasureOwed) ?? false)
        }

        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(owedInsideTheClear.values, [true])
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

    func testAnOptOutDuringAnInFlightWipeAlsoClearsTheRowsTrackedMeanwhile() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        let firstClearStarted = expectation(description: "first clear started")
        let secondClearRan = expectation(description: "second clear ran")
        let gate = DispatchSemaphore(value: 0)

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClear = {
            firstClearStarted.fulfill()
            gate.wait()
        }

        fixture.consent.setEnabled(false)
        wait(for: [firstClearStarted], timeout: 5)

        fixture.consent.setEnabled(true)
        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)

        fixture.clearInterceptor.onClear = { secondClearRan.fulfill() }
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

    func testAQueuedRowCarriesTheConsentEpochOfItsEnqueue() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())

        XCTAssertEqual(try fixture.peekEvents().map(\.consentEpoch), [fixture.identity.consentEpoch])

        fixture.consent.setEnabled(false)
        fixture.consent.setEnabled(true)
        fixture.service.track(.novaCardOpened())

        XCTAssertEqual(try fixture.peekEvents().map(\.consentEpoch), [fixture.identity.consentEpoch])
        XCTAssertEqual(fixture.identity.consentEpoch, 3)
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
