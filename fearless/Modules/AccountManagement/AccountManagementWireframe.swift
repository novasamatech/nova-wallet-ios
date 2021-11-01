import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol {
    func showCreateAccount(
        from view: AccountManagementViewProtocol?,
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

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(createAccountView.controller, animated: true)
        }
    }

    func showImportAccount(
        from view: AccountManagementViewProtocol?,
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

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(importAccountView.controller, animated: true)
        }
    }
}
