import Foundation
import SoraFoundation

struct WalletListViewFactory {
    static func createView() -> WalletListViewProtocol? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let interactor = WalletListInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
        )

        let wireframe = WalletListWireframe()

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
