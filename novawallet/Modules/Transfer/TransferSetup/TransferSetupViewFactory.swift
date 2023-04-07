import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

struct TransferSetupViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        recepient: DisplayAddress?,
        commandFactory: WalletCommandFactoryProtocol?
    ) -> TransferSetupViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard let interactor = createInteractor(for: chainAsset) else {
            return nil
        }

        let initPresenterState = TransferSetupInputState(recepient: recepient?.address, amount: nil)

        let presenterFactory = createPresenterFactory(for: wallet, commandFactory: commandFactory)

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
        for wallet: MetaAccountModel,
        commandFactory: WalletCommandFactoryProtocol?
    ) -> TransferSetupPresenterFactory {
        TransferSetupPresenterFactory(
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            commandFactory: commandFactory,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for chainAsset: ChainAsset
    ) -> TransferSetupInteractor? {
        let kiltChainId = KnowChainId.kilt
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let slip44CoinsUrl = ApplicationConfig.shared.slip44URL
        let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList> = JsonDataProviderFactory.shared.getJson(
            for: slip44CoinsUrl
        )

        guard let kiltConnection = chainRegistry.getConnection(for: kiltChainId),
              let kiltRuntimeService = chainRegistry.getRuntimeProvider(for: kiltChainId) else {
            return nil
        }
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
        let operationQueue = OperationQueue()
        let web3NamesOperationFactory = KiltWeb3NamesOperationFactory(operationQueue: operationQueue)
        let web3NameService = Web3NameService(
            slip44CoinsProvider: slip44CoinsProvider,
            web3NamesOperationFactory: web3NamesOperationFactory,
            runtimeService: kiltRuntimeService,
            connection: kiltConnection,
            kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepository(),
            operationQueue: operationQueue
        )

        return TransferSetupInteractor(
            originChainAssetId: chainAsset.chainAssetId,
            xcmTransfersSyncService: syncService,
            chainsStore: chainsStore,
            accountRepository: accountRepository,
            web3NamesService: web3NameService,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
