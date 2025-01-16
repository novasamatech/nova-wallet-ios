import Foundation
import Foundation_iOS

final class SwapRouteDetailsPresenter {
    weak var view: SwapRouteDetailsViewProtocol?

    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
    let prices: [ChainAssetId: PriceData]
    let viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol

    init(
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        prices: [ChainAssetId: PriceData],
        viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.quote = quote
        self.fee = fee
        self.prices = prices
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = quote.metaOperations.enumerated().map { index, operation in
            let fee = fee.operationFees[index]

            return viewModelFactory.createViewModel(
                for: operation,
                fee: fee,
                locale: selectedLocale
            )
        }

        view?.didReceive(viewModel: viewModel)
    }
}

extension SwapRouteDetailsPresenter: SwapRouteDetailsPresenterProtocol {
    func setup() {
        provideViewModel()
    }
}

extension SwapRouteDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
