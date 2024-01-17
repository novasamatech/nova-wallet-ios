import Foundation

final class StakingConfirmProxyWireframe: StakingConfirmProxyWireframeProtocol {
    func complete(from view: StakingRebagConfirmViewProtocol?) {
        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification("", from: presenter, completion: nil)
        }
    }
}
