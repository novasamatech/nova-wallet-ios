import UIKit
import SoraUI

final class SendAssetOperationWireframe: SendAssetOperationWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?
    private let buyTokensClosure: BuyTokensClosure?

    init(
        buyTokensClosure: BuyTokensClosure?,
        transferCompletion: TransferCompletionClosure?
    ) {
        self.buyTokensClosure = buyTokensClosure
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
        view?.controller.presentingViewController?.dismiss(animated: true) {
            self.buyTokensClosure?()
        }
    }
}

extension SendAssetOperationWireframe: AssetsSearchWireframeProtocol {
    func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
