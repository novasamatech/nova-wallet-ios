import Foundation
import Foundation_iOS
import Operation_iOS
import Keystore_iOS

struct GiftPrepareShareViewFactory {
    static func createView(
        giftId: GiftModel.Id,
        chainAsset: ChainAsset,
        style: GiftPrepareShareViewStyle
    ) -> GiftPrepareShareViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let selectedWallet = SelectedWalletSettings.shared.value,
            let giftAccountId = try? giftId.toAccountId(using: chainAsset.chain.chainFormat)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let storageFacade = UserDataStorageFacade.shared
        let repositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let giftRepository = repositoryFactory.createGiftsRepository(for: nil)
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let keystore = Keychain()

        let giftSecretsManager = GiftSecretsManager(keystore: keystore)

        guard let reclaimFactory = createReclaimFactory(
            for: giftAccountId,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            keystore: keystore
        ) else { return nil }

        let interactor = GiftPrepareShareInteractor(
            selectedWallet: selectedWallet,
            giftRepository: giftRepository,
            reclaimWrapperFactory: reclaimFactory,
            giftSecretsManager: giftSecretsManager,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            giftId: giftId,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        let wireframe = GiftPrepareShareWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let universalLinkFactory = ExternalLinkFactory(
            baseUrl: ApplicationConfig.shared.externalUniversalLinkURL
        )

        let viewModelFactory = GiftPrepareShareViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            universalLinkFactory: universalLinkFactory
        )

        let localizationManager = LocalizationManager.shared

        let presenter = GiftPrepareSharePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            flowStyle: style,
            localizationManager: localizationManager
        )

        let view = GiftPrepareShareViewController(
            presenter: presenter,
            viewStyle: style,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

// MARK: - Private

private extension GiftPrepareShareViewFactory {
    static func createReclaimFactory(
        for giftAccountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        keystore: KeystoreProtocol
    ) -> GiftReclaimWrapperFactoryProtocol? {
        let claimFacade = GiftClaimFactoryFacade(
            operationQueue: operationQueue,
            keystore: keystore
        )

        return switch chainAsset.asset.isAnyEvm {
        case true:
            createEvmReclaimFactory(
                giftAccountId: giftAccountId,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry,
                claimFactoryFacade: claimFacade,
                operationQueue: operationQueue
            )
        case false:
            createSubstrateReclaimFactory(
                giftAccountId: giftAccountId,
                chainAsset: chainAsset,
                chainRegistry: chainRegistry,
                claimFactoryFacade: claimFacade,
                operationQueue: operationQueue
            )
        }
    }

    static func createSubstrateReclaimFactory(
        giftAccountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        claimFactoryFacade: GiftClaimFactoryFacade,
        operationQueue: OperationQueue,
    ) -> GiftReclaimWrapperFactoryProtocol? {
        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createServiceForGiftClaim(accountId: giftAccountId, chain: chainAsset.chain)

        let extrinsicMonitorFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            connection: connection,
            runtimeService: runtimeProvider,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let claimFactory = claimFactoryFacade.createSubstrateFactory(
            extrinsicMonitorFactory: extrinsicMonitorFactory
        )

        return SubstrateGiftReclaimWrapperFactory(
            chainRegistry: chainRegistry,
            walletChecker: GiftReclaimWalletChecker(),
            claimOperationFactory: claimFactory,
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(),
            operationQueue: operationQueue
        )
    }

    static func createEvmReclaimFactory(
        giftAccountId: AccountId,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        claimFactoryFacade: GiftClaimFactoryFacade,
        operationQueue: OperationQueue,
    ) -> GiftReclaimWrapperFactoryProtocol? {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let gasLimitProvider = EvmGasLimitProviderFactory.createGasLimitProvider(
            for: chainAsset.asset,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let nonceProvider = EvmDefaultNonceProvider(operationFactory: operationFactory)

        let transactionService = EvmTransactionService(
            accountId: giftAccountId,
            operationFactory: operationFactory,
            maxPriorityGasPriceProvider: EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory),
            defaultGasPriceProvider: EvmLegacyGasPriceProvider(operationFactory: operationFactory),
            gasLimitProvider: gasLimitProvider,
            nonceProvider: nonceProvider,
            chain: chainAsset.chain,
            operationQueue: operationQueue
        )

        let claimFactory = claimFactoryFacade.createEvmFactory(transactionService: transactionService)

        return EvmGiftReclaimWrapperFactory(
            chainRegistry: chainRegistry,
            walletChecker: GiftReclaimWalletChecker(),
            claimOperationFactory: claimFactory,
            transactionService: transactionService,
            transferCommandFactory: EvmTransferCommandFactory(),
            operationQueue: operationQueue,
            workingQueue: .main
        )
    }
}
