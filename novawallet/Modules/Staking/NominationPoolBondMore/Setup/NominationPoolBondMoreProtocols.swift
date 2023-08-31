import BigInt

protocol NominationPoolBondMoreViewProtocol: ControllerBackedProtocol {
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTransferable(viewModel: String?)
    func didReceiveHints(viewModel: [String])
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
}

protocol NominationPoolBondMorePresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal?)
    func proceed()
}

protocol NominationPoolBondMoreInteractorInputProtocol: NominationPoolBondMoreBaseInteractorInputProtocol {}

protocol NominationPoolBondMoreInteractorOutputProtocol: NominationPoolBondMoreBaseInteractorOutputProtocol {}

protocol NominationPoolBondMoreWireframeProtocol: NominationPoolBondMoreBaseWireframeProtocol {
    func showConfirm(from view: ControllerBackedProtocol?)
}
