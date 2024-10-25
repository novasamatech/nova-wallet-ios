protocol SendAssetOperationCollectionManagerActionDelegate: AnyObject {
    func actionBuy()
}

protocol SendAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSendTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset)
    func showBuyTokens(from view: ControllerBackedProtocol?)
}

protocol SendAssetOperationPresenterProtocol: AssetsSearchPresenterProtocol {
    func buy()
}
