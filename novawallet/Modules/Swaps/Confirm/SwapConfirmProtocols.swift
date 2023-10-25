protocol SwapConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<SwapFeeViewModel>)
    func didReceiveWallet(viewModel: WalletAccountViewModel?)
}

protocol SwapConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {}

protocol SwapConfirmInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {}

protocol SwapConfirmWireframeProtocol: AnyObject {}
