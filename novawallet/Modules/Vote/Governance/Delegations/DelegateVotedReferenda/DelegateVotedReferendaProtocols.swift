import RobinHood
import SoraFoundation

protocol DelegateVotedReferendaViewProtocol: ControllerBackedProtocol {
    func update(viewModels: [ReferendumsCellViewModel])
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
    func update(title: LocalizableResource<String>)
}

protocol DelegateVotedReferendaPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegateVotedReferendaInteractorInputProtocol: AnyObject {
    func setup()
    func retryBlockTime()
    func retryOffchainVotingFetch()
}

protocol DelegateVotedReferendaInteractorOutputProtocol: AnyObject {
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotes)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveError(_ error: DelegateVotedReferendaError)
    func didReceiveChain(_ chainModel: ChainModel)
}

protocol DelegateVotedReferendaWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable {}

enum DelegateVotedReferendaError: Error {
    case blockNumberSubscriptionFailed(Error)
    case metadataSubscriptionFailed(Error)
    case offchainVotingFetchFailed(Error)
    case settingsLoadFailed
    case blockTimeServiceFailed(Error)
    case blockTimeFetchFailed(Error)
    case referendumsFetchFailed(Error)
}
