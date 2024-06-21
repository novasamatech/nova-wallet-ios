import Foundation
import IrohaCrypto

extension AddAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func confirm(
            from view: AccountCreateViewProtocol?,
            request: MetaAccountCreationRequest,
            metadata: MetaAccountCreationMetadata
        ) {
            guard let accountConfirmation = AccountConfirmViewFactory
                .createViewForAdding(request: request, metadata: metadata)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(accountConfirmation, animated: true)
            }
        }
    }
}
