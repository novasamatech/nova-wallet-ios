import Foundation
import SoraUI

final class SignerConnectWireframe: SignerConnectWireframeProtocol, ModalAlertPresenting {
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

    func presentOperationSuccess(from view: SignerConnectViewProtocol?, locale: Locale) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        presentSuccessNotification(title, from: view?.controller, completion: nil)
    }
}
