import Foundation
import SoraFoundation

final class SwapExecutionPresenter {
    weak var view: SwapExecutionViewProtocol?
    let wireframe: SwapExecutionWireframeProtocol
    let interactor: SwapExecutionInteractorInputProtocol

    let model: SwapExecutionModel
    let viewModelFactory: SwapConfirmViewModelFactoryProtocol

    var quote: AssetExchangeQuote {
        model.quote
    }

    var chainAssetIn: ChainAsset {
        model.chainAssetIn
    }

    var chainAssetOut: ChainAsset {
        model.chainAssetOut
    }

    init(
        model: SwapExecutionModel,
        interactor: SwapExecutionInteractorInputProtocol,
        wireframe: SwapExecutionWireframeProtocol,
        viewModelFactory: SwapConfirmViewModelFactoryProtocol
    ) {
        self.model = model
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func provideAssetInViewModel() {
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: chainAssetIn,
            amount: model.quote.route.amountIn,
            priceData: model.prices[chainAssetIn.chainAssetId],
            locale: selectedLocale
        )

        view?.didReceiveAssetIn(viewModel: viewModel)
    }

    private func provideAssetOutViewModel() {
        let viewModel = viewModelFactory.assetViewModel(
            chainAsset: chainAssetOut,
            amount: quote.route.amountOut,
            priceData: model.prices[chainAssetOut.chainAssetId],
            locale: selectedLocale
        )

        view?.didReceiveAssetOut(viewModel: viewModel)
    }

    private func provideRateViewModel() {
        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: model.quote.route.amountIn,
            amountOut: model.quote.route.amountOut
        )

        let viewModel = viewModelFactory.rateViewModel(from: params, locale: selectedLocale)

        view?.didReceiveRate(viewModel: .loaded(value: viewModel))
    }

    private func provideRouteViewModel() {
        let viewModel = viewModelFactory.routeViewModel(from: model.quote.metaOperations)

        view?.didReceiveRoute(viewModel: .loaded(value: viewModel))
    }

    private func providePriceDifferenceViewModel() {
        let params = RateParams(
            assetDisplayInfoIn: chainAssetIn.assetDisplayInfo,
            assetDisplayInfoOut: chainAssetOut.assetDisplayInfo,
            amountIn: quote.route.amountIn,
            amountOut: quote.route.amountOut
        )

        if let viewModel = viewModelFactory.priceDifferenceViewModel(
            rateParams: params,
            priceIn: model.prices[chainAssetIn.chainAssetId],
            priceOut: model.prices[chainAssetOut.chainAssetId],
            locale: selectedLocale
        ) {
            view?.didReceivePriceDifference(viewModel: .loaded(value: viewModel))
        } else {
            view?.didReceivePriceDifference(viewModel: nil)
        }
    }

    private func provideSlippageViewModel() {
        let viewModel = viewModelFactory.slippageViewModel(slippage: model.fee.slippage, locale: selectedLocale)
        view?.didReceiveSlippage(viewModel: viewModel)
    }

    private func provideFeeViewModel() {
        let feeInFiat = model.fee.calculateTotalFeeInFiat(
            assetIn: chainAssetIn,
            assetInPrice: model.payAssetPrice,
            feeAsset: model.feeAsset,
            feeAssetPrice: model.feeAssetPrice
        )

        let viewModel = viewModelFactory.feeViewModel(
            amountInFiat: feeInFiat,
            isEditable: false,
            priceData: model.feeAssetPrice,
            locale: selectedLocale
        )

        view?.didReceiveTotalFee(viewModel: .loaded(value: viewModel))
    }

    private func updateSwapDetails() {
        provideRateViewModel()
        providePriceDifferenceViewModel()
        provideSlippageViewModel()
        provideRouteViewModel()
        provideFeeViewModel()
    }

    private func updateSwapAssets() {
        provideAssetInViewModel()
        provideAssetOutViewModel()
    }
}

extension SwapExecutionPresenter: SwapExecutionPresenterProtocol {
    func setup() {
        updateSwapDetails()
        updateSwapAssets()
    }
}

extension SwapExecutionPresenter: SwapExecutionInteractorOutputProtocol {}

extension SwapExecutionPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            updateSwapAssets()
            updateSwapDetails()
        }
    }
}
