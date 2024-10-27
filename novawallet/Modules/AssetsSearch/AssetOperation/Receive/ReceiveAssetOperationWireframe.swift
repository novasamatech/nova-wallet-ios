protocol ReceiveAssetOperationWireframeProtocol: MessageSheetPresentable, AssetsSearchWireframeProtocol {
    func showReceiveTokens(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel
    )
}

final class ReceiveAssetOperationWireframe: AssetOperationWireframe, ReceiveAssetOperationWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createReceiveView(
            with: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount
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
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
