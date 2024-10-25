import UIKit
import SoraUI

final class SendAssetOperationWireframe: AssetOperationWireframe, SendAssetOperationWireframeProtocol {
    private let transferCompletion: TransferCompletionClosure?
    private let buyTokensClosure: BuyTokensClosure?

    init(
        stateObservable: AssetListModelObservable,
        buyTokensClosure: BuyTokensClosure?,
        transferCompletion: TransferCompletionClosure?
    ) {
        self.buyTokensClosure = buyTokensClosure
        self.transferCompletion = transferCompletion

        super.init(stateObservable: stateObservable)
    }

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        multichainToken: MultichainToken
    ) {
        guard let selectNetworkView = AssetOperationNetworkListViewFactory.createSendView(
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
    func close(view: AssetsSearchViewProtocol?, completion: (() -> Void)?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completion)
    }
}
