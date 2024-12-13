import Foundation
import SoraFoundation

final class SwapRouteDetailsPresenter {
    weak var view: SwapRouteDetailsViewProtocol?
    let wireframe: SwapRouteDetailsWireframeProtocol
    let interactor: SwapRouteDetailsInteractorInputProtocol

    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
    let prices: [ChainAssetId: PriceData]
    let viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol

    init(
        interactor: SwapRouteDetailsInteractorInputProtocol,
        wireframe: SwapRouteDetailsWireframeProtocol,
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        prices: [ChainAssetId: PriceData],
        viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
                prices: prices,
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

extension SwapRouteDetailsPresenter: SwapRouteDetailsInteractorOutputProtocol {}

extension SwapRouteDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
