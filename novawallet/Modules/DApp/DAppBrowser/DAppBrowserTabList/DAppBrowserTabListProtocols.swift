import Foundation
import UIKit

protocol DAppBrowserParentViewProtocol: AnyObject {
    func close()
    func minimize()
}

protocol DAppBrowserTabListViewProtocol: ControllerBackedProtocol, DAppBrowserTabViewTransitionProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabViewModel])
    func setScrollsToLatestOnLoad()
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
    DAppBrowserSearchPresentable,
    DAppBrowserTabsClosePresentable {
    func showTab(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    )

    func close(from view: ControllerBackedProtocol?)
}

protocol DAppBrowserTabViewTransitionProtocol {
    func getTabViewForTransition(for tabId: UUID) -> UIView?
}

protocol DAppBrowserSearchPresentable: AnyObject {
    func presentSearch(
        from view: ControllerBackedProtocol?,
        initialQuery: String?,
        selectedCategoryId: String?,
        delegate: DAppSearchDelegate
    )
}

extension DAppBrowserSearchPresentable {
    func presentSearch(
        from view: ControllerBackedProtocol?,
        initialQuery: String? = nil,
        selectedCategoryId: String? = nil,
        delegate: DAppSearchDelegate
    ) {
        guard let searchView = DAppSearchViewFactory.createView(
            with: initialQuery,
            selectedCategoryId: selectedCategoryId,
            delegate: delegate
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: searchView.controller)
        navigationController.barSettings = NavigationBarSettings.defaultSettings.bySettingCloseButton(false)

        navigationController.modalTransitionStyle = .crossDissolve
        navigationController.modalPresentationStyle = .overCurrentContext
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
