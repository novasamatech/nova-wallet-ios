import XCTest
@testable import NovaAnalytics
import Keystore_iOS
import NovaAppAttest
import Operation_iOS

final class AnalyticsConsentAttestationTests: XCTestCase {
    private let gatewayURL = URL(string: "https://gateway.example/")!
    private let clientId = "client-c"
    private let operationQueue = OperationQueue()
    private let analyticsQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private var storeDirectory: URL!

    private var keyRow: AppAttestKeySettings {
        AppAttestKeySettings(identifier: gatewayURL.absoluteString + "|" + clientId, keyId: "key-c", isAttested: true)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: storeDirectory)

        try super.tearDownWithError()
    }

    func testConsentWithdrawalErasesTheInstallIdAndKeepsTheAttestationIdentity() {
        let settings = makeSettings(isConsentEnabled: true)
        let facade = makeFacade(settings: settings)

        facade.flush(reason: .manual)
        drainQueues()

        facade.consent.setEnabled(false)
        drainQueues()

        XCTAssertNil(settings.string(for: "analyticsInstallId"))
        XCTAssertEqual(settings.string(for: "gatewayAttestationClientId"), clientId)
        XCTAssertEqual(storedKeyRows(in: settings), [keyRow.identifier: keyRow])
    }

    func testConsentGrantAfterWithdrawalKeepsTheAttestationIdentity() {
        let settings = makeSettings(isConsentEnabled: true)
        let facade = makeFacade(settings: settings)

        facade.flush(reason: .manual)
        drainQueues()

        facade.consent.setEnabled(false)
        drainQueues()

        facade.consent.setEnabled(true)
        drainQueues()

        XCTAssertEqual(settings.string(for: "gatewayAttestationClientId"), clientId)
        XCTAssertEqual(storedKeyRows(in: settings), [keyRow.identifier: keyRow])
    }

    func testLaunchWithConsentOffErasesTheInstallIdAndKeepsTheAttestationIdentity() {
        let settings = makeSettings(isConsentEnabled: false)
        let facade = makeFacade(settings: settings)

        drainQueues()

        XCTAssertFalse(facade.consent.isEnabled)
        XCTAssertNil(settings.string(for: "analyticsInstallId"))
        XCTAssertEqual(settings.string(for: "gatewayAttestationClientId"), clientId)
        XCTAssertEqual(storedKeyRows(in: settings), [keyRow.identifier: keyRow])
    }

    private func makeSettings(isConsentEnabled: Bool) -> InMemorySettingsManager {
        let settings = InMemorySettingsManager()

        settings.set(value: isConsentEnabled, for: "analyticsEnabled")
        settings.set(value: "install-a", for: "analyticsInstallId")
        settings.set(value: clientId, for: "gatewayAttestationClientId")
        settings.set(value: [keyRow.identifier: keyRow], for: "appAttestKeys")

        return settings
    }

    private func makeFacade(settings: InMemorySettingsManager) -> AnalyticsServiceFacade {
        let appAttest = AppAttestServiceStub()

        let provider = BackendAttestationProvider(
            appAttest: appAttest,
            remoteFactory: BackendAttestationRemoteFactory(baseURL: gatewayURL),
            identity: BackendAttestationIdentity(settingsManager: settings),
            repository: AnyDataProviderRepository(SettingsAppAttestKeyRepository(settingsManager: settings)),
            gatewayURL: gatewayURL,
            mode: .appAttest,
            appIdentity: AppAttestAppIdentity(appId: "PREFIX.io.novafoundation.novawallet", environment: "development"),
            operationQueue: operationQueue,
            logger: SilentLogger()
        )

        let configuration = AnalyticsConfiguration(
            attestationProvider: AnalyticsAttestationSourceStub(
                attestation: AnalyticsAttestation(gatewayURL: gatewayURL, provider: provider)
            ),
            appAttestService: appAttest,
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

    private func storedKeyRows(in settings: InMemorySettingsManager) -> [String: AppAttestKeySettings]? {
        settings.value(of: [String: AppAttestKeySettings].self, for: "appAttestKeys")
    }

    private func drainQueues() {
        operationQueue.waitUntilAllOperationsAreFinished()
        analyticsQueue.waitUntilAllOperationsAreFinished()
        operationQueue.waitUntilAllOperationsAreFinished()
    }
}
