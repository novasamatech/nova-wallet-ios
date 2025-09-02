import Foundation
import Foundation_iOS

struct ManualBackupWalletListViewFactory {
    static func createView() -> WalletsListViewProtocol? {
        guard
            let interactor = createInteractor(),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let wireframe = ManualBackupWalletListWireframe()

        let presenter = ManualBackupWalletListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ManualBackupWalletListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.baseView = view
        interactor.basePresenter = presenter

        return view
    }

    private static func createInteractor() -> WalletsListInteractor? {
        guard let balancesStore = BalancesStore.createDefault() else {
            return nil
        }

        return WalletsListInteractor(
            balancesStore: balancesStore,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared
        )
    }
}
