protocol ParaStkCollatorInfoViewProtocol: ValidatorInfoViewProtocol {}

protocol ParaStkCollatorInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol ParaStkCollatorInfoInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol ParaStkCollatorInfoInteractorOutputProtocol: AnyObject {
    func didReceivePrice(result: Result<PriceData?, Error>)
}

protocol ParaStkCollatorInfoWireframeProtocol: IdentityPresentable,
    AddressOptionsPresentable,
    ErrorPresentable,
    StakingTotalStakePresentable {}
