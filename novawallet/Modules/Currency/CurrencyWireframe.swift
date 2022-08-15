import Foundation

final class CurrencyWireframe: CurrencyWireframeProtocol {
    func complete(view: CurrencyViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
