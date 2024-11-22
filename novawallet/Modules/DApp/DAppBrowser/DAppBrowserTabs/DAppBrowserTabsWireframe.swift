import Foundation

final class DAppBrowserTabsWireframe: DAppBrowserTabsWireframeProtocol {
    func close(view: DAppBrowserTabsViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
