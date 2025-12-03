import Foundation
import Foundation_iOS
import Keystore_iOS

final class GiftTransferConfirmViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        amount: OnChainTransferAmount<Decimal>,
        transferCompletion: TransferCompletionClosure?
    ) -> GiftTransferConfirmViewProtocol? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccountAddress = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress(),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let interactor: GiftTransferBaseInteractor?
        let wireframe: GiftTransferConfirmWireframeProtocol

        if chainAsset.asset.isAnyEvm {
            let evmWireframe = EvmGiftTransferConfirmWireframe()
            wireframe = evmWireframe

            let validationProviderFactory = EvmValidationProviderFactory(
                presentable: evmWireframe,
                balanceViewModelFactory: balanceViewModelFactory,
                assetInfo: chainAsset.assetDisplayInfo
            )

            interactor = createEvmTransferConfirmInteractor(
                for: chainAsset,
                wallet: wallet,
                validationProviderFactory: validationProviderFactory,
                currencyManager: currencyManager
            )
        } else {
            wireframe = GiftTransferConfirmWireframe()

            interactor = createSubstrateTransferConfirmInteractor(
                for: chainAsset,
                wallet: wallet,
                currencyManager: currencyManager
            )
        }

        guard let interactorInput = interactor as? GiftTransferConfirmInteractorInputProtocol else { return nil }

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            utilityAssetInfo: chainAsset.assetDisplayInfo,
            destUtilityAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = GiftTransferConfirmPresenter(
            interactor: interactorInput,
            wireframe: wireframe,
            wallet: wallet,
            amount: amount,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            senderAccountAddress: selectedAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            transferCompletion: transferCompletion,
            logger: Logger.shared
        )

        let view = GiftTransferConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor?.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }
}

private extension GiftTransferConfirmViewFactory {
    static func createSubstrateTransferConfirmInteractor(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        currencyManager: CurrencyManagerProtocol
    ) -> GiftTransferConfirmInteractor? {
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let selectedAccount = wallet.fetch(for: chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chain)

        let extrinsicMonitorFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            connection: connection,
            runtimeService: runtimeProvider,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let submissionFactory = GiftSubmissionFactoryFacade(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            operationQueue: operationQueue
        ).createSubstrateFactory(extrinsicMonitorFactory: extrinsicMonitorFactory)

        let assetTransferAggregationWrapperFactory = AssetTransferAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return GiftTransferConfirmInteractor(
            giftSubmissionFactory: submissionFactory,
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeProvider,
            feeProxy: ExtrinsicFeeProxy(),
            transferCommandFactory: SubstrateTransferCommandFactory(),
            extrinsicService: extrinsicService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            transferAggregationWrapperFactory: assetTransferAggregationWrapperFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    static func createEvmTransferConfirmInteractor(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> EvmGiftTransferConfirmInteractor? {
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let selectedAccount = wallet.fetch(for: chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chain.chainId)
        else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let gasLimitProvider = EvmGasLimitProviderFactory.createGasLimitProvider(
            for: asset,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let nonceProvider = EvmDefaultNonceProvider(operationFactory: operationFactory)

        let transactionService = EvmTransactionService(
            accountId: selectedAccount.accountId,
            operationFactory: operationFactory,
            maxPriorityGasPriceProvider: EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory),
            defaultGasPriceProvider: EvmLegacyGasPriceProvider(operationFactory: operationFactory),
            gasLimitProvider: gasLimitProvider,
            nonceProvider: nonceProvider,
            chain: chain,
            operationQueue: operationQueue
        )
        
        let transactionMonitorFactory = TransactionSubmitMonitorFactory(
            submissionService: transactionService,
            evmOperationFactory: operationFactory,
            operationQueue: operationQueue
        )

        let submissionFactory = GiftSubmissionFactoryFacade(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            operationQueue: operationQueue
        ).createEvmFactory(transactionMonitorFactory: transactionMonitorFactory)

        return EvmGiftTransferConfirmInteractor(
            giftSubmissionFactory: submissionFactory,
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            feeProxy: EvmTransactionFeeProxy(),
            transferCommandFactory: EvmTransferCommandFactory(),
            transactionService: transactionService,
            validationProviderFactory: validationProviderFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
