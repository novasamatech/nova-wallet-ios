import Foundation

final class CloudBackupAddWalletWireframe: CloudBackupAddWalletWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
