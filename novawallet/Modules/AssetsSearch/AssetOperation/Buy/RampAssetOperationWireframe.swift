import UIKit
import SoraUI

protocol RampAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol,
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

extension RampAssetOperationWireframeProtocol {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}

final class BuyAssetOperationWireframe: AssetOperationWireframe, RampAssetOperationWireframeProtocol {}

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
}

final class SellAssetOperationWireframe: AssetOperationWireframe, RampAssetOperationWireframeProtocol {}

extension SellAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createSellView(
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
}
