import Foundation

extension AddAccount {
    final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
        func showConfirmation(
            on view: HardwareWalletAddressesViewProtocol?,
            walletUpdate: PolkadotVaultWalletUpdate,
            type: ParitySignerType
        ) {
            guard
                let confirmationView = ParitySignerAddConfirmViewFactory.createAddAccountView(
                    with: walletUpdate,
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
