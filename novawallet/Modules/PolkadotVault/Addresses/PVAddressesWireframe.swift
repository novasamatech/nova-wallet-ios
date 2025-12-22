import Foundation

final class PVAddressesWireframe: PVAddressesWireframeProtocol {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        account: PolkadotVaultAccount,
        type: ParitySignerType
    ) {
        guard
            let confirmationView = PVAddConfirmViewFactory.createOnboardingView(
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
