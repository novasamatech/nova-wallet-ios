import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsErasureTests: XCTestCase {
    private struct ClearFailure: Error {}

    private typealias Keys = AnalyticsTestFixture.Keys

    func testAnOptOutPersistsTheObligationBeforeTheClearIsScheduled() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        var owedWhenScheduled: [Bool] = []

        fixture.service.track(.novaCardOpened())
        fixture.drain()

        fixture.clearInterceptor.onClearScheduled = {
            owedWhenScheduled.append(fixture.settings.bool(for: Keys.erasureOwed) ?? false)
        }

        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(owedWhenScheduled, [true])
    }

    func testAFailedWipeIsRetriedBeforeAnythingUploads() throws {
        let fixture = AnalyticsTestFixture.makeConsented()
        fixture.clearInterceptor.clearError = ClearFailure()

        fixture.service.track(.novaCardOpened())
        fixture.consent.setEnabled(false)
        fixture.drain()

        XCTAssertEqual(fixture.settings.bool(for: Keys.erasureOwed), true)
        XCTAssertEqual(try fixture.queueCount(), 1)

        fixture.uploader.reset()
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
        let uploadedPages = Locked<[[String]]>([])

        relaunch.uploader.flushStub = { [queue = relaunch.queue] _ in
            uploadedPages.update { $0.append(Self.queuedNames(in: queue)) }

            return .createWithResult(())
        }

        relaunch.service.track(.appOpened(isFirstLaunch: false))
        relaunch.drain()
        relaunch.drainUploads()

        XCTAssertEqual(uploadedPages.value, [["app_opened"]])
        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), false)
        XCTAssertEqual(try relaunch.queueCount(), 1)
    }

    func testALaunchWithoutConsentRepairsTheRowsIdentityAndGatewayClientLeftBehind() throws {
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

        XCTAssertNil(settings.bool(for: Keys.erasureOwed))

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
        XCTAssertEqual(settings.bool(for: Keys.erasureOwed), false)
    }

    private static func queuedNames(in queue: CoreDataAnalyticsEventQueue) -> [String] {
        let wrapper = queue.peekWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return (try? wrapper.targetOperation.extractNoCancellableResultData().map(\.name)) ?? []
    }
}
