import Foundation
import Foundation_iOS

struct SwapRouteDetailsViewFactory {
    static func createView(
        for quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        state: SwapTokensFlowStateProtocol
    ) -> SwapRouteDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let prices = (try? state.assetListObservable.state.value.priceResult?.get()) ?? [:]

        let viewModelFactory = SwapRouteDetailsViewModelFactory(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager),
            priceStore: state.priceStore
        )

        let presenter = SwapRouteDetailsPresenter(
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

        return view
    }
}
