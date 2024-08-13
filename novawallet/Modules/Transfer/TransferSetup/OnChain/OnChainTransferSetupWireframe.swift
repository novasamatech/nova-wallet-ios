import Foundation

class OnChainTransferSetupWireframe: OnChainTransferSetupWireframeProtocol {
    let transferCompletion: TransferCompletionClosure?

    init(transferCompletion: TransferCompletionClosure?) {
        self.transferCompletion = transferCompletion
    }

    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        sendingAmount: OnChainTransferAmount<Decimal>,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmOnChainViewFactory.createView(
            chainAsset: chainAsset,
            feeAsset: feeAsset,
            recepient: recepient,
            amount: sendingAmount,
            transferCompletion: transferCompletion
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

final class EvmOnChainTransferSetupWireframe: OnChainTransferSetupWireframe, EvmValidationErrorPresentable {}
