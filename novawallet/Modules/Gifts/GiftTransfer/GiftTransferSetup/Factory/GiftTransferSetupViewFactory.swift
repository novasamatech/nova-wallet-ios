import Foundation
import Foundation_iOS

final class GiftTransferSetupViewFactory {
    static func createView(
        from chainAsset: ChainAsset,
        assetListStateObservable: AssetListModelObservable,
        transferCompletion: TransferCompletionClosure?,
        buyTokenClosure: BuyTokensClosure?
    ) -> GiftTransferSetupViewProtocol? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccountAddress = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress(),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let interactor: GiftTransferBaseInteractor?
        let wireframe: GiftTransferSetupWireframeProtocol

        if chainAsset.asset.isAnyEvm {
            let evmWireframe = EvmGiftTransferSetupWireframe(
                assetListStateObservable: assetListStateObservable,
                buyTokensClosure: buyTokenClosure,
                transferCompletion: transferCompletion
            )
            wireframe = evmWireframe
            let validationProviderFactory = EvmValidationProviderFactory(
                presentable: evmWireframe,
                balanceViewModelFactory: balanceViewModelFactory,
                assetInfo: chainAsset.assetDisplayInfo
            )
            interactor = createEvmTransferSetupInteractor(
                for: chainAsset,
                wallet: wallet,
                validationProviderFactory: validationProviderFactory,
                currencyManager: currencyManager
            )
        } else {
            wireframe = GiftTransferSetupWireframe(
                assetListStateObservable: assetListStateObservable,
                buyTokensClosure: buyTokenClosure,
                transferCompletion: transferCompletion
            )
            interactor = createSubstrateTransferSetupInteractor(
                for: chainAsset,
                wallet: wallet,
                currencyManager: currencyManager
            )
        }

        guard let interactorInput = interactor as? GiftTransferSetupInteractorInputProtocol else { return nil }

        let initPresenterState = TransferSetupInputState(recepient: nil, amount: nil)

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)

        let issueViewModelFactory = GiftSetupIssueViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            utilityAssetInfo: chainAsset.assetDisplayInfo,
            destUtilityAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = GiftTransferSetupPresenter(
            interactor: interactorInput,
            wireframe: wireframe,
            chainAsset: chainAsset,
            initialState: initPresenterState,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            networkViewModelFactory: networkViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            issueViewModelFactory: issueViewModelFactory,
            senderAccountAddress: selectedAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GiftTransferSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor?.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }
}

private extension GiftTransferSetupViewFactory {
    static func createSubstrateTransferSetupInteractor(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        currencyManager: CurrencyManagerProtocol
    ) -> GiftTransferSetupInteractor? {
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

        let assetTransferAggregationWrapperFactory = AssetTransferAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return GiftTransferSetupInteractor(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            feeAsset: chainAsset,
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

    static func createEvmTransferSetupInteractor(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> EvmGiftTransferSetupInteractor? {
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

        return EvmGiftTransferSetupInteractor(
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
