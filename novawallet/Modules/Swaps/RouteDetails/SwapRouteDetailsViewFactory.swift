import Foundation
import SoraFoundation

struct SwapRouteDetailsViewFactory {
    static func createView(
        for quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        state: SwapTokensFlowStateProtocol
    ) -> SwapRouteDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let interactor = SwapRouteDetailsInteractor()
        let wireframe = SwapRouteDetailsWireframe()

        let prices = (try? state.assetListObservable.state.value.priceResult?.get()) ?? [:]

        let viewModelFactory = SwapRouteDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SwapRouteDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            quote: quote,
            fee: fee,
            prices: prices,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = SwapRouteDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
