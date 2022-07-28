import Foundation
import SoraFoundation

struct AssetsSearchViewFactory {
    static func createView(
        for initState: AssetListInitState,
        delegate: AssetsSearchDelegate
    ) -> AssetsSearchViewProtocol? {
        let interactor = AssetsSearchInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            logger: Logger.shared
        )

        let wireframe = AssetsSearchWireframe()

        let priceFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: AssetBalanceDisplayInfo.usd())
        let viewModelFactory = AssetListAssetViewModelFactory(
            priceFormatter: priceFormatter,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource()
        )

        let presenter = AssetsSearchPresenter(
            initState: initState,
            delegate: delegate,
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
