import Foundation
import Foundation_iOS
import BigInt

struct GiftClaimViewFactory {
    static func createView(
        info: ClaimableGiftInfo,
        totalAmount: BigUInt
    ) -> GiftClaimViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chain = chainRegistry.getChain(for: info.chainId),
            let chainAsset = chain.chainAssetForSymbol(info.assetSymbol),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let interactor: GiftClaimInteractor?

        if chainAsset.asset.isAnyEvm {
            interactor = createEvmInteractor(
                info: info,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry,
                totalAmount: totalAmount
            )
        } else {
            interactor = createSubstrateInteractor(
                info: info,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry,
                totalAmount: totalAmount
            )
        }

        guard let interactor else { return nil }

        let wireframe = GiftClaimWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let viewModelFactory = GiftClaimViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            assetIconViewModelFactory: AssetIconViewModelFactory()
        )

        let presenter = GiftClaimPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = GiftClaimViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

// MARK: - Private

private extension GiftClaimViewFactory {
    static func createSubstrateInteractor(
        info: ClaimableGiftInfo,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> GiftClaimInteractor? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedWallet.fetch(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: info.chainId),
            let connection = chainRegistry.getConnection(for: info.chainId)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let claimDescriptionFactory = ClaimableGiftDescriptionFactory(
            chainRegistry: chainRegistry,
            transferCommandFactory: SubstrateTransferCommandFactory(),
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy()
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createManagedMetaAccountRepository(for: nil, sortDescriptors: [])

        let walletOperationFactory = GiftClaimWalletOperationFactory(
            walletRepository: walletRepository
        )

        let extrinsicMonitorFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            connection: connection,
            runtimeService: runtimeProvider,
            operationQueue: operationQueue,
            logger: logger
        )

        let claimOperationFactory = GiftClaimFactoryFacade(
            operationQueue: operationQueue
        ).createSubstrateFactory(extrinsicMonitorFactory: extrinsicMonitorFactory)

        return SubstrateGiftClaimInteractor(
            claimDescriptionFactory: claimDescriptionFactory,
            claimOperationFactory: claimOperationFactory,
            chainRegistry: chainRegistry,
            giftInfo: info,
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(),
            walletOperationFactory: walletOperationFactory,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }

    static func createEvmInteractor(
        info: ClaimableGiftInfo,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> EvmGiftClaimInteractor? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedWallet.fetch(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: info.chainId),
            let connection = chainRegistry.getConnection(for: info.chainId)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createManagedMetaAccountRepository(for: nil, sortDescriptors: [])

        let walletOperationFactory = GiftClaimWalletOperationFactory(
            walletRepository: walletRepository
        )

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let gasLimitProvider = EvmGasLimitProviderFactory.createGasLimitProvider(
            for: chainAsset.asset,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            logger: logger
        )

        let nonceProvider = EvmDefaultNonceProvider(operationFactory: operationFactory)

        let transactionService = EvmTransactionService(
            accountId: selectedAccount.accountId,
            operationFactory: operationFactory,
            maxPriorityGasPriceProvider: EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory),
            defaultGasPriceProvider: EvmLegacyGasPriceProvider(operationFactory: operationFactory),
            gasLimitProvider: gasLimitProvider,
            nonceProvider: nonceProvider,
            chain: chainAsset.chain,
            operationQueue: operationQueue
        )

        let claimDescriptionFactory = EvmClaimableGiftDescriptionFactory(
            chainRegistry: chainRegistry,
            transferCommandFactory: EvmTransferCommandFactory(),
            transactionService: transactionService,
            feeProxy: EvmTransactionFeeProxy()
        )

        let claimOperationFactory = GiftClaimFactoryFacade(
            operationQueue: operationQueue
        ).createEvmFactory(transactionService: transactionService)

        return EvmGiftClaimInteractor(
            claimDescriptionFactory: claimDescriptionFactory,
            claimOperationFactory: claimOperationFactory,
            chainRegistry: chainRegistry,
            giftInfo: info,
            walletOperationFactory: walletOperationFactory,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }
}
