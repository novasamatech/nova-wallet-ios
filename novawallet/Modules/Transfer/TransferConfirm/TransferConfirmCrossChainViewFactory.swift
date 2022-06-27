import Foundation
import SoraFoundation
import SoraKeystore

// swiftlint:disable function_body_length
struct TransferConfirmCrossChainViewFactory {
    static func createView(
        originChainAsset: ChainAsset,
        destinationAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        recepient: AccountAddress,
        amount: Decimal
    ) -> TransferConfirmOnChainViewProtocol? {
        let walletSettings = SelectedWalletSettings.shared

        guard
            let wallet = walletSettings.value,
            let interactor = createInteractor(
                for: originChainAsset,
                destinationChainAsset: destinationAsset,
                xcmTransfers: xcmTransfers
            ) else {
            return nil
        }

        let wireframe = TransferConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let sendingBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: originChainAsset.assetDisplayInfo
        )

        let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = originChainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != originChainAsset.asset.assetId {
            let utilityAssetInfo = utilityAsset.displayInfo(with: originChainAsset.chain.icon)
            utilityBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAssetInfo
            )
        } else {
            utilityBalanceViewModelFactory = nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: originChainAsset.assetDisplayInfo,
            utilityAssetInfo: originChainAsset.chain.utilityAssets().first?.displayInfo
        )

        let presenter = TransferCrossChainConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            recepient: recepient,
            amount: amount,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = TransferConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        xcmTransfers: XcmTransfers
    ) -> TransferCrossChainConfirmInteractor? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetch(for: originChainAsset.chain.accountRequest()) else {
            return nil
        }

        let storageFacade = SubstrateDataStorageFacade.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let logger = Logger.shared
        let eventCenter = EventCenter.shared

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let repository = repositoryFactory.createChainStorageItemRepository()

        let walletRemoteSubscriptionService = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            logger: logger
        )

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService,
            chainRegistry: chainRegistry,
            repositoryFactory: repositoryFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        let extrinsicService = XcmTransferService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let resolutionFactory = XcmTransferResolutionFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let transactionStorage = repositoryFactory.createTxRepository()
        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: operationQueue
        )

        return TransferCrossChainConfirmInteractor(
            selectedAccount: selectedAccount,
            xcmTransfers: xcmTransfers,
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset,
            chainRegistry: chainRegistry,
            feeProxy: XcmExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            resolutionFactory: resolutionFactory,
            signingWrapper: SigningWrapper(keystore: Keychain(), metaId: wallet.metaId, accountResponse: selectedAccount),
            persistExtrinsicService: persistentExtrinsicService,
            eventCenter: eventCenter,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: operationQueue
        )
    }
}

// swiftlint:enable function_body_length
