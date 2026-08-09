import Foundation
import Foundation_iOS

final class SwapRouteDetailsPresenter {
    weak var view: SwapRouteDetailsViewProtocol?

    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
    let prices: [ChainAssetId: PriceData]
    let viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol
    let commissionPolicy: AssetExchangeCommissionPolicyProtocol

    init(
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee,
        prices: [ChainAssetId: PriceData],
        viewModelFactory: SwapRouteDetailsViewModelFactoryProtocol,
        commissionPolicy: AssetExchangeCommissionPolicyProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.quote = quote
        self.fee = fee
        self.prices = prices
        self.viewModelFactory = viewModelFactory
        self.commissionPolicy = commissionPolicy
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let chargingIndex = fee.commission?.chargingOperationIndex

        let viewModel = quote.metaOperations.enumerated().map { index, operation in
            let operationFee = fee.operationFees[index]

            // the commission comes out of the charging operation's OUTPUT, so that operation's
            // own input is unreduced — hence `>` for the input and `>=` for the output
            let outputCharged = chargingIndex.map { index >= $0 } ?? false
            let inputCharged = chargingIndex.map { index > $0 } ?? false

            return viewModelFactory.createViewModel(
                for: operation,
                fee: operationFee,
                netAmountIn: commissionPolicy.netAmount(
                    from: operation.amountIn,
                    willCharge: inputCharged
                ),
                netAmountOut: commissionPolicy.netAmount(
                    from: operation.amountOut,
                    willCharge: outputCharged
                ),
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
