import UIKit
import SoraUI

protocol BuyAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol,
    MessageSheetPresentable,
    RampPresentable,
    AlertPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol
    )
}

final class BuyAssetOperationWireframe: AssetOperationWireframe, BuyAssetOperationWireframeProtocol {}

extension BuyAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createBuyView(
            with: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            rampProvider: rampProvider
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
