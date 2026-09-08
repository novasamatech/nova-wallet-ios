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

    func pendingEvents() throws -> [AnalyticsPendingEvent] {
        let wrapper = facade.debugPendingEventsWrapper(count: 500)
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func pendingNames() throws -> [String] {
        try pendingEvents().map(\.name)
    }

    func persistedInstallId() -> String? {
        settings.string(for: AnalyticsTestFixture.Keys.analyticsInstallId)
    }

    func enterForeground() {
        sessionHandler.enterForeground()
        refreshOnForeground()
    }

    func enterBackground() {
        sessionHandler.enterBackground()
        facade.didReceiveDidEnterBackground(notification: Notification(name: .init("test")))
    }

    func refreshOnForeground() {
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
        isFirstLaunch: @escaping () -> Bool = { false },
        operationQueue: OperationQueue = OperationQueue(),
        analyticsOperationQueue: OperationQueue = OperationQueue()
    ) -> AnalyticsConfiguration {
        AnalyticsConfiguration(
            gatewayURL: refusingGatewayURL,
            appVersion: "10.9.0",
            storeDirectory: directory,
            isReleaseBuild: false,
            isFirstLaunch: isFirstLaunch,
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
        persistedRemoteEnabled: Bool? = nil,
        isFirstLaunch: @escaping () -> Bool = { false }
    ) throws -> FacadeFixture {
        let settings = SerialisedSettingsManager()
        settings.set(value: optedIn, for: Keys.analyticsEnabled)

        if let persistedRemoteEnabled {
            settings.set(value: persistedRemoteEnabled, for: Keys.remoteEnabled)
        }

        let remoteSettings = RemoteSettingsStub()
        let sessionHandler = ApplicationHandlerStub()
        let operationQueue = OperationQueue()
        let analyticsOperationQueue = OperationQueue()
        analyticsOperationQueue.maxConcurrentOperationCount = 1

        let directory = try makeStoreDirectory()

        let facade = AnalyticsServiceFacade(
            configuration: makeConfiguration(
                directory: directory,
                settings: settings,
                remoteSettings: remoteSettings,
                isFirstLaunch: isFirstLaunch,
                operationQueue: operationQueue,
                analyticsOperationQueue: analyticsOperationQueue
            ),
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

    func testAForegroundRefreshThatStaysOnDoesNotRerunTheLaunchSequence() throws {
        let fixture = try makeFacadeFixture(optedIn: true)

        fixture.facade.setup()
        fixture.drain()
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])

        fixture.refreshOnForeground()
        fixture.drain()

        XCTAssertEqual(fixture.remoteSettings.requestCount, 2)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true])
    }

    func testAForegroundWhileOnStartsOneMoreSessionWithoutReopeningTheApp() throws {
        let fixture = try makeFacadeFixture(optedIn: true)

        fixture.facade.setup()
        fixture.drain()

        fixture.enterForeground()
        fixture.drain()

        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened", "session_started"])
        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true])
    }

    func testAnOnOffOnRoundTripArmsAndThrottlesTheTrackerOnceEachWay() throws {
        let fixture = try makeFacadeFixture(optedIn: true)

        fixture.facade.setup()
        fixture.drain()
        fixture.recordAndSettleUploads()
        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true])

        fixture.remoteSettings.result = .success(false)
        fixture.refreshOnForeground()
        fixture.drain()
        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true, false])
        XCTAssertEqual(try fixture.pendingNames(), [])

        fixture.remoteSettings.result = .success(true)
        fixture.refreshOnForeground()
        fixture.drain()

        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true, false, true])
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
    }

    func testAResolutionThatLandsInTheBackgroundDefersTheSessionAndTheLaunchFlush() throws {
        let fixture = try makeFacadeFixture(optedIn: true)
        let requested = expectation(description: "remote settings requested")
        let gate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.onRequest = { requested.fulfill() }
        fixture.remoteSettings.gate = gate

        fixture.facade.setup()
        wait(for: [requested], timeout: 5)
        fixture.enterBackground()

        gate.signal()
        fixture.drain()

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(fixture.sessionHandler.delegateAssignments, [true])
        XCTAssertEqual(try fixture.pendingNames(), ["app_opened"])
        XCTAssertNil(fixture.persistedInstallId())

        fixture.remoteSettings.onRequest = nil
        fixture.remoteSettings.gate = nil
        fixture.enterForeground()
        fixture.drain()

        XCTAssertEqual(try fixture.pendingNames(), ["app_opened", "session_started"])
        XCTAssertNotNil(fixture.persistedInstallId())
    }

    func testAnOlderResolutionThatLandsAfterANewerOneIsDropped() throws {
        let fixture = try makeFacadeFixture(optedIn: true)
        let olderRequested = expectation(description: "older resolution requested")
        let olderGate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.result = .success(false)
        fixture.remoteSettings.onRequest = { olderRequested.fulfill() }
        fixture.remoteSettings.gate = olderGate

        fixture.facade.setup()
        wait(for: [olderRequested], timeout: 5)

        let newerRequested = expectation(description: "newer resolution requested")
        let newerGate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.result = .success(true)
        fixture.remoteSettings.onRequest = { newerRequested.fulfill() }
        fixture.remoteSettings.gate = newerGate

        fixture.refreshOnForeground()
        wait(for: [newerRequested], timeout: 5)

        let owner = NSObject()
        let switchedOn = expectation(description: "the newer resolution switched analytics on")
        fixture.facade.consent.addAvailabilityObserver(with: owner, queue: nil) { isAvailable in
            if isAvailable {
                switchedOn.fulfill()
            }
        }

        newerGate.signal()
        wait(for: [switchedOn], timeout: 5)

        olderGate.signal()
        fixture.drain()
        fixture.facade.consent.removeAvailabilityObserver(by: owner)

        XCTAssertTrue(fixture.facade.consent.isAvailable)
        XCTAssertEqual(fixture.settings.bool(for: Keys.remoteEnabled), true)
        XCTAssertEqual(try fixture.pendingNames(), ["session_started", "app_opened"])
    }

    func testTheFirstLaunchFactIsCapturedWhenSetupRunsNotWhenTheResolutionLands() throws {
        var isFirstLaunch = true
        let fixture = try makeFacadeFixture(optedIn: true, isFirstLaunch: { isFirstLaunch })
        let requested = expectation(description: "remote settings requested")
        let gate = DispatchSemaphore(value: 0)
        fixture.remoteSettings.onRequest = { requested.fulfill() }
        fixture.remoteSettings.gate = gate

        fixture.facade.setup()
        wait(for: [requested], timeout: 5)
        isFirstLaunch = false

        gate.signal()
        fixture.drain()

        let appOpened = try XCTUnwrap(fixture.pendingEvents().first { $0.name == "app_opened" })
        let properties = try XCTUnwrap(JSONSerialization.jsonObject(with: appOpened.payload) as? [String: Any])

        XCTAssertEqual(properties["is_first_launch"] as? Bool, true)
    }
}
