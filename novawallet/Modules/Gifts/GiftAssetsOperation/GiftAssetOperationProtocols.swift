protocol GiftAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    )
    func showGiftTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    )
}
