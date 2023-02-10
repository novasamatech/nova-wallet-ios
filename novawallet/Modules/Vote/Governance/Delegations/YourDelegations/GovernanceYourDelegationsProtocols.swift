protocol GovernanceYourDelegationsViewProtocol: ControllerBackedProtocol {}

protocol GovernanceYourDelegationsPresenterProtocol: AnyObject {
    func setup()
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

protocol GovernanceYourDelegationsWireframeProtocol: AnyObject {}
