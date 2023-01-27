import UIKit

protocol InAppUpdatesServiceWireframeProtocol {
    func showUpdates(notInstalledVersions: [Release])
}

final class InAppUpdatesServiceWireframe: InAppUpdatesServiceWireframeProtocol {
    func showUpdates(notInstalledVersions: [Release]) {
        guard
            let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
            let view = InAppUpdatesViewFactory.createView(versions: notInstalledVersions),
            let topViewController = window.rootViewController?.topModalViewController else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: view.controller)
        navigationController.barSettings = .defaultSettings.bySettingCloseButton(false)
        topViewController.present(navigationController, animated: true)
    }
}
