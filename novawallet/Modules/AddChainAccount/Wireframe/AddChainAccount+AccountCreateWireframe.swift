import Foundation
import IrohaCrypto

extension AddChainAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func confirm(
            from view: AccountCreateViewProtocol?,
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

        func presentCryptoTypeSelection(
            from view: AccountCreateViewProtocol?,
            availableTypes: [MultiassetCryptoType],
            selectedType: MultiassetCryptoType,
            delegate: ModalPickerViewControllerDelegate?,
            context: AnyObject?
        ) {
            guard let modalPicker = ModalPickerFactory.createPickerForList(
                availableTypes,
                selectedType: selectedType,
                delegate: delegate,
                context: context
            ) else {
                return
            }

            view?.controller.navigationController?.present(
                modalPicker,
                animated: true,
                completion: nil
            )
        }
    }
}
