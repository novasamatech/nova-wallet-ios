import Foundation

final class LedgerAddAccountConfirmationWireframe: LedgerBaseAccountConfirmationWireframe,
    LedgerAccountConfirmationWireframeProtocol {
    func complete(on view: LedgerAccountConfirmationViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
