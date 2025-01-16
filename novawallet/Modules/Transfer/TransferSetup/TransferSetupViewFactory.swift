import Foundation
import Foundation_iOS
import Operation_iOS

struct TransferSetupViewParams {
    let chainAsset: ChainAsset
    let whoChainAssetPeer: TransferSetupPeer
    let chainAssetPeers: [ChainAsset]?
    let recepient: DisplayAddress?
    let xcmTransfers: XcmTransfers?
}

enum TransferSetupViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        recepient: DisplayAddress?,
        transferCompletion: TransferCompletionClosure? = nil
    ) -> TransferSetupViewProtocol? {
        createView(
            from: .init(
                chainAsset: chainAsset,
                whoChainAssetPeer: .destination,
                chainAssetPeers: nil,
                recepient: recepient,
                xcmTransfers: nil
            ),
            wireframe: TransferSetupWireframe(),
            transferCompletion: transferCompletion
        )
    }

    static func createCrosschainView(
        from origins: [ChainAsset],
        to destination: ChainAsset,
        xcmTransfers: XcmTransfers?,
        assetListObservable: AssetListModelObservable,
        transferCompletion: TransferCompletionClosure? = nil
    ) -> TransferSetupViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let recepient = try? wallet.fetch(for: destination.chain.accountRequest())?.toDisplayAddress()

        return createView(
            from: .init(
                chainAsset: destination,
                whoChainAssetPeer: .origin,
                chainAssetPeers: origins,
                recepient: recepient,
                xcmTransfers: xcmTransfers
            ),
            wireframe: TransferSetupOriginSelectionWireframe(assetListObservable: assetListObservable),
            transferCompletion: transferCompletion
        )
    }

    static func createView(
        from params: TransferSetupViewParams,
        wireframe: TransferSetupWireframeProtocol,
        transferCompletion: TransferCompletionClosure?
    ) -> TransferSetupViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard let interactor = createInteractor(for: params) else {
            return nil
        }

        let initPresenterState = TransferSetupInputState(recepient: params.recepient?.address, amount: nil)

        let presenterFactory = createPresenterFactory(for: wallet, transferCompletion: transferCompletion)

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)
        let viewModelFactory = Web3NameViewModelFactory(
            displayAddressViewModelFactory: DisplayAddressViewModelFactory()
        )

        let presenter = TransferSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            chainAsset: params.chainAsset,
            whoChainAssetPeer: params.whoChainAssetPeer,
            chainAssetPeers: params.chainAssetPeers,
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

        if
            let peerChainAsset = params.chainAssetPeers?.first,
            peerChainAsset.chainAssetId != params.chainAsset.chainAssetId,
            let xcmTransfers = params.xcmTransfers {
            let origin: ChainAsset
            let destination: ChainAsset

            switch params.whoChainAssetPeer {
            case .origin:
                origin = peerChainAsset
                destination = params.chainAsset
            case .destination:
                origin = params.chainAsset
                destination = peerChainAsset
            }

            presenter.childPresenter = presenterFactory.createCrossChainPresenter(
                for: origin,
                destinationChainAsset: destination,
                xcmTransfers: xcmTransfers,
                initialState: initPresenterState,
                view: view
            )
        } else {
            presenter.childPresenter = presenterFactory.createOnChainPresenter(
                for: params.chainAsset,
                initialState: initPresenterState,
                view: view
            )
        }

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenterFactory(
        for wallet: MetaAccountModel,
        transferCompletion: TransferCompletionClosure?
    ) -> TransferSetupPresenterFactory {
        TransferSetupPresenterFactory(
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            logger: Logger.shared,
            transferCompletion: transferCompletion
        )
    }

    private static func createInteractor(for params: TransferSetupViewParams) -> TransferSetupInteractor? {
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
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let web3NameService = Web3NameServiceFactory(operationQueue: operationQueue).createService()

        return TransferSetupInteractor(
            chainAsset: params.chainAsset,
            whoChainAssetPeer: params.whoChainAssetPeer,
            restrictedChainAssetPeers: params.chainAssetPeers,
            xcmTransfersSyncService: syncService,
            chainsStore: chainsStore,
            accountRepository: accountRepository,
            web3NamesService: web3NameService,
            operationManager: OperationManager()
        )
    }
}
