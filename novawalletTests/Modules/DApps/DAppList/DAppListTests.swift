import XCTest
@testable import novawallet
import Keystore_iOS
import Foundation_iOS
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

        let interactor = DAppListInteractor(
            walletSettings: walletSettings,
            eventCenter: EventCenter.shared,
            dAppProvider: AnySingleValueProvider(dAppProvider),
            phishingSyncService: phishingSyncService,
            dAppsLocalSubscriptionFactory: dappLocalProviderFactory,
            dAppsFavoriteRepository: AnyDataProviderRepository(dappsFavoriteRepository),
            walletNotificationService: walletNotificationService,
            logger: Logger.shared
        )

        let viewModelFactory = DAppListViewModelFactory(
            dappCategoriesViewModelFactory: DAppCategoryViewModelFactory(),
            dappIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initialWallet: walletSettings.value,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        let iconExpectation = XCTestExpectation()
        let stateExpectation = XCTestExpectation()

        var sectionsModels: [DAppListSectionViewModel] = []

        stub(view) { stub in
            stub.didReceive(any()).then { sections in
                guard
                    !sections.isEmpty,
                    !sections.contains(where: { $0.model.cells.contains(.notLoaded) })
                else {
                    return
                }

                sectionsModels = sections

                stateExpectation.fulfill()

                let walletSection = sections
                    .first { section in
                        section.model.cells.contains(
                            where: { cell in
                                guard case let .header(header) = cell else { return false }

                                return true
                            }
                        )
                    }

                guard walletSection != nil else { return }

                iconExpectation.fulfill()
            }

            stub.didCompleteRefreshing().thenDoNothing()
        }

        presenter.setup()

        // then

        wait(for: [iconExpectation, stateExpectation], timeout: 10.0)

        let unexpectedFinalStates = sectionsModels.filter { model in
            switch model {
            case .error, .notLoaded:
                true
            default:
                false
            }
        }

        guard unexpectedFinalStates.isEmpty else {
            XCTFail("Unexpected final state")

            return
        }

        verify(phishingSyncService, times(1)).setup()
    }
}
