import Foundation

final class ChangeWatchOnlyWireframe: ChangeWatchOnlyWireframeProtocol {
    func complete(view: ChangeWatchOnlyViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
