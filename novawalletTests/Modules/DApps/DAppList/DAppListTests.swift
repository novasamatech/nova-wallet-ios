import XCTest
@testable import novawallet
import SoraKeystore
import SoraFoundation
import Cuckoo
import RobinHood

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

        let mapper = DAppFavoriteMapper()
        let dappsFavoriteRepository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let interactor = DAppListInteractor(
            walletSettings: walletSettings,
            eventCenter: EventCenter.shared,
            dAppProvider: AnySingleValueProvider(dAppProvider),
            phishingSyncService: phishingSyncService,
            dAppsLocalSubscriptionFactory: dappLocalProviderFactory,
            dAppsFavoriteRepository: AnyDataProviderRepository(dappsFavoriteRepository),
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppListViewModelFactory(),
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

            stub.didReceiveAccount(icon: any()).then { _ in
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
