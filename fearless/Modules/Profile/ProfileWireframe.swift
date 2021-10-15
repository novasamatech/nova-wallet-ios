import Foundation
import UIKit

final class ProfileWireframe: ProfileWireframeProtocol, AuthorizationPresentable {
    func showAccountDetails(from view: ControllerBackedProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createViewForSettings() else {
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

    func showAccountSelection(from view: ControllerBackedProtocol?) {
        guard let accountManagement = AccountManagementViewFactory.createViewForSettings() else {
            return
        }

        accountManagement.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            accountManagement.controller,
            animated: true
        )
    }

    func showNetworks(from view: ControllerBackedProtocol?) {
        guard let networkList = NetworksViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            networkList.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(networkList.controller, animated: true)
        }
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

    func showAbout(from view: ControllerBackedProtocol?) {
        guard let aboutView = AboutViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            aboutView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(aboutView.controller, animated: true)
        }
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
