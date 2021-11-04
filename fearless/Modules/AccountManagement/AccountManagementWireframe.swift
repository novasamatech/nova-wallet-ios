import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showCreateAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        guard let createAccountView = AccountCreateViewFactory.createViewForReplaceChainAccount(
            metaAccountModel: wallet,
            chainModelId: chainId,
            isEthereumBased: isEthereumBased
        ) else {
            return
        }

        let controller = createAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    func showImportAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        guard let importAccountView = AccountImportViewFactory.createViewForReplaceChainAccount(
            modelId: chainId,
            isEthereumBased: isEthereumBased,
            in: wallet
        ) else {
            return
        }

        let controller = importAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }
}
