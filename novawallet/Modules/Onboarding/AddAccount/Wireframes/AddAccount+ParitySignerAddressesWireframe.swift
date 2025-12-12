import Foundation

extension AddAccount {
    final class PVAddressesWireframe: PVAddressesWireframeProtocol {
        func showConfirmation(
            on view: HardwareWalletAddressesViewProtocol?,
            account: PolkadotVaultAccount,
            type: ParitySignerType
        ) {
            guard
                let confirmationView = PVAddConfirmViewFactory.createAddAccountView(
                    with: account,
                    type: type
                ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                confirmationView.controller,
                animated: true
            )
        }
    }
}
