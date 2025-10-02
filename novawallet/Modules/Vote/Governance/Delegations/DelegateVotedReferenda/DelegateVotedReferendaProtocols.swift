import Operation_iOS
import Foundation_iOS

protocol DelegateVotedReferendaViewProtocol: ControllerBackedProtocol {
    func update(viewModels: [ReferendumsCellViewModel])
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
    func update(title: LocalizableResource<String>)
}

protocol DelegateVotedReferendaPresenterProtocol: AnyObject {
    func setup()
    func selectReferendum(with referendumId: ReferendumIdLocal)
}

protocol DelegateVotedReferendaInteractorInputProtocol: AnyObject {
    func setup()
    func retryBlockTime()
    func retryTimepointThreshold()
    func retryOffchainVotingFetch()
    func remakeSubscription()
}

protocol DelegateVotedReferendaInteractorOutputProtocol: AnyObject {
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveOffchainVoting(_ voting: DelegateVotedReferendaModel)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: DelegateVotedReferendaError)
}

protocol DelegateVotedReferendaWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable {
    func showReferendumDetails(from view: ControllerBackedProtocol?, initData: ReferendumDetailsInitData)
}

enum DelegateVotedReferendaError: Error {
    case blockNumberSubscriptionFailed(Error)
    case metadataSubscriptionFailed(Error)
    case offchainVotingFetchFailed(Error)
    case blockTimeFetchFailed(Error)
    case timepointThresholdFetchFailed(Error)
}
