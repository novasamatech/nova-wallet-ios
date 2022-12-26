import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

struct TransactionHistoryViewFactory {
    static func createView(chainAsset: ChainAsset) -> TransactionHistoryViewProtocol? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: SubstrateDataStorageFacade.shared)
        let fetchCount = 100
        let transactionSubscriptionFactory = TransactionSubscriptionFactory(
            storageFacade: repositoryFactory.storageFacade,
            operationQueue: operationQueue,
            historyFacade: AssetHistoryFacade(),
            repositoryFactory: repositoryFactory,
            fetchCount: fetchCount,
            logger: Logger.shared
        )

        let interactor = TransactionHistoryInteractor(
            chainAsset: chainAsset,
            metaAccount: selectedMetaAccount,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            repositoryFactory: repositoryFactory,
            historyFacade: AssetHistoryFacade(),
            dataProviderFactory: transactionSubscriptionFactory,
            fetchCount: fetchCount
        )
        let wireframe = TransactionHistoryWireframe(chainAsset: chainAsset)

        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo)
        let viewModelFactory = TransactionHistoryViewModelFactory2(
            chainAsset: chainAsset,
            tokenFormatter: tokenFormatter,
            dateFormatter: DateFormatter.txHistory,
            groupDateFormatter: DateFormatter.txHistoryDate.localizableResource()
        )
        let presenter = TransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = TransactionHistoryViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
