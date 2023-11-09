import Foundation

protocol SwapConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAssetIn(viewModel: SwapAssetAmountViewModel)
    func didReceiveAssetOut(viewModel: SwapAssetAmountViewModel)
    func didReceiveRate(viewModel: LoadableViewModelState<String>)
    func didReceivePriceDifference(viewModel: LoadableViewModelState<DifferenceViewModel>?)
    func didReceiveSlippage(viewModel: String)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<SwapFeeViewModel>)
    func didReceiveWallet(viewModel: WalletAccountViewModel?)
    func didReceiveWarning(viewModel: String?)
    func didReceiveNotification(viewModel: String?)
    func didReceiveStartLoading()
    func didReceiveStopLoading()
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

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func submit(args: AssetConversion.CallArgs)
}

protocol SwapConfirmInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {
    func didReceiveConfirmation(hash: String)
    func didReceive(error: SwapConfirmError)
}

protocol SwapConfirmWireframeProtocol: SwapBaseWireframeProtocol, AddressOptionsPresentable,
    ShortTextInfoPresentable, ModalAlertPresenting, MessageSheetPresentable {
    func complete(on view: ControllerBackedProtocol?, locale: Locale)
}

enum SwapConfirmError: Error {
    case submit(Error)
}
