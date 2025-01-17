import Foundation
import SubstrateSdk

class DAppOperationConfirmWireframe: DAppOperationConfirmWireframeProtocol {
    func close(view: DAppOperationConfirmViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showTxDetails(from view: DAppOperationConfirmViewProtocol?, json: JSON) {
        guard let detailsView = DAppTxDetailsViewFactory.createView(from: json) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: detailsView.controller)
        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}

final class DAppOperationEvmConfirmWireframe: DAppOperationConfirmWireframe, EvmValidationErrorPresentable {}
