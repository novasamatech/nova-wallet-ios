import Foundation
import UIKit

final class AppearanceSettingsWireframe: AppearanceSettingsWireframeProtocol {
    func presentAppearanceChanged(from view: ControllerBackedProtocol?) {
        let tabBar = view?.controller.tabBarController

        guard
            let window = view?.controller.view.window,
            let selectedViewController = tabBar?.selectedViewController,
            let navigationController = view?.controller.navigationController,
            let snapshot = view?.controller.navigationController?.view.snapshotView(
                afterScreenUpdates: false
            ) else {
            return
        }

        snapshot.frame = navigationController.view.frame
        window.addSubview(snapshot)

        navigationController.view.isHidden = true
        navigationController.popViewController(animated: false)

        tabBar?.selectedIndex = 0

        selectedViewController.view.isHidden = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                snapshot.alpha = 0
            }, completion: { _ in
                snapshot.removeFromSuperview()

                selectedViewController.view.isHidden = false
                selectedViewController.view.alpha = 0

                UIView.animate(withDuration: 0.2) {
                    selectedViewController.view.alpha = 1
                }
            }
        )
    }
}
