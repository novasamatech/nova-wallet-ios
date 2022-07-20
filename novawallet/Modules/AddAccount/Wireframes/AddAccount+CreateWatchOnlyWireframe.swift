import Foundation

extension AddAccount {
    final class CreateWatchOnlyWireframe: BaseCreateWatchOnlyWireframe, CreateWatchOnlyWireframeProtocol {
        func proceed(from view: CreateWatchOnlyViewProtocol?) {
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
