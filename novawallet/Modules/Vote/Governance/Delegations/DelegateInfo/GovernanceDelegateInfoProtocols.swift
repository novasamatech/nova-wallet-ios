protocol GovernanceDelegateInfoViewProtocol: ControllerBackedProtocol {
    func didReceiveDelegate(viewModel: GovernanceDelegateInfoViewModel.Delegate)
    func didReceiveStats(viewModel: GovernanceDelegateInfoViewModel.Stats)
    func didReceiveYourDelegation(viewModel: GovernanceDelegateInfoViewModel.YourDelegation?)
    func didReceiveIdentity(items: [ValidatorInfoViewModel.IdentityItem]?)
}

protocol GovernanceDelegateInfoPresenterProtocol: AnyObject {
    func setup()
    func presentFullDescription()
    func presentDelegations()
    func presentRecentVotes()
    func presentAllVotes()
    func presentIdentityItem(_ item: ValidatorInfoViewModel.IdentityItemValue)
    func presentAccountOptions()
    func addDelegation()
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

protocol GovernanceDelegateInfoWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    AddressOptionsPresentable, WebPresentable, IdentityPresentable {
    func showFullDescription(
        from view: GovernanceDelegateInfoViewProtocol?,
        name: String,
        longDescription: String
    )

    func showDelegations(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress
    )

    func showRecentVotes(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress,
        delegateName: String?
    )

    func showAllVotes(
        from view: GovernanceDelegateInfoViewProtocol?,
        delegateAddress: AccountAddress,
        delegateName: String?
    )

    func showAddDelegation(from view: GovernanceDelegateInfoViewProtocol?)
}
