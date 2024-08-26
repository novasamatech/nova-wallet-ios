import Foundation

final class PayCardWireframe: PayCardWireframeProtocol {
    func showSend(
        from view: ControllerBackedProtocol?,
        with transferModel: MercuryoTransferModel
    ) {
        guard let sendTransferView = TransferSetupViewFactory.createView(
            from: transferModel.chainAsset,
            recepient: DisplayAddress(address: transferModel.address, username: ""),
            amount: transferModel.amount,
            transferCompletion: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            sendTransferView.controller,
            animated: true
        )
    }
}
