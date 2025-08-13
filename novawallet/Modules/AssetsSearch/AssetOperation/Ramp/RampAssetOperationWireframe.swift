import UIKit
import UIKit_iOS

protocol RampAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol,
    MessageSheetPresentable,
    RampPresentable,
    AlertPresentable, FeatureSupportChecking {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        rampType: RampActionType
    )
}

extension RampAssetOperationWireframeProtocol {
    func close(view: ControllerBackedProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(
            animated: true,
            completion: completion
        )
    }
}

final class RampAssetOperationWireframe: AssetOperationWireframe, RampAssetOperationWireframeProtocol {
    private weak var delegate: RampFlowStartingDelegate?

    init(
        delegate: RampFlowStartingDelegate?,
        stateObservable: AssetListModelObservable
    ) {
        super.init(stateObservable: stateObservable)
        self.delegate = delegate
    }
}

extension RampAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        rampType: RampActionType
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createRampView(
            with: multichainToken,
            stateObservable: stateObservable,
            selectedAccount: selectedAccount,
            rampProvider: rampProvider,
            rampType: rampType,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            selectNetworkView.controller,
            animated: true
        )
    }
}
