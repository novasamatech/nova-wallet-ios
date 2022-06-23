import Foundation
import SoraFoundation

final class TransferSetupWireframe: TransferSetupWireframeProtocol {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?,
        locale _: Locale
    ) {
        let title = LocalizableResource { _ in
            "Recipient network"
        }

        guard let viewController = ModalPickerFactory.createNetworkSelectionList(
            selectionState: selectionState,
            delegate: delegate,
            title: title,
            context: context
        ) else {
            return
        }

        view?.controller.present(viewController, animated: true, completion: nil)
    }
}
