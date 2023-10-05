import BigInt

protocol SwapSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel)
    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(payViewModel: String?)
    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model)
    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapAssetInputViewModel)
    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(receiveViewModel: String?)
    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model)
    func didReceiveRate(viewModel: LoadableViewModelState<BalanceViewModelProtocol>)
    func didReceiveNetworkFee(viewModel: LoadableViewModelState<BalanceViewModelProtocol>)
}

protocol SwapSetupPresenterProtocol: AnyObject {
    func setup()
    func selectPayToken()
    func selectReceiveToken()
    func proceed()
    func swap()
}

protocol SwapSetupInteractorInputProtocol: AnyObject {
    func calculateQuote(for args: AssetConversion.QuoteArgs)
}

protocol SwapSetupInteractorOutputProtocol: AnyObject {
    func didReceive(quote: AssetConversion.Quote)
    func didReceive(fee: BigUInt?)
    func didReceive(error: SwapSetupError)
}

protocol SwapSetupWireframeProtocol: AnyObject, AlertPresentable, CommonRetryable, ErrorPresentable {}

enum SwapSetupError: Error {
    case quote(Error)
    case fetchFeeFailed(Error)
}
