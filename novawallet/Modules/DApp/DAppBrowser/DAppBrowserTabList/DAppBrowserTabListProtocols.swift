import Foundation
import UIKit

protocol DAppBrowserParentViewProtocol: AnyObject {
    func close()
}

protocol DAppBrowserTabListViewProtocol: ControllerBackedProtocol, DAppBrowserTabViewTransitionProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabViewModel])
}

protocol DAppBrowserTabListPresenterProtocol: AnyObject {
    func setup()
    func selectTab(with id: UUID)
    func openNewTab()
    func closeTab(with id: UUID)
    func closeAllTabs()
    func close()
}

protocol DAppBrowserTabListInteractorInputProtocol: AnyObject {
    func setup()
    func closeTab(with id: UUID)
    func closeAllTabs()
}

protocol DAppBrowserTabListInteractorOutputProtocol: AnyObject {
    func didReceiveTabs(_ models: [DAppBrowserTab])
    func didReceiveError(_ error: Error)
}

protocol DAppBrowserTabListWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    DAppBrowserSearchPresentable {
    func close(from view: ControllerBackedProtocol?)
}

protocol DAppBrowserTabViewTransitionProtocol {
    func getTabViewForTransition(for tabId: UUID) -> UIView?
}

protocol DAppBrowserSearchPresentable: AnyObject {
    func presentSearch(
        from view: ControllerBackedProtocol?,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    )
}

extension DAppBrowserSearchPresentable {
    func presentSearch(
        from view: ControllerBackedProtocol?,
        initialQuery: String?,
        delegate: DAppSearchDelegate
    ) {
        guard let searchView = DAppSearchViewFactory.createView(with: initialQuery, delegate: delegate) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .fullScreen
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
