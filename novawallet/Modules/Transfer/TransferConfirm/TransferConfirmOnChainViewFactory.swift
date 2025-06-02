import Foundation
import Foundation_iOS
import Keystore_iOS

// swiftlint:disable function_body_length
struct TransferConfirmOnChainViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        recepient: AccountAddress,
        amount: OnChainTransferAmount<Decimal>,
        transferCompletion: TransferCompletionClosure?
    ) -> TransferConfirmOnChainViewProtocol? {
        let walletSettings = SelectedWalletSettings.shared

        guard
            let wallet = walletSettings.value,
            let selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let senderAccountAddress = selectedAccount.toAddress(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let optInteractor: (OnChainTransferBaseInteractor & TransferConfirmOnChainInteractorInputProtocol)?
        let wireframe: TransferConfirmWireframeProtocol

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let sendingBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != chainAsset.asset.assetId {
            let utilityAssetInfo = utilityAsset.displayInfo(with: chainAsset.chain.icon)
            utilityBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAssetInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        } else {
            utilityBalanceViewModelFactory = nil
        }

        if chainAsset.asset.isAnyEvm {
            let evmWireframe = EvmTransferConfirmWireframe()
            wireframe = evmWireframe

            let assetInfo = chainAsset.chain.utilityAssetDisplayInfo() ?? chainAsset.assetDisplayInfo
            let validationProviderFactory = EvmValidationProviderFactory(
                presentable: evmWireframe,
                balanceViewModelFactory: utilityBalanceViewModelFactory ?? sendingBalanceViewModelFactory,
                assetInfo: assetInfo
            )

            optInteractor = createEvmInteractor(
                for: chainAsset,
                account: selectedAccount,
                validationProviderFactory: validationProviderFactory
            )
        } else {
            wireframe = TransferConfirmWireframe()
            optInteractor = createSubstrateInteractor(
                for: chainAsset,
                feeAsset: feeAsset,
                account: selectedAccount,
                accountMetaId: wallet.metaId
            )
        }

        guard let interactor = optInteractor else {
            return nil
        }

        guard let utilityAssetInfo = chainAsset.chain.utilityAssets().first?.displayInfo else {
            return nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            utilityAssetInfo: utilityAssetInfo,
            destUtilityAssetInfo: utilityAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = TransferOnChainConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            recepient: recepient,
            amount: amount,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            chainAsset: chainAsset,
            feeAsset: feeAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            transferCompletion: transferCompletion
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

    private static func createEvmInteractor(
        for chainAsset: ChainAsset,
        account: ChainAccountResponse,
        validationProviderFactory: EvmValidationProviderFactoryProtocol
    ) -> TransferEvmOnChainConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        guard
            let ethereumResponse = SelectedWalletSettings.shared.value?.fetchEthereum(for: account.accountId),
            let connection = chainRegistry.getOneShotConnection(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let gasLimitProvider = EvmGasLimitProviderFactory.createGasLimitProvider(
            for: asset,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let nonceProvider = EvmDefaultNonceProvider(operationFactory: operationFactory)

        let extrinsicService = EvmTransactionService(
            accountId: account.accountId,
            operationFactory: operationFactory,
            maxPriorityGasPriceProvider: EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory),
            defaultGasPriceProvider: EvmLegacyGasPriceProvider(operationFactory: operationFactory),
            gasLimitProvider: gasLimitProvider,
            nonceProvider: nonceProvider,
            chain: chain,
            operationQueue: operationQueue
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(for: ethereumResponse)

        let repositoryFactory = SubstrateRepositoryFactory()
        let transactionStorage = repositoryFactory.createTxRepository()
        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return TransferEvmOnChainConfirmInteractor(
            selectedAccount: account,
            chain: chain,
            asset: asset,
            feeProxy: EvmTransactionFeeProxy(),
            extrinsicService: extrinsicService,
            validationProviderFactory: validationProviderFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            signingWrapper: signingWrapper,
            persistExtrinsicService: persistentExtrinsicService,
            persistenceFilter: AccountTypeExtrinsicPersistenceFilter(),
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private static func createSubstrateInteractor(
        for chainAsset: ChainAsset,
        feeAsset: ChainAsset?,
        account: ChainAccountResponse,
        accountMetaId: String
    ) -> TransferOnChainConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let repositoryFactory = SubstrateRepositoryFactory()

        let walletRemoteSubscriptionService = WalletServiceFacade.sharedSubstrateRemoteSubscriptionService

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: account, chain: chain)

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: accountMetaId,
            accountResponse: account
        )

        let transactionStorage = repositoryFactory.createTxRepository()
        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let assetTransferAggregationWrapperFactory = AssetTransferAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return TransferOnChainConfirmInteractor(
            selectedAccount: account,
            chain: chain,
            asset: asset,
            feeAsset: feeAsset,
            runtimeService: runtimeProvider,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            persistExtrinsicService: persistentExtrinsicService,
            eventCenter: EventCenter.shared,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            transferAggregationWrapperFactory: assetTransferAggregationWrapperFactory,
            persistenceFilter: AccountTypeExtrinsicPersistenceFilter(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}

// swiftlint:enable function_body_length
