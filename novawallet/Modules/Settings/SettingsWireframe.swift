import Foundation
import UIKit

final class SettingsWireframe: SettingsWireframeProtocol, AuthorizationPresentable {
    let dappMediator: DAppInteractionMediating
    let proxySyncService: ProxySyncServiceProtocol

    init(
        dappMediator: DAppInteractionMediating,
        proxySyncService: ProxySyncServiceProtocol
    ) {
        self.dappMediator = dappMediator
        self.proxySyncService = proxySyncService
    }

    func showAccountDetails(for walletId: String, from view: ControllerBackedProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createView(for: walletId) else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }

    func showPincodeChange(from view: ControllerBackedProtocol?) {
        authorize(animated: true, cancellable: true) { [weak self] completed in
            if completed {
                self?.showPinSetup(from: view)
            }
        }
    }

    func showAuthorization(completion: @escaping (Bool) -> Void) {
        authorize(animated: true, cancellable: true) { completed in
            completion(completed)
        }
    }

    func showPincodeAuthorization(completion: @escaping (Bool) -> Void) {
        authorizeByPinCode(animated: true, cancellable: true) { completed in
            completion(completed)
        }
    }

    func showAccountSelection(from view: ControllerBackedProtocol?) {
        guard let accountManagement = WalletManageViewFactory.createViewForAdding() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }

    func showLanguageSelection(from view: ControllerBackedProtocol?) {
        guard let languageSelection = LanguageSelectionViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            languageSelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(languageSelection.controller, animated: true)
        }
    }

    func showCurrencies(from view: ControllerBackedProtocol?) {
        guard let currencySelection = CurrencyViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            currencySelection.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(currencySelection.controller, animated: true)
        }
    }

    func show(url: URL, from view: ControllerBackedProtocol?) {
        guard let view = view, let scheme = url.scheme else {
            return
        }
        if supportedSafariScheme.contains(scheme) {
            showWeb(url: url, from: view, style: .automatic)
        } else if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func showWalletConnect(from view: ControllerBackedProtocol?) {
        guard
            let walletConnectView = WalletConnectSessionsViewFactory.createView(
                with: dappMediator
            ) else {
            return
        }

        walletConnectView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(walletConnectView.controller, animated: true)
    }

    func showSetupNotifications(from view: ControllerBackedProtocol?, delegate: PushNotificationsStatusDelegate) {
        guard let setupNotificationsView = NotificationsSetupViewFactory.createView(delegate: delegate) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: setupNotificationsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showManageNotifications(from view: ControllerBackedProtocol?, delegate: PushNotificationsStatusDelegate) {
        guard let manageNotificationsView = NotificationsManagementViewFactory.createView(delegate: delegate) else {
            return
        }
        manageNotificationsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            manageNotificationsView.controller,
            animated: true
        )
    }

    // MARK: Private

    private func showPinSetup(from view: ControllerBackedProtocol?) {
        guard let pinSetup = PinViewFactory.createPinChangeView() else {
            return
        }

        pinSetup.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            pinSetup.controller,
            animated: true
        )
    }
}
