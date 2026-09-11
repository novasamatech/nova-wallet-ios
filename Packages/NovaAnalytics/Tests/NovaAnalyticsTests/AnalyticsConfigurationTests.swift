import XCTest
import Operation_iOS
@testable import NovaAnalytics

private enum RemoteSettingsError: Error {
    case unreachable
}

private final class RemoteSettingsStub: AnalyticsRemoteSettings {
    var result: Result<Bool, Error> = .success(true)
    var gate: DispatchSemaphore?
    var onRequest: (() -> Void)?

    private let recordedRequests = Locked(0)

    var requestCount: Int { recordedRequests.value }

    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        recordedRequests.update { $0 += 1 }

        let result = result
        let gate = gate
        let onRequest = onRequest

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            onRequest?()
            _ = gate?.wait(timeout: .now() + 5)

            return try result.get()
        })
    }
}

private struct FacadeFixture {
    let facade: AnalyticsServiceFacade
    let remoteSettings: RemoteSettingsStub
    let settings: SerialisedSettingsManager
    let sessionHandler: ApplicationHandlerStub
    let operationQueue: OperationQueue
    let analyticsOperationQueue: OperationQueue
    let directory: URL

    func drain(file: StaticString = #filePath, line: UInt = #line) {
        let drained = XCTestExpectation(description: "operation queues drained")

        DispatchQueue.global().async {
            operationQueue.waitUntilAllOperationsAreFinished()
            analyticsOperationQueue.waitUntilAllOperationsAreFinished()
            drained.fulfill()
        }

        XCTAssertEqual(XCTWaiter().wait(for: [drained], timeout: 10), .completed, file: file, line: line)
    }

    func drainRecording() {
        analyticsOperationQueue.waitUntilAllOperationsAreFinished()
    }

    func recordAndSettleUploads(file: StaticString = #filePath, line: UInt = #line) {
        let settled = XCTestExpectation(description: "in-flight flush settled")

        facade.trackAndFlush(.novaCardOpened(), reason: .manual) { settled.fulfill() }

        XCTAssertEqual(XCTWaiter().wait(for: [settled], timeout: 10), .completed, file: file, line: line)
    }

    func pendingNames() throws -> [String] {
        let wrapper = facade.debugPendingEventsWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map(\.name)
    }

    func enterForeground() {
        sessionHandler.enterForeground()
        facade.didReceiveWillEnterForeground(notification: Notification(name: .init("test")))
    }

    func settle() {
        drain()
        try? FileManager.default.removeItem(at: directory)
    }
}

final class AnalyticsConfigurationTests: XCTestCase {
    private typealias Keys = AnalyticsTestFixture.Keys

    private func makeFacadeFixture(persistedRemoteEnabled: Bool? = nil) throws -> FacadeFixture {
        let settings = SerialisedSettingsManager()
        settings.set(value: true, for: Keys.analyticsEnabled)

        if let persistedRemoteEnabled {
            settings.set(value: persistedRemoteEnabled, for: Keys.remoteEnabled)
        }

        let remoteSettings = RemoteSettingsStub()
        let sessionHandler = ApplicationHandlerStub()
        let operationQueue = OperationQueue()
        let analyticsOperationQueue = OperationQueue()
        analyticsOperationQueue.maxConcurrentOperationCount = 1

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let configuration = AnalyticsConfiguration(
            gatewayURL: URL(string: "https://127.0.0.1:1/")!,
            appVersion: "10.9.0",
            storeDirectory: directory,
            isReleaseBuild: false,
            isFirstLaunch: { false },
            settingsManager: settings,
            remoteSettings: remoteSettings,
            logger: SilentLogger(),
            operationQueue: operationQueue,
            analyticsOperationQueue: analyticsOperationQueue
        )

        let facade = AnalyticsServiceFacade(
            configuration: configuration,
            sessionApplicationHandler: sessionHandler,
            backgroundTaskRunner: ImmediateBackgroundTaskRunner()
        )

        let fixture = FacadeFixture(
            facade: facade,
            remoteSettings: remoteSettings,
            settings: settings,
            sessionHandler: sessionHandler,
            operationQueue: operationQueue,
            analyticsOperationQueue: analyticsOperationQueue,
            directory: directory
        )

        addTeardownBlock { fixture.settle() }

        return fixture
    }

    func testTheLaunchSequenceWaitsForTheKillSwitchResolution() throws {
        let fixture = try makeFacadeFixture()
        let requested = expectation(description: "remote settings requested")
        let gate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.onRequest = { requested.fulfill() }
        fixture.remoteSettings.gate = gate

        fixture.facade.setup()
        wait(for: [requested], timeout: 5)
        fixture.drainRecording()

        XCTAssertEqual(try fixture.pendingNames(), [])
        XCTAssertNil(fixture.settings.string(for: Keys.analyticsInstallId))
        XCTAssertFalse(fixture.facade.consent.isAvailable)

        gate.signal()
        fixture.drain()

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(fixture.settings.bool(for: Keys.remoteEnabled), true)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
    }

    func testAFailedResolutionWithNothingPersistedRecordsNothing() throws {
        let fixture = try makeFacadeFixture()
        fixture.remoteSettings.result = .failure(RemoteSettingsError.unreachable)

        fixture.facade.setup()
        fixture.drain()

        XCTAssertFalse(fixture.facade.consent.isAvailable)
        XCTAssertNil(fixture.settings.bool(for: Keys.remoteEnabled))
        XCTAssertEqual(try fixture.pendingNames(), [])

        fixture.facade.track(.novaCardOpened())
        fixture.drainRecording()

        XCTAssertEqual(try fixture.pendingNames(), [])
    }

    func testAForegroundRefreshThatResolvesOffWipesTheQueueAndStopsRecording() throws {
        let fixture = try makeFacadeFixture()

        fixture.facade.setup()
        fixture.drain()
        fixture.recordAndSettleUploads()
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened", "nova_card_opened"])

        fixture.remoteSettings.result = .success(false)
        fixture.enterForeground()
        fixture.drain()

        XCTAssertEqual(fixture.remoteSettings.requestCount, 2)
        XCTAssertFalse(fixture.facade.consent.isAvailable)
        XCTAssertEqual(fixture.settings.bool(for: Keys.remoteEnabled), false)
        XCTAssertEqual(try fixture.pendingNames(), [])

        fixture.facade.track(.novaCardOpened())
        fixture.drainRecording()

        XCTAssertEqual(try fixture.pendingNames(), [])
    }

    func testAForegroundRefreshThatResolvesOnResumesRecording() throws {
        let fixture = try makeFacadeFixture(persistedRemoteEnabled: false)
        fixture.remoteSettings.result = .success(false)

        fixture.facade.setup()
        fixture.drain()
        XCTAssertEqual(try fixture.pendingNames(), [])

        fixture.remoteSettings.result = .success(true)
        fixture.enterForeground()
        fixture.drain()

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])

        fixture.facade.track(.novaCardOpened())
        fixture.drainRecording()

        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened", "nova_card_opened"])
    }
}
