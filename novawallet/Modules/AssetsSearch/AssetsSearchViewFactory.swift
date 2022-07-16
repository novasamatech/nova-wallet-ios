import Foundation
import SoraFoundation

struct AssetsSearchViewFactory {
    static func createView() -> AssetsSearchViewProtocol? {
        let interactor = AssetsSearchInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())
        let viewModelFactory = WalletListAssetViewModelFactory(
            priceFormatter: priceFormatter,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource()
        )

        let presenter = AssetsSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = AssetsSearchViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
