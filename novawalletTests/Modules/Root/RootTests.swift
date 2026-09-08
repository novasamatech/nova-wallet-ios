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
        var order: [String] = []
        let migrator = MockMigrating()
        stub(migrator) { stub in when(stub.migrate()).then { order.append("migrate") } }
        let analyticsFacade = MockAnalyticsServiceFacadeProtocol()
        stub(analyticsFacade) { stub in when(stub.setup()).then { order.append("analytics") } }
        let walletOperationQueue = RecordingOperationQueue()
        walletOperationQueue.onAdd = { order.append("walletSettings") }

        let presenter = createPresenter(
            wireframe: MockRootWireframeProtocol(),
            walletSettings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: walletOperationQueue),
            settings: InMemorySettingsManager(),
            keystore: InMemoryKeychain(),
            migrators: [migrator],
            analyticsFacade: analyticsFacade
        )

        presenter.interactor.setup()

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

        let silentAnalyticsFacade = MockAnalyticsServiceFacadeProtocol()
        stub(silentAnalyticsFacade) { stub in when(stub.setup()).thenDoNothing() }

        let interactor = RootInteractor(
            walletSettings: walletSettings,
            settings: settings,
            keystore: keystore,
            applicationConfig: ApplicationConfig.shared,
            securityLayerInteractor: actualSecurityLayerInteractor,
            chainRegistryClosure: { chainRegistry },
            eventCenter: MockEventCenterProtocol(),
            analyticsFacade: analyticsFacade ?? silentAnalyticsFacade,
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

private final class RecordingOperationQueue: OperationQueue {
    var onAdd: (() -> Void)?

    override func addOperation(_ operation: Operation) {
        onAdd?()
        super.addOperation(operation)
    }
}
