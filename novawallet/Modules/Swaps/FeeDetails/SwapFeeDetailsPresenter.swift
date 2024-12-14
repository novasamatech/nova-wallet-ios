import Foundation
import SoraFoundation

final class SwapFeeDetailsPresenter {
    weak var view: SwapFeeDetailsViewProtocol?

    let operations: [AssetExchangeMetaOperationProtocol]
    let fee: AssetExchangeFee
    let prices: [ChainAssetId: PriceData]
    let viewModelFactory: SwapFeeDetailsViewModelFactoryProtocol

    init(
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee,
        prices: [ChainAssetId: PriceData],
        viewModelFactory: SwapFeeDetailsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.operations = operations
        self.fee = fee
        self.prices = prices
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            from: operations,
            fee: fee,
            prices: prices,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension SwapFeeDetailsPresenter: SwapFeeDetailsPresenterProtocol {
    func setup() {
        provideViewModel()
    }
}

extension SwapFeeDetailsPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
