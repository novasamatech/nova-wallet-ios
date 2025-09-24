import XCTest
@testable import novawallet
import SubstrateSdk
import Keystore_iOS
import Foundation_iOS
import Cuckoo

final class SettingsTests: XCTestCase {
    func testSettingsSuccessfullyLoaded() throws {
        // given

        let storageFacade = UserDataStorageTestFacade()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )

        let selectedAccount = AccountGenerator.generateMetaAccount()

        walletSettings.save(value: selectedAccount)

        let view = MockSettingsViewProtocol()

        let accountViewModelExpectation = XCTestExpectation()
        let sectionsExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).isSetup.get.thenReturn(false, true)

            when(stub).didLoad(userViewModel: any()).then { _ in
                accountViewModelExpectation.fulfill()
            }

            when(stub).reload(sections: any()).then { _ in
                sectionsExpectation.fulfill()
            }
        }
        
        let biometryAuthMock = MockBiometryAuth()
        
        stub(biometryAuthMock) { stub in
            when(stub).availableBiometryType.get.thenReturn(.none)
            when(stub).supportedBiometryType.get.thenReturn(.none)
        }

        let wireframe = MockSettingsWireframeProtocol()

        let eventCenter = MockEventCenterProtocol()
        let streamableProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateStorageTestFacade(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        let walletConnect = MockWalletConnectDelegateInputProtocol()
        let proxyListLocalSubscriptionFactory = ProxyListLocalSubscriptionFactory(
            chainRegistry: ChainRegistryProtocolStub(),
            streamableProviderFactory: streamableProviderFactory,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )
        let multisigListLocalSubscriptionFactory = MultisigListLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )
        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: proxyListLocalSubscriptionFactory,
            multisigListLocalSubscriptionFactory: multisigListLocalSubscriptionFactory,
            logger: Logger.shared
        )
        
        stub(walletConnect) { stub in
            when(stub).add(delegate: any()).thenDoNothing()
            when(stub).connect(uri: any(), completion: any()).thenDoNothing()
            when(stub).remove(delegate: any()).thenDoNothing()
            when(stub).getSessionsCount().thenReturn(0)
            when(stub).fetchSessions(any()).then { closure in
                closure(.success([]))
            }
            when(stub).disconnect(from: any(), completion: any()).then { session, completion in
                completion(nil)
            }
        }
        
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
      
        let pushNotificationsFacade = MockPushNotificationsServiceFacadeProtocol()
        stub(pushNotificationsFacade) { stub in
            when(stub).subscribeStatus(any(), closure: any()).then { _, closure in
                closure(.unknown, .active)
            }
        }

        let interactor = SettingsInteractor(
            selectedWalletSettings: walletSettings,
            eventCenter: eventCenter,
            walletConnect: walletConnect,
            currencyManager: CurrencyManagerStub(),
            settingsManager: InMemorySettingsManager(),
            biometryAuth: biometryAuthMock,
            walletNotificationService: walletNotificationService,
            pushNotificationsFacade: pushNotificationsFacade,
            privacyStateManager: PrivacyStateManager.shared,
            operationQueue: operationQueue
        )

        let viewModelFactory = SettingsViewModelFactory(
            iconGenerator: NovaIconGenerator(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = SettingsPresenter(
            viewModelFactory: viewModelFactory,
            config: ApplicationConfig.shared,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: nil
        )

        stub(eventCenter) { stub in
            when(stub).add(observer: any(), dispatchIn: any()).thenDoNothing()
        }

        presenter.view = view
        interactor.presenter = presenter

        // when

        presenter.setup()

        // then

        wait(for: [accountViewModelExpectation, sectionsExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
