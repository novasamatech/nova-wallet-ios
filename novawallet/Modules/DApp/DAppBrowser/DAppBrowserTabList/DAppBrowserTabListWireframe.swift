import Foundation

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func showTab(
        from view: ControllerBackedProtocol?,
        _ tab: DAppBrowserTab,
        dApp: DApp?
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(
            with: dApp,
            selectedTab: tab
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }
}
