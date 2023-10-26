protocol SwapConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<SwapFeeViewModel>)
    func didReceiveWallet(viewModel: WalletAccountViewModel?)
    func didReceiveWarning(viewModel: String?)
}

protocol SwapConfirmPresenterProtocol: AnyObject {
    func setup()
    func showRateInfo()
    func showPriceDifferenceInfo()
    func showSlippageInfo()
    func showNetworkFeeInfo()
    func showAddressOptions()
    func confirm()
}

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {}

protocol SwapConfirmInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {}

protocol SwapConfirmWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable, AddressOptionsPresentable,
    ErrorPresentable, SwapErrorPresentable, ShortTextInfoPresentable {}
