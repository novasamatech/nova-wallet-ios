import Foundation
import Operation_iOS
import Foundation_iOS

struct MultisigOperationConfirmViewFactory {
    static func createView(
        for operation: Multisig.PendingOperationProxyModel,
        flowState: MultisigOperationsFlowState
    ) -> MultisigOperationConfirmViewProtocol? {
        guard
            let chain = ChainRegistryFacade.sharedRegistry.getChain(
                for: operation.operation.chainId
            ),
            let asset = chain.utilityAsset(),
            let multisigWallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: operation,
                multisigWallet: multisigWallet,
                chain: chain,
                currencyManager: currencyManager,
                flowState: flowState
            )
        else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let wireframe = MultisigOperationConfirmWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = MultisigOperationConfirmViewModelFactory(
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            networkViewModelFactory: NetworkViewModelFactory(),
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let dataValidatorFactory = MultisigDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = MultisigOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            dataValidationFactory: dataValidatorFactory,
            chain: chain,
            multisigWallet: multisigWallet,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = MultisigOperationConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        dataValidatorFactory.view = view

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable:next function_body_length
    private static func createInteractor(
        for operation: Multisig.PendingOperationProxyModel,
        multisigWallet: MetaAccountModel,
        chain: ChainModel,
        currencyManager: CurrencyManagerProtocol,
        flowState: MultisigOperationsFlowState
    ) -> MultisigOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let multisig = multisigWallet.getMultisig(
                for: chain
            ),
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

        let pendingOperationsProvider = MultisigOperationProviderProxy(
            pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactory.shared,
            callFormattingFactory: CallFormattingOperationFactory(
                chainRegistry: chainRegistry,
                walletRepository: walletRepository
            ),
            operationQueue: operationQueue
        )

        flowState.providerSnapshot.apply(to: pendingOperationsProvider)

        return if operation.operation.isCreator(accountId: multisig.signatory) {
            MultisigOperationRejectInteractor(
                operation: operation,
                chain: chain,
                multisigWallet: multisigWallet,
                priceLocalSubscriptionFactory: PriceProviderFactory.shared,
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                balanceRemoteSubscriptionFactory: walletRemoteWrapper,
                signatoryRepository: MultisigSignatoryRepository(repository: walletRepository),
                pendingOperationProvider: pendingOperationsProvider,
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
                pendingOperationProvider: pendingOperationsProvider,
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
