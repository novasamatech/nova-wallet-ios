import Foundation

final class StakingMainWireframe: StakingMainWireframeProtocol {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }
}
