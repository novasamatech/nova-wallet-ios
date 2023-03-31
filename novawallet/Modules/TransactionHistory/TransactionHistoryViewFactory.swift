import Foundation
import SoraFoundation
import CommonWallet
import RobinHood

struct TransactionHistoryViewFactory {
    static func createView(chainAsset: ChainAsset) -> TransactionHistoryViewProtocol? {
        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let address = try? accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        let interactor = createInteractor(for: accountId, chainAsset: chainAsset)

        let wireframe = TransactionHistoryWireframe(chainAsset: chainAsset)

        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo)
        let viewModelFactory = TransactionHistoryViewModelFactory2(
            chainAsset: chainAsset,
            tokenFormatter: tokenFormatter,
            dateFormatter: DateFormatter.txHistory,
            groupDateFormatter: DateFormatter.txHistoryDate.localizableResource()
        )

        let presenter = TransactionHistoryPresenter(
            address: address,
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

    private static func createInteractor(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> TransactionHistoryInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: SubstrateDataStorageFacade.shared)

        let subscriptionFactory = TransactionLocalSubscriptionFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let fetcherFactory = TransactionHistoryFetcherFactory(
            remoteHistoryFacade: AssetHistoryFacade(),
            providerFactory: subscriptionFactory,
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue
        )

        return .init(accountId: accountId, chainAsset: chainAsset, fetcherFactory: fetcherFactory, pageSize: 100)
    }
}
