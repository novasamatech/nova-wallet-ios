import Foundation
import UIKit

protocol DAppBrowserTabListViewProtocol: ControllerBackedProtocol, DAppBrowserTabViewTransitionProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabViewModel])
}

protocol DAppBrowserTabListPresenterProtocol: AnyObject {
    func setup()
    func selectTab(with id: UUID)
    func openNewTab()
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

protocol DAppBrowserTabListWireframeProtocol: AnyObject, AlertPresentable, ErrorPresentable {
    func showExistingTab(
        from view: DAppBrowserTabListViewProtocol?,
        _ tab: DAppBrowserTab
    )
    func showNewTab(
        from view: DAppBrowserTabListViewProtocol?,
        _ tab: DAppBrowserTab
    )
    func close(from view: ControllerBackedProtocol?)
}

protocol DAppBrowserTabViewTransitionProtocol {
    func getTabViewForTransition(for tabId: UUID) -> UIView?
}
