import Foundation

extension AddAccount {
    final class PVScanWireframe: PVScanWireframeProtocol {
        func completeScan(
            on view: ControllerBackedProtocol?,
            account: PolkadotVaultAccount,
            type: ParitySignerType
        ) {
            guard
                let addressesView = PVAddressesViewFactory.createAddAccountView(
                    with: account,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(addressesView.controller, animated: true)
        }
    }
}
