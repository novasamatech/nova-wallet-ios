import Foundation
import Foundation_iOS

final class WalletsChooseViewFactory {
    static func createView(
        for selectedWalletId: String,
        delegate: WalletsChooseDelegate
    ) -> WalletsChooseViewController? {
        guard
            let interactor = createInteractor(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = WalletsListWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = WalletsChooseViewModelFactory(
            selectedId: selectedWalletId,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let presenter = WalletsChoosePresenter(
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletsChooseViewController(presenter: presenter, localizationManager: localizationManager)

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
