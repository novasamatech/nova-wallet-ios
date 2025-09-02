protocol MythosStkYourCollatorsInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol MythosStkYourCollatorsInteractorOutputProtocol: AnyObject {
    func didReceiveStakingDetails(_ details: MythosStakingDetails?)
    func didReceiveCollatorsResult(_ result: Result<[CollatorStakingSelectionInfoProtocol], Error>)
}

protocol MythosStkYourCollatorsWireframeProtocol: AnyObject, CollatorStkManageCollatorsPresentable {
    func showCollatorInfo(
        from view: CollatorStkYourCollatorsViewProtocol?,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    )

    func showStakeMore(
        from view: CollatorStkYourCollatorsViewProtocol?,
        initialDetails: MythosStakingDetails?
    )

    func showUnstake(from view: CollatorStkYourCollatorsViewProtocol?)
}
