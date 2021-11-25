import Foundation
import IrohaCrypto

extension ImportChainAccount {
    final class AccountImportWireframe: AccountImportWireframeProtocol {
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
