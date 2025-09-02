import Foundation
import Foundation_iOS
import Keystore_iOS

// swiftlint:disable function_body_length
struct TransferConfirmCrossChainViewFactory {
    static func createView(
        originChainAsset: ChainAsset,
        destinationAsset: ChainAsset,
        xcmTransfers: XcmTransfers,
        recepient: AccountAddress,
        amount: Decimal,
        transferCompletion: TransferCompletionClosure?
    ) -> TransferConfirmOnChainViewProtocol? {
        let walletSettings = SelectedWalletSettings.shared

        guard
            let wallet = walletSettings.value,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: originChainAsset,
                destinationChainAsset: destinationAsset,
                xcmTransfers: xcmTransfers
            ) else {
            return nil
        }

        let wireframe = TransferConfirmWireframe()

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let networkViewModelFactory = NetworkViewModelFactory()
        let sendingBalanceViewModelFactory = BalanceViewModelFactory(
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

        guard
            let utilityAssetInfo = originChainAsset.chain.utilityAssetDisplayInfo(),
            let destUtilityAssetInfo = destinationAsset.chain.utilityAssetDisplayInfo()
        else {
            return nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: originChainAsset.assetDisplayInfo,
            utilityAssetInfo: utilityAssetInfo,
            destUtilityAssetInfo: destUtilityAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
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
            transferCompletion: transferCompletion,
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
            let selectedAccount = wallet.fetch(for: originChainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let storageFacade = SubstrateDataStorageFacade.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let eventCenter = EventCenter.shared

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let walletRemoteSubscriptionService = WalletServiceFacade.sharedSubstrateRemoteSubscriptionService

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService
        )

        let extrinsicService = XcmTransferService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: operationQueue
        )

        let resolutionFactory = XcmTransferResolutionFactory(
            chainRegistry: chainRegistry,
            paraIdOperationFactory: ParaIdOperationFactory.shared
        )

        let transactionStorage = repositoryFactory.createTxRepository()
        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: operationQueue
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: wallet.metaId,
            accountResponse: selectedAccount
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
            signingWrapper: signingWrapper,
            persistExtrinsicService: persistentExtrinsicService,
            eventCenter: eventCenter,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            persistenceFilter: AccountTypeExtrinsicPersistenceFilter(),
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

// swiftlint:enable function_body_length
