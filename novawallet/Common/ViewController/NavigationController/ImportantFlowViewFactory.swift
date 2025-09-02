import UIKit
import Foundation_iOS

class ImportantFlowViewFactory {
    static func createNavigation(
        from rootViewController: UIViewController,
        barSettings: NavigationBarSettings = .defaultSettings,
        dismissalClosure: (() -> Void)? = nil
    ) -> UINavigationController {
        let navigationController = ImportantFlowNavigationController(
            rootViewController: rootViewController,
            localizationManager: LocalizationManager.shared,
            dismissalClosure: dismissalClosure
        )

        navigationController.barSettings = barSettings

        return navigationController
    }
}
