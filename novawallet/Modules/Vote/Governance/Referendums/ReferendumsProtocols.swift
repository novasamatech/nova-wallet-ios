import Foundation

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: ChainBalanceViewModel)
}

protocol ReferendumsPresenterProtocol: AnyObject {}

protocol ReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(chainModel: ChainModel)
    func becomeOnline()
    func putOffline()
    func refresh()
    func remakeSubscriptions()
}

protocol ReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ metadata: ReferendumMetadataMapping?)
    func didReceiveVotes(_ votes: [Referenda.ReferendumIndex: ReferendumAccountVoteLocal])
    func didReceiveSelectedChain(_ chain: ChainModel)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )
}
