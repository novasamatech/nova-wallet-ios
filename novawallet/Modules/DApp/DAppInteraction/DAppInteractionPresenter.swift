import UIKit
import UIKit_iOS
import Foundation_iOS

final class DAppInteractionPresenter: AlertPresentable, ErrorPresentable {
    var window: UIWindow? { UIApplication.shared.keyWindow }

    weak var interactor: DAppInteractionInputProtocol?

    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(logger: LoggerProtocol, localizationManager: LocalizationManagerProtocol) {
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func presentModal(the controller: UIViewController, style: UIModalPresentationStyle = .overFullScreen) {
        let navigationController = NovaNavigationController(rootViewController: controller)
        navigationController.barSettings = .init(style: .defaultStyle, shouldSetCloseButton: false)

        navigationController.modalPresentationStyle = style

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
        presentModal(the: view.controller, style: .automatic)
    }

    private func presentWalletConnectAuthConfirmation(for request: DAppAuthRequest) {
        guard
            let confirmationView = DAppWalletAuthViewFactory.createWalletConnectView(
                for: request,
                delegate: self
            ) else {
            return
        }

        presentModal(the: confirmationView.controller)
    }

    private func presentWalletConnectRequestConfirmation(view: DAppOperationConfirmViewProtocol) {
        presentModal(the: view.controller)
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

        _ = present(error: error, from: nil, locale: localizationManager.selectedLocale)
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
        interactor?.completePhishingStateHandling()
    }
}
