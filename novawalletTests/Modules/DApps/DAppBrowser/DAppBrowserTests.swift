import XCTest
@testable import novawallet
import Cuckoo
import Keystore_iOS
import Foundation_iOS
import Operation_iOS

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

        let dAppGlobalSettingsRepository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(DAppGlobalSettingsMapper())
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

        let tabManager = DAppBrowserTabManager.shared

        let tab = DAppBrowserTab(
            from: dAppURL,
            metaId: walletSettings.value.metaId
        )!

        let appAttestService = AppAttestService()
        let remoteAttestationFactory = DAppRemoteAttestFactory()

        let mapper = AnyCoreDataMapper(AppAttestBrowserSettingsMapper())

        let coreDataRepository: CoreDataRepository<AppAttestBrowserSettings, CDAppAttestBrowserSettings> = storageFacade.createRepository(mapper: mapper)

        let attestationProvider = DAppAttestationProvider(
            appAttestService: appAttestService,
            remoteAttestationFactory: remoteAttestationFactory,
            attestationRepository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: operationQueue
        )

        let attestHandler = DAppAttestHandler(
            attestationProvider: attestationProvider,
            operationQueue: operationQueue
        )

        let interactor = DAppBrowserInteractor(
            transports: [transport],
            selectedTab: tab,
            wallet: walletSettings.value,
            chainRegistry: chainRegistry,
            securedLayer: SecurityLayerService.shared,
            dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
            dAppGlobalSettingsRepository: AnyDataProviderRepository(dAppGlobalSettingsRepository),
            dAppsLocalSubscriptionFactory: dAppLocalProviderFactory,
            dAppsFavoriteRepository: dAppsFavoriteRepository,
            operationQueue: OperationQueue(),
            sequentialPhishingVerifier: phishingVerifier,
            tabManager: tabManager,
            applicationHandler: ApplicationHandler(),
            attestHandler: attestHandler,
            logger: Logger.shared
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
        let enableSettingsExpectation = XCTestExpectation()
        let favoriteExpectation = XCTestExpectation()
        let tabCountExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.didReceive(viewModel: any())).then { viewModel in
                loadedModel = viewModel

                loadingExpectation.fulfill()
            }

            when(stub.didSet(favorite: any())).then { _ in
                favoriteExpectation.fulfill()
            }

            when(stub.didReceiveTabsCount(viewModel: any())).then { _ in
                tabCountExpectation.fulfill()
            }

            when(stub.didSet(canShowSettings: any())).then { canShowSettings in
                if canShowSettings {
                    enableSettingsExpectation.fulfill()
                }
            }
        }

        presenter.setup()

        presenter.process(page: DAppBrowserPage(url: URL(string: "https://google.com")!, title: "google"))

        // then

        wait(
            for: [
                loadingExpectation,
                enableSettingsExpectation,
                favoriteExpectation,
                tabCountExpectation
            ],
            timeout: 10
        )

        XCTAssertEqual(loadedModel?.selectedTab.url, URL(string: dAppURL)!)

        if (transport.state as? DAppBrowserWaitingAuthState) == nil {
            XCTFail("Waiting auth state expected after setup")
        }

        XCTAssertNotNil(presenter.browserPage)
    }
}
