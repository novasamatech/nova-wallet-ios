import Foundation
import RobinHood

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: ChainBalanceViewModel)
    func update(model: ReferendumsViewModel)
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
    func didReceiveUnlocks(viewModel: ReferendumsUnlocksViewModel?)
}

protocol ReferendumsPresenterProtocol: AnyObject {
    func select(referendumIndex: UInt)
    func selectUnlocks()
}

protocol ReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(chainModel: ChainModel)
    func becomeOnline()
    func putOffline()
    func refresh()
    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?)
    func remakeSubscriptions()
    func retryBlockTime()
}

protocol ReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>])
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>)
    func didReceiveSelectedChain(_ chain: ChainModel)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveUnlockSchedule(_ unlockSchedule: GovernanceUnlockSchedule)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )

    func showReferendumDetails(
        from view: ControllerBackedProtocol?,
        referendum: ReferendumLocal,
        accountVotes: ReferendumAccountVoteLocal?,
        metadata: ReferendumMetadataLocal?
    )

    func showUnlocksDetails(from view: ControllerBackedProtocol?)
}
