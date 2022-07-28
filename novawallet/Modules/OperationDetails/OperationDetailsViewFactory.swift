import Foundation
import CommonWallet
import SoraFoundation
import RobinHood

struct OperationDetailsViewFactory {
    static func createView(
        for txData: AssetTransactionData,
        chainAsset: ChainAsset,
        commandFactory: WalletCommandFactoryProtocol?
    ) -> OperationDetailsViewProtocol? {
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
            txData: txData,
            chainAsset: chainAsset,
            wallet: SelectedWalletSettings.shared.value,
            walletRepository: AnyDataProviderRepository(walletRepository),
            transactionLocalSubscriptionFactory: transactionLocalSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = OperationDetailsWireframe()
        wireframe.commandFactory = commandFactory

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let feeViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != chainAsset.asset.assetId {
            feeViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAsset.displayInfo(with: chainAsset.chain.icon)
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
