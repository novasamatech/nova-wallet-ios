import UIKit
import SoraUI

final class SendAssetOperationWireframe: SendAssetOperationWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?
    private let stateObservable: AssetListStateObservable

    init(
        stateObservable: AssetListStateObservable,
        transferCompletion: TransferCompletionClosure?
    ) {
        self.stateObservable = stateObservable
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

    func showBuyTokens(
        from view: ControllerBackedProtocol?
    ) {
        guard let assetsSearchView = AssetOperationViewFactory.createView(
            for: stateObservable,
            operation: .buy,
            transferCompletion: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(assetsSearchView.controller, animated: true)
    }
}

extension SendAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
