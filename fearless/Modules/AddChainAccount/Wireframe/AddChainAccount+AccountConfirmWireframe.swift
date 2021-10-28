import Foundation

extension AddChainAccount {
    final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
        // TODO: Check where it should be redirected
        func proceed(from view: AccountConfirmViewProtocol?) {
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
