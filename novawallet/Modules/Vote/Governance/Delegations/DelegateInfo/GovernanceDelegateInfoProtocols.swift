protocol GovernanceDelegateInfoViewProtocol: ControllerBackedProtocol {}

protocol GovernanceDelegateInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol GovernanceDelegateInfoInteractorInputProtocol: AnyObject {
    func setup()
    func refreshDetails()
    func remakeSubscriptions()
    func refreshIdentity()
}

protocol GovernanceDelegateInfoInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(_ details: GovernanceDelegateDetails?)
    func didReceiveMetadata(_ metadata: GovernanceDelegateMetadataRemote?)
    func didReceiveIdentity(_ identity: AccountIdentity?)
    func didReceiveError(_ error: GovernanceDelegateInfoError)
}

protocol GovernanceDelegateInfoWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {}
