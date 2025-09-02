import Foundation_iOS

protocol ControllerAccountViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: ControllerAccountViewModel)
    func didCompleteControllerSelection()
}

protocol ControllerAccountViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        stashItem: StashItem,
        stashAccountItem: MetaChainAccountResponse?,
        chosenAccountItem: MetaChainAccountResponse?,
        isDeprecated: Bool
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
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveControllerAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>, address: AccountAddress)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveIsDeprecated(result: Result<Bool, Error>)
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
