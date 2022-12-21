import SoraFoundation

protocol ControllerAccountConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: ControllerAccountConfirmationVM)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol ControllerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func confirm()
}

protocol ControllerAccountConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
    func estimateFee()
}

protocol ControllerAccountConfirmationInteractorOutputProtocol: AnyObject {
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStashAccount(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didConfirmed(result: Result<String, Error>)
}

protocol ControllerAccountConfirmationWireframeProtocol: AddressOptionsPresentable,
    ErrorPresentable,
    AlertPresentable,
    StakingErrorPresentable,
    MessageSheetPresentable {
    func complete(from view: ControllerAccountConfirmationViewProtocol?)
    func close(view: ControllerBackedProtocol?)
}
