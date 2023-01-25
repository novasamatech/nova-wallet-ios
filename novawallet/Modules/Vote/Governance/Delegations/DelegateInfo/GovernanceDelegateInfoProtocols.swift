protocol GovernanceDelegateInfoViewProtocol: ControllerBackedProtocol {
    func didReceiveDelegate(viewModel: GovernanceDelegateInfoViewModel.Delegate)
    func didReceiveStats(viewModel: GovernanceDelegateInfoViewModel.Stats)
    func didReceiveYourDelegation(viewModel: GovernanceDelegateInfoViewModel.YourDelegation?)
    func didReceiveIdentity(items: [ValidatorInfoViewModel.IdentityItem]?)
}

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
