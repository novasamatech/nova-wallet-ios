import Foundation
import SoraFoundation

struct WalletSelectionViewFactory {
    static func createView() -> WalletsListViewProtocol? {
        guard let interactor = createInteractor(),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = WalletSelectionWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = WalletsListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            priceAssetInfoFactory: priceAssetInfoFactory,
            currencyManager: currencyManager
        )

        let presenter = WalletSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletSelectionViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.baseView = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> WalletSelectionInteractor? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        return WalletSelectionInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager
        )
    }
}
