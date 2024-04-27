import Foundation

extension AddAccount {
    final class ParitySignerAddressesWireframe: ParitySignerAddressesWireframeProtocol {
        func showConfirmation(
            on view: ParitySignerAddressesViewProtocol?,
            accountId: AccountId,
            type: ParitySignerType
        ) {
            guard
                let confirmationView = ParitySignerAddConfirmViewFactory.createAddAccountView(
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
