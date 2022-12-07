import Foundation
import SoraFoundation

extension TransferSetupPresenterFactory {
    func createCrossChainPresenter(
        for originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        initialState: TransferSetupInputState,
        view: TransferSetupChildViewProtocol
    ) -> TransferSetupChildPresenterProtocol? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: originChainAsset,
                destinationChainAsset: destinationChainAsset,
                xcmTransfers: xcmTransfers
            ) else {
            return nil
        }

        let wireframe = CrossChainTransferSetupWireframe(xcmTransfers: xcmTransfers)
        //  wireframe.commandFactory = commandFactory

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let sendBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: originChainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = originChainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != originChainAsset.asset.assetId {
            let utilityAssetInfo = utilityAsset.displayInfo(with: originChainAsset.chain.icon)
            utilityBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAssetInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        } else {
            utilityBalanceViewModelFactory = nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: originChainAsset.assetDisplayInfo,
            utilityAssetInfo: originChainAsset.chain.utilityAssets().first?.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let phishingRepository = SubstrateRepositoryFactory().createPhishingRepository()
        let phishingValidatingFactory = PhishingAddressValidatorFactory(
            repository: phishingRepository,
            presentable: wireframe,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let presenter = CrossChainTransferSetupPresenter(
            wallet: wallet,
            interactor: interactor,
            wireframe: wireframe,
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            initialState: initialState,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            phishingValidatingFactory: phishingValidatingFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        phishingValidatingFactory.view = view
        interactor.presenter = presenter

        return presenter
    }

    private func createInteractor(
        for originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers
    ) -> CrossChainTransferSetupInteractor? {
        guard let selectedAccount = wallet.fetch(for: originChainAsset.chain.accountRequest()),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let walletRemoteSubscriptionService = WalletServiceFacade.sharedRemoteSubscriptionService

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService,
            chainRegistry: chainRegistry,
            repositoryFactory: repositoryFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let extrinsicService = XcmTransferService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let resolutionFactory = XcmTransferResolutionFactory(
            chainRegistry: chainRegistry,
            paraIdOperationFactory: ParaIdOperationFactory.shared
        )

        return CrossChainTransferSetupInteractor(
            selectedAccount: selectedAccount,
            xcmTransfers: xcmTransfers,
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            chainRegistry: chainRegistry,
            feeProxy: XcmExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            resolutionFactory: resolutionFactory,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
