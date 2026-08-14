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
        let netFlow = quote.commissionNetFlow()

        let viewModel = quote.metaOperations.enumerated().map { index, operation in
            let operationFee = fee.operationFees[index]

            return viewModelFactory.createViewModel(
                for: operation,
                fee: operationFee,
                netAmountIn: netFlow.netAmountIn(at: index),
                netAmountOut: netFlow.netAmountOut(at: index),
                locale: selectedLocale
            )
        }

        view?.didReceive(viewModel: viewModel)
    }

    private func provideCommissionDisclosureViewModel() {
        let viewModel = fee.commission != nil
            ? viewModelFactory.commissionDisclosureViewModel(
                rate: AssetExchangeCommissionConstants.rate,
                locale: selectedLocale
            )
            : nil

        view?.didReceiveCommissionDisclosure(viewModel: viewModel)
    }
}

extension SwapRouteDetailsPresenter: SwapRouteDetailsPresenterProtocol {
    func setup() {
        provideViewModel()
        provideCommissionDisclosureViewModel()
    }
}

extension SwapRouteDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
            provideCommissionDisclosureViewModel()
        }
    }
}
