import Foundation
import SoraUI

final class DAppBrowserWireframe: DAppBrowserWireframeProtocol {
    func presentOperationConfirm(
        from view: DAppBrowserViewProtocol?,
        request: DAppOperationRequest,
        type: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    ) {
        guard let confirmationView = DAppOperationConfirmViewFactory.createView(
            for: request,
            type: type,
            delegate: delegate
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless
        )

        confirmationView.controller.modalTransitioningFactory = factory
        confirmationView.controller.modalPresentationStyle = .custom

        view?.controller.present(confirmationView.controller, animated: true, completion: nil)
    }

    func presentSearch(
        from view: DAppBrowserViewProtocol?,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    ) {
        guard let searchView = DAppSearchViewFactory.createView(with: initialQuery, delegate: delegate) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func presentAuth(
        from view: DAppBrowserViewProtocol?,
        request: DAppAuthRequest,
        delegate: DAppAuthDelegate
    ) {
        guard let authVew = DAppAuthConfirmViewFactory.createView(for: request, delegate: delegate) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearless
        )
        authVew.controller.modalTransitioningFactory = factory
        authVew.controller.modalPresentationStyle = .custom

        view?.controller.present(authVew.controller, animated: true, completion: nil)
    }

    func presentPhishingDetected(
        from view: DAppBrowserViewProtocol?,
        delegate: DAppPhishingViewDelegate
    ) {
        guard let phishingView = DAppPhishingViewFactory.createView(with: delegate) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearless
        )
        phishingView.controller.modalTransitioningFactory = factory
        phishingView.controller.modalPresentationStyle = .custom

        view?.controller.present(phishingView.controller, animated: true, completion: nil)
    }

    func presentAddToFavoriteForm(from view: DAppBrowserViewProtocol?, page: DAppBrowserPage) {
        guard let addFavoriteView = DAppAddFavoriteViewFactory.createView(for: page) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: addFavoriteView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func close(view: DAppBrowserViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
