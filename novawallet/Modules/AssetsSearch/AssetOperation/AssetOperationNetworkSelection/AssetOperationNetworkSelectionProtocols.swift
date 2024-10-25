protocol AssetOperationNetworkListViewProtocol: ControllerBackedProtocol {
    func update(with viewModels: [AssetOperationNetworkViewModel])
    func updateHeader(with text: String)
}

protocol AssetOperationNetworkListPresenterProtocol: AnyObject {
    func setup()
    func selectAsset(with chainAssetId: ChainAssetId)
}

protocol AssetOperationNetworkListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetOperationNetworkListInteractorOutputProtocol: AnyObject {
    func didReceive(result: AssetOperationNetworkBuilderResult)
}

protocol AssetOperationNetworkListWireframeProtocol: AnyObject {
    func showOperation(for chainAsset: ChainAsset)
}
