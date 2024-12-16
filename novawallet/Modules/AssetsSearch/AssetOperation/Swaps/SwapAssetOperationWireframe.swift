import UIKit
import SoraUI

final class SwapAssetsOperationWireframe: AssetOperationWireframe, SwapAssetsOperationWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectClosure: @escaping (ChainAsset) -> Void,
        selectClosureStrategy: SubmoduleNavigationStrategy
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createSwapsView(
            with: multichainToken,
            stateObservable: stateObservable,
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
