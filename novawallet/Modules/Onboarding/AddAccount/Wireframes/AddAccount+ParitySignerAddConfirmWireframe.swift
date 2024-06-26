import Foundation

extension AddAccount {
    final class ParitySignerAddConfirmWireframe: ParitySignerAddConfirmWireframeProtocol {
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
}
