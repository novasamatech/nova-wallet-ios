import Foundation
import SoraFoundation

struct WalletSelectionViewFactory {
    static func createView() -> WalletsListViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = WalletSelectionWireframe()

        let localizationManager = LocalizationManager.shared

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())

        let viewModelFactory = WalletsListViewModelFactory(priceFormatter: priceFormatter)
        let presenter = WalletSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = WalletSelectionViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> WalletSelectionInteractor? {
        WalletSelectionInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            settings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )
    }
}
