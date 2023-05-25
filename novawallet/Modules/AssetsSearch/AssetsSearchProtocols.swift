protocol AssetsSearchViewProtocol: ControllerBackedProtocol {
    func didReceiveGroups(state: AssetListGroupState)
}

protocol AssetsSearchPresenterProtocol: AnyObject {
    func setup()
    func selectAsset(for chainAssetId: ChainAssetId)
    func updateSearch(query: String)
    func cancel()
}

protocol AssetsSearchInteractorInputProtocol: AssetListBaseInteractorInputProtocol {}

protocol AssetsSearchInteractorOutputProtocol: AssetListBaseInteractorOutputProtocol {}

protocol AssetsSearchWireframeProtocol: AnyObject {
    func finish(
        selection: ChainAsset,
        view: AssetsSearchViewProtocol?
    )
    func cancel(from view: AssetsSearchViewProtocol?)
}

protocol AssetsSearchDelegate: AnyObject {
    func assetSearchDidSelect(chainAssetId: ChainAssetId)
    func assetSearchDidCancel()
}

extension AssetsSearchDelegate {
    func assetSearchDidCancel() {}
}
