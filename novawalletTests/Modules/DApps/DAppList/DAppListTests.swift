import XCTest
@testable import novawallet
import SoraKeystore
import SoraFoundation
import Cuckoo
import Operation_iOS

class DAppListTests: XCTestCase {
    func testSuccessSetup() throws {
        // given

        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let operationQueue = OperationQueue()

        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: walletSettings
        )

        let view = MockDAppListViewProtocol()
        let wireframe = MockDAppListWireframeProtocol()

        let dAppProvider = SingleValueProviderStub(
            item: DAppListGenerator.createAnyDAppList()
        )

        let phishingSyncService = MockApplicationServiceProtocol()
        phishingSyncService.applyDefaultStub()

        let dappLocalProviderFactory = DAppLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )
        let streamableProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateStorageTestFacade(),
            operationManager: OperationManagerFacade.sharedManager
        )
        
        let mapper = DAppFavoriteMapper()
        let dappsFavoriteRepository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let proxyListLocalSubscriptionFactory = ProxyListLocalSubscriptionFactory(
            chainRegistry: ChainRegistryProtocolStub(),
            streamableProviderFactory: streamableProviderFactory,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )
        let walletNotificationService = WalletNotificationService(
            proxyListLocalSubscriptionFactory: proxyListLocalSubscriptionFactory,
            logger: Logger.shared
        )
        
        let interactor = DAppListInteractor(
            walletSettings: walletSettings,
            eventCenter: EventCenter.shared,
            dAppProvider: AnySingleValueProvider(dAppProvider),
            phishingSyncService: phishingSyncService,
            dAppsLocalSubscriptionFactory: dappLocalProviderFactory,
            dAppsFavoriteRepository: AnyDataProviderRepository(dappsFavoriteRepository),
            walletNotificationService: walletNotificationService,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        
        let dAppCategoryViewModelFactory = DAppCategoryViewModelFactory()
        
        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: dAppCategoryViewModelFactory
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            categoryViewModelFactory: dAppCategoryViewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let iconExpectation = XCTestExpectation()

        let stateExpectation = XCTestExpectation()

        var actualState: DAppListState? = nil

        stub(view) { stub in
            stub.didReceive(state: any()).then { state in
                guard case .loaded = state else {
                    return
                }

                actualState = state

                stateExpectation.fulfill()
            }

            stub.didCompleteRefreshing().thenDoNothing()

            stub.didReceiveWalletSwitch(viewModel: any()).then { _ in
                iconExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(for: [iconExpectation, stateExpectation], timeout: 10.0)

        switch actualState {
        case .loading, .error, .none:
            XCTFail("Unexpected final state")
        case .loaded:
            break
        }

        verify(phishingSyncService, times(1)).setup()
    }
}
