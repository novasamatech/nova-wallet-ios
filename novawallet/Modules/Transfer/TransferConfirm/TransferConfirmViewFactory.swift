import Foundation
import SoraFoundation

struct TransferConfirmViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        recepient: AccountAddress,
        amount: Decimal
    ) -> TransferConfirmViewProtocol? {
        guard let interactor = createInteractor(for: chainAsset) else {
            return nil
        }

        let walletSettings = SelectedWalletSettings.shared

        guard
            let wallet = walletSettings.value,
            let selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let senderAccountAddress = selectedAccount.toAddress() else {
            return nil
        }

        let wireframe = TransferConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let sendingBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != chainAsset.asset.assetId {
            let utilityAssetInfo = utilityAsset.displayInfo(with: chainAsset.chain.icon)
            utilityBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAssetInfo
            )
        } else {
            utilityBalanceViewModelFactory = nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            utilityAssetInfo: chainAsset.chain.utilityAssets().first?.displayInfo
        )

        let presenter = TransferConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            recepient: recepient,
            amount: amount,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager
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
        for chainAsset: ChainAsset
    ) -> TransferConfirmInteractor? {
        let walletSettings = SelectedWalletSettings.shared

        guard
            let selectedAccount = walletSettings.value.fetch(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared
        let repositoryFactory = SubstrateRepositoryFactory()
        let repository = repositoryFactory.createChainStorageItemRepository()
        let eventCenter = EventCenter.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let walletRemoteSubscriptionService = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: operationManager,
            logger: logger
        )

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService,
            chainRegistry: chainRegistry,
            repositoryFactory: repositoryFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        return TransferConfirmInteractor(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeProvider,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: operationQueue
        )
    }
}
