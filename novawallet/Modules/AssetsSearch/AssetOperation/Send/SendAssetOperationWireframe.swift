import UIKit
import SoraUI

protocol SendAssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSendTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset)
}

final class SendAssetOperationWireframe: SendAssetOperationWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?

    init(transferCompletion: TransferCompletionClosure?) {
        self.transferCompletion = transferCompletion
    }

    func showSendTokens(from view: ControllerBackedProtocol?, chainAsset: ChainAsset) {
        guard let transferSetupView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: nil,
            transferCompletion: transferCompletion
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
