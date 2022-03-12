import Foundation
import CommonWallet
import SoraFoundation
import RobinHood

struct OperationDetailsViewFactory {
    static func createView(
        for txData: AssetTransactionData,
        chainAsset: ChainAsset
    ) -> OperationDetailsViewProtocol? {
        let mapper = MetaAccountMapper()
        let walletRepository = UserDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let interactor = OperationDetailsInteractor(
            txData: txData,
            chainAsset: chainAsset,
            wallet: SelectedWalletSettings.shared.value,
            walletRepository: AnyDataProviderRepository(walletRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = OperationDetailsWireframe()

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let viewModelFactory = OperationDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = OperationDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            localizationManager: localizationManager
        )

        let view = OperationDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
