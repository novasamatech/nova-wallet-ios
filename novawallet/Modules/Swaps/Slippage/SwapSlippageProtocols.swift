import Foundation

protocol SwapSlippageViewProtocol: ControllerBackedProtocol {
    func didReceivePreFilledPercents(viewModel: [SlippagePercentViewModel])
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveInput(error: String?)
    func didReceiveInput(warning: String?)
    func didReceiveResetState(available: Bool)
    func didReceiveButtonState(available: Bool)
}

protocol SwapSlippagePresenterProtocol: AnyObject {
    func setup()
    func select(percent: SlippagePercentViewModel)
    func updateAmount(_ amount: Decimal?)
    func apply()
    func showSlippageInfo()
    func reset()
}

protocol SwapSlippageWireframeProtocol: AnyObject, ShortTextInfoPresentable {
    func close(from view: ControllerBackedProtocol?)
}
