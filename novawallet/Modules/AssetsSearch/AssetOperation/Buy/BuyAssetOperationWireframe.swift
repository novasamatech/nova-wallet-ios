import UIKit
import SoraUI

protocol BuyAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol, MessageSheetPresentable,
    PurchasePresentable, AlertPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol
    )
}

final class BuyAssetOperationWireframe: AssetOperationWireframe, BuyAssetOperationWireframeProtocol {}

extension BuyAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        purchaseProvider: PurchaseProviderProtocol
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createBuyView(
            with: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            purchaseProvider: purchaseProvider
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectNetworkView.controller,
            animated: true
        )
    }

    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
