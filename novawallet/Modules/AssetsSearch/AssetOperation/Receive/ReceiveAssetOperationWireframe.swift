protocol ReceiveAssetOperationWireframeProtocol: MessageSheetPresentable, AssetsSearchWireframeProtocol {
    func showReceiveTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
    
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        metaChainAccountResponse: MetaChainAccountResponse
    )
}

final class ReceiveAssetOperationWireframe: AssetOperationWireframe, ReceiveAssetOperationWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        metaChainAccountResponse: MetaChainAccountResponse
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createView(
            with: multichainToken,
            stateObservable: stateObservable
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectNetworkView.controller,
            animated: true
        )
    }
    
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
    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
