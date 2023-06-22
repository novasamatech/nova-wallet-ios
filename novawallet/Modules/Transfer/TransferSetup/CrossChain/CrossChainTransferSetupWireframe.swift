import Foundation

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    let xcmTransfers: XcmTransfers
    let transferCompletion: TransferCompletionClosure?

    init(xcmTransfers: XcmTransfers, transferCompletion: TransferCompletionClosure?) {
        self.xcmTransfers = xcmTransfers
        self.transferCompletion = transferCompletion
    }

    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmCrossChainViewFactory.createView(
            originChainAsset: originChainAsset,
            destinationAsset: destinationChainAsset,
            xcmTransfers: xcmTransfers,
            recepient: recepient,
            amount: sendingAmount,
            transferCompletion: transferCompletion
        ) else {
            return
        }

        guard let navigationViewController = view?.controller.navigationController else {
            return
        }

        confirmView.controller.hidesBottomBarWhenPushed = true
        navigationViewController.pushViewController(confirmView.controller, animated: true)
    }
}
