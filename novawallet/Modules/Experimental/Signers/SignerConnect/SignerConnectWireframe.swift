import Foundation
import SoraUI

final class SignerConnectWireframe: SignerConnectWireframeProtocol {
    func showConfirmation(
        from view: SignerConnectViewProtocol?,
        request: DAppOperationRequest,
        signingType: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    ) {
        guard let confirmView = DAppOperationConfirmViewFactory.createView(
            for: request,
            type: signingType,
            delegate: delegate
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless
        )

        confirmView.controller.modalTransitioningFactory = factory
        confirmView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmView.controller, animated: true, completion: nil)
    }
}
