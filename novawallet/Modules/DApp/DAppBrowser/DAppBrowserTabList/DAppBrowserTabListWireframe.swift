import Foundation

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func showTab(
        from view: ControllerBackedProtocol?,
        _ tab: DAppBrowserTab
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }

    func close(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
