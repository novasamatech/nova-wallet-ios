import Foundation

final class NotificationsManagementWireframe: NotificationsManagementWireframeProtocol {
    func showWallets(from _: ControllerBackedProtocol?) {}
    func showStakingRewardsSetup(from _: ControllerBackedProtocol?) {}
    func showGovSetup(from _: ControllerBackedProtocol?) {}
    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
