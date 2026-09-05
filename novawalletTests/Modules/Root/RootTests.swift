import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import NovaAnalytics

class RootTests: XCTestCase {
    func testOnboardingDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let presenter = createPresenter(
            wireframe: wireframe,
            walletSettings: walletSettings,
            settings: settings,
            keystore: keystore
        )

        let onboardingExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showOnboarding(on: any())).then { _ in
                onboardingExpectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(
            for: [onboardingExpectation],
            timeout: Constants.defaultExpectationDuration
        )

        XCTAssertFalse(try keystore.checkKey(for: KeystoreTag.pincode.rawValue))
    }

    func testPincodeSetupDecision() {
        // given

        let wireframe = MockRootWireframeProtocol()
        let settings = InMemorySettingsManager()

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        walletSettings.save(value: selectedAccount)

        let keystore = InMemoryKeychain()

        let presenter = createPresenter(
            wireframe: wireframe,
            walletSettings: walletSettings,
            settings: settings,
            keystore: keystore
        )

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showPincodeSetup(on: any())).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    func testMainScreenDecision() throws {
        // given

        let wireframe = MockRootWireframeProtocol()

        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()
        walletSettings.save(value: selectedAccount)

        let expectedPincode = "123456"
        try keystore.saveKey(
            expectedPincode.data(using: .utf8)!,
            with: KeystoreTag.pincode.rawValue
        )

        let presenter = createPresenter(
            wireframe: wireframe,
            walletSettings: walletSettings,
            settings: settings,
            keystore: keystore
        )

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.showLocalAuthentication(on: any())).then { _ in
                expectation.fulfill()
            }
        }

        // when

        presenter.interactor.decideModuleSynchroniously()

        // then

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    func testAnalyticsSetupRunsBetweenTheMigratorsAndTheWalletSettings() {
        // given

        var order: [String] = []

        let migrator = MockMigrating()

        stub(migrator) { stub in
            when(stub.migrate()).then { order.append("migrate") }
        }

        let analyticsFacade = MockAnalyticsServiceFacadeProtocol()

        stub(analyticsFacade) { stub in
            when(stub.setup()).then { order.append("analytics") }
        }

        // walletSettings.setup reaches its store by adding one operation to the queue it
        // was built with, so the queue is a faithful "wallet settings started" probe.
        let walletOperationQueue = RecordingOperationQueue { order.append("walletSettings") }

        let walletSettings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: walletOperationQueue
        )

        let presenter = createPresenter(
            wireframe: MockRootWireframeProtocol(),
            walletSettings: walletSettings,
            settings: InMemorySettingsManager(),
            keystore: InMemoryKeychain(),
            migrators: [migrator],
            analyticsFacade: analyticsFacade
        )

        // when

        presenter.interactor.setup()

        // then

        // The ordering is not about store contention — analytics owns its own sqlite — but
        // about staying inside loadOnLaunch(), which AppDelegate runs before it clears
        // `isAppFirstLaunch`; see RootInteractor.setup().
        XCTAssertEqual(order, ["migrate", "analytics", "walletSettings"])
    }

    private func createPresenter(
        wireframe: MockRootWireframeProtocol,
        walletSettings: SelectedWalletSettings,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        securityLayerInteractor: SecurityLayerInteractorInputProtocol? = nil,
        migrators: [Migrating] = [],
        analyticsFacade: AnalyticsServiceFacadeProtocol? = nil
    ) -> RootPresenter {
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: Set())
        let actualSecurityLayerInteractor: SecurityLayerInteractorInputProtocol

        if let securityLayerInteractor = securityLayerInteractor {
            actualSecurityLayerInteractor = securityLayerInteractor
        } else {
            let mockLayer = MockSecurityLayerInteractorInputProtocol()

            stub(mockLayer) { stub in
                when(stub.setup()).thenDoNothing()
            }

            actualSecurityLayerInteractor = mockLayer
        }

        let actualAnalyticsFacade: AnalyticsServiceFacadeProtocol

        if let analyticsFacade = analyticsFacade {
            actualAnalyticsFacade = analyticsFacade
        } else {
            let mockFacade = MockAnalyticsServiceFacadeProtocol()

            stub(mockFacade) { stub in
                when(stub.setup()).thenDoNothing()
            }

            actualAnalyticsFacade = mockFacade
        }

        let interactor = RootInteractor(
            walletSettings: walletSettings,
            settings: settings,
            keystore: keystore,
            applicationConfig: ApplicationConfig.shared,
            securityLayerInteractor: actualSecurityLayerInteractor,
            chainRegistryClosure: { chainRegistry },
            eventCenter: MockEventCenterProtocol(),
            analyticsFacade: actualAnalyticsFacade,
            migrators: migrators
        )
        let presenter = RootPresenter()

        presenter.view = UIWindow()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        stub(wireframe) { stub in
            when(stub.showOnboarding(on: any())).thenDoNothing()
            when(stub.showLocalAuthentication(on: any())).thenDoNothing()
            when(stub.showPincodeSetup(on: any())).thenDoNothing()
            when(stub.showBroken(on: any())).thenDoNothing()
        }

        return presenter
    }
}

/// A probe, not a protocol double: Cuckoo cannot generate a mock for a Foundation class,
/// and the only thing the test needs is the moment an operation is scheduled.
private final class RecordingOperationQueue: OperationQueue {
    private let onAdd: () -> Void

    init(onAdd: @escaping () -> Void) {
        self.onAdd = onAdd

        super.init()
    }

    override func addOperation(_ operation: Operation) {
        onAdd()

        super.addOperation(operation)
    }
}
