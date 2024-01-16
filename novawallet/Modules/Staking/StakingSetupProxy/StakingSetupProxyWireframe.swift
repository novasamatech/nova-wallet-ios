import Foundation

final class StakingSetupProxyWireframe: StakingSetupProxyWireframeProtocol {
    func checkDismissing(view: ControllerBackedProtocol?) -> Bool {
        view?.controller.navigationController?.isBeingDismissed ?? true
    }
}
