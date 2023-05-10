import UIKit
import SoraUI

final class DAppInteractionPresenter {
    var window: UIWindow? { UIApplication.shared.keyWindow }

    weak var interactor: DAppInteractionInputProtocol?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func presentOverFullscreen(the controller: UIViewController) {
        let navigationController = NovaNavigationController(rootViewController: controller)
        navigationController.barSettings = .init(style: .defaultStyle, shouldSetCloseButton: false)

        navigationController.modalPresentationStyle = .overFullScreen

        window?.rootViewController?.topModalViewController.present(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    private func presentInBottomSheet(the controller: UIViewController) {
        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.nova
        )

        controller.modalTransitioningFactory = factory
        controller.modalPresentationStyle = .custom

        window?.rootViewController?.topModalViewController.present(
            controller,
            animated: true,
            completion: nil
        )
    }

    private func presentDefaultAuthConfirmation(for request: DAppAuthRequest) {
        guard let authVew = DAppAuthConfirmViewFactory.createView(for: request, delegate: self) else {
            return
        }

        presentInBottomSheet(the: authVew.controller)
    }

    private func presentDefaultRequestConfirmation(view: DAppOperationConfirmViewProtocol) {
        presentInBottomSheet(the: view.controller)
    }

    private func presentWalletConnectAuthConfirmation(for request: DAppAuthRequest) {
        guard
            let confirmationView = DAppWalletAuthViewFactory.createWalletConnectView(
                for: request,
                delegate: self
            ) else {
            return
        }

        presentOverFullscreen(the: confirmationView.controller)
    }

    private func presentWalletConnectRequestConfirmation(view: DAppOperationConfirmViewProtocol) {
        presentOverFullscreen(the: view.controller)
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

        if request.transportName == DAppTransports.walletConnect {
            presentWalletConnectRequestConfirmation(view: confirmationView)
        } else {
            presentDefaultRequestConfirmation(view: confirmationView)
        }
    }

    func didReceiveAuth(request: DAppAuthRequest) {
        if request.transportName == DAppTransports.walletConnect {
            presentWalletConnectAuthConfirmation(for: request)
        } else {
            presentDefaultAuthConfirmation(for: request)
        }
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
