import UIKit
import SoraUI

protocol BuyAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol, MessageSheetPresentable,
    PurchasePresentable, AlertPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    )
}

final class BuyAssetOperationWireframe: AssetOperationWireframe, BuyAssetOperationWireframeProtocol {}

extension BuyAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createBuyView(
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

    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
