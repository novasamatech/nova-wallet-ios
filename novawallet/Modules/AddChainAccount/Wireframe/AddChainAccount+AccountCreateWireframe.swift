import Foundation
import IrohaCrypto

extension AddChainAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func confirm(
            from view: OldAccountCreateViewProtocol?,
            request: ChainAccountImportMnemonicRequest,
            metaAccountModel: MetaAccountModel,
            chainModelId: ChainModel.Id
        ) {
            guard let confirmationController = AccountConfirmViewFactory.createViewForReplace(
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId
            )?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(confirmationController, animated: true)
            }
        }
    }
}
