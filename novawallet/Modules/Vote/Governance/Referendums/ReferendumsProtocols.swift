import Foundation

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: ChainBalanceViewModel)
    func update(model: ReferendumsViewModel)
    func updateReferendums(time: [UInt: StatusTimeViewModel?])
}

protocol ReferendumsPresenterProtocol: AnyObject {
    func select(referendumIndex: UInt)
}

protocol ReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(chainModel: ChainModel)
    func becomeOnline()
    func putOffline()
    func refresh()
    func remakeSubscriptions()
    func retryBlockTime()
}

protocol ReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveReferendums(_ referendums: [ReferendumLocal])
    func didReceiveReferendumsMetadata(_ metadata: ReferendumMetadataMapping?)
    func didReceiveVotes(_ votes: [ReferendumIdLocal: ReferendumAccountVoteLocal])
    func didReceiveSelectedChain(_ chain: ChainModel)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveBlockTime(_ blockTime: BlockTime)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )

    func showReferendumDetails(from view: ControllerBackedProtocol?, referendum: ReferendumLocal)
}
