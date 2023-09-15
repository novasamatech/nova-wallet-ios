import Foundation

class StartStakingInfoWireframe: StartStakingInfoWireframeProtocol {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let accountManagementView = AccountManagementViewFactory.createView(for: wallet.identifier) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountManagementView.controller, animated: true)
    }

    func showSetupAmount(from _: ControllerBackedProtocol?) {
        fatalError("Must be overriden by subsclass")
    }

    func complete(from view: ControllerBackedProtocol?) {
        MainTransitionHelper.dismissAndPopBack(from: view)
    }
}
