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
    
    func showYourWallets(from view: TransferSetupViewProtocol?, chain: ChainAsset, address: AccountAddress?) {
        guard let viewController = YourWalletsViewFactory.createView(chain: chain,
                                                                     address: address) else {
            return
        }

        view?.controller.present(viewController, animated: true, completion: nil)
    }
}
