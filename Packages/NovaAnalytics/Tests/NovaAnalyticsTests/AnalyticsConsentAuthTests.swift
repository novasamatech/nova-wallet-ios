import XCTest
@testable import NovaAnalytics
import Keystore_iOS
import NovaAuth
import Operation_iOS

final class AnalyticsConsentAuthTests: XCTestCase {
    private let gatewayURL = URL(string: "https://gateway.example/")!
    private let clientId = "client-c"
    private let operationQueue = OperationQueue()
    private let analyticsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var storeDirectory: URL!

    private let authClient = AnalyticsAuthClientSpy()

    override func setUpWithError() throws {
        try super.setUpWithError()

        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: storeDirectory)

        try super.tearDownWithError()
    }

    func testConsentWithdrawalErasesTheInstallIdAndKeepsTheSharedAuthIdentity() {
        let settings = makeSettings(isConsentEnabled: true)
        let facade = makeFacade(settings: settings)

        facade.flush(reason: .manual)
        drainQueues()

        facade.consent.setEnabled(false)
        drainQueues()

        XCTAssertNil(settings.string(for: "analyticsInstallId"))
        XCTAssertEqual(settings.string(for: "novaAuthIdentitySentinel"), clientId)
    }

    func testConsentGrantAfterWithdrawalKeepsTheSharedAuthIdentity() {
        let settings = makeSettings(isConsentEnabled: true)
        let facade = makeFacade(settings: settings)

        facade.flush(reason: .manual)
        drainQueues()

        facade.consent.setEnabled(false)
        drainQueues()

        facade.consent.setEnabled(true)
        drainQueues()

        XCTAssertEqual(settings.string(for: "novaAuthIdentitySentinel"), clientId)
    }

    func testLaunchWithConsentOffErasesTheInstallIdAndKeepsTheSharedAuthIdentity() {
        let settings = makeSettings(isConsentEnabled: false)
        let facade = makeFacade(settings: settings)

        drainQueues()

        XCTAssertFalse(facade.consent.isEnabled)
        XCTAssertNil(settings.string(for: "analyticsInstallId"))
        XCTAssertEqual(settings.string(for: "novaAuthIdentitySentinel"), clientId)
    }

    private func makeSettings(isConsentEnabled: Bool) -> InMemorySettingsManager {
        let settings = InMemorySettingsManager()

        settings.set(value: isConsentEnabled, for: "analyticsEnabled")
        settings.set(value: "install-a", for: "analyticsInstallId")
        settings.set(value: clientId, for: "novaAuthIdentitySentinel")

        return settings
    }

    private func makeFacade(settings: InMemorySettingsManager) -> AnalyticsServiceFacade {
        let configuration = AnalyticsConfiguration(
            authProvider: AnalyticsAuthSourceStub(auth: analyticsTestAuth(authClient)),
            isAuthSupported: true,
            appVersion: "10.9.0",
            storeDirectory: storeDirectory,
            isFirstLaunch: { false },
            settingsManager: settings,
            logger: SilentLogger(),
            operationQueue: operationQueue,
            analyticsOperationQueue: analyticsQueue
        )

        return AnalyticsServiceFacade(
            configuration: configuration,
            sessionApplicationHandler: ApplicationHandlerStub(),
            backgroundTaskRunner: ImmediateBackgroundTaskRunner()
        )
    }

    private func drainQueues() {
        operationQueue.waitUntilAllOperationsAreFinished()
        analyticsQueue.waitUntilAllOperationsAreFinished()
        operationQueue.waitUntilAllOperationsAreFinished()
    }

    func testOnlyActualConsentEnableRequestsUserInitiatedAdmissionAndUploadsStayBackground() {
        let settings = makeSettings(isConsentEnabled: false)
        let facade = makeFacade(settings: settings)
        facade.setup()
        drainQueues()
        XCTAssertTrue(authClient.admissions.isEmpty)

        let admitted = expectation(description: "consent action admits shared auth")
        authClient.onAdmission = { admitted.fulfill() }
        facade.consent.setEnabled(true)
        wait(for: [admitted], timeout: 5)
        drainQueues()
        authClient.onAdmission = nil
        XCTAssertEqual(authClient.admissions, [.userInitiated])

        facade.consent.setEnabled(true)
        facade.didReceiveWillEnterForeground(notification: Notification(name: Notification.Name("test")))
        facade.flush(reason: .manual)
        drainQueues()
        XCTAssertEqual(authClient.admissions, [.userInitiated])
        XCTAssertTrue(authClient.requests.allSatisfy { $0.intent == .background })
        facade.throttle()
    }

    func testAlreadyEnabledConsentAtSetupDoesNotAuthorizeRecovery() {
        let facade = makeFacade(settings: makeSettings(isConsentEnabled: true))
        facade.setup()
        drainQueues()
        XCTAssertTrue(authClient.admissions.isEmpty)
        facade.throttle()
    }

    func testWithdrawalAndThrottleCancelUnresolvedConsentRecovery() {
        for throttle in [false, true] {
            let queue = OperationQueue()
            queue.isSuspended = true
            var enabled = true
            let client = AnalyticsAuthClientSpy()
            let recovery = AnalyticsConsentAuthRecovery(
                provider: AnalyticsAuthSourceStub(auth: analyticsTestAuth(client)),
                operationQueue: queue,
                isConsentEnabled: { enabled }
            )
            recovery.setActive(true)
            recovery.enableConsent()
            if throttle { recovery.setActive(false) }
            else { enabled = false; recovery.cancel() }
            queue.isSuspended = false
            queue.waitUntilAllOperationsAreFinished()
            XCTAssertTrue(client.admissions.isEmpty)
        }
    }
}
