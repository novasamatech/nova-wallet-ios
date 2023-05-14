import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

struct TransferSetupViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        recepient: DisplayAddress?
    ) -> TransferSetupViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard let interactor = createInteractor(for: chainAsset) else {
            return nil
        }

        let initPresenterState = TransferSetupInputState(recepient: recepient?.address, amount: nil)

        let presenterFactory = createPresenterFactory(for: wallet)

        let localizationManager = LocalizationManager.shared

        let wireframe = TransferSetupWireframe()

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)
        let viewModelFactory = Web3NameViewModelFactory(displayAddressViewModelFactory: DisplayAddressViewModelFactory())

        let presenter = TransferSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            originChainAsset: chainAsset,
            childPresenterFactory: presenterFactory,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            networkViewModelFactory: networkViewModelFactory,
            web3NameViewModelFactory: viewModelFactory,
            logger: Logger.shared
        )

        let view = TransferSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.childPresenter = presenterFactory.createOnChainPresenter(
            for: chainAsset,
            initialState: initPresenterState,
            view: view
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenterFactory(
        for wallet: MetaAccountModel) -> TransferSetupPresenterFactory {
        TransferSetupPresenterFactory(
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for chainAsset: ChainAsset
    ) -> TransferSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let syncService = XcmTransfersSyncService(
            remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainsStore = ChainsStore(chainRegistry: chainRegistry)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        let web3NameService = createWeb3NameService()

        return TransferSetupInteractor(
            originChainAssetId: chainAsset.chainAssetId,
            xcmTransfersSyncService: syncService,
            chainsStore: chainsStore,
            accountRepository: accountRepository,
            web3NamesService: web3NameService,
            operationManager: OperationManager()
        )
    }

    private static func createWeb3NameService() -> Web3NameServiceProtocol? {
        let kiltChainId = KnowChainId.kiltOnEnviroment
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let kiltConnection = chainRegistry.getConnection(for: kiltChainId),
              let kiltRuntimeService = chainRegistry.getRuntimeProvider(for: kiltChainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let web3NamesOperationFactory = KiltWeb3NamesOperationFactory(operationQueue: operationQueue)

        let recipientRepository = KiltTransferAssetRecipientRepository(integrityVerifier: Web3NameIntegrityVerifier())

        let slip44CoinsUrl = ApplicationConfig.shared.slip44URL
        let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList> = JsonDataProviderFactory.shared.getJson(
            for: slip44CoinsUrl
        )

        return Web3NameService(
            providerName: Web3NameProvider.kilt,
            slip44CoinsProvider: slip44CoinsProvider,
            web3NamesOperationFactory: web3NamesOperationFactory,
            runtimeService: kiltRuntimeService,
            connection: kiltConnection,
            transferRecipientRepository: recipientRepository,
            operationQueue: operationQueue
        )
    }
}
