protocol ParaStkCollatorInfoViewProtocol: ValidatorInfoViewProtocol {}

protocol ParaStkCollatorInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol ParaStkCollatorInfoInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol ParaStkCollatorInfoInteractorOutputProtocol: AnyObject {
    func didReceivePrice(_ price: PriceData?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveError(_ error: Error)
}

protocol ParaStkCollatorInfoWireframeProtocol: IdentityPresentable,
    AddressOptionsPresentable,
    ErrorPresentable,
    StakingTotalStakePresentable {}
