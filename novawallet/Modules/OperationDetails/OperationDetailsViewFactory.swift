import Foundation

import SoraFoundation
import RobinHood

struct OperationDetailsViewFactory {
    static func createView(
        for transaction: TransactionHistoryItem,
        chainAsset: ChainAsset
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

        let interactor = OperationDetailsInteractor(
            transaction: transaction,
            chainAsset: chainAsset,
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            currencyManager: currencyManager,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            operationDataProvider: operationDetailsDataProvider
        )

        let wireframe = OperationDetailsWireframe()

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let feeViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != chainAsset.asset.assetId {
            feeViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAsset.displayInfo(with: chainAsset.chain.icon),
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        } else {
            feeViewModelFactory = nil
        }

        let viewModelFactory = OperationDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            feeViewModelFactory: feeViewModelFactory
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
}
