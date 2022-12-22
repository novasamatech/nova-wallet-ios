import Foundation
import CommonWallet

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    func showSend(
        from view: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let transferView = TransferSetupViewFactory.createView(
            from: chainAsset,
            recepient: displayAddress
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(transferView.controller, animated: true)
    }
}
