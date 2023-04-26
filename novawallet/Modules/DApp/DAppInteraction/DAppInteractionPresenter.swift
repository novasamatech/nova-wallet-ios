import UIKit
import SoraUI

final class DAppInteractionPresenter {
    var window: UIWindow? { UIApplication.shared.keyWindow }

    weak var interactor: DAppInteractionInputProtocol?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension DAppInteractionPresenter: DAppInteractionOutputProtocol {
    func didReceiveConfirmation(request: DAppOperationRequest, type: DAppSigningType) {
        guard let confirmationView = DAppOperationConfirmViewFactory.createView(
            for: request,
            type: type,
            delegate: self
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova
        )

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        window?.rootViewController?.topModalViewController.present(
            confirmationView.controller,
            animated: true,
            completion: nil
        )
    }

    func didReceiveAuth(request: DAppAuthRequest) {
        guard let authVew = DAppAuthConfirmViewFactory.createView(for: request, delegate: self) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.nova
        )
        authVew.controller.modalTransitioningFactory = factory
        authVew.controller.modalPresentationStyle = .custom

        window?.rootViewController?.topModalViewController.present(
            authVew.controller,
            animated: true,
            completion: nil
        )
    }

    func didDetectPhishing(host _: String) {
        guard let phishingView = DAppPhishingViewFactory.createView(with: self) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.nova
        )
        phishingView.controller.modalTransitioningFactory = factory
        phishingView.controller.modalPresentationStyle = .custom

        window?.rootViewController?.topModalViewController.present(
            phishingView.controller,
            animated: true,
            completion: nil
        )
    }

    func didReceive(error: DAppInteractionError) {
        logger.error("Did receive error: \(error)")
    }
}

extension DAppInteractionPresenter: DAppAuthDelegate {
    func didReceiveAuthResponse(_ response: DAppAuthResponse, for request: DAppAuthRequest) {
        interactor?.processAuth(response: response, forTransport: request.transportName)
    }
}

extension DAppInteractionPresenter: DAppOperationConfirmDelegate {
    func didReceiveConfirmationResponse(
        _ response: DAppOperationResponse,
        for request: DAppOperationRequest
    ) {
        interactor?.processConfirmation(response: response, forTransport: request.transportName)
    }
}

extension DAppInteractionPresenter: DAppPhishingViewDelegate {
    func dappPhishingViewDidHide() {
        // TODO: we might need to notify child ui to hide phishing interface
    }
}
