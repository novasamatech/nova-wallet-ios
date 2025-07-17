import Foundation
import BigInt

protocol SwapConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>)
    func didReceiveExecutionTime(viewModel: LoadableViewModelState<String>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveWallet(viewModel: WalletAccountViewModel?)
    func didReceiveWarning(viewModel: String?)
    func didReceiveStartLoading()
    func didReceiveStopLoading()
}

protocol SwapConfirmPresenterProtocol: AnyObject {
    func setup()
    func showRateInfo()
    func showPriceDifferenceInfo()
    func showSlippageInfo()
    func showNetworkFeeInfo()
    func showRouteDetails()
    func showAddressOptions()
    func confirm()
}

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func initiateSwapSubmission(of model: SwapExecutionModel)
}

protocol SwapConfirmInteractorOutProtocol: SwapBaseInteractorOutputProtocol {
    func didCompleteSwapSubmission(with result: Result<ExtrinsicSubmittedModel, Error>)
    func didDecideMonitoredExecution(for model: SwapExecutionModel)
}

protocol SwapConfirmWireframeProtocol: SwapBaseWireframeProtocol, AddressOptionsPresentable,
    ShortTextInfoPresentable, MessageSheetPresentable, ExtrinsicSigningErrorHandling,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {
    func showSwapExecution(
        from view: SwapConfirmViewProtocol?,
        model: SwapExecutionModel
    )

    func showRouteDetails(
        from view: ControllerBackedProtocol?,
        quote: AssetExchangeQuote,
        fee: AssetExchangeFee
    )

    func showFeeDetails(
        from view: ControllerBackedProtocol?,
        operations: [AssetExchangeMetaOperationProtocol],
        fee: AssetExchangeFee
    )
}
