import Foundation

final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType
    ) {
        guard
            let confirmationView = ParitySignerAddConfirmViewFactory.createOnboardingView(
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
