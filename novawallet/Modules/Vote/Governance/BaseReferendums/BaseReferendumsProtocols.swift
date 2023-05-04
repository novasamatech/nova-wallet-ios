import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

protocol BaseReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func becomeOnline()
    func putOffline()
    func refresh()
    func remakeSubscriptions()
    func retryBlockTime()
    func retryOffchainVotingFetch()
}

protocol BaseReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotesLocal)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: BaseReferendumsInteractorError)
}
