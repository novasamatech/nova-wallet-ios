import Foundation

extension AddAccount {
    final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
        func completeScan(
            on view: ControllerBackedProtocol?,
            walletFormat: ParitySignerWalletFormat,
            type: ParitySignerType
        ) {
            guard
                let addressesView = ParitySignerAddressesViewFactory.createAddAccountView(
                    with: walletFormat,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
