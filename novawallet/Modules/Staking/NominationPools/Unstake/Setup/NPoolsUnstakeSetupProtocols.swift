import Foundation

protocol NPoolsUnstakeSetupViewProtocol: NPoolsUnstakeBaseViewProtocol {
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTransferable(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
}

protocol NPoolsUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal?)
    func proceed()
}

protocol NPoolsUnstakeSetupInteractorInputProtocol: NPoolsUnstakeBaseInteractorInputProtocol {}

protocol NPoolsUnstakeSetupInteractorOutputProtocol: NPoolsUnstakeBaseInteractorOutputProtocol {}

protocol NPoolsUnstakeSetupWireframeProtocol: NPoolsUnstakeBaseWireframeProtocol {
    func showConfirm(from view: NPoolsUnstakeSetupViewProtocol?, amount: Decimal)
}
