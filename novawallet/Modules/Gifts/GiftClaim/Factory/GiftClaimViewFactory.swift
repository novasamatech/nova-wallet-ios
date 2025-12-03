import Foundation
import Foundation_iOS
import Keystore_iOS
import BigInt

struct GiftClaimViewFactory {
    static func createView(
        giftPayload: ClaimGiftPayload,
        totalAmount: BigUInt
    ) -> GiftClaimViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainId = giftPayload.chainAssetId.chainId
        let assetId = giftPayload.chainAssetId.assetId

        guard
            let currencyManager = CurrencyManager.shared,
            let chain = chainRegistry.getChain(for: chainId),
            let chainAsset = chain.chainAsset(for: assetId)
        else { return nil }

        let interactor: GiftClaimInteractor?

        if chainAsset.asset.isAnyEvm {
            interactor = createEvmInteractor(
                claimableGift: giftPayload,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry,
                totalAmount: totalAmount
            )
        } else {
            interactor = createSubstrateInteractor(
                claimableGift: giftPayload,
                chain: chainAsset.chain,
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
        claimableGift: ClaimGiftPayload,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> GiftClaimInteractor? {
        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let logger = Logger.shared

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createServiceForGiftClaim(accountId: claimableGift.accountId, chain: chain)

        let claimDescriptionFactory = SubstrateGiftDescriptionFactory(
            chainRegistry: chainRegistry,
            transferCommandFactory: SubstrateTransferCommandFactory(),
            extrinsicService: extrinsicService,
            callbackQueue: .main
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
            operationQueue: operationQueue,
            keystore: InMemoryKeychain()
        ).createSubstrateFactory(extrinsicMonitorFactory: extrinsicMonitorFactory)

        return SubstrateGiftClaimInteractor(
            claimDescriptionFactory: claimDescriptionFactory,
            claimOperationFactory: claimOperationFactory,
            chainRegistry: chainRegistry,
            claimableGift: claimableGift,
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(),
            walletOperationFactory: walletOperationFactory,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }

    static func createEvmInteractor(
        claimableGift: ClaimGiftPayload,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> EvmGiftClaimInteractor? {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else { return nil }

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
            accountId: claimableGift.accountId,
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
            callbackQueue: .main
        )

        let transactionMonitorFactory = TransactionSubmitMonitorFactory(
            submissionService: transactionService,
            evmOperationFactory: operationFactory,
            operationQueue: operationQueue
        )

        let claimOperationFactory = GiftClaimFactoryFacade(
            operationQueue: operationQueue,
            keystore: InMemoryKeychain()
        ).createEvmFactory(transactionMonitorFactory: transactionMonitorFactory)

        return EvmGiftClaimInteractor(
            claimDescriptionFactory: claimDescriptionFactory,
            claimOperationFactory: claimOperationFactory,
            chainRegistry: chainRegistry,
            claimableGift: claimableGift,
            walletOperationFactory: walletOperationFactory,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }
}
