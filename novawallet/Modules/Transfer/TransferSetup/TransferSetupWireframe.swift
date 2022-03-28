import Foundation
import CommonWallet

final class TransferSetupWireframe: TransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showConfirmation(
        from _: TransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {
        guard let confirmView = TransferConfirmViewFactory.createView(
            chainAsset: chainAsset,
            recepient: recepient,
            amount: sendingAmount
        ) else {
            return
        }

        let command = commandFactory?.preparePresentationCommand(for: confirmView.controller)
        command?.presentationStyle = .push(hidesBottomBar: true)
        try? command?.execute()
    }

    func showRecepientScan(from view: TransferSetupViewProtocol?, delegate: TransferScanDelegate) {
        guard let scanView = TransferScanViewFactory.createView(for: delegate) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: scanView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func hideRecepientScan(from view: TransferSetupViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
