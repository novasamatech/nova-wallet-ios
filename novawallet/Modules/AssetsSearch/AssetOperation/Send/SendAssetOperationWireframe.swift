import UIKit
import SoraUI

protocol SendAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSendTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset)
}

final class SendAssetOperationWireframe: SendAssetOperationWireframeProtocol {
    func showSendTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(transferSetupView.controller, animated: true)
    }
}

extension SendAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
