import Foundation

protocol SwapSlippageViewProtocol: ControllerBackedProtocol {
    func didReceivePreFilledPercents(viewModel: [Percent])
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
}

protocol SwapSlippagePresenterProtocol: AnyObject {
    func setup()
    func select(percent: Percent)
    func updateAmount(_ amount: Decimal?)
    func apply()
}

protocol SwapSlippageInteractorInputProtocol: AnyObject {}

protocol SwapSlippageInteractorOutputProtocol: AnyObject {}

protocol SwapSlippageWireframeProtocol: AnyObject {
    func close(from view: ControllerBackedProtocol?)
}
