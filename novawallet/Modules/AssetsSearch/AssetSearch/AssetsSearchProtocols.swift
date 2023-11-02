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
    func search(query: String)
}

protocol AssetsSearchInteractorOutputProtocol: AnyObject {
    func didReceive(result: AssetSearchBuilderResult)
}

protocol AssetsSearchWireframeProtocol: AnyObject {
    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?)
}

extension AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        close(view: view, completion: nil)
    }
}

protocol AssetsSearchDelegate: AnyObject {
    func assetSearchDidSelect(chainAssetId: ChainAssetId)
    func assetSearchDidCancel()
}

extension AssetsSearchDelegate {
    func assetSearchDidCancel() {}
}
