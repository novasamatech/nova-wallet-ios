import Foundation

extension SwitchAccount {
    final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
        func showConfirmation(on view: ParitySignerAddressesViewProtocol?, accountId: AccountId) {
            guard
                let confirmationView = ParitySignerAddConfirmViewFactory.createSwitchAccountView(
                    with: accountId
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
