import Foundation
import UIKit

final class AppearanceSettingsWireframe: AppearanceSettingsWireframeProtocol {
    func presentAppearanceChanged(from view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
