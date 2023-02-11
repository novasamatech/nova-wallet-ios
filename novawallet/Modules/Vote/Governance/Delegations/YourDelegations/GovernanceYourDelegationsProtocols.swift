protocol GovernanceYourDelegationsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [GovernanceYourDelegationCell.Model])
}

protocol GovernanceYourDelegationsPresenterProtocol: AnyObject {
    func setup()
    func addDelegation()
    func selectDelegate(for address: AccountAddress)
}

protocol GovernanceYourDelegationsInteractorInputProtocol: AnyObject {
    func setup()
    func refreshDelegates()
    func remakeSubscriptions()
    func refreshTracks()
}

protocol GovernanceYourDelegationsInteractorOutputProtocol: AnyObject {
    func didReceiveDelegations(_ delegations: [TrackIdLocal: ReferendumDelegatingLocal])
    func didReceiveDelegates(_ delegates: [GovernanceDelegateLocal])
    func didReceiveTracks(_ tracks: [GovernanceTrackInfoLocal])
    func didReceiveError(_ error: GovernanceYourDelegationsInteractorError)
}

protocol GovernanceYourDelegationsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showAddDelegation(from view: GovernanceYourDelegationsViewProtocol?)
    func showDelegateInfo(from view: GovernanceYourDelegationsViewProtocol?, delegate: GovernanceDelegateLocal)
}
