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
}

protocol ParaStkYourCollatorsWireframeProtocol: AnyObject {
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
}
