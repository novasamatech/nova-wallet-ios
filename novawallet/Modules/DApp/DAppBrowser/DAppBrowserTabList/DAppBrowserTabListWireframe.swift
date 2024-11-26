import Foundation

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func showTab(
        from view: DAppBrowserTabListViewProtocol?,
        _ tab: DAppBrowserTab
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        if #available(iOS 18.0, *) {
            browserView.controller.preferredTransition = .zoom { _ in
                view?.getTabViewForTransition(for: tab.uuid)
            }
        } else {
            // Fallback on earlier versions
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
