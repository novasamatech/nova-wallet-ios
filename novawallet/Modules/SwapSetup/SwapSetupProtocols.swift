protocol SwapSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(payViewModel viewModel: SwapsAssetViewModel?)
    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(payViewModel: String?)
    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapsAssetViewModel?)
    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(receiveViewModel: String?)
}

protocol SwapSetupPresenterProtocol: AnyObject {
    func setup()
    func selectPayToken()
    func selectReceiveToken()
}

protocol SwapSetupInteractorInputProtocol: AnyObject {}

protocol SwapSetupInteractorOutputProtocol: AnyObject {}

protocol SwapSetupWireframeProtocol: AnyObject {}
