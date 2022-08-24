import Foundation
import SoraFoundation

final class TransferSetupWireframe: TransferSetupWireframeProtocol {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let viewController = ModalPickerFactory.createNetworkSelectionList(
            selectionState: selectionState,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(viewController, animated: true, completion: nil)
    }

    func showRecepientScan(from view: TransferSetupViewProtocol?, delegate: AddressScanDelegate) {
        guard
            let scanView = AddressScanViewFactory.createTransferRecipientScan(
                for: delegate,
                context: nil
            ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: scanView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func hideRecepientScan(from view: TransferSetupViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showYourWallets(
        from view: TransferSetupViewProtocol?,
        accounts: [PossibleMetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    ) {
        guard let viewController = YourWalletsViewFactory.createView(
            metaAccounts: accounts,
            address: address,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.present(viewController.controller, animated: true, completion: nil)
    }
}
