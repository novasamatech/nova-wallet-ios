import SoraFoundation

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: ControllerAccountViewModel)
    func didCompleteControllerSelection()
}

protocol ControllerAccountViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        stashItem: StashItem,
        stashAccountItem: MetaChainAccountResponse?,
        chosenAccountItem: MetaChainAccountResponse?
    ) -> ControllerAccountViewModel
}

protocol ControllerAccountPresenterProtocol: AnyObject {
    func setup()
    func handleStashAction()
    func handleControllerAction()
    func selectLearnMore()
    func proceed()
}

protocol ControllerAccountInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for account: ChainAccountResponse)
    func fetchLedger(controllerAddress: AccountAddress)
    func fetchControllerAccountInfo(controllerAddress: AccountAddress)
}

protocol ControllerAccountInteractorOutputProtocol: AnyObject {
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveStashAccount(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveControllerAccount(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveAccounts(result: Result<[MetaChainAccountResponse], Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveControllerAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
}

protocol ControllerAccountWireframeProtocol: WebPresentable,
    AddressOptionsPresentable,
    AccountSelectionPresentable,
    StakingErrorPresentable,
    AlertPresentable,
    ErrorPresentable {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: MetaChainAccountResponse
    )
    func close(view: ControllerBackedProtocol?)
}
