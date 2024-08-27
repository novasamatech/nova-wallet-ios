import Foundation

final class PayCardWireframe: PayCardWireframeProtocol {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: MercuryoTransferModel
    ) {
        guard let sendTransferView = TransferSetupViewFactory.createCardTopUpView(
            from: transferModel.chainAsset,
            recepient: DisplayAddress(address: transferModel.address, username: ""),
            amount: transferModel.amount,
            transferCompletion: nil
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
