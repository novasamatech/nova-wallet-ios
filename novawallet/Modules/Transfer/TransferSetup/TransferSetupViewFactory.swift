import Foundation
import SoraFoundation
import CommonWallet

struct TransferSetupViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        recepient: DisplayAddress?,
        commandFactory: WalletCommandFactoryProtocol?
    ) -> TransferSetupViewProtocol? {
        let walletSettings = SelectedWalletSettings.shared

        let interactor = createInteractor(for: chainAsset)
        let initPresenterState = TransferSetupInputState(recepient: recepient?.address, amount: nil)

        let presenterFactory = createPresenterFactory(for: walletSettings.value, commandFactory: commandFactory)

        let localizationManager = LocalizationManager.shared

        let wireframe = TransferSetupWireframe()

        let presenter = TransferSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            originChainAsset: chainAsset,
            childPresenterFactory: presenterFactory,
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
    ) -> TransferSetupInteractor {
        let syncService = XcmTransfersSyncService(
            remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsStore = ChainsStore(chainRegistry: ChainRegistryFacade.sharedRegistry)

        return TransferSetupInteractor(
            originChainAssetId: chainAsset.chainAssetId,
            xcmTransfersSyncService: syncService,
            chainsStore: chainsStore
        )
    }
}
