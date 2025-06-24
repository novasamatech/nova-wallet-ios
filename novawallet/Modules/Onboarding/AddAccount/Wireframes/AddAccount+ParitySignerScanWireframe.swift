import Foundation

extension AddAccount {
    final class ParitySignerScanWireframe: ParitySignerScanWireframeProtocol {
        func completeScan(
            on view: ControllerBackedProtocol?,
            walletUpdate: PolkadotVaultWalletUpdate,
            type: ParitySignerType
        ) {
            guard
                let addressesView = ParitySignerAddressesViewFactory.createAddAccountView(
                    with: walletUpdate,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
