import Foundation
import SubstrateSdk

final class DAppOperationConfirmWireframe: DAppOperationConfirmWireframeProtocol {
    func close(view: DAppOperationConfirmViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showTxDetails(from view: DAppOperationConfirmViewProtocol?, json: JSON) {
        guard let detailsView = DAppTxDetailsViewFactory.createView(from: json) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: detailsView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
