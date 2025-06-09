import Foundation

final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
    func showConfirmation(
        on view: HardwareWalletAddressesViewProtocol?,
        walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType
    ) {
        guard
            let confirmationView = ParitySignerAddConfirmViewFactory.createOnboardingView(
                with: walletFormat,
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
