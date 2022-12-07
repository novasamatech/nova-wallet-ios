import Foundation
import CommonWallet

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    let xcmTransfers: XcmTransfers

    init(xcmTransfers: XcmTransfers) {
        self.xcmTransfers = xcmTransfers
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
            amount: sendingAmount
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
