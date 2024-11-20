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
    func showAddressOptions()
    func confirm()
}

protocol SwapConfirmInteractorInputProtocol: SwapBaseInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee)
}

protocol SwapConfirmInteractorOutputProtocol: SwapBaseInteractorOutputProtocol {
    func didReceiveSwaped(amount: Balance)
    func didReceive(error: SwapConfirmError)
}

protocol SwapConfirmWireframeProtocol: SwapBaseWireframeProtocol, AddressOptionsPresentable,
    ShortTextInfoPresentable, ModalAlertPresenting, MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        locale: Locale
    )
}

enum SwapConfirmError: Error {
    case submit(Error)
}
