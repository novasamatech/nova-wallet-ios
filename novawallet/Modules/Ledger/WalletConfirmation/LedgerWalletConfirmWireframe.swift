import Foundation

final class LedgerWalletConfirmWireframe: LedgerWalletConfirmWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
