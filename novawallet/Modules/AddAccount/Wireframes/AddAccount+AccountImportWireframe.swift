import Foundation
import IrohaCrypto

extension AddAccount {
    final class AccountImportWireframe: BaseAccountImportWireframe, AccountImportWireframeProtocol {
        func proceed(from view: AccountImportViewProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            MainTransitionHelper.transitToMainTabBarController(
                closing: navigationController,
                animated: true
            )
        }
    }
}
