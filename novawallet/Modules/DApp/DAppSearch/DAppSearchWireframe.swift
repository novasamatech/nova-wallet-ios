import Foundation

final class DAppSearchWireframe: DAppSearchWireframeProtocol {
    func showBrowser(from view: DAppSearchViewProtocol?, input: String) {
        guard let browserView = DAppBrowserViewFactory.createView(for: input) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }
}
