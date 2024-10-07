import Foundation

final class PayCardWireframe: PayCardWireframeProtocol {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: PayCardTopupModel,
        transferCompletion: @escaping TransferCompletionClosure
    ) {
        guard let sendTransferView = TransferSetupViewFactory.createCardTopUpView(
            from: transferModel.chainAsset,
            recepient: DisplayAddress(address: transferModel.recipientAddress, username: ""),
            amount: transferModel.amount,
            transferCompletion: transferCompletion
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: sendTransferView.controller)

        view?.controller.present(
            navigationController,
            animated: true
        )
    }
}
