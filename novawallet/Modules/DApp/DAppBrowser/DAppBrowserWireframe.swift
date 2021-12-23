import Foundation
import SoraUI

final class DAppBrowserWireframe: DAppBrowserWireframeProtocol {
    func presentOperationConfirm(
        from view: DAppBrowserViewProtocol?,
        request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate
    ) {
        guard let confirmationView = DAppOperationConfirmViewFactory.createView(
            for: request,
            delegate: delegate
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
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
        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
