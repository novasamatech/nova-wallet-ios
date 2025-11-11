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

        let claimableGift = ClaimableGift(
            seed: giftPayload.seed,
            accountId: giftPayload.accountId,
            chainAsset: chainAsset
        )

        let interactor: GiftClaimInteractor?

        if claimableGift.chainAsset.asset.isAnyEvm {
            interactor = createEvmInteractor(
                claimableGift: claimableGift,
                chainRegistry: chainRegistry,
                totalAmount: totalAmount
            )
        } else {
            interactor = createSubstrateInteractor(
                claimableGift: claimableGift,
                chainRegistry: chainRegistry,
                totalAmount: totalAmount
            )
        }

        guard let interactor else { return nil }

        let wireframe = GiftClaimWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: claimableGift.chainAsset.assetDisplayInfo,
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
        claimableGift: ClaimableGift,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> GiftClaimInteractor? {
        let chain = claimableGift.chainAsset.chain

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
            keystore: InMemoryKeychain(),
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
        claimableGift: ClaimableGift,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> EvmGiftClaimInteractor? {
        let chain = claimableGift.chainAsset.chain

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else { return nil }

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
            for: claimableGift.chainAsset.asset,
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
            chain: chain,
            operationQueue: operationQueue
        )

        let claimDescriptionFactory = EvmClaimableGiftDescriptionFactory(
            transferCommandFactory: EvmTransferCommandFactory(),
            transactionService: transactionService,
            callbackQueue: .main
        )

        let claimOperationFactory = GiftClaimFactoryFacade(
            operationQueue: operationQueue,
            keystore: InMemoryKeychain()
        ).createEvmFactory(transactionService: transactionService)

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
