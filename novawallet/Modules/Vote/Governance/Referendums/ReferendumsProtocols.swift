import Foundation

protocol ReferendumsViewProtocol: ControllerBackedProtocol {
    var presenter: ReferendumsPresenterProtocol? { get set }

    func didReceiveChainBalance(viewModel: ChainBalanceViewModel)
}

protocol ReferendumsPresenterProtocol: AnyObject {}

protocol ReferendumsInteractorInputProtocol: AnyObject {
    func setup()
    func saveSelected(chainModel: ChainModel)
}

protocol ReferendumsInteractorOutputProtocol: AnyObject {
    func didReceiveSelectedChain(_ chain: ChainModel)
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveError(_ error: ReferendumsInteractorError)
}

protocol ReferendumsWireframeProtocol: AnyObject {
    func selectChain(
        from view: ControllerBackedProtocol?,
        delegate: AssetSelectionDelegate,
        selectedChainAssetId: ChainAssetId?
    )
}
