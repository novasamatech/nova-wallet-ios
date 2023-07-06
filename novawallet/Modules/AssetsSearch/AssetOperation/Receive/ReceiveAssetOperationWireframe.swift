protocol ReceiveAssetOperationWireframeProtocol: MessageSheetPresentable, AssetsSearchWireframeProtocol {
    func showReceiveTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
}

final class ReceiveAssetOperationWireframe: ReceiveAssetOperationWireframeProtocol {
    func showReceiveTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let receiveTokensView = AssetReceiveViewFactory.createView(
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(receiveTokensView.controller, animated: true)
    }
}

extension ReceiveAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
