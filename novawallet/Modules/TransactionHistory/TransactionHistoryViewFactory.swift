import Foundation
import SoraFoundation
import CommonWallet

struct TransactionHistoryViewFactory {
    static func createView(chainAsset: ChainAsset) -> TransactionHistoryViewProtocol? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }
        let historyFacade: AssetHistoryFactoryFacadeProtocol = AssetHistoryFacade()
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        // let dataProvider: SingleValueProvider<AssetTransactionPageData>
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = TransactionHistoryInteractor(
            chainAsset: chainAsset,
            metaAccount: selectedMetaAccount,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            repositoryFactory: repositoryFactory,
            historyFacade: AssetHistoryFacade()
        )
        let wireframe = TransactionHistoryWireframe()

        let walletAsset = WalletAsset(
            identifier: chainAsset.chainAssetId.walletId,
            name: LocalizableResource { _ in chainAsset.asset.name ?? chainAsset.chain.name },
            platform: LocalizableResource { _ in chainAsset.chain.name },
            symbol: chainAsset.asset.symbol,
            precision: chainAsset.assetDisplayInfo.assetPrecision,
            modes: WalletAssetModes.all
        )

        let viewModelFactory = TransactionHistoryViewModelFactory2(
            chainAsset: chainAsset,
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            dateFormatter: DateFormatter.txHistory,
            assets: [walletAsset]
        )
        let presenter = TransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            transactionsPerPage: 10,
            filter: .init(),
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
