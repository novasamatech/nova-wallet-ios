import Foundation

extension SwitchAccount {
    final class CloudBackupAddWalletWireframe: CloudBackupAddWalletWireframeProtocol {
        func proceed(from view: UsernameSetupViewProtocol?) {
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            navigationController.popToRootViewController(animated: true)
        }
    }
}
