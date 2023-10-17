import Foundation

protocol SwapSlippageViewProtocol: ControllerBackedProtocol {
    func didReceivePreFilledPercents(viewModel: [Percent])
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveResetState(available: Bool)
}

protocol SwapSlippagePresenterProtocol: AnyObject {
    func setup()
    func select(percent: Percent)
    func updateAmount(_ amount: Decimal?)
    func apply()
    func showSlippageInfo()
    func reset()
}

protocol SwapSlippageInteractorInputProtocol: AnyObject {}

protocol SwapSlippageInteractorOutputProtocol: AnyObject {}

protocol SwapSlippageWireframeProtocol: AnyObject {
    func close(from view: ControllerBackedProtocol?)
}
