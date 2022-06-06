protocol ParaStkYourCollatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: ParaStkYourCollatorsState)
}

protocol ParaStkYourCollatorsPresenterProtocol: AnyObject {
    func setup()
    func retry()
    func manageCollators()
    func selectCollator(viewModel: CollatorSelectionViewModel)
}

protocol ParaStkYourCollatorsInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol ParaStkYourCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>)
    func didReceiveDelegator(result: Result<ParachainStaking.Delegator?, Error>)
    func didReceiveScheduledRequests(result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>)
}

protocol ParaStkYourCollatorsWireframeProtocol: AlertPresentable, ErrorPresentable, ParachainStakingErrorPresentable {
    func showCollatorInfo(
        from view: ParaStkYourCollatorsViewProtocol?,
        collatorInfo: CollatorSelectionInfo
    )

    func showManageCollators(
        from view: ParaStkYourCollatorsViewProtocol?,
        options: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )

    func showStakeMore(
        from view: ParaStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )

    func showUnstake(
        from view: ParaStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )
}
