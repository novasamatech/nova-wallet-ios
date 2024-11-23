protocol SwapExecutionViewProtocol: ControllerBackedProtocol {
    func didReceiveExecution(viewModel: SwapExecutionViewModel)
    func didUpdateExecution(remainedTime: UInt)
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

protocol SwapExecutionInteractorInputProtocol: AnyObject {
    func submit(using estimation: AssetExchangeFee)
}

protocol SwapExecutionInteractorOutputProtocol: AnyObject {
    func didStartExecution(for operationIndex: Int)
    func didCompleteFullExecution(received amount: Balance)
    func didFailExecution(with error: Error)
}

protocol SwapExecutionWireframeProtocol: AnyObject {}
