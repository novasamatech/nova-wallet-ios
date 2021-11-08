import Foundation
import SoraFoundation

struct WalletListViewFactory {
    static func createView() -> WalletListViewProtocol? {
        let interactor = WalletListInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = WalletListWireframe(walletUpdater: WalletDetailsUpdater.shared)

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())
        let viewModelFactory = WalletListViewModelFactory(
            priceFormatter: priceFormatter,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource()
        )
        let localizationManager = LocalizationManager.shared

        let presenter = WalletListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = WalletListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
