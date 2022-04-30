import XCTest
@testable import novawallet
import Cuckoo
import SoraKeystore
import SoraFoundation
import RobinHood

class DAppBrowserTests: XCTestCase {
    let dAppURL = "https://polkadot.js.org/apps"

    let dAppChain = ChainModelGenerator.generateChain(
        generatingAssets: 2,
        addressPrefix: 42,
        hasCrowdloans: true
    )

    func testSetupCompletion() throws {
        // given

        let view = MockDAppBrowserViewProtocol()
        let wireframe = MockDAppBrowserWireframeProtocol()

        let keychain = InMemoryKeychain()
        let operationQueue = OperationQueue()

        let storageFacade = UserDataStorageTestFacade()
        let walletSettings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: walletSettings
        )

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [dAppChain])

        let dAppSettingsRepository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(DAppSettingsMapper())
        )

        let transport = DAppPolkadotExtensionTransport()

        let phishingVerifier = PhishingSiteVerifier.createSequentialVerifier(
            for: SubstrateStorageTestFacade()
        )

        let dAppLocalProviderFactory = DAppLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let dAppsFavoriteRepository = AccountRepositoryFactory(
            storageFacade: storageFacade
        ).createFavoriteDAppsRepository()

        let interactor = DAppBrowserInteractor(
            transports: [transport],
            userQuery: .query(string: dAppURL),
            wallet: walletSettings.value,
            chainRegistry: chainRegistry,
            dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
            dAppsLocalSubscriptionFactory: dAppLocalProviderFactory,
            dAppsFavoriteRepository: dAppsFavoriteRepository,
            operationQueue: OperationQueue(),
            sequentialPhishingVerifier: phishingVerifier
        )

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        var loadedModel: DAppBrowserModel?

        let loadingExpectation = XCTestExpectation()
        let favoritesExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { viewModel in
                loadedModel = viewModel

                loadingExpectation.fulfill()
            }

            when(stub).didReceiveFavorite(flag: any()).then { _ in
                favoritesExpectation.fulfill()
            }
        }

        presenter.setup()

        presenter.process(page: DAppBrowserPage(url: URL(string: "https://google.com")!, title: "google"))

        // then

        wait(for: [loadingExpectation, favoritesExpectation], timeout: 10)

        XCTAssertEqual(loadedModel?.url, URL(string: dAppURL)!)

        if (transport.state as? DAppBrowserWaitingAuthState) == nil {
            XCTFail("Waiting auth state expected after setup")
        }

        verify(view, times(1)).didReceiveFavorite(flag: any())
        XCTAssertNotNil(presenter.favorites)
        XCTAssertNotNil(presenter.browserPage)
    }
}
