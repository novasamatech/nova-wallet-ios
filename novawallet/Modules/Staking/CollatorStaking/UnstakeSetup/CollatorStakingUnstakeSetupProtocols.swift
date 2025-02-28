import Foundation

protocol CollatorStkBaseUnstakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveMinStake(viewModel: LoadableViewModelState<BalanceViewModelProtocol>?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveTransferable(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
}

protocol CollatorStkFullUnstakeSetupViewProtocol: CollatorStkBaseUnstakeSetupViewProtocol {}

protocol CollatorStkPartialUnstakeSetupViewProtocol: CollatorStkBaseUnstakeSetupViewProtocol {}

protocol CollatorStkBaseUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
    func selectCollator()
    func proceed()
}

protocol CollatorStkFullUnstakeSetupPresenterProtocol: CollatorStkBaseUnstakeSetupPresenterProtocol {}

protocol CollatorStkPartialUnstakeSetupPresenterProtocol: CollatorStkBaseUnstakeSetupPresenterProtocol {
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
}
