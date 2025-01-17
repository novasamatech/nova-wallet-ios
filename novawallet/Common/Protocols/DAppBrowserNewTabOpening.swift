import Foundation
import UIKit

protocol DAppBrowserOpening: AnyObject {
    func showNewBrowserStack(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    )

    func showBrowserTabs(from view: ControllerBackedProtocol?)
}

extension DAppBrowserOpening {
    func showNewBrowserStack(
        _ tab: DAppBrowserTab,
        from _: ControllerBackedProtocol?
    ) {
        guard let mainContainerView = findMainContainer() else { return }

        mainContainerView.openBrowser(with: tab)
    }

    func showBrowserTabs(from _: ControllerBackedProtocol?) {
        guard let mainContainerView = findMainContainer() else { return }

        mainContainerView.openBrowser(with: nil)
    }

    private func findMainContainer() -> NovaMainAppContainerViewProtocol? {
        UIApplication
            .shared
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController as? NovaMainAppContainerViewProtocol
    }
}
