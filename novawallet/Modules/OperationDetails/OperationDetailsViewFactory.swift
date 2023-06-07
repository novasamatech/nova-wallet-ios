import Foundation
import CommonWallet
import SoraFoundation
import RobinHood

struct OperationDetailsViewFactory {
    // TODO: remove
    static func createView(
        for _: AssetTransactionData,
        chainAsset _: ChainAsset
    ) -> OperationDetailsViewProtocol? {
        nil
    }

    static func createView(
        for transaction: TransactionHistoryItem,
        chainAsset: ChainAsset
    ) -> OperationDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let storageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let walletRepository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let transactionLocalSubscriptionFactory = TransactionLocalSubscriptionFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let interactor = OperationDetailsInteractor(
            transaction: transaction,
            chainAsset: chainAsset,
            wallet: SelectedWalletSettings.shared.value,
            walletRepository: AnyDataProviderRepository(walletRepository),
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
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
