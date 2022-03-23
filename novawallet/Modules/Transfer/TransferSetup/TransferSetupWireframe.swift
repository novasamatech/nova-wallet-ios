import Foundation

final class TransferSetupWireframe: TransferSetupWireframeProtocol {
    func showConfirmation(
        from view: TransferSetupViewProtocol?,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmViewFactory.createView(
            from: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showRecepientScan(from _: TransferSetupViewProtocol?) {
        // TODO:
    }
}
