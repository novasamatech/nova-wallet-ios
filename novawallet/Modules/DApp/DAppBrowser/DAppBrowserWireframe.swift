import Foundation
import UIKit_iOS

class BaseDAppBrowserWireframe {
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

        view?.controller.presentWithCardLayout(
            confirmationView.controller,
            animated: true,
            completion: nil
        )
    }

    func presentSearch(
        from view: DAppBrowserViewProtocol?,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    ) {
        guard let searchView = DAppSearchViewFactory.createView(with: initialQuery, delegate: delegate) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: searchView.controller)
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
            configuration: ModalSheetPresentationConfiguration.nova
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
            configuration: ModalSheetPresentationConfiguration.nova
        )
        phishingView.controller.modalTransitioningFactory = factory
        phishingView.controller.modalPresentationStyle = .custom

        view?.controller.present(phishingView.controller, animated: true, completion: nil)
    }

    func presentAddToFavoriteForm(
        from view: DAppBrowserViewProtocol?,
        page: DAppBrowserPage
    ) {
        guard let addFavoriteView = DAppAddFavoriteViewFactory.createView(for: page) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: addFavoriteView.controller)

        view?.controller.present(
            navigationController,
            animated: true
        )
    }

    func presentSettings(
        from view: DAppBrowserViewProtocol?,
        state: DAppSettingsInput,
        delegate: DAppSettingsDelegate
    ) {
        guard let dappSettingsView = DAppSettingsViewFactory.createView(
            state: state,
            delegate: delegate
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.nova
        )
        dappSettingsView.controller.modalTransitioningFactory = factory
        dappSettingsView.controller.modalPresentationStyle = .custom

        view?.controller.present(dappSettingsView.controller, animated: true, completion: nil)
    }

    func showTabs(from view: DAppBrowserViewProtocol?) {
        DAppBrowserTabTransition.setTransition(
            from: view?.controller,
            to: nil,
            tabId: nil
        )

        view?.controller.navigationController?.popViewController(
            animated: DAppBrowserTabTransition.animated
        )
    }
}

final class DAppBrowserWireframe: BaseDAppBrowserWireframe, DAppBrowserWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }
}

final class DAppBrowserChildWireframe: BaseDAppBrowserWireframe, DAppBrowserWireframeProtocol {
    private let parentView: DAppBrowserParentViewProtocol

    init(parentView: DAppBrowserParentViewProtocol) {
        self.parentView = parentView
    }

    func close(view _: ControllerBackedProtocol?) {
        parentView.minimize()
    }
}
