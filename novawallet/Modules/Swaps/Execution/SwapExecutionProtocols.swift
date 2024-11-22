protocol SwapExecutionViewProtocol: ControllerBackedProtocol {
    func didReceive(countdownViewModel: CountdownLoadingView.ViewModel)
    func didReceive(currentOperation: String)
    func didReceive(executing: UInt, total: UInt)
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceiveRoute(viewModel: LoadableViewModelState<[SwapRouteItemView.ItemViewModel]>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveTotalFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
}

protocol SwapExecutionPresenterProtocol: AnyObject {
    func setup()
}

protocol SwapExecutionInteractorInputProtocol: AnyObject {}

protocol SwapExecutionInteractorOutputProtocol: AnyObject {}

protocol SwapExecutionWireframeProtocol: AnyObject {}
