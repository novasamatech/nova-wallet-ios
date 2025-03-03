protocol ParaStkYourCollatorsInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol ParaStkYourCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveCollators(result: Result<[ParachainStkCollatorSelectionInfo], Error>)
    func didReceiveDelegator(result: Result<ParachainStaking.Delegator?, Error>)
    func didReceiveScheduledRequests(result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>)
}

protocol ParaStkYourCollatorsWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    CollatorStkManageCollatorsPresentable {
    func showCollatorInfo(
        from view: CollatorStkYourCollatorsViewProtocol?,
        collatorInfo: ParachainStkCollatorSelectionInfo
    )

    func showStakeMore(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )

    func showUnstake(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        delegationRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )
}
