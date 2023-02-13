import RobinHood
protocol DelegateVotedReferendaViewProtocol: ControllerBackedProtocol {
    func update(viewModels: [ReferendumsCellViewModel])
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
}

protocol DelegateVotedReferendaPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegateVotedReferendaInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol DelegateVotedReferendaInteractorOutputProtocol: AnyObject {
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotes)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveError(_ error: DelegateVotedReferendaError)
}

protocol DelegateVotedReferendaWireframeProtocol: AnyObject {}

enum DelegateVotedReferendaError: Error {
    case blockNumberSubscriptionFailed(Error)
    case metadataSubscriptionFailed(Error)
    case offchainVotingFetchFailed(Error)
    case settingsLoadFailed
    case blockTimeServiceFailed(Error)
    case blockTimeFetchFailed(Error)
    case referendumsFetchFailed(Error)
}
