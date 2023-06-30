protocol AssetsSearchViewProtocol: ControllerBackedProtocol {
    func didReceiveGroups(state: AssetListGroupState)
}

protocol AssetsSearchPresenterProtocol: AnyObject {
    func setup()
    func selectAsset(for chainAssetId: ChainAssetId)
    func updateSearch(query: String)
    func cancel()
}

protocol AssetsSearchInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetsSearchInteractorOutputProtocol: AnyObject {
    func didReceive(state: AssetListState)
}

protocol AssetsSearchWireframeProtocol: AnyObject {
    func close(view: AssetsSearchViewProtocol?)
}

protocol AssetsSearchDelegate: AnyObject {
    func assetSearchDidSelect(chainAssetId: ChainAssetId)
    func assetSearchDidCancel()
}

extension AssetsSearchDelegate {
    func assetSearchDidCancel() {}
}
