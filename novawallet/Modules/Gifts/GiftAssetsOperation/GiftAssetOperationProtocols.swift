protocol GiftAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    )
    func showSendTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
}
