import XCTest
import Operation_iOS
import Keystore_iOS
@testable import NovaAnalytics

private enum RemoteSettingsError: Error {
    case unreachable
}

private final class RemoteSettingsStub: AnalyticsRemoteSettings {
    var result: Result<Bool, Error> = .success(true)
    var gate: DispatchSemaphore?
    var onRequest: (() -> Void)?

    private let mutex = NSLock()
    private var recordedRequests = 0

    var requestCount: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return recordedRequests
    }

    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        mutex.lock()
        recordedRequests += 1
        mutex.unlock()

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
    let operationQueue: OperationQueue
    let analyticsOperationQueue: OperationQueue
    let directory: URL

    func drain() {
        operationQueue.waitUntilAllOperationsAreFinished()
        drainRecording()
    }

    func drainRecording() {
        analyticsOperationQueue.waitUntilAllOperationsAreFinished()
    }

    func pendingNames() throws -> [String] {
        let wrapper = facade.debugPendingEventsWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map(\.name)
    }

    func persistedInstallId() -> String? {
        settings.string(for: AnalyticsTestFixture.Keys.analyticsInstallId)
    }

    func enterForeground() {
        facade.didReceiveWillEnterForeground(notification: Notification(name: .init("test")))
    }

    func settle() {
        drain()
        try? FileManager.default.removeItem(at: directory)
    }
}

final class AnalyticsConfigurationTests: XCTestCase {
    private typealias Keys = AnalyticsTestFixture.Keys

    private let refusingGatewayURL = URL(string: "https://127.0.0.1:1/")!

    private func makeConfiguration(
        directory: URL,
        settings: SettingsManagerProtocol = InMemorySettingsManager(),
        remoteSettings: AnalyticsRemoteSettings,
        operationQueue: OperationQueue = OperationQueue(),
        analyticsOperationQueue: OperationQueue = OperationQueue()
    ) -> AnalyticsConfiguration {
        AnalyticsConfiguration(
            gatewayURL: refusingGatewayURL,
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
    }

    private func makeStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return directory
    }

    private func makeFacadeFixture(
        optedIn: Bool = false,
        persistedRemoteEnabled: Bool? = nil
    ) throws -> FacadeFixture {
        let settings = SerialisedSettingsManager()
        settings.set(value: optedIn, for: Keys.analyticsEnabled)

        if let persistedRemoteEnabled {
            settings.set(value: persistedRemoteEnabled, for: Keys.remoteEnabled)
        }

        let remoteSettings = RemoteSettingsStub()
        let operationQueue = OperationQueue()
        let analyticsOperationQueue = OperationQueue()
        analyticsOperationQueue.maxConcurrentOperationCount = 1

        let directory = try makeStoreDirectory()

        let facade = AnalyticsServiceFacade(
            configuration: makeConfiguration(
                directory: directory,
                settings: settings,
                remoteSettings: remoteSettings,
                operationQueue: operationQueue,
                analyticsOperationQueue: analyticsOperationQueue
            )
        )

        let fixture = FacadeFixture(
            facade: facade,
            remoteSettings: remoteSettings,
            settings: settings,
            operationQueue: operationQueue,
            analyticsOperationQueue: analyticsOperationQueue,
            directory: directory
        )

        addTeardownBlock { fixture.settle() }

        return fixture
    }

    func testFacadeBuildsFromConfigurationAlone() throws {
        let fixture = try makeFacadeFixture()

        XCTAssertFalse(fixture.facade.consent.isEnabled)
    }

    func testAppVersionComesFromConfigurationNotTheBundle() throws {
        let directory = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = makeConfiguration(directory: directory, remoteSettings: RemoteSettingsStub())

        XCTAssertEqual(configuration.appVersion, "10.9.0")
        XCTAssertNotEqual(configuration.appVersion, "")
    }

    func testTheLaunchSequenceWaitsForTheKillSwitchResolution() throws {
        let fixture = try makeFacadeFixture(optedIn: true)
        let requested = expectation(description: "remote settings requested")
        let gate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.onRequest = { requested.fulfill() }
        fixture.remoteSettings.gate = gate

        fixture.facade.setup()
        wait(for: [requested], timeout: 5)
        fixture.drainRecording()

        XCTAssertEqual(try fixture.pendingNames(), [])
        XCTAssertNil(fixture.persistedInstallId())
        XCTAssertFalse(fixture.facade.consent.isAvailable)

        gate.signal()
        fixture.drain()

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(fixture.settings.bool(for: Keys.remoteEnabled), true)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
    }

    func testAFailedResolutionWithNothingPersistedRecordsNothing() throws {
        let fixture = try makeFacadeFixture(optedIn: true)
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

    func testAFailedResolutionKeepsRecordingWhenTheLastResolutionWasOn() throws {
        let fixture = try makeFacadeFixture(optedIn: true, persistedRemoteEnabled: true)
        fixture.remoteSettings.result = .failure(RemoteSettingsError.unreachable)

        fixture.facade.setup()
        fixture.drain()

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
    }

    func testAForegroundRefreshThatResolvesOffWipesTheQueueAndStopsRecording() throws {
        let fixture = try makeFacadeFixture(optedIn: true)

        fixture.facade.setup()
        fixture.drain()
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])

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
        let fixture = try makeFacadeFixture(optedIn: true, persistedRemoteEnabled: false)
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

    func testAForegroundRefreshBeforeSetupIsIgnored() throws {
        let fixture = try makeFacadeFixture(optedIn: true)

        fixture.enterForeground()
        fixture.drain()

        XCTAssertEqual(fixture.remoteSettings.requestCount, 0)
        XCTAssertFalse(fixture.facade.consent.isAvailable)
    }
}
