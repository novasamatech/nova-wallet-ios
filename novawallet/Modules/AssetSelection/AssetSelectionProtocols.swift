import BigInt
import RobinHood

protocol AssetSelectionViewProtocol: SelectionListViewProtocol {}

protocol AssetSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol AssetSelectionWireframeProtocol: AssetSelectionBaseWireframeProtocol {
    func complete(on view: AssetSelectionViewProtocol, selecting chainAsset: ChainAsset)
}

protocol AssetSelectionDelegate: AnyObject {
    func assetSelection(view: AssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset)
}

typealias AssetSelectionFilter = (ChainAsset) -> Bool

protocol AssetSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>])
    func didReceivePrice(changes: [ChainAssetId: DataProviderChange<PriceData>])
    func didReceivePrice(error: Error)
}
