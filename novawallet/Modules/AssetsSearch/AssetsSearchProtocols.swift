protocol AssetsSearchViewProtocol: ControllerBackedProtocol {
    func didReceiveGroups(state: WalletListGroupState)
}

protocol AssetsSearchPresenterProtocol: AnyObject {
    func setup()
    func selectAsset(for chainAssetId: ChainAssetId)
    func updateSearch(query: String)
    func cancel()
}

protocol AssetsSearchInteractorInputProtocol: WalletListBaseInteractorInputProtocol {}

protocol AssetsSearchInteractorOutputProtocol: WalletListBaseInteractorOutputProtocol {}

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
