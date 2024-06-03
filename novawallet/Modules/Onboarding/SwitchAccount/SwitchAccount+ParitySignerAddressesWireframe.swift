import Foundation

extension SwitchAccount {
    final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
        func showConfirmation(
            on view: ParitySignerAddressesViewProtocol?,
            accountId: AccountId,
            type: ParitySignerType
        ) {
            guard
                let confirmationView = ParitySignerAddConfirmViewFactory.createSwitchAccountView(
                    with: accountId,
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
