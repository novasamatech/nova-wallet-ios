import Foundation

final class OnChainTransferSetupWireframe: OnChainTransferSetupWireframeProtocol {
    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmOnChainViewFactory.createView(
            chainAsset: chainAsset,
            recepient: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        guard let navigationController = view?.controller.navigationController else {
            return
        }
        confirmView.controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(confirmView.controller, animated: true)
    }
}
