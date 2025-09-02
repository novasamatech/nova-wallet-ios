import BigInt
import Operation_iOS

protocol ChainAssetSelectionViewProtocol: SelectionListViewProtocol {}

protocol ChainAssetSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol ChainAssetSelectionWireframeProtocol: ChainAssetSelectionBaseWireframeProtocol {
    func complete(on view: ChainAssetSelectionViewProtocol, selecting chainAsset: ChainAsset)
}

protocol ChainAssetSelectionDelegate: AnyObject {
    func assetSelection(view: ChainAssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset)
}

typealias ChainAssetSelectionFilter = (ChainAsset) -> Bool

protocol ChainAssetSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ChainAssetSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveChainAssets(result: Result<[ChainAsset], Error>)
    func didReceiveBalance(resultWithChanges: Result<[ChainAssetId: AssetBalance], Error>)
    func didReceivePrice(changes: [ChainAssetId: DataProviderChange<PriceData>])
    func didReceivePrice(error: Error)
}
