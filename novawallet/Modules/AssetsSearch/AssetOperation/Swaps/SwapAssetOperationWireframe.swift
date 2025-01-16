import UIKit
import UIKit_iOS

final class SwapAssetsOperationWireframe: SwapAssetsOperationWireframeProtocol {
    let state: SwapTokensFlowStateProtocol
    let selectClosure: SwapAssetSelectionClosure
    let selectClosureStrategy: SubmoduleNavigationStrategy

    init(
        state: SwapTokensFlowStateProtocol,
        selectClosure: @escaping SwapAssetSelectionClosure,
        selectClosureStrategy: SubmoduleNavigationStrategy
    ) {
        self.state = state
        self.selectClosure = selectClosure
        self.selectClosureStrategy = selectClosureStrategy
    }

    func showSelectNetwork(from view: ControllerBackedProtocol?, multichainToken: MultichainToken) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createSwapsView(
            with: multichainToken,
            state: state,
            selectClosure: selectClosure,
            selectClosureStrategy: selectClosureStrategy
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectNetworkView.controller,
            animated: true
        )
    }
}

extension SwapAssetsOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
