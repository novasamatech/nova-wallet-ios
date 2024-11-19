protocol SendAssetOperationCollectionManagerActionDelegate: AnyObject {
    func actionBuy()
}

protocol SendAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    )
    func showSendTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
    func showBuyTokens(from view: ControllerBackedProtocol?)
}

protocol SendAssetOperationPresenterProtocol: AssetsSearchPresenterProtocol {
    func buy()
}
