import Foundation

final class StartStakingInfoWireframe: StartStakingInfoWireframeProtocol {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }

    func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let setupAmountView = StakingSetupAmountViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(setupAmountView.controller, animated: true)
    }
}
