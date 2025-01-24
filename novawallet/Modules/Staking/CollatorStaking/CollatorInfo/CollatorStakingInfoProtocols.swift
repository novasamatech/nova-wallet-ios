protocol CollatorStakingInfoViewProtocol: ValidatorInfoViewProtocol {}

protocol CollatorStakingInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol CollatorStakingInfoInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol CollatorStakingInfoInteractorOutputProtocol: AnyObject {
    func didReceivePrice(_ price: PriceData?)
    func didReceiveDelegator(_ delegator: CollatorStakingDelegator?)
    func didReceiveError(_ error: Error)
}

protocol CollatorStakingInfoWireframeProtocol: IdentityPresentable,
    AddressOptionsPresentable,
    ErrorPresentable,
    StakingTotalStakePresentable {}
