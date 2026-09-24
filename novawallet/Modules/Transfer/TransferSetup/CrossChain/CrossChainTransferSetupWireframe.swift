import Foundation

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    let xcmTransfers: XcmTransfers
    let transferCompletion: TransferCompletionClosure?
    let analyticsFlow: TransferAnalyticsFlow

    init(
        xcmTransfers: XcmTransfers,
        transferCompletion: TransferCompletionClosure?,
        analyticsFlow: TransferAnalyticsFlow
    ) {
        self.xcmTransfers = xcmTransfers
        self.transferCompletion = transferCompletion
        self.analyticsFlow = analyticsFlow
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
            transferCompletion: transferCompletion,
            analyticsFlow: analyticsFlow
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
