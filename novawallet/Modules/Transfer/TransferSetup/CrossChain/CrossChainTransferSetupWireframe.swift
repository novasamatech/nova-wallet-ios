import Foundation
import CommonWallet

final class CrossChainTransferSetupWireframe: CrossChainTransferSetupWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    ) {

    }

    func showRecepientScan(from view: TransferSetupChildViewProtocol?, delegate: TransferScanDelegate) {
        guard let scanView = TransferScanViewFactory.createView(for: delegate) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: scanView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func hideRecepientScan(from view: TransferSetupChildViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
