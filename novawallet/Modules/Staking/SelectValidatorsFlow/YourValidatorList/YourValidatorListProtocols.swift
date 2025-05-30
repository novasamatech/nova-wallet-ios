import Foundation_iOS

protocol YourValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(state: YourValidatorListViewState)
}

protocol YourValidatorListPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func didSelectValidator(viewModel: YourValidatorViewModel)
    func changeValidators()
}

protocol YourValidatorListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol YourValidatorListInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>)
    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveLedger(result: Result<StakingLedger?, Error>)
    func didReceiveRewardDestination(result: Result<Staking.RewardDestinationArg?, Error>)
}

protocol YourValidatorListWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: YourValidatorListViewProtocol?
    )

    func proceedToSelectValidatorsStart(
        from view: YourValidatorListViewProtocol?,
        existingBonding: ExistingBonding
    )
}
