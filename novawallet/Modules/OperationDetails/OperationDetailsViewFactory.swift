import Foundation

import Foundation_iOS
import Operation_iOS

struct OperationDetailsViewFactory {
    static func createView(
        for transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        operationState: AssetOperationState,
        swapState: SwapTokensFlowStateProtocol
    ) -> OperationDetailsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let operationDetailsDataProviderFactory = OperationDetailsDataProviderFactory(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            accountRepositoryFactory: accountRepositoryFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        guard
            let operationDetailsDataProvider = operationDetailsDataProviderFactory.createProvider(
                for: transaction
            ) else {
            return nil
        }

        let transactionLocalSubscriptionFactory = TransactionLocalSubscriptionFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let interactor: OperationDetailsBaseInteractor

        if transaction.swap != nil {
            interactor = createSwapInteractor(
                transaction: transaction,
                chainAsset: chainAsset,
                transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
                currencyManager: currencyManager,
                priceLocalSubscriptionFactory: PriceProviderFactory.shared,
                operationDataProvider: operationDetailsDataProvider
            )
        } else {
            interactor = createInteractor(
                transaction: transaction,
                chainAsset: chainAsset,
                transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
                currencyManager: currencyManager,
                priceLocalSubscriptionFactory: PriceProviderFactory.shared,
                operationDataProvider: operationDetailsDataProvider
            )
        }

        let wireframe = OperationDetailsWireframe(
            operationState: operationState,
            swapState: swapState
        )

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)

        let viewModelFactory = OperationDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = OperationDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            localizationManager: localizationManager
        )

        let view = OperationDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createSwapInteractor(
        transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationDataProvider: OperationDetailsDataProviderProtocol
    ) -> OperationDetailsBaseInteractor {
        OperationSwapDetailsInteractor(
            transaction: transaction,
            chainAsset: chainAsset,
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            currencyManager: currencyManager,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationDataProvider: operationDataProvider
        )
    }

    static func createInteractor(
        transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationDataProvider: OperationDetailsDataProviderProtocol
    ) -> OperationDetailsBaseInteractor {
        OperationDetailsInteractor(
            transaction: transaction,
            chainAsset: chainAsset,
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            currencyManager: currencyManager,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationDataProvider: operationDataProvider
        )
    }
}
