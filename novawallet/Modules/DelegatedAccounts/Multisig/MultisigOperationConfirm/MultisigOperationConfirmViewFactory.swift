import Foundation
import Operation_iOS
import Foundation_iOS

struct MultisigOperationConfirmViewFactory {
    static func createView(for operation: Multisig.PendingOperation) -> MultisigOperationConfirmViewProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(for: operation.chainId),
            let asset = chain.utilityAsset(),
            let multisigWallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: operation,
                multisigWallet: multisigWallet,
                chain: chain,
                currencyManager: currencyManager
            )
        else {
            return nil
        }

        let wireframe = MultisigOperationConfirmWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = MultisigOperationConfirmViewModelFactory(
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            networkViewModelFactory: NetworkViewModelFactory(),
            utilityBalanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = MultisigOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain,
            multisigWallet: multisigWallet,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = MultisigOperationConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for operation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        chain: ChainModel,
        currencyManager: CurrencyManagerProtocol
    ) -> MultisigOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let multisig = multisigWallet.multisigAccount?.multisig,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createMetaAccountRepository(for: nil, sortDescriptors: [])

        let walletRemoteWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: WalletServiceFacade.sharedSubstrateRemoteSubscriptionService
        )

        return if operation.isCreator(accountId: multisig.signatory) {
            MultisigOperationRejectInteractor(
                operation: operation,
                chain: chain,
                multisigWallet: multisigWallet,
                priceLocalSubscriptionFactory: PriceProviderFactory.shared,
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                balanceRemoteSubscriptionFactory: walletRemoteWrapper,
                signatoryRepository: MultisigSignatoryRepository(repository: walletRepository),
                pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
                extrinsicServiceFactory: extrinsicServiceFactory,
                signingWrapperFactory: SigningWrapperFactory(),
                assetInfoOperationFactory: AssetStorageInfoOperationFactory(),
                chainRegistry: chainRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                currencyManager: currencyManager,
                logger: Logger.shared
            )
        } else {
            MultisigOperationApproveInteractor(
                operation: operation,
                chain: chain,
                multisigWallet: multisigWallet,
                priceLocalSubscriptionFactory: PriceProviderFactory.shared,
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                balanceRemoteSubscriptionFactory: walletRemoteWrapper,
                signatoryRepository: MultisigSignatoryRepository(repository: walletRepository),
                pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
                extrinsicServiceFactory: extrinsicServiceFactory,
                signingWrapperFactory: SigningWrapperFactory(),
                assetInfoOperationFactory: AssetStorageInfoOperationFactory(),
                chainRegistry: chainRegistry,
                callWeightEstimator: CallWeightEstimatingFactory(),
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                currencyManager: currencyManager,
                logger: Logger.shared
            )
        }
    }
}
