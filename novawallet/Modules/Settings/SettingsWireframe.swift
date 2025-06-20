import Foundation
import UIKit

final class SettingsWireframe {
    let serviceCoordinator: ServiceCoordinatorProtocol

    var delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol {
        serviceCoordinator.delegatedAccountSyncService
    }

    init(serviceCoordinator: ServiceCoordinatorProtocol) {
        self.serviceCoordinator = serviceCoordinator
    }

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

// MARK: SettingsWireframeProtocol

extension SettingsWireframe: SettingsWireframeProtocol {
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
                with: serviceCoordinator.dappMediator
            ) else {
            return
        }

        walletConnectView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(walletConnectView.controller, animated: true)
    }

    func showManageNotifications(from view: ControllerBackedProtocol?) {
        guard let manageNotificationsView = NotificationsManagementViewFactory.createView() else {
            return
        }
        manageNotificationsView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            manageNotificationsView.controller,
            animated: true
        )
    }

    func showNetworks(from view: ControllerBackedProtocol?) {
        guard let networksView = NetworksListViewFactory.createView() else {
            return
        }
        networksView.controller.hidesBottomBarWhenPushed = true
        view?.controller.navigationController?.pushViewController(
            networksView.controller,
            animated: true
        )
    }

    func showBackup(from view: ControllerBackedProtocol?) {
        guard let backupView = CloudBackupSettingsViewFactory.createView() else {
            return
        }

        backupView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            backupView.controller,
            animated: true
        )
    }

    func showAppearance(from view: ControllerBackedProtocol?) {
        guard let appearanceView = AppearanceSettingsViewFactory.createView() else {
            return
        }

        appearanceView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            appearanceView.controller,
            animated: true
        )
    }
}
